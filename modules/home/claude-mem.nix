{
  lib,
  pkgs,
  ...
}:

let
  claudeMem = pkgs.claude-mem;
  # Keep this list aligned with the claude-mem slash commands you use.
  # The plugin prefix is implicit here; e.g. "mem-search" is
  # "claude-mem:mem-search".
  enabledClaudeMemSkills = [
    "how-it-works"
    "mem-search"
    "pathfinder"
    "smart-explore"
    "what-the"
  ];
  claudeMemPlugin = pkgs.runCommand "claude-mem-plugin" { } ''
    mkdir -p "$out"
    cp -R ${claudeMem.pluginRoot}/. "$out/"
    chmod -R u+w "$out"
    rm "$out/node_modules"
    ln -s ${claudeMem}/share/claude-mem/node_modules "$out/node_modules"
    ${lib.concatMapStringsSep "\n" (name: ''
      skill="$out/skills/${lib.escapeShellArg name}"
      if [ ! -d "$skill" ]; then
        echo "Unknown enabled claude-mem skill: ${lib.escapeShellArg name}" >&2
        exit 1
      fi
    '') enabledClaudeMemSkills}
    for skill in "$out"/skills/*; do
      [ -d "$skill" ] || continue
      skill_name="''${skill##*/}"
      case "$skill_name" in
        ${lib.concatMapStringsSep "|" lib.escapeShellArg enabledClaudeMemSkills}) ;;
        *) rm -rf "$skill" ;;
      esac
    done
  '';
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
        -c 'tui.keymap.composer.submit=["enter"]' \
        -c 'tui.keymap.editor.insert_newline=["shift-enter"]' \
        -c 'mcp_servers.claude-mem.default_tools_approval_mode="approve"' \
        "$@"
    '')
  ];

  # Env overrides settings.json, so no machine-specific settings file is managed.
  # Run local on purpose: hide the cmem.ai Pro trial welcome hint.
  home.sessionVariables = {
    # Claude MIM owns persistent memory for Claude Code.
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    CLAUDE_MEM_WELCOME_HINT_ENABLED = "false";
    # Keep the context injected for the model, hide the noisy terminal copy.
    CLAUDE_MEM_CONTEXT_SHOW_TERMINAL_OUTPUT = "false";
    # Key projects by git remote slug so worktrees share the parent project.
    CLAUDE_MEM_PROJECT_NAME_SOURCE = "git-remote";
  };

  programs.claude-code = {
    enable = true;
    plugins = [ claudeMemPlugin ];
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
