# nixpkgs settings shared by every builder: overlays and config.
# Takes only the flake inputs; returns plain data.
{ inputs }:

{
  # Overlays for the packages in which we want the latest version
  overlays = [
    (
      final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        bun = unstable.bun;
        claude-code = unstable.claude-code;
        claude-mem = final.callPackage ../packages/claude-mem.nix { };
        cliproxyapi = final.callPackage ../packages/cliproxyapi.nix { inherit (unstable) cliproxyapi; };
        cpa-usage-keeper = final.callPackage ../packages/cpa-usage-keeper.nix { };
        herdr-agent-icons = final.callPackage ../packages/herdr-agent-icons.nix { };
        codex = unstable.codex;
        gemini-cli = unstable.gemini-cli;
        herdr = unstable.herdr;
        lazygit = unstable.lazygit;
        nerd-fonts = unstable.nerd-fonts;
        linear-cli = final.callPackage ../packages/linear-cli.nix { };
        ntn = final.callPackage ../packages/ntn.nix { };
        opencode = final.callPackage ../packages/opencode.nix {
          opencode-v2 = inputs.opencode-v2;
        };
        openusage = unstable.openusage;
        t3 = final.callPackage ../packages/t3.nix { };
        tree-sitter = unstable.tree-sitter;
        uv = unstable.uv;
        worktrunk = unstable.worktrunk;
        zellij = unstable.zellij;
        zoxide = unstable.zoxide;
      }
    )
  ];

  # Allow unfree packages.
  config.allowUnfree = true;
}
