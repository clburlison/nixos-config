# Host override file for srv-devbox (system): Proxmox VM, x86_64,
# headless, SSH-first.
{
  _class = "nixos";

  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.qemuGuest.enable = true;

  # Set at install time. Read the NixOS release notes before changing.
  system.stateVersion = "26.05";
}
