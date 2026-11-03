{ pkgs, ... }:

{
  _class = "darwin";

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
  programs.zsh.interactiveShellInit = ''
    # Rex
    if [ -n "$REX_BIN_DIR" ]; then
      export PATH="$REX_BIN_DIR:$PATH"
    fi
  '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    # Nix
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
    # End Nix
  '';
  programs.fish.interactiveShellInit = ''
    # Rex
    if test -n "$REX_BIN_DIR"
      set -gx PATH $REX_BIN_DIR $PATH
    end
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
