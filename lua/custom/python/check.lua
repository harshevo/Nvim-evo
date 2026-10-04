local M = { generation = 0 }
local env = require 'custom.python.environment'
local tasks = require 'custom.cpp.tasks'

local function decode(text)
  local ok, value = pcall(vim.json.decode, text or '')
  return ok and type(value) == 'table' and value or nil
end

function M.ruff_items(result)
  local data, items = decode(result.stdout), {}
  if data then
    for _, item in ipairs(data) do
      items[#items + 1] = {
        filename = item.filename,
        lnum = item.location.row,
        col = item.location.column,
        text = (item.code or 'syntax') .. ': ' .. item.message,
        type = 'E',
      }
    end
  elseif result.code ~= 0 then
    items[#items + 1] = { text = result.stderr ~= '' and result.stderr or result.stdout, type = 'E' }
  end
  return items
end

function M.type_items(result)
  local data, items = decode(result.stdout), {}
  if data then
    for _, item in ipairs(data.generalDiagnostics or {}) do
      items[#items + 1] = {
        filename = item.file,
        lnum = item.range.start.line + 1,
        col = item.range.start.character + 1,
        text = 'Pyright: ' .. item.message,
        type = item.severity == 'error' and 'E' or 'W',
      }
    end
  elseif result.code ~= 0 then
    items[#items + 1] = { text = result.stderr ~= '' and result.stderr or result.stdout, type = 'E' }
  end
  return items
end

local function diagnostics(buf, root, all)
  local items = {}
  for _, client in ipairs(vim.lsp.get_clients { name = 'pyright' }) do
    local namespace = vim.lsp.diagnostic.get_namespace(client.id)
    for _, diagnostic in ipairs(vim.diagnostic.get(all and nil or buf, { namespace = namespace })) do
      local file = vim.api.nvim_buf_get_name(diagnostic.bufnr)
      if file:sub(1, #root + 1) == root .. '/' then
        items[#items + 1] = {
          filename = file,
          lnum = diagnostic.lnum + 1,
          col = diagnostic.col + 1,
          text = 'Pyright: ' .. diagnostic.message,
          type = diagnostic.severity == vim.diagnostic.severity.ERROR and 'E' or 'W',
        }
      end
    end
  end
  return items
end

local function open()
  vim.cmd 'botright copen 12'
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, '<cmd>cclose<CR>', { buffer = true, nowait = true })
  end
  vim.keymap.set('n', 'o', function()
    vim.cmd '.cc'
  end, { buffer = true })
end

function M.stop()
  M.generation = M.generation + 1
  M.running = false
  M.pending = false
  for _, kind in ipairs { 'py-check', 'py-syntax', 'py-check-type' } do
    tasks.stop(kind)
  end
end

function M.run(mode)
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  M.stop()
  local generation, root = M.generation, env.root(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  M.key = file .. ':' .. vim.api.nvim_buf_get_changedtick(buf) .. ':' .. env.python(root)
  M.time = vim.uv.hrtime()
  local all = mode == 'project'
  vim.fn.setqflist({}, 'r', { title = 'Checking Python: ' .. vim.fs.basename(root), items = {} })
  local items, remaining = {}, all and 3 or 2
  local function complete(found)
    if generation ~= M.generation then
      return
    end
    vim.list_extend(items, found)
    remaining = remaining - 1
    if remaining ~= 0 then
      return
    end
    if not all then
      vim.list_extend(items, diagnostics(buf, root, false))
    end
    table.sort(items, function(a, b)
      return (a.filename or '') .. string.format('%08d:%08d', a.lnum or 0, a.col or 0)
        < (b.filename or '') .. string.format('%08d:%08d', b.lnum or 0, b.col or 0)
    end)
    M.items = items
    vim.fn.setqflist({}, 'r', { title = 'Python: ' .. #items .. ' findings', items = items })
    M.time = vim.uv.hrtime()
    M.running = false
  end
  M.running = true
  tasks.run('py-check', { env.tool('ruff', root), 'check', '--output-format=json', '--force-exclude', all and root or file }, root, {
    on_exit = function(result)
      complete(M.ruff_items(result))
    end,
  })
  tasks.run('py-syntax', { env.python(root), vim.fn.stdpath 'config' .. '/scripts/python_syntax.py', file }, root, {
    on_exit = function(result)
      local error = decode(result.stdout)
      complete(
        error and { { filename = error.file, lnum = error.line, col = error.col, text = error.message, type = 'E' } }
          or (result.code ~= 0 and { { text = result.stderr, type = 'E' } } or {})
      )
    end,
  })
  if all then
    tasks.run('py-check-type', { env.tool('pyright', root), '--pythonpath', env.python(root), '--outputjson', root }, root, {
      on_exit = function(result)
        complete(M.type_items(result))
      end,
    })
  end
end

function M.toggle()
  local buf = env.source()
  if not buf then
    return
  end
  if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
    vim.cmd 'cclose'
    return
  end
  open()
  if M.pending then
    return
  end
  local key = vim.api.nvim_buf_get_name(buf) .. ':' .. vim.api.nvim_buf_get_changedtick(buf) .. ':' .. env.python(env.root(buf))
  if M.key == key and (M.running or (M.time and vim.uv.hrtime() - M.time < 2e9)) then
    return
  end
  M.pending = true
  local generation = M.generation
  vim.defer_fn(function()
    if generation == M.generation and vim.api.nvim_buf_is_valid(buf) then
      M.pending = false
      vim.api.nvim_buf_call(buf, function()
        M.run()
      end)
    end
  end, 20)
end

function M.explicit(mode)
  if env.source() then
    open()
    M.run(mode)
  end
end

function M.types()
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  local root = env.root(buf)
  tasks.run('py-type', { env.tool('pyright', root), '--pythonpath', env.python(root), '--outputjson', root }, root, {
    open = true,
    title = 'Project type checking',
    decorate = function(s, result)
      local items = M.type_items(result)
      s.items = items
      s.lines = { 'Project type checking', #items .. ' findings', '' }
      for _, item in ipairs(items) do
        s.lines[#s.lines + 1] = (item.filename and (item.filename .. ':' .. item.lnum .. ':' .. item.col .. ': ') or '') .. item.text:gsub('\n', ' ')
      end
    end,
  })
end

function M.analyze()
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  local root = env.root(buf)
  tasks.run('py-analysis', { env.tool('ruff', root), 'check', '--output-format=json', root }, root, {
    open = true,
    title = 'Project Ruff analysis',
    decorate = function(s, result)
      local items = M.ruff_items(result)
      s.items = items
      s.lines = { 'Project Ruff analysis', #items .. ' findings', '' }
      for _, item in ipairs(items) do
        s.lines[#s.lines + 1] = (item.filename and (item.filename .. ':' .. item.lnum .. ':' .. item.col .. ': ') or '') .. item.text
      end
    end,
  })
end
return M
