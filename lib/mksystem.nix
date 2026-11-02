# Initially inspired by Mitchell Hashimoto's nixos-config:
# https://github.com/mitchellh/nixos-config/blob/3218eb631958f22bde7e312c117a8cfb3afa9357/lib/mksystem.nix
#
# This function creates a nix-darwin or NixOS system for one Host table
# entry. Home Manager is standalone; see mkhome.nix.
{ inputs }:

name:
{
  system,
  platform,
  user,
}:

let
  inherit (inputs.nixpkgs) lib;
  nixpkgsSettings = import ./nixpkgs.nix { inherit inputs; };
  isDarwin = platform == "darwin";

  hostSystem = ../hosts/${name}/system.nix;

  # NixOS vs nix-darwin functions
  systemFunc = if isDarwin then inputs.darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;

  hostIdentity = {
    clb.host = { inherit name user; };
  };
in
systemFunc {
  inherit system;
  specialArgs = { inherit inputs; };

  modules = [
    # Overlays and nixpkgs config from lib/nixpkgs.nix, shared with
    # mkhome.nix.
    {
      nixpkgs.overlays = nixpkgsSettings.overlays;
      nixpkgs.config = nixpkgsSettings.config;
    }

    ./host-option.nix
    hostIdentity
  ]
  # Platform aggregator for the host's platform (modules/darwin or
  # modules/nixos), then the optional host override file.
  ++ [ ../modules/${platform} ]
  ++ lib.optional (builtins.pathExists hostSystem) hostSystem;
}
