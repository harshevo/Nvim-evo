local function command(name, callback, keys, description, opts)
  vim.api.nvim_create_user_command(name, callback, opts or {})
  if keys then
    vim.keymap.set('n', '<leader>' .. keys, '<cmd>' .. name .. '<CR>', { desc = description, silent = true })
  end
end

command('DebugContinue', function()
  local dap = require 'dap'
  if dap.session() then
    dap.continue()
    return
  end
  local buf = require('runner').source_buffer()
  if not buf then
    return
  end
  if vim.bo[buf].filetype == 'python' then
    require('custom.python.debug').run()
  else
    require('runner').debug()
  end
end, 'dc', 'Start debugger / continue')

for _, spec in ipairs {
  { 'DebugStepInto', 'step_into', 'di', 'Step into function' },
  { 'DebugStepOver', 'step_over', 'do', 'Step over line' },
  { 'DebugStepOut', 'step_out', 'dO', 'Step out of function' },
  { 'DebugPause', 'pause', 'dp', 'Pause running program' },
  { 'DebugStop', 'terminate', 'dq', 'Terminate debugger' },
  { 'DebugRestart', 'restart', 'dR', 'Restart debug session' },
  { 'DebugBreakpoint', 'toggle_breakpoint', 'db', 'Toggle breakpoint' },
  { 'DebugClearBreakpoints', 'clear_breakpoints', 'dx', 'Clear breakpoints' },
  { 'DebugRunToCursor', 'run_to_cursor', 'dn', 'Run to cursor' },
  { 'DebugFrameUp', 'up', 'dk', 'Select caller frame' },
  { 'DebugFrameDown', 'down', 'dj', 'Select callee frame' },
} do
  command(spec[1], function()
    require('dap')[spec[2]]()
    if package.loaded['custom.debug.views'] then
      vim.defer_fn(function()
        require('custom.debug.views').refresh()
      end, 50)
    end
  end, spec[3], spec[4])
end

command('DebugConditionalBreakpoint', function()
  vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(condition)
    if condition and condition ~= '' then
      require('dap').set_breakpoint(condition)
    end
  end)
end, 'dt', 'Conditional breakpoint')
command('DebugBreakpoints', function()
  require('dap').list_breakpoints()
  vim.cmd 'copen'
end, 'dB', 'List breakpoints')
command('DebugRepl', function()
  require('dap').repl.toggle()
end, 'dr', 'Toggle debugger REPL')
command('DebugScopes', function()
  local widgets = require 'dap.ui.widgets'
  widgets.centered_float(widgets.scopes)
end, 'ds', 'Inspect local variables')
command('DebugFrames', function()
  local widgets = require 'dap.ui.widgets'
  widgets.centered_float(widgets.frames)
end, 'df', 'Inspect stack frames')
command('DebugMemory', function(opts)
  require('custom.debug.views').memory(opts.args ~= '' and opts.args or nil)
end, 'dm', 'Toggle memory view', { nargs = '?' })
command('DebugMemoryExpression', function()
  require('custom.debug.views').choose_memory()
end, 'dM', 'Choose memory address / expression')
command('DebugAssembly', function()
  require('custom.debug.views').assembly()
end, 'da', 'Toggle assembly / Python bytecode')
command('DebugViewsRefresh', function()
  require('custom.debug.views').refresh()
end, 'dv', 'Refresh debugger views')
command('ValgrindToggle', function()
  require('custom.debug.memcheck').toggle()
end, 'vg', 'Toggle right memory-check sidebar')
command('ValgrindRun', function(opts)
  require('custom.debug.memcheck').run(opts.fargs)
end, 'vR', 'Rerun memory checks', { nargs = '*' })
command('ValgrindStop', function()
  require('custom.debug.memcheck').stop()
end, 'vq', 'Stop memory checking')
command('DebugHelp', function()
  vim.cmd 'help debug-workflow'
end, 'dh', 'Run / debugger shortcut guide')
vim.keymap.set('n', '<leader>S', '<cmd>RunStop<CR>', { desc = 'Stop program and close output', silent = true })
