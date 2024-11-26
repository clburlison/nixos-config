{ pkgs }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  packages = [
    pkgs.wsl-open
    pkgs.wsl-setup
  ];
}
