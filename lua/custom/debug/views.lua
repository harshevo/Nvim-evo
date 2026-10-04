local M = { generations = {}, expressions = {} }
local tasks = require 'custom.cpp.tasks'

local function visible(kind)
  local state = tasks.states[kind]
  return state and state.buf and vim.api.nvim_buf_is_valid(state.buf) and #vim.fn.win_findbuf(state.buf) > 0
end

local function show(kind, lines)
  local state = tasks.states[kind]
  if state then
    state.lines = lines
    tasks.refresh(kind)
  end
end

local function context(kind)
  M.generations[kind] = (M.generations[kind] or 0) + 1
  local generation = M.generations[kind]
  local session = require('dap').session()
  tasks.states[kind].locations = {}
  tasks.states[kind].cwd = session and session.config.cwd or vim.fn.getcwd()
  local frame = session and session.current_frame
  if not session or not frame or not session.stopped_thread_id then
    show(kind, { 'Pause the debugger at a breakpoint first.', 'Space dc: start / continue   Space dp: pause' })
    return
  end
  return session,
    frame,
    function()
      return M.generations[kind] == generation
        and require('dap').session() == session
        and session.stopped_thread_id ~= nil
        and session.current_frame
        and session.current_frame.id == frame.id
    end
end

local function evaluate(session, frame, expression, context_name, callback)
  session:request_with_timeout('evaluate', { expression = expression, frameId = frame.id, context = context_name or 'watch' }, 5000, callback)
end

local function lines(text)
  return vim.split(text or '', '\n', { plain = true })
end

