# Home Manager configuration for workstation hosts (the default profile).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/dev/me/nixos-config/dotfiles";
  isLinux = pkgs.stdenv.isLinux;
  mkLink = config.lib.file.mkOutOfStoreSymlink;
in
{
  _class = "homeManager";

  imports = [
    ./darwin.nix
    ./programs/zsh.nix
    ./programs/worktrunk.nix
    ./programs/claude-mem.nix
    ./programs/cliproxyapi.nix
    ./programs/obot.nix
    ./programs/uv.nix
    ./programs/op-agents.nix
    ./programs/antigravity.nix
    ./programs/t3.nix
    ./programs/agent-git.nix
    ./programs/agent-skills.nix
    ./programs/homebrew.nix
  ];

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed on workstations. I'll investigate using
  # per-project flakes sourced with direnv and nix-shell in the future.
  home.packages = [
    # pkgs.python314 # switch to `uv` for python version management
    # pkgs.terraform # this is a slow install with nix?
    pkgs.azure-cli
    pkgs.bun
    pkgs.gh
    pkgs.git-lfs
    pkgs.git-open
    pkgs.kubectl
    pkgs.lazygit
    pkgs.linear-cli
    pkgs.mysql84
    pkgs.nerd-fonts.caskaydia-mono
    pkgs.nerd-fonts.go-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.meslo-lg
    pkgs.nixfmt
    pkgs.nodejs_24
    pkgs.ntn
    pkgs.ripgrep-all
    pkgs.rustc
    pkgs.rustup
    pkgs.t3
    pkgs.tree-sitter
    pkgs.worktrunk
    pkgs.zsh-history-substring-search
    pkgs.zsh-vi-mode
  ]
  ++ (lib.optionals isLinux [
    # Install on Linux workstations only
    pkgs.chromium
    pkgs.firefox
  ]);

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionVariables = {
    GIT_LFS_SKIP_SMUDGE = "1";
    # Hide Claude Code's "How is Claude doing this session?" survey.
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
  };

  home.file = {
    ".claude/CLAUDE.md".source = mkLink "${dotfiles}/claude/CLAUDE.md";
    ".claude/keybindings.json".source = mkLink "${dotfiles}/claude/keybindings.json";
    ".claude/mods".source = mkLink "${dotfiles}/claude/mods";
    ".codex/AGENTS.md".source = mkLink "${dotfiles}/AGENTS.md";
    ".config/fish/completions/ntn.fish".source = pkgs.runCommand "ntn-fish-completions" { } ''
      ${pkgs.ntn}/bin/ntn completions fish > $out
    '';
    ".config/ghostty/config".source = mkLink "${dotfiles}/config/ghostty/config";
    ".config/karabiner/karabiner.json".source = mkLink "${dotfiles}/config/karabiner/karabiner.json";
    ".config/lazygit".source = mkLink "${dotfiles}/config/lazygit";
    ".gemini/GEMINI.md".source = mkLink "${dotfiles}/gemini/GEMINI.md";
    ".kube/switch-config.yaml".source = ../../dotfiles/kube/switch-config.yaml;
    ".kube/switch-state/switch-state.alias".source = ../../dotfiles/kube/switch-state/switch.alias;
    ".t3/userdata/keybindings.json" = {
      source = mkLink "${dotfiles}/t3code/keybindings.json";
      force = true;
    };
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  # Local Claude Code mods, loaded live from the dotfiles symlink.
  programs.claude-code.plugins = [
    "${config.home.homeDirectory}/.claude/mods/context-status"
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
    silent = true;
    config.whitelist.prefix = [ "${config.home.homeDirectory}/dev/worktrees/" ];
    # `use mise` in an .envrc loads mise.toml tools, like `use flake` for Nix.
    # `direnv allow` is the trust gate, so mise trusts the .envrc directory.
    stdlib = ''
      use_mise() {
        watch_file mise.toml .mise.toml mise.lock .tool-versions
        MISE_TRUSTED_CONFIG_PATHS="$PWD" direnv_load mise direnv exec
      }
    '';
  };

  programs.go = {
    enable = true;
    env = {
      GOPATH = [ "${config.home.homeDirectory}/dev/go" ];
    };
  };

  programs.kubeswitch = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    commandName = "kswitch";
  };

  programs.mise = {
    enable = true;
    # Repos load tools through direnv (`use flake`), so never activate mise in
    # the shell. The CLI stays available for explicit `mise install`/`mise x`.
    # (`ignored_config_paths` only matches exact files, not directories.)
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    enableNushellIntegration = false;
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf isLinux {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
