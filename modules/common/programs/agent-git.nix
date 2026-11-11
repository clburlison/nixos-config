{
  config,
  lib,
  pkgs,
  ...
}:

# Git signing and GitHub SSH push with an agent key that works while 1Password
# is locked, or on a headless host without 1Password. Every session uses it;
# 1Password and the personal key are the fallback when it isn't loaded. A
# 1Password service account reads one SSH key, shared by all machines, from the
# Agents vault and loads it into a dedicated ssh-agent. The token comes from
# op-agents.nix. See docs/agent-git.md.
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  home = config.home.homeDirectory;
  vault = "Agents";
  item = "git-agent";
  socket = "${home}/.ssh/agent-git.sock";
  publicKeyFile = "${home}/.ssh/agent-git.pub";
  logFile = "${home}/Library/Logs/agent-git.log";
  inherit (config.clb.opAgents) readToken tokenSource tokenFix;

  sshKeygen = if isDarwin then "/usr/bin/ssh-keygen" else "${pkgs.openssh}/bin/ssh-keygen";
  # Signs with the personal key when the agent key isn't loaded. Linux has no
  # 1Password app, so it uses the session agent, e.g. one forwarded over SSH.
  fallbackSigner =
    if isDarwin then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" else sshKeygen;
  logHint = if isDarwin then logFile else "journalctl --user -u agent-git-load";

  # git's gpg.ssh.program. Signs with the agent key when loaded.
  # Otherwise falls back to the personal key from ~/.gitconfig, so machines
  # without the agent key keep today's behavior.
  agentGitSign = pkgs.writeShellApplication {
    name = "agent-git-sign";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      if [ "''${1:-}" != "-Y" ] || [ "''${2:-}" != "sign" ] \
        || SSH_AUTH_SOCK=${socket} ssh-add -L >/dev/null 2>&1; then
        SSH_AUTH_SOCK=${socket} exec ${sshKeygen} "$@"
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
      ${fallbackSigner} "''${args[@]}"
    '';
  };

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
        echo "$(date -u +%FT%TZ) no token in ${tokenSource}; skipping" >&2
        exit 0
      fi
      export OP_SERVICE_ACCOUNT_TOKEN

      op read "op://${vault}/${item}/private key?ssh-format=openssh" | ssh-add -q -
      ssh-add -L | head -n 1 > ${publicKeyFile}
      echo "$(date -u +%FT%TZ) loaded ${vault}/${item}" >&2
    '';
  };

  checkServices =
    if isDarwin then
      ''
        for label in com.clburlison.agent-git-ssh-agent com.clburlison.agent-git-load; do
          if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
            pass "launchd job loaded: $label"
          else
            fail "launchd job missing: $label" "run task switch"
          fi
        done
      ''
    else
      ''
        for unit in agent-git-ssh-agent.service agent-git-load.timer; do
          if systemctl --user is-active --quiet "$unit"; then
            pass "systemd user unit active: $unit"
          else
            fail "systemd user unit inactive: $unit" "run task home; check loginctl show-user $USER -p Linger"
          fi
        done
      '';

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
      failures=0
      pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
      fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "''${2:-}" ] && printf '       %s\n' "$2"; failures=$((failures + 1)); }
      info() { printf '  \033[33minfo\033[0m %s\n' "$1"; }

      echo "agent-git: ${vault}/${item}"

      echo "1Password service account"
      if token="$(read_token)"; then
        pass "token in ${tokenSource}"
        if whoami_err="$(OP_SERVICE_ACCOUNT_TOKEN="$token" op whoami 2>&1 >/dev/null)"; then
          pass "op whoami: service account authenticates"
        else
          fail "op whoami rejected the token (''${#token} chars)" "${tokenFix}: $(tail -n 1 <<<"$whoami_err")"
        fi
        if vault_pub="$(OP_SERVICE_ACCOUNT_TOKEN="$token" op read "op://${vault}/${item}/public key" 2>/dev/null)"; then
          pass "item readable: op://${vault}/${item}"
        else
          fail "cannot read op://${vault}/${item}" "check item name and the service account's vault access"
        fi
      else
        fail "no token in ${tokenSource}" "${tokenFix}"
      fi
      unset token

      echo "ssh-agent"
      ${checkServices}
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
        fail "no key in agent" "run agent-git-load; logs: ${logHint}"
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
        if (
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

      echo "Config"
      if [ "$(git config --get user.signingkey || true)" = ${publicKeyFile} ]; then
        pass "git signs with agent-git"
      else
        fail "git does not sign with agent-git" "check ~/.config/git/agent-git is included from ~/.gitconfig"
      fi
      if [ -n "$agent_pub" ]; then
        if ssh -G github.com | grep -qx "identityagent ${socket}"; then
          pass "ssh to github.com uses agent-git"
        else
          fail "ssh to github.com does not use agent-git" "check dotfiles/ssh/config"
        fi
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
  _class = "homeManager";

  config = lib.mkMerge [
    {
      home.packages = [
        agentGitCheck
        agentGitLoad
      ];

      # Included last from dotfiles/gitconfig, so it overrides the 1Password
      # signer there. agent-git-sign falls back to it.
      xdg.configFile."git/agent-git".text = lib.generators.toGitINI {
        user.signingkey = publicKeyFile;
        gpg.ssh.program = "${agentGitSign}/bin/agent-git-sign";
      };
    }

    (lib.mkIf isDarwin {
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
    })

    # User services start at boot when the host enables lingering, so the key
    # loads before anyone logs in.
    (lib.mkIf isLinux {
      systemd.user.services.agent-git-ssh-agent = {
        Unit.Description = "ssh-agent for the agent-git key";
        Service = {
          # A stale socket from a crash blocks ssh-agent from binding.
          ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${socket}";
          ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a ${socket}";
          Restart = "always";
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.agent-git-load = {
        Unit = {
          Description = "Load the agent-git key from 1Password";
          After = [ "agent-git-ssh-agent.service" ];
          Requires = [ "agent-git-ssh-agent.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${agentGitLoad}/bin/agent-git-load";
        };
      };

      # Retries after boot, network loss, or an ssh-agent restart. A no-op once
      # the key is loaded.
      systemd.user.timers.agent-git-load = {
        Unit.Description = "Retry loading the agent-git key";
        Timer = {
          OnStartupSec = "10s";
          OnUnitActiveSec = "5min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ];
}
