# https://nix-community.github.io/home-manager/options.xhtml

# { isWSL, inputs, pkgsUnstable, ... }:
{ isWSL, inputs, ... }:

{ config, lib, pkgs, ... }:

let
  # sources = import ../../nix/sources.nix;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  dotfiles = "${config.home.homeDirectory}/dev/me/nixos-config/dotfiles";

in {
  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.05";

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. I'll investigate using per-project
  # flakes sourced with direnv and nix-shell in the future.
  home.packages = [
    pkgs.bun
    pkgs.curl
    pkgs.fzf
    pkgs.gh
    pkgs.git
    pkgs.git-lfs
    pkgs.go
    pkgs.htop
    pkgs.jq
    pkgs.kubectl
    pkgs.kubeswitch
    pkgs.lazygit
    pkgs.mysql84
    pkgs.neovim
    pkgs.nerd-fonts.caskaydia-mono
    pkgs.nerd-fonts.go-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.meslo-lg
    pkgs.nodejs_22 # Node is required for Copilot.vim
    pkgs.oh-my-posh
    pkgs.python312
    pkgs.ripgrep
    pkgs.ripgrep-all
    pkgs.rustc
    pkgs.rustup
    # pkgs.rust-bin.nightly."2025-07-27".default
    # pkgs.terraform # this is a slow install with nix?
    pkgs.tree
    pkgs.tree-sitter
    pkgs.uv
    pkgs.vim
    pkgs.wget
    pkgs.zellij
    pkgs.zoxide
    pkgs.zsh-history-substring-search
    pkgs.zsh-vi-mode
  ] ++ (lib.optionals isDarwin [
    # Install on macOS only
    pkgs._1password-cli
    # pkgs.azure-cli
    pkgs.ffmpeg_7-full
    pkgs.hugo
    pkgs.ngrok
    pkgs.terraform-docs
    pkgs.tflint
    pkgs.yt-dlp # youtube-dl replacement
  ]) ++ (lib.optionals (isLinux && !isWSL) [
    # Install on Linux only
    pkgs.chromium
    pkgs.firefox
  ]);

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less -FirSwX";
    # Set default blocksize for ls, df, du
    BLOCKSIZE = "1k";
  };

  home.file = {
    ".aliases".source = ./dotfiles/aliases;
    ".config/lazygit".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/lazygit";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/nvim";
    ".config/ohmyposh".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/ohmyposh";
    ".config/zellij".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/zellij";
    ".config/fish/aliases.fish".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/fish/aliases.fish";
    ".config/fish/functions".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/fish/functions";
    ".config/fish/omp-vimmode.fish".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/fish/omp-vimmode.fish";
    ".config/fish/path.fish".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/fish/path.fish";
    ".editorconfig".source = ./dotfiles/editorconfig;
    ".functions".source = ./dotfiles/functions;
    ".git-commit-template.txt".source = ./dotfiles/git-commit-template.txt;
    ".gitconfig".source = ./dotfiles/gitconfig;
    ".gitignore".source = ./dotfiles/gitignore;
    ".inputrc".source = ./dotfiles/inputrc;
    ".kube/switch-config.yaml".source = ./dotfiles/kube/switch-config.yaml;
    ".kube/switch-state/switch-state.alias".source = ./dotfiles/kube/switch-state/switch.alias;
    ".path".source = ./dotfiles/path;
  };

  # Disable Safe Mode for Zen/Firefox. I use the hyper key for launch and this causes issues.
  # https://github.com/zen-browser/desktop/issues/6538
  launchd.agents.MOZ_DISABLE_SAFE_MODE = {
    enable = true;
    config = {
      Label = "com.clburlison.MOZ_DISABLE_SAFE_MODE";
      ProgramArguments = [ "/bin/launchctl" "setenv" "MOZ_DISABLE_SAFE_MODE_KEY" "1" ];
      RunAtLoad = true;
      ServiceIPC = false;
    };
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = !isDarwin;

  programs.bash = {
    enable = true;
    shellOptions = [];
    historyControl = [ "ignoredups" "ignorespace" ];
    initExtra = builtins.readFile ./dotfiles/bashrc;
  };

  programs.fish = {
    enable = true;
    shellInit = ''
        set fish_greeting ""

        source ~/.config/fish/aliases.fish
        source ~/.config/fish/functions/lazygit.fish
        source ~/.config/fish/path.fish

        # Enable vim mode
        set -g fish_key_bindings fish_vi_key_bindings

        bind ctrl-y accept-autosuggestion
        bind ctrl-p history-search-backward
        bind ctrl-n history-search-forward

        bind --mode insert ctrl-y accept-autosuggestion
        bind --mode insert ctrl-p history-search-backward
        bind --mode insert ctrl-n history-search-forward

        # bun
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
    '';
  };

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    # initExtra = builtins.readFile ./dotfiles/zshrc;
    initContent = ''
      # Load the shell dotfiles, and then some:
      # * ~/.path can be used to extend `$PATH`.
      # * ~/.extra can be used for other settings you don’t want to commit.
      for file in ~/.{path,aliases,functions,extra}; do
          [ -r "$file" ] && [ -f "$file" ] && source "$file";
      done;
      unset file;

      # bun
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      fpath+=(${pkgs.bun}/share/zsh/site-functions)

      # kubeswitch
      source <(switcher init zsh)
      source <(switch completion zsh)

      # HACK: https://github.com/zellij-org/zellij/issues/1933#issuecomment-2274464004
      source <( zellij setup --generate-completion zsh | sed -Ee 's/^(_(zellij) ).*/compdef \1\2/' )
      eval "$(zoxide init zsh)"
      # source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      # zvm_after_init_commands+=("bindkey '^y' autosuggest-accept")
      bindkey '^y' autosuggest-accept

      # Better zsh history
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
    '';
  };

  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    configFile = "$HOME/.config/ohmyposh/clburlison.toml";
  };

  programs.git = {
    enable = true;
  };

  programs.go = {
    enable = true;
    env = {
        GOPATH = [ "dev/go" ];
    };
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
