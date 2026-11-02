{
  config,
  lib,
  pkgs,
  ...
}:

{
  _class = "darwin";

  # Determinate Nix uses its own daemon to manage the Nix
  # both being enabled at the same fails.
  nix.enable = false;

  # Determinate Nix includes this file from /etc/nix/nix.conf. nix-darwin's
  # nix.settings are inactive because nix.enable is false above.
  # Runs first in postActivation, before Home Manager activation.
  system.activationScripts.postActivation.text = lib.mkBefore (
    let
      nixCustomConf = pkgs.writeText "nix.custom.conf" ''
        trusted-users = root ${config.clb.host.user}
        accept-flake-config = true
        keep-outputs = true
        keep-derivations = true
        extra-substituters = https://nix-community.cachix.org https://nix-darwin.cachix.org https://nixpkgs-ruby.cachix.org
        extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nix-darwin.cachix.org-1:RIiwxkm/D5C8GGGdWKYQOY5TdpYIQejZ+j+O6Qz0aFA= nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=
      '';
    in
    ''
      if ! cmp -s ${nixCustomConf} /etc/nix/nix.custom.conf; then
        install -m 0644 ${nixCustomConf} /etc/nix/nix.custom.conf
        launchctl kickstart -k system/systems.determinate.nix-daemon
      fi
    ''
  );
}
