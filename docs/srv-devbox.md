# srv-devbox

Headless NixOS development host: a Proxmox VM, x86_64, reached over SSH. Defined by
the `srv-devbox` entry in the host table (`flake.nix`), the NixOS platform
aggregator (`modules/nixos/`), and the host override files in
`hosts/srv-devbox/`. Files named below without a path are in that
directory.

## 1. Create the Proxmox VM

| Setting | Value |
| --- | --- |
| Machine | Default (`i440fx`). The committed hardware file matches it |
| BIOS | OVMF (UEFI), with an EFI disk. Uncheck "Pre-Enroll keys" |
| CPU type | `host` |
| SCSI controller | VirtIO SCSI (`virtio-scsi-pci` or `virtio-scsi-single`) |
| Disk | On the VirtIO SCSI controller |
| Network | VirtIO (paravirtualized) NIC |
| QEMU guest agent | Enabled (Options > QEMU Guest Agent) |

Attach the Determinate NixOS installer ISO (from
<https://docs.determinate.systems>) and boot it.

Pre-enrolled keys turn on Secure Boot, which rejects the unsigned ISO and
systemd-boot with `BdsDxe: ... Access Denied`. If the EFI disk already
has keys, press Esc at boot and turn off Device Manager > Secure Boot
Configuration > Attempt Secure Boot.

## 2. Partition and mount

From the installer console. It logs in as `nixos`, so become root first;
steps 2 through 4 all run as root. Replace `/dev/sda` with the VM disk.

```sh
sudo -i
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 1GiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart root ext4 1GiB 100%

mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

`parted` prints "You may need to update /etc/fstab" after each change.
Ignore it. Step 3 records the mounts in `hardware-configuration.nix`.

## 3. Generate and push the hardware file (required)

`hardware-configuration.nix` is a placeholder. Generate the
real one:

```sh
nix-shell -p git
git clone https://github.com/clburlison/nixos-config /tmp/nixos-config
cd /tmp/nixos-config
nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/srv-devbox/hardware-configuration.nix
git add hosts/srv-devbox/hardware-configuration.nix
```

Commit and push it **before installing**. Step 5 clones from GitHub, so
every later `task system` uses the placeholder otherwise. The installer
has no GitHub credentials, so copy the file to a Mac and push from there.
On the installer, run `passwd` so root can accept SSH, then on the Mac:

```sh
cd ~/dev/me/nixos-config
scp root@<installer-ip>:/tmp/nixos-config/hosts/srv-devbox/hardware-configuration.nix \
  hosts/srv-devbox/
git add hosts/srv-devbox/hardware-configuration.nix
git commit -m "feat(srv-devbox): Add hardware configuration"
git push
```

## 4. Install

Still as root (`sudo -i` again if you left the root shell for step 3):

```sh
nixos-install --flake /tmp/nixos-config#srv-devbox
```

`nixos-install` asks for a root password at the end. Then set the user
password once. Wheel `sudo` asks for it, and it is not stored in the repo:

```sh
nixos-enter --root /mnt -c 'passwd clburlison'
```

Detach the ISO and reboot.

## 5. SSH in and clone

Password SSH is off; log in with the key from `lib/ssh-keys.nix`.

Step 6 fetches the private `clb-skills` input over SSH, so forward the
agent-git agent from the Mac (`docs/agent-git.md`). Plain `ssh -A`
forwards the empty launchd agent instead:

```sh
ssh -o ForwardAgent=~/.ssh/agent-git.sock clburlison@srv-devbox
ssh-add -l   # lists the agent-git key
```

Git comes from Home Manager, so steps 5 and 6 borrow it with
`nix shell nixpkgs#git -c`:

```sh
mkdir -p ~/dev/me
nix shell nixpkgs#git -c git clone https://github.com/clburlison/nixos-config ~/dev/me/nixos-config
cd ~/dev/me/nixos-config
```

Check that the clone has the generated hardware file, not the placeholder:

```sh
! grep -q 'TEMPORARY PLACEHOLDER' hosts/srv-devbox/hardware-configuration.nix \
  || echo 'Push the generated hardware file first (step 3)'
```

## 6. Bootstrap Home Manager

The first run installs `home-manager` into `~/.nix-profile`. Git must be
on `PATH`: without it, Nix fetches `clb-skills` with its built-in git
library, which can't use the forwarded agent and fails with
"authentication required but no callback set".

```sh
nix shell nixpkgs#git -c nix run home-manager/release-26.05 -- \
  switch --flake .#clburlison@srv-devbox
```

After that, use `task home` (no sudo), `task system` (sudo), or `task switch`.

## 7. agent-git

Lets the host sign commits and reach GitHub without a forwarded agent. The
token is a sops-nix secret (`secrets.yaml`, encrypted to this host's key in
`.sops.yaml`); see "NixOS hosts" in `docs/agent-git.md`. After a reinstall,
the host key changes: redo "Add a NixOS host" there before `task system`, or
sops-nix can't decrypt the secret.

Once `agent-git-check` passes, switch the clone from step 5 to SSH so pushes
use the agent-git key:

```sh
git remote set-url origin git@github.com:clburlison/nixos-config.git
```

## 8. Tailscale

`tailscaled` starts at boot (`services.tailscale` in `system.nix`). Log in
once after the first `task system`; the node key in `/var/lib/tailscale`
reconnects it on every boot after that:

```sh
sudo tailscale up
tailscale status
```

In the Tailscale admin console, open the machine and choose **Disable key
expiry**, or it drops off the tailnet when the key expires (180 days by
default).

## 9. T3 Code server

The `t3-serve` user service (`home.nix`) runs `t3 serve` on port 3773 on
all interfaces and also publishes it over HTTPS on the tailnet with
Tailscale Serve. Lingering starts it at boot. Serve needs step 8 done and
HTTPS certificates enabled for the tailnet (admin console > DNS > HTTPS
Certificates).

- Direct: `http://srv-devbox:3773` from the LAN or the tailnet (plain HTTP).
- Tailnet HTTPS: the `https://srv-devbox.mermaid-agama.ts.net` URL.

After `task system` and `task home`:

```sh
systemctl --user status t3-serve
journalctl --user -u t3-serve
t3 pair --tailscale   # pairing link through the tailnet HTTPS URL
t3 pair               # direct; swap the printed host for srv-devbox:3773
```

## 10. claude-mem hosted server

`claude-mem-server.nix` runs upstream's Docker Compose stack
(<https://docs.claude-mem.ai/hosted-server>) as the `claude-mem-server`
system service, pinned to a release tag. Compose builds the images locally,
so the first `task system` start takes several minutes. The server listens
on port 37877 on all interfaces.

Postgres credentials are generated once into
`/var/lib/claude-mem-server/postgres.env`. Postgres only reads them when it
creates its volume, so keep that file as long as the volume exists.

The worker generates observations through the CLIProxyAPI hub on this host
(step 11), with the OpenAI subscription logins there. `claude-mem-server.nix`
sets the provider (`openrouter`, which takes any OpenAI-compatible base
URL), the base URL (`http://host.docker.internal:8317/v1`, the Docker host
gateway, since 127.0.0.1 in the container is the container) and the model
(`gpt-6-luna`; list the hub's models with `GET /v1/models`). The key is the
hub's client access key, rendered from `cliproxyapi.yaml` by sops.

`claude-mem-server.env.sops` (sops binary dotenv, encrypted whole) holds
any other worker env. To replace it (only the host can decrypt, so rewrite
the whole file):

```sh
printf '%s\n' \
  'OPENROUTER_API_KEY=<openrouter.ai key, unused while the hub is set>' \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/claude-mem-server.env.sops \
    --input-type binary --output-type binary /dev/stdin \
  > hosts/srv-devbox/claude-mem-server.env.sops
```

To go back to openrouter.ai, drop `CLAUDE_MEM_OPENROUTER_BASE_URL` and the
rendered key env file, and set the model to an OpenRouter one (for example
`~anthropic/claude-haiku-latest`).

Commit, pull on the host, and `task system`; the secret change restarts
the service.

`sudo claude-mem-server-compose` is `docker compose` with this stack's files:

```sh
systemctl status claude-mem-server
sudo claude-mem-server-compose ps
sudo claude-mem-server-compose logs -f claude-mem-worker
# First API key (shown once):
sudo claude-mem-server-compose exec claude-mem-server \
  bun /opt/claude-mem/scripts/server-service.cjs server api-key create \
  --name clburlison --scope memories:read,memories:write
```

Connect a client through the tailnet name. It resolves on and off the home
network, and at home Tailscale connects directly over the LAN:

```sh
claude mcp add --scope user --transport http claude-mem \
  http://srv-devbox.mermaid-agama.ts.net:37877/v1/mcp \
  --header "Authorization: Bearer cm_..."
```

That name needs Tailscale running on the client. For a LAN fallback at
home with Tailscale off, add a local DNS record on the home router for
`srv-devbox.mermaid-agama.ts.net` pointing to srv-devbox's LAN IP
(192.xxx.xxx.xxx, from DHCP, so reserve it). Tailscale's MagicDNS answers
first whenever Tailscale is up, so the same URL works either way. Away from
home there is no fallback without Tailscale: upstream says not to expose
the server to the internet.

Postgres is published on the tailnet address only (`tailnetIp` in
`claude-mem-server.nix`), for database clients. The password is in
`/var/lib/claude-mem-server/postgres.env`:

```sh
psql postgres://claude_mem:<password>@100.75.137.72:5432/claude_mem
```

To upgrade, change `version` and `hash` in `claude-mem-server.nix`. Back up
first and follow upstream's "Upgrading the Postgres image" when the
Postgres image changes:

```sh
sudo claude-mem-server-compose exec postgres \
  sh -c 'pg_dumpall -U "$POSTGRES_USER"' > claude-mem-backup.sql
```

## 11. CLIProxyAPI hub

`cliproxyapi.nix` runs [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
as the `cliproxyapi` system service, following
<https://gist.github.com/t3dotgg/59a521d2ee8d70aaf90e280c175072af>. Claude
and Codex accounts sign in here once; every other machine uses this host as
its API endpoint. It listens on port 8317 on all interfaces (plain HTTP):

- LAN: `http://192.xxx.xxx.xxx:8317` (srv-devbox's LAN IP)
- Tailnet: `http://srv-devbox.mermaid-agama.ts.net:8317`

The module and package come from nixpkgs-unstable. Nix writes
`/var/lib/cliproxyapi/config.yaml` at every start, so change settings in
`cliproxyapi.nix`, not the management panel. Account logins live in
`/var/lib/cliproxyapi` and are kept.

The client access key and management key are in `cliproxyapi.yaml`
(sops, encrypted to this host). Read them on the host (the access key is
owned by the host user, for its own Claude Code and Codex):

```sh
cat /run/secrets/cliproxyapi-api-key
sudo cat /run/secrets/cliproxyapi-management-key
```

To rotate, rewrite the whole file (only the host can decrypt). Commit, pull,
and `task system`; the change restarts the service. Works in fish and bash;
the file is only replaced if encryption succeeds:

```sh
printf 'api-key: sk-%s\nmanagement-key: %s\n' \
  "$(nix run nixpkgs#openssl -- rand -hex 32)" \
  "$(nix run nixpkgs#openssl -- rand -hex 32)" \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/cliproxyapi.yaml \
    --input-type yaml --output-type yaml /dev/stdin \
  > cliproxyapi.yaml.tmp \
  && mv cliproxyapi.yaml.tmp hosts/srv-devbox/cliproxyapi.yaml
```

OpenRouter is also an upstream (`api-keys.openai-compatibility` in
`cliproxyapi.nix`): clients call the listed aliases (`glm-5.3`,
`gemma-4-31b-free`, ...) with the hub's access key, and the hub sends the
OpenRouter key. Only listed models are exposed; add more from
<https://openrouter.ai/models>. The key is in `openrouter.yaml` (sops,
encrypted to this host). Create a key at <https://openrouter.ai/keys>, then
write the file (`read -s` keeps the key out of shell history; in fish use
`read -s key`):

```sh
read -rs key
printf 'api-key: %s\n' "$key" \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/openrouter.yaml \
    --input-type yaml --output-type yaml /dev/stdin \
  > openrouter.yaml.tmp \
  && mv openrouter.yaml.tmp hosts/srv-devbox/openrouter.yaml
```

Sign accounts in with `sudo cliproxyapi-login`, which runs the binary as
the service user with the service's config and `-no-browser`, so each login
prints a URL to open on your laptop. The running service picks up new
accounts without a restart.

Claude's browser login is the annoying one: its OAuth callback lands on
port 54545 on srv-devbox, not on the laptop with the browser. Fix: open a
tunnel from the laptop first and keep it open:

```sh
ssh -L 54545:localhost:54545 -L 1455:localhost:1455 srv-devbox
```

Then, in that SSH session on srv-devbox, run once per account:

```sh
# Claude
sudo cliproxyapi-login -claude-login

# Codex, either device code
sudo cliproxyapi-login -codex-device-login

# Or Codex browser login (uses the 1455 tunnel)
sudo cliproxyapi-login -codex-login
```

Check accounts in the panel at `http://srv-devbox:8317/management.html`
(management key) and verify from another machine:

```sh
curl -s http://srv-devbox.mermaid-agama.ts.net:8317/v1/models \
  -H "Authorization: Bearer <api key>" | head -c 300
```

Claude Code and Codex route through the hub on every host
(`modules/common/programs/cliproxyapi.nix`), in their usual `~/.claude` and
`~/.codex`. Their wrappers read the key at each run and set
`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and
`CLAUDE_CODE_PROMPT_CACHE_TTL=1h` for Claude (through a custom base URL it
otherwise caches for 5 minutes, not the subscription's 1 hour), and a
`cliproxyapi` model provider for Codex. `settings.json` and `config.toml`
stay untouched. T3 Code runs the same `claude` and `codex`, so it follows
too; for Codex, pick **Use existing CLI**.

srv-devbox uses `http://127.0.0.1:8317` and reads the sops secret directly
(`hosts/srv-devbox/home.nix`). Macs use the tailnet URL and keep the key in
the login keychain (service `cliproxyapi-api-key`), like agent-git's token
(`docs/agent-git.md`): the keychain stays unlocked while 1Password is
locked. 1Password holds the source copy. Once, save the output of
`cat /run/secrets/cliproxyapi-api-key` on srv-devbox as an API Credential
named `CLIProxyAPI` in your Agents vault. Then on each Mac, signed in to
`op`, after `task home`:

```sh
op read --account my "op://Agents/CLIProxyAPI/cliproxyapi-api-key" | cliproxyapi-set-key
```

`cliproxyapi-set-key` reads stdin (or the clipboard), checks the key against
the hub, and stores it. After rotating the key, update the 1Password item
and rerun it on each Mac.

Check that cache writes use the 1-hour TTL: run
`claude -p hello --output-format json` and look for
`ephemeral_1h_input_tokens` in `usage.cache_creation`. The 1-hour request
travels partly in the `anthropic-beta` header, so the hub must forward it.

Without the key, a host keeps its own Claude and Codex logins. To sign in
directly on a Mac (e.g. clb-work), delete the key:
`security delete-generic-password -s cliproxyapi-api-key`.

## Notes

- `system.stateVersion` in `system.nix` is pinned at install. Don't bump it
  without reading the NixOS release notes.
- If the Determinate module fails on `nixos-26.05`, drop
  `determinate.nixosModules.default` from `modules/nixos/default.nix` and keep
  the stock `nix.settings`.
- `homeConfigurations."clburlison@srv-devbox".activationPackage` can't be
  evaluated from a Mac without an `x86_64-linux` builder. `agent-skills-nix`
  reads each transformed `SKILL.md` (our `linear-cli` skill) from a
  derivation built for the target system, which is import from derivation.
  `config.home-files` and the rest of the config evaluate fine. On the host
  itself, `task test-home` and `task home` evaluate and build normally.

## 12. CPA Usage Keeper

`cpa-usage-keeper.nix` runs [CPA Usage Keeper](https://github.com/Willxup/cpa-usage-keeper)
as the `cpa-usage-keeper` system service: usage history by model, account,
and client key, cost estimates, latency, and credential quotas for the hub.
It subscribes to the hub's usage queue (`observability.usage` in
`cliproxyapi.nix`; records wait up to an hour) and keeps the history in
SQLite under `/var/lib/cpa-usage-keeper`, with daily backups there.

Keeper needs CLIProxyAPI 8.0.12 or later, so `packages/cliproxyapi.nix`
pins a newer release than nixpkgs-unstable. Newer releases need a newer Go
than unstable has.

The dashboard listens on port 8080 on all interfaces:

- LAN: `http://192.xxx.xxx.xxx:8080`
- Tailnet: `http://srv-devbox.mermaid-agama.ts.net:8080`

It reads the hub with the management key. The login password is in
`cpa-usage-keeper.yaml` (sops, encrypted to this host):

```sh
sudo cat /run/secrets/cpa-usage-keeper-login-password
journalctl -fu cpa-usage-keeper
```

To rotate the password, rewrite the file:

```sh
printf 'login-password: %s\n' "$(nix run nixpkgs#openssl -- rand -hex 16)" \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/cpa-usage-keeper.yaml \
    --input-type yaml --output-type yaml /dev/stdin \
  > cpa-usage-keeper.yaml.tmp \
  && mv cpa-usage-keeper.yaml.tmp hosts/srv-devbox/cpa-usage-keeper.yaml
```

## 13. MCP hub

`mcp-hub.nix` puts Slack, Zoom and Intercom MCP access behind one endpoint on
port 8319 (Caddy, plain HTTP, tailnet interface only). It replaces the
claude.ai connectors, which an `ANTHROPIC_BASE_URL` setup can't reach. Each
server is at `http://srv-devbox.mermaid-agama.ts.net:8319/<name>/mcp` and
every request needs `Authorization: Bearer <hub token>`.

| Server | Upstream | Auth on the hub |
| --- | --- | --- |
| `slack` | `https://mcp.slack.com/mcp` | OAuth, your Slack app |
| `zoom` | `https://mcp.zoom.us/mcp/zoom/streamable` | OAuth, your Zoom app |
| `intercom` | `https://mcp.intercom.com/mcp` | access token as a bearer token |

Slack and Zoom don't support dynamic client registration, so each needs an
OAuth app you register. The hub does the OAuth once and refreshes the tokens
(`mcp-remote`, bridged to HTTP by `mcp-proxy`); clients only ever hold the hub
token. Intercom with a bearer token has no Fin Operator tools (OAuth only).

Secrets are in 1Password. sops holds one thing: the hub's service account
token. Each service resolves its `{{ op://... }}` references with
`op inject` at start, into `/run/mcp-hub` (tmpfs, root only). The OAuth
tokens themselves are in `/var/lib/mcp-hub/<name>/mcp-auth`.

### OAuth apps

Register this redirect URL on each app (the login callback, see below):

- Slack: `http://localhost:3118/oauth/callback`
- Zoom: `http://localhost:3119/oauth/callback`

Slack: a confidential app, internal or Marketplace (unlisted apps can't use
MCP), approved by a workspace admin. Add the user token scopes listed in
`mcp-hub.nix` to the app; they are read-only. For writes add the write scopes
to both the app and `scope` there. Zoom: a General app with user-level
OAuth; the scopes are the ones set on the app, from the Zoom MCP server docs.
If a provider rejects an `http://localhost` redirect, the login in the next
section can't complete; that is untested.

### 1Password setup

| Vault | Item | Fields |
| --- | --- | --- |
| `MCP` | `slack` | `client-id`, `client-secret` |
| `MCP` | `zoom` | `client-id`, `client-secret` |
| `MCP` | `intercom` | `token` |
| `Agents` | `mcp-hub` | `credential`: the hub token, e.g. `openssl rand -hex 32` |

Create a service account `mcp-hub` with **read** on `MCP` and `Agents` (grant
access when creating it). Clients read `Agents/mcp-hub` with the existing
`agents` service account from agent-git, so a compromised client can't read
the upstream credentials in `MCP`. Write the token into `mcp-hub.yaml` (only
the host can decrypt; `read -s` keeps it out of shell history, fish: `read -s token`):

```sh
read -rs token
printf 'op-token: %s\n' "$token" \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/mcp-hub.yaml \
    --input-type yaml --output-type yaml /dev/stdin \
  > mcp-hub.yaml.tmp \
  && mv mcp-hub.yaml.tmp hosts/srv-devbox/mcp-hub.yaml
```

Create this file before the first `task system`: the build fails without it.

### Log in (once per OAuth server)

`mcp-hub-slack` and `mcp-hub-zoom` don't start until they have tokens. On
srv-devbox:

```sh
sudo mcp-hub-login slack
```

It prints the authorization URL and waits for the callback on port 3118
(`3119` for Zoom). From your machine, forward that port first, then open the
URL in your browser:

```sh
ssh -L 3118:localhost:3118 srv-devbox
```

After the redirect the tokens are saved and the service restarts. If a
refresh token is ever revoked, run the login again.

### Clients

A host gets servers by listing them in its override file
(`clb.mcp.servers` in `hosts/<name>/home.nix`); an unlisted host has none.
`modules/common/programs/mcp.nix` adds them through
`programs.claude-code.mcpServers`. The `claude` wrapper reads
`op://Agents/mcp-hub/credential` at each start with the agent-git token
(keychain on Darwin, `/run/secrets/agent-git-token` on Linux) and exports
it as `MCP_HUB_TOKEN`. Without that token Claude Code still starts and the
hub servers show as failed. Check with `/mcp` in Claude Code. The servers
are namespaced under the `claude-code-home-manager` plugin.

### Operations

```sh
systemctl status mcp-hub-gateway mcp-hub-slack mcp-hub-zoom
journalctl -fu mcp-hub-slack
# After changing a secret in 1Password:
sudo systemctl restart 'mcp-hub-*'
```

To add a server, add an entry to `servers` in `mcp-hub.nix`, then list its
name in the hosts that should have it. To update `mcp-remote`, change
`mcpRemote` there (`npm view mcp-remote version`) and `task system`. To
rotate the hub token, change `Agents/mcp-hub`, restart the hub services, and
restart Claude Code on each client.
