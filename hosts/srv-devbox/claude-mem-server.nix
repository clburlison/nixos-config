# claude-mem hosted server (beta) on srv-devbox: upstream's Docker Compose
# stack (Postgres 17 with pgvector and pg_textsearch, Valkey, the HTTP
# server on port 37877, and the generation worker), pinned to a release tag.
# Compose builds the images locally from the pinned source. See
# docs/srv-devbox.md step 10 and https://docs.claude-mem.ai/hosted-server.
{
  config,
  pkgs,
  ...
}:

let
  version = "15.17.0";
  src = pkgs.fetchFromGitHub {
    owner = "thedotmack";
    repo = "claude-mem";
    tag = "v${version}";
    hash = "sha256-8qmM7mthX8TNqSDtp6ktYpLciCK2+L68QX33sPLOOfg=";
  };

  # Tailnet-only viewer proxy (Caddy, below). The viewer's browser code
  # sends no API key, so on 37877 every data call gets 401.
  viewerPort = 37878;

  # The worker generates through the CLIProxyAPI hub on this host
  # (cliproxyapi.nix), with the OpenAI subscription logins there. The
  # `openrouter` provider takes any OpenAI-compatible base URL. Inside the
  # container 127.0.0.1 is the container, so the hub is reached through the
  # Docker host gateway. Literal values here win over the env files.
  override = (pkgs.formats.yaml { }).generate "claude-mem-server-override.yml" {
    services.claude-mem-worker = {
      environment = {
        CLAUDE_MEM_SERVER_PROVIDER = "openrouter";
        CLAUDE_MEM_OPENROUTER_BASE_URL = "http://host.docker.internal:8317/v1";
        CLAUDE_MEM_SERVER_MODEL = "gpt-6-luna";
      };
      extra_hosts = [ "host.docker.internal:host-gateway" ];
    };
    services.postgres.ports = [ "${tailnetIp}:5432:5432" ];
  };

  stateDir = "/var/lib/claude-mem-server";

  # srv-devbox's tailnet address (stable per node). Postgres is published
  # only here, so database clients on the tailnet can connect.
  tailnetIp = "100.75.137.72";

  # A fixed project name keeps the volumes (claude-mem_postgres-data, ...)
  # stable when the source store path changes on upgrade.
  compose = pkgs.writeShellScriptBin "claude-mem-server-compose" ''
    exec ${config.virtualisation.docker.package}/bin/docker compose \
      --project-name claude-mem \
      --project-directory ${src} \
      --file ${src}/docker-compose.yml \
      --file ${override} \
      --env-file ${stateDir}/postgres.env \
      --env-file ${config.clb.opAgents.secrets.claude-mem-server-env.path} \
      --env-file ${config.clb.opAgents.secrets.claude-mem-server-cliproxy-env.path} \
      "$@"
  '';
in
{
  virtualisation.docker = {
    enable = true;
    # Weekly `docker system prune`: dangling images from upgrades. Volumes
    # are kept.
    autoPrune.enable = true;
  };

  clb.opAgents.secrets = {
    # Dotenv file, kept whole in a Secure Note. Holds the worker's provider
    # settings and credential. docs/srv-devbox.md step 10 shows how to
    # replace it.
    claude-mem-server-env = {
      reference = "op://Agents/claude-mem-server-env/notesPlain";
      services = [ "claude-mem-server" ];
    };
    # The hub's client access key, as the worker's OpenRouter key. The last
    # env file, so it wins over any OPENROUTER_API_KEY above.
    claude-mem-server-cliproxy-env = {
      template = "OPENROUTER_API_KEY={{ op://Agents/CLIProxyAPI/cliproxyapi-api-key }}";
      services = [ "claude-mem-server" ];
    };
    # memories:read key that the viewer proxy adds to every request.
    claude-mem-viewer-env = {
      template = "CLAUDE_MEM_VIEWER_KEY={{ op://Agents/claude-mem-viewer/credential }}";
      services = [ "caddy" ];
    };
  };

  # Viewer at http://srv-devbox.mermaid-agama.ts.net:37878. Caddy adds the
  # read key, so anyone who reaches this port reads the key's team: bind the
  # tailnet address only, open the port only on tailscale0, and refuse any
  # source outside the tailnet ranges.
  services.caddy = {
    enable = true;
    globalConfig = "auto_https off";
    virtualHosts."http://:${toString viewerPort}".extraConfig = ''
      bind ${tailnetIp}
      @outsideTailnet not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
      respond @outsideTailnet 403
      reverse_proxy 127.0.0.1:37877 {
        header_up Authorization "Bearer {env.CLAUDE_MEM_VIEWER_KEY}"
      }
    '';
  };
  systemd.services.caddy = {
    after = [ "tailscaled.service" ];
    serviceConfig.EnvironmentFile = config.clb.opAgents.secrets.claude-mem-viewer-env.path;
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ viewerPort ];

  # Wraps compose with this stack's files for operations as root:
  # `sudo claude-mem-server-compose ps`, `logs -f`, `exec ...`.
  environment.systemPackages = [ compose ];

  systemd.services.claude-mem-server = {
    description = "claude-mem hosted server (Docker Compose)";
    after = [
      "cliproxyapi.service"
      "docker.service"
      "network-online.target"
      "tailscaled.service"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # Postgres reads its credentials only when it creates the data volume,
    # so they are generated once on the host and never rotated by Nix. Hex
    # keeps the password safe inside the database URL.
    preStart = ''
      if [ ! -s ${stateDir}/postgres.env ]; then
        umask 077
        printf 'POSTGRES_USER=claude_mem\nPOSTGRES_DB=claude_mem\nPOSTGRES_PASSWORD=%s\n' \
          "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${stateDir}/postgres.env
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "claude-mem-server";
      StateDirectoryMode = "0700";
      # Compose restarts crashed containers (restart: unless-stopped).
      ExecStart = "${compose}/bin/claude-mem-server-compose up --detach --build --remove-orphans";
      ExecStop = "${compose}/bin/claude-mem-server-compose down";
      # The first build downloads base images, npm packages, and the
      # embedding model.
      TimeoutStartSec = "1h";
    };
  };

  # Docker publishes 37877 through its own iptables rules, which bypass
  # networking.firewall, so the server is reachable from the LAN and the
  # tailnet like t3-serve. Listed here to document the open port.
  networking.firewall.allowedTCPPorts = [ 37877 ];

  # Postgres binds the tailnet address, which tailscaled may not have
  # assigned yet when the stack starts at boot. Non-local binds let the
  # port publish succeed before the address exists.
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;
}
