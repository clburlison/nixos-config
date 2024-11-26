{
  description = "Clayton's nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    # platform this configuration will be used on.
    system = "aarch64-darwin";

    # Import pkgs for the current system
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Import apps.nix with pkgs and the system type
    apps = import ./apps/darwin.nix { inherit pkgs; };

    configuration = { pkgs, ... }: {
      # Apply darwinPackages
      environment.systemPackages = apps.darwinPackages;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#clayton-1AXM
    darwinConfigurations."clayton-1AXM" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
    darwinConfigurations."clayton-7HYM" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}
