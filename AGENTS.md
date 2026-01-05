# Agent Guidelines

## Build & Test

- **Apply Config**: `task switch` (builds and switches system config)
- **Verify/Test**: `task test` (builds and runs `darwin-rebuild check` or `nixos-rebuild test`)
- **Single Test**: System configs are monolithic; run `task test` to validate entire configuration.
- **Linting**:
  - Lua: `stylua` (config in `dotfiles/config/nvim/.stylua.toml`)
  - Nix: Standard `nixfmt` (2 spaces indent)

## Code Style & Conventions

- **Formatting**: Use 2 spaces for indentation in both Nix and Lua files.
- **Lua**: Prefer single quotes (`'`) and avoid call parentheses where possible.
- **Nix**: Follow `flake.nix` patterns; use `mkSystem` wrapper for new hosts.
- **Structure**:
  - `machines/`: Host-specific configurations.
  - `dotfiles/`: User-space application configs (Neovim, Fish, etc.).
  - `lib/`: Shared Nix functions.
- **Changes**: When adding packages, check `overlays` in `flake.nix` first. Use `unstable` only if necessary.
