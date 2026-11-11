# op-agents: one secret per host

Where this fits in the setup order: [docs/README.md](README.md).

Every host holds exactly one secret: the token for the `agents` 1Password
service account. That account can only read the `Agents` vault, and every
other secret the hosts need lives there. What a host can reach is what you put
in `Agents`; your Private and other vaults stay out of reach.

- `modules/common/programs/op-agents.nix` (Home Manager, every host):
  - `op-agents`: `op` as the service account, e.g.
    `op-agents read op://Agents/CLIProxyAPI/cliproxyapi-api-key`.
  - `op-agents-check`: tests the token, and on Darwin each cached secret.
  - Darwin: the token is in the login keychain (service
    `op-agents-service-account`), which stays unlocked while the screen and
    1Password are locked. `op-agents-set-token` stores it.
    `clb.opAgents.secrets` lists Agents items that the `op-agents-load`
    launchd job caches into the keychain (service `op-agents:<name>`) at login
    and hourly. Wrappers read the cache, so they're fast and work offline.
  - NixOS: reads the token from `/run/secrets/op-agents-token`.
- `modules/nixos/op-agents.nix` (system, every NixOS host):
  - sops-nix decrypts the token from the host's `secrets.yaml` to
    `/run/secrets/op-agents-token`. It is the only sops secret.
  - `clb.opAgents.secrets` lists secrets that `op-agents.service` writes to
    `/run/op-agents/<name>` (tmpfs) at boot. Each takes a `reference`, or a
    `template` with `{{ op://... }}` references for env files (`op inject`).
    Services listed in a secret's `services` start after it.
  - `op-agents-refresh.timer` refetches hourly and restarts the services
    whose secrets changed.

Consumers: agent-git (`docs/agent-git.md`), the CLIProxyAPI client key
(`modules/common/programs/cliproxyapi.nix`), and srv-devbox's services
(`docs/srv-devbox.md`).

## Agents vault items

**Boot** marks the items srv-devbox's system services read through
`op-agents.service`. It fetches them all in one run and fails if any is
missing, and every service that reads one requires it, so they must all
exist before the `task system` in `docs/srv-devbox.md` step 7.

| Item | Field | Boot | Used by |
| --- | --- | --- | --- |
| `git-agent` (SSH Key) | `private key`, `public key` | | agent-git, every host |
| `CLIProxyAPI` (API Credential) | `cliproxyapi-api-key` | yes | Claude Code and Codex wrappers on every host; the hub and claude-mem worker on srv-devbox |
| `CLIProxyAPI` | `password` (the management key) | yes | hub panel, CPA Usage Keeper |
| `OpenRouter` (API Credential) | `credential` | yes | hub's OpenRouter upstream |
| `cpa-usage-keeper` (Password) | `password` | yes | Keeper dashboard login |
| `claude-mem-server-env` (Secure Note) | `notesPlain` | yes | claude-mem worker dotenv |
| `claude-mem-viewer` (API Credential) | `credential` (`memories:read` key) | yes | claude-mem viewer proxy (Caddy) on srv-devbox |
| `clb-memory-rw` (API Credential) | `credential` (`memories:read,memories:write` key) | | claude-mem hooks and MCP server on every host, set by hand (`docs/claude-mem.md`) |
| `claude-mem-api-key` (API Credential) | `credential` (`memories:read,memories:write` key) | | the key `clb-memory-rw` replaces; delete once revoked |

To add one: create the item in `Agents`, then add it to
`clb.opAgents.secrets` (system or Home Manager) and point the consumer at its
`path` (NixOS) or `readCommand` (Darwin).

## One-time setup

1Password.com > **Developer > Service Accounts > New**:

- Name: `agents`
- Vault: `Agents`, **read** only. Grant access when creating it; you may not
  be able to change vault access afterwards.
- Copy the token. 1Password shows it once. Save it as an API Credential in
  your Private vault, not `Agents`. The current item is
  `op://Private/ztezaqx7cdcf65dgxtawptugaq/credential` in the `my` account.

Reading it below needs `op` signed in as you; see "Before you start" in
`docs/agent-git.md`.

## Mac

After `task switch`:

```sh
op read --account my "op://Private/ztezaqx7cdcf65dgxtawptugaq/credential" | op-agents-set-token
op-agents-check
```

Without a pipe it reads the clipboard. It checks the token with `op whoami`,
stores it, clears the clipboard, and reloads `op-agents-load` and
agent-git. Don't use `security add-generic-password -w` at its prompt: the
prompt truncates input at 128 characters.

## NixOS host

For srv-devbox this is step 7 of `docs/srv-devbox.md`; create the Boot items
above first.

1. On the host, convert its SSH host key to an age recipient:

   ```sh
   nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
   ```

   Add it to `.sops.yaml` under `keys`, with a `creation_rules` entry for
   `hosts/<name>/secrets.yaml`.

2. On a Mac signed in to `op`, in the repo root, encrypt the token to it:

   ```sh
   op read --account my "op://Private/ztezaqx7cdcf65dgxtawptugaq/credential" \
     | sed 's/^/op-agents-token: /' \
     | nix run nixpkgs#sops -- encrypt --filename-override hosts/<name>/secrets.yaml \
       --input-type yaml --output-type yaml /dev/stdin > hosts/<name>/secrets.yaml
   ```

   Only the host can decrypt the file, so to change it, rerun this instead of
   `sops edit`. srv-devbox's file still stores the token as `agent-git-token`
   (`sops.secrets.op-agents-token.key` in its `system.nix`); rerunning this
   for it lets you drop that line.

3. Set `sops.defaultSopsFile = ./secrets.yaml;` in `hosts/<name>/system.nix`.
   Commit, push, pull on the host, then `task system` and `task home`.
4. Run `op-agents-check` and `systemctl status op-agents`.

Reinstalling a host changes its host key. Repeat steps 1 to 3.

## Operations

- **Logs**: `~/Library/Logs/op-agents.log` on Darwin;
  `journalctl -u op-agents -u op-agents-refresh` on NixOS.
- **Refresh now**: `launchctl kickstart -k gui/$(id -u)/com.clburlison.op-agents-load`
  on Darwin; `sudo systemctl start op-agents-refresh` on NixOS.
- **Rotate a secret**: change it in `Agents`. Hosts pick it up within the
  hour, or refresh now. NixOS restarts the services that read it.
- **Rotate the token**: create a new token for the service account, update
  it in your Private vault, run `op-agents-set-token` on every Mac and redo
  step 2 of "NixOS host" for each NixOS host, then revoke the old one.
- **Machine compromised**: rotate the token and every secret in `Agents`.

## Limits

- Any process running as you can read the token, and so everything in
  `Agents`. Keep only agent secrets there.
- On NixOS, one missing or unreadable item fails `op-agents.service`, and
  with it every service that reads any of its secrets.
- On NixOS, boot needs 1Password reachable: `op-agents.service` retries for
  10 minutes, and services that need its secrets wait for it. After that,
  `sudo systemctl restart op-agents` and the waiting services.
- Service accounts are rate limited, hence the hourly refresh.
- Darwin needs a logged-in session to read the keychain.
