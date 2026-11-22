# Host override file for clb-mini (nix-darwin).
{ config, ... }:

{
  _class = "darwin";

  # Always-on home lab host: never sleep, and come back on its own.
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
      PermitRootLogin no
    '';
  };
  users.users.${config.clb.host.user}.openssh.authorizedKeys.keys = import ../../lib/ssh-keys.nix;

  # tailscaled as a launchd daemon, up before login. MagicDNS works through
  # /etc/resolver/ts.net, so overrideLocalDns stays off.
  services.tailscale.enable = true;

  # Restart tailscaled if it exits; nix-darwin only sets RunAtLoad.
  launchd.daemons.tailscaled.serviceConfig.KeepAlive = true;
}
