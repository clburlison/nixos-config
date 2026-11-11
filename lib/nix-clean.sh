#!/bin/sh
# Prune every Nix profile to its last two generations, collect garbage, then
# deduplicate the store. Run as root. Used by `task clean` and the weekly
# nix-clean job (modules/darwin/nix.nix, modules/nixos/default.nix).
set -u

export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

for dir in \
  /nix/var/nix/profiles \
  /root/.local/state/nix/profiles \
  /var/root/.local/state/nix/profiles \
  /home/*/.local/state/nix/profiles \
  /Users/*/.local/state/nix/profiles; do
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 3 -type l -name '*-[0-9]*-link' |
    sed -E 's/-[0-9]+-link$//' | sort -u |
    while IFS= read -r profile; do
      nix-env --profile "$profile" --delete-generations +2 ||
        echo "nix-clean: failed to prune $profile" >&2
    done
done

nix-collect-garbage
nix-store --optimise
