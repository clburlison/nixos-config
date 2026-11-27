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
  # host key (docs/op-agents.md): remove `enable = false;` and set
  # `sops.defaultSopsFile = ./secrets.yaml;`.
  clb.opAgents = {
    enable = false;
    secrets = {
      claude-mem-api-key = {
        reference = "op://Agents/claude-mem-rw/credential";
        owner = config.clb.host.user;
      };
      cliproxyapi-api-key = {
        reference = "op://Agents/CLIProxyAPI/cliproxyapi-api-key";
        owner = config.clb.host.user;
      };
    };
  };

  system.stateVersion = "26.05";
}
