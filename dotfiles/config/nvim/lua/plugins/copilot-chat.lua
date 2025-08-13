return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
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
