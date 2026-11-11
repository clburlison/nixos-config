# macOS host

Install Nix and apply this configuration on a Mac (nix-darwin plus standalone
Home Manager). The host must be in the host table in `flake.nix`, named after
the Mac's hostname. Where it fits in the whole setup:
[docs/README.md](README.md).

## 1. Install

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

5. Install Nix (<https://docs.determinate.systems/>)

   ```sh
   ./task install
   ```

6. (Optional) Set macOS computer name

   ```sh
   ./task rename-mac
   ```

7. Configure the system, then bootstrap Home Manager

   ```sh
   ./task system
   nix run home-manager/release-26.05 -- switch --flake ".#$USER@$(hostname)"
   ```

   The first Home Manager run installs `home-manager` into `~/.nix-profile`.
   After that, `task switch` applies both, and the global `task` replaces
   `./task`.

## 2. Secrets and signing

1. Set the op-agents token: "Mac" in [op-agents.md](op-agents.md#mac).
2. Check agent-git: [agent-git.md](agent-git.md#4-apply-and-set-the-token).
3. Switch the clone to SSH and drop the bootstrap `task`:

   ```sh
   git remote set-url origin git@github.com:clburlison/nixos-config.git
   rm ./task
   ```

Claude Code and Codex now route through the CLIProxyAPI hub on srv-devbox,
with no further step ([srv-devbox.md](srv-devbox.md#clients)).

## 3. Shared memory

Give the host its claude-mem server key and approve the Codex hooks:
[claude-mem.md](claude-mem.md#hosted-server).

## Extras

Set theme for Apple Terminal

```sh
open ~/dev/me/nixos-config/dotfiles/Solarized\ Dark.terminal
# Open Terminal preferences > Profile > Set Solarized Dark as default
```

Change shell to `fish`

- Open System Settings → Users & Groups → Right click on user and change shell or
- `chsh -s /run/current-system/sw/bin/fish`

Work email for repositories under a directory: [gitconfig.md](gitconfig.md).
