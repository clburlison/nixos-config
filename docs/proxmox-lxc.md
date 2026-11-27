# Proxmox LXC servers

NixOS server hosts (`profile = "server"` in `flake.nix`) default to Proxmox
LXC containers via `modules/nixos/server.nix`, which imports nixpkgs'
`proxmox-lxc.nix` module and enables Docker.

The `nixos` entry in the Host table is the bare server config used to build the
Proxmox LXC template tarball. Each new server is cloned from that template and
switched to its own Host table entry.

## 1. Build the template tarball

On an `x86_64-linux` Nix host (such as `ai-hub`):

```sh
nix build .#nixosConfigurations.nixos.config.system.build.tarball
ls -lh result/tarball/
```

Copy the resulting `.tar.xz` to Proxmox's CT template cache on `nas02-proxmox`:

```sh
scp result/tarball/*.tar.xz root@<proxmox-host>:/mnt/pve/nas02-proxmox/template/cache/nixos-lxc.tar.xz
```

## 2. Create the `template-nixos` Proxmox template

On the Proxmox host (adjust VMID, rootfs storage, and bridge as needed):

```sh
pct create 1002 nas02-proxmox:vztmpl/nixos-lxc.tar.xz \
  --hostname template-nixos \
  --arch amd64 \
  --ostype nixos \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --dev0 /dev/net/tun \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --rootfs nvme-raid:20 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --onboot 1

pct template 1002
```

- `nesting=1,keyctl=1` is required for systemd and Docker inside an
  unprivileged LXC.
- `--dev0 /dev/net/tun` exposes the TUN device needed for Tailscale (to add it
  to an existing CT: `pct set <vmid> --dev0 /dev/net/tun` followed by
  `pct stop <vmid> && pct start <vmid>`).
- Convert to a template **before** starting the container so each clone gets
  its own SSH host keys, `/etc/machine-id`, and first-boot
  `register-nix-paths` run.

## 3. Provision a new server (example: `gitea`)

1. Add the host to `flake.nix` with `profile = "server"`:

   ```nix
   gitea = {
     system = "x86_64-linux";
     platform = "nixos";
     user = "clburlison";
     profile = "server";
   };
   ```

   Add per-host overrides in `hosts/gitea/system.nix` and/or
   `hosts/gitea/home.nix` as needed, then commit and push.

2. Clone `template-nixos` in Proxmox and set the CT hostname to the short
   Host table name (`gitea`, with DNS domain `home.clb.ai`). `proxmox-lxc.nix`
   reads `/etc/hostname` and network settings from Proxmox by default
   (`manageHostName = false`, `manageNetwork = false`).

3. Start the container from the Proxmox host (wheel `sudo` is passwordless;
   optionally set a console password with
   `pct exec <vmid> -- /run/wrappers/bin/passwd clburlison`):

   ```sh
   pct start <vmid>
   ```

4. SSH in with your key from `lib/ssh-keys.nix`, clone this repo, and apply
   both system and Home Manager configs (server profile does not reference
   private flake inputs, so plain HTTPS clone works without agent forwarding):

   ```sh
   ssh clburlison@gitea.home.clb.ai
   mkdir -p ~/dev/me
   git clone https://github.com/clburlison/nixos-config ~/dev/me/nixos-config
   cd ~/dev/me/nixos-config

   sudo nixos-rebuild switch --flake .#gitea
   nix run home-manager/release-26.05 -- switch --flake .#clburlison@gitea
   ```

After bootstrap, manage the host with `task system`, `task home`, or
`task switch`.
