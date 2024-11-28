{ config, inputs, pkgs, currentSystemUser, ... }:

{
  #---------------------------------------------------------------------
  # Preferences
  #---------------------------------------------------------------------
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
  system.defaults.finder.ShowPathbar = true;
  system.defaults.finder.FXPreferredViewStyle = "Nlsv"; # List view
  system.defaults.finder.FXRemoveOldTrashItems = true; # Remove items from trash after 30 days
  system.defaults.finder.NewWindowTarget = "Home";
  system.defaults.ActivityMonitor.ShowCategory = 100; # Show all processes
  # Keyboard remapping currently does not work
  # system.keyboard.enableKeyMapping = true;
  # system.keyboard.remapCapsLockToEscape = true;


  # nixpkgs.overlays = import ../../lib/overlays.nix ++ [
  #   (import ./vim.nix { inherit inputs; })
  # ];

  # homebrew = {
  #   enable = true;
  #   casks  = [
  #     "1password"
  #     # "cleanshot"
  #     "discord"
  #     "google-chrome"
  #     # "hammerspoon"
  #     # "imageoptim"
  #     # "istat-menus"
  #     # "monodraw"
  #     # "raycast"
  #     # "rectangle"
  #     # "screenflow"
  #     "slack"
  #     "spotify"
  #   ];
  # };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.${currentSystemUser} = {
    home = "/Users/${currentSystemUser}";
    shell = pkgs.zsh;
  };
}
