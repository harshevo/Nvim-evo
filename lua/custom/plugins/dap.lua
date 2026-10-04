return {
  'mfussenegger/nvim-dap',
  lazy = true,
  cmd = { 'CppDebug' },
  keys = {
    {
      '<F6>',
      function()
        local dap = require 'dap'
        if dap.session() then
          dap.continue()
        else
          require('runner').debug()
        end
      end,
      desc = 'Build/debug or continue',
    },
    {
      '<F9>',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Toggle breakpoint',
    },
    {
      '<F10>',
      function()
        require('dap').step_over()
      end,
      desc = 'Step over',
    },
    {
      '<F11>',
      function()
        require('dap').step_into()
      end,
      desc = 'Step into',
    },
    {
      '<S-F11>',
      function()
        require('dap').step_out()
      end,
      desc = 'Step out',
    },
    { '<leader>dc', '<cmd>CppDebug<CR>', desc = 'Build and debug C/C++' },
  },
  config = function()
    local dap = require 'dap'
    local adapter = vim.fn.exepath 'lldb-dap'
    if adapter == '' then
      for _, path in ipairs { '/opt/homebrew/opt/llvm/bin/lldb-dap', '/usr/local/opt/llvm/bin/lldb-dap', '/Library/Developer/CommandLineTools/usr/bin/lldb-dap' } do
        if vim.fn.executable(path) == 1 then
          adapter = path
          break
        end
      end
    end
    dap.adapters.lldb = { type = 'executable', command = adapter, name = 'lldb', options = { initialize_timeout_sec = 30 } }
    dap.defaults.fallback.terminal_win_cmd = 'botright 12new'
    dap.defaults.fallback.focus_terminal = false
    vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })
    vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticWarn', linehl = 'Visual' })
    dap.configurations.cpp = {
      {
        name = 'Launch executable',
        type = 'lldb',
        request = 'launch',
        cwd = '${workspaceFolder}',
        program = function()
          local path = vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file')
          return path ~= '' and path or dap.ABORT
        end,
        runInTerminal = true,
      },
    }
    dap.configurations.c = dap.configurations.cpp
    vim.api.nvim_create_user_command('CppDebug', function()
      require('runner').debug()
    end, { desc = 'Save, rebuild and launch LLDB' })
    vim.keymap.set('n', '<leader>df', function()
      local widgets = require 'dap.ui.widgets'
      widgets.centered_float(widgets.frames)
    end, { desc = 'Debug stack frames' })
    vim.keymap.set('n', '<leader>db', function()
      dap.list_breakpoints()
      vim.cmd 'copen'
    end, { desc = 'Debug breakpoints' })
  end,
}
