{ pkgs }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  wslPackages = [
    pkgs.wsl-open
    pkgs.wsl-setup
  ];
}
