return {
  {
    'ldelossa/litee-calltree.nvim',
    dependencies = 'ldelossa/litee.nvim',
    event = 'VeryLazy',
    opts = {
      on_open = 'panel',
      map_resize_keys = true,
    },
    config = function(_, opts)
      require('litee.calltree').setup(opts)
    end,
  },
}
