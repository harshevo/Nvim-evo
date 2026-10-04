local M = {}
local env = require 'custom.python.environment'

local function symbol()
  local line, col = vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  for first, name, last in line:gmatch '()([%a_][%w_%.]*)()' do
    if col >= first and col < last then
      return name:gsub('%.$', '')
    end
  end
  return vim.fn.expand '<cword>'
end

function M.open(name)
  local buf = env.source()
  if not buf then
    return
  end
  name = name or symbol()
  if name == '' then
    return
  end
  local root = env.root(buf)
  require('custom.cpp.tasks').run('py-doc', {
    env.python(root),
    vim.fn.stdpath 'config' .. '/scripts/python_docs.py',
    name,
    vim.api.nvim_buf_get_name(buf),
  }, root, { open = true, title = 'Python documentation: ' .. name })
end

function M.hover()
  if #vim.lsp.get_clients { bufnr = 0, name = 'pyright' } > 0 then
    vim.lsp.buf.hover { border = 'single', max_width = 100 }
  else
    M.open()
  end
end

function M.web(name)
  name = name or symbol()
  local encoded = name:gsub('([^%w%-_%.~])', function(char)
    return string.format('%%%02X', string.byte(char))
  end)
  vim.ui.open('https://docs.python.org/3/search.html?q=' .. encoded)
end
return M
