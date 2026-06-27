return {
  {
    'p00f/clangd_extensions.nvim', -- clangd extension, some good stuff
    ft = { 'c', 'cpp' },
    config = function()
      local icons = require 'custom.config.icons'

      require('clangd_extensions').setup {
        -- These apply to the default ClangdSetInlayHints command
        inlay_hints = {
          inline = vim.fn.has 'nvim-0.10' == 1,
          -- Only show inlay hints for the current line
          only_current_line = true,
          -- Event which triggers a refersh of the inlay hints.
          -- You can make this "CursorMoved" or "CursorMoved,CursorMovedI" but
          -- not that this may cause  higher CPU usage.
          -- This option is only respected when only_current_line and
          -- autoSetHints both are true.
          only_current_line_autocmd = 'CursorHold',
          -- whether to show parameter hints with the inlay hints or not
          show_parameter_hints = true,
          -- prefix for parameter hints
          parameter_hints_prefix = '<- ',
          -- prefix for all the other hints (type, chaining)
          other_hints_prefix = '=> ',
          -- whether to align to the length of the longest line in the file
          max_len_align = false,
          -- padding from the left if max_len_align is true
          max_len_align_padding = 1,
          -- whether to align to the extreme right or not
          right_align = false,
          -- padding from the right if right_align is true
          right_align_padding = 7,
          -- The color of the hints
          highlight = 'Comment',
          -- The highlight group priority for extmark
          priority = 100,
        },
        ast = {
          -- These require codicons (https://github.com/microsoft/vscode-codicons)
          role_icons = {
            type = '',
            declaration = icons.kind.Method,
            expression = icons.ui.Circle,
            specifier = icons.kind.Specifier,
            statement = icons.kind.Statement,
            ['template argument'] = icons.type.Template,
          },

          kind_icons = {
            Compound = icons.type.Object,
            Recovery = icons.kind.Recovery,
            TranslationUnit = icons.kind.TranslationUnit,
            PackExpansion = icons.kind.PackExpansion,
            TemplateTypeParm = icons.type.Template,
            TemplateTemplateParm = icons.type.Template,
            TemplateParamObject = icons.type.Template,
          },

          highlights = {
            detail = 'Comment',
          },
        },
        memory_usage = {
          border = 'single',
        },
        symbol_info = {
          border = 'single',
        },
      }
    end,
  },
  {
    'Civitasv/cmake-tools.nvim',
    dependencies = {
      'stevearc/overseer.nvim',
    },
    cmd = {
      'CMakeGenerate',
      'CMakeBuild',
      'CMakeRun',
      'CMakeDebug',
      'CMakeSelectBuildType',
      'CMakeSelectBuildTarget',
      'CMakeSelectLaunchTarget',
      'CMakeOpenExecutor',
      'CMakeCloseExecutor',
      'CMakeOpenRunner',
      'CMakeCloseRunner',
      'CMakeInstall',
      'CMakeClean',
      'CMakeStopRunner',
      'CMakeStopExecutor',
    },
    ft = { 'cmake' },
    config = function()
      local function setup_cmake_runner_kill_on_hide()
        local ok, cmake_toggleterm = pcall(require, 'cmake-tools.toggleterm')
        if not ok or cmake_toggleterm.__kill_on_hide_patched then
          return
        end

        cmake_toggleterm.__kill_on_hide_patched = true

        local group = vim.api.nvim_create_augroup('CMakeRunnerKillOnHide', { clear = true })

        local function process_exists(pid)
          if not pid or pid <= 0 then
            return false
          end

          pcall(vim.fn.system, { 'kill', '-0', tostring(pid) })
          return vim.v.shell_error == 0
        end

        local function process_tree(pid)
          local ok_ps, lines = pcall(vim.fn.systemlist, { 'ps', '-axo', 'pid=,ppid=' })
          if not ok_ps then
            return { pid }
          end

          local children = {}
          for _, line in ipairs(lines) do
            local child, parent = line:match '^%s*(%d+)%s+(%d+)%s*$'
            child, parent = tonumber(child), tonumber(parent)
            if child and parent then
              children[parent] = children[parent] or {}
              table.insert(children[parent], child)
            end
          end

          local pids = {}
          local function visit(parent)
            for _, child in ipairs(children[parent] or {}) do
              visit(child)
              table.insert(pids, child)
            end
          end

          visit(pid)
          table.insert(pids, pid)
          return pids
        end

        local function kill_processes(pids, signal)
          for _, pid in ipairs(pids) do
            if process_exists(pid) then
              pcall(vim.fn.system, { 'kill', signal, tostring(pid) })
            end
          end
        end

        local function job_running(chan)
          if not chan then
            return false
          end

          local ok_wait, status = pcall(vim.fn.jobwait, { chan }, 0)
          return ok_wait and status[1] == -1
        end

        local function wipe_runner_buffer(bufnr)
          vim.schedule(function()
            if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
              pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end
          end)
        end

        local function terminate_runner(bufnr)
          if cmake_toggleterm.__terminating then
            return
          end

          cmake_toggleterm.__terminating = true

          local chan = cmake_toggleterm.chan_id or (cmake_toggleterm.term and cmake_toggleterm.term.job_id)
          local pid = chan and vim.fn.jobpid(chan) or nil
          local pids = pid and pid > 0 and process_tree(pid) or {}

          if chan and job_running(chan) then
            pcall(vim.api.nvim_chan_send, chan, '\003')
            pcall(vim.fn.jobwait, { chan }, 100)
          end

          if pid and pid > 0 then
            pcall(vim.fn.system, { 'kill', '-TERM', '-' .. pid })
          end
          kill_processes(pids, '-TERM')

          if chan and job_running(chan) then
            pcall(vim.fn.jobstop, chan)
            pcall(vim.fn.jobwait, { chan }, 200)
          end

          if pid and pid > 0 then
            pcall(vim.fn.system, { 'kill', '-KILL', '-' .. pid })
          end
          kill_processes(pids, '-KILL')

          cmake_toggleterm.chan_id = nil
          cmake_toggleterm.cmd = nil
          wipe_runner_buffer(bufnr or (cmake_toggleterm.term and cmake_toggleterm.term.bufnr))

          cmake_toggleterm.__terminating = false
        end

        local function install_hide_autocmds()
          local term = cmake_toggleterm.term
          if not (term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)) then
            return
          end

          local bufnr = term.bufnr
          local winid = term.window
          vim.api.nvim_clear_autocmds { group = group }

          local function cleanup()
            if cmake_toggleterm.term == term then
              terminate_runner(bufnr)
            end
          end

          vim.api.nvim_create_autocmd('WinLeave', {
            group = group,
            buffer = bufnr,
            once = true,
            callback = cleanup,
          })

          if winid and vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_create_autocmd('WinClosed', {
              group = group,
              pattern = tostring(winid),
              once = true,
              callback = cleanup,
            })
          end

          vim.api.nvim_create_autocmd({ 'BufHidden', 'BufWipeout' }, {
            group = group,
            buffer = bufnr,
            once = true,
            callback = cleanup,
          })
        end

        local original_run = cmake_toggleterm.run
        cmake_toggleterm.run = function(...)
          original_run(...)
          vim.schedule(install_hide_autocmds)
        end

        local original_close = cmake_toggleterm.close
        cmake_toggleterm.close = function(opts)
          terminate_runner(cmake_toggleterm.term and cmake_toggleterm.term.bufnr)
          pcall(original_close, opts)
        end

        cmake_toggleterm.stop = function()
          terminate_runner(cmake_toggleterm.term and cmake_toggleterm.term.bufnr)
        end
      end

      setup_cmake_runner_kill_on_hide()

      require('overseer').setup {
        task_list = {
          direction = 'right',
          bindings = {
            ['?'] = 'ShowHelp',
            ['g?'] = 'ShowHelp',
            ['<CR>'] = 'RunAction',
            ['<C-e>'] = 'Edit',
            ['o'] = 'Open',
            ['<C-v>'] = 'OpenVsplit',
            ['<C-s>'] = 'OpenSplit',
            ['<C-f>'] = 'OpenFloat',
            ['<C-q>'] = 'OpenQuickFix',
            ['p'] = 'TogglePreview',
            ['<C-l>'] = false,
            ['<C-h>'] = false,
            ['<A-l>'] = 'IncreaseDetail',
            ['<A-h>'] = 'DecreaseDetail',
            ['L'] = 'IncreaseAllDetail',
            ['H'] = 'DecreaseAllDetail',
            ['['] = 'DecreaseWidth',
            [']'] = 'IncreaseWidth',
            ['{'] = 'PrevTask',
            ['}'] = 'NextTask',
            ['<C-k>'] = false,
            ['<C-j>'] = false,
            ['<A-k>'] = 'ScrollOutputUp',
            ['<A-j>'] = 'ScrollOutputDown',
            ['q'] = 'Close',
          },
        },
      }
      local cmake_tools_dir = vim.fn.stdpath 'data' .. '/CMakeTools'
      local cmake_kits_path = cmake_tools_dir .. '/cmake-tools-kits.json'
      vim.fn.mkdir(cmake_tools_dir, 'p')
      if vim.fn.filereadable(cmake_kits_path) == 0 or table.concat(vim.fn.readfile(cmake_kits_path), '') == '[]' then
        vim.fn.writefile({
          '[',
          '  {',
          '    "name": "Apple Clang",',
          '    "compilers": {',
          '      "C": "/usr/bin/clang",',
          '      "CXX": "/usr/bin/clang++"',
          '    }',
          '  }',
          ']',
        }, cmake_kits_path)
      end

      require('cmake-tools').setup {
        cmake_command = 'cmake', -- this is used to specify cmake command path
        ctest_command = 'ctest',
        cmake_regenerate_on_save = true, -- auto generate when save CMakeLists.txt
        cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' }, -- this will be passed when invoke `CMakeGenerate`
        cmake_build_options = { '-j4' }, -- this will be passed when invoke `CMakeBuild`
        cmake_build_directory = 'out/${variant:buildType}', -- this is used to specify generate directory for cmake
        cmake_soft_link_compile_commands = true, -- this will automatically make a soft link from compile commands file to project root dir
        cmake_compile_commands_from_lsp = false, -- this will automatically set compile commands file location using lsp, to use it, please set `cmake_soft_link_compile_commands` to false
        cmake_kits_path = cmake_kits_path,
        cmake_variants_message = {
          short = { show = true }, -- whether to show short message
          long = { show = true, max_length = 40 }, -- whether to show long message
        },
        cmake_dap_configuration = { -- debug settings for cmake
          name = 'cpp',
          type = 'codelldb',
          request = 'launch',
          stopOnEntry = false,
          runInTerminal = true,
          console = 'integratedTerminal',
        },
        cmake_executor = { -- executor to use
          name = 'quickfix', -- name of the executor
          opts = {}, -- the options the executor will get, possible values depend on the executor type. See `default_opts` for possible values.
          default_opts = { -- a list of default and possible values for executors
            quickfix = {
              show = 'always', -- "always", "only_on_error"
              position = 'belowright', -- "bottom", "top"
              size = 10,
              auto_close_when_success = true, -- typically, you can use it with the true option; it will auto-close the quickfix buffer if the execution is successful.
            },
            toggleterm = {
              direction = 'float', -- 'vertical' | 'horizontal' | 'tab' | 'float'
              close_on_exit = false, -- whether close the terminal when exit
              auto_scroll = true, -- whether auto scroll to the bottom
            },
            overseer = {
              new_task_opts = {
                strategy = {
                  'toggleterm',
                  direction = 'horizontal',
                  autos_croll = true,
                  quit_on_exit = 'success',
                },
              }, -- options to pass into the `overseer.new_task` command
              on_new_task = function(_) end, -- a function that gets overseer.Task when it is created, before calling `task:start`
            },
            terminal = {
              name = 'Main Terminal',
              prefix_name = '[CMakeTools]: ', -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
              split_direction = 'horizontal', -- "horizontal", "vertical"
              split_size = 10,

              -- Window handling
              single_terminal_per_instance = true, -- Single instance, multiple windows
              single_terminal_per_tab = true, -- Single instance per tab
              keep_terminal_static_location = true, -- Static location of the viewport if avialable

              -- Running Tasks
              start_insert = false, -- If you want to enter terminal with :startinsert
              focus = false, -- Focus on cmake terminal when cmake task is launched.
              do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
            }, -- terminal executor uses the values in cmake_terminal
          },
        },
        cmake_runner = { -- runner to use
          name = 'toggleterm', -- name of the runner
          opts = {}, -- the options the runner will get, possible values depend on the runner type. See `default_opts` for possible values.
          default_opts = { -- a list of default and possible values for runners
            quickfix = {
              show = 'always', -- "always", "only_on_error"
              position = 'belowright', -- "bottom", "top"
              size = 10,
              encoding = 'utf-8',
              auto_close_when_success = false, -- typically, you can use it with the true option; it will auto-close the quickfix buffer if the execution is successful.
            },
            toggleterm = {
              direction = 'float', -- 'vertical' | 'horizontal' | 'tab' | 'float'
              close_on_exit = true, -- whether close the terminal when exit
              auto_scroll = true, -- whether auto scroll to the bottom
            },
            overseer = {
              new_task_opts = {
                strategy = {
                  'toggleterm',
                  direction = 'float',
                  autos_croll = true,
                },
              }, -- options to pass into the `overseer.new_task` command
              on_new_task = function(_) end, -- a function that gets overseer.Task when it is created, before calling `task:start`
            },
            terminal = {
              name = 'Runner Terminal',
              prefix_name = '[CMakeTools]: ', -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
              split_direction = 'horizontal', -- "horizontal", "vertical"
              split_size = 10,

              -- Window handling
              single_terminal_per_instance = true, -- Single instance, multiple windows
              single_terminal_per_tab = true, -- Single instance per tab
              keep_terminal_static_location = true, -- Static location of the viewport if avialable

              -- Running Tasks
              start_insert = true, -- If you want to enter terminal with :startinsert
              focus = true, -- Focus on cmake terminal when cmake task is launched.
              do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
            },
          },
        },
        cmake_notifications = {
          runner = { enabled = false },
          executor = { enabled = true },
          spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }, -- icons used for progress display
          refresh_rate_ms = 100, -- how often to iterate icons
        },
        cmake_virtual_text_support = true, -- Show the target related to current file using virtual text (at right corner)
      }
    end,
  },
}
