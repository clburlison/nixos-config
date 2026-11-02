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

    opencode-v2 = {
      url = "github:anomalyco/opencode/v2.0.31";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

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

    cloudflare-security-audit-skills = {
      url = "github:cloudflare/security-audit-skill";
      flake = false;
    };

    herdr-nix = {
      url = "github:kevinpita/herdr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    smart-splits-nvim = {
      url = "github:smart-splits-nvim/smart-splits.nvim";
      flake = false;
    };

    herdr-worktrunk = {
      url = "github:devashish2203/herdr-worktrunk";
      flake = false;
    };

    herdr-bar = {
      url = "github:jeffarese/herdr-bar";
      flake = false;
    };

    herdr-automatic-rename = {
      url = "github:qu8n/herdr-automatic-rename";
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
      inherit (nixpkgs) lib;

      # Host table: the canonical source of host identity.
      hosts = {
        vm-clayton-mac = {
          system = "aarch64-darwin";
          platform = "darwin";
          user = "clburlison";
        };
        clb-work = {
          system = "aarch64-darwin";
          platform = "darwin";
          user = "clburlison";
        };
        clb-mini = {
          system = "aarch64-darwin";
          platform = "darwin";
          user = "clburlison";
        };
      };

      hostsFor = platform: lib.filterAttrs (_: host: host.platform == platform) hosts;

      mkSystem = import ./lib/mksystem.nix { inherit inputs; };
      mkHome = import ./lib/mkhome.nix { inherit inputs; };
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
        platform = "nixos";
        user = "clburlison";
        wsl = true;
      };

      darwinConfigurations = lib.mapAttrs mkSystem (hostsFor "darwin");

      homeConfigurations = lib.mapAttrs' (
        name: host: lib.nameValuePair "${host.user}@${name}" (mkHome name host)
      ) hosts;
    };
}
