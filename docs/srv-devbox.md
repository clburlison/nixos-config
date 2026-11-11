# srv-devbox

Headless NixOS development host: a Proxmox VM, x86_64, reached over SSH. It
is the hub every other host uses: the Claude and Codex logins (CLIProxyAPI)
and the shared memory server (claude-mem). Defined by
the `srv-devbox` entry in the host table (`flake.nix`), the NixOS platform
aggregator (`modules/nixos/`), and the host override files in
`hosts/srv-devbox/`. Files named below without a path are in that
directory.

Do the steps in order; each one assumes the ones before it. Where it fits in
the whole setup: [docs/README.md](README.md).

| Step | Needs |
| --- | --- |
| [1. Create the Proxmox VM](#1-create-the-proxmox-vm) | |
| [2. Partition and mount](#2-partition-and-mount) | |
| [3. Generate and push the hardware file](#3-generate-and-push-the-hardware-file-required) | a machine that can push to GitHub |
| [4. Install](#4-install) | |
| [5. SSH in and clone](#5-ssh-in-and-clone) | an SSH agent holding a GitHub key |
| [6. Bootstrap Home Manager](#6-bootstrap-home-manager) | |
| [7. op-agents token](#7-op-agents-token) | the Agents vault items, a Mac with `op` |
| [8. agent-git](#8-agent-git) | 7 |
| [9. Tailscale](#9-tailscale) | |
| [10. T3 Code server](#10-t3-code-server) | 9 |
| [11. CLIProxyAPI hub](#11-cliproxyapi-hub) | 7 |
| [12. CPA Usage Keeper](#12-cpa-usage-keeper) | 7, 11 |
| [13. claude-mem hosted server](#13-claude-mem-hosted-server) | 7, 9, 11 |

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

The new install has a new SSH host key, so it can't decrypt the committed
op-agents token yet. Until step 7, `op-agents` fails after a 10-minute
retry at boot, and the hub, Keeper, claude-mem server and Caddy don't
start. That is expected.

## 5. SSH in and clone

Password SSH is off; log in with the key from `lib/ssh-keys.nix`.

Step 6 fetches the private `clb-skills` input over SSH, so forward an agent
that holds a GitHub key. Plain `ssh -A` forwards the empty launchd agent
instead. From a Mac with agent-git set up (`docs/agent-git.md`):

```sh
ssh -o ForwardAgent=~/.ssh/agent-git.sock clburlison@srv-devbox
ssh-add -l   # lists the agent-git key
```

On a Mac without agent-git, forward 1Password's agent instead:
`-o "ForwardAgent=~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"`.

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

## 7. op-agents token

The host holds one secret, the op-agents service account token
(`secrets.yaml`, encrypted to this host's SSH host key in `.sops.yaml`).
Every other secret on this host comes from the Agents vault through it
(`docs/op-agents.md`).

1. Check that every Agents item this host reads exists: the srv-devbox rows
   of [Agents vault items](op-agents.md#agents-vault-items). op-agents
   fetches them all in one run and fails if any is missing, and each service
   that reads one requires it, so one missing item stops the hub, Keeper,
   the claude-mem server and Caddy together. On a first setup,
   `claude-mem-viewer` can't exist yet (step 13 creates the key): create it
   with any placeholder `credential` now.
2. Encrypt the token to this host: "NixOS host" in `docs/op-agents.md`,
   steps 1 to 4. It ends with `task system`, `task home` and
   `op-agents-check`.

After a reinstall, the host key changes: redo item 2 before `task system`.

## 8. agent-git

Lets the host sign commits and reach GitHub without a forwarded agent. It
reads `op://Agents/git-agent` with the token from step 7
(`docs/agent-git.md`, "NixOS hosts").

```sh
agent-git-check
```

Once it passes, switch the clone from step 5 to SSH so pushes use the
agent-git key:

```sh
git remote set-url origin git@github.com:clburlison/nixos-config.git
```

## 9. Tailscale

`tailscaled` starts at boot (`services.tailscale` in `system.nix`). Log in
once; the node key in `/var/lib/tailscale` reconnects it on every boot
after that:

```sh
sudo tailscale up
tailscale status
```

In the Tailscale admin console, open the machine and choose **Disable key
expiry**, or it drops off the tailnet when the key expires (180 days by
default).

The tailnet address is pinned as `tailnetIp` in `claude-mem-server.nix`
(Postgres and the viewer bind it). It is stable per node; after
re-registering the node, check `tailscale ip -4` and update it.

## 10. T3 Code server

The `t3-serve` user service (`home.nix`) runs `t3 serve` on port 3773 on
all interfaces and also publishes it over HTTPS on the tailnet with
Tailscale Serve. Lingering starts it at boot. Serve needs step 9 done and
HTTPS certificates enabled for the tailnet (admin console > DNS > HTTPS
Certificates).

- Direct: `http://srv-devbox:3773` from the LAN or the tailnet (plain HTTP).
- Tailnet HTTPS: the `https://srv-devbox.mermaid-agama.ts.net` URL.

```sh
systemctl --user status t3-serve
journalctl --user -u t3-serve
t3 pair --tailscale   # pairing link through the tailnet HTTPS URL
t3 pair               # direct; swap the printed host for srv-devbox:3773
```

## 11. CLIProxyAPI hub

`cliproxyapi.nix` runs [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
as the `cliproxyapi` system service, following
<https://gist.github.com/t3dotgg/59a521d2ee8d70aaf90e280c175072af>. Claude
and Codex accounts sign in here once; every other machine uses this host as
its API endpoint. It listens on port 8317 on all interfaces (plain HTTP):

- LAN: `http://192.xxx.xxx.xxx:8317` (srv-devbox's LAN IP)
- Tailnet: `http://srv-devbox.mermaid-agama.ts.net:8317`

The module comes from nixpkgs-unstable; `packages/cliproxyapi.nix` pins a
newer release. Its Claude cloaking reports a fixed Claude Code version
upstream, and models that need a newer client are refused ("Claude Code
2.1.x does not support this model") until the pin moves to a release that
reports a newer one. Nix writes `/var/lib/cliproxyapi/config.yaml` at every
start, so change settings in `cliproxyapi.nix`, not the management panel.
Account logins live in `/var/lib/cliproxyapi` and are kept.

### Keys

The client access key and management key are the `cliproxyapi-api-key` and
`password` fields of `CLIProxyAPI` in the Agents vault. op-agents
writes them to `/run/op-agents` (the access key is owned by the host user,
for its own Claude Code and Codex):

```sh
cat /run/op-agents/cliproxyapi-api-key
sudo cat /run/op-agents/cliproxyapi-management-key
```

To rotate, set new values in 1Password (e.g. `sk-` plus
`openssl rand -hex 32` for the access key, `openssl rand -hex 32` for the
management key), then `sudo systemctl start op-agents-refresh`, which
restarts the hub. Macs pick the new access key up within the hour.

OpenRouter is also an upstream (`api-keys.openai-compatibility` in
`cliproxyapi.nix`): clients call the listed aliases (`glm-5.3`,
`gemma-4-31b-free`, ...) with the hub's access key, and the hub sends the
OpenRouter key. Only listed models are exposed; add more from
<https://openrouter.ai/models>. The key is the `credential` of `OpenRouter`
in the Agents vault; create one at <https://openrouter.ai/keys>.

### Account logins

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

### Clients

Claude Code and Codex route through the hub on every host
(`modules/common/programs/cliproxyapi.nix`), in their usual `~/.claude` and
`~/.codex`. Their wrappers read the key at each run and set
`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and
`CLAUDE_CODE_PROMPT_CACHE_TTL=1h` for Claude (through a custom base URL it
otherwise caches for 5 minutes, not the subscription's 1 hour), and a
`cliproxyapi` model provider for Codex. `settings.json` and `config.toml`
stay untouched. T3 Code runs the same `claude` and `codex`, so it follows
too; for Codex, pick **Use existing CLI**.

srv-devbox uses `http://127.0.0.1:8317` and reads the op-agents file
directly (`hosts/srv-devbox/home.nix`). Macs use the tailnet URL and read
op-agents' keychain cache of `op://Agents/CLIProxyAPI/cliproxyapi-api-key`
(`docs/op-agents.md`), which works while 1Password is locked. No per-Mac
step beyond the op-agents token.

Check that cache writes use the 1-hour TTL: run
`claude -p hello --output-format json` and look for
`ephemeral_1h_input_tokens` in `usage.cache_creation`. The 1-hour request
travels partly in the `anthropic-beta` header, so the hub must forward it.

`CLAUDE_NO_PROXY=1 claude` skips the hub for one run, e.g. for claude.ai
connectors, which only load with the claude.ai login. Without the key, a
host keeps its own Claude and Codex logins. To sign in directly on a Mac
(e.g. clb-work), set `clb.cliproxyapi.enable = false;` in its host override
file, then drop the cache:
`security delete-generic-password -s op-agents:cliproxyapi-api-key`.

## 12. CPA Usage Keeper

`cpa-usage-keeper.nix` runs [CPA Usage Keeper](https://github.com/Willxup/cpa-usage-keeper)
as the `cpa-usage-keeper` system service: usage history by model, account,
and client key, cost estimates, latency, and credential quotas for the hub.
It subscribes to the hub's usage queue (`observability.usage` in
`cliproxyapi.nix`; records wait up to an hour) and keeps the history in
SQLite under `/var/lib/cpa-usage-keeper`, with daily backups there.

Keeper needs CLIProxyAPI 8.0.12 or later, which `packages/cliproxyapi.nix`
covers.

The dashboard listens on port 8080 on all interfaces:

- LAN: `http://192.xxx.xxx.xxx:8080`
- Tailnet: `http://srv-devbox.mermaid-agama.ts.net:8080`

It reads the hub with the management key. The login password is the
`password` of `cpa-usage-keeper` in the Agents vault:

```sh
sudo cat /run/op-agents/cpa-usage-keeper-env
journalctl -fu cpa-usage-keeper
```

To rotate the password, change it in 1Password (e.g. `openssl rand -hex 16`),
then `sudo systemctl start op-agents-refresh`. Keeper restarts and accepts
only the new password, but browsers already logged in keep their session
(7 days); revoke them on Keeper's sessions page.

## 13. claude-mem hosted server

`claude-mem-server.nix` runs upstream's Docker Compose stack
(<https://docs.claude-mem.ai/hosted-server>) as the `claude-mem-server`
system service, pinned to a release tag. Compose builds the images locally,
so the first `task system` start takes several minutes. The server listens
on port 37877 on all interfaces. Each host's hooks and MCP server connect to
it (`docs/claude-mem.md`, "Hosted server").

Postgres credentials are generated once into
`/var/lib/claude-mem-server/postgres.env`. Postgres only reads them when it
creates its volume, so keep that file as long as the volume exists.

`sudo claude-mem-server-compose` is `docker compose` with this stack's files:

```sh
systemctl status claude-mem-server
sudo claude-mem-server-compose ps
sudo claude-mem-server-compose logs -f claude-mem-worker
# Keys and projects (no secrets):
sudo claude-mem-server-compose exec claude-mem-server \
  bun /opt/claude-mem/scripts/server-service.cjs server keys
```

### Generation

The worker generates observations through the CLIProxyAPI hub (step 11),
with the OpenAI subscription logins there. `claude-mem-server.nix` sets the
provider (`openrouter`, which takes any OpenAI-compatible base URL), the
base URL (`http://host.docker.internal:8317/v1`, the Docker host gateway,
since 127.0.0.1 in the container is the container) and the model
(`gpt-6-luna`; list the hub's models with `GET /v1/models`). The key is the
hub's client access key, filled in from `op://Agents/CLIProxyAPI` by
op-agents.

The Secure Note `claude-mem-server-env` in the Agents vault holds any other
worker env as a dotenv, e.g.
`OPENROUTER_API_KEY=<openrouter.ai key, unused while the hub is set>`. Edit
the note to change it. op-agents picks up a changed note within the hour and
restarts the service; `sudo systemctl start op-agents-refresh` does it now.

To go back to openrouter.ai, drop `CLAUDE_MEM_OPENROUTER_BASE_URL` and the
rendered key env file, and set the model to an OpenRouter one (for example
`~anthropic/claude-haiku-latest`).

### API keys

Keys are shown once, at creation. Save each one in the Agents vault right
away (`docs/op-agents.md`). Pass `--team` and `--project` so the key lands
on the existing project (`local-hook-project`,
`CLAUDE_MEM_SERVER_PROJECT_ID` in `modules/common/programs/claude-mem.nix`);
without them the CLI bootstraps its own.

Keep the team named `local-hook-team`. Upstream finds it by that name in
`server keys rotate`, the installer's server bootstrap and `api-key create`
without `--team`; after a rename each of those creates a new, empty team
and project.

```sh
sudo claude-mem-server-compose exec -T claude-mem-server \
  bun /opt/claude-mem/scripts/server-service.cjs server api-key create \
  --name <name> --scope <scopes> \
  --team b5819eed-7f22-4054-b5da-9e31515d1a00 \
  --project 3bee384a-652b-4947-bd36-027c429b4589
```

| 1Password item (Agents) | Scopes | Used by |
| --- | --- | --- |
| `claude-mem-rw` | `memories:read,memories:write` | hooks and the MCP server on every host (`docs/claude-mem.md`, "Hosted server") |
| `claude-mem-viewer` | `memories:read` | the viewer proxy below, through op-agents |

Revoke a key with `server api-key revoke <id>`. To rotate a host key,
create a new one, save it in 1Password, update every host, then revoke the
old one. Don't use `server keys rotate`: it mints a key for the bootstrap
project and writes it into the local `settings.json` only.

On a first setup, create `claude-mem-rw` and `claude-mem-viewer` here, and
replace the placeholder `claude-mem-viewer` from step 7.

### Viewer

The server serves the memory viewer at `/`, but the viewer's browser code
sends no API key, so opened directly on 37877 every data call gets 401 and
the page stays empty. Caddy fronts it on the tailnet:
<http://srv-devbox.mermaid-agama.ts.net:37878>. It adds the `claude-mem-viewer`
read key to every request.

Anyone who reaches that port reads as the key's team, so it is
tailnet-only: Caddy binds the tailnet address, the firewall opens 37878
only on `tailscale0`, and requests from outside `100.64.0.0/10` and
`fd7a:115c:a1e0::/48` get 403.

The viewer is read-only (the key has no write scope). New rows show on
reload; the server sends no live updates. My Work is not on the server
runtime; it runs in each host's local worker.

To rotate the key, create a new `memories:read` key, replace the
`credential` in `claude-mem-viewer`, then revoke the old one. op-agents
restarts Caddy within the hour, or now with
`sudo systemctl start op-agents-refresh`.

### Postgres

Postgres is published on the tailnet address only (`tailnetIp` in
`claude-mem-server.nix`), for database clients. The password is in
`/var/lib/claude-mem-server/postgres.env`:

```sh
psql postgres://claude_mem:<password>@100.75.137.72:5432/claude_mem
```

### Upgrading

Change `version` and `hash` in `claude-mem-server.nix`. Back up first and
follow upstream's "Upgrading the Postgres image" when the Postgres image
changes:

```sh
sudo claude-mem-server-compose exec postgres \
  sh -c 'pg_dumpall -U "$POSTGRES_USER"' > claude-mem-backup.sql
```

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
