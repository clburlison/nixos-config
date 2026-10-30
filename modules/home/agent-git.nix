{
  config,
  lib,
  pkgs,
  ...
}:

# Unattended git signing and SSH push for coding agents while 1Password is
# locked. A 1Password service account reads one SSH key, shared by all
# machines, from the Agents vault and loads it into a dedicated ssh-agent. See
# docs/agent-git.md.
let
  home = config.home.homeDirectory;
  vault = "Agents";
  item = "git-agent";
  socket = "${home}/.ssh/agent-git.sock";
  publicKeyFile = "${home}/.ssh/agent-git.pub";
  keychainService = "op-agents-service-account";
  logFile = "${home}/Library/Logs/agent-git.log";

  # Claude Code and Codex get these to sign and push with the agent key. Your
  # interactive shells keep the 1Password agent and personal key.
  agentEnv = {
    SSH_AUTH_SOCK = socket;
    GIT_CONFIG_COUNT = "3";
    GIT_CONFIG_KEY_0 = "gpg.format";
    GIT_CONFIG_VALUE_0 = "ssh";
    GIT_CONFIG_KEY_1 = "gpg.ssh.program";
    GIT_CONFIG_VALUE_1 = "${agentGitSign}/bin/agent-git-sign";
    GIT_CONFIG_KEY_2 = "user.signingkey";
    GIT_CONFIG_VALUE_2 = publicKeyFile;
  };
  exportAgentEnv = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") agentEnv
  );

  # git's gpg.ssh.program for agents. Signs with the agent key when loaded.
  # Otherwise falls back to 1Password and the personal key from ~/.gitconfig,
  # so machines without the agent key keep today's behavior.
  agentGitSign = pkgs.writeShellApplication {
    name = "agent-git-sign";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      if [ "''${1:-}" != "-Y" ] || [ "''${2:-}" != "sign" ] \
        || SSH_AUTH_SOCK=${socket} ssh-add -L >/dev/null 2>&1; then
        exec /usr/bin/ssh-keygen "$@"
      fi

      personal="$(mktemp)"
      trap 'rm -f "$personal"' EXIT
      key="$(git config --file "$HOME/.gitconfig" user.signingkey)"
      printf '%s\n' "''${key#key::}" > "$personal"

      args=()
      while [ "$#" -gt 0 ]; do
        if [ "$1" = "-f" ]; then
          args+=(-f "$personal" -U)
          shift 2
        else
          args+=("$1")
          shift
        fi
      done
      /Applications/1Password.app/Contents/MacOS/op-ssh-sign "''${args[@]}"
    '';
  };

  # Shared by the loader and the check script.
  readToken = ''
    read_token() {
      /usr/bin/security find-generic-password -s ${keychainService} -a "$USER" -w 2>/dev/null
    }
  '';

  agentGitLoad = pkgs.writeShellApplication {
    name = "agent-git-load";
    runtimeInputs = [
      pkgs._1password-cli
      pkgs.coreutils
      pkgs.openssh
    ];
    text = ''
      ${readToken}
      export SSH_AUTH_SOCK=${socket}

      # Already loaded: only refresh the public key file.
      if ssh-add -L >/dev/null 2>&1; then
        ssh-add -L | head -n 1 > ${publicKeyFile}
        exit 0
      fi

      if ! OP_SERVICE_ACCOUNT_TOKEN="$(read_token)"; then
        echo "$(date -u +%FT%TZ) no token in keychain service ${keychainService}; skipping" >&2
        exit 0
      fi
      export OP_SERVICE_ACCOUNT_TOKEN

      op read "op://${vault}/${item}/private key?ssh-format=openssh" | ssh-add -q -
      ssh-add -L | head -n 1 > ${publicKeyFile}
      echo "$(date -u +%FT%TZ) loaded ${vault}/${item}" >&2
    '';
  };

  # The `security -w` prompt truncates at 128 chars, far shorter than a
  # service account token. `security -i` reads the command from stdin, which
  # keeps the token out of argv and shell history.
  agentGitSetToken = pkgs.writeShellApplication {
    name = "agent-git-set-token";
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

      printf 'add-generic-password -U -s %s -a %s -T /usr/bin/security -w %s\n' \
        ${keychainService} "$USER" "$token" | /usr/bin/security -i
      if [ -t 0 ]; then
        /usr/bin/pbcopy </dev/null
        echo "Cleared the clipboard." >&2
      fi
      unset token

      /bin/launchctl kickstart -k "gui/$(id -u)/com.clburlison.agent-git-load"
      echo "Stored in keychain service ${keychainService} and reloaded. Run agent-git-check." >&2
    '';
  };

  agentGitCheck = pkgs.writeShellApplication {
    name = "agent-git-check";
    runtimeInputs = [
      pkgs._1password-cli
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.openssh
    ];
    text = ''
      ${readToken}
      # Captured before the signing test exports the agent env.
      caller_sock="''${SSH_AUTH_SOCK:-}"
      caller_signingkey="$(git config --get user.signingkey || true)"
      failures=0
      pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
      fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "''${2:-}" ] && printf '       %s\n' "$2"; failures=$((failures + 1)); }
      info() { printf '  \033[33minfo\033[0m %s\n' "$1"; }

      echo "agent-git: ${vault}/${item}"

      echo "1Password service account"
      if token="$(read_token)"; then
        pass "token in keychain (service ${keychainService})"
        if whoami_err="$(OP_SERVICE_ACCOUNT_TOKEN="$token" op whoami 2>&1 >/dev/null)"; then
          pass "op whoami: service account authenticates"
        else
          fail "op whoami rejected the token (''${#token} chars)" "rerun agent-git-set-token: $(tail -n 1 <<<"$whoami_err")"
        fi
        if vault_pub="$(OP_SERVICE_ACCOUNT_TOKEN="$token" op read "op://${vault}/${item}/public key" 2>/dev/null)"; then
          pass "item readable: op://${vault}/${item}"
        else
          fail "cannot read op://${vault}/${item}" "check item name and the service account's vault access"
        fi
      else
        fail "no token in keychain service ${keychainService}" "run agent-git-set-token"
      fi
      unset token

      echo "ssh-agent"
      for label in com.clburlison.agent-git-ssh-agent com.clburlison.agent-git-load; do
        if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
          pass "launchd job loaded: $label"
        else
          fail "launchd job missing: $label" "run task switch"
        fi
      done
      if [ -S ${socket} ]; then
        pass "socket exists: ${socket}"
      else
        fail "socket missing: ${socket}"
      fi
      # ssh-add -L prints "The agent has no identities." on stdout, exit 1.
      if agent_pub="$(SSH_AUTH_SOCK=${socket} ssh-add -L 2>/dev/null)"; then
        agent_pub="$(head -n 1 <<<"$agent_pub")"
      else
        agent_pub=""
      fi
      if [ -n "$agent_pub" ]; then
        pass "key loaded: $(SSH_AUTH_SOCK=${socket} ssh-add -l | head -n 1)"
        if [ -n "''${vault_pub:-}" ] && [ "$(cut -d' ' -f1,2 <<<"$agent_pub")" != "$(cut -d' ' -f1,2 <<<"$vault_pub")" ]; then
          fail "loaded key differs from 1Password item" "ssh-add -D against the socket, then agent-git-load"
        fi
      else
        fail "no key in agent" "run agent-git-load; logs: ${logFile}"
      fi
      if [ -s ${publicKeyFile} ]; then
        pass "public key file: ${publicKeyFile}"
      else
        fail "public key file missing: ${publicKeyFile}"
      fi

      echo "Signing"
      if [ -n "$agent_pub" ]; then
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        printf 'agent@localhost %s\n' "$agent_pub" > "$tmp/allowed_signers"
        # Same environment agent sessions get.
        if (
          ${exportAgentEnv}
          cd "$tmp"
          git init -q repo && cd repo
          git -c user.name=agent-git -c user.email=agent@localhost \
            commit -q -S --allow-empty -m agent-git-check
          git -c gpg.ssh.allowedSignersFile="$tmp/allowed_signers" verify-commit HEAD
        ) >/dev/null 2>&1; then
          pass "signed and verified a test commit"
        else
          fail "test commit signing failed"
        fi
      else
        info "skipped: no key loaded"
      fi

      echo "GitHub"
      if [ -n "$agent_pub" ]; then
        gh_out="$(SSH_AUTH_SOCK=${socket} ssh -T -o BatchMode=yes -o IdentityAgent=${socket} git@github.com 2>&1 || true)"
        if grep -q 'successfully authenticated' <<<"$gh_out"; then
          pass "ssh auth: $(grep -o 'Hi [^!]*' <<<"$gh_out")"
        else
          fail "ssh auth to github.com failed" "add the key as an Authentication key: $gh_out"
        fi
      else
        info "skipped: no key loaded"
      fi

      echo "This shell"
      if [ "$caller_sock" = ${socket} ]; then
        pass "SSH_AUTH_SOCK points at agent-git"
      else
        info "SSH_AUTH_SOCK is not agent-git (expected outside agent sessions)"
      fi
      if [ "$caller_signingkey" = ${publicKeyFile} ]; then
        pass "git signs with agent-git"
      else
        info "git signs with your personal key (expected outside agent sessions)"
      fi

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
  options.agentGit.env = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Environment agent wrappers set to sign and push with the agent key.";
  };

  config = lib.mkIf pkgs.stdenv.isDarwin {
    agentGit.env = agentEnv;

    home.packages = [
      agentGitCheck
      agentGitLoad
      agentGitSetToken
    ];

    # T3 Code launches this same wrapper. The Codex wrapper in claude-mem.nix
    # reads agentGit.env.
    programs.claude-code.package = pkgs.symlinkJoin {
      name = "claude-code-agent-git";
      paths = [ pkgs.claude-code ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm $out/bin/claude
        makeWrapper ${pkgs.claude-code}/bin/claude $out/bin/claude \
          ${lib.concatStringsSep " " (
            lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") agentEnv
          )}
      '';
      inherit (pkgs.claude-code) meta version;
    };

    launchd.agents.agent-git-ssh-agent = {
      enable = true;
      config = {
        Label = "com.clburlison.agent-git-ssh-agent";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          # A stale socket from a crash blocks ssh-agent from binding.
          "rm -f ${socket}; exec ${pkgs.openssh}/bin/ssh-agent -D -a ${socket}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = logFile;
      };
    };

    # Retries after boot, network loss, or an ssh-agent restart. A no-op once
    # the key is loaded.
    launchd.agents.agent-git-load = {
      enable = true;
      config = {
        Label = "com.clburlison.agent-git-load";
        ProgramArguments = [ "${agentGitLoad}/bin/agent-git-load" ];
        RunAtLoad = true;
        StartInterval = 300;
        StandardErrorPath = logFile;
      };
    };
  };
}
