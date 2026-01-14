return {
  {
    'NickvanDyke/opencode.nvim',
    enabled = true,
    dependencies = {
      -- Recommended for `ask()` and `select()`.
      -- Required for `snacks` provider.
      ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
      { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
      }

      -- Required for `opts.events.reload`.
      vim.o.autoread = true

      -- Recommended/example keymaps.
      vim.keymap.set({ 'n', 'x' }, '<leader>at', function()
        require('opencode').ask('@this: ', { submit = true })
      end, { desc = 'Ask opencode about @this' })
      vim.keymap.set({ 'n', 'x' }, '<leader>ad', function()
        require('opencode').ask('@diagnostics: ', { submit = true })
      end, { desc = 'Ask opencode about @diagnostics' })
      vim.keymap.set({ 'n', 'x' }, '<leader>ax', function()
        require('opencode').select()
      end, { desc = 'Execute opencode action…' })
      vim.keymap.set({ 'n', 't' }, '<leader>ac', function()
        require('opencode').toggle()
      end, { desc = 'Toggle opencode' })

      vim.keymap.set({ 'n', 'x' }, 'go', function()
        return require('opencode').operator '@this '
      end, { expr = true, desc = 'Add range to opencode' })
      vim.keymap.set('n', 'goo', function()
        return require('opencode').operator '@this ' .. '_'
      end, { expr = true, desc = 'Add line to opencode' })

      vim.keymap.set('n', '<S-C-u>', function()
        require('opencode').command 'session.half.page.up'
      end, { desc = 'opencode half page up' })
      vim.keymap.set('n', '<S-C-d>', function()
        require('opencode').command 'session.half.page.down'
      end, { desc = 'opencode half page down' })

      -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
      -- vim.keymap.set('n', '<C-a>', { desc = 'Increment', noremap = true })
      -- vim.keymap.set('n', '<C-x>', { desc = 'Decrement', noremap = true })
    end,
  },
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    enabled = false,
    dependencies = {
      { 'nvim-lua/plenary.nvim', branch = 'master' },
    },
    build = 'make tiktoken',
    opts = {
      {
        model = 'gemini-2.5-pro', -- AI model to use
        temperature = 0.1, -- Lower = focused, higher = creative
        window = {
          layout = 'vertical', -- 'vertical', 'horizontal', 'float'
          width = 0.5, -- 50% of screen width
        },
        auto_insert_mode = true, -- Enter insert mode when opening
      },
    },
    keys = {
      { '<leader>ac', ':CopilotChatToggle<CR>', mode = 'n', desc = 'Chat with Copilot' },
      { '<leader>ar', ':CopilotChatReset<CR>', mode = 'n', desc = 'Reset Copilot Chat' },
      { '<leader>ae', ':CopilotChatExplain<CR>', mode = 'v', desc = 'Explain Code' },
      { '<leader>ar', ':CopilotChatReview<CR>', mode = 'v', desc = 'Review Code' },
      { '<leader>af', ':CopilotChatFix<CR>', mode = 'v', desc = 'Fix Code Issues' },
      { '<leader>ao', ':CopilotChatOptimize<CR>', mode = 'v', desc = 'Optimize Code' },
      { '<leader>ad', ':CopilotChatDocs<CR>', mode = 'v', desc = 'Generate Docs' },
      { '<leader>at', ':CopilotChatTests<CR>', mode = 'v', desc = 'Generate Tests' },
      { '<leader>am', ':CopilotChatCommit<CR>', mode = 'n', desc = 'Generate Commit Message' },
      { '<leader>as', ':CopilotChatCommit<CR>', mode = 'v', desc = 'Generate Commit Message' },
    },
  },
}
