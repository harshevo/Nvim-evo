local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
fixture = vim.uv.fs_realpath(fixture) or fixture
local function wait(fn, label)
  assert(vim.wait(30000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function suite()
  assert(vim.system({ 'uv', 'venv', '--python', '/usr/local/bin/python3', fixture .. '/.venv' }):wait().code == 0)
  vim.fn.writefile({ '[tool.ruff]', 'line-length = 88' }, fixture .. '/pyproject.toml')
  vim.fn.writefile({ 'import sys', 'prefix = sys.prefix', 'value = 41', 'value += 1', 'print(value)' }, fixture .. '/debug.py')
  vim.cmd('edit ' .. vim.fn.fnameescape(fixture .. '/debug.py'))
  local dap = require 'dap'
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  dap.toggle_breakpoint()
  local stops = 0
  dap.listeners.after.event_stopped.python_test = function()
    stops = stops + 1
  end
  vim.cmd 'DebugContinue'
  wait(function()
    return dap.session() and dap.session().current_frame and stops > 0
  end, 'Python breakpoint was not hit')
  local session = dap.session()
  assert(session.current_frame.line == 4, vim.inspect(session.current_frame))
  local function evaluate(expression)
    local result, done
    session:request('evaluate', { expression = expression, frameId = session.current_frame.id, context = 'watch' }, function(error, value)
      assert(not error, vim.inspect(error))
      result, done = value.result, true
    end)
    wait(function()
      return done
    end, 'Python evaluation timed out')
    return result
  end
  assert(evaluate('prefix'):find(fixture .. '/.venv', 1, true))
  assert(evaluate 'value' == '41')
  print 'PASS debugpy hits a real source breakpoint using a bare project venv without installing debugpy into it'
  vim.cmd 'DebugStepOver'
  wait(function()
    return stops == 2 and session.current_frame and session.current_frame.line == 5
  end, 'Python step did not advance')
  assert(evaluate 'value' == '42')
  print 'PASS Python stepping and variable evaluation update 41 to 42'
  local views = require 'custom.debug.views'
  local tasks = require 'custom.cpp.tasks'
  views.memory 'value'
  wait(function()
    local state = tasks.states['debug-memory']
    return state and table.concat(state.lines, '\n'):find('Shallow object size', 1, true)
  end, 'Python object memory view failed')
  assert(table.concat(tasks.states['debug-memory'].lines, '\n'):find('42', 1, true))
  views.assembly()
  wait(function()
    local state = tasks.states['debug-assembly']
    return state and state.result ~= nil
  end, 'Python bytecode failed')
  assert(table.concat(tasks.states['debug-assembly'].lines, '\n'):find('LOAD_', 1, true))
  views.memory()
  views.assembly()
  print 'PASS Python object memory and saved-source bytecode inspection work'
  vim.cmd 'CppDebugUI'
  assert(#vim.api.nvim_tabpage_list_wins(0) >= 5)
  vim.cmd 'CppDebugUI'
  dap.continue()
  wait(function()
    return dap.session() == nil
  end, 'Python debugger did not finish')
  print 'PASS Python debugger panels toggle and the process exits normally'
  print 'ALL PYTHON DEBUG CHECKS PASSED'
end
local ok, error = xpcall(suite, debug.traceback)
if package.loaded.dap then
  require('dap').terminate()
end
if not ok then
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then
      print(vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
    end
  end
  print(error)
end
vim.fn.delete(fixture, 'rf')
vim.cmd(ok and 'qa!' or 'cquit 1')
