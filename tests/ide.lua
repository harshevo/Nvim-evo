local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
fixture = vim.uv.fs_realpath(fixture)
local checks = {}
local function pass(name)
  checks[#checks + 1] = name
  print('PASS ' .. name)
end
local function wait_for(fn, label)
  assert(vim.wait(25000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function output()
  return RunNowState.buf and table.concat(vim.api.nvim_buf_get_lines(RunNowState.buf, 0, -1, false), '\n') or ''
end
local function suite()
  vim.fn.writefile({
    'cmake_minimum_required(VERSION 3.20)',
    'project(ide_test LANGUAGES C CXX)',
    'set(CMAKE_CXX_STANDARD 20)',
    'include(CTest)',
    'add_executable(app main.cpp)',
    'add_test(NAME success COMMAND app)',
    'add_executable(failure failure.cpp)',
    'add_test(NAME intentional_failure COMMAND failure)',
    'add_executable(memory_error memory_error.cpp)',
  }, fixture .. '/CMakeLists.txt')
  vim.fn.writefile({ '#include <cstdio>', '#include "value.h"', 'int main(){puts(VALUE);return 0;}' }, fixture .. '/main.cpp')
  vim.fn.writefile({ '#define VALUE "PRESET_DEBUG"' }, fixture .. '/value.h')
  vim.fn.writefile({ '#include <cstdio>', 'int main(){fprintf(stderr,"%s:2:1: error: assertion failed\\n",__FILE__);return 1;}' }, fixture .. '/failure.cpp')
  vim.fn.writefile({ 'int main(){int *p=new int[1];p[2]=7;int v=p[2];delete[] p;return v;}' }, fixture .. '/memory_error.cpp')
  vim.cmd('cd ' .. vim.fn.fnameescape(fixture))
  vim.cmd 'edit main.cpp'
  local source = vim.api.nvim_get_current_buf()
  assert(not package.loaded.dapui and not package.loaded['custom.cpp.testing'] and not package.loaded['custom.cpp.analysis'])
  pass 'Test, analysis and debugger UI stay unloaded at file opening'
  vim.ui.select = function(items, _, callback)
    for _, item in ipairs(items) do
      if item.name == 'app' then
        callback(item)
        return
      end
    end
    callback(items[1])
  end
  local project = require 'custom.cpp.project'
  assert(project.init_presets(fixture))
  local path = fixture .. '/CMakeUserPresets.json'
  local data = project.read(path)
  data.configurePresets[#data.configurePresets + 1] = { name = 'user-existing', generator = 'Ninja', binaryDir = fixture .. '/build/user' }
  vim.fn.writefile({ vim.json.encode(data) }, path)
  assert(project.init_presets(fixture))
  assert(#project.read(path).configurePresets == 5, 'Overwrote existing preset or duplicated generated entries')
  pass 'Presets add Debug/Release/ASan/UBSan while preserving existing user presets'
  local function select(name)
    vim.api.nvim_set_current_buf(source)
    local done, success
    project.choose(name, function(ok)
      success = ok
      done = true
    end)
    wait_for(function()
      return done
    end, 'Preset selection')
    assert(success, vim.inspect(require('custom.cpp.tasks').states.configure))
    assert(project.selected(fixture).preset == name)
    require('custom.cpp.tasks').close 'configure'
    vim.api.nvim_set_current_buf(source)
  end
  select 'nvim-debug'
  vim.cmd 'CppTarget'
  wait_for(function()
    return not RunNowState.build and RunNowState.cmake_targets[fixture] == 'app'
  end, 'Executable picker')
  vim.cmd 'RunBuild'
  wait_for(function()
    return output():find('PRESET_DEBUG', 1, true) and RunNowState.chan == nil
  end, 'Debug preset run')
  local dir = project.build_dir(fixture)
  local cache = table.concat(vim.fn.readfile(dir .. '/CMakeCache.txt'), '\n')
  assert(cache:find('CMAKE_GENERATOR:INTERNAL=Ninja', 1, true), cache)
  assert(cache:match 'CMAKE_CXX_COMPILER_LAUNCHER:[A-Z_]+=ccache', cache)
  wait_for(function()
    local client = vim.lsp.get_clients({ bufnr = source, name = 'clangd' })[1]
    return client and client.config.init_options.compilationDatabasePath == dir
  end, 'clangd preset synchronization: ' .. vim.inspect(vim.tbl_map(function(c)
    return { root = c.config.root_dir, init = c.config.init_options, buffers = c.attached_buffers }
  end, vim.lsp.get_clients { name = 'clangd' })) .. ' selected=' .. vim.inspect(project.selected(fixture)))
  pass 'Selected preset runs Ninja + ccache and updates clangd compilation database'
  local old = vim.uv.fs_stat(fixture .. '/value.h')
  vim.cmd 'RunStop'
  vim.cmd 'edit value.h'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '#define VALUE "NINJA_FRESH_HEADER"' })
  vim.cmd 'write'
  vim.uv.fs_utime(fixture .. '/value.h', old.atime.sec, old.mtime.sec)
  vim.cmd 'edit main.cpp'
  vim.cmd 'RunBuild'
  wait_for(function()
    return output():find('NINJA_FRESH_HEADER', 1, true) and RunNowState.chan == nil
  end, 'Ninja stale header prevention')
  pass 'Ninja rebuilds edited headers even when timestamps do not advance'
  vim.cmd 'RunStop'
  vim.api.nvim_set_current_buf(source)
  local testing = require 'custom.cpp.testing'
  local tasks = require 'custom.cpp.tasks'
  testing.run()
  wait_for(function()
    return tasks.states.test and tasks.states.test.result
  end, 'CTest all')
  assert(tasks.states.test.result.code ~= 0, 'Failing test reported success')
  assert(tasks.states.test.result.stdout:find '50%% tests passed', tasks.states.test.result.stdout)
  local row
  for i, line in ipairs(tasks.states.test.lines) do
    if line:find('failure.cpp:2:1:', 1, true) then
      row = i
    end
  end
  assert(row, vim.inspect(tasks.states.test.lines))
  tasks.open 'test'
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  tasks.jump 'test'
  assert(vim.api.nvim_buf_get_name(0) == fixture .. '/failure.cpp' and vim.api.nvim_win_get_cursor(0)[1] == 2)
  pass 'CTest reports pass/fail and Enter-compatible jumps reach test source'
  tasks.close 'test'
  vim.api.nvim_set_current_buf(source)
  local select_original = vim.ui.select
  vim.ui.select = function(items, _, callback)
    for _, item in ipairs(items) do
      if item.name == 'success' then
        callback(item)
        return
      end
    end
    callback(nil)
  end
  testing.run 'failed'
  wait_for(function()
    return tasks.states.test.result and tasks.states.test.result.code ~= 0
  end, 'Rerun failed test')
  assert(tasks.states.test.result.stdout:find '1/1', tasks.states.test.result.stdout)
  testing.run 'select'
  wait_for(function()
    return tasks.states.test.result and tasks.states.test.result.code == 0
  end, 'Selected CTest success')
  assert(tasks.states.test.result.stdout:find '100%% tests passed')
  testing.run 'last'
  wait_for(function()
    return tasks.states.test.result and tasks.states.test.result.stdout:find '1/1'
  end, 'Last CTest selection')
  vim.ui.select = select_original
  pass 'Test picker and rerun-last execute the selected test'
  tasks.close 'test'
  vim.api.nvim_set_current_buf(source)
  testing.run()
  testing.stop()
  vim.wait(300, function()
    return false
  end)
  assert(not RunNowState.build and not tasks.states.test.process, 'Cancelled test build started a test')
  pass 'Stopping tests cancels the pending build and prevents delayed test execution'
  tasks.close 'test'
  vim.api.nvim_set_current_buf(source)
  select 'nvim-release'
  assert(project.build_dir(fixture):find('nvim-release', 1, true))
  local release = table.concat(vim.fn.readfile(project.build_dir(fixture) .. '/CMakeCache.txt'), '\n')
  assert(release:find('CMAKE_BUILD_TYPE:STRING=Release', 1, true))
  select 'nvim-asan'
  vim.cmd 'RunBuild'
  wait_for(function()
    return output():find('NINJA_FRESH_HEADER', 1, true) and RunNowState.chan == nil
  end, 'ASan build')
  local asan = vim.system({ project.build_dir(fixture) .. '/memory_error' }, { text = true }):wait(15000)
  assert((asan.code ~= 0 or asan.signal ~= 0) and asan.stderr:find('AddressSanitizer', 1, true), vim.inspect(asan))
  pass 'Release and ASan presets work; ASan detects a real heap buffer overflow'
  vim.cmd 'RunStop'
  vim.api.nvim_set_current_buf(source)
  vim.cmd('vsplit ' .. vim.fn.fnameescape(fixture .. '/value.h'))
  local windows = #vim.api.nvim_tabpage_list_wins(0)
  assert(require('custom.cpp.session').save())
  vim.cmd 'only'
  vim.cmd 'edit main.cpp'
  project.remember(fixture, { preset = 'nvim-debug', build_dir = fixture .. '/build/nvim-debug' })
  assert(require('custom.cpp.session').load())
  assert(#vim.api.nvim_tabpage_list_wins(0) == windows)
  assert(project.selected(fixture).preset == 'nvim-asan')
  pass 'Project sessions restore split layout, files and active preset'
  require 'dapui'
  vim.cmd 'CppDebugUI'
  assert(#vim.api.nvim_list_wins() > windows)
  vim.cmd 'CppDebugUI'
  pass 'Debugger layout opens and closes scopes, watches, stack, breakpoints and output'
  assert(vim.fn.maparg('<Space>tt', 'n', false, true).desc)
  assert(vim.fn.maparg('<Space>pp', 'n', false, true).desc)
  assert(vim.fn.exists ':CppCommands' == 2)
  assert(#require('custom.cpp.commands').entries > 20)
  require 'which-key'
  pass 'Shortcut menu, command palette and documented mappings are registered'
  print(('ALL %d IDE CHECKS PASSED'):format(#checks))
end
local ok, err = xpcall(suite, debug.traceback)
if package.loaded['custom.cpp.tasks'] then
  for kind in pairs(require('custom.cpp.tasks').states) do
    require('custom.cpp.tasks').stop(kind)
  end
end
vim.cmd 'RunStop'
vim.fn.delete(fixture, 'rf')
if ok then
  vim.cmd 'qa!'
else
  print(err)
  vim.cmd 'cquit 1'
end
