local M = {}
local env = require 'custom.python.environment'

function M.setup()
  local dap = require 'dap'
  dap.adapters.python = {
    type = 'executable',
    command = env.tool_python(),
    args = { '-m', 'debugpy.adapter' },
    options = { source_filetype = 'python' },
  }
  dap.configurations.python = {
    {
      name = 'Python: current file',
      type = 'python',
      request = 'launch',
      program = vim.fn.stdpath 'config' .. '/scripts/python_run.py',
      args = function()
        local buf = env.source()
        return { env.root(buf), 'file', buf and vim.api.nvim_buf_get_name(buf) or '' }
      end,
      pythonPath = function()
        return env.python()
      end,
      cwd = function()
        return env.root()
      end,
      console = 'integratedTerminal',
      justMyCode = true,
    },
  }
end

function M.run(args, module)
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  if vim.fn.executable(env.tool_python()) ~= 1 then
    vim.notify('Missing debugpy tool environment: ' .. env.tool_python(), vim.log.levels.ERROR)
    return
  end
  M.setup()
  local root = env.root(buf)
  local config = {
    name = 'Python: ' .. (module or vim.fs.basename(vim.api.nvim_buf_get_name(buf))),
    type = 'python',
    request = 'launch',
    pythonPath = env.python(root),
    cwd = root,
    args = { root, module and 'module' or 'file', module or vim.api.nvim_buf_get_name(buf) },
    console = 'integratedTerminal',
    justMyCode = true,
  }
  vim.list_extend(config.args, args or {})
  config.program = vim.fn.stdpath 'config' .. '/scripts/python_run.py'
  require('dap').run(config)
end

function M.attach(address)
  local host, port = (address or '127.0.0.1:5678'):match '^([^:]+):(%d+)$'
  if not host then
    vim.notify('Use :PyDebugAttach host:port', vim.log.levels.ERROR)
    return
  end
  local dap = require 'dap'
  dap.adapters.python_attach = { type = 'server', host = host, port = tonumber(port) }
  dap.run { name = 'Python: attach', type = 'python_attach', request = 'attach', justMyCode = true }
end
return M
