return {
  'stevearc/oil.nvim',
  opts = {
    vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' }),
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    view_options = {
      show_hidden = true,
      is_always_hidden = function(name, bufnr)
        local hidden_files = {
          ['.DS_Store'] = true,
          ['Thumbs.db'] = true,
          ['.git'] = true,
        }
        return hidden_files[name] == true
      end,
    },
  },
  dependencies = { { 'echasnovski/mini.icons', opts = {} } },
}
