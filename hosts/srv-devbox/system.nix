# Host override file for srv-devbox (system): Proxmox VM, x86_64,
# headless, SSH-first.
{ config, ... }:

{
  _class = "nixos";

  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.qemuGuest.enable = true;

  # agent-git (docs/agent-git.md): the 1Password service account token,
  # encrypted to this host's SSH host key (.sops.yaml). Lingering starts
  # the user's agent-git services at boot, before anyone logs in.
  sops.secrets.agent-git-token = {
    sopsFile = ./secrets.yaml;
    owner = config.clb.host.user;
    mode = "0400";
  };
  users.users.${config.clb.host.user}.linger = true;

  # Set at install time. Read the NixOS release notes before changing.
  system.stateVersion = "26.05";
}
