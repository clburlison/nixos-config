# nixOS Configuration

Nix configurations for my systems. Getting into Nix is not beginner friendly and this repo isn't intended to guide you, however it might be useful for examples. I borrowed many ideas from [Mitchell Hashimoto](https://github.com/mitchellh/nixos-config).

## Usage

1. Install Apple command line tools for Darwin based systems. Open Terminal.app and run `git` to trigger the installation process.
2. Clone this repo

   ```sh
   mkdir -p $HOME/src/clburlison
   cd $HOME/src/clburlison
   git clone https://github.com/clburlison/nixos-config
   cd nixos-config
   ```

3. Install Nix

   ```sh
   make install
   # or
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
     sh -s -- install
   ```

4. Run nix switch to configure the system

   ```sh
   make switch
   ```

## Other

### Nix taking up to much space?

The following article goes into much greater details [https://nixos.wiki/wiki/Storage_optimization](https://nixos.wiki/wiki/Storage_optimization). However if you just want the easy options run the following.

```sh
# optimise can take a really long time
nix-store --optimise
sudo nix-collect-garbage -d
```

### Uninstall

If you have had enough of nix...

```sh
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
/nix/nix-installer uninstall
```

## References

-
- https://davi.sh/til/nix/nix-macos-setup/
- https://gist.github.com/niranjanaryan/8ab9105bdd66d7e0ebcba72126044964
- https://github.com/DeterminateSystems/nix-installer
- https://github.com/LnL7/nix-darwin
- https://github.com/nix-community/home-manager
- https://zero-to-nix.com/start/install
- https://github.com/zhaofengli/attic (self hosted caching)
- https://github.com/jacobbednarz/j
