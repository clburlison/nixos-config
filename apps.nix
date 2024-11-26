{ pkgs, system }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  darwinPackages = if system == "x86_64-darwin" || system == "aarch64-darwin" then [
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
  ] else [];

  linuxPackages = if system == "x86_64-linux" then [
    pkgs.curl
    pkgs.git
    pkgs.htop
  ] else [];

  wslPackages = if system == "x86_64-linux" && builtins.getEnv "WSL_DISTRO_NAME" != null then [
    pkgs.wsl-open
    pkgs.wsl-setup
  ] else [];
}
