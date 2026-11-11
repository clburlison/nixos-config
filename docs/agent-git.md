# Agent git signing while 1Password is locked

Signing commits and pushing over SSH through 1Password's agent fails while the
app is locked. `modules/common/programs/agent-git.nix` adds a separate key that works
locked and makes it the default for every session and app: shells, herdr
remote sessions, Claude Code, Codex and T3 Code. 1Password and the personal
key are the fallback.

How it works on each Mac:

1. The op-agents service account token sits in the login keychain
   (`docs/op-agents.md`). The login keychain stays unlocked while the screen
   is locked.
2. launchd runs a dedicated `ssh-agent` on `~/.ssh/agent-git.sock`.
3. `agent-git-load` reads `op://Agents/git-agent/private key` with
   the token, pipes it into that agent, and writes the public key to
   `~/.ssh/agent-git.pub`. The private key never touches disk. launchd reruns it
   every 5 minutes, which is a no-op once loaded.
4. `~/.config/git/agent-git`, included last from `dotfiles/gitconfig`, points
   git at `agent-git-sign` and the agent public key. `dotfiles/ssh/config`
   sends `github.com` to the agent socket when it holds a key. Both are config
   files, not env vars, so they apply to any process regardless of the
   environment it inherits.
5. If the agent key isn't loaded, `agent-git-sign` falls back to `op-ssh-sign`
   and your personal key, and SSH to GitHub falls back to the 1Password agent.
   SSH to other hosts is unchanged. A machine that isn't set up yet behaves as
   before.

All machines share one key. NixOS hosts work the same way, except the token
comes from a sops-nix secret instead of the keychain; see "NixOS hosts" below.

## Before you start: sign in to `op`

Setup reads the service account token from your Private vault with `op`. Sign
in first in the terminal you'll use:

```sh
eval $(op signin)   # zsh/bash
eval (op signin)    # fish
```

With 1Password's CLI integration this prompts for Touch ID and prints nothing.
Otherwise it asks for your account password and exports a session for that
shell only.

If `op` acts as if 1Password isn't installed (it says to run `eval $(op
signin)`, or `op read` reports "You are not currently signed in"), macOS is
blocking your terminal from 1Password's data. `op --debug whoami` shows
`settings.json: operation not permitted`. Either use the `eval` sign-in above,
or grant the terminal access and restart it:

```sh
tccutil reset SystemPolicyAppData com.mitchellh.ghostty
```

Then run any `op` command and click **Allow** on "Ghostty would like to access
data from other apps". The toggle is under System Settings > Privacy &
Security.

## One-time setup

### 1. Vault and SSH key item

Create a vault named `Agents`. Service accounts can't read Personal or Private
vaults. Keep only the agent key in it.

In `Agents`: **New Item > SSH Key > Generate**, type Ed25519, title
`git-agent`.

### 2. GitHub

Copy the item's public key and add it twice under GitHub **Settings > SSH and
GPG keys**, both titled `git-agent`:

- **Authentication key**: for push.
- **Signing key**: shows agent commits as Verified.

An authentication key can reach every repository your account can.

### 3. Service account

The `agents` service account from `docs/op-agents.md` reads this item. Set
it up there once.

## Per machine

### 4. Apply and set the token

`task switch`, then set the token as in "Mac" in `docs/op-agents.md`
(`op-agents-set-token` also reloads agent-git), and run:

```sh
agent-git-check
```

`agent-git-check` tests each link: token, `op whoami`, item access, launchd
jobs, socket, loaded key matches the item, a signed and verified test
commit, SSH auth to GitHub, and that git and SSH resolve to the agent key. It
exits non-zero on any failure.

Run it with the screen locked (for example from an agent or over SSH) to prove
the point of the setup.

No restart needed: git and SSH read the config on each call, including in
already running apps. Codex's sandbox may still block the agent socket or
network, so pushes from Codex can need approval.

## NixOS hosts

A headless host has no keychain or 1Password app, so the token is the
host's sops-nix secret, `/run/secrets/op-agents-token`; see "NixOS host" in
`docs/op-agents.md` to add one.

- systemd user services replace the launchd jobs: `agent-git-ssh-agent` and an
  `agent-git-load` timer every 5 minutes. The host enables lingering
  (`users.users.<user>.linger` in `hosts/srv-devbox/system.nix`), so they
  start at boot without a login.
- If the agent key isn't loaded, `agent-git-sign` falls back to the personal
  key through the session agent, such as one forwarded over SSH. There is no
  1Password app to fall back to.

Run `agent-git-check` on the host once the token is in place.

## Operations

- **Logs**: `~/Library/Logs/agent-git.log` on Darwin;
  `journalctl --user -u agent-git-load` on NixOS.
- **Reload now**: `launchctl kickstart -k gui/$(id -u)/com.clburlison.agent-git-load`
  on Darwin; `systemctl --user start agent-git-load` on NixOS.
- **Rotate key**: delete both GitHub keys and the `git-agent` item, redo steps
  1 and 2, then on each machine run
  `SSH_AUTH_SOCK=~/.ssh/agent-git.sock ssh-add -D` and reload.
- **Rotate token**: see `docs/op-agents.md`.
- **Machine compromised**: rotate the token (`docs/op-agents.md`) and the key.

## Limits

- Darwin needs a logged-in user session. After a reboot with FileVault, nothing
  loads until you log in. NixOS hosts load at boot.
- On NixOS, root on the running host can read the decrypted token in
  `/run/secrets`.
- Anything can sign and push without approval. That is the goal, but it means
  any process running as you on that machine can.
- Without a token, the loader logs and exits 0, so machines not yet set up stay
  quiet.
