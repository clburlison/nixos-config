return {
  {
    'swaits/zellij-nav.nvim',
    lazy = true,
    event = 'VeryLazy',
    keys = {
      { '<c-h>', '<cmd>ZellijNavigateLeftTab<cr>', { silent = true, desc = 'navigate left or tab' } },
      { '<c-j>', '<cmd>ZellijNavigateDown<cr>', { silent = true, desc = 'navigate down' } },
      { '<c-k>', '<cmd>ZellijNavigateUp<cr>', { silent = true, desc = 'navigate up' } },
      { '<c-l>', '<cmd>ZellijNavigateRightTab<cr>', { silent = true, desc = 'navigate right or tab' } },
    },
    opts = {},
  },
  {
    -- Not sure why this plugin was mentioned as required? Navigation seems to work
    -- just fine without it. With it enabled it drastically slows down neovim's shutdown.
    'hiasr/vim-zellij-navigator.nvim',
    enabled = false,
    event = 'VeryLazy',
    config = function()
      require('vim-zellij-navigator').setup()
    end,
  },
}
