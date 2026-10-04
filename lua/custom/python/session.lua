local M = {}
local env = require 'custom.python.environment'
local function path(root)
  local dir = vim.fn.stdpath 'state' .. '/python-ide/sessions'
  vim.fn.mkdir(dir, 'p')
  return dir .. '/' .. vim.fn.sha256(root) .. '.vim'
end

function M.save()
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return false
  end
  local root, options = env.root(buf), vim.o.sessionoptions
  vim.o.sessionoptions = 'buffers,curdir,folds,help,tabpages,winsize'
  local ok, error = pcall(vim.cmd, 'mksession! ' .. vim.fn.fnameescape(path(root)))
  vim.o.sessionoptions = options
  if not ok then
    vim.notify(error, vim.log.levels.ERROR)
    return false
  end
  vim.fn.writefile({ vim.json.encode { python = env.selection(root) } }, path(root) .. '.json')
  vim.notify 'Saved Python project session'
  return true
end

function M.load()
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return false
  end
  local root = env.root(buf)
  if not vim.uv.fs_stat(path(root)) then
    vim.notify('No saved Python session for this project', vim.log.levels.WARN)
    return false
  end
  local ok, lines = pcall(vim.fn.readfile, path(root) .. '.json')
  local valid, metadata = false, {}
  if ok then
    valid, metadata = pcall(vim.json.decode, table.concat(lines, '\n'))
  end
  if valid then
    env.remember(root, metadata.python)
  end
  vim.cmd('source ' .. vim.fn.fnameescape(path(root)))
  env.restart()
  return true
end
return M
