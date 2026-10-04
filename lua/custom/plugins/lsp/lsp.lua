return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    cmd = { 'LspInfo', 'Mason', 'MasonToolsInstall', 'MasonToolsUpdate', 'MasonToolsClean' },
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'b0o/SchemaStore.nvim',
    },

    config = function()
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
              workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
              telemetry = { enable = false },
            },
          },
        },

        jsonls = {
          settings = {
            json = {
              schemas = {},
              validate = { enable = true },
            },
          },
        },

        yamlls = {
          filetypes = { 'yaml' },
          settings = {
            yaml = {
              schemaStore = { enable = false, url = '' },
              schemas = {},
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
            '--fallback-style=LLVM',
            '--header-insertion=iwyu',
            '--completion-style=detailed',
            '--background-index',
            '--background-index-priority=background',
            '-j=2',
            '--pch-storage=memory',
            '--log=error',
          },
          init_options = {
            clangdFileStatus = true,
            usePlaceholders = false,
            fallbackFlags = { '-Wall', '-Wextra' },
          },
          filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
          root_markers = { { '.clangd', 'compile_commands.json', 'compile_flags.txt', 'CMakeLists.txt', 'Makefile', 'makefile' }, '.git' },
          before_init = function(params, config)
            require('custom.cpp.language').configure(params, config)
          end,
        },

        vtsls = true,
        pyright = {
          root_markers = { { 'pyproject.toml', 'pyrightconfig.json', 'pytest.ini', 'setup.py', 'setup.cfg', 'Pipfile', 'requirements.txt', '.venv' }, '.git' },
          settings = {
            pyright = { disableOrganizeImports = true },
            python = {
              analysis = {
                autoSearchPaths = true,
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = 'openFilesOnly',
                typeCheckingMode = 'standard',
                exclude = { '**/.venv', '**/venv', '**/env', '**/__pycache__', '**/.git', '**/build', '**/dist', '**/.mypy_cache', '**/.pytest_cache' },
              },
            },
          },
          before_init = function(_, config)
            config.settings.python.pythonPath = require('custom.python.environment').python(config.root_dir)
          end,
        },
        ruff = {
          cmd = { vim.fn.stdpath 'data' .. '/python-tools/bin/ruff', 'server' },
          filetypes = { 'python' },
          root_markers = { { 'pyproject.toml', 'ruff.toml', '.ruff.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.venv' }, '.git' },
          init_options = { settings = { logLevel = 'error' } },
          manual_install = true,
        },
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
        'clang-format',
      }
      vim.list_extend(ensure_installed, servers_to_install)

      require('mason-tool-installer').setup {
        ensure_installed = ensure_installed,
        run_on_start = false,
      }

      -- === Register & enable servers (pure Neovim 0.11 API) ===
      for name, cfg in pairs(servers) do
        local cfg_table = (cfg == true) and {} or vim.deepcopy(cfg)
        cfg_table = vim.tbl_deep_extend('force', {}, { capabilities = capabilities }, cfg_table)

        if name == 'tsserver' then
          name = 'ts_ls'
        end

        -- Skip manual_install servers whose binary isn't on $PATH yet
        if cfg_table.manual_install and vim.fn.executable((cfg_table.cmd or {})[1] or name) == 0 then
          goto continue
        end

        cfg_table.flags = vim.tbl_extend('force', cfg_table.flags or {}, { debounce_text_changes = 200 })
        if name == 'jsonls' or name == 'yamlls' then
          cfg_table.before_init = function(_, config)
            if name == 'jsonls' then
              config.settings.json.schemas = require('schemastore').json.schemas()
            else
              config.settings.yaml.schemas = require('schemastore').yaml.schemas()
            end
          end
        end

        local user_on_init = cfg_table.on_init
        cfg_table.on_init = function(client, init_result)
          normalize_server_capabilities(client)
          if user_on_init then
            return user_on_init(client, init_result)
          end
        end

        vim.lsp.config(name, cfg_table)
        local resolved = vim.lsp.config[name]
        local root_dir = resolved.root_dir
        local root_markers = resolved.root_markers
        vim.lsp.config(name, {
          root_dir = function(bufnr, on_dir)
            if vim.b[bufnr].large_file then
              return
            end
            if type(root_dir) == 'function' then
              return root_dir(bufnr, on_dir)
            end
            on_dir(root_dir or (root_markers and vim.fs.root(bufnr, root_markers)) or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':h'))
          end,
        })
        vim.lsp.enable(name)

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
          if client.name == 'ruff' then
            client.server_capabilities.hoverProvider = false
            return
          end
          -- Defer the telescope require until the keymap is actually pressed,
          -- so opening a code file doesn't drag telescope into startup.
          vim.keymap.set('n', 'gd', function()
            require('telescope.builtin').lsp_definitions()
          end, { buffer = bufnr })
          vim.keymap.set('n', 'gr', function()
            require('telescope.builtin').lsp_references()
          end, { buffer = bufnr })
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { buffer = bufnr })
          vim.keymap.set('n', 'gT', vim.lsp.buf.type_definition, { buffer = bufnr })
          vim.keymap.set('n', 'K', function()
            if client.name == 'clangd' then
              require('custom.cpp.docs').hover()
            elseif client.name == 'pyright' then
              require('custom.python.docs').hover()
            else
              vim.lsp.buf.hover { border = 'single', max_width = 100 }
            end
          end, { buffer = bufnr, desc = 'LSP hover (press K again to focus)' })
          vim.keymap.set('n', 'gK', function()
            vim.lsp.buf.signature_help { border = 'single' }
          end, { buffer = bufnr, desc = 'LSP signature help' })
          vim.keymap.set('i', '<C-k>', function()
            vim.lsp.buf.signature_help { border = 'single' }
          end, { buffer = bufnr })
          vim.keymap.set('n', '<space>cr', vim.lsp.buf.rename, { buffer = bufnr })
          vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, { buffer = bufnr })
          if client.name == 'clangd' then
            require('custom.cpp.language').attach(bufnr)
          end

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
        update_in_insert = false,
        severity_sort = true,
        signs = { severity = { min = vim.diagnostic.severity.WARN } },
        virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
        underline = { severity = { min = vim.diagnostic.severity.WARN } },
      }
    end,
  },
}
