{
  description = "Clayton's nix configuration";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system. Using "unstable" is an option
    # https://github.com/NixOS/nixpkgs/branches/all?query=nixos-
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Build a custom WSL installer
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # https://github.com/nix-community/home-manager/branches/all?query=release
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      ...
    }@inputs:
    let

      # Overlays for the packages in which we want the latest version
      overlays = [
        (
          final: prev:
          let
            system = prev.stdenv.hostPlatform.system;
            unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
          in
          {
            bun = unstable.bun;
            lazygit = unstable.lazygit;
            nodejs_22 = unstable.nodejs_22;
            opencode = unstable.opencode;
            tree-sitter = unstable.tree-sitter;
            zellij = unstable.zellij;
            zoxide = unstable.zoxide;
          }
        )
      ];

      mkSystem = import ./lib/mksystem.nix {
        inherit overlays nixpkgs inputs;
      };
    in
    {
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
        user = "clburlison";
        wsl = true;
      };

      darwinConfigurations."vm-clayton-mac" = mkSystem "darwin-default" {
        system = "aarch64-darwin";
        user = "clburlison";
        darwin = true;
      };

      darwinConfigurations."clayton-1AXM" = mkSystem "darwin-default" {
        system = "aarch64-darwin";
        user = "clayton";
        darwin = true;
      };

      darwinConfigurations."clayton-7HYM" = mkSystem "darwin-default" {
        system = "aarch64-darwin";
        user = "clayton";
        darwin = true;
      };
    };
}
