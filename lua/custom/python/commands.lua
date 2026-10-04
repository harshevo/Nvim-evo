local M = {}
M.entries = {
  { 'Open Python guide', 'PyHelp' },
  { 'Run current Python file', 'RunNow' },
  { 'Run project command', 'RunBuild' },
  { 'Stop run process', 'RunStop' },
  { 'Toggle Python errors', 'PyCheckToggle' },
  { 'Check whole project', 'PyCheck project' },
  { 'Choose Python environment', 'PyEnv' },
  { 'Show Python environment', 'PyEnvInfo' },
  { 'Create .venv with uv', 'PyVenv' },
  { 'Sync uv project dependencies', 'PySync' },
  { 'Install pytest in selected environment', 'PyTestInstall' },
  { 'Run all tests', 'PyTest' },
  { 'Run current test file', 'PyTest file' },
  { 'Run nearest test', 'PyTest nearest' },
  { 'Select a pytest test', 'PyTest select' },
  { 'Rerun failed tests', 'PyTest failed' },
  { 'Rerun last tests', 'PyTest last' },
  { 'Toggle test output', 'PyTestOutput' },
  { 'Stop tests/discovery', 'PyTestStop' },
  { 'Run project Ruff analysis', 'PyAnalyze' },
  { 'Check project types', 'PyTypeCheck' },
  { 'Debug current file', 'DebugContinue' },
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
  { 'Open Python REPL', 'PyRepl' },
  { 'Start uvicorn development server', 'PyServe' },
  { 'Open runtime API documentation', 'PyDoc' },
  { 'Search Python documentation online', 'PyReference' },
  { 'Save Python project session', 'PySessionSave' },
  { 'Restore Python project session', 'PySessionLoad' },
  { 'Search all shortcuts', 'Telescope keymaps' },
  { 'Search project symbols', 'Telescope lsp_dynamic_workspace_symbols' },
}

function M.palette()
  local actions = require 'telescope.actions'
  require('telescope.pickers')
    .new({}, {
      prompt_title = 'Python commands',
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
