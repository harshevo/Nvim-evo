return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 200,
    triggers = { { '<leader>', mode = 'n' } },
    icons = { mappings = false },
    spec = {
      { '<leader>a', group = 'Analysis' },
      { '<leader>c', group = 'Code / documentation' },
      { '<leader>d', group = 'Debug' },
      { '<leader>f', group = 'Find' },
      { '<leader>h', group = 'Git / bookmarks' },
      { '<leader>m', group = 'Build / format' },
      { '<leader>p', group = 'Project / commands' },
      { '<leader>t', group = 'Tests / toggles' },
      { '<leader>s', group = 'Search / splits' },
      { '<leader>v', group = 'Valgrind / memory checks' },
    },
  },
}
