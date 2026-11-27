# This function creates a standalone Home Manager configuration,
# homeConfigurations."<user>@<host>", for one Host table entry.
{ inputs }:

name:
{
  system,
  user,
  profile ? "workstation",
  ...
}:

let
  inherit (inputs.nixpkgs) lib;
  nixpkgsSettings = import ./nixpkgs.nix { inherit inputs; };
  profileHome = ../modules/common/${profile}.nix;
  hostHome = ../hosts/${name}/home.nix;
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs {
    inherit system;
    inherit (nixpkgsSettings) overlays config;
  };
  extraSpecialArgs = { inherit inputs; };

  modules = [
    ./host-option.nix
    {
      clb.host = { inherit name user profile; };
      programs.home-manager.enable = true;
    }
    ../modules/common
  ]
  ++ lib.optional (builtins.pathExists profileHome) profileHome
  ++ lib.optional (builtins.pathExists hostHome) hostHome;
}
