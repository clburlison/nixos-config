{
  description = "Clayton's nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    # Define systems based on hostname
    system = if builtins.getEnv "HOSTNAME" == "clayton-1AXM" then "aarch64-darwin"
             else if builtins.getEnv "HOSTNAME" == "clayton-7HYM" then "aarch64-darwin"
             else "x86_64-linux";

    # Import pkgs for the current system
    pkgs = import nixpkgs { inherit system; };

    # Import apps.nix with pkgs and the system type
    apps = import ./apps.nix { inherit pkgs system; };

    configuration = { pkgs, ... }: {
      # Enable unfree packages
      nixpkgs.config.allowUnfree = true;

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
