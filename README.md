# nixOS Configuration

My nix and dotfile configurations.

## Usage

<details><summary>Installation macOS</summary>
<p>

1. Open `Terminal.app`
2. Run `git` to trigger the Apple command line tools installation.

   ```sh
   git
   ```

3. Clone this repo

   ```sh
   mkdir -p $HOME/dev/me
   cd $HOME/dev/me
   git clone https://github.com/clburlison/nixos-config
   cd nixos-config
   ```

4. Install `task`

   ```sh
   sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ./
   ```

5. Install Nix

   https://docs.determinate.systems/

   ```sh
   ./task install
   ```

6. Run nix switch to configure the system

   ```sh
   ./task switch
   ```

Future runs can use the global install of `task`.

<details><summary>Extra</summary>
<p>

Set theme for Apple Terminal

```sh
open /users/clburlison/dotfiles/Solarized\ Dark.terminal
# Open Terminal preferences > Profile > Set Solarized Dark as default
```

Change shell to `fish`

- Open System Settings → Users & Groups → Right click on user and change shell or
- `chsh -s /run/current-system/sw/bin/fish`

</p>
</details>

</p>
</details>

<details><summary>Installation Windows Subsystem for Linux (WSL)</summary>
<p>

Coming soon...

</p>
</details>

</p>
</details>

<details><summary>Installation Linux</summary>
<p>

Coming soon...

</p>
</details>

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
- [Mitchell Hashimoto nix](https://github.com/mitchellh/nixos-config)
