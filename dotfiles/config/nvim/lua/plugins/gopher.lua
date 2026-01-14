return {
  'olexsmir/gopher.nvim',
  enabled = false,
  ft = 'go',
  -- branch = "develop"
  -- (optional) updates the plugin's dependencies on each update
  build = function()
    vim.cmd.GoInstallDeps()
  end,
  ---@module "gopher"
  ---@type gopher.Config
  opts = {},
  keys = {
    { '<leader>ge', ':GoIfErr<CR>', mode = 'n', desc = 'Go error handle' },
  },
}
