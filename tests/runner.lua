local config_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.rtp:prepend(config_dir)
vim.g.mapleader = ' '
if vim.fn.exists ':RunNow' == 0 then
  require 'runner'
end
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
local checks = {}
local function passed(name)
  checks[#checks + 1] = name
  print('PASS ' .. name)
end
local function edit(path, lines)
  vim.cmd 'stopinsert'
  vim.cmd('edit! ' .. vim.fn.fnameescape(path))
  if lines then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
  return vim.api.nvim_get_current_buf()
end
local function output()
  local b = _G.RunNowState.buf
  return b and vim.api.nvim_buf_is_valid(b) and table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), '\n') or ''
end
local function wait_for(predicate, label)
  assert(vim.wait(12000, predicate, 20), label .. '\n' .. output() .. '\n' .. vim.fn.execute 'messages')
end
local function run_until(command, marker)
  vim.cmd(command)
  wait_for(function()
    return output():find(marker, 1, true) ~= nil and _G.RunNowState.chan == nil
  end, command .. ' missing ' .. marker)
end
local function cpp(marker)
  return { '#include <cstdio>', 'int main(){puts("' .. marker .. '");}' }
end
local function suite()
  local file = fixture .. '/main.cpp'
  local source = edit(file, cpp 'FIRST_VALUE')
  run_until('RunNow', 'FIRST_VALUE')
  assert(table.concat(vim.fn.readfile(file), '\n'):find('FIRST_VALUE', 1, true))
  assert(vim.bo.buftype == 'terminal', 'Runner must leave output focused')
  passed 'Space R path saves and compiles modified C++'

  vim.api.nvim_buf_set_lines(source, 0, -1, false, cpp 'SECOND_VALUE')
  run_until('RunBuild', 'SECOND_VALUE') -- triggered from previous output
  assert(not output():find('FIRST_VALUE', 1, true), 'Old output leaked')
  passed 'Project rerun from terminal rebuilds unsaved changes and replaces output'

  vim.api.nvim_buf_set_lines(source, 0, -1, false, { 'int main(){SYNTAX_ERROR}' })
  vim.cmd 'RunBuild'
  wait_for(function()
    return _G.RunNowState.build == nil and #vim.fn.getqflist() > 0
  end, 'No compile errors')
  assert(not _G.RunNowState.buf, 'Failed compile ran stale binary')
  assert(vim.fn.getqflist()[1].valid == 1, 'Compiler error must be jumpable')
  passed 'Failed project compile opens quickfix and never runs old binary'

  edit(file, cpp 'FILE_FAILURE_BASE')
  run_until('RunNow', 'FILE_FAILURE_BASE')
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { 'int main(){SYNTAX_ERROR}' })
  vim.cmd 'RunNow'
  wait_for(function()
    return _G.RunNowState.chan == nil and output():find('error:', 1, true) ~= nil
  end, 'No file compile error')
  assert(not output():find('FILE_FAILURE_BASE', 1, true))
  passed 'Failed Space R compile shows fresh error output without old program'

  local other_dir = fixture .. "/same name with space'quote"
  vim.fn.mkdir(other_dir, 'p')
  edit(other_dir .. '/main.cpp', cpp 'OTHER_PROJECT')
  run_until('RunBuild', 'OTHER_PROJECT')
  edit(file, cpp 'ORIGINAL_PROJECT')
  run_until('RunBuild', 'ORIGINAL_PROJECT')
  local first_binary = vim.fn.stdpath 'cache' .. '/runner/' .. vim.fn.sha256(file):sub(1, 24) .. '/program'
  local second_binary = vim.fn.stdpath 'cache' .. '/runner/' .. vim.fn.sha256(other_dir .. '/main.cpp'):sub(1, 24) .. '/program'
  assert(vim.fn.executable(first_binary) == 1 and vim.fn.executable(second_binary) == 1)
  passed 'Same-basename files and paths containing spaces/quotes are isolated'

  local inputfile = fixture .. '/input.cpp'
  local inputbuf =
    edit(inputfile, { '#include <cstdio>', 'int main(){ char c; puts("WAITING_INPUT"); fflush(stdout); scanf(" %c", &c); printf("INPUT_%c\\n",c); }' })
  vim.cmd 'RunNow'
  wait_for(function()
    return output():find('WAITING_INPUT', 1, true) ~= nil
  end, 'No interactive prompt')
  local old_chan = _G.RunNowState.chan
  vim.api.nvim_buf_set_lines(inputbuf, 0, -1, false, cpp 'RERUN_AFTER_INPUT')
  run_until('RunNow', 'RERUN_AFTER_INPUT')
  assert(vim.fn.jobwait({ old_chan }, 0)[1] ~= -1, 'Old program still running')
  passed 'Rerun while stdin waits stops old job and starts fresh compilation'

  edit(inputfile, { '#include <cstdio>', 'int main(){ char c; scanf(" %c", &c); printf("INPUT_%c\\n",c); }' })
  vim.cmd 'RunNow'
  local chan = _G.RunNowState.chan
  vim.api.nvim_chan_send(chan, 'H\n')
  wait_for(function()
    return output():find('INPUT_H', 1, true) ~= nil and _G.RunNowState.chan == nil
  end, 'Input H intercepted')
  assert(vim.fn.maparg('H', 't') == '', 'H cannot close terminal in input mode')
  passed 'Interactive stdin accepts capital H'

  local relative = fixture .. '/relative.py'
  vim.fn.writefile({ 'LOCAL_DATA' }, fixture .. '/data.txt')
  edit(relative, { 'from pathlib import Path', 'print(Path("data.txt").read_text().strip())' })
  run_until('RunNow', 'LOCAL_DATA')
  passed 'File runs from its own directory for relative resources'

  edit(fixture .. '/arguments.py', { 'import sys', 'print("ARG=" + sys.argv[1])' })
  run_until([[RunNow 'hello world']], 'ARG=hello world')
  passed 'RunNow passes optional arguments without blocking prompt'

  local make_dir = fixture .. '/make-project'
  vim.fn.mkdir(make_dir, 'p')
  vim.fn.writefile({ 'all: app', 'app: main.cpp values.h', '\tclang++ -std=c++20 main.cpp -o app', 'run: app', '\t./app' }, make_dir .. '/Makefile')
  vim.fn.writefile({ '#define VALUE "MAKE_OLD"' }, make_dir .. '/values.h')
  vim.fn.writefile({ '#include <cstdio>', '#include "values.h"', 'int main(){puts(VALUE);}' }, make_dir .. '/main.cpp')
  local header = edit(make_dir .. '/values.h', { '#define VALUE "MAKE_NEW"' })
  edit(make_dir .. '/main.cpp')
  run_until('RunBuild', 'MAKE_NEW')
  assert(not vim.bo[header].modified)
  passed 'Make project rebuild saves modified headers in other buffers'

  local header_path = make_dir .. '/values.h'
  local old_stat = vim.uv.fs_stat(header_path)
  vim.api.nvim_buf_set_lines(header, 0, -1, false, { '#define VALUE "MAKE_COARSE_TIMESTAMP"' })
  vim.api.nvim_buf_call(header, function()
    vim.cmd 'write'
  end)
  vim.uv.fs_utime(header_path, old_stat.atime.sec, old_stat.mtime.sec)
  run_until('RunBuild', 'MAKE_COARSE_TIMESTAMP')
  passed 'Make rebuilds saved header even when timestamp does not advance'

  vim.cmd 'RunStop'
  edit(file, cpp 'CANCEL_TEST')
  vim.cmd [[BuildNow sleep 1; echo 'main.cpp:1:1: error: STALE_BUILD']]
  vim.cmd [[BuildNow true]]
  wait_for(function()
    return _G.RunNowState.build == nil
  end, 'Build cancellation timeout')
  vim.wait(1300, function()
    return false
  end)
  assert(#vim.fn.getqflist() == 0, 'Canceled build overwrote quickfix')
  passed 'Late canceled build cannot overwrite newer results'

  edit(file, cpp 'READONLY_OLD')
  run_until('RunBuild', 'READONLY_OLD')
  edit(file, cpp 'READONLY_NEW')
  vim.bo.readonly = true
  local old_generation = _G.RunNowState.generation
  pcall(vim.cmd, 'RunBuild')
  assert(_G.RunNowState.generation == old_generation, 'Started build despite failed save')
  assert(vim.bo.modified, 'Read-only edit unexpectedly saved')
  vim.bo.readonly = false
  vim.cmd 'RunStop'
  passed 'Save failures abort build/run'

  edit(fixture .. '/plain.c', { '#include <stdio.h>', 'int main(void){ puts("C_OK"); return 0; }' })
  run_until('RunBuild', 'C_OK')
  passed 'C17 file saves, builds and runs'

  vim.cmd 'RunStop'
  vim.fn.writefile(checks, fixture .. '/runner-test-results.txt')
  print(('ALL %d RUNNER CHECKS PASSED'):format(#checks))
end
local ok, err = xpcall(suite, debug.traceback)
vim.fn.delete(fixture, 'rf')
if not ok then
  print(err)
  vim.cmd 'cquit 1'
else
  vim.cmd 'qa!'
end
