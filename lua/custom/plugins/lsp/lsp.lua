return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    cmd = { 'LspInfo', 'LspInstall', 'LspUninstall', 'Mason' },
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

      -- Normalize vim.NIL (JSON null) -> nil in server_capabilities so that
      -- built-in runtime handlers (e.g. semantic_tokens.lua) don't try to
      -- index a userdata value. Must run before any LspAttach callback fires,
      -- so hook it via on_init rather than LspAttach.
      local function normalize_server_capabilities(client)
        if client and client.server_capabilities then
          for k, v in pairs(client.server_capabilities) do
            if type(v) == 'userdata' then
              client.server_capabilities[k] = nil
            end
          end
        end
      end

      -- === Language servers definition ===
      local servers = {
        bashls = true,

        lua_ls = {
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
          filetypes = { 'yaml' },
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
        'prettier',
        'goimports',
        'isort',
        'black',
        'clang-format',
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

        -- Skip manual_install servers whose binary isn't on $PATH yet
        if cfg_table.manual_install and vim.fn.executable(name) == 0 then
          goto continue
        end

        local user_on_init = cfg_table.on_init
        cfg_table.on_init = function(client, init_result)
          normalize_server_capabilities(client)
          if user_on_init then
            return user_on_init(client, init_result)
          end
        end

        pcall(function() vim.lsp.config(name, cfg_table) end)
        pcall(function() vim.lsp.enable(name) end)

        ::continue::
      end

      -- === LspAttach: keymaps & overrides ===
      local disable_semantic_tokens = { lua = true }

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufnr = args.buf
          local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

          -- Normalize vim.NIL (from JSON null in server responses) to nil,
          -- otherwise indexing e.g. semanticTokensProvider crashes.
          if client.server_capabilities then
            for k, v in pairs(client.server_capabilities) do
              if type(v) == 'userdata' then
                client.server_capabilities[k] = nil
              end
            end
          end

          local settings = servers[client.name]
          if type(settings) ~= 'table' then
            settings = {}
          end

          vim.opt_local.omnifunc = 'v:lua.vim.lsp.omnifunc'
          -- Defer the telescope require until the keymap is actually pressed,
          -- so opening a code file doesn't drag telescope into startup.
          vim.keymap.set('n', 'gd', function() require('telescope.builtin').lsp_definitions() end, { buffer = bufnr })
          vim.keymap.set('n', 'gr', function() require('telescope.builtin').lsp_references() end, { buffer = bufnr })
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { buffer = bufnr })
          vim.keymap.set('n', 'gT', vim.lsp.buf.type_definition, { buffer = bufnr })
          vim.keymap.set('n', 'K', function() vim.lsp.buf.hover { border = 'single', max_width = 100 } end, { buffer = bufnr, desc = 'LSP hover (press K again to focus)' })
          vim.keymap.set('n', 'gK', function() vim.lsp.buf.signature_help { border = 'single' } end, { buffer = bufnr, desc = 'LSP signature help' })
          vim.keymap.set('i', '<C-k>', function() vim.lsp.buf.signature_help { border = 'single' } end, { buffer = bufnr })
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
      vim.diagnostic.config {
        float = { border = 'single' },
        signs = { severity = { min = vim.diagnostic.severity.ERROR } },
        virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
        underline = { severity = { min = vim.diagnostic.severity.ERROR } },
      }

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
