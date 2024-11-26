{ pkgs }:

{
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  linuxPackages = [
    pkgs.curl
    pkgs.git
    pkgs.htop
  ];
}
