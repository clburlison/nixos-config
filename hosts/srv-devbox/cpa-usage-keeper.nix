# CPA Usage Keeper on srv-devbox: usage history, cost estimates, and quota
# tracking for the CLIProxyAPI hub (cliproxyapi.nix). It reads the hub's
# usage queue and management API and keeps the history in SQLite. See
# docs/srv-devbox.md step 12.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 8080;
  stateDir = "/var/lib/cpa-usage-keeper";
in
{
  # Dashboard login password.
  sops.secrets.cpa-usage-keeper-login-password = {
    sopsFile = ./cpa-usage-keeper.yaml;
    key = "login-password";
  };

  sops.templates.cpa-usage-keeper-env.content = ''
    CPA_MANAGEMENT_KEY=${config.sops.placeholder.cliproxyapi-management-key}
    LOGIN_PASSWORD=${config.sops.placeholder.cpa-usage-keeper-login-password}
  '';

  systemd.services.cpa-usage-keeper = {
    description = "CPA Usage Keeper";
    after = [
      "cliproxyapi.service"
      "network-online.target"
    ];
    wants = [
      "cliproxyapi.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.sops.templates.cpa-usage-keeper-env.content ];

    environment = {
      # The hub's HTTP API and its usage queue (RESP on the same port).
      CPA_BASE_URL = "http://127.0.0.1:${toString config.services.cliproxyapi.settings.server.port}";
      # "Back to CPA" link in the dashboard.
      CPA_PUBLIC_URL = "http://srv-devbox.mermaid-agama.ts.net:${toString config.services.cliproxyapi.settings.server.port}";
      APP_PORT = toString port;
      TZ = config.time.timeZone;
      WORK_DIR = stateDir;
      # Logs go to the journal.
      LOG_FILE_ENABLED = "false";
    };

    serviceConfig = {
      ExecStart = lib.getExe pkgs.cpa-usage-keeper;
      EnvironmentFile = config.sops.templates.cpa-usage-keeper-env.path;
      DynamicUser = true;
      StateDirectory = "cpa-usage-keeper";
      WorkingDirectory = stateDir;
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Dashboard from the LAN and the tailnet, like the hub.
  networking.firewall.allowedTCPPorts = [ port ];
}
