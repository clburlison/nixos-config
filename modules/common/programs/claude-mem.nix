{
  config,
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
  # Agents launched outside a login shell (e.g. T3 Code's launchd service)
  # don't get session variables, so hooks and the worker they spawn read
  # these from settings.json instead.
  serverSettings = lib.getAttrs [
    "CLAUDE_MEM_RUNTIME"
    "CLAUDE_MEM_SERVER_URL"
    "CLAUDE_MEM_SERVER_PROJECT_ID"
  ] config.home.sessionVariables;
in
{
  _class = "homeManager";

  home.packages = [
    claudeMem
    # Keep config.toml, hooks.json, project trusts, and login state writable.
    # The package adds its inline hooks/MCP through targeted CLI overrides.
    # Routes through the CLIProxyAPI hub when its key is present
    # (cliproxyapi.nix).
    (pkgs.writeShellScriptBin "codex" ''
      ${config.clb.cliproxyapi.codexEnv}
      exec ${claudeMem}/bin/claude-mem-codex \
        -c 'tui.keymap.composer.submit=["enter"]' \
        -c 'tui.keymap.editor.insert_newline=["shift-enter"]' \
        -c 'mcp_servers.claude-mem.default_tools_approval_mode="approve"' \
        "$@"
    '')
  ];

  # Env overrides settings.json, but only reaches agents started from a login
  # shell, so server settings are also merged into settings.json
  # (claudeMemServerSettings below).
  # Run local on purpose: hide the cmem.ai Pro trial welcome hint.
  home.sessionVariables = {
    # Claude MIM owns persistent memory for Claude Code.
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
    CLAUDE_MEM_WELCOME_HINT_ENABLED = "false";
    # Keep the context injected for the model, hide the noisy terminal copy.
    CLAUDE_MEM_CONTEXT_SHOW_TERMINAL_OUTPUT = "false";
    # Key projects by git remote slug so worktrees share the parent project.
    CLAUDE_MEM_PROJECT_NAME_SOURCE = "git-remote";
    # Worker snapshots the SQLite store to ~/.claude-mem/backups (daily, keep 7).
    CLAUDE_MEM_BACKUP_ENABLED = "true";
    # Hooks send to the hosted server on srv-devbox (docs/srv-devbox.md
    # step 10). The API key is a secret: add CLAUDE_MEM_SERVER_API_KEY to
    # ~/.claude-mem/settings.json on each host. Without it, the worker falls
    # back to local SQLite.
    CLAUDE_MEM_RUNTIME = "server";
    # srv-devbox overrides this with loopback (hosts/srv-devbox/home.nix).
    CLAUDE_MEM_SERVER_URL = lib.mkDefault "http://srv-devbox.mermaid-agama.ts.net:37877";
    CLAUDE_MEM_SERVER_PROJECT_ID = "3bee384a-652b-4947-bd36-027c429b4589";
  };

  # Merge the server settings into the mutable settings.json, keeping the API
  # key and everything else. Stop a running worker on change so the next hook
  # starts one that reads them.
  home.activation.claudeMemServerSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dataDir="${config.home.homeDirectory}/.claude-mem"
    settings="$dataDir/settings.json"

    ${pkgs.coreutils}/bin/install -d -m 700 "$dataDir"
    if [ ! -e "$settings" ]; then
      printf '{}\n' > "$settings"
    fi
    tmp="$(${pkgs.coreutils}/bin/mktemp "$dataDir/settings.json.XXXXXX")"
    ${pkgs.jq}/bin/jq --argjson server ${lib.escapeShellArg (builtins.toJSON serverSettings)} \
      '. + $server' "$settings" > "$tmp"
    if ${pkgs.diffutils}/bin/cmp -s "$tmp" "$settings"; then
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    else
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
      if [ -e "$dataDir/worker.pid" ]; then
        ${claudeMem}/bin/claude-mem stop || true
      fi
    fi
  '';

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
        (builtins.readFile ../../../dotfiles/config/opencode/opencode.jsonc);
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
