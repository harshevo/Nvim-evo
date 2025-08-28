local M = {}

-- Default root help dir
M.root_dir = vim.fn.expand '~/dev/help'

-- Internal: search in a given subdir
local function search_in(subdir)
  local ok, telescope = pcall(require, 'telescope.builtin')
  if not ok then
    vim.notify('Telescope not found!', vim.log.levels.ERROR)
    return
  end

  local dir = M.root_dir .. '/' .. subdir

  -- Show message in Neovim command line
  vim.notify('🔍 Searching in: ' .. dir, vim.log.levels.INFO)

  telescope.live_grep {
    cwd = dir,
    prompt_title = 'Help Search (' .. subdir .. ') [' .. dir .. ']', -- shows dir at top of telescope
  }
end

-- Setup
function M.setup(opts)
  if opts and opts.root_dir then
    M.root_dir = vim.fn.expand(opts.root_dir)
  end

  -- Commands for flexibility
  vim.api.nvim_create_user_command('HelpSearchPython', function()
    search_in 'python'
  end, {})
  vim.api.nvim_create_user_command('HelpSearchC', function()
    search_in 'c'
  end, {})
  vim.api.nvim_create_user_command('HelpSearchCpp', function()
    search_in 'cpp'
  end, {})

  -- Keymaps (customizable)
  vim.keymap.set('n', '<leader>hp', function()
    search_in 'python'
  end, { desc = 'Search Python help' })
  vim.keymap.set('n', '<leader>hc', function()
    search_in 'c'
  end, { desc = 'Search C help' })
  vim.keymap.set('n', '<leader>hC', function()
    search_in 'cpp'
  end, { desc = 'Search C++ help' })
end

return M
