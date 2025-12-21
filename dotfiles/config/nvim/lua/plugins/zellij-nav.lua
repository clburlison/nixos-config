-- https://github.com/hiasr/vim-zellij-navigator
return {
  {
    'mrjones2014/smart-splits.nvim',
    enabled = true,
    lazy = false,
    event = 'VeryLazy',
    keys = {
      -- moving between splits
      { '<C-h>', '<cmd>SmartCursorMoveLeft<cr>', { silent = true, desc = 'move cursor left' } },
      { '<C-j>', '<cmd>SmartCursorMoveDown<cr>', { silent = true, desc = 'move cursor down' } },
      { '<C-k>', '<cmd>SmartCursorMoveUp<cr>', { silent = true, desc = 'move cursor up' } },
      { '<C-l>', '<cmd>SmartCursorMoveRight<cr>', { silent = true, desc = 'move cursor right' } },
      -- resizing splits
      -- these keymaps will also accept a range,
      -- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
      { '<A-h>', '<cmd>SmartResizeLeft<cr>', { silent = true, desc = 'resize left' } },
      { '<A-j>', '<cmd>SmartResizeDown<cr>', { silent = true, desc = 'resize down' } },
      { '<A-k>', '<cmd>SmartResizeUp<cr>', { silent = true, desc = 'resize up' } },
      { '<A-l>', '<cmd>SmartResizeRight<cr>', { silent = true, desc = 'resize right' } },
      -- swapping buffers between windows
      { '<leader><leader>h', '<cmd>SmartSwapLeft<cr>', { silent = true, desc = 'swap buffer left' } },
      { '<leader><leader>j', '<cmd>SmartSwapDown<cr>', { silent = true, desc = 'swap buffer down' } },
      { '<leader><leader>k', '<cmd>SmartSwapUp<cr>', { silent = true, desc = 'swap buffer up' } },
      { '<leader><leader>l', '<cmd>SmartSwapRight<cr>', { silent = true, desc = 'swap buffer right' } },
    },
  },
  {
    'swaits/zellij-nav.nvim',
    enabled = false,
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
}
