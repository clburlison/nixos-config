-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
return {
  {
    'folke/tokyonight.nvim',
    enabled = true,
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('tokyonight').setup {
        transparent = false,
        style = {
          comments = { italic = false },
          keywords = { italic = false },
        },
      }
      vim.cmd.colorscheme 'tokyonight-night'
      vim.cmd.hi 'Comment gui=none'
    end,
  },
  {
    'craftzdog/solarized-osaka.nvim',
    enabled = false,
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      require('solarized-osaka').setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        transparent = true, -- Enable this to disable setting the background color
        styles = {
          -- Style to be applied to different syntax groups
          -- Value is any valid attr-list value for `:help nvim_set_hl`
          comments = { italic = false },
          keywords = { italic = false },
          functions = {},
          variables = {},
          -- Background styles. Can be "dark", "transparent" or "normal"
          sidebars = 'transparent', -- style for sidebars, see below
          floats = 'transparent', -- style for floating windows
        },
        sidebars = { 'qf', 'help' }, -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
        day_brightness = 1, -- Adjusts the brightness of the colors of the **Day** style. Number between 0 and 1, from dull to vibrant colors
        hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
        dim_inactive = false, -- dims inactive windows
        lualine_bold = false, -- When `true`, section headers in the lualine theme will be bold
      }
      vim.cmd.colorscheme 'solarized-osaka'
    end,
  },
}
