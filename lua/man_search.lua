local M = {}
local cache, loading

local function picker(entries)
  local actions = require 'telescope.actions'
  require('telescope.pickers')
    .new({}, {
      prompt_title = 'System manuals',
      finder = require('telescope.finders').new_table {
        results = entries,
        entry_maker = function(entry)
          return { value = entry, display = entry.display, ordinal = entry.display }
        end,
      },
      sorter = require('telescope.config').values.generic_sorter {},
      attach_mappings = function()
        actions.select_default:replace(function(bufnr)
          local entry = require('telescope.actions.state').get_selected_entry()
          actions.close(bufnr)
          if entry then
            vim.cmd('Man ' .. entry.value.section .. ' ' .. vim.fn.fnameescape(entry.value.name))
          end
        end)
        return true
      end,
    })
    :find()
end

function M.search_man_pages(refresh)
  if cache and not refresh then
    picker(cache)
    return
  end
  if loading then
    return
  end
  loading = true
  vim.system({ 'man', '-k', '.' }, { text = true }, function(result)
    vim.schedule(function()
      loading = false
      cache = {}
      for line in (result.stdout or ''):gmatch '[^\n]+' do
        local name = line:match '^([^,%s%(]+)'
        local section = line:match '%(([%w]+)%)'
        if name and section then
          cache[#cache + 1] = { name = name, section = section, display = line }
        end
      end
      if #cache == 0 then
        vim.notify('No manual index found', vim.log.levels.WARN)
        return
      end
      picker(cache)
    end)
  end)
end

vim.keymap.set('n', '<leader>fm', function()
  M.search_man_pages()
end, { desc = 'Search system manuals' })
vim.api.nvim_create_user_command('ManSearch', function(opts)
  M.search_man_pages(opts.bang)
end, { bang = true })
return M
