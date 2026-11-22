{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  claudeMem = pkgs.claude-mem;
  cfg = config.clb.claudeMem;

  # The hosted server's MCP endpoint and read/write key. Claude Code runs the
  # helper at each connect, so the key stays out of the store and
  # ~/.claude.json. Darwin reads op-agents' keychain cache; Linux reads
  # apiKeyFile, e.g. from the system's op-agents secrets.
  readKey =
    if isDarwin then
      config.clb.opAgents.secrets.claude-mem-api-key.readCommand
    else
      "cat ${lib.escapeShellArg cfg.apiKeyFile} 2>/dev/null";
  mcpHeaders = pkgs.writeShellScript "claude-mem-mcp-headers" ''
    key="$(${readKey})" && [ -n "$key" ] || exit 1
    ${pkgs.jq}/bin/jq -n --arg key "$key" '{Authorization: ("Bearer " + $key)}'
  '';
  hasKey = isDarwin || cfg.apiKeyFile != null;
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
  # these from settings.json instead. The legacy SERVER_BETA_* keys are
  # fallbacks for the primary ones; pin them to match, without a second copy
  # of the key.
  serverSettings =
    let
      env = config.home.sessionVariables;
    in
    lib.getAttrs [
      "CLAUDE_MEM_RUNTIME"
      "CLAUDE_MEM_SERVER_URL"
      "CLAUDE_MEM_SERVER_PROJECT_ID"
    ] env
    // {
      CLAUDE_MEM_SERVER_BETA_URL = env.CLAUDE_MEM_SERVER_URL;
      CLAUDE_MEM_SERVER_BETA_PROJECT_ID = env.CLAUDE_MEM_SERVER_PROJECT_ID;
      CLAUDE_MEM_SERVER_BETA_API_KEY = "";
    };

  # For activation, which may run before op-agents-load fills the keychain
  # cache: falls back to reading 1Password directly.
  activationReadKey =
    if isDarwin then
      ''
        ${config.clb.opAgents.readToken}
        read_key() {
          ${readKey} && return 0
          token="$(read_token)" || return 1
          OP_SERVICE_ACCOUNT_TOKEN="$token" ${pkgs._1password-cli}/bin/op read --no-newline \
            ${lib.escapeShellArg config.clb.opAgents.secrets.claude-mem-api-key.reference} 2>/dev/null
        }
      ''
    else
      ''
        read_key() {
          ${readKey}
        }
      '';
in
{
  _class = "homeManager";

  options.clb.claudeMem.apiKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Linux only: file holding the hosted server's read/write key, for the
      hooks (settings.json) and the MCP server. Unset, Linux gets no MCP
      server and settings.json keeps whatever key it has. Darwin uses
      op-agents.
    '';
  };

  config = {
    home.packages = [
      claudeMem
      # Keep config.toml, hooks.json, project trusts, and login state writable.
      # The package adds its inline hooks/MCP through targeted CLI overrides.
      # Routes through the CLIProxyAPI hub when its key is present
      # (cliproxyapi.nix).
      (pkgs.writeShellScriptBin "codex" ''
        ${config.clb.cliproxyapi.codexEnv}
        ${config.clb.obot.codexEnv}
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
      # Hooks send to the hosted server on ai-hub (docs/ai-hub.md
      # step 13). The API key is a secret, so activation writes it into
      # settings.json from op-agents (claudeMemServerSettings below). Without
      # it, the worker falls back to local SQLite.
      CLAUDE_MEM_RUNTIME = "server";
      # The LAN name: hosts are on the home LAN. ai-hub overrides this
      # with loopback and clb-work with its failover proxy (hosts/*/home.nix).
      CLAUDE_MEM_SERVER_URL = lib.mkDefault "http://ai-hub.home.clb.ai:37877";
      CLAUDE_MEM_SERVER_PROJECT_ID = "3bee384a-652b-4947-bd36-027c429b4589";
    };

    # Merge the server settings and the API key into the mutable
    # settings.json, keeping everything else. A key that can't be read keeps
    # the current one. Stop a running worker on change so the next hook starts
    # one that reads them.
    home.activation.claudeMemServerSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dataDir="${config.home.homeDirectory}/.claude-mem"
      settings="$dataDir/settings.json"

      ${pkgs.coreutils}/bin/install -d -m 700 "$dataDir"
      if [ ! -e "$settings" ]; then
        printf '{}\n' > "$settings"
      fi
      key=""
      ${lib.optionalString hasKey ''
        ${activationReadKey}
        if ! key="$(read_key)" || [ -z "$key" ]; then
          key=""
          warnEcho "claude-mem: can't read the server API key; keeping the current one (${config.clb.opAgents.tokenFix})"
        fi
      ''}
      tmp="$(${pkgs.coreutils}/bin/mktemp "$dataDir/settings.json.XXXXXX")"
      ${pkgs.jq}/bin/jq --argjson server ${lib.escapeShellArg (builtins.toJSON serverSettings)} \
        --arg key "$key" \
        '. + $server + (if $key == "" then {} else {CLAUDE_MEM_SERVER_API_KEY: $key} end)' \
        "$settings" > "$tmp"
      unset key
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

    clb.opAgents.secrets = lib.mkIf isDarwin {
      claude-mem-api-key.reference = "op://Agents/claude-mem-rw/credential";
    };

    programs.claude-code = {
      enable = true;
      plugins = [ claudeMemPlugin ];
      # Leave settings empty: existing mutable settings.json remains its owner.
      # Search and memory tools from the hosted server.
      mcpServers = lib.mkIf hasKey {
        claude-mem = {
          type = "http";
          url = "${config.home.sessionVariables.CLAUDE_MEM_SERVER_URL}/v1/mcp";
          headersHelper = "${mcpHeaders}";
        };
      };
    };

    # Drop the hand-added user-scope entry (`claude mcp add`) the server above
    # replaces, so the tools don't load twice.
    home.activation.claudeMemMcpMigrate = lib.mkIf hasKey (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ${pkgs.jq}/bin/jq -e '.mcpServers["claude-mem"]' \
          "${config.home.homeDirectory}/.claude.json" >/dev/null 2>&1; then
          run ${pkgs.claude-code}/bin/claude mcp remove --scope user claude-mem || true
        fi
      ''
    );

    home.file = lib.listToAttrs (
      lib.concatMap (name: [
        {
          name = ".codex/skills/${name}";
          value.source = "${claudeMem.pluginRoot}/skills/${name}";
        }
      ]) memorySkills
    );
  };
}
