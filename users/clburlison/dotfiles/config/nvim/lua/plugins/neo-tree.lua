-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim
return {
  'nvim-neo-tree/neo-tree.nvim',
  enabled = false,
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not required, but recommended
    'MunifTanjim/nui.nvim',
  },
  config = function()
    require('neo-tree').setup {
      default_path = '~', -- Optional: Set your preferred default root path
      filesystem = {
        follow_modified = 1,
      },
      window = {
        position = 'right',
      },
    }

    vim.keymap.set('n', '<leader>bd', '<cmd>Neotree toggle<cr>', { noremap = true, desc = 'Toggle Neotree Directory' })
    vim.keymap.set('n', '<leader>bb', '<cmd>Neotree toggle show buffers<cr>', { noremap = true, desc = 'Toggle Neotree Buffers' })
    vim.keymap.set('n', '<leader>b\\', '<cmd>Neotree reveal<cr>', { noremap = true, desc = 'Reveal Neotree Buffers' })
    --nnoremap / :Neotree toggle current reveal_force_cwd<cr>
    -- nnoremap | :Neotree reveal<cr>
    -- nnoremap gd :Neotree float reveal_file=<cfile> reveal_force_cwd<cr>
    -- nnoremap <leader>b :Neotree toggle show buffers right<cr>
    --nnoremap <leader>s :Neotree float git_status<cr>
  end,
}
