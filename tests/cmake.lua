local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile({
  'cmake_minimum_required(VERSION 3.20)',
  'project(runner_test LANGUAGES CXX)',
  'set(CMAKE_CXX_STANDARD 20)',
  'add_executable(runner_test main.cpp)',
  'add_executable(other_target other.cpp)',
}, root .. '/CMakeLists.txt')
vim.fn.writefile({ '#include <cstdio>', 'int main(){ puts("OTHER_TARGET"); }' }, root .. '/other.cpp')
vim.fn.writefile({ '#define VALUE "CMAKE_OLD"' }, root .. '/values.h')
vim.fn.writefile({ '#include <cstdio>', '#include "values.h"', 'int main(){ puts(VALUE); }' }, root .. '/main.cpp')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
vim.ui.select = function(items, opts, callback)
  for i, item in ipairs(items) do
    if item.name == 'runner_test' then
      callback(item, i)
      return
    end
  end
  callback(items[1], 1)
end
local function output()
  return RunNowState.buf and table.concat(vim.api.nvim_buf_get_lines(RunNowState.buf, 0, -1, false), '\n') or ''
end
local function run(marker)
  vim.cmd 'RunBuild'
  assert(
    vim.wait(15000, function()
      return output():find(marker, 1, true) ~= nil and RunNowState.chan == nil
    end, 25),
    'CMake missing ' .. marker .. '\n' .. vim.fn.execute 'messages'
  )
end
local function suite()
  vim.cmd 'edit values.h'
  local header = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(header, 0, -1, false, { '#define VALUE "CMAKE_NEW"' })
  vim.cmd 'edit main.cpp'
  local source = vim.api.nvim_get_current_buf()
  run 'CMAKE_NEW'
  print 'PASS Fresh CMake configures, builds and selects executable; saves modified header'
  vim.api.nvim_buf_set_lines(header, 0, -1, false, { '#define VALUE "CMAKE_UPDATED"' })
  run 'CMAKE_UPDATED'
  assert(not output():find('CMAKE_NEW', 1, true))
  print 'PASS CMake rerun rebuilds edited header and replaces previous output'
  local header_path = vim.api.nvim_buf_get_name(header)
  local old_stat = vim.uv.fs_stat(header_path)
  vim.api.nvim_buf_set_lines(header, 0, -1, false, { '#define VALUE "CMAKE_DIRECT"' })
  vim.api.nvim_buf_call(header, function()
    vim.cmd 'write'
  end)
  vim.uv.fs_utime(header_path, old_stat.atime.sec, old_stat.mtime.sec)
  vim.cmd 'edit CMakeLists.txt'
  vim.cmd 'CMakeRun'
  assert(
    vim.wait(15000, function()
      return output():find('CMAKE_DIRECT', 1, true) ~= nil and RunNowState.chan == nil
    end, 25),
    vim.inspect(RunNowState) .. '\n' .. output() .. '\n' .. vim.fn.execute 'messages'
  )
  print 'PASS Direct CMakeRun from CMakeLists saves header, builds and runs'
  vim.cmd 'edit main.cpp'
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { 'int main(){SYNTAX_ERROR}' })
  vim.cmd 'RunBuild'
  assert(vim.wait(15000, function()
    return RunNowState.build == nil and #vim.fn.getqflist() > 0
  end, 25))
  assert(not RunNowState.buf)
  print 'PASS Failed CMake build does not execute old target'
  print 'ALL 4 CMAKE CHECKS PASSED'
end
local ok, err = xpcall(suite, debug.traceback)
vim.fn.delete(root, 'rf')
if not ok then
  print(err)
  vim.cmd 'cquit 1'
else
  vim.cmd 'qa!'
end
