{
  description = "Clayton's nix configuration";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system. Using "unstable" is an option
    # https://github.com/NixOS/nixpkgs/branches/all?query=nixos-
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Build a custom WSL installer
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # https://github.com/nix-community/home-manager/branches/all?query=release
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs: let
    mkSystem = import ./lib/mksystem.nix {
      inherit nixpkgs inputs;
    };
  in {
    # nixosConfigurations."vm-aarch64" = mkSystem "vm-aarch64" {
    #   system = "aarch64-linux";
    #   user   = "clburlison";
    # };

    # nixosConfigurations."vm-intel" = mkSystem "vm-intel" rec {
    #   system = "x86_64-linux";
    #   user   = "clburlison";
    # };

    nixosConfigurations."wsl" = mkSystem "wsl" {
      system = "x86_64-linux";
      user   = "clburlison";
      wsl    = true;
    };

    darwinConfigurations."vm-clayton-mac" = mkSystem "darwin-default" {
      system = "aarch64-darwin";
      user   = "clburlison";
      darwin = true;
    };

    darwinConfigurations."clayton-1AXM" = mkSystem "darwin-default" {
      system = "aarch64-darwin";
      user   = "clayton";
      darwin = true;
    };

    darwinConfigurations."clayton-7HYM" = mkSystem "darwin-default" {
      system = "aarch64-darwin";
      user   = "clayton";
      darwin = true;
    };
  };
}
