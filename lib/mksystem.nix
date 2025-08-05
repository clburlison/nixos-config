# MIT License

# Copyright (c) 2021 Mitchell Hashimoto

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# https://github.com/mitchellh/nixos-config
# This function creates a NixOS system based on our VM setup for a
# particular architecture.
{ overlays, nixpkgs, inputs }:

name:
{
  system,
  user,
  nixConfigUser ? "clburlison",
  darwin ? false,
  wsl ? false
}:

let
  # True if this is a WSL system.
  isWSL = wsl;

  # The config files for this system.
  machineConfig = ../machines/${name}.nix;
  userOSConfig = ../${if darwin then "darwin" else "nixos" }.nix;
  userHMConfig = ../home-manager.nix;

  # NixOS vs nix-darwin functions
  systemFunc = if darwin then inputs.darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  home-manager = if darwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in systemFunc rec {
  inherit system;

  modules = [
    # Apply our overlays. Overlays are keyed by system type so we have
    # to go through and apply our system type. We do this first so
    # the overlays are available globally.
    { nixpkgs.overlays = overlays; }

    # Allow unfree packages.
    { nixpkgs.config.allowUnfree = true; }

    # Bring in WSL if this is a WSL build
    (if isWSL then inputs.nixos-wsl.nixosModules.wsl else {})

    machineConfig
    userOSConfig
    home-manager.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import userHMConfig {
        isWSL = isWSL;
        inputs = inputs;
      };
    }

    # We expose some extra arguments so that our modules can parameterize
    # better based on these values.
    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        isWSL = isWSL;
        inputs = inputs;
      };
    }
  ];
}
