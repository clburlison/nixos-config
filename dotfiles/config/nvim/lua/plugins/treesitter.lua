-- Highlight, edit, and navigate code
-- data stored at ~/.local/share/nvim/lazy/nvim-treesitter/parser
return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  build = ':TSUpdate',
  cmd = { 'TSUpdate', 'TSInstall', 'TSLog', 'TSUninstall' },
  event = { 'BufReadPre', 'BufNewFile' },
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  opts = {
    ensure_installed = {
      'bash',
      'c',
      'diff',
      'go',
      'gomod',
      'gosum',
      'html',
      'javascript',
      'jsdoc',
      'json',
      'json5',
      'jsonc',
      'kdl',
      'lua',
      'luadoc',
      'luap',
      'markdown',
      'markdown_inline',
      'nix',
      'printf',
      'python',
      'query',
      'regex',
      'sql',
      'swift',
      'toml',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'xml',
      'yaml',
    },
    highlight = { enable = true },
    indent = { enable = true },
    folds = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<Enter>',
        node_incremental = '<Enter>',
        scope_incremental = false,
        node_decremental = '<Backspace>',
      },
    },
  },
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}
