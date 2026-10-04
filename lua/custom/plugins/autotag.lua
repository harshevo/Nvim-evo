return {
  'windwp/nvim-ts-autotag',
  ft = { 'html', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'xml' },
  config = function()
    require('nvim-ts-autotag').setup()
  end,
}
