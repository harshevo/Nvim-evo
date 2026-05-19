-- Enable bytecode cache (Neovim 0.9+). Must run before any require().
vim.loader.enable()

do
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if level ~= nil and level < vim.log.levels.ERROR then
      return
    end
    return orig_notify(msg, level, opts)
  end
end

vim.env.PATH = vim.env.PATH .. ':/usr/bin'

-- Disable unused providers (no Perl/Ruby/Python/Node plugins in use).
-- Unused built-in runtime plugins (tar, zip, gzip, tohtml, tutor, netrw)
-- are disabled in lua/custom/lazy.lua via lazy.nvim's `disabled_plugins`.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0

require 'custom.core'
require 'custom.lazy'
require('helpsearch').setup {
  help_dir = '~/dev/help',
}
require 'man_search'

-- function _G.set_terminal_keymaps()
--   local opts = { noremap = true }
--   vim.api.nvim_buf_set_keymap(0, 't', '<esc>', [[<C-\><C-n>]], opts)
--   vim.api.nvim_buf_set_keymap(0, 't', 'jk', [[<C-\><C-n>]], opts)
--   vim.api.nvim_buf_set_keymap(0, 't', '<C-h>', [[<C-\><C-n><C-W>h]], opts)
--   vim.api.nvim_buf_set_keymap(0, 't', '<C-j>', [[<C-\><C-n><C-W>j]], opts)
--   vim.api.nvim_buf_set_keymap(0, 't', '<C-k>', [[<C-\><C-n><C-W>k]], opts)
--   vim.api.nvim_buf_set_keymap(0, 't', '<C-l>', [[<C-\><C-n><C-W>l]], opts)
-- end

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    (vim.hl or vim.highlight).on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})
-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
