# Host override file for devbox (system): Proxmox LXC workstation, x86_64.
{
  config,
  modulesPath,
  pkgs,
  ...
}:

{
  _class = "nixos";

  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  environment.systemPackages = [ pkgs.git ];

  virtualisation.docker.enable = true;

  # Requires /dev/net/tun passed into the LXC on Proxmox (e.g. `pct set <vmid> --dev0 /dev/net/tun`).
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [ "--operator=${config.clb.host.user}" ];
  };

  # Direct access to t3-serve (home.nix) from the LAN and the tailnet.
  networking.firewall.allowedTCPPorts = [ 3773 ];

  users.users.${config.clb.host.user} = {
    extraGroups = [ "docker" ];
    linger = true;
  };

  # The host's one secret, the op-agents service account token
  # (docs/op-agents.md), encrypted to this container's SSH host key.
  sops.defaultSopsFile = ./secrets.yaml;

  clb.opAgents.secrets = {
    claude-mem-api-key = {
      reference = "op://Agents/claude-mem-rw/credential";
      owner = config.clb.host.user;
    };
    cliproxyapi-api-key = {
      reference = "op://Agents/CLIProxyAPI/cliproxyapi-api-key";
      owner = config.clb.host.user;
    };
  };

  system.stateVersion = "26.05";
}
