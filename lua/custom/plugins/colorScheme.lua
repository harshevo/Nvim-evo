return {
  -- --3rd
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      local transparent = false -- set to true if you would like to enable transparency

      local bg = '#151515'
      local bg_dark = '#161616'
      local side_bar = '#131313'
      local bg_highlight = '#30293A'
      local bg_search = '#393939'
      local bg_visual = '#30293A'
      local fg = '#EEEEEE'
      local fg_dark = '#EEEEEE'
      local fg_gutter = '#393939'
      local border = '#393939'

      require('tokyonight').setup {
        style = 'night',
        transparent = transparent,
        styles = {
          sidebars = transparent and 'transparent' or 'dark',
          floats = transparent and 'transparent' or 'dark',
        },
        on_colors = function(colors)
          colors.bg = bg
          colors.bg_dark = transparent and colors.none or bg_dark
          colors.bg_float = transparent and colors.none or bg_dark
          colors.bg_highlight = bg_highlight
          colors.bg_popup = bg_dark
          colors.bg_search = bg_search
          colors.bg_sidebar = transparent and colors.none or side_bar
          colors.bg_statusline = transparent and colors.none or bg_dark
          colors.bg_visual = bg_visual
          colors.border = border
          colors.fg = fg
          colors.fg_dark = fg_dark
          colors.bg_float = '#131313'
          colors.fg_float = '#EEEEEE'
          colors.fg_gutter = fg_gutter
          colors.bg_statusline = '#131313'
          colors.fg_sidebar = fg_dark
        end,

        -- on_highlights = function(hl, colors)
        --   hl.keywords = { fg = bg_search }
        --   hl.Function = { fg = '#ffffff' }
        --   hl.Variables = { fg = '#ffffff' }
        -- end,
      }
      vim.cmd 'colorscheme tokyonight'
    end,
  },
  --
  -- --
  -- --     vim.cmd 'colorscheme tokyonight-night'
  -- --   end,
  -- -- },
  --
  -- -- {
  -- --   'catppuccin/nvim',
  -- --   name = 'catppuccin',
  -- --   priority = 1000,
  -- --   config = function()
  -- --     require('catppuccin').setup {
  -- --       flavour = 'auto', -- latte, frappe, macchiato, mocha
  -- --       background = { -- :h background
  -- --         light = 'latte',
  -- --         dark = 'mocha',
  -- --       },
  -- --       transparent_background = false, -- disables setting the background color.
  -- --       show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
  -- --       term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
  -- --       dim_inactive = {
  -- --         enabled = false, -- dims the background color of inactive window
  -- --         shade = 'dark',
  -- --         percentage = 0.15, -- percentage of the shade to apply to the inactive window
  -- --       },
  -- --       no_italic = false, -- Force no italic
  -- --       no_bold = false, -- Force no bold
  -- --       no_underline = false, -- Force no underline
  -- --       styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
  -- --         comments = { 'italic' }, -- Change the style of comments
  -- --         -- conditionals = { 'italic' },
  -- --         loops = {},
  -- --         functions = {},
  -- --         keywords = {},
  -- --         strings = {},
  -- --         variables = {},
  -- --         numbers = {},
  -- --         booleans = {},
  -- --         properties = {},
  -- --         types = {},
  -- --         operators = {},
  -- --         -- miscs = {}, -- Uncomment to turn off hard-coded styles
  -- --       },
  -- --       color_overrides = {},
  -- --       custom_highlights = {},
  -- --       default_integrations = true,
  -- --       integrations = {
  -- --         telescope = true,
  -- --         cmp = true,
  -- --         gitsigns = true,
  -- --         nvimtree = true,
  -- --         treesitter = true,
  -- --         notify = false,
  -- --         mini = {
  -- --           enabled = true,
  -- --           indentscope_color = '',
  -- --         },
  -- --       },
  -- --     }
  -- --     vim.cmd.colorscheme 'catppuccin'
  -- --   end,
  -- -- },
  -- --
  --
  -- {
  --   'EdenEast/nightfox.nvim',
  --   lazy = false,
  --   config = function()
  --     vim.cmd.colorscheme 'duskfox'
  --   end,
  -- },
  --
  -- -- {
  -- --   'Everblush/nvim',
  -- --   name = 'everblush',
  -- --   config = function()
  -- --     vim.cmd.colorscheme 'everblush'
  -- --   end,
  -- -- },
  -- --
  -- -- {
  -- --   'oxfist/night-owl.nvim',
  -- --   lazy = false, -- make sure we load this during startup if it is your main colorscheme
  -- --   priority = 1000, -- make sure to load this before all the other start plugins
  -- --   config = function()
  -- --     -- load the colorscheme here
  -- --     require('night-owl').setup()
  -- --     vim.cmd.colorscheme 'night-owl'
  -- --   end,
  -- -- },
  --
  -- -- {
  -- --   'rose-pine/neovim',
  -- --   name = 'rose-pine',
  -- --
  -- --   config = function()
  -- --     require('rose-pine').setup {
  -- --       variant = 'auto',
  -- --
  -- --       styles = {
  -- --         bold = false,
  -- --         italic = false,
  -- --         transparency = false,
  -- --       },
  -- --     }
  -- --     vim.cmd.colorscheme 'rose-pine'
  -- --   end,
  -- -- },

  -- {
  --   'projekt0n/github-nvim-theme',
  --   lazy = false, -- make sure we load this during startup if it is your main colorscheme
  --   priority = 1000, -- make sure to load this before all the other start plugins
  --   config = function()
  --     require('github-theme').setup {}
  --
  --     vim.cmd 'colorscheme github_dark'
  --   end,
  -- },

  -- {
  --   'blazkowolf/gruber-darker.nvim',
  --   config = function()
  --     require('gruber-darker').setup {
  --       bold = false,
  --     }
  --     vim.cmd 'colorscheme gruber-darker'
  --   end,
  -- },

  -- {
  --   'slugbyte/lackluster.nvim',
  --   config = function()
  --     vim.cmd.colorscheme 'lackluster'
  --   end,
  -- },
}
