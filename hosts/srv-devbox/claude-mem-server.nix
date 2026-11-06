# claude-mem hosted server (beta) on srv-devbox: upstream's Docker Compose
# stack (Postgres 17 with pgvector and pg_textsearch, Valkey, the HTTP
# server on port 37877, and the generation worker), pinned to a release tag.
# Compose builds the images locally from the pinned source. See README
# step 10 and https://docs.claude-mem.ai/hosted-server.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  version = "15.10.0";
  src = pkgs.fetchFromGitHub {
    owner = "thedotmack";
    repo = "claude-mem";
    tag = "v${version}";
    hash = "sha256-gtIt9Q/eFWkKdDXm8SHiTPkQE7xHJp1n9MbLq5sD/Is=";
  };

  # Upstream's compose file passes only the provider choice and API keys
  # to the worker. Also pass the model (the `openrouter` provider's default
  # is a free model) and the Claude subscription token from the sops env
  # file. No credential leaves the worker idle.
  passthrough = [
    "CLAUDE_MEM_SERVER_MODEL"
    "CLAUDE_CODE_OAUTH_TOKEN"
  ];
  override = (pkgs.formats.yaml { }).generate "claude-mem-server-override.yml" {
    services.claude-mem-worker.environment = lib.genAttrs passthrough (name: "\${${name}:-}");
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
      --env-file ${config.sops.secrets.claude-mem-server-env.path} \
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

  # Dotenv file, encrypted whole (sops binary format). Holds the worker's
  # provider settings and credential. README step 10 shows how to replace
  # it.
  sops.secrets.claude-mem-server-env = {
    sopsFile = ./claude-mem-server.env.sops;
    format = "binary";
  };

  # Wraps compose with this stack's files for operations as root:
  # `sudo claude-mem-server-compose ps`, `logs -f`, `exec ...`.
  environment.systemPackages = [ compose ];

  systemd.services.claude-mem-server = {
    description = "claude-mem hosted server (Docker Compose)";
    after = [
      "docker.service"
      "network-online.target"
      "tailscaled.service"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.sops.secrets.claude-mem-server-env.sopsFile ];

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
