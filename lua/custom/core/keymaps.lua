vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.keymap.set('x', '<leader>p', [["_dP]])

vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set('n', '<leader>Y', [["+Y]])
vim.keymap.set({ 'n', 'v' }, '<leader>d', [["_d]])

vim.keymap.set('i', 'jk', '<Esc>', { silent = true })
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>c', ':bd<CR>')

vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', {
  noremap = true,
})
--
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

--buffer change
vim.keymap.set('n', '<S-l>', function()
  vim.cmd.bnext()
end)

vim.keymap.set('n', '<S-h>', function()
  vim.cmd.bprevious()
end)

vim.keymap.set('n', '<leader>gb', '``')

vim.keymap.set('n', '<leader>sv', '<C-w>v', { desc = 'Split window vertically' })
-- vim.keymap.set('n', '<leader>sh', '<C-w>s', { desc = 'Split window vertically' })
-- vim.keymap.set('n', '<leader>se', '<C-w>=', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>sx', '<cmd>close<CR>', { desc = 'Split window vertically' })

---------------------------------------------------------------------------
-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

vim.api.nvim_create_user_command('DiagnosticToggle', function()
  local config = vim.diagnostic.config
  local vt = config().virtual_text
  config {
    virtual_text = not vt,
    underline = not vt,
    signs = not vt,
  }
end, { desc = 'toggle diagnostic' })

vim.keymap.set('n', '<leader><S-e>', function()
  vim.cmd.DiagnosticToggle()
end)
