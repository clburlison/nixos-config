# Antigravity CLI (agy), routed through the CLIProxyAPI hub
# (cliproxyapi.nix) and wired to claude-mem. Opt-in per host.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.clb.antigravity;
  hub = config.clb.cliproxyapi;
  claudeMem = pkgs.claude-mem;
  gemini = "${config.home.homeDirectory}/.gemini/config";

  # claude-mem's own `claude-mem antigravity-cli install` writes `bun` and
  # store paths that go stale, so write the same entries here instead.
  hook = event: {
    type = "command";
    command = "${claudeMem}/bin/claude-mem hook antigravity-cli ${event}";
    timeout = 30;
  };
  hooks = {
    SessionStart = [ (hook "context") ];
    PreInvocation = [ (hook "session-init") ];
    PostToolUse = [
      {
        matcher = "*";
        hooks = [ (hook "observation") ];
      }
    ];
    PostInvocation = [ (hook "observation") ];
    Stop = [ (hook "summarize") ];
  };
  mcpServer.command = "${claudeMem}/bin/claude-mem-mcp";

  t3Instance = {
    driver = "acpRegistry";
    displayName = "Antigravity (hub)";
    config = {
      source = "local";
      commandPath = "${config.home.profileDirectory}/bin/agy";
      commandArgs = [ "acp" ];
    };
  };

  # Obot's vMCPs (obot.nix). agy has no headers helper and expands no
  # variables in mcp_config.json, so the key goes into the file (mode 600),
  # refreshed at each switch. Activation may run before op-agents-load fills
  # the keychain cache, so Darwin falls back to reading 1Password directly.
  obot = config.clb.obot;
  obotEnabled =
    obot.vmcps != { }
    && (if pkgs.stdenv.isDarwin then obot.apiKeyReference != null else obot.apiKeyFile != null);
  obotServers = lib.mapAttrs (_: id: { url = "${obot.url}/mcp-connect/${id}"; }) obot.vmcps;
  readObotKey =
    if pkgs.stdenv.isDarwin then
      ''
        ${config.clb.opAgents.readToken}
        read_obot_key() {
          ${config.clb.opAgents.secrets.obot-api-key.readCommand} && return 0
          token="$(read_token)" || return 1
          OP_SERVICE_ACCOUNT_TOKEN="$token" ${pkgs._1password-cli}/bin/op read --no-newline \
            ${lib.escapeShellArg obot.apiKeyReference} 2>/dev/null
        }
      ''
    else
      ''
        read_obot_key() {
          cat ${lib.escapeShellArg (toString obot.apiKeyFile)} 2>/dev/null
        }
      '';
