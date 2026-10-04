local fixture = vim.fn.tempname() .. ' python project'
vim.fn.mkdir(fixture, 'p')
fixture = vim.uv.fs_realpath(fixture) or fixture
local function wait(fn, label)
  assert(vim.wait(30000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function write(name, lines)
  vim.fn.writefile(lines, fixture .. '/' .. name)
end
local function edit(name)
  vim.cmd('edit! ' .. vim.fn.fnameescape(fixture .. '/' .. name))
  return vim.api.nvim_get_current_buf()
end
local function output()
  return RunNowState.buf and vim.api.nvim_buf_is_valid(RunNowState.buf) and table.concat(vim.api.nvim_buf_get_lines(RunNowState.buf, 0, -1, false), '\n') or ''
end
local function task(kind)
  return require('custom.cpp.tasks').states[kind]
end
local function task_done(kind)
  wait(function()
    return task(kind) and task(kind).result ~= nil and task(kind).process == nil
  end, kind .. ' timed out')
  return task(kind)
end
local function request(client, method, params, buf)
  local result, done, error
  client:request(method, params, function(err, value)
    result, error, done = value, err, true
  end, buf)
  wait(function()
    return done
  end, method .. ' timed out')
  assert(not error, vim.inspect(error))
  return result
end
local function suite()
  write('pyproject.toml', { '[tool.ruff]', 'line-length = 88' })
  local result = vim.system({ 'uv', 'venv', '--system-site-packages', '--python', '/usr/local/bin/python3', fixture .. '/.venv' }):wait()
  assert(result.code == 0, result.stderr)
  write('main.py', { 'import sys', 'print("ENV=" + sys.prefix)' })
  local buf = edit 'main.py'
  assert(vim.bo.shiftwidth == 4 and vim.bo.expandtab)
  for _, module in ipairs { 'custom.python.testing', 'custom.python.check', 'custom.python.debug', 'custom.python.docs', 'dap', 'conform', 'telescope' } do
    assert(not package.loaded[module], module .. ' loaded while opening file')
  end
  print 'PASS Python opens with four-space indentation and tools stay unloaded'
  local env = require 'custom.python.environment'
  assert(env.python() == fixture .. '/.venv/bin/python')
  local client
  wait(function()
    client = vim.lsp.get_clients({ bufnr = buf, name = 'pyright' })[1]
    return client and client.initialized and #vim.lsp.get_clients { bufnr = buf, name = 'ruff' } == 1
  end, 'Python language servers did not attach')
  assert(client.config.settings.python.pythonPath == fixture .. '/.venv/bin/python')
  assert(vim.lsp.get_clients({ bufnr = buf, name = 'ruff' })[1].server_capabilities.hoverProvider == false)
  print 'PASS Pyright and Ruff attach with the project environment and one hover provider'
  local site = vim.system({ env.python(), '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))' }, { text = true }):wait().stdout:gsub('%s+$', '')
  vim.fn.writefile({ 'TOKEN = 42' }, site .. '/nvim_ide_env_probe.py')
  write('environment.py', { 'import nvim_ide_env_probe', 'print(nvim_ide_env_probe.TOKEN)' })
  local envbuf = edit 'environment.py'
  wait(function()
    return #vim.lsp.get_clients { bufnr = envbuf, name = 'pyright' } == 1
  end, 'Environment probe did not attach')
  local function missing_probe()
    return vim.iter(vim.diagnostic.get(envbuf)):any(function(diagnostic)
      return diagnostic.message:find('nvim_ide_env_probe', 1, true) and diagnostic.message:find('could not be resolved', 1, true)
    end)
  end
  vim.cmd 'PyEnv /usr/local/bin/python3'
  wait(missing_probe, 'Changing environment did not update actual Pyright imports')
  vim.cmd('PyEnv ' .. vim.fn.fnameescape(fixture .. '/.venv/bin/python'))
  wait(function()
    return not missing_probe()
  end, 'Project import stayed unresolved after selecting its environment')
  assert(env.python() == fixture .. '/.venv/bin/python')
  print 'PASS Switching interpreters updates real import resolution and accepts paths containing spaces'
  edit 'main.py'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'import sys', 'print("FRESH_ENV=" + sys.prefix)' })
  vim.cmd 'RunNow'
  wait(function()
    return output():find('FRESH_ENV=', 1, true) and RunNowState.chan == nil
  end, 'Python run failed')
  assert(output():gsub('\n', ''):find(fixture .. '/.venv', 1, true), output())
  vim.cmd 'RunStop'
  print 'PASS Space R run saves edits and uses the selected project interpreter'

  write('value.py', { 'VALUE = 11' })
  local stamp = math.floor(os.time()) - 10
  vim
    .system({ env.python(), '-c', 'import os,py_compile; p="value.py"; os.utime(p,(' .. stamp .. ',' .. stamp .. ')); py_compile.compile(p)' }, { cwd = fixture })
    :wait()
  write('value.py', { 'VALUE = 22' })
  vim.system({ env.python(), '-c', 'import os; os.utime("value.py",(' .. stamp .. ',' .. stamp .. '))' }, { cwd = fixture }):wait()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'from value import VALUE', 'print("VALUE=" + str(VALUE))' })
  vim.cmd 'RunBuild'
  wait(function()
    return output():find('VALUE=22', 1, true) and RunNowState.chan == nil
  end, 'Stale imported bytecode was used')
  vim.cmd 'RunStop'
  print 'PASS Project run reads fresh imports despite an old bytecode cache with identical timestamps'

  edit 'main.py'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'import sys', 'import os', 'def add(a:int,b:int)->int:', ' return a+b', 'print(add(1,2))' })
  vim.cmd 'write'
  local formatted = table.concat(vim.fn.readfile(fixture .. '/main.py'), '\n')
  assert(formatted:find('import os\nimport sys', 1, true), formatted)
  assert(formatted:find('    return a + b', 1, true), formatted)
  print 'PASS Ruff sorts imports and formats Python on save'

  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    { 'def add(left: int, right: int) -> int:', '    """Add two integers."""', '    return left + right', '', 'answer = add(1, 2)' }
  )
  vim.cmd 'write'
  vim.api.nvim_exec_autocmds('TextChanged', { buffer = buf })
  vim.wait(400)
  local call_line
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find('answer = add', 1, true) then
      call_line = row - 1
    end
  end
  local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = call_line, character = 10 } }
  local hover = request(client, 'textDocument/hover', params, buf)
  assert(vim.inspect(hover):find('Add two integers', 1, true), vim.inspect(hover))
  local defs = request(client, 'textDocument/definition', params, buf)
  assert(#defs > 0, vim.inspect(defs))
  params.position.character = 13
  local sig = request(client, 'textDocument/signatureHelp', params, buf)
  assert(sig and sig.signatures and #sig.signatures > 0, vim.inspect(sig))
  print 'PASS Real Python hover, definitions and function signatures work'

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'def main():', '    DOES_NOT_EXIST', '', 'main()' })
  local check = require 'custom.python.check'
  local start = vim.uv.hrtime()
  vim.cmd 'BuildToggle'
  assert(vim.fn.getqflist({ winid = 0 }).winid ~= 0)
  assert((vim.uv.hrtime() - start) / 1e6 < 200, 'Error pane toggle blocked')
  vim.cmd 'BuildToggle'
  assert(vim.fn.getqflist({ winid = 0 }).winid == 0)
  wait(function()
    return not check.pending and not check.running and #vim.fn.getqflist() > 0
  end, 'Python diagnostics missing')
  assert(vim.fn.getqflist({ winid = 0 }).winid == 0)
  local qf = vim.fn.getqflist()
  assert(
    vim.iter(qf):any(function(item)
      return item.lnum == 2 and item.text:find('DOES_NOT_EXIST', 1, true)
    end),
    vim.inspect(qf)
  )
  vim.cmd 'cfirst'
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
  print 'PASS Space b toggles immediately; background findings remain hidden and jump to the source'

  write('bad_types.py', { 'number: int = "wrong"' })
  edit 'main.py'
  check.explicit 'project'
  wait(function()
    return not check.running
  end, 'Whole project check failed')
  assert(
    vim.iter(vim.fn.getqflist()):any(function(item)
      return item.text:find('Pyright:', 1, true) and vim.api.nvim_buf_get_name(item.bufnr):find('bad_types.py', 1, true)
    end),
    vim.inspect(vim.fn.getqflist())
  )
  vim.cmd 'cclose'
  print 'PASS Whole-project check finds type errors in unopened Python files'

  write('test_sample.py', {
    'import pytest',
    '',
    'def test_pass():',
    '    assert 2 + 2 == 4',
    '',
    '@pytest.mark.parametrize("value", [1, 2])',
    'def test_parameter(value):',
    '    assert value > 0',
    '',
    'def test_fail():',
    '    assert 1 == 2',
  })
  edit 'test_sample.py'
  local testing = require 'custom.python.testing'
  testing.run()
  local tests = task_done 'py-test'
  assert(tests.result.code == 1 and #tests.tests == 4 and #tests.failures == 1, vim.inspect(tests))
  assert(table.concat(tests.lines, '\n'):find('3 passed', 1, true))
  local failrow
  for row, line in ipairs(tests.lines) do
    if line:find('FAILED test_sample.py::test_fail', 1, true) then
      failrow = row
    end
  end
  assert(failrow)
  vim.api.nvim_win_set_cursor(0, { failrow, 0 })
  require('custom.cpp.tasks').jump 'py-test'
  assert(vim.api.nvim_win_get_cursor(0)[1] == 11)
  print 'PASS pytest executes passing/parameterized/failing tests and failure rows jump to the assertion'

  vim.api.nvim_win_set_cursor(0, { 8, 0 })
  testing.run 'nearest'
  wait(function()
    local s = task 'py-test'
    return s.result ~= nil and s.process == nil and table.concat(s.lines, '\n'):find('2 passed', 1, true) ~= nil
  end, 'Nearest parameterized test did not run')
  testing.run 'last'
  tests = task_done 'py-test'
  assert(table.concat(tests.lines, '\n'):find('2 passed', 1, true))
  testing.run 'failed'
  tests = task_done 'py-test'
  assert(tests.result.code == 1 and #tests.failures == 1)
  print 'PASS Nearest, last and failed-test reruns work'

  local select = vim.ui.select
  vim.ui.select = function(values, _, done)
    for _, value in ipairs(values) do
      if value.id and value.id:find('test_pass', 1, true) then
        done(value)
        return
      end
    end
  end
  edit 'test_sample.py'
  testing.run 'select'
  wait(function()
    local s = task 'py-test'
    return s.result ~= nil and s.process == nil and table.concat(s.lines, '\n'):find('1 passed', 1, true) ~= nil
  end, 'Selected pytest did not execute')
  vim.ui.select = select
  testing.run 'select'
  testing.stop()
  wait(function()
    return task('py-collect').process == nil
  end, 'Collection did not stop')
  print 'PASS Test picker executes selections and stopping discovery cancels follow-up work'

  local cache_case = fixture .. '/cache-case'
  vim.fn.mkdir(cache_case, 'p')
  local cached = cache_case .. '/test_fresh.py'
  local stamp = os.time() - 10
  local function cached_test(assertion)
    vim.fn.writefile({ 'def test_value():', '    assert 1 == ' .. assertion }, cached)
    assert(vim.system({ env.python(fixture), '-c', 'import os,sys; os.utime(sys.argv[1],(' .. stamp .. ',' .. stamp .. '))', cached }):wait().code == 0)
    return vim
      .system({ env.python(fixture), vim.fn.stdpath 'config' .. '/scripts/python_pytest.py', cache_case .. '/report.json', '-q' }, { cwd = cache_case })
      :wait()
  end
  assert(cached_test('1').code == 0)
  local changed = cached_test '2'
  assert(changed.code == 1, changed.stdout)
  print 'PASS pytest recompiles changed test assertions even when size and timestamp stay identical'

  edit 'main.py'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'from pathlib import Path', 'Path(".")' })
  vim.cmd 'write'
  require('custom.python.docs').open 'Path'
  local docs = task_done 'py-doc'
  assert(table.concat(docs.lines, '\n'):find('class Path', 1, true), vim.inspect(docs.lines))
  print 'PASS Offline API documentation resolves imported aliases in the selected environment'

  edit 'main.py'
  vim.cmd 'only'
  vim.cmd 'vsplit'
  local session = require 'custom.python.session'
  env.remember(fixture, fixture .. '/.venv/bin/python')
  assert(session.save())
  local wins = #vim.api.nvim_tabpage_list_wins(0)
  vim.cmd 'only'
  env.remember(fixture, '/usr/local/bin/python3')
  assert(session.load())
  assert(#vim.api.nvim_tabpage_list_wins(0) == wins, 'Split count not restored')
  assert(env.python(fixture) == fixture .. '/.venv/bin/python', 'Interpreter not restored: ' .. env.python(fixture))
  print 'PASS Python sessions restore files, split layout and interpreter'
  assert(#require('custom.python.commands').entries >= 25)
  print 'ALL 15 PYTHON CHECKS PASSED'
end
local ok, error = xpcall(suite, debug.traceback)
if package.loaded['custom.python.testing'] then
  require('custom.python.testing').stop()
end
if package.loaded['custom.python.check'] then
  require('custom.python.check').stop()
end
vim.cmd 'RunStop'
vim.fn.delete(fixture, 'rf')
if ok then
  vim.cmd 'qa!'
else
  print(error)
  vim.cmd 'cquit 1'
end
