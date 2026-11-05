{ config, ... }:

{
  _class = "darwin";

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
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain."com.apple.sound.beep.feedback" = 1; # requires system restart afterwards
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
  system.defaults.finder.ShowPathbar = true;
  system.defaults.finder.ShowStatusBar = true;
  system.defaults.finder.FXPreferredViewStyle = "Nlsv"; # List view
  system.defaults.finder.FXRemoveOldTrashItems = true; # Remove items from trash after 30 days
  system.defaults.finder.NewWindowTarget = "Home";
  system.defaults.finder.FXDefaultSearchScope = "SCcf";
  system.defaults.CustomUserPreferences."com.apple.finder".DesktopViewSettings.GroupBy = "Kind"; # Use Stacks on the desktop
  system.defaults.ActivityMonitor.ShowCategory = 100; # Show all processes

  # Standalone Tailscale (tailscale-app cask) updates itself with Sparkle.
  # The Homebrew cask is auto_updates, so `brew bundle --no-upgrade` leaves
  # updates to the app.
  system.defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
    HideDockIcon = true;
  };

  system.defaults.dock = {
    autohide = true;
    orientation = "left";
    show-recents = false;
    persistent-apps = [
      "/Applications/Google Chrome.app"
      "/Applications/Slack.app"
      "/Applications/Spotify.app"
      "/Applications/zoom.us.app"
      "/Applications/1Password.app"
      "/Applications/Ghostty.app"
      "/Applications/Tower.app"
      "/Applications/TablePlus.app"
      "/System/Applications/Messages.app"
      "/System/Applications/System Settings.app"
    ];
    persistent-others = [
      {
        folder = {
          path = "/Users/${config.clb.host.user}/Downloads";
          displayas = "folder";
          arrangement = "date-added";
          showas = "grid";
        };
      }
    ];
  };

  # Keyboard remapping
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;
}
