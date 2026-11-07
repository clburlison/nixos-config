# Route Claude Code and Codex through the CLIProxyAPI hub on srv-devbox
# (docs/srv-devbox.md step 11), on every host. They keep their usual
# config dirs (~/.claude, ~/.codex). The access key is a secret, so it stays
# out of Nix: the wrappers read it at each run. Darwin keeps it in the login
# keychain, set from 1Password with cliproxyapi-set-key (like agent-git's
# token); Linux reads apiKeyFile, e.g. a sops-nix secret. A host without the
# key keeps its own Claude and Codex logins.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.clb.cliproxyapi;
  keychainService = "cliproxyapi-api-key";

  # Prints the key, or fails when there is none.
  readKey =
    if isDarwin then
      ''/usr/bin/security find-generic-password -s ${keychainService} -a "$USER" -w 2>/dev/null''
    else
      "cat ${lib.escapeShellArg cfg.apiKeyFile} 2>/dev/null";

  # Codex provider for the hub, as in the gist; the key comes from
  # CLIPROXYAPI_API_KEY instead of the config file.
  codexArgs = [
    "-c"
    ''model_provider="cliproxyapi"''
    "-c"
    ''model_providers.cliproxyapi={name="CLIProxyAPI",base_url="${cfg.url}/v1",wire_api="responses",requires_openai_auth=false,supports_websockets=true,env_key="CLIPROXYAPI_API_KEY"}''
  ];

  # The `security -w` prompt truncates long input; `security -i` reads the
  # command from stdin, which keeps the key out of argv and shell history.
  setKey = pkgs.writeShellApplication {
    name = "cliproxyapi-set-key";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      if [ -t 0 ]; then
        echo "Reading key from the clipboard." >&2
        key="$(/usr/bin/pbpaste)"
      else
        key="$(cat)"
      fi
      key="$(printf '%s' "$key" | tr -d '[:space:]')"

      if [ -z "$key" ]; then
        echo "No key on the clipboard or stdin." >&2
        exit 1
      fi
      status="$(curl -s -o /dev/null -w '%{http_code}' -K - <<<"header = \"Authorization: Bearer $key\"" \
        ${lib.escapeShellArg cfg.url}/v1/models || true)"
      if [ "$status" != 200 ]; then
        echo "${cfg.url} rejected the key (HTTP $status); not stored." >&2
        exit 1
      fi

      printf 'add-generic-password -U -s %s -a %s -T /usr/bin/security -w %s\n' \
        ${keychainService} "$USER" "$key" | /usr/bin/security -i
      if [ -t 0 ]; then
        /usr/bin/pbcopy </dev/null
        echo "Cleared the clipboard." >&2
      fi
      unset key
      echo "Stored in keychain service ${keychainService}." >&2
    '';
  };
in
{
  _class = "homeManager";

  options.clb.cliproxyapi = {
    url = lib.mkOption {
      type = lib.types.str;
      default = "http://srv-devbox.mermaid-agama.ts.net:8317";
      description = "CLIProxyAPI base URL, without /v1.";
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Linux only: file holding the access key. Darwin uses the keychain.";
    };
    codexEnv = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = ''
        Shell snippet for the codex wrapper in claude-mem.nix: when the key
        is available, exports it and prepends the hub provider's `-c`
        overrides to "$@".
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = isDarwin || cfg.apiKeyFile != null;
        message = "clb.cliproxyapi.apiKeyFile must be set on Linux.";
      }
    ];

    clb.cliproxyapi.codexEnv = ''
      if cliproxyapi_key="$(${readKey})" && [ -n "$cliproxyapi_key" ]; then
        export CLIPROXYAPI_API_KEY="$cliproxyapi_key"
        set -- ${lib.escapeShellArgs codexArgs} "$@"
      fi
    '';

    home.packages = lib.mkIf isDarwin [ setKey ];

    # programs.claude-code (claude-mem.nix) wraps this again with its plugins.
    programs.claude-code.package = pkgs.symlinkJoin {
      name = "claude-code-cliproxyapi";
      paths = [ pkgs.claude-code ];
      postBuild = ''
        rm $out/bin/claude
        cat > $out/bin/claude <<'EOF'
        #! ${pkgs.bash}/bin/bash
        if key="$(${readKey})" && [ -n "$key" ]; then
          export ANTHROPIC_AUTH_TOKEN="$key"
          export ANTHROPIC_BASE_URL=${lib.escapeShellArg cfg.url}
          # With a custom base URL and token, Claude Code writes the prompt
          # cache with a 5-minute TTL instead of the subscription's 1 hour,
          # so every pause over 5 minutes rewrites the whole cache.
          # https://code.claude.com/docs/en/prompt-caching#choose-the-ttl-yourself
          export CLAUDE_CODE_PROMPT_CACHE_TTL=1h
        fi
        unset key
        ${config.clb.mcp.claudeEnv}
        exec -a "$0" ${pkgs.claude-code}/bin/claude "$@"
        EOF
        chmod +x $out/bin/claude
      '';
      inherit (pkgs.claude-code) meta;
    };
  };
}
