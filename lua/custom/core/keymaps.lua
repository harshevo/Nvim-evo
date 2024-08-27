vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.keymap.set('x', '<leader>p', [["_dP]])

vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]])
vim.keymap.set('n', '<leader>Y', [["+Y]])
vim.keymap.set({ 'n', 'v' }, '<leader>d', [["_d]])

vim.keymap.set('i', 'jk', '<Esc>', { silent = true })
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>c', ':bdelete<CR>')

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

-------------------------------------------------------------------------------------------

local keymap = vim.keymap.set

keymap({ 'n', 't' }, '<A-o>', function()
  require('dap').step_out()
end, { silent = true, desc = 'step out' })
keymap({ 'n', 't' }, '<A-i>', function()
  require('dap').step_into()
end, { silent = true, desc = 'step into' })
keymap({ 'n', 't' }, '<A-j>', function()
  require('dap').step_over()
end, { silent = true, desc = 'step over' })
keymap({ 'n', 't' }, '<A-h>', function()
  require('dap').continue()
end, { silent = true, desc = 'continue' })
keymap({ 'n', 't' }, '<A-k>', function()
  require('dap.ui.widgets').hover()
end, { silent = true, desc = 'caculate expr' })
keymap('n', '<F5>', function()
  require('dap').toggle_breakpoint()
end, { silent = true, desc = 'toggle breakpoint' })

-- Cmake

keymap('n', '<leader>mg', '<cmd>CMakeGenerate<CR>', { desc = 'Generate' })
keymap('n', '<leader>mb', '<cmd>CMakeBuild<CR>', { desc = 'Build' })
keymap('n', '<leader>mr', '<cmd>CMakeRun<CR>', { desc = 'Run' })
keymap('n', '<leader>md', '<cmd>CMakeDebug<CR>', { desc = 'Debug' })
keymap('n', '<leader>mt', '<cmd>CMakeSelectBuildType<CR>', { desc = 'Select Build Type' })
keymap('n', '<leader>mst', '<cmd>CMakeSelectBuildTarget<CR>', { desc = 'Select Build Target' })
keymap('n', '<leader>ml', '<cmd>CMakeSelectLaunchTarget<CR>', { desc = 'Select Launch Target' })
keymap('n', '<leader>meo', '<cmd>CMakeOpenExecutor<CR>', { desc = 'Open CMake Executor' })
keymap('n', '<leader>mec', '<cmd>CMakeCloseExecutor<CR>', { desc = 'Close CMake Executor' })
keymap('n', '<leader>mor', '<cmd>CMakeOpenRunner<CR>', { desc = 'Open CMake Runner' })
keymap('n', '<leader>mcr', '<cmd>CMakeCloseRunner<CR>', { desc = 'Close CMake Runner' })
keymap('n', '<leader>mi', '<cmd>CMakeInstall<CR>', { desc = 'Intall CMake target' })
keymap('n', '<leader>mc', '<cmd>CMakeClean<CR>', { desc = 'Clean CMake target' })
keymap('n', '<leader>ms', function()
  vim.cmd [[CMakeStopRunner]]
  vim.cmd [[CMakeStopExecutor]]
end, { desc = 'Stop CMake Process' })

--debug

keymap('n', '<leader>dt', "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", { desc = 'Toggle Condition Breakpoint' })
keymap('n', '<leader>dk', "<cmd>lua require'dap'.up()<CR>", { desc = 'Stack up' })
keymap('n', '<leader>dj', "<cmd>lua require'dap'.down()<CR>", { desc = 'Stack down' })
keymap('n', '<leader>dn', "<cmd>lua require'dap'.run_to_cursor()<CR>", { desc = 'Run To Cursor' })
keymap('n', '<leader>dq', "<cmd>lua require'dap'.terminate()<CR>", { desc = 'Terminate' })
--[[ .exit               Closes the REPL ]]
--[[ .c or .continue     Same as |dap.continue| ]]
--[[ .n or .next         Same as |dap.step_over| ]]
--[[ .into               Same as |dap.step_into| ]]
--[[ .into_target        Same as |dap.step_into{askForTargets=true}| ]]
--[[ .out                Same as |dap.step_out| ]]
--[[ .up                 Same as |dap.up| ]]
--[[ .down               Same as |dap.down| ]]
--[[ .goto               Same as |dap.goto_| ]]
--[[ .scopes             Prints the variables in the current scopes ]]
--[[ .threads            Prints all threads ]]
--[[ .frames             Print the stack frames ]]
--[[ .capabilities       Print the capabilities of the debug adapter ]]
--[[ .b or .back         Same as |dap.step_back| ]]
--[[ .rc or .reverse-continue   Same as |dap.reverse_continue| ]]
keymap('n', '<leader>dr', "<cmd>lua require'dap'.repl.toggle()<CR>", { desc = 'Toggle Repl' })
keymap('n', '<leader>df', '<cmd>Telescope dap frames<CR>', { desc = 'Stack frames' })
keymap('n', '<leader>db', '<cmd>Telescope dap list_breakpoints<CR>', { desc = 'All breakpoints' })
keymap('n', '<leader>ds', "<cmd>lua require'dap.ui.widgets'.centered_float(require'dap.ui.widgets'.scopes)<CR>", { desc = 'View current scope' })

---------------------------------- Insert Mode --------------------------
-- Debug
keymap('i', '<F5>', function()
  require('dap').toggle_breakpoint()
end, { silent = true })

keymap('n', '<C-l>hi', '<cmd>lua vim.lsp.buf.incoming_calls()<cr>', { silent = true, desc = 'incoming calls' })
keymap('n', '<C-l>ho', '<cmd>lua vim.lsp.buf.outgoing_calls()<cr>', { silent = true, desc = 'outgoing calls' })

-------------------------------------------------------------------------

--cp cpp

keymap('n', '<F10>', '<cmd>!g++ -o %< % && ./%< < input<cr>')

--dabod
--database

keymap('n', '<F12>', '<cmd>DBUI<cr>')
