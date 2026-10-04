local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
dir = vim.uv.fs_realpath(dir) or dir
local memcheck = require 'custom.debug.memcheck'
local tasks = require 'custom.cpp.tasks'
local function wait(fn, label)
  assert(vim.wait(30000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function suite()
  vim.fn.writefile({ 'int main(void) { return 0; }' }, dir .. '/main.c')
  vim.fn.writefile({ 'cmake_minimum_required(VERSION 3.20)', 'project(MemoryTest C)', 'add_executable(memory_app main.c)' }, dir .. '/CMakeLists.txt')
  vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/main.c'))
  vim.cmd 'ValgrindRun'
  wait(function()
    return not memcheck.running
  end, 'CMake memory check stuck')
  local state = tasks.states.valgrind
  assert(table.concat(state.lines, '\n'):find('0 leaks', 1, true), vim.inspect(state.lines))
  print 'PASS CMake builds/selects actual target and runs memory analysis'
  tasks.close 'valgrind'
  vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/CMakeLists.txt'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'cmake_minimum_required(VERSION 3.20)', 'project(MemoryTest C)', 'add_library(memory_lib STATIC main.c)' })
  vim.cmd 'ValgrindRun'
  wait(function()
    return not memcheck.running
  end, 'CMake with no executable stuck')
  assert(table.concat(state.lines, '\n'):find('No executable', 1, true))
  print 'PASS Library-only CMake project reports unavailable executable without a stuck task'
  tasks.close 'valgrind'
  vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/CMakeLists.txt'))
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    { 'cmake_minimum_required(VERSION 3.20)', 'project(MemoryTest C)', 'add_executable(one main.c)', 'add_executable(two main.c)' }
  )
  local old_select = vim.ui.select
  vim.ui.select = function(_, _, callback)
    callback(nil)
  end
  vim.cmd 'ValgrindRun'
  wait(function()
    return not memcheck.running
  end, 'Cancel target picker stuck')
  vim.ui.select = old_select
  assert(table.concat(state.lines, '\n'):find('No executable', 1, true))
  print 'PASS Canceling CMake target selection does not launch a binary or leave task running'
end
local ok, error = xpcall(suite, debug.traceback)
memcheck.stop()
vim.cmd 'RunStop'
vim.fn.delete(dir, 'rf')
if not ok then
  print(error)
end
vim.cmd(ok and 'qa!' or 'cquit 1')
