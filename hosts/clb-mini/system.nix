# Host override file for clb-mini (nix-darwin).
{ config, ... }:

{
  _class = "darwin";

  # Always-on home lab machine: never sleep, and come back on its own.
  power = {
    sleep.computer = "never";
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };

  # Remote Login, keys only.
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };
  users.users.${config.clb.host.user}.openssh.authorizedKeys.keys = import ../../lib/ssh-keys.nix;

  # tailscaled as a launchd daemon, up before login. Authenticate once by
  # hand: `sudo tailscale up --ssh`.
  services.tailscale = {
    enable = true;
    overrideLocalDns = true;
  };
}
