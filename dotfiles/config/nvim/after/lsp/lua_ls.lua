return {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      completion = {
        callSnippet = 'Replace',
      },
      diagnostics = {
        -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
        disable = { 'missing-fields' },
        globals = {
          'vim',
          'require',
          'Snacks',
        },
      },
    },
  },
}
