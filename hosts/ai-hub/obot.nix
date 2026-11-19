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
#
# The server's secrets are generated here, once, not read from the Agents
# vault: every Mac's service account reads that vault, and none of them
# needs these. Save the encryption key in your own vault (docs).
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
  # The Local auth owner, the only account. Not a mailbox Obot writes to.
  ownerEmail = "git@clburlison.com";

  stateDir = "/var/lib/obot";
  # Obot's /data: embedded Postgres (/data/postgresql), cache, files. 0711:
  # Postgres runs as UID 70 in the container and must traverse it.
  dataDir = "${stateDir}/data";
  # Generated secrets (root only), and the Tailscale auth key you add.
  secretsDir = "${stateDir}/secrets";
  backupDir = "${stateDir}/backups";

  # The image's Postgres listens on all interfaces, and Obot attaches the
  # MCP containers it starts to its own network. Runs once, at initdb (the
  # image's init dir is /var/lib/postgres/initdb, not
  # /docker-entrypoint-initdb.d): loopback only, so those containers can't
  # reach the database. obot-prepare enforces it on existing databases,
  # before Postgres starts.
  initdbListen = pkgs.writeText "10-listen-localhost.sql" ''
    ALTER SYSTEM SET listen_addresses = 'localhost';
  '';

  # Tailscale Serve config; containerboot fills in ${TS_CERT_DOMAIN}.
  serveConfig = pkgs.writeText "obot-tailscale-serve.json" (
    builtins.toJSON {
      TCP."443".HTTPS = true;
      Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://obot:8080";
      AllowFunnel."\${TS_CERT_DOMAIN}:443" = false;
    }
  );

  # Long syntax, so a missing source fails the start instead of Docker
  # creating an empty directory in its place.
  bind = source: target: {
    type = "bind";
    inherit source target;
    read_only = true;
    bind.create_host_path = false;
  };

  composeFile = (pkgs.formats.yaml { }).generate "obot-compose.yml" {
    services = {
      obot = {
        image = "ghcr.io/obot-platform/obot:${version}";
        restart = "unless-stopped";
        ports = [ "127.0.0.1:${toString localPort}:8080" ];
        volumes = [
          {
            type = "bind";
            source = dataDir;
            target = "/data";
            bind.create_host_path = false;
          }
          "/var/run/docker.sock:/var/run/docker.sock"
          (bind "${secretsDir}/encryption.yaml" "/config/encryption.yaml")
          (bind "${initdbListen}" "/var/lib/postgres/initdb/10-listen-localhost.sql")
        ];
        # POSTGRES_PASSWORD (read at initdb and for Obot's DSN) and the
        # owner's one-time setup token.
        env_file = [ "${secretsDir}/obot.env" ];
        environment = {
          OBOT_SERVER_HOSTNAME = url;
          OBOT_SERVER_ENABLE_AUTHENTICATION = "true";
          OBOT_SERVER_LOCAL_AUTH_INITIAL_OWNER_EMAIL = ownerEmail;
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
          (bind "${serveConfig}" "/config/serve.json")
          (bind "${secretsDir}/ts-authkey" "/config/ts-authkey")
        ];
        environment = {
          TS_HOSTNAME = nodeName;
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_SERVE_CONFIG = "/config/serve.json";
          TS_USERSPACE = "true";
          # The key is read from the file, so it isn't in argv; with
          # AUTH_ONCE it is used only while the node has no state.
          TS_AUTHKEY = "file:/config/ts-authkey";
          TS_AUTH_ONCE = "true";
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

  # Creates the dirs and, once, the secrets. Never rotates them: the
  # Postgres password is fixed at initdb, and a new encryption key would
  # orphan every stored grant.
  prepare = pkgs.writeShellApplication {
    name = "obot-prepare";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.openssl
    ];
    text = ''
      umask 077
      install -d -m 0700 ${stateDir} ${secretsDir} ${backupDir}
      install -d -m 0711 ${dataDir}
      chmod 0711 ${dataDir}

      # An existing (or restored) database needs its own secrets back: a new
      # password wouldn't match it, a new key can't decrypt it.
      if [ -e ${dataDir}/postgresql/PG_VERSION ]; then
        for f in encryption.yaml obot.env; do
          if [ ! -s "${secretsDir}/$f" ]; then
            echo "${dataDir} holds a database but ${secretsDir}/$f is missing; restore it (docs/ai-hub.md step 15, Backups)." >&2
            exit 1
          fi
        done

        # Loopback only from the first moment Postgres starts, for a database
        # made without the init script (e.g. restored). The same setting
        # ALTER SYSTEM writes; Postgres is stopped here.
        auto=${dataDir}/postgresql/postgresql.auto.conf
        if ! grep -qx "listen_addresses = 'localhost'" "$auto" 2>/dev/null; then
          echo "setting listen_addresses = 'localhost' in $auto" >&2
          { grep -v '^listen_addresses' "$auto" 2>/dev/null || true
            echo "listen_addresses = 'localhost'"
          } > "$auto.tmp"
          chown --reference=${dataDir}/postgresql/PG_VERSION "$auto.tmp"
          chmod 0600 "$auto.tmp"
          mv "$auto.tmp" "$auto"
        fi
      fi

      if [ ! -s ${secretsDir}/encryption.yaml ]; then
        key="$(openssl rand -base64 32)"
        cat > ${secretsDir}/encryption.yaml.tmp <<EOF
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
                    secret: "$key"
            - identity: {}
      EOF
        unset key
        mv ${secretsDir}/encryption.yaml.tmp ${secretsDir}/encryption.yaml
      fi

      # Hex keeps the password safe inside Obot's DSN.
      if [ ! -s ${secretsDir}/obot.env ]; then
        printf 'POSTGRES_PASSWORD=%s\nOBOT_SERVER_LOCAL_AUTH_INITIAL_OWNER_SETUP_TOKEN=%s\n' \
          "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" > ${secretsDir}/obot.env.tmp
        mv ${secretsDir}/obot.env.tmp ${secretsDir}/obot.env
      fi

      # You write the key (docs); an empty file is fine once enrolled.
      if [ ! -e ${secretsDir}/ts-authkey ]; then
        install -m 0400 /dev/null ${secretsDir}/ts-authkey
      fi
      chmod 0400 ${secretsDir}/*
    '';
  };

  # Fails the start unless Obot answers, its Postgres listens on loopback
  # only, and Obot answers over HTTPS on the tailnet as `mcp`. The HTTPS
  # probe runs from this host, a tailnet member the policy lets in, and
  # pins the name to the sidecar's address, so it needs no MagicDNS here.
  ready = pkgs.writeShellApplication {
    name = "obot-ready";
    runtimeInputs = [
      compose
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      host=${nodeName}.mermaid-agama.ts.net

      for _ in $(seq 1 60); do
        curl -fsS -o /dev/null http://127.0.0.1:${toString localPort}/api/healthz && break
        sleep 5
      done

      # In the container over TCP (the socket is in /tmp there); the SQL
      # is $1 inside.
      # shellcheck disable=SC2016
      if ! listen="$(obot-compose exec -T obot sh -c \
        'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SHOW listen_addresses"')"; then
        echo "Can't query Obot's Postgres; see 'obot-compose logs obot'." >&2
        exit 1
      fi
      if [ "$listen" != localhost ]; then
        echo "Postgres listens on '$listen', not localhost only; stopping." >&2
        exit 1
      fi

      for _ in $(seq 1 60); do
        if ip="$(obot-compose exec -T tailscale tailscale ip -4 2>/dev/null)" && [ -n "$ip" ] \
          && curl -fsS -o /dev/null --max-time 10 --resolve "$host:443:$ip" "https://$host/api/healthz"; then
          exit 0
        fi
        sleep 5
      done
      echo "https://$host isn't answering; see 'obot-compose logs tailscale'." >&2
      echo "First start: is the auth key in ${secretsDir}/ts-authkey? Are HTTPS certificates on for the tailnet?" >&2
      echo "Renamed (${nodeName}-1)? Delete the old ${nodeName} machine in the admin console." >&2
      exit 1
    '';
  };

  # Stops Obot for a consistent copy of the embedded Postgres, archives
  # the data dir, and starts it again. The encryption key isn't in it.
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
      archive="${backupDir}/obot-data-${version}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
      obot-compose stop obot
      trap 'rm -f "$archive.tmp"; obot-compose start obot' EXIT
      tar -C ${dataDir} -czf "$archive.tmp" .
      mv "$archive.tmp" "$archive"
      find ${backupDir} -name 'obot-data-*.tar.gz' -mtime +14 -delete
      echo "wrote $archive"
    '';
  };
in
{
  virtualisation.docker.enable = true;

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
      ExecStartPre = "${prepare}/bin/obot-prepare";
      # Compose restarts crashed containers (restart: unless-stopped).
      ExecStart = "${compose}/bin/obot-compose up --detach --remove-orphans";
      ExecStartPost = "${ready}/bin/obot-ready";
      # Post, so it also runs after a failed start and leaves nothing up.
      ExecStopPost = "${compose}/bin/obot-compose down";
      # The first start pulls the images.
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
