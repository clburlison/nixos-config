# Local failover proxy to ai-hub's services. clb-work leaves the home
# LAN and may run another VPN or tailnet, so it keeps the CLIProxyAPI hub
# and the claude-mem server whichever network reaches ai-hub. Clients
# use 127.0.0.1 (home.nix); Caddy sends each request to the LAN name when it answers, else the
# tailnet name, and switches mid-session when either drops.
#
# A system daemon, not a Home Manager agent: macOS local network privacy
# blocks LAN connections from user processes whose app lacks the grant
# (e.g. agents under T3 Code), and launchd daemons are exempt (Apple
# TN3179).
{ pkgs, ... }:

let
  lanHost = "ai-hub.home.clb.ai";
  tailnetHost = "ai-hub.mermaid-agama.ts.net";

  # Local port = ai-hub port.
  ports = {
    cliproxyapi = 8317;
    claude-mem = 37877;
  };

  site = port: ''
    :${toString port} {
      bind 127.0.0.1
      reverse_proxy ${lanHost}:${toString port} ${tailnetHost}:${toString port} {
        # LAN first: direct and faster than a tailnet DERP relay.
        lb_policy first
        lb_try_duration 5s
        lb_try_interval 250ms
        fail_duration 30s
        health_uri /
        health_interval 10s
        health_timeout 2s
        # Stream SSE responses as they arrive.
        flush_interval -1
        transport http {
          dial_timeout 1s
        }
      }
    }
  '';

  caddyfile = pkgs.writeText "hub-proxy.Caddyfile" ''
    {
      admin off
      persist_config off
      auto_https off
    }

    ${site ports.cliproxyapi}
    ${site ports.claude-mem}
  '';
in
{
  _class = "darwin";

  launchd.daemons.hub-proxy.serviceConfig = {
    ProgramArguments = [
      "${pkgs.caddy}/bin/caddy"
      "run"
      "--adapter"
      "caddyfile"
      "--config"
      "${caddyfile}"
    ];
    UserName = "nobody";
    GroupName = "nobody";
    EnvironmentVariables = {
      HOME = "/var/empty";
      XDG_CONFIG_HOME = "/var/empty";
      XDG_DATA_HOME = "/var/empty";
    };
    RunAtLoad = true;
    KeepAlive = true;
    StandardErrorPath = "/var/log/hub-proxy.log";
  };

  # Writable by the daemon's user.
  system.activationScripts.postActivation.text = ''
    touch /var/log/hub-proxy.log
    chown nobody:nobody /var/log/hub-proxy.log
  '';
}
