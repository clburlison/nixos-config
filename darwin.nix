{
  config,
  inputs,
  pkgs,
  currentSystemUser,
  ...
}:

{
  # Determinate Nix uses its own daemon to manage the Nix
  # both being enabled at the same fails.
  nix.enable = false;

  # https://github.com/NixOS/nixpkgs/pull/73966
  documentation.doc.enable = false;

  #---------------------------------------------------------------------
  # Preferences
  #---------------------------------------------------------------------
  # Previously, some nix-darwin options applied to the user running
  # `darwin-rebuild`. As part of a long‐term migration to make
  # nix-darwin focus on system‐wide activation and support first‐class
  # multi‐user setups, all system activation now runs as `root`, and
  # these options instead apply to the `system.primaryUser` user.
  #
  #
  # To continue using these options, set `system.primaryUser` to the name
  # of the user you have been using to run `darwin-rebuild`. In the long
  # run, this setting will be deprecated and removed after all the
  # functionality it is relevant for has been adjusted to allow
  # specifying the relevant user separately, moved under the
  # `users.users.*` namespace, or migrated to Home Manager.
  #
  # system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  # system.defaults.finder.AppleShowAllExtensions = true;
  # system.defaults.finder.FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
  # system.defaults.finder.ShowPathbar = true;
  # system.defaults.finder.FXPreferredViewStyle = "Nlsv"; # List view
  # system.defaults.finder.FXRemoveOldTrashItems = true; # Remove items from trash after 30 days
  # system.defaults.finder.NewWindowTarget = "Home";
  # system.defaults.ActivityMonitor.ShowCategory = 100; # Show all processes

  # Keyboard remapping currently does not work
  # system.keyboard.enableKeyMapping = true;
  # system.keyboard.remapCapsLockToEscape = true;

  # nixpkgs.overlays = import ../../lib/overlays.nix ++ [
  #   (import ./vim.nix { inherit inputs; })
  # ];

  # Install Homebrew itself. nix-darwin's `homebrew` module below only
  # manages packages in an existing Homebrew installation.
  nix-homebrew = {
    enable = true;
    user = currentSystemUser;

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
      "discord"
      "firefox"
      "ghostty"
      "google-chrome"
      "hiddenbar"
      "karabiner-elements"
      "raycast"
      "slack"
      "spotify"
      "suspicious-package"
      "tableplus"
      "tableplus"
      "tower"
      "utm"
      "zed"
      "zen"
    ];
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  system.primaryUser = currentSystemUser;

  users.users.${currentSystemUser} = {
    home = "/Users/${currentSystemUser}";
    shell = pkgs.fish;
  };
}
