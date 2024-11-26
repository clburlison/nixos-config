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
    # This is not pure Nix, https://blog.kubukoz.com/flakes-first-steps/
    # system = builtins.currentSystem;

    # Import pkgs for the current system
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Dynamically select apps based on the system
    appFile = if pkgs.system == "aarch64-darwin" then ./apps/darwin.nix
               else if pkgs.system == "x86_64-linux" then ./apps/linux.nix
               else if pkgs.system == "x86_64-windows" then ./apps/windows.nix
               else throw "Unsupported system: ${pkgs.system}";
    apps = import appFile { inherit pkgs; };

    configuration = { pkgs, ... }: {
      # Apply darwinPackages
      environment.systemPackages = apps.packages;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = system;
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
