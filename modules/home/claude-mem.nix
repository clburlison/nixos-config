{
  lib,
  pkgs,
  ...
}:

let
  claudeMem = pkgs.claude-mem;
  memorySkills = [
    "mem-search"
    "smart-explore"
  ];
in
{
  home.packages = [
    claudeMem
    # Keep config.toml, hooks.json, project trusts, and login state writable.
    # The package adds its inline hooks/MCP through targeted CLI overrides.
    (pkgs.writeShellScriptBin "codex" ''
      exec ${claudeMem}/bin/claude-mem-codex \
        -c 'tui.keymap.composer.submit=["shift-enter"]' \
        -c 'tui.keymap.editor.insert_newline=["enter"]' \
        "$@"
    '')
  ];

  # Env overrides settings.json, so no machine-specific settings file is managed.
  # Run local on purpose: hide the cmem.ai Pro trial welcome hint.
  home.sessionVariables = {
    CLAUDE_MEM_WELCOME_HINT_ENABLED = "false";
    # Keep the context injected for the model, hide the noisy terminal copy.
    CLAUDE_MEM_CONTEXT_SHOW_TERMINAL_OUTPUT = "false";
    # Key projects by git remote slug so worktrees share the parent project.
    CLAUDE_MEM_PROJECT_NAME_SOURCE = "git-remote";
  };

  programs.claude-code = {
    enable = true;
    plugins = [ claudeMem.pluginRoot ];
    # Leave settings empty: existing mutable settings.json remains its owner.
  };

  xdg.configFile."opencode/plugins/claude-mem.js".source = claudeMem.opencodePlugin;

  # Render the existing JSONC template, preserving comments and other settings.
  # Do not also create opencode.json or use HM's legacy shared-MCP transformer.
  home.file = {
    ".config/opencode/opencode.jsonc".text =
      builtins.replaceStrings
        [ "@claudeMemMcp@" ]
        [
          "${claudeMem}/bin/claude-mem-mcp"
        ]
        (builtins.readFile ../../dotfiles/config/opencode/opencode.jsonc);
  }
  // lib.listToAttrs (
    lib.concatMap (name: [
      {
        name = ".codex/skills/${name}";
        value.source = "${claudeMem.pluginRoot}/skills/${name}";
      }
      {
        name = ".config/opencode/skills/${name}";
        value.source = "${claudeMem.pluginRoot}/skills/${name}";
      }
    ]) memorySkills
  );
}
