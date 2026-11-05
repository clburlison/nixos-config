# Home Manager settings that break or are meaningless on Linux.
{ lib, pkgs, ... }:

{
  _class = "homeManager";

  config = lib.mkIf pkgs.stdenv.isDarwin {
    # After the common list in modules/common/default.nix.
    home.packages = lib.mkOrder 1051 [
      # Install on macOS only
      # pkgs.ngrok
      # pkgs.yt-dlp # youtube-dl replacement
      pkgs._1password-cli
      pkgs.colima
      pkgs.docker
      pkgs.ffmpeg_7-full
      pkgs.hugo
      pkgs.terraform-docs
      pkgs.tflint
    ];

    # Disable Safe Mode for Zen/Firefox. I use the hyper key for launch and this causes issues.
    # https://github.com/zen-browser/desktop/issues/6538
    launchd.agents.MOZ_DISABLE_SAFE_MODE = {
      enable = true;
      config = {
        Label = "com.clburlison.MOZ_DISABLE_SAFE_MODE";
        ProgramArguments = [
          "/bin/launchctl"
          "setenv"
          "MOZ_DISABLE_SAFE_MODE_KEY"
          "1"
        ];
        RunAtLoad = true;
        ServiceIPC = false;
      };
    };
  };
}
