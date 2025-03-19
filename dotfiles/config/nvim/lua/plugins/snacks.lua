return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = false },
      dashboard = { enabled = false },
      explorer = { enabled = false },
      indent = {
        enabled = true,
        animate = { enabled = false },
      },
      image = { enabled = false },
      input = { enabled = true },
      lazygit = { enabled = true },
      notifier = { enabled = false },
      picker = { enabled = false },
      quickfile = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = true },
      statuscolumn = {
        enabled = true,
        left = { 'fold', 'sign' },
        right = { 'mark', 'git' },
        folds = {
          open = true,
          git_hl = false,
        },
        git = {
          patterns = { 'GitSign', 'MiniDiffSign' },
        },
        refresh = 50,
      },
      words = { enabled = false },
    },
    keys = {
      -- lazygit
      {
        '<leader>lg',
        function()
          Snacks.lazygit()
        end,
        desc = 'Lazygit',
      },
    },
  },
}
