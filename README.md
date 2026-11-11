# nixOS Configuration

My Nix and dotfile configurations for macOS (nix-darwin) and NixOS hosts, with a standalone Home Manager user environment shared across them. Terms like **host**, **platform aggregator**, and **host override file** are defined in [CONTEXT.md](CONTEXT.md).

## Setup

New machine or rebuilding from scratch: follow [docs/README.md](docs/README.md).
It is the order of operations across 1Password, srv-devbox (the NixOS hub)
and each Mac, linking into the guides in `docs/`.

## Tasks

| Task | What it does |
| --- | --- |
| `task home` | `home-manager switch` for `$USER@$NIXNAME`, no sudo |
| `task system` | `darwin-rebuild switch` / `nixos-rebuild switch` (sudo) |
| `task switch` | `system`, then `home` |
| `task test-home` | `home-manager build`, no activation |
| `task test-system` | `darwin-rebuild check` / `nixos-rebuild test` (sudo) |
| `task test` | `test-system`, then `test-home` |

`NIXNAME` defaults to `hostname`.

## Where to make common changes

These are the files that changed most often over the past year, mapped to where they live now.

| I want to... | Edit | Apply with |
| --- | --- | --- |
| Add or remove a CLI package (every host) | `modules/common/default.nix` (`home.packages`) | `task home` |
| Add a macOS-only CLI package | `modules/common/darwin.nix` | `task home` |
| Add or remove a macOS app (cask / App Store) | `modules/common/programs/homebrew.nix` | `task home` |
| Change macOS settings, dock, keyboard | `modules/darwin/defaults.nix` | `task system` |
| Pull a package from `nixpkgs-unstable` | `lib/nixpkgs.nix` (overlays) | `task home` |
| Add a flake input or bump a pinned version | `flake.nix`, then `task update -- <input>` | both |
| Turn AI agent skills on or off | `modules/common/programs/agent-skills.nix` | `task home` |
| Ship a pushed clb-skills change | nothing here (`clb-skills` input is pinned in `flake.lock`) | `task skills` (`task home` alone keeps the old pin) |
| Change herdr, worktrunk, claude-mem, agent-git, fish, zsh | `modules/common/programs/<name>.nix` | `task home` |
| Link a new dotfile into `$HOME` | `modules/common/default.nix` (`home.file`) | `task home` |
| Edit Neovim, fish functions, Ghostty, SSH, Claude config | `dotfiles/config/...`, `dotfiles/ssh/`, `dotfiles/claude/` | nothing (live symlink) |
| Edit `gitconfig`, `aliases`, `path`, `functions` | `dotfiles/<name>` | `task home` (copied into the store) |
| Something for one host only | `hosts/<name>/home.nix` or `hosts/<name>/system.nix` | `task home` / `task system` |
| Add a host | host table in `flake.nix`, plus optional `hosts/<name>/` | `task switch` on that host |

Dotfiles linked with `mkOutOfStoreSymlink` in `home.file` are live: edits show up immediately. Dotfiles linked with a plain path are copied into the Nix store and need `task home`.

## Layout

**Nix configuration** (evaluated by the flake)

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs and the **host table** (every host's name, system, platform, user) |
| `lib/` | Builders (`mksystem.nix` for nix-darwin/NixOS, `mkhome.nix` for Home Manager) and shared data (`nixpkgs.nix` overlays, `host-option.nix`, `ssh-keys.nix`) |
| `modules/common/` | Home Manager config every host gets. `darwin.nix` holds the macOS-only bits; `programs/` holds one file per larger program |
| `modules/darwin/` | Darwin **platform aggregator**: system config every Mac gets (Nix daemon, users, defaults, Homebrew install, shells) |
| `modules/nixos/` | NixOS **platform aggregator**: system config every NixOS host gets (Determinate Nix, user, SSH, firewall, locale) |
| `hosts/<name>/` | **Host override files**: `system.nix`, `home.nix`, and anything only that host needs (e.g. `srv-devbox` hardware config and services) |

**Supporting files** (not Nix modules)

| Path | Purpose |
| --- | --- |
| `dotfiles/` | App configs (Neovim, fish, Ghostty, git, SSH, Claude, ...) linked into `$HOME` by `modules/common` |
| `packages/` | Custom package derivations (claude-mem, linear-cli, ntn, opencode, t3, ...) and their update scripts (`packages/Taskfile.yml`) |
| `patches/` | Patches applied to upstream packages |
| `plugins/` | herdr plugins (layouts) |
| `docs/` | Setup guide (`docs/README.md`), per-topic guides, and research notes |
| `Taskfile.yml` | `task` entry points (below) |

## How a host is built

Each host in the flake's host table produces two independent outputs:

```text
darwinConfigurations.<host> / nixosConfigurations.<host>     (task system, sudo)
  lib/mksystem.nix
    -> modules/<platform>/                           (platform aggregator)
    -> hosts/<host>/system.nix                        (if present)

homeConfigurations."<user>@<host>"                            (task home, no sudo)
  lib/mkhome.nix
    -> modules/common/
    -> hosts/<host>/home.nix                          (if present)
```

Rules: the host override file layers on top of the platform aggregator, no module compares host names, and `modules/common` branches only on `pkgs.stdenv` (Darwin vs Linux).

### Sharing config between some hosts

There is no role layer. Config for one host goes in `hosts/<name>/`. If a second host later needs the same config (e.g. a media server pair), pull it into a shared module and import it from each host's `system.nix` / `home.nix`.

## AI agents

Claude Code and Codex route through the CLIProxyAPI hub on srv-devbox, and
Claude Code, Codex, and OpenCode share [Nix-managed claude-mem](docs/claude-mem.md)
backed by the hosted server there. See [docs/README.md](docs/README.md).

## Other

### Nix taking up too much space?

Every host runs `lib/nix-clean.sh` weekly (Sundays 3am): it keeps the last
two generations of each profile, collects garbage, then optimises the store.
Run it now with `task clean`. More background:
<https://nixos.wiki/wiki/Storage_optimization>.

### Uninstall

If you have had enough of nix...

```sh
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller
/nix/nix-installer uninstall
```

## References

- https://davi.sh/til/nix/nix-macos-setup/
- https://gist.github.com/niranjanaryan/8ab9105bdd66d7e0ebcba72126044964
- https://github.com/DeterminateSystems/nix-installer
- https://github.com/LnL7/nix-darwin
- https://github.com/nix-community/home-manager
- https://zero-to-nix.com/start/install
- https://github.com/zhaofengli/attic (self hosted caching)
- https://github.com/jacobbednarz/j
- [Mitchell Hashimoto nix](https://github.com/mitchellh/nixos-config)
