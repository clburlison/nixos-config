# Host override file for clb-work (system).
{
  _class = "darwin";

  imports = [ ./hub-proxy.nix ];

  # Standalone Tailscale (tailscale-app cask) updates itself with Sparkle.
  # The Homebrew cask is auto_updates, so `brew bundle --no-upgrade` leaves
  # updates to the app.
  system.defaults.CustomUserPreferences."io.tailscale.ipn.macsys" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
    HideDockIcon = true;
  };
}
