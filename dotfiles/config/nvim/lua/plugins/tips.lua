return {
  'saxon1964/neovim-tips',
  enabled = true,
  version = '*', -- Only update on tagged releases
  lazy = true,
  dependencies = {
    'MunifTanjim/nui.nvim',
    -- OPTIONAL: Choose your preferred markdown renderer (or omit for raw markdown)
    'MeanderingProgrammer/render-markdown.nvim', -- Clean rendering
    -- OR: "OXY2DEV/markview.nvim", -- Rich rendering with advanced features
  },
  opts = {
    daily_tip = 0, -- 0 = off, 1 = once per day, 2 = every startup
    bookmark_symbol = '🌟 ',
  },
  keys = {
    { '<leader>nto', ':NeovimTips<CR>', desc = 'Neovim tips' },
    { '<leader>ntb', ':NeovimTipsBookmarks<CR>', desc = 'Bookmarked tips' },
    { '<leader>ntr', ':NeovimTipsRandom<CR>', desc = 'Show random tip' },
    { '<leader>nte', ':NeovimTipsEdit<CR>', desc = 'Edit your tips' },
    { '<leader>nta', ':NeovimTipsAdd<CR>', desc = 'Add your tip' },
    { '<leader>ntp', ':NeovimTipsPdf<CR>', desc = 'Open tips PDF' },
  },
}
