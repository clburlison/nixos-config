# NixOS configuration for server hosts.
# Servers default to Proxmox LXC containers with Docker enabled.
# Override per host in hosts/<name>/system.nix (e.g. `proxmoxLXC.enable = false;`
# for a VM or bare-metal server).
{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  _class = "nixos";

  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  # Keep git available on fresh clones before Home Manager is bootstrapped.
  environment.systemPackages = [ pkgs.git ];

  virtualisation.docker.enable = lib.mkDefault true;

  users.users.${config.clb.host.user}.extraGroups = lib.mkIf config.virtualisation.docker.enable [
    "docker"
  ];

  system.stateVersion = lib.mkDefault "26.05";
}
