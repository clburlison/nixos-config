-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local function augroup(name)
  return vim.api.nvim_create_augroup('lazyvim_' .. name, { clear = true })
end

-- Auto-command to customize chat buffer behavior
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = 'copilot-*',
  callback = function()
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.opt_local.conceallevel = 0
  end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = augroup 'highlight-yank',
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ 'VimResized' }, {
  desc = 'Resize splits if window is resized',
  group = augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- Go to last loc when opening a buffer
vim.api.nvim_create_autocmd('BufReadPost', {
  desc = 'Go to last location when opening a buffer',
  group = augroup 'last_loc',
  callback = function(event)
    local exclude = { 'gitcommit' }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Function to show diagnostics in a floating window
local function show_diagnostics_float()
  vim.diagnostic.open_float(nil, {
    focusable = false,
    scope = 'cursor',
    border = 'rounded',
    source = 'always',
    prefix = '',
  })
end

-- CursorHold to show diagnostics
vim.api.nvim_create_autocmd('CursorHold', {
  callback = show_diagnostics_float,
  desc = 'Show floating diagnostics when cursor is held',
})

-- Create the LspToggle command
vim.api.nvim_create_user_command('LspToggle', function(opts)
  local lsp_name = opts.args
  local clients = vim.lsp.get_clients { name = lsp_name }

  if #clients > 0 then
    -- LSP is running, stop it
    vim.cmd('LspStop ' .. lsp_name)
    vim.notify('Stopped ' .. lsp_name, vim.log.levels.INFO)
  else
    -- LSP is not running, start it
    vim.cmd('LspStart ' .. lsp_name)
    vim.notify('Started ' .. lsp_name, vim.log.levels.INFO)
  end
end, {
  nargs = 1,
  complete = function()
    -- Optional: add completion for available LSP clients
    local clients = {}
    for _, client in ipairs(vim.lsp.get_clients()) do
      table.insert(clients, client.name)
    end
    return clients
  end,
  desc = 'Toggle LSP client on/off',
})
