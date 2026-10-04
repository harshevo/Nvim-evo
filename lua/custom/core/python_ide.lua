local M = {}
local function command(name, module, method, opts)
  vim.api.nvim_create_user_command(name, function(args)
    require(module)[method](args.args ~= '' and args.args or nil)
  end, opts or {})
end

vim.api.nvim_create_user_command('PyEnv', function(args)
  require('custom.python.environment').choose(args.fargs[1])
end, { nargs = '?', complete = 'file' })
command('PyEnvInfo', 'custom.python.environment', 'info')
command('PyRestart', 'custom.python.environment', 'restart')
command('PyVenv', 'custom.python.runtime', 'venv')
command('PySync', 'custom.python.runtime', 'sync')
command('PyCheck', 'custom.python.check', 'explicit', { nargs = '?' })
command('PyCheckToggle', 'custom.python.check', 'toggle')
command('PyCheckStop', 'custom.python.check', 'stop')
command('PyTypeCheck', 'custom.python.check', 'types')
command('PyAnalyze', 'custom.python.check', 'analyze')
command('PyTest', 'custom.python.testing', 'run', {
  nargs = '?',
  complete = function()
    return { 'file', 'nearest', 'select', 'last', 'failed' }
  end,
})
command('PyTestStop', 'custom.python.testing', 'stop')
command('PyTestInstall', 'custom.python.testing', 'install')
command('PyRepl', 'custom.python.runtime', 'repl')
command('PyDoc', 'custom.python.docs', 'open', { nargs = '?' })
command('PyReference', 'custom.python.docs', 'web', { nargs = '?' })
command('PyCommands', 'custom.python.commands', 'palette')
command('PySessionSave', 'custom.python.session', 'save')
command('PySessionLoad', 'custom.python.session', 'load')
vim.api.nvim_create_user_command('PyHelp', function()
  vim.cmd 'help python-workflow'
end, {})
for _, pair in ipairs { { 'PyRunModule', 'module', '+' }, { 'PyServe', 'serve', '*' } } do
  vim.api.nvim_create_user_command(pair[1], function(opts)
    require('custom.python.runtime')[pair[2]](opts.fargs)
  end, { nargs = pair[3] })
end
vim.api.nvim_create_user_command('PyDebug', function(opts)
  require('custom.python.debug').run(opts.fargs)
end, { nargs = '*' })
vim.api.nvim_create_user_command('PyDebugModule', function(opts)
  local module = table.remove(opts.fargs, 1)
  require('custom.python.debug').run(opts.fargs, module)
end, { nargs = '+' })
command('PyDebugAttach', 'custom.python.debug', 'attach', { nargs = '?' })
for _, pair in ipairs { { 'PyTestOutput', 'py-test' }, { 'PyAnalysisOutput', 'py-analysis' }, { 'PyTypeOutput', 'py-type' } } do
  vim.api.nvim_create_user_command(pair[1], function()
    require('custom.cpp.tasks').toggle(pair[2])
  end, {})
end
vim.api.nvim_create_user_command('PyAnalysisStop', function()
  require('custom.cpp.tasks').stop 'py-analysis'
  require('custom.cpp.tasks').stop 'py-type'
end, {})
vim.api.nvim_create_user_command('PyAnalysisQuickfix', function()
  local state = require('custom.cpp.tasks').states['py-analysis']
  vim.fn.setqflist({}, 'r', { title = 'Python Ruff findings', items = state and state.items or {} })
  vim.cmd 'botright copen 12'
end, {})

local maps = {
  { '<leader>pp', 'PyCommands', 'Python command palette' },
  { '<leader>pe', 'PyEnv', 'Select Python environment' },
  { '<leader>pE', 'PyEnvInfo', 'Show Python environment' },
  { '<leader>pv', 'PyVenv', 'Create Python .venv' },
  { '<leader>pS', 'PySync', 'Sync uv dependencies' },
  { '<leader>pr', 'PyRepl', 'Python REPL' },
  { '<leader>ps', 'PySessionSave', 'Save Python project session' },
  { '<leader>pl', 'PySessionLoad', 'Restore Python project session' },
  { '<leader>tt', 'PyTest', 'Run all pytest tests' },
  { '<leader>tF', 'PyTest file', 'Run current test file' },
  { '<leader>tn', 'PyTest nearest', 'Run nearest test' },
  { '<leader>ts', 'PyTest select', 'Select pytest test' },
  { '<leader>tl', 'PyTest last', 'Rerun last tests' },
  { '<leader>tf', 'PyTest failed', 'Rerun failed tests' },
  { '<leader>to', 'PyTestOutput', 'Toggle Python test output' },
  { '<leader>tq', 'PyTestStop', 'Stop Python tests' },
  { '<leader>cl', 'PyAnalyze', 'Analyze Python project with Ruff' },
  { '<leader>cT', 'PyTypeCheck', 'Check Python project types' },
  { '<leader>ao', 'PyAnalysisOutput', 'Toggle Python analysis output' },
  { '<leader>aq', 'PyAnalysisQuickfix', 'Python analysis findings in quickfix' },
  { '<leader>as', 'PyAnalysisStop', 'Stop Python analysis' },
  { '<leader>cm', 'PyDoc', 'Python API manual' },
  { '<leader>cR', 'PyReference', 'Search official Python documentation' },
  { '<leader>dc', 'DebugContinue', 'Debug Python / continue' },
}

function M.map(buf)
  for _, map in ipairs(maps) do
    vim.keymap.set('n', map[1], '<cmd>' .. map[2] .. '<CR>', { buffer = buf, desc = map[3], silent = true })
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  group = vim.api.nvim_create_augroup('PythonIDE', { clear = true }),
  callback = function(event)
    require('custom.python.environment').last_buf = event.buf
    vim.bo[event.buf].expandtab = true
    vim.bo[event.buf].shiftwidth = 4
    vim.bo[event.buf].softtabstop = 4
    vim.bo[event.buf].tabstop = 4
    M.map(event.buf)
    vim.keymap.set('n', 'K', function()
      require('custom.python.docs').hover()
    end, { buffer = event.buf, desc = 'Python signature and documentation' })
    vim.keymap.set('n', '<leader>cf', function()
      require('conform').format { bufnr = event.buf, async = true, lsp_format = 'never' }
    end, { buffer = event.buf, desc = 'Format Python with Ruff' })
    vim.keymap.set('n', '<leader>cw', function()
      require('telescope.builtin').lsp_dynamic_workspace_symbols()
    end, { buffer = event.buf, desc = 'Search Python project symbols' })
    vim.keymap.set('n', '<leader>cs', function()
      require('telescope.builtin').lsp_document_symbols()
    end, { buffer = event.buf, desc = 'Search Python file symbols' })
    vim.keymap.set('n', '<leader>cI', vim.lsp.buf.incoming_calls, { buffer = event.buf, desc = 'Python callers' })
    vim.keymap.set('n', '<leader>cO', vim.lsp.buf.outgoing_calls, { buffer = event.buf, desc = 'Python callees' })
  end,
})
return M
