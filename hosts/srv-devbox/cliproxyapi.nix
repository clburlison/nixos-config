# CLIProxyAPI hub on srv-devbox: Claude and Codex subscription logins live
# here, and every other machine points Claude Code and Codex at this one
# endpoint. Setup follows
# https://gist.github.com/t3dotgg/59a521d2ee8d70aaf90e280c175072af. See
# README step 11.
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

  # Client access key and management panel key. Root-owned; the service
  # reads them through LoadCredential and writes them into its generated
  # config.yaml.
  sops.secrets = {
    cliproxyapi-api-key = {
      sopsFile = ./cliproxyapi.yaml;
      key = "api-key";
    };
    cliproxyapi-management-key = {
      sopsFile = ./cliproxyapi.yaml;
      key = "management-key";
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
  systemd.services.cliproxyapi.restartTriggers = [ ./cliproxyapi.yaml ];

  # `sudo cliproxyapi-login -codex-device-login`: account logins as the service
  # user, saved to the service's auth dir. The running service picks new
  # accounts up without a restart.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "cliproxyapi-login" ''
      cd /var/lib/cliproxyapi
      exec ${pkgs.util-linux}/bin/runuser -u cliproxyapi -- \
        ${pkgs.cliproxyapi}/bin/cliproxyapi -config /var/lib/cliproxyapi/config.yaml -no-browser "$@"
    '')
  ];
}
