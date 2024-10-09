-- function NvimTreeTrash()
--   local lib = require 'nvim-tree.lib'
--   local function on_exit(job_id, data, event)
--     lib.refresh_tree()
--   end
--   local node = lib.get_node_at_cursor()
--   if node then
--     vim.fn.jobstart('trash ' .. node.absolute_path, {
--       detach = true,
--       on_exit = on_exit,
--     })
--   end
-- end
--
return {
  'nvim-tree/nvim-tree.lua',
  version = '*',
  lazy = false,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },

  config = function()
    require('nvim-tree').setup {
      view = {
        width = 30,
      },
      filters = {
        custom = { '^\\.git' },
      },
    }
    --
    -- vim.g.nvim_tree_bindings = {
    --   { key = 'd', cb = ':lua NvimTreeTrash()<CR>' },
    -- }
  end,
}
