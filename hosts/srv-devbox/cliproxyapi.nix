# CLIProxyAPI hub on srv-devbox: Claude and Codex subscription logins live
# here, and every other machine points Claude Code and Codex at this one
# endpoint. Setup follows
# https://gist.github.com/t3dotgg/59a521d2ee8d70aaf90e280c175072af. See
# docs/srv-devbox.md step 11.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  port = 8317;

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

  # Client access key and management panel key. The service reads them
  # through LoadCredential and writes them into its generated config.yaml.
  sops.secrets = {
    # Readable by the host user: Claude Code and Codex on this host use it
    # (modules/common/programs/cliproxyapi.nix).
    cliproxyapi-api-key = {
      sopsFile = ./cliproxyapi.yaml;
      key = "api-key";
      owner = config.clb.host.user;
    };
    cliproxyapi-management-key = {
      sopsFile = ./cliproxyapi.yaml;
      key = "management-key";
    };
    # OpenRouter upstream key (openrouter.ai/keys), for the models below.
    cliproxyapi-openrouter-key = {
      sopsFile = ./openrouter.yaml;
      key = "api-key";
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
        secret-key._secret = config.sops.secrets.cliproxyapi-management-key.path;
      };
      access.api-keys = [ { _secret = config.sops.secrets.cliproxyapi-api-key.path; } ];
      # OpenRouter as an upstream: clients use the aliases with the hub's
      # access key, and the hub sends the OpenRouter key. Only listed models
      # are exposed. The `-free` ones are rate-limited, not billed.
      # v8 layout: providers go under the top-level `api-keys` map, with
      # `keys` per group. At the root, the legacy layout ignores `keys`.
      api-keys.openai-compatibility = [
        {
          name = "openrouter";
          base-url = "https://openrouter.ai/api/v1";
          keys = [ { api-key._secret = config.sops.secrets.cliproxyapi-openrouter-key.path; } ];
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

  # Restart on key rotation; the config is regenerated at each start.
  systemd.services.cliproxyapi.restartTriggers = [
    ./cliproxyapi.yaml
    ./openrouter.yaml
  ];

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
