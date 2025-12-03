return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {},
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify', -- Optional
  },
  keys = {
    { '<leader>nn', '<cmd>Noice dismiss<cr>', { silent = true, desc = 'Dismiss notifications' } },
  },
}
