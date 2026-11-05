# Host override file for srv-devbox (Home Manager).
{ pkgs, ... }:

{
  _class = "homeManager";

  # T3 Code server, reachable over HTTPS on the tailnet through Tailscale
  # Serve. Lingering (system.nix) starts it at boot; the host user is a
  # Tailscale operator so it can configure Serve. Pair a client with
  # `t3 pair`. See README step 9.
  systemd.user.services.t3-serve = {
    Unit.Description = "T3 Code server on the tailnet";
    Service = {
      ExecStart = "${pkgs.t3}/bin/t3 serve --host 127.0.0.1 --tailscale-serve --no-browser %h/dev";
      # User services get a bare PATH; agents need git, claude, codex and
      # the rest of the user's tools.
      Environment = [
        "PATH=%h/.local/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