local function read_memory()
  local kind = 'debug-memory'
  local session, frame, current = context(kind)
  if not session then
    return
  end
  local python = session.config.type == 'python' or session.config.type == 'python_attach'
  local expression = M.expressions[python and 'python' or 'native'] or (python and 'locals()' or '(void*)$sp')
  show(kind, { 'Memory: ' .. expression, 'Reading paused process...' })
  evaluate(session, frame, expression, 'watch', function(error, result)
    if not current() then
      return
    end
    if error then
      show(kind, { 'Memory expression: ' .. expression, error.message, 'Space dM: choose another address/expression' })
      return
    end
    if python then
      local output = {
        'Python object view (native memory is unavailable in debugpy)',
        'Expression: ' .. expression,
        'Type: ' .. (result.type or 'object'),
        '',
        (result.result or ''):sub(1, 8000),
      }
      show(kind, output)
      evaluate(session, frame, "__import__('sys').getsizeof(" .. expression .. ')', 'watch', function(size_error, size)
        if current() and not size_error then
          output[#output + 1] = 'Shallow object size: ' .. size.result .. ' bytes'
          show(kind, output)
        end
      end)
      return
    end
    local address = result.memoryReference or (result.result or ''):match '0x[%da-fA-F]+'
    if not address then
      show(kind, {
        'Expression has no memory address: ' .. expression,
        result.result or '',
        'Use &variable for an object, or a pointer/address.',
        'Space dM: choose expression',
      })
      return
    end
    local function fallback()
      evaluate(session, frame, '`memory read --format x --size 1 --count 128 ' .. address, 'repl', function(read_error, memory)
        if current() then
          local output = { 'Native memory: ' .. expression .. ' @ ' .. address, '' }
          vim.list_extend(output, lines(read_error and read_error.message or memory.result))
          show(kind, output)
        end
      end)
    end
    if not session.capabilities.supportsReadMemoryRequest then
      fallback()
      return
    end
    session:request_with_timeout('readMemory', { memoryReference = address, count = 128 }, 5000, function(read_error, memory)
      if not current() then
        return
      end
      if read_error then
        fallback()
        return
      end
      local ok, bytes = pcall(vim.base64.decode, memory.data or '')
      if not ok then
        show(kind, { 'Unable to decode debugger memory response' })
        return
      end
      local output = { 'Native memory: ' .. expression, 'Address: ' .. (memory.address or address), 'Hex bytes / ASCII', '' }
      for offset = 1, #bytes, 16 do
        local hex, ascii = {}, {}
        for index = offset, math.min(offset + 15, #bytes) do
          local byte = bytes:byte(index)
          hex[#hex + 1] = string.format('%02x', byte)
          ascii[#ascii + 1] = byte >= 32 and byte < 127 and string.char(byte) or '.'
        end
        output[#output + 1] = string.format('+%04x  %-47s  %s', offset - 1, table.concat(hex, ' '), table.concat(ascii))
      end
      if memory.unreadableBytes and memory.unreadableBytes > 0 then
        output[#output + 1] = memory.unreadableBytes .. ' bytes unreadable'
      end
      show(kind, output)
    end)
  end)
end

local function read_assembly()
  local kind = 'debug-assembly'
  local session, frame, current = context(kind)
  if not session then
    return
  end
  show(kind, { 'Assembly: ' .. (frame.name or ''), 'Reading...' })
  if session.config.type == 'python' or session.config.type == 'python_attach' then
    local file = frame.source and frame.source.path
    if not file then
      show(kind, { 'This Python frame has no local source file.' })
      return
    end
    local env = require 'custom.python.environment'
    tasks.run(
      kind,
      { session.config.pythonPath or env.python(), vim.fn.stdpath 'config' .. '/scripts/python_bytecode.py', file, tostring(frame.line) },
      session.config.cwd or vim.fs.dirname(file),
      { title = 'Python bytecode from saved source (not native assembly)' }
    )
    return
  end
  local function fallback()
    evaluate(session, frame, '`disassemble --frame --mixed', 'repl', function(error, result)
      if current() then
        show(kind, lines(error and error.message or result.result))
      end
    end)
  end
  if not session.capabilities.supportsDisassembleRequest or not frame.instructionPointerReference then
    fallback()
    return
  end
  session:request_with_timeout(
    'disassemble',
    { memoryReference = frame.instructionPointerReference, instructionOffset = -8, instructionCount = 40, resolveSymbols = true },
    5000,
    function(error, result)
      if not current() then
        return
      end
      if error then
        fallback()
        return
      end
      local output, locations = { 'Assembly: ' .. (frame.name or ''), 'PC: ' .. frame.instructionPointerReference, '' }, {}
      for _, instruction in ipairs(result.instructions or {}) do
        output[#output + 1] = instruction.address .. '  ' .. instruction.instruction
        if instruction.location and instruction.location.path then
          locations[#output] = { file = instruction.location.path, line = instruction.line or 1 }
        end
      end
      tasks.states[kind].locations = locations
      show(kind, output)
    end
  )
end

function M.memory(expression)
  if not expression and visible 'debug-memory' then
    tasks.close 'debug-memory'
    return
  end
  if expression then
    local session = require('dap').session()
    local python = session and (session.config.type == 'python' or session.config.type == 'python_attach')
    M.expressions[python and 'python' or 'native'] = expression
  end
  tasks.open('debug-memory', { layout = 'right' })
  read_memory()
end

function M.choose_memory()
  local word = vim.fn.expand '<cword>'
  local session = require('dap').session()
  local python = session and (session.config.type == 'python' or session.config.type == 'python_attach')
  local default = python and (word ~= '' and word or 'locals()') or (word:match '^[%a_][%w_]*$' and '&' .. word or '(void*)$sp')
  vim.ui.input({ prompt = 'Memory expression/address: ', default = default }, function(expression)
    if expression and expression ~= '' then
      M.memory(expression)
    end
  end)
end

function M.assembly()
  if visible 'debug-assembly' then
    tasks.close 'debug-assembly'
    return
  end
  tasks.open('debug-assembly', { layout = 'right' })
  read_assembly()
end

function M.refresh()
  if visible 'debug-memory' then
    read_memory()
  end
  if visible 'debug-assembly' then
    read_assembly()
  end
end

local dap = require 'dap'
dap.listeners.after.stackTrace.debug_views = function()
  vim.schedule(M.refresh)
end
for _, event in ipairs { 'event_continued', 'event_terminated', 'event_exited' } do
  dap.listeners.after[event].debug_views = function()
    for _, kind in ipairs { 'debug-memory', 'debug-assembly' } do
      M.generations[kind] = (M.generations[kind] or 0) + 1
      tasks.stop(kind)
      show(kind, { event == 'event_continued' and 'Program running; pause to refresh this view.' or 'Debug session ended.' })
    end
  end
end
return M
