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
