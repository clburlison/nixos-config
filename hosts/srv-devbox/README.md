# srv-devbox

Headless NixOS development host: a Proxmox VM, x86_64, reached over SSH. Defined by
the `srv-devbox` entry in the host table (`flake.nix`), the NixOS platform
aggregator (`modules/nixos/`), and the host override files in this
directory.

## 1. Create the Proxmox VM

| Setting | Value |
| --- | --- |
| Machine | `q35` |
| BIOS | OVMF (UEFI), with an EFI disk |
| CPU type | `host` |
| SCSI controller | VirtIO SCSI (`virtio-scsi-pci` or `virtio-scsi-single`) |
| Disk | On the VirtIO SCSI controller |
| Network | VirtIO (paravirtualized) NIC |
| QEMU guest agent | Enabled (Options > QEMU Guest Agent) |

Attach the Determinate NixOS installer ISO (from
<https://docs.determinate.systems>) and boot it.

## 2. Partition and mount

From the installer console, as root. Replace `/dev/sda` with the VM disk.

```sh
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 1GiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart root ext4 1GiB 100%

mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

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

Password SSH is off; log in with the key from `lib/ssh-keys.nix`:

```sh
ssh clburlison@srv-devbox
mkdir -p ~/dev/me
git clone https://github.com/clburlison/nixos-config ~/dev/me/nixos-config
cd ~/dev/me/nixos-config
```

Check that the clone has the generated hardware file, not the placeholder:

```sh
! grep -q 'TEMPORARY PLACEHOLDER' hosts/srv-devbox/hardware-configuration.nix \
  || echo 'Push the generated hardware file first (step 3)'
```

## 6. Bootstrap Home Manager

The first run installs `home-manager` into `~/.nix-profile`:

```sh
nix run home-manager/release-26.05 -- switch --flake .#clburlison@srv-devbox
```

After that, use `task home` (no sudo), `task system` (sudo), or `task switch`.

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
