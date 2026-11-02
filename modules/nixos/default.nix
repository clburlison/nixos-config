# NixOS platform aggregator: everything every NixOS host gets.
{
  config,
  inputs,
  pkgs,
  ...
}:

let
  user = config.clb.host.user;
in
{
  _class = "nixos";

  imports = [ inputs.determinate.nixosModules.default ];

  networking.hostName = config.clb.host.name;

  # Determinate Nix: its module provides nix.package and moves nix.settings
  # into /etc/nix/nix.custom.conf.
  nix.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      user
    ];
  };

  # Wheel sudo asks for the user's password. Set it once during install
  # (see hosts/srv-devbox/README.md); it is not stored in this repo.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = import ../../lib/ssh-keys.nix;
  };
  security.sudo.wheelNeedsPassword = true;

  # Mirrors modules/darwin/shells.nix.
  programs.fish.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH only; services.openssh opens port 22.
  networking.firewall.enable = true;
}
