local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
dir = vim.uv.fs_realpath(dir) or dir
local tasks = require 'custom.cpp.tasks'
local memcheck = require 'custom.debug.memcheck'
local function output()
  return table.concat(tasks.states.valgrind.lines, '\n')
end
local function wait(fn, label)
  assert(vim.wait(30000, fn, 20), label .. '\n' .. output() .. '\n' .. vim.fn.execute 'messages')
end
local function edit(file, lines)
  vim.cmd('edit! ' .. vim.fn.fnameescape(file))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  return vim.api.nvim_get_current_buf()
end
local function suite()
  local file = dir .. '/leak.c'
  local source = edit(file, {
    '#include <stdlib.h>',
    '#include <string.h>',
    '#include <unistd.h>',
    'void *volatile sink;',
    '__attribute__((noinline)) void leak(void)',
    '{',
    '  for (int i=0;i<100;i++) { sink=malloc(4096); memset(sink, 42, 4096); }',
    '  sink=NULL;',
    '}',
    'int main(void) { leak(); sleep(1); return 0; }',
  })
  vim.cmd 'ValgrindToggle'
  local s = tasks.states.valgrind
  local win = vim.fn.win_findbuf(s.buf)[1]
  assert(win and vim.api.nvim_win_get_position(win)[2] > 0, 'Not on the right')
  vim.cmd 'ValgrindToggle'
  vim.cmd 'ValgrindToggle'
  wait(function()
    return memcheck.running
  end, 'Did not begin')
  vim.cmd 'ValgrindToggle'
  wait(function()
    return not memcheck.running and s.result ~= nil
  end, 'Memory check did not finish')
  assert(output():find('100 leaks', 1, true), output())
  assert(output():find('macOS leaks', 1, true))
  assert(#vim.fn.win_findbuf(s.buf) == 0, 'Hidden pane reopened after completion')
  assert(not vim.bo[source].modified, 'Unsaved source not saved')
  print 'PASS Right sidebar checks freshly built unsaved source; detects 100 leaks and stays hidden after completion'
  local generation = memcheck.generation
  vim.cmd 'ValgrindToggle'
  vim.wait(80, function()
    return false
  end)
  assert(memcheck.generation == generation and not memcheck.running, 'Cached toggle reran checks')
  local row
  for index, location in pairs(s.locations or {}) do
    if location.file == file then
      row = index
      break
    end
  end
  assert(row, 'No source location parsed: ' .. vim.inspect(s.locations) .. '\n' .. output())
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  tasks.jump 'valgrind'
  assert(vim.api.nvim_buf_get_name(0) == file, 'Source jump failed')
  print 'PASS Reopening cached report is immediate and leak source frames are jumpable'
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { 'int main(void) { BROKEN_SOURCE }' })
  vim.cmd 'ValgrindRun'
  wait(function()
    return not memcheck.running
  end, 'Failed build stuck')
  assert(not output():find('100 leaks', 1, true), 'Stale report survived failed build')
  assert(#vim.fn.getqflist() > 0, 'Missing compile errors')
  print 'PASS Failed compilation does not analyze an old binary or show old leak results'
  tasks.close 'valgrind'
  vim.api.nvim_set_current_buf(source)
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { 'int main(void) { return 0; }' })
  vim.cmd 'ValgrindToggle'
  vim.cmd 'ValgrindStop'
  generation = memcheck.generation
  vim.wait(100, function()
    return false
  end)
  assert(memcheck.generation == generation and not memcheck.running and not s.process, 'Deferred run survived cancel')
  print 'PASS Cancel prevents delayed runs from starting'
  tasks.close 'valgrind'
  vim.api.nvim_set_current_buf(source)
  vim.cmd 'write'
  edit(dir .. '/memory.py', { 'payload = [bytearray(4096) for _ in range(100)]', 'print("PY_MEMORY_RAN")' })
  vim.cmd 'ValgrindRun'
  wait(function()
    return not memcheck.running
  end, 'Python memory check did not finish')
  assert(output():find('PY_MEMORY_RAN', 1, true) and output():find('tracemalloc', 1, true), output())
  assert(output():find('Peak traced memory', 1, true))
  print 'PASS Python runs fresh code and displays a clearly labeled allocation report'
  tasks.close 'valgrind'
  edit(file, { '#include <unistd.h>', 'int main(void) { sleep(60); return 0; }' })
  vim.cmd 'ValgrindRun'
  local binary_dir = vim.fn.stdpath 'cache' .. '/runner/' .. vim.fn.sha256(file):sub(1, 24)
  wait(function()
    return #vim.fn.glob(binary_dir .. '/.nvim-leaks-*', false, true) > 0
  end, 'Checker copy was not created')
  vim.cmd 'ValgrindStop'
  wait(function()
    return #vim.fn.glob(binary_dir .. '/.nvim-leaks-*', false, true) == 0
  end, 'Canceled checker left a temporary executable')
  assert(not memcheck.running and not s.process)
  print 'PASS Canceling a running native check stops the process and removes its temporary executable'
end
local ok, error = xpcall(suite, debug.traceback)
memcheck.stop()
vim.cmd 'RunStop'
vim.fn.delete(dir, 'rf')
if not ok then
  print(error)
end
vim.cmd(ok and 'qa!' or 'cquit 1')
