local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
local function wait_for(fn, label)
  assert(vim.wait(25000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function suite()
  vim.cmd('edit ' .. vim.fn.fnameescape(fixture .. '/bad.cpp'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'int main()', '{', '  int *p = new int(7);', '  delete p;', '  return *p;', '}' })
  vim.cmd 'CppAnalyze'
  local tasks = require 'custom.cpp.tasks'
  tasks.toggle 'analysis'
  wait_for(function()
    return tasks.states.analysis and tasks.states.analysis.result
  end, 'clang-tidy analysis')
  local s = tasks.states.analysis
  local text = table.concat(s.lines, '\n')
  assert(text:find('Use of memory after it is released', 1, true), text)
  assert(#s.diagnostics > 0, text)
  assert(#vim.fn.win_findbuf(s.buf) == 0, 'Analysis reopened hidden panel')
  vim.cmd 'CppAnalysisQuickfix'
  vim.cmd 'cc 1'
  assert(vim.api.nvim_buf_get_name(0):find('bad.cpp', 1, true))
  vim.cmd 'cclose'
  print 'PASS Background clang-tidy detects use-after-free, stays hidden, and produces jumpable findings'
  tasks.run('cancel-test', { 'python3', '-c', 'import time; time.sleep(1); print("STALE")' }, fixture)
  tasks.run('cancel-test', { 'python3', '-c', 'print("CURRENT")' }, fixture)
  wait_for(function()
    return tasks.states['cancel-test'].result
  end, 'Task cancellation')
  vim.wait(1100, function()
    return false
  end)
  assert(tasks.states['cancel-test'].result.stdout:find('CURRENT', 1, true))
  print 'PASS Cancelled task callbacks cannot replace newer output'

  vim.cmd('edit ' .. vim.fn.fnameescape(fixture .. '/cache.cpp'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '#include <cstdio>', 'int main(){puts("CACHE_TEST");}' })
  vim.env.CCACHE_DIR = fixture .. '/cache'
  local function run()
    vim.cmd 'RunNow'
    wait_for(function()
      return RunNowState.buf
        and not RunNowState.chan
        and table.concat(vim.api.nvim_buf_get_lines(RunNowState.buf, 0, -1, false), '\n'):find('CACHE_TEST', 1, true)
    end, 'Cached file run')
  end
  local before = vim.uv.hrtime()
  run()
  local cold = (vim.uv.hrtime() - before) / 1e6
  before = vim.uv.hrtime()
  run()
  local warm = (vim.uv.hrtime() - before) / 1e6
  local stats = vim.system({ 'ccache', '--print-stats' }, { text = true }):wait()
  local hits = tonumber(stats.stdout:match 'direct_cache_hit%s+(%d+)') or 0
  hits = hits + (tonumber(stats.stdout:match 'preprocessed_cache_hit%s+(%d+)') or 0)
  assert(hits >= 1, stats.stdout)
  print(('PASS Compiler caching records a real cache hit; cold %.1fms, warm %.1fms'):format(cold, warm))
end
local ok, err = xpcall(suite, debug.traceback)
vim.cmd 'RunStop'
vim.fn.delete(fixture, 'rf')
if ok then
  vim.cmd 'qa!'
else
  print(err)
  vim.cmd 'cquit 1'
end
