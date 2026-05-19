local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system {
		'git',
		'clone',
		'--filter=blob:none',
		'https://github.com/folke/lazy.nvim.git',
		'--branch=stable', -- latest stable release
		lazypath,
	}
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
	-- NOTE: First, some plugins that don't require any configuration

	{ import = 'custom.plugins' },
	{ import = 'custom.plugins.lsp' },

	-- Git related plugins (load only when their commands are used)
	{ 'tpope/vim-fugitive', cmd = { 'G', 'Git', 'Gvdiffsplit', 'Gdiffsplit', 'Gread', 'Gwrite', 'Ggrep', 'GMove', 'GDelete', 'GBrowse', 'GRemove', 'GRename', 'Glgrep', 'Gedit' } },
	{ 'tpope/vim-rhubarb', cmd = { 'GBrowse' } },

	-- Detect tabstop and shiftwidth automatically
	{ 'tpope/vim-sleuth', event = { 'BufReadPre', 'BufNewFile' } },
}, {
	performance = {
		rtp = {
			disabled_plugins = {
				'gzip',
				'tarPlugin',
				'tohtml',
				'tutor',
				'zipPlugin',
				'netrwPlugin',
			},
		},
	},
})
