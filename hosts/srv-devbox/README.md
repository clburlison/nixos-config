# srv-devbox

Headless NixOS development host: a Proxmox VM, x86_64, reached over SSH. Defined by
the `srv-devbox` entry in the host table (`flake.nix`), the NixOS platform
aggregator (`modules/nixos/`), and the host override files in this
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

`hardware-configuration.nix` in this directory is a placeholder. Generate the
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

The worker generates observations through OpenRouter: prepaid credits, so
access stops instead of billing on when they run out. Create a key at
<https://openrouter.ai/keys>, then encrypt the env file (only the host can
decrypt, so rewrite the whole file to change it):

```sh
printf '%s\n' \
  'CLAUDE_MEM_SERVER_PROVIDER=openrouter' \
  'OPENROUTER_API_KEY=<key>' \
  'CLAUDE_MEM_SERVER_MODEL=~anthropic/claude-haiku-latest' \
  | nix run nixpkgs#sops -- encrypt \
    --filename-override hosts/srv-devbox/claude-mem-server.env.sops \
    --input-type binary --output-type binary /dev/stdin \
  > hosts/srv-devbox/claude-mem-server.env.sops
```

The model tracks the newest Haiku, like the local plugin's default
(upstream recommends Haiku for compression). A Claude subscription
(`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, provider `claude`)
also works.

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
named `CLIProxyAPI` in your Private vault. Then on each Mac, signed in to
`op`, after `task home`:

```sh
op read --account my "op://Private/CLIProxyAPI/credential" | cliproxyapi-set-key
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
