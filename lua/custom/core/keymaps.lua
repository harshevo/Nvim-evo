vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.keymap.set('x', '<leader>p', [["_dP]])

vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set('n', '<leader>Y', [["+Y]])
vim.keymap.set({ 'n', 'v' }, '<leader>d', [["_d]])

vim.keymap.set('i', 'jk', '<Esc>', { silent = true })
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>c', ':bd<CR>')

-- vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', {
--   noremap = true,
-- })
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

vim.keymap.set('n', '<leader>sv', '<C-w>v', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>sh', '<C-w>s', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>se', '<C-w>=', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>sx', '<cmd>close<CR>', { desc = 'Split window vertically' })
