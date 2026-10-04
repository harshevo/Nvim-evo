local M = {}

function M.reference(symbol)
  symbol = symbol or vim.fn.expand '<cword>'
  local query = symbol:gsub('[^%w%-_%.~]', function(c)
    return string.format('%%%02X', string.byte(c))
  end)
  vim.ui.open('https://en.cppreference.com/mwiki/index.php?search=' .. query)
end

function M.manual(symbol)
  symbol = symbol or vim.fn.expand '<cword>'
  if not symbol:match '^[%w_][%w_.:+-]*$' then
    return
  end
  local origin = vim.api.nvim_get_current_win()
  local sections = { '3', '2', '' }
  local function lookup(index)
    if not sections[index] then
      vim.notify('No system manual for ' .. symbol .. '; use Space cR for cppreference', vim.log.levels.INFO)
      return
    end
    local section = sections[index]
    local args = { 'man', '-w' }
    if section ~= '' then
      args[#args + 1] = section
    end
    args[#args + 1] = symbol
    vim.system(args, { text = true }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          lookup(index + 1)
          return
        end
        if not vim.api.nvim_win_is_valid(origin) then
          return
        end
        vim.api.nvim_set_current_win(origin)
        vim.cmd('botright Man ' .. (section ~= '' and section .. ' ' or '') .. vim.fn.fnameescape(symbol))
      end)
    end)
  end
  lookup(1)
end

function M.hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'clangd' })[1]
  if not client then
    M.manual()
    return
  end
  -- Use the native handler for focus-on-second-K, markdown and signature rendering.
  vim.lsp.buf.hover { border = 'rounded', max_width = 100, max_height = 24 }
end

return M
