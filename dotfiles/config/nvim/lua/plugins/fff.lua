return {
  'dmtrKovalenko/fff.nvim',
  enabled = true,
  build = 'cargo build --release',
  opts = {},
  keys = {
    {
      '<leader>ff',
      function()
        require('fff').find_files()
      end,
      desc = 'Open file picker',
    },
  },
}
