{
  description = "Clayton's nix configuration";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system. Using "unstable" is an option
    # https://github.com/NixOS/nixpkgs/branches/all?query=nixos-
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Build a custom WSL installer
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # https://github.com/nix-community/home-manager/branches/all?query=release
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Install and manage Homebrew itself through nix-darwin.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    agent-skills.url = "github:Kyure-A/agent-skills-nix";

    matt-pocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    notion-skills = {
      url = "github:makenotion/skills";
      flake = false;
    };

    linear-cli-skills = {
      url = "github:schpet/linear-cli";
      flake = false;
    };
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
            unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          in
          {
            antigravity-cli = unstable.antigravity-cli;
            bun = unstable.bun;
            claude-code = unstable.claude-code;
            codex = unstable.codex;
            codeburn = final.callPackage ./packages/codeburn.nix { };
            gemini-cli = unstable.gemini-cli;
            herdr = unstable.herdr;
            lazygit = unstable.lazygit;
            linear-cli = final.callPackage ./packages/linear-cli.nix { };
            ntn = final.callPackage ./packages/ntn.nix { };
            opencode = unstable.opencode;
            openusage = unstable.openusage;
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

      darwinConfigurations."clb-work" = mkSystem "darwin-default" {
        system = "aarch64-darwin";
        user = "clburlison";
        darwin = true;
      };

      darwinConfigurations."clb-mini" = mkSystem "darwin-default" {
        system = "aarch64-darwin";
        user = "clburlison";
        darwin = true;
      };
    };
}
