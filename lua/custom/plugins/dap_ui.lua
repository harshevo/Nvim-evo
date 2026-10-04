return {
  'rcarriga/nvim-dap-ui',
  lazy = true,
  dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
  cmd = { 'CppDebugUI' },
  keys = {
    { '<leader>du', '<cmd>CppDebugUI<CR>', desc = 'Toggle debugger layout' },
    {
      '<leader>de',
      function()
        require('dapui').eval()
      end,
      mode = { 'n', 'v' },
      desc = 'Evaluate expression',
    },
  },
  config = function()
    local ui = require 'dapui'
    ui.setup {
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.35 },
            { id = 'watches', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'breakpoints', size = 0.15 },
          },
          size = 40,
          position = 'left',
        },
        { elements = { { id = 'repl', size = 0.5 }, { id = 'console', size = 0.5 } }, size = 10, position = 'bottom' },
      },
      controls = { enabled = true },
      floating = { border = 'rounded' },
    }
    vim.api.nvim_create_user_command('CppDebugUI', function()
      ui.toggle()
    end, {})
  end,
}
