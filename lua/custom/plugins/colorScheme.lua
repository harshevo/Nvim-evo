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
  -- 'tiagovla/tokyodark.nvim',
  -- opts = {},
  -- config = function(_, opts)
  --   require('tokyodark').setup(opts) -- calling setup is optional
  --   vim.cmd [[colorscheme tokyodark]]
  -- end,
  -- config = function()
  --   require('catppuccin').setup {
  --     flavour = 'mocha', -- latte, frappe, macchiato, mocha
  --     term_colors = true,
  --     transparent_background = false,
  --     no_italic = false,
  --     no_bold = false,
  --     styles = {
  --       comments = {},
  --       conditionals = {},
  --       loops = {},
  --       functions = {},
  --       keywords = {},
  --       strings = {},
  --       variables = {},
  --       numbers = {},
  --       booleans = {},
  --       properties = {},
  --       types = {},
  --     },
  --     color_overrides = {
  --       mocha = {
  --         base = '#000000',
  --         mantle = '#000000',
  --         crust = '#000000',
  --       },
  --     },
  --     highlight_overrides = {
  --       mocha = function(C)
  --         return {
  --           TabLineSel = { bg = C.pink },
  --           CmpBorder = { fg = C.surface2 },
  --           Pmenu = { bg = C.none },
  --           TelescopeBorder = { link = 'FloatBorder' },
  --         }
  --       end,
  --     },
  --   }
  --
  --   vim.cmd.colorscheme 'catppuccin'
  -- end,
  --

  --3rd
  'folke/tokyonight.nvim',
  lazy = false,
  priority = 1000,
  config = function()
    local bg = '#000000'
    local bg_dark = '#000000'
    require('tokyonight').setup {
      style = 'night',
      transparent = false,
      on_colors = function(colors)
        colors.bg = bg
        colors.bg_dark = bg_dark
        colors.bg_popup = bg_dark
        colors.bg_float = bg_dark
        colors.bg_sidebar = bg_dark
      end,
    }

    vim.cmd 'colorscheme tokyonight-night'
  end,

  -- 4th
  -- 'EdenEast/nightfox.nvim',
  -- lazy = false,
  -- priority = 1000,
  -- config = function()
  --   require('nightfox').setup {
  --     options = {
  --       transparent = false,
  --     },
  --   }
  --   vim.cmd.colorscheme 'carbonfox'
  -- end,

  --5th
  -- 'folke/tokyonight.nvim',
  -- priority = 1000,
  -- config = function()
  --   local bg = '#011628'
  --   local bg_dark = '#011423'
  --   local bg_highlight = '#143652'
  --   local bg_search = '#0A64AC'
  --   local bg_visual = '#275378'
  --   local fg = '#CBE0F0'
  --   local fg_dark = '#B4D0E9'
  --   local fg_gutter = '#627E97'
  --   local border = '#547998'
  --
  --   require('tokyonight').setup {
  --     style = 'night',
  --     -- transparent = true,
  --     on_colors = function(colors)
  --       colors.bg = bg
  --       colors.bg_dark = bg_dark
  --       colors.bg_float = bg_dark
  --       colors.bg_highlight = bg_highlight
  --       colors.bg_popup = bg_dark
  --       colors.bg_search = bg_search
  --       colors.bg_sidebar = bg_dark
  --       colors.bg_statusline = bg_dark
  --       colors.bg_visual = bg_visual
  --       colors.border = border
  --       colors.fg = fg
  --       colors.fg_dark = fg_dark
  --       colors.fg_float = fg
  --       colors.fg_gutter = fg_gutter
  --       colors.fg_sidebar = fg_dark
  --     end,
  --   }
  --
  --   vim.cmd 'colorscheme tokyonight-night'
  -- end,

  --6th
  -- 'dasupradyumna/midnight.nvim',
  -- lazy = false,
  -- priority = 1000,
  -- config = function()
  --   vim.cmd.colorscheme 'midnight'
  -- end,
}
