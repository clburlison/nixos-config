-- Highlight, edit, and navigate code
return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs',
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
    -- Auto-install languages that are not installed
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = false },
  },
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}
