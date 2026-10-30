# Agent git signing while 1Password is locked

Coding agents sign commits and push over SSH through 1Password's agent, which
fails while the app is locked. `modules/home/agent-git.nix` gives agents a
separate key that works locked. Your own shells keep the 1Password agent and
personal key.

How it works on each Mac:

1. A 1Password **service account** token sits in the login keychain. The login
   keychain stays unlocked while the screen is locked.
2. launchd runs a dedicated `ssh-agent` on `~/.ssh/agent-git.sock`.
3. `agent-git-load` reads `op://Agents/git-agent/private key` with
   the token, pipes it into that agent, and writes the public key to
   `~/.ssh/agent-git.pub`. The private key never touches disk. launchd reruns it
   every 5 minutes, which is a no-op once loaded.
4. Nix wraps `claude` (which T3 Code also launches) and `codex` so their
   shells get `SSH_AUTH_SOCK` and `GIT_CONFIG_*`. Git then signs through
   `agent-git-sign` instead of `op-ssh-sign`. `dotfiles/ssh/config` skips the
   1Password agent whenever `SSH_AUTH_SOCK` offers keys, so pushes use the
   agent key too.
5. If the agent key isn't loaded, `agent-git-sign` falls back to `op-ssh-sign`
   and your personal key, and SSH falls back to the 1Password agent. A machine
   that isn't set up yet behaves as before.

Darwin only. All machines share one key.

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

1Password.com > **Developer > Service Accounts > New**:

- Name: `agents`
- Vault: `Agents`, **read** only. Grant access when creating it; you may not be
  able to change vault access afterwards.
- Copy the token. 1Password shows it once. Save it in your Private vault, not
  `Agents`, so you can paste it on each machine.

All machines share this one token.

## Per machine

### 4. Apply

```sh
task switch
```

### 5. Token in the keychain and verify

Signed in to `op` (see "Before you start"), pipe the token from your Private
vault:

```sh
op read "op://Private/<token item>/credential" | agent-git-set-token
agent-git-check
```

Use `/password` instead of `/credential` if you saved it as a Password item.
With several 1Password accounts, add `--account <shorthand>` to `op read`.
Without a pipe, `agent-git-set-token` reads the clipboard.

`agent-git-set-token` reads stdin (or the clipboard), checks the
token with `op whoami`, stores it, clears the clipboard, and reloads the key.
Don't use `security add-generic-password -w` at its prompt: the prompt
truncates input at 128 characters and service account tokens are longer.

`agent-git-check` tests each link: keychain token, `op whoami`, item access,
launchd jobs, socket, loaded key matches the item, a signed and verified test
commit, and SSH auth to GitHub. It exits non-zero on any failure. The "This
shell" lines are informational; outside an agent session they report your
personal setup.

Run it with the screen locked (for example from an agent or over SSH) to prove
the point of the setup.

### 6. Restart agents

Restart Claude Code, Codex, and T3 Code so they pick up the new wrappers. Run
`agent-git-check` from inside an agent session; the "This shell" lines should
pass.

The environment lives in `agentEnv` in `modules/home/agent-git.nix`. Claude's
wrapper sets it as process env. The Codex wrapper in
`modules/home/claude-mem.nix` passes it as `shell_environment_policy.set`
overrides, because Codex strips `*KEY*` variables such as `GIT_CONFIG_KEY_0`
from inherited env. Neither touches `~/.claude/settings.json` or
`~/.codex/config.toml`.

Codex's sandbox may block the agent socket or network. Pushes from Codex can
still need approval.

## Operations

- **Logs**: `~/Library/Logs/agent-git.log`.
- **Reload now**: `launchctl kickstart -k gui/$(id -u)/com.clburlison.agent-git-load`.
- **Rotate key**: delete both GitHub keys and the `git-agent` item, redo steps
  1 and 2, then on each machine run
  `SSH_AUTH_SOCK=~/.ssh/agent-git.sock ssh-add -D` and reload.
- **Rotate token**: create a new token for the service account, update it in
  your Private vault, run `agent-git-set-token` on every machine, then revoke
  the old one.
- **Machine compromised**: rotate the token and the key. Every machine needs
  the new token.

## Limits

- Needs a logged-in user session. After a reboot with FileVault, nothing loads
  until you log in.
- Agents can sign and push without approval. That is the goal, but it also
  means any process running as you on that machine can, too.
- Without a token, the loader logs and exits 0, so machines not yet set up stay
  quiet.
