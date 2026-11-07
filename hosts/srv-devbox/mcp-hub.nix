# MCP hub on srv-devbox: Slack, Zoom and Intercom MCP access behind one
# authenticated endpoint. Other machines point Claude Code at it
# (modules/common/programs/mcp.nix) instead of each doing OAuth and holding
# the credentials. Replaces the claude.ai connectors, which an
# ANTHROPIC_BASE_URL setup can't reach. See docs/srv-devbox.md step 13.
#
# Slack and Zoom use their hosted OAuth servers. Neither supports dynamic
# client registration, so the hub uses your own OAuth app for each, logs in
# once (`sudo mcp-hub-login <name>`), and `mcp-remote` refreshes the tokens
# from then on. mcp-proxy bridges mcp-remote's stdio to HTTP.
#
# Secrets live in 1Password, not in sops. The only sops secret is the hub's
# own service account token (`mcp-hub-op-token`); every service resolves its
# `{{ op://... }}` references with `op inject` each time it starts.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 8319;
  # Runtime env files, rendered by `op inject`. Root only, tmpfs.
  envDir = "/run/mcp-hub";
  stateRoot = "/var/lib/mcp-hub";
  mcpRemote = "mcp-remote@0.16.5";

  # The `MCP` vault holds the upstream credentials and is read by the hub's
  # service account only. The access token clients present is in `Agents`,
  # which the shared agent-git service account (every machine) can read.
  vault = "MCP";
  secret = item: field: "{{ op://${vault}/${item}/${field} }}";
  accessToken = "{{ op://Agents/mcp-hub/credential }}";

  # Add a server: one entry here, then add its name to a client's
  # `clb.mcp.servers`. It is served at /<name>/mcp.
  #   oauth:         a hosted OAuth server. `url` is its endpoint, `port` the
  #                  local port of the login callback (register
  #                  http://localhost:<port>/oauth/callback on the OAuth
  #                  app), `proxyPort` where mcp-proxy listens, `scope`
  #                  optional space-separated scopes to request.
  #   url + headers: a hosted server with a static token; the gateway adds
  #                  the headers.
  servers = {
    # Slack's hosted server takes a confidential OAuth app (client ID and
    # secret), internal or Marketplace, approved by a workspace admin. Read
    # scopes only; add the write scopes to the app and here for messages,
    # reactions and canvases.
    slack = {
      oauth = {
        url = "https://mcp.slack.com/mcp";
        port = 3118;
        proxyPort = 13080;
        scope = lib.concatStringsSep " " [
          "search:read.public"
          "search:read.private"
          "search:read.mpim"
          "search:read.im"
          "search:read.files"
          "search:read.users"
          "channels:history"
          "groups:history"
          "mpim:history"
          "im:history"
          "channels:read"
          "groups:read"
          "mpim:read"
          "im:read"
          "users:read"
          "users:read.email"
        ];
      };
      env = {
        MCP_OAUTH_CLIENT_ID = secret "slack" "client-id";
        MCP_OAUTH_CLIENT_SECRET = secret "slack" "client-secret";
      };
    };

    # Zoom's hosted server takes a General app with user-level OAuth; the
    # scopes are the ones set on the app. Regional endpoints (mcp-us,
    # mcp-eu, mcp-au .zoom.us) exist if the account needs one.
    zoom = {
      oauth = {
        url = "https://mcp.zoom.us/mcp/zoom/streamable";
        port = 3119;
        proxyPort = 13081;
      };
      env = {
        MCP_OAUTH_CLIENT_ID = secret "zoom" "client-id";
        MCP_OAUTH_CLIENT_SECRET = secret "zoom" "client-secret";
      };
    };

    # Intercom's hosted server takes an access token as a bearer token. Not
    # available this way: the Fin Operator tools (OAuth only). EU
    # workspaces use https://mcp.eu.intercom.com/mcp.
    intercom = {
      url = "https://mcp.intercom.com/mcp";
      headers.Authorization = "Bearer ${secret "intercom" "token"}";
    };
  };

  local = lib.filterAttrs (_: s: s ? oauth) servers;
  remote = lib.filterAttrs (_: s: s ? url) servers;

  envLines = env: lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") env) + "\n";

  # Renders a template to ${envDir}/<name>.env before the service starts,
  # as root (the `+` on ExecStartPre), so a failed 1Password lookup fails
  # the start and Restart retries it.
  inject =
    name: env:
    pkgs.writeShellScript "mcp-hub-inject-${name}" ''
      umask 077
      export HOME=${envDir}
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${config.sops.secrets.mcp-hub-op-token.path})"
      export OP_SERVICE_ACCOUNT_TOKEN
      exec ${lib.getExe pkgs._1password-cli} inject --force \
        --file-mode 0600 \
        --in-file ${pkgs.writeText "mcp-hub-${name}.env.tpl" (envLines env)} \
        --out-file ${envDir}/${name}.env
    '';

  hardening = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    Restart = "on-failure";
    RestartSec = "30s";
  };

  base = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
  };

  # Runs one OAuth server. Serving: mcp-proxy bridges mcp-remote to HTTP on
  # 127.0.0.1. With MCP_HUB_LOGIN set: mcp-remote alone, to log in (it
  # prints the authorization URL and waits for the callback on `port`). The
  # OAuth client goes to a private file, not argv, so it isn't in the
  # process list.
  oauthRun =
    name: server:
    let
      o = server.oauth;
      remoteArgs = [
        "${pkgs.nodejs_24}/bin/npx"
        "--yes"
        mcpRemote
        o.url
        (toString o.port)
        "--transport"
        "http-only"
        "--static-oauth-client-info"
        "@\"$dir/client.json\""
      ]
      ++ lib.optionals (o ? scope) [
        "--static-oauth-client-metadata"
        "@\"$dir/metadata.json\""
      ];
    in
    pkgs.writeShellScript "mcp-hub-run-${name}" ''
      set -eu
      umask 077
      dir="''${RUNTIME_DIRECTORY:-$(mktemp -d)}"
      ${pkgs.jq}/bin/jq -n --arg id "$MCP_OAUTH_CLIENT_ID" --arg secret "$MCP_OAUTH_CLIENT_SECRET" \
        '{client_id: $id, client_secret: $secret}' > "$dir/client.json"
      ${lib.optionalString (o ? scope) ''
        ${pkgs.jq}/bin/jq -n --arg scope ${lib.escapeShellArg o.scope} '{scope: $scope}' > "$dir/metadata.json"
      ''}
      if [ -n "''${MCP_HUB_LOGIN:-}" ]; then
        # mcp-remote authenticates on startup, then exits at the end of stdin.
        ${lib.concatStringsSep " " remoteArgs} --auth-timeout 600 </dev/null
      else
        exec ${lib.getExe pkgs.mcp-proxy} --host 127.0.0.1 --port ${toString o.proxyPort} \
          --pass-environment -- ${lib.concatStringsSep " " remoteArgs}
      fi
    '';

  mkServer =
    name: server:
    lib.nameValuePair "mcp-hub-${name}" (
      base
      // {
        description = "MCP hub: ${name}";
        # Until `mcp-hub-login` has saved tokens, skip the start instead of
        # looping on an authorization URL nobody opens.
        unitConfig.ConditionPathExistsGlob = "${stateRoot}/${name}/mcp-auth/*/*_tokens.json";
        path = [
          pkgs.bash
          pkgs.coreutils
          pkgs.nodejs_24
        ];
        environment = {
          HOME = "${stateRoot}/${name}";
          MCP_REMOTE_CONFIG_DIR = "${stateRoot}/${name}/mcp-auth";
        };
        serviceConfig = hardening // {
          User = "mcp-hub";
          Group = "mcp-hub";
          ExecStartPre = "+${inject name server.env}";
          # `-`: the file doesn't exist until ExecStartPre has run once.
          EnvironmentFile = "-${envDir}/${name}.env";
          StateDirectory = "mcp-hub/${name}";
          RuntimeDirectory = "mcp-hub-${name}";
          RuntimeDirectoryMode = "0700";
          ExecStart = oauthRun name server;
        };
      }
    );

  # `sudo mcp-hub-login <name>`: renders the server's secrets, then runs the
  # OAuth login as the service user, so the tokens land in its state dir.
  # Open the printed URL in a browser that can reach the callback port, e.g.
  # through `ssh -L <port>:localhost:<port> srv-devbox`.
  login = pkgs.writeShellScriptBin "mcp-hub-login" ''
    set -eu
    name="''${1:-}"
    case "$name" in
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: server: ''
          ${name})
            port=${toString server.oauth.port}
            inject=${inject name server.env}
            run=${oauthRun name server}
            ;;
        '') local
      )}
      *)
        echo "usage: mcp-hub-login ${lib.concatStringsSep "|" (lib.attrNames local)}" >&2
        exit 2
        ;;
    esac

    "$inject"
    echo "Callback: http://localhost:$port/oauth/callback" >&2
    echo "From your machine: ssh -L $port:localhost:$port ${config.networking.hostName}" >&2
    # KEY=VALUE lines, read literally rather than sourced.
    while IFS== read -r key value; do
      export "$key=$value"
    done < ${envDir}/$name.env
    dir="$(mktemp -d)"
    chown mcp-hub:mcp-hub "$dir"
    trap 'rm -rf "$dir"' EXIT
    ${pkgs.util-linux}/bin/runuser -u mcp-hub -- env \
      "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.nodejs_24
        ]
      }" \
      "HOME=${stateRoot}/$name" \
      "MCP_REMOTE_CONFIG_DIR=${stateRoot}/$name/mcp-auth" \
      "RUNTIME_DIRECTORY=$dir" \
      "MCP_OAUTH_CLIENT_ID=$MCP_OAUTH_CLIENT_ID" \
      "MCP_OAUTH_CLIENT_SECRET=$MCP_OAUTH_CLIENT_SECRET" \
      MCP_HUB_LOGIN=1 "$run"
    systemctl restart "mcp-hub-$name.service"
    echo "Logged in; mcp-hub-$name restarted." >&2
  '';

  # Environment variable carrying a remote server's header value.
  headerVar =
    name: header: "MCP_${lib.toUpper name}_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] header)}";

  gatewayEnv = {
    MCP_HUB_TOKEN = accessToken;
  }
  // lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        name: server:
        lib.mapAttrsToList (header: value: lib.nameValuePair (headerVar name header) value) server.headers
      ) remote
    )
  );

  localRoute = name: server: ''
    handle_path /${name}/* {
      reverse_proxy 127.0.0.1:${toString server.oauth.proxyPort} {
        header_up -Authorization
        flush_interval -1
      }
    }
  '';

  remoteRoute =
    name: server:
    let
      m = builtins.match "(https?://[^/]+)(/.*)?" server.url;
      origin = builtins.elemAt m 0;
      path = if builtins.elemAt m 1 == null then "/" else builtins.elemAt m 1;
    in
    ''
      handle_path /${name}/* {
        rewrite * ${path}
        reverse_proxy ${origin} {
          ${lib.concatStringsSep "\n    " (
            lib.mapAttrsToList (
              header: _: "header_up ${header} \"{$" + headerVar name header + "}\""
            ) server.headers
          )}
          flush_interval -1
        }
      }
    '';

  # {$VAR} is replaced when Caddy parses the file, from the environment
  # the unit gets from ${envDir}/gateway.env, so no secret is in the store.
  caddyfile = pkgs.writeText "mcp-hub.Caddyfile" ''
    {
      admin off
      auto_https off
    }

    :${toString port} {
      @authed header Authorization "Bearer {$MCP_HUB_TOKEN}"
      handle @authed {
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList localRoute local)}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList remoteRoute remote)}
        respond "unknown server" 404
      }
      respond "unauthorized" 401
    }
  '';
in
{
  # The hub's 1Password service account token (read on the MCP and Agents
  # vaults). Create mcp-hub.yaml first (docs/srv-devbox.md step 13).
  sops.secrets.mcp-hub-op-token = {
    sopsFile = ./mcp-hub.yaml;
    key = "op-token";
  };

  # Owns the OAuth tokens in ${stateRoot}/<name>/mcp-auth.
  users.users.mcp-hub = {
    isSystemUser = true;
    group = "mcp-hub";
  };
  users.groups.mcp-hub = { };

  # The state dirs exist before the first login, which runs before the
  # services have started.
  systemd.tmpfiles.rules = [
    "d ${envDir} 0700 root root -"
    "d ${stateRoot} 0755 root root -"
  ]
  ++ lib.mapAttrsToList (name: _: "d ${stateRoot}/${name} 0700 mcp-hub mcp-hub -") local;

  systemd.services = lib.mapAttrs' mkServer local // {
    mcp-hub-gateway = base // {
      description = "MCP hub gateway";
      environment = {
        XDG_DATA_HOME = "/var/lib/mcp-hub-gateway";
        XDG_CONFIG_HOME = "/var/lib/mcp-hub-gateway";
      };
      serviceConfig = hardening // {
        DynamicUser = true;
        ExecStartPre = "+${inject "gateway" gatewayEnv}";
        EnvironmentFile = "-${envDir}/gateway.env";
        StateDirectory = "mcp-hub-gateway";
        ExecStart = "${lib.getExe pkgs.caddy} run --config ${caddyfile} --adapter caddyfile";
      };
    };
  };

  environment.systemPackages = [ login ];

  # Tailnet only. The backends bind 127.0.0.1.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}
