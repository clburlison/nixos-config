{ config, pkgs, ... }: {
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # Determinate Nix includes this file from /etc/nix/nix.conf. nix-darwin's
  # nix.settings are inactive because nix.enable is false in darwin.nix.
  system.activationScripts.postActivation.text =
    let
      nixCustomConf = pkgs.writeText "nix.custom.conf" ''
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
    '';

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
  '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    # Nix
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
    # End Nix
  '';

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];
  # environment.systemPackages = with pkgs; [
  #   cachix
  # ];
}
