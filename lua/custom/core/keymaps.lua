vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.keymap.set('x', '<leader>p', [["_dP]])

vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set('n', '<leader>y', [["+Y]])
vim.keymap.set({ 'n', 'v' }, '<leader>D', [["_d]], { desc = 'Delete without changing registers' })

vim.keymap.set('i', 'jk', '<Esc>', { silent = true })
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>x', ':bdelete<CR>', { desc = 'Close buffer' })

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
vim.keymap.set('v', '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
local function jump_error(count)
  vim.diagnostic.jump { count = count, severity = vim.diagnostic.severity.ERROR, float = true }
end

vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', 'gf', function()
  jump_error(1)
end, { desc = 'Go to next error' })
vim.keymap.set('n', 'ge', function()
  jump_error(-1)
end, { desc = 'Go to previous error' })
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

-------------------------------------------------------------------------------------------

local keymap = vim.keymap.set

-- Cmake

keymap('n', '<leader>mg', '<cmd>CppConfigure<CR>', { desc = 'Generate' })
keymap('n', '<leader>mb', '<cmd>CMakeBuild<CR>', { desc = 'Build' })
keymap('n', '<leader>mr', '<cmd>RunBuild<CR>', { desc = 'Save, rebuild and run' })
keymap('n', '<leader>md', '<cmd>DebugContinue<CR>', { desc = 'Debug / continue' })
keymap('n', '<leader>mt', '<cmd>CppPreset<CR>', { desc = 'Select Build Type' })
keymap('n', '<leader>mst', '<cmd>CMakeSelectBuildTarget<CR>', { desc = 'Select Build Target' })
keymap('n', '<leader>ml', '<cmd>CppTarget<CR>', { desc = 'Select Launch Target' })
keymap('n', '<leader>meo', '<cmd>CMakeOpenExecutor<CR>', { desc = 'Open CMake Executor' })
keymap('n', '<leader>mec', '<cmd>CMakeCloseExecutor<CR>', { desc = 'Close CMake Executor' })
keymap('n', '<leader>mor', '<cmd>CMakeOpenRunner<CR>', { desc = 'Open CMake Runner' })
keymap('n', '<leader>mcr', function()
  vim.cmd [[CMakeStopRunner]]
  vim.cmd [[CMakeCloseRunner]]
end, { desc = 'Close CMake Runner' })
keymap('n', '<leader>mi', '<cmd>CMakeInstall<CR>', { desc = 'Intall CMake target' })
keymap('n', '<leader>mc', '<cmd>CMakeClean<CR>', { desc = 'Clean CMake target' })
keymap('n', '<leader>ms', function()
  vim.cmd [[CMakeStopRunner]]
  vim.cmd [[CMakeStopExecutor]]
end, { desc = 'Stop CMake Process' })

keymap('n', '<C-l>hi', '<cmd>lua vim.lsp.buf.incoming_calls()<cr>', { silent = true, desc = 'incoming calls' })
keymap('n', '<C-l>ho', '<cmd>lua vim.lsp.buf.outgoing_calls()<cr>', { silent = true, desc = 'outgoing calls' })

-- Make <Esc> leave terminal job mode
vim.api.nvim_set_keymap('t', '<Esc>', [[<C-\><C-n>]], { noremap = true })

-------------------------------------------------------------------------

--cp cpp

--dabod
--database

keymap('n', '<leader>od', '<cmd>DBUIToggle<cr>')
-- set system clipboard
vim.keymap.set('n', 'y', '"+y')
vim.keymap.set('n', 'yy', '"+yy')
vim.keymap.set('n', 'Y', '"+Y')
vim.keymap.set('x', 'y', '"+y')
vim.keymap.set('x', 'Y', '"+Y')

-- Import runner (this will also register the :RunNow command)
require 'runner'
