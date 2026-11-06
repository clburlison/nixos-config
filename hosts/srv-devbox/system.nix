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
