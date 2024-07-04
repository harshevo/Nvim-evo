return {
  'ldelossa/litee.nvim',
  event = 'VeryLazy',
  opts = {
    notify = { enabled = false },
    panel = {
      orientation = 'right',
      panel_size = 30,
    },
  },
  config = function(_, opts)
    require('litee.lib').setup(opts)
  end,
}
