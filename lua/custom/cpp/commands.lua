local M = {}
M.entries = {
  { 'Open C/C++ guide', 'CppHelp' },
  { 'Run current file', 'RunNow' },
  { 'Rebuild and run project', 'RunBuild' },
  { 'Toggle compiler errors', 'BuildToggle' },
  { 'Build project', 'BuildNow' },
  { 'Stop running program/build', 'RunStop' },
  { 'Choose build preset', 'CppPreset' },
  { 'Configure active build preset', 'CppConfigure' },
  { 'Select executable target', 'CppTarget' },
  { 'Create local build presets', 'CppPresetsInit' },
  { 'Run all tests', 'CppTest' },
  { 'Select a test', 'CppTest select' },
  { 'Rerun failed tests', 'CppTest failed' },
  { 'Rerun last test selection', 'CppTest last' },
  { 'Toggle test output', 'CppTestOutput' },
  { 'Run clang-tidy', 'CppAnalyze' },
  { 'Toggle analysis output', 'CppAnalysisOutput' },
  { 'Analysis findings in quickfix', 'CppAnalysisQuickfix' },
  { 'Build and debug project', 'DebugContinue' },
  { 'Toggle debug panels', 'CppDebugUI' },
  { 'Debug shortcut guide', 'DebugHelp' },
  { 'Step into', 'DebugStepInto' },
  { 'Step over', 'DebugStepOver' },
  { 'Step out', 'DebugStepOut' },
  { 'Pause debugger', 'DebugPause' },
  { 'Stop debugger', 'DebugStop' },
  { 'Toggle memory view', 'DebugMemory' },
  { 'Choose memory expression', 'DebugMemoryExpression' },
  { 'Toggle assembly / Python bytecode', 'DebugAssembly' },
  { 'Toggle right memory-check sidebar', 'ValgrindToggle' },
  { 'Rerun memory checks', 'ValgrindRun' },
  { 'Stop memory checks', 'ValgrindStop' },
  { 'Save project session', 'CppSessionSave' },
  { 'Restore project session', 'CppSessionLoad' },
  { 'Restart clangd', 'CppRestart' },
  { 'Open symbol manual', 'CppMan' },
  { 'Search system manuals', 'ManSearch' },
  { 'Search cppreference', 'CppReference' },
  { 'Search every shortcut', 'Telescope keymaps' },
  { 'Search project symbols', 'Telescope lsp_dynamic_workspace_symbols' },
  { 'Compiler cache statistics', 'CppCacheStats' },
  { 'Exclude generated directories from indexing', 'CppIndexConfig' },
}
function M.palette()
  local actions = require 'telescope.actions'
  require('telescope.pickers')
    .new({}, {
      prompt_title = 'C/C++ commands',
      finder = require('telescope.finders').new_table {
        results = M.entries,
        entry_maker = function(entry)
          local label = entry[1] .. '  :' .. entry[2]
          return { value = entry, display = label, ordinal = label }
        end,
      },
      sorter = require('telescope.config').values.generic_sorter {},
      attach_mappings = function()
        actions.select_default:replace(function(buf)
          local selection = require('telescope.actions.state').get_selected_entry()
          actions.close(buf)
          if selection then
            vim.cmd(selection.value[2])
          end
        end)
        return true
      end,
    })
    :find()
end
return M
