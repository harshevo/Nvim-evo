return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  event = { 'BufReadPost', 'BufNewFile' },
  cmd = { 'TSInstall', 'TSUpdate', 'TSUpdateSync', 'TSInstallFromGrammar' },
  dependencies = {
    { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
  },
  build = ':TSUpdate',

  config = function()
    -- [[ Configure Treesitter ]]
    -- The `main` branch is a rewrite: there is no `nvim-treesitter.configs`
    -- and nothing is started automatically. We install the parsers we want
    -- and start highlighting/indentation per buffer via `vim.treesitter.start`.
    local ensureInstalled = {
      'c', 'cpp', 'go', 'lua', 'python', 'rust',
      'tsx', 'javascript', 'typescript', 'vimdoc', 'vim', 'bash',
    }

    -- Filetypes whose treesitter indentexpr misbehaves; leave them on the
    -- default indenter (matches the old `indent.disable` list).
    local indentDisabled = { python = true }

    require('nvim-treesitter').install(ensureInstalled)

    local function startForBuffer(bufnr)
      local filetype = vim.bo[bufnr].filetype
      local lang = vim.treesitter.language.get_lang(filetype)
      if not lang then
        return
      end
      -- Skips silently when the parser is not installed yet (first run,
      -- before the async install above has finished).
      if not pcall(vim.treesitter.start, bufnr, lang) then
        return
      end
      if not indentDisabled[filetype] then
        vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      callback = function(event)
        startForBuffer(event.buf)
      end,
    })

    -- The BufReadPost/BufNewFile event that lazy-loaded this plugin has
    -- already fired FileType for the current buffer, so start it directly.
    startForBuffer(vim.api.nvim_get_current_buf())

    -- [[ Textobjects ]] -- also rewritten on `main`: keymaps are set manually.
    require('nvim-treesitter-textobjects').setup {
      select = {
        lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      },
      move = {
        set_jumps = true, -- whether to set jumps in the jumplist
      },
    }

    local select = require 'nvim-treesitter-textobjects.select'
    local selectMappings = {
      aa = '@parameter.outer',
      ia = '@parameter.inner',
      af = '@function.outer',
      ['if'] = '@function.inner',
      ac = '@class.outer',
      ic = '@class.inner',
    }
    for key, capture in pairs(selectMappings) do
      vim.keymap.set({ 'x', 'o' }, key, function()
        select.select_textobject(capture, 'textobjects')
      end, { desc = 'Select ' .. capture })
    end

    local swap = require 'nvim-treesitter-textobjects.swap'
    vim.keymap.set('n', '<leader>a', function()
      swap.swap_next '@parameter.inner'
    end, { desc = 'Swap next parameter' })
    vim.keymap.set('n', '<leader>A', function()
      swap.swap_previous '@parameter.inner'
    end, { desc = 'Swap previous parameter' })

    local move = require 'nvim-treesitter-textobjects.move'
    local moveMappings = {
      goto_next_start = { [']m'] = '@function.outer', [']]'] = '@class.outer' },
      goto_next_end = { [']M'] = '@function.outer', [']['] = '@class.outer' },
      goto_previous_start = { ['[m'] = '@function.outer', ['[['] = '@class.outer' },
      goto_previous_end = { ['[M'] = '@function.outer', ['[]'] = '@class.outer' },
    }
    for functionName, maps in pairs(moveMappings) do
      for key, capture in pairs(maps) do
        vim.keymap.set({ 'n', 'x', 'o' }, key, function()
          move[functionName](capture, 'textobjects')
        end, { desc = functionName .. ' ' .. capture })
      end
    end
  end,
}
