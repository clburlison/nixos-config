{ lib, pkgs, ... }:

# Homebrew casks and Mac App Store apps, installed by `task home` without
# sudo. Homebrew itself (/opt/homebrew) is installed by nix-homebrew in
# modules/darwin/homebrew.nix.
#
# Runs `brew bundle --no-upgrade`: installs anything missing, never upgrades,
# and never removes apps dropped from these lists. Casks that ship a .pkg
# installer (karabiner-elements, tailscale-app, zoom) prompt for sudo the
# first time they install.
let
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

  brewPrefix = "/opt/homebrew";

  brewfile = pkgs.writeText "Brewfile" (
    lib.concatLines (
      map (cask: ''cask "${cask}", trusted: true'') casks
      ++ lib.mapAttrsToList (name: id: ''mas "${name}", id: ${toString id}'') masApps
    )
  );
in
{
  _class = "homeManager";

  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.activation.homebrewBundle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x ${brewPrefix}/bin/brew ]; then
        PATH="${brewPrefix}/bin:${lib.getBin pkgs.mas}/bin:$PATH" \
          HOMEBREW_NO_AUTO_UPDATE=1 \
          run ${brewPrefix}/bin/brew bundle --file=${brewfile} --no-upgrade
      else
        warnEcho "Homebrew is not installed; run 'task system' first. Skipping casks."
      fi
    '';
  };
}
