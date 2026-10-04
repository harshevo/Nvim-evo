local M = {}
local function executable()
  for _, name in ipairs { 'clang-tidy', '/opt/homebrew/opt/llvm/bin/clang-tidy', '/usr/local/opt/llvm/bin/clang-tidy' } do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
end
function M.run()
  local runner = require 'runner'
  local buf = runner.source_buffer()
  if not buf or not runner.save_sources() then
    return
  end
  local tidy = executable()
  if not tidy then
    vim.notify('clang-tidy is unavailable; install LLVM or the Mason clang-tidy package', vim.log.levels.ERROR)
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  local root = require('custom.cpp.project').root(buf)
  local dir = require('custom.cpp.project').build_dir(root)
  local cmd = { tidy, file, '--quiet' }
  if not vim.fs.find('.clang-tidy', { path = vim.fs.dirname(file), upward = true })[1] then
    cmd[#cmd + 1] = '--checks=clang-analyzer-*,bugprone-*,performance-*'
  end
  if vim.uv.fs_stat(dir .. '/compile_commands.json') then
    vim.list_extend(cmd, { '-p', dir })
  elseif vim.uv.fs_stat(root .. '/compile_commands.json') then
    vim.list_extend(cmd, { '-p', root })
  elseif vim.uv.fs_stat(root .. '/CMakeLists.txt') then
    vim.notify('Build the project first so clang-tidy has its compilation database', vim.log.levels.WARN)
    return
  else
    local c = vim.bo[buf].filetype == 'c'
    vim.list_extend(cmd, { '--', '-x', c and 'c' or 'c++', c and '-std=c17' or '-std=c++20' })
  end
  require('custom.cpp.tasks').run('analysis', cmd, root, {
    title = 'clang-tidy: ' .. vim.fs.basename(file),
    open = true,
    decorate = function(s)
      local diagnostics = {}
      for _, line in ipairs(s.lines) do
        local path, lnum, col, severity, message = line:match '^(.-):(%d+):(%d+):%s+(%w+):%s+(.*)'
        if path then
          diagnostics[#diagnostics + 1] = {
            filename = path,
            lnum = tonumber(lnum),
            col = tonumber(col),
            type = severity == 'error' and 'E' or severity == 'warning' and 'W' or 'I',
            text = message,
          }
        end
      end
      s.diagnostics = diagnostics
    end,
  })
end
function M.quickfix()
  local s = require('custom.cpp.tasks').states.analysis
  vim.fn.setqflist({}, 'r', { title = 'clang-tidy', items = s and s.diagnostics or {} })
  vim.cmd 'botright copen 12'
end
return M
