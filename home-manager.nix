{ isWSL, inputs, pkgsUnstable, ... }:

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
    (pkgs.nerdfonts.override { fonts = [ "CascadiaMono" "Go-Mono" "Hack" "Meslo"]; })
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
    pkgs.mysql84
    pkgs.neovim
    pkgs.nodejs_22 # Node is required for Copilot.vim
    pkgs.python312
    pkgs.ripgrep
    pkgs.ripgrep-all
    # pkgs.terraform # this is a slow install with nix?
    pkgs.tmux
    pkgs.tree
    pkgs.tree-sitter
    pkgs.vim
    pkgs.wget
    pkgs.zsh-powerlevel10k
    pkgs.zsh-vi-mode
    pkgsUnstable.bun
    pkgsUnstable.lazygit
    pkgsUnstable.zoxide
  ] ++ (lib.optionals isDarwin [
    # Install on macOS only
    pkgs._1password-cli
    pkgs.azure-cli
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
    ".editorconfig".source = ./dotfiles/editorconfig;
    ".functions".source = ./dotfiles/functions;
    ".git-commit-template.txt".source = ./dotfiles/git-commit-template.txt;
    ".gitconfig".source = ./dotfiles/gitconfig;
    ".gitignore".source = ./dotfiles/gitignore;
    ".inputrc".source = ./dotfiles/inputrc;
    ".kube/switch-config.yaml".source = ./dotfiles/kube/switch-config.yaml;
    ".kube/switch-state/switch-state.alias".source = ./dotfiles/kube/switch-state/switch.alias;
    ".p10k.zsh".source = ./dotfiles/p10k.zsh;
    ".path".source = ./dotfiles/path;
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

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        # "terraform"
        "kubectl"
      ];
      extraConfig = ''
        zstyle ':omz:plugins:nvm' lazy yes
        zstyle ':omz:update' mode disabled

        # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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

        # kubeswitch
        source <(switcher init zsh)
        source <(switch completion zsh)

        eval "$(zoxide init zsh)"
        source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
      '';
    };
    # initExtra = builtins.readFile ./dotfiles/zshrc;
    initExtraFirst = ''
      source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
      # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
      # Initialization code that may require console input (password prompts, [y/n]
      # confirmations, etc.) must go above this block; everything else may go below.
      if [[ -r "''${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
    '';
  };

  # programs.direnv= {
  #   enable = true;

  #   config = {
  #     whitelist = {
  #       prefix= [
  #         "$HOME/code/go/src/github.com/hashicorp"
  #         "$HOME/code/go/src/github.com/mitchellh"
  #       ];

  #       exact = ["$HOME/.envrc"];
  #     };
  #   };
  # };

  programs.git = {
    enable = true;
    userName = "Clayton Burlison";
    userEmail = "git@clburlison.com";
    # signing = {
    #   key = "523D5DC389D273BC";
    #   signByDefault = true;
    # };
    # aliases = {
    #   cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 -r git branch -d";
    #   prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
    #   root = "rev-parse --show-toplevel";
    # };
    # extraConfig = {
    #   branch.autosetuprebase = "always";
    #   color.ui = true;
    #   core.askPass = ""; # needs to be empty to use terminal for ask pass
    #   credential.helper = "store"; # want to make this more secure
    #   github.user = "mitchellh";
    #   push.default = "tracking";
    #   init.defaultBranch = "main";
    # };
  };

  programs.go = {
    enable = true;
    goPath = "dev/go";
    goPrivate = [ "github.com/clburlison" ];
  };

  # programs.tmux = {
  #   enable = true;
  #   terminal = "xterm-256color";
  #   shortcut = "l";
  #   secureSocket = false;
  #   mouse = true;

  #   extraConfig = ''
  #     set -ga terminal-overrides ",*256col*:Tc"

  #     set -g @dracula-show-battery false
  #     set -g @dracula-show-network false
  #     set -g @dracula-show-weather false

  #     bind -n C-k send-keys "clear"\; send-keys "Enter"

  #     run-shell ${sources.tmux-pain-control}/pain_control.tmux
  #     run-shell ${sources.tmux-dracula}/dracula.tmux
  #   '';
  # };

  # services.gpg-agent = {
  #   enable = isLinux;
  #   pinentryPackage = pkgs.pinentry-tty;

  #   # cache the keys forever so we don't get asked for a password
  #   defaultCacheTtl = 31536000;
  #   maxCacheTtl = 31536000;
  # };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
