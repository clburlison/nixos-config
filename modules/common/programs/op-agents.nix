{
  config,
  lib,
  pkgs,
  ...
}:

# The one secret every host holds: a token for the `agents` 1Password service
# account, which reads only the Agents vault. Everything else comes from that
# vault through it. Darwin keeps the token in the login keychain; NixOS gets it
# from a sops-nix secret (modules/nixos/op-agents.nix). On Darwin, a launchd
# job also caches each secret in clb.opAgents.secrets into the keychain, so
# wrappers read them fast, offline, and while 1Password is locked. See
# docs/op-agents.md.
let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.clb.opAgents;
  keychainService = "op-agents-service-account";
  cachePrefix = "op-agents:";
  logFile = "${config.home.homeDirectory}/Library/Logs/op-agents.log";
  tokenSource = if isDarwin then "keychain service ${keychainService}" else cfg.tokenFile;

  readToken =
    if isDarwin then
      ''
        read_token() {
          /usr/bin/security find-generic-password -s ${keychainService} -a "$USER" -w 2>/dev/null
        }
      ''
    else
      ''
        read_token() {
          cat ${lib.escapeShellArg cfg.tokenFile} 2>/dev/null
        }
      '';

  # store_secret SERVICE VALUE: writes a login keychain item readable by
  # /usr/bin/security. Updating an existing item in place (`-U` with `-T`)
  # rewrites its ACL, which makes macOS prompt for the keychain password. So
  # an unchanged value is left alone, and a changed one is deleted and re-added.
  # `security -i` reads the command from stdin, keeping the value out of argv.
  storeSecret = ''
    store_secret() {
      if [ "$(/usr/bin/security find-generic-password -s "$1" -a "$USER" -w 2>/dev/null)" = "$2" ]; then
        return 0
      fi
      /usr/bin/security delete-generic-password -s "$1" -a "$USER" >/dev/null 2>&1 || true
      printf 'add-generic-password -s %s -a %s -T /usr/bin/security -w %s\n' \
        "$1" "$USER" "$2" | /usr/bin/security -i
    }
  '';

  # `op` as the service account, e.g. `op-agents read op://Agents/item/field`.
  opAgents = pkgs.writeShellApplication {
    name = "op-agents";
    runtimeInputs = [ pkgs._1password-cli ];
    text = ''
      ${readToken}
      if ! OP_SERVICE_ACCOUNT_TOKEN="$(read_token)"; then
        echo "no token in ${tokenSource}; ${cfg.tokenFix}" >&2
        exit 1
      fi
      export OP_SERVICE_ACCOUNT_TOKEN
      exec op "$@"
    '';
  };

  # Refreshes the keychain cache. A secret that fails to read keeps its last
  # cached value.
  opAgentsLoad = pkgs.writeShellApplication {
    name = "op-agents-load";
    runtimeInputs = [ opAgents ];
    text = ''
      ${storeSecret}
      failures=0
      ${lib.concatMapStrings (name: ''
        if value="$(op-agents read --no-newline ${lib.escapeShellArg cfg.secrets.${name}.reference})"; then
          store_secret ${lib.escapeShellArg "${cachePrefix}${name}"} "$value"
        else
          echo "$(date -u +%FT%TZ) failed to read ${name}" >&2
          failures=$((failures + 1))
        fi
      '') (lib.attrNames cfg.secrets)}
      unset value
      echo "$(date -u +%FT%TZ) cached ${toString (lib.length (lib.attrNames cfg.secrets))} secret(s), $failures failed" >&2
      [ "$failures" -eq 0 ]
    '';
  };

  # The `security -w` prompt truncates at 128 chars, far shorter than a
  # service account token. `security -i` reads the command from stdin, which
  # keeps the token out of argv and shell history.
  opAgentsSetToken = pkgs.writeShellApplication {
    name = "op-agents-set-token";
    runtimeInputs = [ pkgs._1password-cli ];
    text = ''
      if [ -t 0 ]; then
        echo "Reading token from the clipboard." >&2
        token="$(/usr/bin/pbpaste)"
      else
        token="$(cat)"
      fi
      token="$(printf '%s' "$token" | tr -d '[:space:]')"

      if [ -z "$token" ]; then
        echo "No token on the clipboard or stdin." >&2
        exit 1
      fi
      if ! OP_SERVICE_ACCOUNT_TOKEN="$token" op whoami >/dev/null; then
        echo "op whoami rejected the token (''${#token} chars); not stored." >&2
        exit 1
      fi

      ${storeSecret}
      store_secret ${keychainService} "$token"
      if [ -t 0 ]; then
        /usr/bin/pbcopy </dev/null
        echo "Cleared the clipboard." >&2
      fi
      unset token

      for label in com.clburlison.op-agents-load com.clburlison.agent-git-load; do
        /bin/launchctl kickstart -k "gui/$(id -u)/$label" || true
      done
      echo "Stored in keychain service ${keychainService} and reloaded. Run op-agents-check." >&2
    '';
  };

  opAgentsCheck = pkgs.writeShellApplication {
    name = "op-agents-check";
    runtimeInputs = [
      opAgents
      pkgs.coreutils
    ];
    text = ''
      ${readToken}
      failures=0
      pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
      fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "''${2:-}" ] && printf '       %s\n' "$2"; failures=$((failures + 1)); }

      echo "1Password service account"
      if token="$(read_token)"; then
        pass "token in ${tokenSource}"
        if whoami_err="$(op-agents whoami 2>&1 >/dev/null)"; then
          pass "op whoami: service account authenticates"
        else
          fail "op whoami rejected the token (''${#token} chars)" "${cfg.tokenFix}: $(tail -n 1 <<<"$whoami_err")"
        fi
      else
        fail "no token in ${tokenSource}" "${cfg.tokenFix}"
      fi
      unset token

      ${lib.optionalString (cfg.secrets != { }) ''
        echo "Secrets"
        ${lib.concatMapStrings (name: ''
          if op-agents read ${lib.escapeShellArg cfg.secrets.${name}.reference} >/dev/null 2>&1; then
            pass "readable: ${cfg.secrets.${name}.reference}"
          else
            fail "cannot read ${cfg.secrets.${name}.reference}" "check the item and the service account's vault access"
          fi
          if ${cfg.secrets.${name}.readCommand} >/dev/null; then
            pass "cached: ${name}"
          else
            fail "not cached: ${name}" "run op-agents-load; logs: ${logFile}"
          fi
        '') (lib.attrNames cfg.secrets)}
      ''}

      if [ "$failures" -eq 0 ]; then
        echo "All checks passed."
      else
        echo "$failures check(s) failed."
        exit 1
      fi
    '';
  };
