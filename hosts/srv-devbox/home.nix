# Host override file for srv-devbox (Home Manager).
{
  config,
  pkgs,
  ...
}:

{
  _class = "homeManager";

  # The claude-mem hosted server runs here (system.nix), so skip the
  # tailnet round trip.
  home.sessionVariables.CLAUDE_MEM_SERVER_URL = "http://127.0.0.1:37877";

  # The CLIProxyAPI hub runs here too (cliproxyapi.nix); its op-agents
  # secret is owned by the host user.
  clb.cliproxyapi = {
    url = "http://127.0.0.1:8317";
    apiKeyFile = "/run/op-agents/cliproxyapi-api-key";
  };

  # T3 Code server, reachable directly on port 3773 (LAN or tailnet IP, plain
  # HTTP) and over HTTPS on the tailnet through Tailscale Serve. Lingering
  # (system.nix) starts it at boot; the host user is a Tailscale operator so
  # it can configure Serve. system.nix opens the port. See
  # docs/srv-devbox.md step 9.
  systemd.user.services.t3-serve = {
    Unit.Description = "T3 Code server on the tailnet";
    Service = {
      ExecStart = "${pkgs.t3}/bin/t3 serve --host 0.0.0.0 --port 3773 --tailscale-serve --no-browser %h/dev";
      # User services get a bare PATH; agents need git, claude, codex and
      # the rest of the user's tools. Also pass the claude-mem hosted server
      # settings (modules/common/programs/claude-mem.nix), since user
      # services don't get home.sessionVariables.
      Environment = [
        "PATH=%h/.local/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ]
      ++ map (name: "${name}=${config.home.sessionVariables.${name}}") [
        "CLAUDE_MEM_RUNTIME"
        "CLAUDE_MEM_SERVER_URL"
        "CLAUDE_MEM_SERVER_PROJECT_ID"
      ];
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
