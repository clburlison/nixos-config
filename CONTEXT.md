# Nix Configuration

Clayton's Nix configuration for macOS (nix-darwin) and NixOS machines, plus a standalone Home Manager user environment shared across them.

## Language

### Machines

**Host**:
One machine this repository configures, identified by its name (e.g. `clb-work`, `ai-hub`). Name prefixes like `clb-` are labels only and never select configuration.
_Avoid_: Machine, box, system

**Host table**:
The single list in the flake that names every host with its platform, system architecture, user, and optional profile (default `workstation`); the canonical source of host identity.
_Avoid_: Machine list, host registry

**Profile**:
The role of a host (`workstation` or `server`, defaulting to `workstation`), set in the Host table and exposed as `clb.host.profile`. Selects the profile module under `modules/common/<profile>.nix` and optionally `modules/<platform>/<profile>.nix`.
_Avoid_: Host type, role, flavor

### Layers

**Platform aggregator**:
The entry point for everything every host of one platform (Darwin or NixOS) gets.
_Avoid_: Baseline, base module, platform defaults

**Host override file**:
An optional per-host file holding only facts and choices specific to that one host.
_Avoid_: Host config, machine config
