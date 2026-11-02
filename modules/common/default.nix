# https://nix-community.github.io/home-manager/options.xhtml
# Home Manager configuration shared by every host.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # sources = import ../../nix/sources.nix;
  dotfiles = "${config.home.homeDirectory}/dev/me/nixos-config/dotfiles";
  isLinux = pkgs.stdenv.isLinux;
  mkLink = config.lib.file.mkOutOfStoreSymlink;

in
{
  _class = "homeManager";

  imports = [
    ./darwin.nix
    ./programs/zsh.nix
    ./programs/fish.nix
    ./programs/worktrunk.nix
    ./programs/ssh.nix
    ./programs/claude-mem.nix
    ./programs/uv.nix
    ./programs/herdr.nix
    ./programs/agent-git.nix
    ./programs/agent-skills.nix
    ./programs/homebrew.nix
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.05";

  # Avoid generating the Home Manager option manual, which triggers a
  # Determinate Nix store-context warning.
  manual.manpages.enable = false;

  xdg.enable = true;

  home.username = config.clb.host.user;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${config.clb.host.user}" else "/home/${config.clb.host.user}";

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. I'll investigate using per-project
  # flakes sourced with direnv and nix-shell in the future.
  # Ordered after module-provided packages, as before the module split, so
  # home-path keeps the same input order.
  home.packages = lib.mkOrder 1050 (
    [
      # pkgs.python314 # switch to `uv` for python version management
      # pkgs.terraform # this is a slow install with nix?
      pkgs.azure-cli
      pkgs.bun
      pkgs.curl
      pkgs.fzf
      pkgs.gh
      pkgs.git-lfs
      pkgs.git-open
      pkgs.go-task
      pkgs.htop
      pkgs.jq
      pkgs.kubectl
      pkgs.lazygit
      pkgs.linear-cli
      pkgs.mysql84
      pkgs.neovim
      pkgs.nerd-fonts.caskaydia-mono
      pkgs.nerd-fonts.go-mono
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.meslo-lg
      pkgs.nixfmt
      pkgs.nodejs_24
      pkgs.ntn
      pkgs.opencode
      pkgs.ripgrep
      pkgs.ripgrep-all
      pkgs.rustc
      pkgs.rustup
      pkgs.t3
      pkgs.tree
      pkgs.tree-sitter
      pkgs.wget
      pkgs.worktrunk
      pkgs.zsh-history-substring-search
      pkgs.zsh-vi-mode
    ]
    ++ (lib.optionals isLinux [
      # Install on Linux only
      pkgs.chromium
      pkgs.firefox
    ])
  );

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less -FirSwX";
    # Set default blocksize for ls, df, du
    BLOCKSIZE = "1k";
    GIT_LFS_SKIP_SMUDGE = "1";
    # Remove duplicates and commands that start with space
    HISTCONTROL = "ignoreboth";
    # oh-my-posh fallback when the per-session config cache is lost (e.g.
    # after a switch); otherwise running shells render the default theme.
    POSH_CONFIG = "${config.home.homeDirectory}/.config/ohmyposh/clburlison.toml";
    # Hide Claude Code's "How is Claude doing this session?" survey.
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
  };

  home.file = {
    ".aliases".source = ../../dotfiles/aliases;
    ".claude/CLAUDE.md".source = mkLink "${dotfiles}/claude/CLAUDE.md";
    ".claude/keybindings.json".source = mkLink "${dotfiles}/claude/keybindings.json";
    ".claude/mods".source = mkLink "${dotfiles}/claude/mods";
    ".config/fish/aliases.fish".source = mkLink "${dotfiles}/config/fish/aliases.fish";
    ".config/fish/conf.d".source = mkLink "${dotfiles}/config/fish/config.d";
    ".config/fish/functions".source = mkLink "${dotfiles}/config/fish/functions";
    ".config/fish/omp-vimmode.fish".source = mkLink "${dotfiles}/config/fish/omp-vimmode.fish";
    ".config/fish/path.fish".source = mkLink "${dotfiles}/config/fish/path.fish";
    ".config/fish/completions/ntn.fish".source = pkgs.runCommand "ntn-fish-completions" { } ''
      ${pkgs.ntn}/bin/ntn completions fish > $out
    '';
    ".config/ghostty/config".source = mkLink "${dotfiles}/config/ghostty/config";
    ".config/karabiner/karabiner.json".source = mkLink "${dotfiles}/config/karabiner/karabiner.json";
    ".config/lazygit".source = mkLink "${dotfiles}/config/lazygit";
    ".config/nvim".source = mkLink "${dotfiles}/config/nvim";
    ".config/ohmyposh".source = mkLink "${dotfiles}/config/ohmyposh";
    ".editorconfig".source = ../../dotfiles/editorconfig;
    ".functions".source = ../../dotfiles/functions;
    ".git-commit-template.txt".source = ../../dotfiles/git-commit-template.txt;
    ".gitconfig".source = ../../dotfiles/gitconfig;
    ".gitignore".source = ../../dotfiles/gitignore;
    ".inputrc".source = ../../dotfiles/inputrc;
    ".kube/switch-config.yaml".source = ../../dotfiles/kube/switch-config.yaml;
    ".kube/switch-state/switch-state.alias".source = ../../dotfiles/kube/switch-state/switch.alias;
    ".path".source = ../../dotfiles/path;
    ".ssh/config".source = mkLink "${dotfiles}/ssh/config";
    ".ssh/hosts".source = mkLink "${dotfiles}/ssh/hosts";
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

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    # Run after Home Manager's shell integrations, as before the module split.
    initExtra = lib.mkOrder 1050 (builtins.readFile ../../dotfiles/bashrc);
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
    silent = true;
    config.whitelist.prefix = [ "${config.home.homeDirectory}/dev/worktrees/" ];
  };

  programs.git = {
    enable = true;
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

  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    configFile = "$HOME/.config/ohmyposh/clburlison.toml";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf isLinux {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
