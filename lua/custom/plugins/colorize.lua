return {
  'norcalli/nvim-colorizer.lua',
  ft = { 'css', 'javascript', 'html', 'lua' },
  config = function()
    require('colorizer').setup {
      'css',
      'javascript',
      'html',
      'lua',
    }
  end,
}
