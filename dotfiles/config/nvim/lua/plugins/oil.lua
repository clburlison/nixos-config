return {
  'stevearc/oil.nvim',
  opts = {
    vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' }),
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    lsp_file_methods = {
      enabled = true,
      timeout_ms = 1000,
      autosave_changes = true,
    },
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
    keymaps = {
      ['g?'] = { 'actions.show_help', mode = 'n' },
      ['<CR>'] = 'actions.select',
      ['<C-s>'] = false,
      ['<C-h>'] = false,
      ['<C-t>'] = false,
      ['<C-p>'] = 'actions.preview',
      ['<C-c>'] = { 'actions.close', mode = 'n' },
      ['<C-r>'] = 'actions.refresh',
      ['-'] = { 'actions.parent', mode = 'n' },
      ['_'] = { 'actions.open_cwd', mode = 'n' },
      ['`'] = { 'actions.cd', mode = 'n' },
      ['g~'] = { 'actions.cd', opts = { scope = 'tab' }, mode = 'n' },
      ['gs'] = { 'actions.change_sort', mode = 'n' },
      ['gx'] = 'actions.open_external',
      ['g.'] = { 'actions.toggle_hidden', mode = 'n' },
      ['g\\'] = { 'actions.toggle_trash', mode = 'n' },
    },
  },
  dependencies = { { 'echasnovski/mini.icons', opts = {} } },
}
