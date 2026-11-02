# Agent Guidelines

## Build & Test

- **Apply Config**: `task switch` (`task system` with sudo, then `task home` for standalone Home Manager)
- **Verify/Test**: `task test` (`task test-system` runs `darwin-rebuild check` or `nixos-rebuild test`; `task test-home` runs `home-manager build`)
- **Agent Verification**: Do not run full system builds or apply/test commands such as `task switch` or `task test`; they can be slow and require interactive `sudo` authentication. Incremental Nix builds for individual packages and hash generation are allowed. Run `nixfmt` for modified Nix files.
- **Linting**:
  - Lua: `stylua` (config in `dotfiles/config/nvim/.stylua.toml`)
  - Nix: Standard `nixfmt` (2 spaces indent)

## Code Style & Conventions

- **Formatting**: Use 2 spaces for indentation in both Nix and Lua files.
- **Lua**: Prefer single quotes (`'`) and avoid call parentheses where possible.
- **Nix**: Follow `flake.nix` patterns; add new hosts to the host table in `flake.nix`.
- **Structure** (terms defined in `CONTEXT.md`):
  - `lib/`: Builders (`mksystem.nix`, `mkhome.nix`) and shared data (`nixpkgs.nix`, `host-option.nix`, `ssh-keys.nix`).
  - `modules/common/`: Home Manager configuration shared by every host; branches only on `pkgs.stdenv`.
  - `modules/darwin/`, `modules/nixos/`: Platform aggregators.
  - `roles/`: Roles; import platform aggregators only.
  - `hosts/<name>/`: Host override files (`system.nix`, `home.nix`).
  - `dotfiles/`: User-space application configs (Neovim, Fish, etc.).
- **Changes**: When adding packages, check `overlays` in `lib/nixpkgs.nix` first. Use `unstable` only if necessary. No module compares host names; put host-specific settings in a host override file.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `clburlison/nixos-config`. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five canonical triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Uses a single-context domain-doc layout. See `docs/agents/domain.md`.
