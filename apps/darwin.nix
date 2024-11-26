{ pkgs }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  # https://search.nixos.org/packages
  packages = [
    pkgs.azure-cli
    pkgs.bun
    pkgs.ffmpeg_7-full
    pkgs.git
    pkgs.git-lfs
    pkgs.go
    pkgs.hugo
    pkgs.jq
    pkgs.ngrok
    pkgs.python312
    pkgs.ripgrep-all
    pkgs.terraform
    pkgs.terraform-docs
    pkgs.tflint
    pkgs.tmux
    pkgs.tree
    pkgs.vim
    pkgs.wget
    pkgs.yt-dlp # youtube-dl replacement
    pkgs.zsh-z
  ];
}
