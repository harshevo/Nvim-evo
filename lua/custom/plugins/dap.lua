return {
  'mfussenegger/nvim-dap',
  lazy = true,
  cmd = { 'CppDebug' },
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
    dap.defaults.fallback.switchbuf = function(buf, line, column)
      local target
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == buf then
          target = win
          break
        end
        if not target and not vim.wo[win].winfixbuf and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' then
          target = win
        end
      end
      if target then
        vim.api.nvim_set_current_win(target)
      else
        vim.cmd 'topleft new'
      end
      vim.api.nvim_win_set_buf(0, buf)
      vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(buf)), math.max(0, column - 1) })
      vim.cmd 'normal! zv'
    end
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
    vim.keymap.set('n', '<leader>dB', function()
      dap.list_breakpoints()
      vim.cmd 'copen'
    end, { desc = 'Debug breakpoints' })
  end,
}
