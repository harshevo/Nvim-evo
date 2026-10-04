local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, 'p')
local checks = {}
local function passed(name)
  checks[#checks + 1] = name
  print('PASS ' .. name)
end
local function wait_for(fn, label)
  assert(vim.wait(15000, fn, 20), label .. '\n' .. vim.fn.execute 'messages')
end
local function edit(name, lines)
  local path = fixture .. '/' .. name
  if lines then
    vim.fn.writefile(lines, path)
  end
  vim.cmd('edit! ' .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end
local function suite()
  local buf = edit('main.cpp', {
    '#include <cstdio>',
    '/// Adds two integers.',
    'int add(int left, int right) { return left + right; }',
    'int main() { int value = add(3, 4); printf("%d\\n", value); return 0; }',
  })
  assert(not package.loaded.dap, 'Debugger loaded at C++ startup')
  wait_for(function()
    return (vim.lsp.get_clients({ bufnr = buf, name = 'clangd' })[1] or {}).initialized
  end, 'clangd startup')
  local client = vim.lsp.get_clients({ bufnr = buf, name = 'clangd' })[1]
  local function request(method, line, character, extra)
    local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = line, character = character } }
    for k, v in pairs(extra or {}) do
      params[k] = v
    end
    local response, err = client:request_sync(method, params, 10000, buf)
    assert(response and not response.err, vim.inspect(err or response))
    return response.result
  end
  local hover = request('textDocument/hover', 2, 5)
  assert(vim.inspect(hover):find('int add', 1, true) and vim.inspect(hover):find('Adds two integers', 1, true), vim.inspect(hover))
  local signature = request('textDocument/signatureHelp', 3, 31)
  assert(signature and #signature.signatures > 0, vim.inspect(signature))
  local definition = request('textDocument/definition', 3, 26)
  assert(definition and #definition > 0, vim.inspect(definition))
  local completion = request('textDocument/completion', 3, 27, { context = { triggerKind = 1 } })
  assert(vim.inspect(completion):find('add', 1, true), vim.inspect(completion))
  passed 'Real clangd returns completion, signatures, documentation and definitions'
  vim.api.nvim_win_set_cursor(0, { 3, 5 })
  vim.fn.maparg('K', 'n', false, true).callback()
  wait_for(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), '\n')
        if text:find('int add', 1, true) then
          vim.api.nvim_win_close(win, true)
          return true
        end
      end
    end
  end, 'K hover float')
  passed 'K opens the actual signature/documentation float'
  vim.fn.writefile({ 'BasedOnStyle: Google', 'BreakBeforeBraces: Attach' }, fixture .. '/.clang-format')
  vim.cmd 'write'
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  assert(text:find('int add(int left, int right)\n{', 1, true), text)
  assert(text:find('int main()\n{', 1, true), text)
  passed 'Save formats C++ with Allman braces, including conflicting project styles'

  buf = edit('standard.cpp', {
    '#include <span>',
    '#include <concepts>',
    'template <std::integral T> T twice(T v) { return v + v; }',
    'int main() { int a[2] = {1,2}; std::span<int> s(a); return twice(s[0]); }',
  })
  wait_for(function()
    return #vim.lsp.get_clients { bufnr = buf, name = 'clangd' } > 0
  end, 'second file attachment')
  client = vim.lsp.get_clients({ bufnr = buf, name = 'clangd' })[1]
  local types = request('textDocument/hover', 2, 31)
  assert(types, 'C++20 hover missing')
  wait_for(function()
    return #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) == 0
  end, 'C++20 diagnostics did not clear')
  passed 'Standalone clangd understands C++20 and SDK standard headers'

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'int main()', '{', '  UNKNOWN_SYMBOL;', '}' })
  local before = vim.uv.hrtime()
  vim.cmd 'BuildToggle'
  local elapsed = (vim.uv.hrtime() - before) / 1e6
  assert(vim.bo.filetype == 'qf', 'No immediate quickfix split')
  assert(elapsed < 100, 'Slow pane: ' .. elapsed .. 'ms')
  vim.cmd 'BuildToggle'
  assert(vim.fn.getqflist({ winid = 0 }).winid == 0)
  wait_for(function()
    return not _G.RunNowState.check_pending and not _G.RunNowState.build and #vim.fn.getqflist() > 0
  end, 'background syntax check')
  assert(vim.fn.getqflist({ winid = 0 }).winid == 0, 'Finished check reopened hidden pane')
  local errors = vim.fn.getqflist()
  assert(errors[1].valid == 1 and errors[1].lnum == 3, vim.inspect(errors))
  local generation = _G.RunNowState.generation
  vim.cmd 'BuildToggle'
  vim.wait(50, function()
    return false
  end)
  assert(_G.RunNowState.generation == generation, 'Instant reopen rebuilt unchanged source')
  vim.cmd 'cc 1'
  assert(vim.api.nvim_get_current_buf() == buf and vim.api.nvim_win_get_cursor(0)[1] == 3)
  vim.cmd 'cclose'
  passed(('Error pane opens in %.1fms, toggles instantly, stays hidden and jumps to errors'):format(elapsed))

  buf = edit('library.h', { '#ifndef LIBRARY_H', '#define LIBRARY_H', 'int library_function(int value);', '#endif' })
  vim.bo.filetype = 'c'
  vim.cmd 'BuildToggle'
  wait_for(function()
    return not _G.RunNowState.check_pending and not _G.RunNowState.build
  end, 'C header syntax check')
  assert(#vim.fn.getqflist() == 0, vim.inspect(vim.fn.getqflist()))
  vim.cmd 'cclose'
  passed 'C headers check without requiring a main function or linking'

  local project = fixture .. '/project'
  vim.fn.mkdir(project .. '/out/Debug', 'p')
  vim.fn.writefile({ 'cmake_minimum_required(VERSION 3.16)', 'project(CompileFlags)' }, project .. '/CMakeLists.txt')
  local project_file = project .. '/project.cpp'
  vim.fn.writefile({ '#if __cplusplus != 201703L', '#error Project must use C++17', '#endif', 'int main() { return PROJECT_VALUE; }' }, project_file)
  local actual_project = vim.uv.fs_realpath(project)
  local commands = {
    {
      directory = actual_project,
      file = actual_project .. '/project.cpp',
      arguments = { 'clang++', '-std=c++17', '-DPROJECT_VALUE=0', '-c', actual_project .. '/project.cpp' },
    },
  }
  vim.fn.writefile({ vim.json.encode(commands) }, project .. '/out/Debug/compile_commands.json')
  vim.cmd('edit ' .. vim.fn.fnameescape(project_file))
  buf = vim.api.nvim_get_current_buf()
  wait_for(function()
    return (vim.lsp.get_clients({ bufnr = buf, name = 'clangd' })[1] or {}).initialized
  end, 'project clangd')
  client = vim.lsp.get_clients({ bufnr = buf, name = 'clangd' })[1]
  assert(client.config.init_options.compilationDatabasePath == actual_project .. '/out/Debug')
  local macro = request('textDocument/hover', 3, 22)
  assert(vim.inspect(macro):find('PROJECT_VALUE 0', 1, true), vim.inspect(macro))
  assert(#vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) == 0, vim.inspect(vim.diagnostic.get(buf)))
  passed 'Project database in out/Debug preserves C++17 and compiler definitions'

  vim.cmd 'CppMan printf'
  wait_for(function()
    return vim.bo.filetype == 'man'
  end, 'printf manual')
  local manual = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(manual:find('SYNOPSIS', 1, true) and manual:find('printf', 1, true), manual)
  passed 'Installed printf(3) manual opens with synopsis'
  print(('ALL %d C/C++ CHECKS PASSED'):format(#checks))
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
