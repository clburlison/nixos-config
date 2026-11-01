# Nix Configuration

Clayton's Nix configuration for macOS (nix-darwin) and NixOS machines, plus a standalone Home Manager user environment shared across them.

## Language

### Machines

**Host**:
One machine this repository configures, identified by its name (e.g. `clb-work`, `srv-devbox`). Name prefixes like `clb-` and `srv-` are labels only and never select configuration.
_Avoid_: Machine, box, system

**Host table**:
The single list in the flake that names every host with its platform, system architecture, and user; the canonical source of host identity.
_Avoid_: Machine list, host registry

### Layers

**Platform aggregator**:
The entry point for everything every host of one platform (Darwin or NixOS) gets.
_Avoid_: Baseline, base module, platform defaults

**Role**:
A thin layer between a host and its platform aggregator, grouping configuration shared by some but not all hosts of a platform.
_Avoid_: Profile, preset

**Host override file**:
An optional per-host file holding only facts and choices specific to that one host.
_Avoid_: Host config, machine config
