return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'master',
  event = { 'BufReadPost', 'BufNewFile' },
  cmd = { 'TSInstall', 'TSBufEnable', 'TSBufDisable', 'TSModuleInfo', 'TSUpdate' },
  dependencies = {
    { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'master' },
  },
  build = ':TSUpdate',

  config = function()
    -- [[ Configure Treesitter ]]
    -- See `:help nvim-treesitter`
    require('nvim-treesitter.configs').setup {
        -- Add languages to be installed here that you want installed for treesitter
        ensure_installed = { 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'tsx', 'javascript', 'typescript', 'vimdoc', 'vim', 'bash' },

        -- Autoinstall languages that are not installed. Defaults to false (but you can change for yourself!)
        auto_install = false,

        autotag = {
          enable = true,
        },

        highlight = { enable = true },
        indent = {
          enable = true,
          disable = { 'python' },
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = '<c-space>',
            node_incremental = '<c-space>',
            scope_incremental = '<c-s>',
            node_decremental = '<M-space>',
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              [']m'] = '@function.outer',
              [']]'] = '@class.outer',
            },
            goto_next_end = {
              [']M'] = '@function.outer',
              [']['] = '@class.outer',
            },
            goto_previous_start = {
              ['[m'] = '@function.outer',
              ['[['] = '@class.outer',
            },
            goto_previous_end = {
              ['[M'] = '@function.outer',
              ['[]'] = '@class.outer',
            },
          },
          swap = {
            enable = true,
            swap_next = {
              ['<leader>a'] = '@parameter.inner',
            },
            swap_previous = {
              ['<leader>A'] = '@parameter.inner',
            },
          },
        },
    }

    -- nvim-treesitter master branch is archived and its query predicates/
    -- directives assume `match[id]` is a single TSNode. In Neovim 0.12 it is
    -- always a TSNode[] list, which crashes the decoration provider and
    -- disables treesitter highlighting buffer-wide (e.g. clangd hover on a C
    -- symbol opens a markdown float whose code-block injection triggers this).
    -- Re-register the affected handlers with list-aware versions.
    local tsquery = require 'vim.treesitter.query'
    local override = { force = true, all = true }

    local function firstNode(raw)
      if type(raw) == 'table' then
        return raw[1]
      end
      return raw
    end

    local htmlScriptTypeLanguages = {
      ['importmap'] = 'json',
      ['module'] = 'javascript',
      ['application/ecmascript'] = 'javascript',
      ['text/ecmascript'] = 'javascript',
    }

    local nonFiletypeInjectionAliases = {
      ex = 'elixir',
      pl = 'perl',
      sh = 'bash',
      uxn = 'uxntal',
      ts = 'typescript',
    }

    local function parserFromMarkdownInfoString(alias)
      local m = vim.filetype.match { filename = 'a.' .. alias }
      return m or nonFiletypeInjectionAliases[alias] or alias
    end

    tsquery.add_predicate('nth?', function(match, _, _, pred)
      local node = firstNode(match[pred[2]])
      local n = tonumber(pred[3])
      if node and node:parent() and node:parent():named_child_count() > n then
        return node:parent():named_child(n) == node
      end
      return false
    end, override)

    tsquery.add_predicate('is?', function(match, _, bufnr, pred)
      local locals = require 'nvim-treesitter.locals'
      local node = firstNode(match[pred[2]])
      local types = { unpack(pred, 3) }
      if not node then
        return true
      end
      local _, _, kind = locals.find_definition(node, bufnr)
      return vim.tbl_contains(types, kind)
    end, override)

    tsquery.add_predicate('kind-eq?', function(match, _, _, pred)
      local node = firstNode(match[pred[2]])
      local types = { unpack(pred, 3) }
      if not node then
        return true
      end
      return vim.tbl_contains(types, node:type())
    end, override)

    tsquery.add_directive('set-lang-from-mimetype!', function(match, _, bufnr, pred, metadata)
      local node = firstNode(match[pred[2]])
      if not node then
        return
      end
      local typeAttrValue = vim.treesitter.get_node_text(node, bufnr)
      local configured = htmlScriptTypeLanguages[typeAttrValue]
      if configured then
        metadata['injection.language'] = configured
      else
        local parts = vim.split(typeAttrValue, '/', {})
        metadata['injection.language'] = parts[#parts]
      end
    end, override)

    tsquery.add_directive('set-lang-from-info-string!', function(match, _, bufnr, pred, metadata)
      local node = firstNode(match[pred[2]])
      if not node then
        return
      end
      local alias = vim.treesitter.get_node_text(node, bufnr):lower()
      metadata['injection.language'] = parserFromMarkdownInfoString(alias)
    end, override)

    tsquery.add_directive('downcase!', function(match, _, bufnr, pred, metadata)
      local id = pred[2]
      local node = firstNode(match[id])
      if not node then
        return
      end
      local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ''
      if not metadata[id] then
        metadata[id] = {}
      end
      metadata[id].text = string.lower(text)
    end, override)
  end,
}
