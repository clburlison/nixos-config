
# Install Nix

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install

# Nix-darwin

Unsure if I want to use this.

## Install Nix-darwin

mkdir -p ~/.config/nix
cd ~/.config/nix
nix flake init -t nix-darwin
sed -i '' "s/simple/$(scutil --get LocalHostName)/" flake.nix

## install nix-darwin

nix run nix-darwin -- switch --flake ~/.config/nix

## using nix-darwin

darwin-rebuild switch --flake ~/.config/nix

# References

- https://davi.sh/til/nix/nix-macos-setup/
- https://gist.github.com/niranjanaryan/8ab9105bdd66d7e0ebcba72126044964
- https://github.com/DeterminateSystems/nix-installer
- https://github.com/LnL7/nix-darwin
- https://github.com/nix-community/home-manager
- https://zero-to-nix.com/start/install
