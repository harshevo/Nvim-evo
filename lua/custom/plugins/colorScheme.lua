return {
  -- --3rd
  -- {
  --   'folke/tokyonight.nvim',
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     local bg = '#19181A'
  --     local bg_dark = '#19181A'
  --     local bg_sidebar = '#00000F'
  --     local border = '#19181E'
  --     require('tokyonight').setup {
  --       style = 'moon',
  --       transparent = false,
  --       terminal_colors = true,
  --       styles = {
  --         comments = { italic = true },
  --       },
  --       on_colors = function(colors)
  --         colors.bg = bg
  --         colors.bg_dark = bg_dark
  --         colors.bg_popup = bg_dark
  --         colors.bg_float = border
  --         colors.bg_sidebar = bg_sidebar
  --       end,
  --     }
  --
  --     vim.cmd 'colorscheme tokyonight-night'
  --   end,
  -- },

  -- {
  --   'tjdevries/colorbuddy.nvim',
  --   lazy = false,
  --   config = function()
  --     vim.cmd.colorscheme 'gruvbuddy'
  --   end,
  -- },
  --
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup {
        flavour = 'auto', -- latte, frappe, macchiato, mocha
        background = { -- :h background
          light = 'latte',
          dark = 'macchiato',
        },
        transparent_background = false, -- disables setting the background color.
        show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
        term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
        dim_inactive = {
          enabled = false, -- dims the background color of inactive window
          shade = 'dark',
          percentage = 0.15, -- percentage of the shade to apply to the inactive window
        },
        no_italic = false, -- Force no italic
        no_bold = false, -- Force no bold
        no_underline = false, -- Force no underline
        styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
          comments = { 'italic' }, -- Change the style of comments
          -- conditionals = { 'italic' },
          loops = {},
          functions = {},
          keywords = {},
          strings = {},
          variables = {},
          numbers = {},
          booleans = {},
          properties = {},
          types = {},
          operators = {},
          -- miscs = {}, -- Uncomment to turn off hard-coded styles
        },
        color_overrides = {
          macchiato = {
            rosewater = '#F5B8AB',
            flamingo = '#F29D9D',
            pink = '#AD6FF7',
            mauve = '#FF8F40',
            red = '#E66767',
            maroon = '#EB788B',
            peach = '#FAB770',
            yellow = '#FACA64',
            green = '#70CF67',
            teal = '#4CD4BD',
            sky = '#61BDFF',
            sapphire = '#4BA8FA',
            blue = '#00BFFF',
            lavender = '#00BBCC',
            text = '#C1C9E6',
            subtext1 = '#A3AAC2',
            subtext0 = '#8E94AB',
            overlay2 = '#7D8296',
            overlay1 = '#676B80',
            overlay0 = '#464957',
            surface2 = '#3A3D4A',
            surface1 = '#2F313D',
            surface0 = '#1D1E29',
            base = '#0b0b12',
            mantle = '#11111a',
            crust = '#191926',
          },
        },
        custom_highlights = {},
        default_integrations = true,
        integrations = {
          telescope = true,
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          treesitter = false,
          notify = false,
          mini = {
            enabled = true,
            indentscope_color = '',
          },
        },
      }
      vim.cmd.colorscheme 'catppuccin'
    end,
  },
  --
  -- {
  --   'rebelot/kanagawa.nvim',
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     -- Default options:
  --     require('kanagawa').setup {
  --       compile = true, -- enable compiling the colorscheme
  --       undercurl = true, -- enable undercurls
  --       commentStyle = { italic = true },
  --       functionStyle = {},
  --       keywordStyle = { italic = true },
  --       statementStyle = { bold = true },
  --       typeStyle = {},
  --       transparent = false, -- do not set background color
  --       dimInactive = false, -- dim inactive window `:h hl-NormalNC`
  --       terminalColors = true, -- define vim.g.terminal_color_{0,17}
  --       colors = { -- add/modify theme and palette colors
  --         palette = {},
  --         theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
  --       },
  --       overrides = function(colors) -- add/modify highlights
  --         return {}
  --       end,
  --       theme = 'wave', -- Load "wave" theme when 'background' option is not set
  --       background = { -- map the value of 'background' option to a theme
  --         dark = 'wave', -- try "dragon" !
  --         light = 'lotus',
  --       },
  --     }
  --
  --     -- setup must be called before loading
  --     vim.cmd 'colorscheme kanagawa'
  --   end,
  -- },
}
