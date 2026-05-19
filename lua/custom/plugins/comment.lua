-- "gc" to comment visual regions/lines
return {
  'numToStr/Comment.nvim',
  keys = {
    { 'gc', mode = { 'n', 'v' } },
    { 'gcc', mode = 'n' },
    { 'gbc', mode = 'n' },
    { 'gb', mode = { 'n', 'v' } },
  },
  opts = {},
}
