return {
  {
    'kndndrj/nvim-dbee',
    enabled = false,
    dependencies = { 'MunifTanjim/nui.nvim' },
    build = function()
      require('dbee').install()
    end,
    config = function()
      -- local source = require 'dbee.sources'
      require('dbee').setup {
        -- sources = {
        --   source.MemorySource:new({
        --     ---@diagnostic disable-next-line: missing-fields
        --     {
        --       type = 'postgres',
        --       name = 'postgres',
        --       url = 'postgresql://postgres:postgres@localhost:5432/',
        --     },
        --   }, 'postgres'),
        -- },
      }
      require 'custom.dbee'
    end,
  },
}
