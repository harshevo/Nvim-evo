vim.api.nvim_create_autocmd('User', {
  pattern = 'CMakeToolsEnterProject',
  callback = function(event) end,
})

vim.api.nvim_create_autocmd({ 'VimResized' }, {
  callback = function()
    vim.cmd 'tabdo wincmd ='
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function(event)
    vim.opt_local.cursorline = true

    local function select_quickfix_item(delta)
      local qf_win = vim.api.nvim_get_current_win()
      local qf_size = vim.fn.getqflist({ size = 0 }).size
      if qf_size == 0 then
        return
      end

      local row = vim.api.nvim_win_get_cursor(qf_win)[1] + delta
      if row < 1 then
        row = qf_size
      elseif row > qf_size then
        row = 1
      end

      vim.api.nvim_win_set_cursor(qf_win, { row, 0 })
    end

    vim.keymap.set('n', 'j', function()
      select_quickfix_item(1)
    end, { buffer = event.buf, silent = true, desc = 'Select next quickfix item' })

    vim.keymap.set('n', 'k', function()
      select_quickfix_item(-1)
    end, { buffer = event.buf, silent = true, desc = 'Select previous quickfix item' })

    vim.keymap.set('n', '<leader>b', '<cmd>BuildToggle<CR>', { buffer = event.buf, silent = true, desc = 'Close build quickfix' })
  end,
})