in
{
  _class = "homeManager";

  options.clb.opAgents = {
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/op-agents-token";
      description = "Linux only: file holding the service account token. Darwin uses the keychain.";
    };
    readToken = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      default = readToken;
      description = "Shell snippet defining read_token, which prints the token or fails.";
    };
    tokenSource = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = tokenSource;
      description = "Where the token lives, for messages.";
    };
    tokenFix = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = if isDarwin then "run op-agents-set-token" else "add the sops secret (docs/op-agents.md)";
      description = "How to fix a missing or rejected token, for messages.";
    };
    secrets = lib.mkOption {
      description = ''
        Darwin only: Agents vault secrets cached in the login keychain. On
        NixOS, use the system module's clb.opAgents.secrets instead.
      '';
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              reference = lib.mkOption {
                type = lib.types.str;
                example = "op://Agents/CLIProxyAPI/cliproxyapi-api-key";
                description = "1Password secret reference.";
              };
              readCommand = lib.mkOption {
                type = lib.types.str;
                readOnly = true;
                default = ''/usr/bin/security find-generic-password -s ${lib.escapeShellArg "${cachePrefix}${name}"} -a "$USER" -w 2>/dev/null'';
                description = "Shell command that prints the cached value, or fails.";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkMerge [
    {
      home.packages = [
        opAgents
        opAgentsCheck
      ];
    }

    (lib.mkIf isDarwin {
      home.packages = [
        opAgentsLoad
        opAgentsSetToken
      ];

      # Service accounts are rate limited, so refresh hourly. Rotations reach
      # Macs within the hour; op-agents-set-token reloads at once.
      launchd.agents.op-agents-load = lib.mkIf (cfg.secrets != { }) {
        enable = true;
        config = {
          Label = "com.clburlison.op-agents-load";
          ProgramArguments = [ "${opAgentsLoad}/bin/op-agents-load" ];
          RunAtLoad = true;
          StartInterval = 3600;
          StandardErrorPath = logFile;
        };
      };
    })
  ];
}
