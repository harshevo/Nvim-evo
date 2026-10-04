local function command(name, module, method, opts)
  vim.api.nvim_create_user_command(name, function(args)
    require(module)[method](args.args ~= '' and args.args or nil)
  end, opts or {})
end
command('CppCommands', 'custom.cpp.commands', 'palette')
vim.api.nvim_create_user_command('CppConfigure', function()
  local project = require 'custom.cpp.project'
  project.choose((project.selected(project.root()) or {}).preset)
end, {})
vim.api.nvim_create_user_command('CppTarget', function()
  require('runner').select_target()
end, {})
command('CppPreset', 'custom.cpp.project', 'choose', { nargs = '?', desc = 'Select, configure and activate a CMake preset' })
command('CppIndexConfig', 'custom.cpp.project', 'index_config')
command('CppPresetsInit', 'custom.cpp.project', 'init_presets')
command('CppTest', 'custom.cpp.testing', 'run', {
  nargs = '?',
  complete = function()
    return { 'select', 'failed', 'last' }
  end,
})
command('CppTestOutput', 'custom.cpp.testing', 'toggle')
command('CppTestStop', 'custom.cpp.testing', 'stop')
command('CppAnalyze', 'custom.cpp.analysis', 'run')
command('CppAnalysisQuickfix', 'custom.cpp.analysis', 'quickfix')
command('CppSessionSave', 'custom.cpp.session', 'save')
command('CppSessionLoad', 'custom.cpp.session', 'load')
vim.api.nvim_create_user_command('CppAnalysisOutput', function()
  require('custom.cpp.tasks').toggle 'analysis'
end, {})
vim.api.nvim_create_user_command('CppAnalysisStop', function()
  require('custom.cpp.tasks').stop 'analysis'
end, {})
vim.api.nvim_create_user_command('CppCacheStats', function()
  require('custom.cpp.tasks').run('cache', { 'ccache', '--show-stats' }, vim.fn.getcwd(), { open = true, title = 'Compiler cache statistics' })
end, {})
local maps = {
  { '<leader>pp', 'CppCommands', 'C/C++ command palette' },
  { '<leader>fk', 'Telescope keymaps', 'Search all shortcuts' },
  { '<leader>mP', 'CppPreset', 'Select build preset' },
  { '<leader>mI', 'CppPresetsInit', 'Create local build presets' },
  { '<leader>mC', 'CppCacheStats', 'Compiler cache statistics' },
  { '<leader>tt', 'CppTest', 'Build and run all tests' },
  { '<leader>ts', 'CppTest select', 'Select and run test' },
  { '<leader>tl', 'CppTest last', 'Rerun last test selection' },
  { '<leader>tf', 'CppTest failed', 'Rerun failed tests' },
  { '<leader>to', 'CppTestOutput', 'Toggle test output' },
  { '<leader>tq', 'CppTestStop', 'Stop test process' },
  { '<leader>cl', 'CppAnalyze', 'Analyze current file with clang-tidy' },
  { '<leader>ao', 'CppAnalysisOutput', 'Toggle analysis output' },
  { '<leader>aq', 'CppAnalysisQuickfix', 'Analysis findings in quickfix' },
  { '<leader>as', 'CppAnalysisStop', 'Stop clang-tidy' },
  { '<leader>ps', 'CppSessionSave', 'Save project files and window layout' },
  { '<leader>pl', 'CppSessionLoad', 'Restore project session' },
}
for _, map in ipairs(maps) do
  vim.keymap.set('n', map[1], '<cmd>' .. map[2] .. '<CR>', { desc = map[3], silent = true })
end
