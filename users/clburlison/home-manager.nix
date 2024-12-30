{ isWSL, inputs, ... }:

{ config, lib, pkgs, ... }:

let
  # sources = import ../../nix/sources.nix;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  # manpager = (pkgs.writeShellScriptBin "manpager" (if isDarwin then ''
  #   sh -c 'col -bx | bat -l man -p'
  #   '' else ''
  #   cat "$1" | col -bx | bat --language man --style plain
  # ''));
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
    pkgs.bun
    pkgs.curl
    pkgs.gh
    pkgs.git
    pkgs.git-lfs
    pkgs.git-town
    pkgs.go
    pkgs.htop
    pkgs.jq
    pkgs.kubectl
    pkgs.kubeswitch
    pkgs.neovim
    pkgs.python312
    pkgs.ripgrep-all
    # pkgs.terraform
    pkgs.tmux
    pkgs.tree
    pkgs.vim
    pkgs.wget
    pkgs.zsh-powerlevel10k
    pkgs.zsh-z
    # Node is required for Copilot.vim
    # pkgs.nodejs
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
    # MANPAGER = "${manpager}/bin/manpager";
    # Set default blocksize for ls, df, du: http://hints.macworld.com/comment.php?mode=view&cid=24491
    BLOCKSIZE = "1k";
  };

  home.file = {
    ".aliases".source = ./dotfiles/aliases;
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
    # ".vimrc".source = ./dotfiles/vimrc; # legacy to delete once fully migrated to nvim
  };
  # } // (if isDarwin then {
  #   "Library/Application Support/jj/config.toml".source = ./jujutsu.toml;
  # } else {});

  # xdg.configFile = {
  #   "i3/config".text = builtins.readFile ./i3;
  #   "rofi/config.rasi".text = builtins.readFile ./rofi;

  #   # tree-sitter parsers
  #   "nvim/parser/proto.so".source = "${pkgs.tree-sitter-proto}/parser";
  #   "nvim/queries/proto/folds.scm".source =
  #     "${sources.tree-sitter-proto}/queries/folds.scm";
  #   "nvim/queries/proto/highlights.scm".source =
  #     "${sources.tree-sitter-proto}/queries/highlights.scm";
  #   "nvim/queries/proto/textobjects.scm".source =
  #     ./textobjects.scm;
  # } // (if isDarwin then {
  #   # Rectangle.app. This has to be imported manually using the app.
  #   "rectangle/RectangleConfig.json".text = builtins.readFile ./RectangleConfig.json;
  # } else {}) // (if isLinux then {
  #   "ghostty/config".text = builtins.readFile ./ghostty.linux;
  #   "jj/config.toml".source = ./jujutsu.toml;
  # } else {});

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
        "z"
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

        # bun completions
        [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

        # bun
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"

        # kubeswitch
        # https://github.com/danielfoehrKn/kubeswitch/blob/master/docs/installation.md
        source <(switcher init zsh)
        source <(switch completion zsh)
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

  # programs.fish = {
  #   enable = true;
  #   interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" ([
  #     "source ${sources.theme-bobthefish}/functions/fish_prompt.fish"
  #     "source ${sources.theme-bobthefish}/functions/fish_right_prompt.fish"
  #     "source ${sources.theme-bobthefish}/functions/fish_title.fish"
  #     (builtins.readFile ./config.fish)
  #     "set -g SHELL ${pkgs.fish}/bin/fish"
  #   ]));

  #   shellAliases = {
  #     ga = "git add";
  #     gc = "git commit";
  #     gco = "git checkout";
  #     gcp = "git cherry-pick";
  #     gdiff = "git diff";
  #     gl = "git prettylog";
  #     gp = "git push";
  #     gs = "git status";
  #     gt = "git tag";

  #     jf = "jj git fetch";
  #     jn = "jj new";
  #     js = "jj st";
  #   } // (if isLinux then {
  #     # Two decades of using a Mac has made this such a strong memory
  #     # that I'm just going to keep it consistent.
  #     pbcopy = "xclip";
  #     pbpaste = "xclip -o";
  #   } else {});

  #   plugins = map (n: {
  #     name = n;
  #     src  = sources.${n};
  #   }) [
  #     "fish-fzf"
  #     "fish-foreign-env"
  #     "theme-bobthefish"
  #   ];
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
    goPath = "src/go";
    goPrivate = [ "github.com/clburlison" ];
  };

  # programs.jujutsu = {
  #   enable = true;

  #   # I don't use "settings" because the path is wrong on macOS at
  #   # the time of writing this.
  # };

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

  # programs.alacritty = {
  #   enable = !isWSL;

  #   settings = {
  #     env.TERM = "xterm-256color";

  #     key_bindings = [
  #       { key = "K"; mods = "Command"; chars = "ClearHistory"; }
  #       { key = "V"; mods = "Command"; action = "Paste"; }
  #       { key = "C"; mods = "Command"; action = "Copy"; }
  #       { key = "Key0"; mods = "Command"; action = "ResetFontSize"; }
  #       { key = "Equals"; mods = "Command"; action = "IncreaseFontSize"; }
  #       { key = "Subtract"; mods = "Command"; action = "DecreaseFontSize"; }
  #     ];
  #   };
  # };

  # programs.kitty = {
  #   enable = !isWSL;
  #   extraConfig = builtins.readFile ./kitty;
  # };

  # programs.i3status = {
  #   enable = isLinux && !isWSL;

  #   general = {
  #     colors = true;
  #     color_good = "#8C9440";
  #     color_bad = "#A54242";
  #     color_degraded = "#DE935F";
  #   };

  #   modules = {
  #     ipv6.enable = false;
  #     "wireless _first_".enable = false;
  #     "battery all".enable = false;
  #   };
  # };

  # programs.neovim = {
  #   enable = true;
  #   package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;

  #   withPython3 = true;

  #   plugins = with pkgs; [
  #     customVim.vim-copilot
  #     customVim.vim-cue
  #     customVim.vim-fish
  #     customVim.vim-glsl
  #     customVim.vim-misc
  #     customVim.vim-pgsql
  #     customVim.vim-tla
  #     customVim.vim-zig
  #     customVim.pigeon
  #     customVim.AfterColors

  #     customVim.vim-nord
  #     customVim.nvim-comment
  #     customVim.nvim-conform
  #     customVim.nvim-dressing
  #     customVim.nvim-gitsigns
  #     customVim.nvim-lualine
  #     customVim.nvim-lspconfig
  #     customVim.nvim-nui
  #     customVim.nvim-plenary # required for telescope
  #     customVim.nvim-telescope
  #     customVim.nvim-treesitter
  #     customVim.nvim-treesitter-playground
  #     customVim.nvim-treesitter-textobjects

  #     vimPlugins.vim-eunuch
  #     vimPlugins.vim-markdown
  #     vimPlugins.vim-nix
  #     vimPlugins.typescript-vim
  #     vimPlugins.nvim-treesitter-parsers.elixir
  #   ] ++ (lib.optionals (!isWSL) [
  #     # This is causing a segfaulting while building our installer
  #     # for WSL so just disable it for now. This is a pretty
  #     # unimportant plugin anyway.
  #     customVim.nvim-web-devicons
  #   ]);

  #   extraConfig = (import ./vim-config.nix) { inherit sources; };
  # };

  # services.gpg-agent = {
  #   enable = isLinux;
  #   pinentryPackage = pkgs.pinentry-tty;

  #   # cache the keys forever so we don't get asked for a password
  #   defaultCacheTtl = 31536000;
  #   maxCacheTtl = 31536000;
  # };

  # xresources.extraConfig = builtins.readFile ./Xresources;

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
