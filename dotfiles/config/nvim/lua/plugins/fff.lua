-- fff.nvim has had some bad updates. If the download fails try
-- the following:
-- 1. rm -rf .local/share/nvim/lazy/fff.nvim
-- 2. lua require("fff.download").download_or_build_binary()
return {
  'dmtrKovalenko/fff.nvim',
  enabled = true,
  -- build = 'cargo build --release',
  build = function()
    -- this will download prebuild binary or try to use existing rustup toolchain to build from source
    -- (if you are using lazy you can use gb for rebuilding a plugin if needed)
    require('fff.download').download_or_build_binary()
  end,
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
  },
}
