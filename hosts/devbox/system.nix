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

  users.users.${config.clb.host.user} = {
    extraGroups = [ "docker" ];
    linger = true;
  };

  # Enable once hosts/devbox/secrets.yaml is encrypted to this container's SSH
  # host key (docs/op-agents.md), and set `sops.defaultSopsFile = ./secrets.yaml;`.
  clb.opAgents.enable = false;

  system.stateVersion = "26.05";
}