in
{
  _class = "homeManager";

  options.clb.antigravity = {
    enable = lib.mkEnableOption "the Antigravity CLI (agy) through the hub, with claude-mem";
    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gemini-4-neon-xhigh"
        "claude-opus-5-5"
        "claude-sonnet-5-5"
        "gpt-6.2-sol"
      ];
      description = ''
        Hub model ids agy offers (/v1/models). The first is the default:
        unlisted, agy defaults to the hub's first model, which may be dead.
      '';
    };
    hubUrl = lib.mkOption {
      type = lib.types.str;
      default = hub.url;
      defaultText = lib.literalExpression "config.clb.cliproxyapi.url";
      example = "https://ai-hub.mermaid-agama.ts.net:8443";
      description = ''
        Hub URL for agy, without /v1. agy rejects a remote plain-http
        gateway, so it must be loopback or https (the hub's tailnet HTTPS
        port, hosts/ai-hub/cliproxyapi.nix).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # agy refuses a remote plain-http gateway.
        assertion =
          !hub.enable
          ||
            builtins.match "https://.*|http://(127\\.[0-9.]+|localhost|\\[::1])(:[0-9]+)?(/.*)?" cfg.hubUrl
            != null;
        message = "clb.antigravity.hubUrl must be loopback or https; agy rejects remote plain http.";
      }
    ];

    home.packages = [
      (pkgs.symlinkJoin {
        name = "antigravity-cli-cliproxyapi";
        paths = [ pkgs.antigravity-cli ];
        postBuild = ''
          rm $out/bin/agy
          cat > $out/bin/agy <<'EOF'
          #! ${pkgs.bash}/bin/bash
          ${hub.agyEnv}
          if [ -n "''${AGY_LLM_GATEWAY_API_KEY:-}" ]; then
            export AGY_LLM_GATEWAY_URL=${lib.escapeShellArg cfg.hubUrl}
          fi
          export AGY_LLM_GATEWAY_MODELS=${lib.escapeShellArg (lib.concatStringsSep "," cfg.models)}
          exec -a "$0" ${pkgs.antigravity-cli}/bin/agy "$@"
          EOF
          chmod +x $out/bin/agy
        '';
        inherit (pkgs.antigravity-cli) meta;
      })
    ];

    # Skills from agent-skills.nix. agy reads global skills from
    # ~/.gemini/config/skills, not the target's default
    # ~/.gemini/antigravity/skills.
    programs.agent-skills.targets.antigravity = {
      enable = true;
      dest = "$HOME/.gemini/config/skills";
    };

    # Merge claude-mem's hooks and MCP server, and the Obot vMCPs, into
    # agy's mutable configs, keeping every other entry.
    home.activation.antigravityConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      merge_json() {
        file="$1" mode="$2" filter="$3"; shift 3
        ${pkgs.coreutils}/bin/install -d -m 755 "''${file%/*}"
        if [ ! -s "$file" ]; then
          printf '{}\n' > "$file"
        fi
        tmp="$(${pkgs.coreutils}/bin/mktemp "$file.XXXXXX")"
        ${pkgs.jq}/bin/jq "$@" "$filter" "$file" > "$tmp"
        if ${pkgs.diffutils}/bin/cmp -s "$tmp" "$file"; then
          ${pkgs.coreutils}/bin/rm -f "$tmp"
        else
          ${pkgs.coreutils}/bin/chmod "$mode" "$tmp"
          ${pkgs.coreutils}/bin/mv "$tmp" "$file"
        fi
      }
      merge_json ${lib.escapeShellArg "${gemini}/hooks.json"} 644 \
        '.["claude-mem"] = $hooks' \
        --argjson hooks ${lib.escapeShellArg (builtins.toJSON hooks)}
      merge_json ${lib.escapeShellArg "${gemini}/mcp_config.json"} 600 \
        '.mcpServers["claude-mem"] = $server' \
        --argjson server ${lib.escapeShellArg (builtins.toJSON mcpServer)}
      ${lib.optionalString obotEnabled ''
        ${readObotKey}
        # The key reaches jq through the environment, not argv.
        if OBOT_KEY="$(read_obot_key)" && [ -n "$OBOT_KEY" ]; then
          export OBOT_KEY
          merge_json ${lib.escapeShellArg "${gemini}/mcp_config.json"} 600 \
            '.mcpServers += ($servers | map_values(.headers.Authorization = "Bearer " + $ENV.OBOT_KEY))' \
            --argjson servers ${lib.escapeShellArg (builtins.toJSON obotServers)}
        else
          warnEcho "antigravity: can't read the Obot API key; keeping the current vMCP entries (${config.clb.opAgents.tokenFix})"
        fi
        unset OBOT_KEY
      ''}

      # T3 Code: agy as a local ACP agent, which keeps ~/.gemini (hooks,
      # MCP, skills) and the wrapper's hub env. T3's built-in Antigravity
      # provider runs agy with its own GEMINI_HOME instead. commandArgs is
      # hidden in T3's form. Only where T3 already has settings.
      t3=${lib.escapeShellArg "${config.home.homeDirectory}/.t3/userdata/settings.json"}
      if [ -s "$t3" ]; then
        merge_json "$t3" 644 \
          '.providerInstances.agy = ((.providerInstances.agy // {}) * $instance)' \
          --argjson instance ${lib.escapeShellArg (builtins.toJSON t3Instance)}
      fi
    '';
  };
}
