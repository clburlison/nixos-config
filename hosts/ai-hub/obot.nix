# Obot MCP gateway on ai-hub: each provider's OAuth (Gmail, Outlook,
# Slack, ...) is done once here, Obot keeps and refreshes the tokens, and
# every Mac reaches the tools through vMCPs with its own API key
# (modules/common/programs/obot.nix). Obot's LLM gateway is unused;
# CLIProxyAPI stays the model router. See docs/ai-hub.md step 15.
#
# A Docker Compose stack, with every image pinned: upgrade on purpose by
# bumping `version` (docs/ai-hub.md, "Upgrade").
#   obot       the server, with its embedded Postgres in the data dir. It
#              mounts the Docker socket to start local MCP servers as
#              sibling containers on this stack's network, so it is
#              root-equivalent on this host.
#   tailscale  a sidecar that joins the tailnet as its own node `mcp`
#              (tag:mcp-gateway) and serves HTTPS with the ts.net cert.
#              The host's own Tailscale Serve :443 belongs to t3-serve.
# Nothing is published beyond 127.0.0.1 on the host.
{
  config,
  pkgs,
  ...
}:

let
  version = "v0.28.0";
  # Not the host's tailscale version: tailscale publishes images for some
  # patch releases only.
  tailscaleImage = "ghcr.io/tailscale/tailscale:v1.104.4";

  # The sidecar's node name; with the tailnet name it makes the URL.
  nodeName = "mcp";
  url = "https://${nodeName}.mermaid-agama.ts.net";
  # Local access on the host only (e.g. `curl` over SSH). 8080 is taken
  # by CPA Usage Keeper.
  localPort = 8090;

  stateDir = "/var/lib/obot";
  # Obot's /data: embedded Postgres (/data/postgresql), cache, files.
  dataDir = "${stateDir}/data";
  backupDir = "${stateDir}/backups";

  secret = config.clb.opAgents.secrets;

  # Tailscale Serve config; containerboot fills in ${TS_CERT_DOMAIN}.
  serveConfig = pkgs.writeText "obot-tailscale-serve.json" (
    builtins.toJSON {
      TCP."443".HTTPS = true;
      Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://obot:8080";
      AllowFunnel."\${TS_CERT_DOMAIN}:443" = false;
    }
  );

  composeFile = (pkgs.formats.yaml { }).generate "obot-compose.yml" {
    services = {
      obot = {
        image = "ghcr.io/obot-platform/obot:${version}";
        restart = "unless-stopped";
        ports = [ "127.0.0.1:${toString localPort}:8080" ];
        volumes = [
          "${dataDir}:/data"
          "/var/run/docker.sock:/var/run/docker.sock"
          "${secret.obot-encryption.path}:/config/encryption.yaml:ro"
        ];
        env_file = [ secret.obot-env.path ];
        environment = {
          OBOT_SERVER_HOSTNAME = url;
          OBOT_SERVER_ENABLE_AUTHENTICATION = "true";
          OBOT_SERVER_ENCRYPTION_PROVIDER = "custom";
          OBOT_SERVER_ENCRYPTION_CONFIG_FILE = "/config/encryption.yaml";
          OBOT_SERVER_DISABLE_UPDATE_CHECK = "true";
          OBOT_SERVER_PRODUCT_ANALYTICS_MODE = "off";
          OBOT_SERVER_LLM_GATEWAY_MODEL_DATA_URL = "off";
        };
      };
      tailscale = {
        image = tailscaleImage;
        restart = "unless-stopped";
        hostname = nodeName;
        volumes = [
          "tailscale-state:/var/lib/tailscale"
          "${serveConfig}:/config/serve.json:ro"
        ];
        env_file = [ secret.obot-tailscale-env.path ];
        environment = {
          TS_HOSTNAME = nodeName;
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_SERVE_CONFIG = "/config/serve.json";
          TS_USERSPACE = "true";
          TS_EXTRA_ARGS = "--advertise-tags=tag:mcp-gateway";
        };
        depends_on = [ "obot" ];
      };
    };
    volumes.tailscale-state = { };
  };

  # A fixed project name keeps the network (obot_default, which Obot
  # attaches its MCP containers to) and volumes stable across upgrades.
  compose = pkgs.writeShellScriptBin "obot-compose" ''
    exec ${config.virtualisation.docker.package}/bin/docker compose \
      --project-name obot \
      --file ${composeFile} \
      "$@"
  '';

  # Stops Obot for a consistent copy of the embedded Postgres, archives
  # the data dir, and starts it again. The encryption key lives in
  # 1Password (Agents/obot), not in the archive.
  backup = pkgs.writeShellApplication {
    name = "obot-backup";
    runtimeInputs = [
      compose
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.gzip
    ];
    text = ''
      umask 077
      install -d -m 0700 ${backupDir}
      archive="${backupDir}/obot-data-${version}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
      obot-compose stop obot
      trap 'obot-compose start obot' EXIT
      tar -C ${dataDir} -czf "$archive.tmp" .
      mv "$archive.tmp" "$archive"
      find ${backupDir} -name 'obot-data-*.tar.gz' -mtime +14 -delete
      echo "wrote $archive"
    '';
  };
