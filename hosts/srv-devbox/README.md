# srv-devbox

Headless NixOS dev box: a Proxmox VM, x86_64, reached over SSH. Defined by
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

## 3. Generate and commit the hardware file

`hardware-configuration.nix` in this directory is a placeholder. Replace it
with the generated file:

```sh
nix-shell -p git
git clone https://github.com/clburlison/nixos-config /tmp/nixos-config
cd /tmp/nixos-config
nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/srv-devbox/hardware-configuration.nix
git add hosts/srv-devbox/hardware-configuration.nix
```

Commit and push it (from here or by copying the file to a Mac) so the repo
matches the installed machine.

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
