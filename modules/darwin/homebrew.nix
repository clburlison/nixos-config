{ config, inputs, ... }:

{
  _class = "darwin";

  # Installs and owns Homebrew itself. Casks and Mac App Store apps are
  # installed by Home Manager (modules/common/programs/homebrew.nix) so
  # they apply with `task home`, no sudo.
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    user = config.clb.host.user;

    # All configured Macs are Apple Silicon. Leave the Intel prefix disabled
    # unless an x86_64-only formula is required through Rosetta.
    enableRosetta = false;

    # Keep taps writable so normal Homebrew casks work without pinning the
    # homebrew-core and homebrew-cask repositories as separate flake inputs.
    mutableTaps = true;
  };
}