in
{
  virtualisation.docker.enable = true;

  clb.opAgents.secrets = {
    # Credential encryption (AES-GCM) for OAuth tokens, credentials and
    # identities. Losing the key loses every stored grant.
    obot-encryption.services = [ "obot" ];
    obot-encryption.template = ''
      apiVersion: apiserver.config.k8s.io/v1
      kind: EncryptionConfiguration
      resources:
        - resources:
            - credentials.obot.obot.ai
            - users.obot.obot.ai
            - identities.obot.obot.ai
            - mcpoauthtokens.obot.obot.ai
            - mcpoauthpendingstates.obot.obot.ai
            - mcpauditlogs.obot.obot.ai
            - llmauditlogs.obot.obot.ai
            - policyviolations.obot.obot.ai
            - properties.obot.obot.ai
          providers:
            - aesgcm:
                keys:
                  - name: key0
                    secret: "{{ op://Agents/obot/encryption-key }}"
            - identity: {}
    '';
    # The built-in Local auth provider with one preconfigured owner: the
    # only account. Obot revokes the setup token once the password is set.
    obot-env.services = [ "obot" ];
    obot-env.template = ''
      OBOT_SERVER_LOCAL_AUTH_INITIAL_OWNER_EMAIL={{ op://Agents/obot/owner-email }}
      OBOT_SERVER_LOCAL_AUTH_INITIAL_OWNER_SETUP_TOKEN={{ op://Agents/obot/owner-setup-token }}
    '';
    # Used once, to register the sidecar node; its state volume keeps it.
    obot-tailscale-env.services = [ "obot" ];
    obot-tailscale-env.template = ''
      TS_AUTHKEY={{ op://Agents/obot/tailscale-authkey }}
    '';
  };

  # Wraps compose with this stack's file for operations as root:
  # `sudo obot-compose ps`, `logs -f obot`.
  environment.systemPackages = [
    compose
    backup
  ];

  systemd.services.obot = {
    description = "Obot MCP gateway (Docker Compose)";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = [
        "obot"
        "obot/data"
        "obot/backups"
      ];
      StateDirectoryMode = "0700";
      # Compose restarts crashed containers (restart: unless-stopped).
      ExecStart = "${compose}/bin/obot-compose up --detach --remove-orphans";
      ExecStop = "${compose}/bin/obot-compose down";
      TimeoutStartSec = "30min";
    };
  };

  systemd.services.obot-backup = {
    description = "Back up the Obot data dir";
    after = [ "obot.service" ];
    requisite = [ "obot.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backup}/bin/obot-backup";
    };
  };
  systemd.timers.obot-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:15:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
