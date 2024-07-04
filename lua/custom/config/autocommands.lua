vim.api.nvim_create_autocmd('User', {
  pattern = 'CMakeToolsEnterProject',
  callback = function(event) end,
})

vim.api.nvim_create_autocmd({ 'VimResized' }, {
  callback = function()
    vim.cmd 'tabdo wincmd ='
  end,
})
