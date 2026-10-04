vim.api.nvim_create_autocmd({ 'VimResized' }, {
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.cmd 'tabdo wincmd ='
    vim.api.nvim_set_current_tabpage(tab)
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function(event)
    vim.opt_local.cursorline = true
    vim.keymap.set('n', 'q', '<cmd>cclose<CR>', { buffer = event.buf, silent = true })
    vim.keymap.set('n', '<Esc>', '<cmd>cclose<CR>', { buffer = event.buf, silent = true })
    vim.keymap.set('n', 'o', '<CR>', { buffer = event.buf, remap = true, silent = true })

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

    vim.keymap.set('n', '<leader>b', '<cmd>BuildToggle<CR>', { buffer = event.buf, silent = true, nowait = true, desc = 'Close build quickfix' })
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  callback = function(args)
    require('custom.cpp.language').setup_buffer(args.buf)
  end,
})
vim.api.nvim_create_user_command('CppRestart', function()
  require('custom.cpp.language').restart()
end, {})
vim.api.nvim_create_user_command('CppHelp', function()
  vim.cmd 'help cpp-workflow'
end, {})
vim.api.nvim_create_user_command('CppMan', function(opts)
  require('custom.cpp.docs').manual(opts.args ~= '' and opts.args or nil)
end, { nargs = '?' })
vim.api.nvim_create_user_command('CppReference', function(opts)
  require('custom.cpp.docs').reference(opts.args ~= '' and opts.args or nil)
end, { nargs = '?' })
