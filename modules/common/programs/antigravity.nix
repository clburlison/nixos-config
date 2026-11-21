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
  effortModels = import ../../../lib/effort-models.nix { inherit lib; };
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

  # agy shows hub models by id (gemini-4-neon-xhigh) and takes no display
  # names, so `agy acp` (T3 Code) runs through this filter, which swaps in
  # effortModels.labels: grouped models in the `model` config option, and
  # each effort in `availableModels`. Only those names change; ids and
  # values stay, so model selection is unaffected. Other lines pass as is.
  acpLabels = pkgs.writeText "agy-acp-labels.jq" ''
    def relabel($names): map(.name |= ($names[.] // .));
    . as $line
    | if test("\"(availableModels|configOptions)\"") then
        try (
          fromjson
          | walk(
              if type == "object" then
                (if .id == "model" and (.options | type) == "array"
                  then .options |= relabel($labels.models) else . end)
                | (if (.availableModels | type) == "array"
                  then .availableModels |= relabel($labels.efforts) else . end)
              else . end)
          | tojson
        ) catch $line
      else $line end
  '';

  # T3 Code's built-in Antigravity provider runs agy with a private
  # GEMINI_HOME per instance: <state dir>/providers/antigravity/<hex
  # sha256 of the instance id>. At each start T3 links ~/.gemini's skills
  # and AGENTS.md/GEMINI.md into it, but not hooks.json or mcp_config.json.
  agy = "${config.home.profileDirectory}/bin/agy";
  t3Profile = "${config.home.homeDirectory}/.t3/userdata/providers/antigravity/${builtins.hashString "sha256" "antigravity"}";
  t3ProfileConfigs = [
    "hooks.json"
    "mcp_config.json"
  ];

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
      # The hub's per-effort models; the first is the default.
      default = effortModels.names;
      defaultText = lib.literalMD "the hub's per-effort models (`lib/effort-models.nix`)";
      description = ''
        Hub model ids agy offers (/v1/models). The first is the default:
        unlisted, agy defaults to the hub's first model, which may be dead.
        agy groups names that differ only by an effort suffix, e.g.
        `gemini-4-neon-low` to `-xhigh`, into one model with a Thinking
        Level setting (also in T3 Code over ACP); the first listed is its
        default level. A plain name sharing that base shows as a separate,
        effort-less model.
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
          if [ "''${1:-}" = acp ]; then
            exec > >(exec ${pkgs.jq}/bin/jq -R -r --unbuffered \
              --argjson labels ${lib.escapeShellArg (builtins.toJSON effortModels.labels)} \
              -f ${acpLabels})
          fi
          exec -a "$0" ${pkgs.antigravity-cli}/bin/agy "$@"
          EOF
          chmod +x $out/bin/agy
        '';
        inherit (pkgs.antigravity-cli) meta;
      })
    ];

    # T3 Code's built-in Antigravity provider on the wrapper, for the hub
    # env (T3 accepts a custom binary named agy).
    clb.t3.providerInstances.antigravity = {
      driver = "antigravity";
      enabled = true;
      config = {
        enabled = true;
        binaryPath = agy;
      };
    };

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

      # T3's Antigravity profile reads hooks and MCP servers from its own
      # config dir: link ~/.gemini's. T3 creates the profile 0700.
      profile=${lib.escapeShellArg t3Profile}
      ${pkgs.coreutils}/bin/install -d -m 700 "$profile"
      ${pkgs.coreutils}/bin/install -d -m 755 "$profile/config"
      for name in ${lib.escapeShellArgs t3ProfileConfigs}; do
        ${pkgs.coreutils}/bin/ln -sfn ${lib.escapeShellArg gemini}/"$name" "$profile/config/$name"
      done
    '';
  };
}
