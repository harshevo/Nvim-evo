return {
  'rmagatti/auto-session',
  config = function()
    local auto_session = require 'auto-session'

    auto_session.setup {
      auto_restore_enabled = false,
      auto_session_suppress_dirs = {},
    }

    local keymap = vim.keymap

    keymap.set('n', '<leader>rs', '<cmd>SessionRestore<CR>', { desc = 'Restore session for cwd ' })
    keymap.set('n', '<leader>bs', '<cmd>SessionSave<CR>', { desc = 'Save session for auto session root dir' })
  end,
}
