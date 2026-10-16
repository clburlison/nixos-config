{
  lib,
  pkgs,
  ...
}:

let
  claudeMem = pkgs.claude-mem;
  memorySkills = [
    "mem-search"
    "smart-explore"
  ];
in
{
  home.packages = [
    claudeMem
    # Keep config.toml, hooks.json, project trusts, and login state writable.
    # The package adds its inline hooks/MCP through targeted CLI overrides.
    (pkgs.writeShellScriptBin "codex" ''
      exec ${claudeMem}/bin/claude-mem-codex "$@"
    '')
  ];

  programs.claude-code = {
    enable = true;
    plugins = [ claudeMem.pluginRoot ];
    # Leave settings empty: existing mutable settings.json remains its owner.
  };

  xdg.configFile."opencode/plugins/claude-mem.js".source = claudeMem.opencodePlugin;

  # Render the existing JSONC template, preserving comments and other settings.
  # Do not also create opencode.json or use HM's legacy shared-MCP transformer.
  home.file = {
    ".config/opencode/opencode.jsonc".text =
      builtins.replaceStrings
        [ "@claudeMemMcp@" ]
        [
          "${claudeMem}/bin/claude-mem-mcp"
        ]
        (builtins.readFile ../../dotfiles/config/opencode/opencode.jsonc);
  }
  // lib.listToAttrs (
    lib.concatMap (name: [
      {
        name = ".codex/skills/${name}";
        value.source = "${claudeMem.pluginRoot}/skills/${name}";
      }
      {
        name = ".config/opencode/skills/${name}";
        value.source = "${claudeMem.pluginRoot}/skills/${name}";
      }
    ]) memorySkills
  );
}
