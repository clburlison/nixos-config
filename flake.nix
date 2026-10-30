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
            bun = unstable.bun;
            claude-code = unstable.claude-code;
            claude-mem = final.callPackage ./packages/claude-mem.nix { };
            herdr-agent-icons = final.callPackage ./packages/herdr-agent-icons.nix { };
            codex = unstable.codex;
            gemini-cli = unstable.gemini-cli;
            herdr = unstable.herdr;
            lazygit = unstable.lazygit;
            nerd-fonts = unstable.nerd-fonts;
            linear-cli = final.callPackage ./packages/linear-cli.nix { };
            ntn = final.callPackage ./packages/ntn.nix { };
            opencode = final.callPackage ./packages/opencode.nix {
              opencode-v2 = inputs.opencode-v2;
            };
            openusage = unstable.openusage;
            t3 = final.callPackage ./packages/t3.nix { };
            tree-sitter = unstable.tree-sitter;
            uv = unstable.uv;
            worktrunk = unstable.worktrunk;
            zellij = unstable.zellij;
            zoxide = unstable.zoxide;
          }
        )
      ];

      mkSystem = import ./lib/mksystem.nix {
        inherit overlays nixpkgs inputs;
      };

      mkDarwin =
        hostName:
        mkSystem "darwin-default" {
          inherit hostName;
          system = "aarch64-darwin";
          user = "clburlison";
          darwin = true;
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

      darwinConfigurations = nixpkgs.lib.genAttrs [
        "vm-clayton-mac"
        "clb-work"
        "clb-mini"
      ] mkDarwin;
    };
}
