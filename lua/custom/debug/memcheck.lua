local M = { generation = 0, running = false }
local tasks = require 'custom.cpp.tasks'
local kind = 'valgrind'

local function signature(buf)
  local parts = { vim.api.nvim_buf_get_name(buf) }
  for _, loaded in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(loaded) and vim.bo[loaded].buftype == '' then
      parts[#parts + 1] = loaded .. ':' .. vim.api.nvim_buf_get_changedtick(loaded)
    end
  end
  return table.concat(parts, '|')
end

local function message(lines)
  tasks.states[kind].lines = lines
  tasks.refresh(kind)
end

local function decorate(state, root)
  local sources = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype == '' and file ~= '' then
      sources[vim.fs.basename(file)] = file
    end
  end
  for row, line in ipairs(state.lines) do
    local file, number = line:match '([^%s%(]+):(%d+)%)?%s*$'
    if file then
      local path = file:sub(1, 1) == '/' and file or root .. '/' .. file
      if not vim.uv.fs_stat(path) then
        path = sources[file]
      end
      if path and vim.uv.fs_stat(path) then
        state.locations[row] = { file = path, line = tonumber(number) }
      end
    end
    for base, path in pairs(sources) do
      local matched = line:match(vim.pesc(base) .. ':(%d+)')
      if matched then
        state.locations[row] = { file = path, line = tonumber(matched) }
        break
      end
    end
  end
end

function M.stop()
  M.generation = M.generation + 1
  M.pending = nil
  if M.build_generation and M.build_generation == RunNowState.generation then
    require('runner').stop_build()
  end
  M.build_generation = nil
  M.running = false
  tasks.stop(kind)
  if tasks.states[kind] then
    message { 'Memory checking stopped', 'Space vR: run again   Space vg: hide/show' }
  end
end

function M.run(args, keep_hidden)
  local runner = require 'runner'
  local buf = runner.source_buffer()
  if not buf then
    return
  end
  local filetype = vim.bo[buf].filetype
  local file = vim.api.nvim_buf_get_name(buf)
  RunNowState.source_buf = buf
  M.stop()
  local generation = M.generation
  args = args or {}
  if not tasks.states[kind] or not keep_hidden then
    tasks.open(kind, { layout = 'right', width = 68 })
  end
  if not runner.save_sources() then
    message { 'Save failed; memory checking was not started.' }
    return
  end
  M.key = signature(buf)
  M.running = true
  message { 'Memory analysis', 'Saving/building the current program...', 'Space vg hides/shows this pane. Space vq cancels.' }
  local uname = vim.uv.os_uname()
  local valgrind = vim.fn.exepath 'valgrind'
  local can_valgrind = valgrind ~= '' and not (uname.sysname == 'Darwin' and uname.machine == 'arm64')
  local function launch(executable, root, metadata)
    if generation ~= M.generation then
      return
    end
    M.build_generation = nil
    local cmd, title, environment
    if can_valgrind then
      cmd = {
        valgrind,
        '--tool=memcheck',
        '--leak-check=full',
        '--show-leak-kinds=all',
        '--track-origins=yes',
        '--num-callers=24',
        '--error-exitcode=97',
        executable,
      }
      title = 'Valgrind Memcheck: leaks, invalid access, undefined values'
    elseif filetype == 'python' then
      cmd = { executable, '-u', vim.fn.stdpath 'config' .. '/scripts/python_allocations.py', root, file }
      title = 'Python allocation analysis (tracemalloc)'
    elseif uname.sysname == 'Darwin' and vim.fn.executable '/usr/bin/leaks' == 1 then
      if metadata and metadata.build_dir then
        local ok, cache = pcall(vim.fn.readfile, metadata.build_dir .. '/CMakeCache.txt')
        if ok and table.concat(cache, '\n'):find('-fsanitize=address', 1, true) then
          M.running = false
          message { 'Choose a Debug preset without ASan for macOS leaks.', 'Space mP: select nvim-debug. Then Space vR to rerun.' }
          return
        end
      end
      cmd = { vim.fn.exepath 'python3', vim.fn.stdpath 'config' .. '/scripts/macos_memcheck.py', executable }
      title = 'macOS leaks — native Valgrind is unavailable on Apple Silicon'
    else
      M.running = false
      message {
        'Valgrind is not installed for this platform.',
        'Install Valgrind in a supported Linux environment and retry Space vR.',
        'https://valgrind.org/info/platforms.html',
      }
      return
    end
    if can_valgrind and filetype == 'python' then
      vim.list_extend(cmd, { '-u', vim.fn.stdpath 'config' .. '/scripts/python_run.py', root, 'file', file })
      environment = { PYTHONMALLOC = 'malloc' }
    end
    vim.list_extend(cmd, args)
    tasks.run(kind, cmd, root, {
      title = title,
      layout = 'right',
      env = environment,
      decorate = function(state)
        decorate(state, root)
      end,
      on_exit = function()
        if generation == M.generation then
          M.running = false
        end
      end,
    })
  end
  if filetype == 'python' then
    local env = require 'custom.python.environment'
    launch(env.python(env.root(buf)), env.root(buf))
  elseif filetype == 'c' or filetype == 'cpp' or filetype == 'cmake' then
    local started = runner.build_executable(launch, function(error)
      if generation == M.generation then
        M.running = false
        M.build_generation = nil
        message { error, 'Space vR: try again' }
      end
    end)
    if started then
      M.build_generation = RunNowState.generation
    end
  else
    M.running = false
    message { 'Open a C, C++ or Python program for memory analysis.' }
  end
end

function M.toggle()
  local state = tasks.states[kind]
  if state and state.buf and #vim.fn.win_findbuf(state.buf) > 0 then
    tasks.close(kind)
    return
  end
  local buf = require('runner').source_buffer()
  if not buf then
    return
  end
  RunNowState.source_buf = buf
  tasks.open(kind, { layout = 'right', width = 68 })
  if not M.running and not M.pending and M.key ~= signature(buf) then
    local generation = M.generation
    M.pending = true
    vim.defer_fn(function()
      if generation ~= M.generation then
        return
      end
      M.pending = nil
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_call(buf, function()
          M.run(nil, true)
        end)
      end
    end, 20)
  end
end
return M
