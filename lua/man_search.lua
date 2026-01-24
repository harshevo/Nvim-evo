local M = {}

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

-- Run apropos and normalize entries
local function get_man_entries()
  local handle = io.popen 'man -k .'
  if not handle then
    return {}
  end

  local results = {}

  for line in handle:lines() do
    -- Example:
    -- kill, pkill, skill (1) - send signals to processes
    -- Extract canonical name: kill
    local name = line:match '^([^,%s]+)'
    local desc = line:match '%-%s+(.*)$'

    if name and desc then
      table.insert(results, {
        name = name,
        display = name .. ' — ' .. desc,
      })
    end
  end

  handle:close()
  return results
end

function M.search_man_pages()
  local entries = get_man_entries()

  pickers
    .new({}, {
      prompt_title = 'Man Pages',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry.name,
            display = entry.display,
            ordinal = entry.display,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(_, map)
        actions.select_default:replace(function(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection and selection.value then
            vim.cmd('Man ' .. selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

-- Keybinding
vim.keymap.set('n', '<leader>m', M.search_man_pages, {
  desc = 'Search man pages (Telescope)',
})

return M
