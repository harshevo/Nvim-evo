local set = vim.opt -- set options
set.tabstop = 2
set.softtabstop = 2
set.shiftwidth = 2

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.wo.relativenumber = true
vim.opt.fillchars = { eob = ' ' }
vim.opt.cursorline = false
vim.opt.scrolloff = 8

vim.g.have_nerd_font = true

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true
vim.opt.background = 'dark'


vim.opt.splitright = true
vim.opt.splitbelow = true
--------------------------------------------------------------------------

-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

vim.wo.wrap = false

-- Enable mouse mode
vim.o.mouse = 'a'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

