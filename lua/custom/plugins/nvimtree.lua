return {
  'nvim-tree/nvim-tree.lua',
  version = '*',
  cmd = { 'NvimTreeToggle', 'NvimTreeOpen', 'NvimTreeFocus', 'NvimTreeFindFile' },
  keys = { { '<leader>e', '<cmd>NvimTreeToggle<cr>', desc = 'Toggle file tree' } },
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },

  config = function()
    local trash_dir = vim.fn.expand '~/.Trash'
    local trash_history = {}

    local function snapshot_trash()
      local set = {}
      for _, name in ipairs(vim.fn.readdir(trash_dir)) do
        set[name] = true
      end
      return set
    end

    local function trash_and_remember(api)
      return function()
        local node = api.tree.get_node_under_cursor()
        if not node or node.name == '..' then
          return
        end
        local original = node.absolute_path
        local before = snapshot_trash()
        api.fs.trash(node)
        vim.defer_fn(function()
          for _, name in ipairs(vim.fn.readdir(trash_dir)) do
            if not before[name] then
              table.insert(trash_history, { original = original, trash = trash_dir .. '/' .. name })
              return
            end
          end
        end, 250)
      end
    end

    local function restore_last(api)
      return function()
        local entry = table.remove(trash_history)
        if not entry then
          vim.notify('nvim-tree: nothing to restore', vim.log.levels.WARN)
          return
        end
        if vim.fn.filereadable(entry.trash) == 0 and vim.fn.isdirectory(entry.trash) == 0 then
          vim.notify('nvim-tree: missing in trash: ' .. entry.trash, vim.log.levels.ERROR)
          return
        end
        local result = vim.fn.system { 'mv', entry.trash, entry.original }
        if vim.v.shell_error ~= 0 then
          vim.notify('nvim-tree: restore failed: ' .. result, vim.log.levels.ERROR)
          table.insert(trash_history, entry)
          return
        end
        api.tree.reload()
        vim.notify('nvim-tree: restored ' .. entry.original)
      end
    end

    local function on_attach(bufnr)
      local api = require 'nvim-tree.api'
      local function opts(desc)
        return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      api.config.mappings.default_on_attach(bufnr)

      vim.keymap.set('n', 'd', trash_and_remember(api), opts 'Trash')
      vim.keymap.set('n', 'D', api.fs.remove, opts 'Delete (permanent)')
      vim.keymap.set('n', '<C-z>', restore_last(api), opts 'Restore last trashed')
    end

    require('nvim-tree').setup {
      view = {
        width = 30,
      },
      filters = {
        custom = { '^\\.git' },
      },
      trash = {
        cmd = 'trash',
      },
      on_attach = on_attach,
    }
  end,
}
