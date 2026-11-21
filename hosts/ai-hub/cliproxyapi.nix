# CLIProxyAPI hub on ai-hub: Claude and Codex subscription logins live
# here, and every other machine points Claude Code and Codex at this one
# endpoint. Setup follows
# https://gist.github.com/t3dotgg/59a521d2ee8d70aaf90e280c175072af. See
# docs/ai-hub.md step 11.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  port = 8317;
  effortModels = import ../../lib/effort-models.nix { inherit lib; };

  # The module and package are only in nixpkgs-unstable (the package comes
  # from the overlay in lib/nixpkgs.nix). Drop the module's `meta`: its
  # manual chapter breaks the 26.05 manual build (missing redirects).
  module = import "${inputs.nixpkgs-unstable}/nixos/modules/services/misc/cliproxyapi.nix";
  moduleWithoutDocs = lib.setFunctionArgs (args: removeAttrs (module args) [ "meta" ]) (
    lib.functionArgs module
  );
in
{
  imports = [ moduleWithoutDocs ];

  # Client access key, management panel key, and the OpenRouter upstream
  # key (openrouter.ai/keys) for the models below. The service reads them
  # through LoadCredential and writes them into its generated config.yaml.
  clb.opAgents.secrets = {
    # Readable by the host user: Claude Code and Codex on this host use it
    # (modules/common/programs/cliproxyapi.nix).
    cliproxyapi-api-key = {
      reference = "op://Agents/CLIProxyAPI/cliproxyapi-api-key";
      owner = config.clb.host.user;
      services = [ "cliproxyapi" ];
    };
    cliproxyapi-management-key = {
      reference = "op://Agents/CLIProxyAPI/password";
      services = [ "cliproxyapi" ];
    };
    cliproxyapi-openrouter-key = {
      reference = "op://Agents/OpenRouter/credential";
      services = [ "cliproxyapi" ];
    };
  };

  services.cliproxyapi = {
    enable = true;
    # Direct access from the LAN and the tailnet (plain HTTP), like t3-serve.
    openFirewall = true;
    settings = {
      config-version = 8;
      server = {
        # All interfaces: the LAN address and the tailnet address.
        host = "";
        inherit port;
      };
      management = {
        # The panel at /management.html, from other machines.
        allow-remote = true;
        secret-key._secret = config.clb.opAgents.secrets.cliproxyapi-management-key.path;
      };
      access.api-keys = [ { _secret = config.clb.opAgents.secrets.cliproxyapi-api-key.path; } ];
      # OpenRouter as an upstream: clients use the aliases with the hub's
      # access key, and the hub sends the OpenRouter key. Only listed models
      # are exposed. The `-free` ones are rate-limited, not billed.
      # v8 layout: providers go under the top-level `api-keys` map, with
      # `keys` per group. At the root, the legacy layout ignores `keys`.
      api-keys.openai-compatibility = [
        {
          name = "openrouter";
          base-url = "https://openrouter.ai/api/v1";
          keys = [ { api-key._secret = config.clb.opAgents.secrets.cliproxyapi-openrouter-key.path; } ];
          models = [
            {
              name = "moonshotai/kimi-k3.1-pro";
              alias = "kimi-k3.1-pro";
            }
            {
              name = "deepseek/deepseek-v4.1-flash";
              alias = "deepseek-v4.1-flash";
            }
            {
              name = "z-ai/glm-5.3";
              alias = "glm-5.3";
            }
            {
              name = "x-ai/grok-4.7";
              alias = "grok-4.7";
            }
            {
              name = "google/gemma-4-31b-it:free";
              alias = "gemma-4-31b-free";
            }
            {
              name = "cohere/north-mini-code:free";
              alias = "north-mini-code-free";
            }
          ];
        }
      ];
      # Per-request usage records for CPA Usage Keeper
      # (cpa-usage-keeper.nix), which pulls them from the hub's queue. Keep
      # them the maximum hour, so a Keeper restart loses nothing.
      observability.usage = {
        usage-statistics-enabled = true;
        redis-usage-queue-retention-seconds = 3600;
      };
      # One model per reasoning effort (lib/effort-models.nix) for the
      # Antigravity and Codex accounts, for agy's Thinking Level and other
      # clients with no effort setting. An alias selects the upstream model;
      # a payload rule on the alias sets its effort, replacing the client's.
      # Antigravity payload paths are relative to its `request` wrapper.
      oauth.model-alias = effortModels.aliases;
      oauth.excluded-models = effortModels.excluded;
      requests.payload = effortModels.payload;
      routing = {
        strategy = "round-robin";
        # Keep a session on one account so its prompt cache is reused.
        session-affinity = true;
        session-affinity-ttl = "1h";
        retry = {
          request-retry = 3;
          max-retry-interval = 30;
        };
      };
    };
  };

  # The hub over HTTPS on the tailnet, at
  # https://ai-hub.mermaid-agama.ts.net:8443, for agy on Macs: it rejects a
  # remote plain-http gateway. Tailscale Serve terminates TLS with the
  # ts.net cert; its :443 belongs to t3-serve (home.nix), which adds its
  # own port and leaves this one alone.
  systemd.services.cliproxyapi-tailscale-serve = {
    description = "Serve CLIProxyAPI over HTTPS on the tailnet";
    after = [
      "tailscaled.service"
      "cliproxyapi.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=8443 http://127.0.0.1:${toString port}";
      # tailscaled may still be connecting at boot.
      Restart = "on-failure";
      RestartSec = 30;
    };
  };

  # `sudo cliproxyapi-login -claude-login` (and `-codex-login` or
  # `-codex-device-login`): account logins as the service user, saved to
  # the service's auth dir. The running service picks new accounts up
  # without a restart.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "cliproxyapi-login" ''
      cd /var/lib/cliproxyapi
      exec ${pkgs.util-linux}/bin/runuser -u cliproxyapi -- \
        ${pkgs.cliproxyapi}/bin/cliproxyapi -config /var/lib/cliproxyapi/config.yaml -no-browser "$@"
    '')
  ];
}
