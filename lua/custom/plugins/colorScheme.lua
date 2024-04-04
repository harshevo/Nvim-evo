-- Theme
return {
  -- 1st
  -- Theme inspired by Atom
  -- 'navarasu/onedark.nvim',
  -- priority = 1000,
  -- config = function()
  --   vim.cmd.colorscheme 'onedark'
  -- end,

  -- 2nd
  -- "tiagovla/tokyodark.nvim",
  -- opts = {
  -- },
  -- config = function(_, opts)
  --     require("tokyodark").setup(opts) -- calling setup is optional
  --     vim.cmd [[colorscheme tokyodark]]
  -- end,
  -- config = function()
  --     require("catppuccin").setup {
  --         flavour = "mocha", -- latte, frappe, macchiato, mocha
  --         term_colors = true,
  --         transparent_background = false,
  --         no_italic = false,
  --         no_bold = false,
  --         styles = {
  --             comments = {},
  --             conditionals = {},
  --             loops = {},
  --             functions = {},
  --             keywords = {},
  --             strings = {},
  --             variables = {},
  --             numbers = {},
  --             booleans = {},
  --             properties = {},
  --             types = {},
  --         },
  --         color_overrides = {
  --             mocha = {
  --                 base = "#000000",
  --                 mantle = "#000000",
  --                 crust = "#000000",
  --             },
  --         },
  --         highlight_overrides = {
  --             mocha = function(C)
  --                 return {
  --                     TabLineSel = { bg = C.pink },
  --                     CmpBorder = { fg = C.surface2 },
  --                     Pmenu = { bg = C.none },
  --                     TelescopeBorder = { link = "FloatBorder" },
  --                 }
  --             end,
  --         },
  --     }
  --
  --     vim.cmd.colorscheme "catppuccin"
  -- end,
  --

  --3rd
  -- "folke/tokyonight.nvim",
  -- lazy = false,
  -- priority = 1000,
  -- config = function()
  --   vim.cmd.colorscheme 'tokyonight-night'
  -- end,
  --
  --
  -- 4th
  'EdenEast/nightfox.nvim',
  lazy = false,
  priority = 1000,
  config = function()
    vim.cmd.colorscheme 'carbonfox'
  end,
}
