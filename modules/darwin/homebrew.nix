{ config, inputs, ... }:

{
  _class = "darwin";

  # nix-darwin's homebrew module manages packages, but nix-homebrew
  # installs and owns Homebrew itself.
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # Install Homebrew itself. nix-darwin's `homebrew` module below only
  # manages packages in an existing Homebrew installation.
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

  homebrew = {
    enable = true;

    # Avoid changing unrelated packages on every system rebuild. Declared
    # packages are still installed when missing.
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };

    casks = [
      "1password"
      "claude"
      "discord"
      "firefox"
      "ghostty"
      "google-chrome"
      "hiddenbar"
      "karabiner-elements"
      "linear"
      "loom"
      "notion"
      "openusage"
      "orbstack"
      "raycast"
      "slack"
      "spotify"
      "suspicious-package"
      "tableplus"
      "t3-code"
      "tailscale-app"
      "tower"
      "utm"
      "zed"
      "zen"
      "zoom"
    ];

    masApps = {
      Amphetamine = 937984704;
    };
  };
}
