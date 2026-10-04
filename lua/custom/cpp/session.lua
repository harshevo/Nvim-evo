local M = {}
local function path(root)
  local dir = vim.fn.stdpath 'state' .. '/cpp-ide/sessions'
  vim.fn.mkdir(dir, 'p')
  return dir .. '/' .. vim.fn.sha256(root) .. '.vim'
end
function M.save()
  local root = require('custom.cpp.project').root()
  local options = vim.o.sessionoptions
  vim.o.sessionoptions = 'buffers,curdir,folds,help,tabpages,winsize'
  local ok, err = pcall(vim.cmd, 'mksession! ' .. vim.fn.fnameescape(path(root)))
  vim.o.sessionoptions = options
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  local selected = require('custom.cpp.project').selected(root)
  vim.fn.writefile({ vim.json.encode(selected or vim.empty_dict()) }, path(root) .. '.json')
  vim.notify('Saved project session: ' .. vim.fs.basename(root))
  return true
end
function M.load()
  local root = require('custom.cpp.project').root()
  if not require('runner').save_sources() then
    return false
  end
  if not vim.uv.fs_stat(path(root)) then
    vim.notify('No saved session for this project', vim.log.levels.WARN)
    return false
  end
  local project = require 'custom.cpp.project'
  local selected = project.read(path(root) .. '.json')
  if selected and selected.preset then
    project.remember(root, selected)
  end
  vim.cmd('source ' .. vim.fn.fnameescape(path(root)))
  require('custom.cpp.language').restart()
  return true
end
return M
