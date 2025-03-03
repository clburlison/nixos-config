-- Toggle the boolean word (true/false) under the cursor
vim.api.nvim_create_user_command('ToggleBoolean', function(opts)
  -- Helper function that toggles booleans in a given line using a replacement function.
  local function toggle_line(line)
    return line:gsub('(%f[%a])(true|false)(%f[%A])', function(left, word, right)
      return left .. (word == 'true' and 'false' or 'true') .. right
    end)
  end

  -- Retrieve the lines in the specified range.
  local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
  for idx, line in ipairs(lines) do
    lines[idx] = toggle_line(line)
  end
  -- Update the buffer with the toggled lines.
  vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, false, lines)
  vim.notify('Toggled booleans in selected line(s).', vim.log.levels.INFO)
end, { range = true, desc = 'Toggle all occurrences of true/false in current or selected line(s)' })

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
