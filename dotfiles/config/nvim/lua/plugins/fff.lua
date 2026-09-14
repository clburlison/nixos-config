-- fff.nvim has had some bad updates. If the download fails try
-- the following:
-- 1. rm -rf .local/share/nvim/lazy/fff.nvim
-- 2. lua require("fff.download").download_or_build_binary()
return {
  'dmtrKovalenko/fff',
  enabled = true,
  -- build = 'cargo build --release',
  build = function()
    -- this will download prebuild binary or try to use existing rustup toolchain to build from source
    -- (if you are using lazy you can use gb for rebuilding a plugin if needed)
    require('fff.download').download_or_build_binary()
  end,
  lazy = false, -- the plugin lazy-initialises itself
  opts = {
    prompt = '🪄 ',
  },
  keys = {
    {
      '<leader>ff',
      function()
        require('fff').find_files()
      end,
      desc = 'Open file picker',
    },
    {
      '<leader>fg',
      function()
        require('fff').live_grep()
      end,
      desc = 'LiFFFe grep',
    },
    {
      '<leader>fz',
      function()
        require('fff').live_grep { grep = { modes = { 'fuzzy', 'plain' } } }
      end,
      desc = 'Live fffuzy grep',
    },
    {
      '<leader>fw',
      function()
        require('fff').live_grep_under_cursor()
      end,
      mode = { 'n', 'x' },
      desc = 'Search current word / selection',
    },
  },
}
