local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
local function wait_for(fn, label)
  assert(vim.wait(20000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function suite()
  local file = fixture .. '/debug.cpp'
  if vim.env.CPP_TEST_CMAKE == '1' then
    vim.fn.writefile(
      { 'cmake_minimum_required(VERSION 3.16)', 'project(DebugTest LANGUAGES CXX)', 'add_executable(debug_test debug.cpp)' },
      fixture .. '/CMakeLists.txt'
    )
  end
  vim.fn.writefile(
    { '#include <cstdio>', 'int main()', '{', '  int value = 41;', '  value += 1;', '  printf("VALUE=%d\\n", value);', '  return 0;', '}' },
    file
  )
  vim.cmd('edit ' .. vim.fn.fnameescape(file))
  local dap = require 'dap'
  dap.set_log_level 'DEBUG'
  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  dap.toggle_breakpoint()
  local stops = 0
  dap.listeners.after.event_stopped.cpp_test = function()
    stops = stops + 1
  end
  vim.cmd 'CppDebug'
  wait_for(function()
    return dap.session() and dap.session().current_frame and stops > 0
  end, 'Breakpoint not hit')
  local session = dap.session()
  assert(session.current_frame.line == 5, vim.inspect(session.current_frame))
  print 'PASS Save/build/debug hits source breakpoint'
  local function evaluate()
    local done, value
    session:request('evaluate', { expression = 'value', frameId = session.current_frame.id, context = 'watch' }, function(err, result)
      assert(not err, vim.inspect(err))
      value = result.result
      done = true
    end)
    wait_for(function()
      return done
    end, 'Evaluate timeout')
    return value
  end
  assert(evaluate() == '41')
  print 'PASS LLDB reads local variable value = 41'
  dap.step_over()
  wait_for(function()
    return stops == 2 and session.current_frame and session.current_frame.line == 6
  end, 'Step over did not advance')
  assert(evaluate() == '42')
  print 'PASS Step over advances line and updates variable to 42'
  dap.continue()
  wait_for(function()
    return dap.session() == nil
  end, 'Debug session did not finish')
  print 'ALL DEBUG CHECKS PASSED'
end
local ok, err = xpcall(suite, debug.traceback)
if not ok then
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buftype == 'terminal' then
      print(vim.api.nvim_buf_get_name(b), vim.inspect(vim.api.nvim_buf_get_lines(b, 0, -1, false)))
    end
  end
end
if package.loaded.dap then
  require('dap').terminate()
end
vim.cmd 'RunStop'
vim.fn.delete(fixture, 'rf')
if ok then
  vim.cmd 'qa!'
else
  print(err)
  vim.cmd 'cquit 1'
end
