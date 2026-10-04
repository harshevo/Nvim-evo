local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local function wait(fn, label)
  assert(vim.wait(25000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function content(kind)
  local s = require('custom.cpp.tasks').states[kind]
  return s and table.concat(s.lines, '\n') or ''
end
local function suite()
  local file = dir .. '/views.cpp'
  vim.fn.writefile({ 'int increment(int number)', '{', '  return number + 1;', '}' }, dir .. '/increment.h')
  vim.fn.writefile({
    '#include <cstdio>',
    '#include "increment.h"',
    '',
    '',
    '',
    'int main()',
    '{',
    '  int value = 41;',
    '  value = increment(value);',
    '  printf("VALUE=%d\\n", value);',
    '  return 0;',
    '}',
  }, file)
  vim.cmd('edit ' .. vim.fn.fnameescape(file))
  for _, key in ipairs { '<F5>', '<F6>', '<F9>', '<F10>', '<F11>', '<S-F11>' } do
    assert(vim.fn.maparg(key, 'n') == '', 'Function-key mapping remains: ' .. key)
  end
  assert(vim.fn.maparg(' R', 'n'):find('RunNow', 1, true))
  local dap = require 'dap'
  local stops = 0
  dap.listeners.after.event_stopped.views_test = function()
    stops = stops + 1
  end
  vim.api.nvim_win_set_cursor(0, { 9, 0 })
  vim.cmd 'DebugBreakpoint'
  vim.cmd 'DebugContinue'
  wait(function()
    return dap.session() and dap.session().current_frame and stops > 0
  end, 'No C++ breakpoint')
  local session = dap.session()
  print 'PASS Space commands start the debugger and set a real breakpoint; function-key mappings are removed'
  local views = require 'custom.debug.views'
  views.memory '&value'
  wait(function()
    return content('debug-memory'):find('29 00 00 00', 1, true) ~= nil
  end, 'Memory value 41 not shown: ' .. content 'debug-memory')
  print 'PASS Native memory pane reads actual process bytes for value = 41'
  views.assembly()
  wait(function()
    return content('debug-assembly'):find '0x%x+' and #require('custom.cpp.tasks').states['debug-assembly'].lines > 5
  end, 'No native assembly: ' .. content 'debug-assembly')
  print 'PASS Assembly pane displays real machine instructions from the paused function'
  vim.cmd 'DebugStepInto'
  wait(function()
    return stops >= 2 and session.current_frame and session.current_frame.name:find('increment', 1, true)
  end, 'Step into failed')
  assert(vim.api.nvim_buf_get_name(0):match 'increment.h$', 'Step into did not switch to the other source file')
  assert(#vim.fn.win_findbuf(require('custom.cpp.tasks').states['debug-memory'].buf) == 1, 'Step replaced memory pane')
  vim.cmd 'DebugFrameUp'
  wait(function()
    return session.current_frame.name == 'main'
  end, 'Stack up failed')
  vim.cmd 'DebugFrameDown'
  wait(function()
    return session.current_frame.name:find('increment', 1, true)
  end, 'Stack down failed')
  vim.cmd 'DebugStepOut'
  wait(function()
    return stops >= 3 and session.current_frame and session.current_frame.name == 'main'
  end, 'Step out failed')
  local previous = stops
  vim.cmd 'DebugStepOver'
  wait(function()
    return stops > previous and session.current_frame
  end, 'Step over failed')
  local done, value
  session:request('evaluate', { expression = 'value', frameId = session.current_frame.id, context = 'watch' }, function(error, result)
    assert(not error, vim.inspect(error))
    value = result.result
    done = true
  end)
  wait(function()
    return done
  end, 'Variable evaluation failed')
  assert(value == '42', value)
  print 'PASS Step into/out/over and stack up/down work; value changes to 42'
  views.refresh()
  wait(function()
    return content('debug-memory'):find('2a 00 00 00', 1, true) ~= nil
  end, 'Memory did not refresh after stepping')
  views.memory()
  assert(#vim.fn.win_findbuf(require('custom.cpp.tasks').states['debug-memory'].buf) == 0)
  views.memory()
  assert(#vim.fn.win_findbuf(require('custom.cpp.tasks').states['debug-memory'].buf) == 1)
  vim.cmd 'DebugContinue'
  wait(function()
    return dap.session() == nil
  end, 'Debug session did not finish')
  wait(function()
    return content('debug-memory'):find('ended', 1, true) ~= nil
  end, 'Ended session left stale memory')
  print 'PASS Views toggle, refresh after steps, and clear stale values when the debug session ends'
end
local ok, error = xpcall(suite, debug.traceback)
if not ok then
  print(content 'debug-memory')
  print(content 'debug-assembly')
  print(error)
end
if package.loaded.dap then
  require('dap').terminate()
end
vim.cmd 'RunStop'
vim.fn.delete(dir, 'rf')
vim.cmd(ok and 'qa!' or 'cquit 1')
