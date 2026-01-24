return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'folke/neodev.nvim',
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'stevearc/conform.nvim',
      'b0o/SchemaStore.nvim',
    },

    config = function()
      -- === neodev: Lua runtime/LSP tweaks ===
      require('neodev').setup {}

      -- === Capabilities ===
      local capabilities = nil
      if pcall(require, 'cmp_nvim_lsp') then
        capabilities = require('cmp_nvim_lsp').default_capabilities()
      end

      -- === Language servers definition ===
      local servers = {
        bashls = true,

        lua_ls = {
          server_capabilities = { semanticTokensProvider = vim.NIL },
          settings = {
            Lua = {
              runtime = { version = 'LuaJIT' },
              diagnostics = { globals = { 'vim' } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },

        jsonls = {
          settings = {
            json = {
              schemas = require('schemastore').json.schemas(),
              validate = { enable = true },
            },
          },
        },

        yamlls = {
          settings = {
            yaml = {
              schemaStore = { enable = false, url = '' },
              schemas = require('schemastore').yaml.schemas(),
            },
          },
        },

        ocamllsp = {
          manual_install = true,
          settings = {
            codelens = { enable = true },
            inlayHints = { enable = true },
          },
          filetypes = {
            'ocaml',
            'ocaml.interface',
            'ocaml.menhir',
            'ocaml.cram',
          },
        },

        clangd = {
          cmd = {
            'clangd',
            '--function-arg-placeholders=0',
            '--fallback-style=Google',
          },
          init_options = {
            clangdFileStatus = true,
            usePlaceholders = false,
          },
          filetypes = { 'c', 'cpp' },
        },

        vtsls = true,
        pyright = true,
        dockerls = true,
      }

      -- === Mason setup ===
      require('mason').setup()

      local servers_to_install = vim.tbl_filter(function(key)
        local t = servers[key]
        if type(t) == 'table' then
          return not t.manual_install
        else
          return t
        end
      end, vim.tbl_keys(servers))

      local ensure_installed = {
        'stylua',
        'vtsls',
        'lua_ls',
        'delve',
        'tailwindcss-language-server',
      }
      vim.list_extend(ensure_installed, servers_to_install)

      require('mason-tool-installer').setup {
        ensure_installed = ensure_installed,
      }

      -- === Register & enable servers (pure Neovim 0.11 API) ===
      for name, cfg in pairs(servers) do
        local cfg_table = (cfg == true) and {} or vim.deepcopy(cfg)
        cfg_table = vim.tbl_deep_extend('force', {}, { capabilities = capabilities }, cfg_table)

        if name == 'tsserver' then
          name = 'ts_ls'
        end

        -- Register configuration
        pcall(function()
          vim.lsp.config(name, cfg_table)
        end)

        -- Enable it for its filetypes
        pcall(function()
          vim.lsp.enable(name)
        end)
      end

      -- === LspAttach: keymaps & overrides ===
      local disable_semantic_tokens = { lua = true }

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufnr = args.buf
          local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

          local settings = servers[client.name]
          if type(settings) ~= 'table' then
            settings = {}
          end

          local builtin = require 'telescope.builtin'

          vim.opt_local.omnifunc = 'v:lua.vim.lsp.omnifunc'
          vim.keymap.set('n', 'gd', builtin.lsp_definitions, { buffer = bufnr })
          vim.keymap.set('n', 'gr', builtin.lsp_references, { buffer = bufnr })
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { buffer = bufnr })
          vim.keymap.set('n', 'gT', vim.lsp.buf.type_definition, { buffer = bufnr })
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
          vim.keymap.set('n', '<space>cr', vim.lsp.buf.rename, { buffer = bufnr })
          vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, { buffer = bufnr })

          if disable_semantic_tokens[vim.bo[bufnr].filetype] then
            client.server_capabilities.semanticTokensProvider = nil
          end

          if settings.server_capabilities then
            for k, v in pairs(settings.server_capabilities) do
              client.server_capabilities[k] = (v == vim.NIL) and nil or v
            end
          end
        end,
      })

      -- === Diagnostics & UI borders ===
      local _border = 'single'
      vim.diagnostic.config { float = { border = _border } }
      vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = _border })
      vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = _border })

      -- === Autoformat on save ===
      vim.api.nvim_create_autocmd('BufWritePre', {
        callback = function(args)
          require('conform').format {
            bufnr = args.buf,
            lsp_fallback = true,
            quiet = true,
          }
        end,
      })
    end,
  },
}
