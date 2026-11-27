# Host override file for devbox (Home Manager).
{
  config,
  pkgs,
  ...
}:

{
  _class = "homeManager";

  # Secrets written to /run/op-agents by the system's op-agents service.
  clb.claudeMem.apiKeyFile = "/run/op-agents/claude-mem-api-key";
  clb.cliproxyapi.apiKeyFile = "/run/op-agents/cliproxyapi-api-key";

  # T3 Code server, reachable directly on port 3773 (LAN or tailnet IP, plain
  # HTTP) and over HTTPS on the tailnet through Tailscale Serve. Lingering
  # (system.nix) starts it at boot; the host user is a Tailscale operator so
  # it can configure Serve. system.nix opens the port.
  systemd.user.services.t3-serve = {
    Unit.Description = "T3 Code server on the tailnet";
    Service = {
      ExecStart = "${pkgs.t3}/bin/t3 serve --host 0.0.0.0 --port 3773 --tailscale-serve --no-browser %h/dev";
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
