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

-- Move to window using the <ctrl> hjkl keys
set('n', '<C-h>', '<C-w>h', { desc = 'Go to Left Window', remap = true })
set('n', '<C-j>', '<C-w>j', { desc = 'Go to Lower Window', remap = true })
set('n', '<C-k>', '<C-w>k', { desc = 'Go to Upper Window', remap = true })
set('n', '<C-l>', '<C-w>l', { desc = 'Go to Right Window', remap = true })

-- Resize window using <ctrl> arrow keys
set('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Increase Window Height' })
set('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Decrease Window Height' })
set('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Decrease Window Width' })
set('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase Window Width' })

-- Create window splits
set('n', '<leader>ww', '<C-W>v', { desc = 'Split Window Right', remap = true })
set('n', '<leader>wW', '<C-W>s', { desc = 'Split Window Below', remap = true })
set('n', '<leader>wd', '<C-W>c', { desc = 'Delete Window', remap = true })

-- tabs
set('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
set('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
set('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
set('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
set('n', '<leader><tab>n', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
set('n', '<leader><tab>p', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })
set('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })

-- Move Lines
set('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", { desc = 'Move Down' })
set('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = 'Move Up' })
set('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move Down' })
set('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move Up' })
set('v', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = 'Move Down' })
set('v', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = 'Move Up' })

-- buffers
set('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
set('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
set('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
set('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
set('n', '<leader>bd', '<cmd>bd<cr>', { desc = 'Delete Buffer' })

-- new file
set('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New File' })

-- quit
set('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit All' })

-- Add quotes around selected text
set('v', '<leader>e"', ':s/^\\(\\s*\\)\\(.*\\)$/\\1"\\2",/g<CR>', { desc = 'Add double quotes & comma around text' })

-- Add trailing comma to list
set('v', '<leader>ec', ':s/^\\(\\s*\\)\\(.*\\)$/\\2,/g<CR>', { desc = 'Add trailing comma to text' })

-- Toggle virtual_text
set('n', '<leader>tv', ':ToggleVirtualText<CR>', { desc = 'Toggle Diagnostic Virtual Text' })

-- Toggle Markdown Rendering
set('n', '<leader>tm', ':RenderMarkdown toggle<CR>', { desc = 'Toggle Markdown Rendering' })

-- Remove duplicate lines
set('v', '<leader>rl', ':RemoveDuplicateLines<CR>', {
  noremap = true,
  silent = true,
  desc = 'Remove duplicates with feedback',
})
