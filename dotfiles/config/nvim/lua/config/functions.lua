-- Function to toggle the 80-character ruler
local function toggle_ruler_80()
  if string.find(vim.o.colorcolumn, '81') then
    -- Ruler is on, turn it off
    vim.opt.colorcolumn = ''
  else
    -- Ruler is off, turn it on
    vim.opt.colorcolumn = '81'
  end
end

-- Command to toggle the ruler
vim.api.nvim_create_user_command('Ruler80', toggle_ruler_80, {})

-- Function to toggle diagnostic virtual text
local function toggle_virtual_text()
  local current_config = vim.diagnostic.config() or {}
  local virtual_text_enabled = current_config.virtual_text or false
  -- Toggle the state
  virtual_text_enabled = not virtual_text_enabled
  vim.diagnostic.config {
    virtual_text = virtual_text_enabled,
  }
  vim.notify('Diagnostic Virtual Text ' .. (virtual_text_enabled and 'Enabled' or 'Disabled'), vim.log.levels.INFO)
end

-- Command to toggle diagnostic virtual text
vim.api.nvim_create_user_command('ToggleVirtualText', toggle_virtual_text, {})

-- Remove duplicate lines in visual block
vim.api.nvim_create_user_command('RemoveDuplicateLines', function(opts)
  local start_line = opts.line1
  local end_line = opts.line2

  -- Get selected lines and calculate original count
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local original_count = #lines

  -- Remove duplicates while preserving order
  local seen = {}
  local unique_lines = {}
  for _, line in ipairs(lines) do
    if not seen[line] then
      seen[line] = true
      table.insert(unique_lines, line)
    end
  end

  -- Replace lines and calculate removed count
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, unique_lines)
  local removed_count = original_count - #unique_lines

  -- Show appropriate notification
  if removed_count > 0 then
    vim.notify(string.format('%d duplicate lines removed', removed_count), vim.log.levels.INFO)
  else
    vim.notify('No duplicates found in selection', vim.log.levels.INFO)
  end
end, { range = true })

--
-- Start of sorting
--
-- Function to sort lines in the current buffer between a given range.
local function sort_lines(opts)
  -- Get the start and end line numbers from the command range.
  local start_line = opts.line1
  local end_line = opts.line2

  -- Retrieve the lines from the current buffer (0-indexed).
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  -- Determine the comparator based on the sort type passed in opts.args.
  local comparator = nil
  local sort_type = opts.args or 'Alpha' -- default to case-sensitive alphabetical

  if sort_type == 'Alpha' then
    comparator = function(a, b)
      return a < b
    end
  elseif sort_type == 'ReverseAlpha' then
    comparator = function(a, b)
      return a > b
    end
  elseif sort_type == 'AlphaIgnoreCase' then
    comparator = function(a, b)
      return string.lower(a) < string.lower(b)
    end
  elseif sort_type == 'ReverseAlphaIgnoreCase' then
    comparator = function(a, b)
      return string.lower(a) > string.lower(b)
    end
  else
    error('Unknown sort type: ' .. sort_type)
  end

  -- Sort the selected lines using the comparator.
  table.sort(lines, comparator)

  -- Replace the original lines with the sorted lines.
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end

-- Create user commands for different sorts.
vim.api.nvim_create_user_command('SortAz', function(opts)
  sort_lines { args = 'Alpha', line1 = opts.line1, line2 = opts.line2 }
end, { range = true, desc = 'Sort lines alphabetically (case sensitive)' })

vim.api.nvim_create_user_command('SortZa', function(opts)
  sort_lines { args = 'ReverseAlpha', line1 = opts.line1, line2 = opts.line2 }
end, { range = true, desc = 'Sort lines in reverse alphabetical order (case sensitive)' })

vim.api.nvim_create_user_command('Sortaz', function(opts)
  sort_lines { args = 'AlphaIgnoreCase', line1 = opts.line1, line2 = opts.line2 }
end, { range = true, desc = 'Sort lines alphabetically (ignoring case)' })

vim.api.nvim_create_user_command('Sortza', function(opts)
  sort_lines { args = 'ReverseAlphaIgnoreCase', line1 = opts.line1, line2 = opts.line2 }
end, { range = true, desc = 'Sort lines in reverse alphabetical order (ignoring case)' })
--
-- End of sorting
--
