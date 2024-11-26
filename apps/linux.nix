{ pkgs }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  packages = [
    pkgs.curl
    pkgs.git
    pkgs.htop
  ];
}
