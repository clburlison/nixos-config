-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
local set = vim.keymap.set

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Toggle true/false
vim.fn.setreg('t', '^f:wye ciw' .. string.char(18) .. '=@"=~"true"?"false":"true"' .. string.char(27) .. string.char(27))
set('n', '<leader>tt', '@t', { noremap = true, desc = 'Toggle true/false' })

-- Add quotes around selected text
set('v', '<leader>tq', ':s/^\\(\\s*\\)\\(.*\\)$/\\1"\\2"/g<CR>', { desc = 'Add double quotes around text' })

-- Function to toggle diagnostic virtual text
local function toggle_virtual_text()
  local current_config = vim.diagnostic.config()
  local virtual_text_enabled = current_config.virtual_text or false
  -- Toggle the state
  virtual_text_enabled = not virtual_text_enabled
  vim.diagnostic.config {
    virtual_text = virtual_text_enabled,
  }
  vim.notify('Diagnostic Virtual Text ' .. (virtual_text_enabled and 'Enabled' or 'Disabled'), vim.log.levels.INFO)
end

-- Toggle virtual_text with <leader>tv
set('n', '<leader>tv', toggle_virtual_text, { desc = 'Toggle Diagnostic Virtual Text' })
