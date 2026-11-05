# Agent git signing while 1Password is locked

Signing commits and pushing over SSH through 1Password's agent fails while the
app is locked. `modules/common/programs/agent-git.nix` adds a separate key that works
locked and makes it the default for every session and app: shells, herdr
remote sessions, Claude Code, Codex and T3 Code. 1Password and the personal
key are the fallback.

How it works on each Mac:

1. A 1Password **service account** token sits in the login keychain. The login
   keychain stays unlocked while the screen is locked.
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

1Password.com > **Developer > Service Accounts > New**:

- Name: `agents`
- Vault: `Agents`, **read** only. Grant access when creating it; you may not be
  able to change vault access afterwards.
- Copy the token. 1Password shows it once. Save it as an API Credential in
  your Private vault, not `Agents`. The current item is
  `op://Private/ztezaqx7cdcf65dgxtawptugaq/credential` in the `my` account.
  The reference only locates the item; reading it still requires your
  1Password access.

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
op read --account my "op://Private/ztezaqx7cdcf65dgxtawptugaq/credential" | agent-git-set-token
agent-git-check
```

If you recreate the token item, update this reference and the one in step 3.
Without a pipe, `agent-git-set-token` reads the clipboard.

`agent-git-set-token` reads stdin (or the clipboard), checks the
token with `op whoami`, stores it, clears the clipboard, and reloads the key.
Don't use `security add-generic-password -w` at its prompt: the prompt
truncates input at 128 characters and service account tokens are longer.

`agent-git-check` tests each link: keychain token, `op whoami`, item access,
launchd jobs, socket, loaded key matches the item, a signed and verified test
commit, SSH auth to GitHub, and that git and SSH resolve to the agent key. It
exits non-zero on any failure.

Run it with the screen locked (for example from an agent or over SSH) to prove
the point of the setup.

No restart needed: git and SSH read the config on each call, including in
already running apps. Codex's sandbox may still block the agent socket or
network, so pushes from Codex can need approval.

## NixOS hosts

A headless host has no keychain or 1Password app, so the token is a
[sops-nix](https://github.com/Mic92/sops-nix) secret instead:

- `hosts/<name>/secrets.yaml` holds the token under `agent-git-token`,
  encrypted to the host's SSH host key. `.sops.yaml` lists each host's key,
  converted to age. Only that host can decrypt it.
- At boot sops-nix decrypts it to `/run/secrets/agent-git-token` (tmpfs, mode
  0400, owned by the host user). It never sits decrypted on disk.
- systemd user services replace the launchd jobs: `agent-git-ssh-agent` and an
  `agent-git-load` timer every 5 minutes. The host enables lingering, so they
  start at boot without a login.
- If the agent key isn't loaded, `agent-git-sign` falls back to the personal
  key through the session agent, such as one forwarded over SSH. There is no
  1Password app to fall back to.

The host override file wires it up (`sops.secrets.agent-git-token` and
`users.users.<user>.linger`; see `hosts/srv-devbox/system.nix`).

### Add a NixOS host

1. On the host, convert its SSH host key to an age recipient:

   ```sh
   nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
   ```

   Add it to `.sops.yaml` under `keys`, with a `creation_rules` entry for
   `hosts/<name>/secrets.yaml`.

2. On a Mac signed in to `op`, in the repo root, encrypt the token to it. The
   token only passes through pipes:

   ```sh
   op read --account my "op://Private/ztezaqx7cdcf65dgxtawptugaq/credential" \
     | sed 's/^/agent-git-token: /' \
     | nix run nixpkgs#sops -- encrypt --filename-override hosts/<name>/secrets.yaml \
       --input-type yaml --output-type yaml /dev/stdin > hosts/<name>/secrets.yaml
   ```

   No one but the host can decrypt the file, so to change it, rerun this
   instead of `sops edit`.

3. Commit, push, and pull on the host. Then `task system` (decrypts the
   secret, enables lingering) and `task home` (installs the services).
4. Run `agent-git-check` on the host.

Reinstalling a host changes its host key. Repeat steps 1 to 3 with the new key.

## Operations

- **Logs**: `~/Library/Logs/agent-git.log` on Darwin;
  `journalctl --user -u agent-git-load` on NixOS.
- **Reload now**: `launchctl kickstart -k gui/$(id -u)/com.clburlison.agent-git-load`
  on Darwin; `systemctl --user start agent-git-load` on NixOS.
- **Rotate key**: delete both GitHub keys and the `git-agent` item, redo steps
  1 and 2, then on each machine run
  `SSH_AUTH_SOCK=~/.ssh/agent-git.sock ssh-add -D` and reload.
- **Rotate token**: create a new token for the service account, update it in
  your Private vault, run `agent-git-set-token` on every Mac and redo step 2
  of "Add a NixOS host" for each NixOS host, then revoke the old one.
- **Machine compromised**: rotate the token and the key. Every machine needs
  the new token.

## Limits

- Darwin needs a logged-in user session. After a reboot with FileVault, nothing
  loads until you log in. NixOS hosts load at boot.
- On NixOS, root on the running host can read the decrypted token in
  `/run/secrets`.
- Anything can sign and push without approval. That is the goal, but it means
  any process running as you on that machine can.
- Without a token, the loader logs and exits 0, so machines not yet set up stay
  quiet.
