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

  imports = [
    inputs.determinate.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    ./op-agents.nix
  ];

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

  # Weekly `task clean`. Persistent: a missed run happens on next boot.
  systemd.services.nix-clean = {
    description = "Prune Nix profiles, collect garbage, optimise store";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.runtimeShell} ${../../lib/nix-clean.sh}";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.nix-clean = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:00:00";
      Persistent = true;
    };
  };

  # Wheel sudo asks for the user's password. It is not stored in this repo;
  # set it once with `passwd` when installing a host.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = import ../../lib/ssh-keys.nix;
  };
  security.sudo.wheelNeedsPassword = true;

  # Mirrors modules/darwin/shells.nix.
  programs.fish.enable = true;

  # Runs prebuilt generic-Linux binaries that expect the FHS loader, such as
  # uv-managed Python (modules/common/programs/uv.nix) and t3.
  programs.nix-ld.enable = true;

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
