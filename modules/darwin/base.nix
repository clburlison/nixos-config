{ config, pkgs, ... }:

{
  _class = "darwin";

  # https://github.com/NixOS/nixpkgs/pull/73966
  documentation.doc.enable = false;

  # Enable Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  system.primaryUser = config.clb.host.user;

  # GUI apps (e.g. T3 Code) skip shell init, so give Node the Nix CA bundle
  # via launchd or remote MCP servers fail TLS verification.
  launchd.user.envVariables.NODE_EXTRA_CA_CERTS = config.environment.variables.NIX_SSL_CERT_FILE;

  users.users.${config.clb.host.user} = {
    home = "/Users/${config.clb.host.user}";
    shell = pkgs.fish;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
