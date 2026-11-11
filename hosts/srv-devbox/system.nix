# Host override file for srv-devbox (system): Proxmox VM, x86_64,
# headless, SSH-first.
{ config, ... }:

{
  _class = "nixos";

  imports = [
    ./hardware-configuration.nix
    ./claude-mem-server.nix
    ./cliproxyapi.nix
    ./cpa-usage-keeper.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.qemuGuest.enable = true;

  # tailscaled starts at boot and reconnects with the node key in
  # /var/lib/tailscale. Log in once with `sudo tailscale up`
  # (docs/srv-devbox.md step 8).
  # openFirewall allows the UDP port for direct connections instead of DERP
  # relays.
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # Lets the host user run `tailscale serve` without sudo, for t3-serve
    # in home.nix.
    extraSetFlags = [ "--operator=${config.clb.host.user}" ];
  };

  # Direct access to t3-serve (home.nix) from the LAN and the tailnet.
  networking.firewall.allowedTCPPorts = [ 3773 ];

  # The host's one secret, the op-agents service account token
  # (docs/op-agents.md), encrypted to this host's SSH host key (.sops.yaml).
  # Every other secret comes from the Agents vault through it.
  sops.defaultSopsFile = ./secrets.yaml;
  # Stored under its old name; renaming means re-encrypting the file.
  sops.secrets.op-agents-token.key = "agent-git-token";
  # Lingering starts the user's agent-git services at boot, before anyone
  # logs in.
  users.users.${config.clb.host.user}.linger = true;

  # Set at install time. Read the NixOS release notes before changing.
  system.stateVersion = "26.05";
}
