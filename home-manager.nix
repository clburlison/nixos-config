# https://nix-community.github.io/home-manager/options.xhtml

{
  isWSL,
  inputs,
  hostName,
  ...
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # sources = import ../../nix/sources.nix;
  dotfiles = "${config.home.homeDirectory}/dev/me/nixos-config/dotfiles";
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  mkLink = config.lib.file.mkOutOfStoreSymlink;
  mattPocockSkills = {
    # Engineering
    "ask-matt" = false;
    "code-review" = true;
    "codebase-design" = false;
    "diagnosing-bugs" = false;
    "domain-modeling" = false;
    "grill-with-docs" = true;
    "implement" = true;
    "implement-spec" = true;
    "improve-codebase-architecture" = true;
    "pr" = true;
    "prototype" = true;
    "research" = true;
    "retro" = true;
    "setup-matt-pocock-skills" = true;
    "tdd" = true;
    "to-spec" = true;
    "to-tickets" = true;
    "triage" = true;
    "wayfinder" = true;
    "wizard" = false;

    # Productivity
    "grill-me" = true;
    "grilling" = true;
    "handoff" = true;
    "teach" = true;
    "to-questionnaire" = false;
    "wait-what" = true;
    "writing-for-agents" = true;
  };

in
{
  # Backport declarative Python/tool management to the released Home Manager.
  disabledModules = [ "programs/uv.nix" ];

  imports = [
    ./modules/home/claude-mem.nix
    (builtins.fetchurl {
      url = "https://raw.githubusercontent.com/nix-community/home-manager/f53f3267f5d009dd8f99443505e609389d7ff267/modules/programs/uv.nix";
      sha256 = "sha256-rvf6gkV/jDiaxHaeXA25tpQ+2gw2VPQGsRwPjrYI0K4=";
    })
    inputs.agent-skills.homeManagerModules.default
    inputs.herdr-nix.homeModules.default
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.05";

  # Avoid generating the Home Manager option manual, which triggers a
  # Determinate Nix store-context warning.
  manual.manpages.enable = false;

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. I'll investigate using per-project
  # flakes sourced with direnv and nix-shell in the future.
  home.packages = [
    # pkgs.python314 # switch to `uv` for python version management
    # pkgs.terraform # this is a slow install with nix?
    pkgs.azure-cli
    pkgs.bun
    pkgs.codeburn
    pkgs.curl
    pkgs.fzf
    pkgs.gh
    pkgs.git-lfs
    pkgs.git-open
    pkgs.go-task
    pkgs.herdr-agent-icons
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
    pkgs.tree
    pkgs.tree-sitter
    pkgs.wget
    pkgs.worktrunk
    pkgs.zsh-history-substring-search
    pkgs.zsh-vi-mode
  ]
  ++ (lib.optionals isDarwin [
    # Install on macOS only
    # pkgs.ngrok
    # pkgs.yt-dlp # youtube-dl replacement
    pkgs._1password-cli
    pkgs.colima
    pkgs.docker
    pkgs.ffmpeg_7-full
    pkgs.hugo
    pkgs.terraform-docs
    pkgs.tflint
  ])
  ++ (lib.optionals (isLinux && !isWSL) [
    # Install on Linux only
    pkgs.chromium
    pkgs.firefox
  ]);

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
    ".aliases".source = ./dotfiles/aliases;
    ".claude/CLAUDE.md".source = mkLink "${dotfiles}/claude/CLAUDE.md";
    ".claude/keybindings.json".source = mkLink "${dotfiles}/claude/keybindings.json";
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
    ".editorconfig".source = ./dotfiles/editorconfig;
    ".functions".source = ./dotfiles/functions;
    ".git-commit-template.txt".source = ./dotfiles/git-commit-template.txt;
    ".gitconfig".source = ./dotfiles/gitconfig;
    ".gitignore".source = ./dotfiles/gitignore;
    ".inputrc".source = ./dotfiles/inputrc;
    ".kube/switch-config.yaml".source = ./dotfiles/kube/switch-config.yaml;
    ".kube/switch-state/switch-state.alias".source = ./dotfiles/kube/switch-state/switch.alias;
    ".path".source = ./dotfiles/path;
    ".ssh/config".source = mkLink "${dotfiles}/ssh/config";
    ".ssh/hosts".source = mkLink "${dotfiles}/ssh/hosts";
    ".t3/userdata/keybindings.json".source = mkLink "${dotfiles}/t3code/keybindings.json";
    ".t3/userdata/settings.json".source = mkLink "${dotfiles}/t3code/settings.json";
  };

  home.activation.authorizeSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sshDir="${config.home.homeDirectory}/.ssh"
    authorizedKeys="$sshDir/authorized_keys"
    key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC187yAHL5GQ2BzAFFA9b0otVM3asoW0JFg8CPR1m5tU'

    ${pkgs.coreutils}/bin/install -d -m 700 "$sshDir"
    if [ ! -e "$authorizedKeys" ]; then
      ${pkgs.coreutils}/bin/touch "$authorizedKeys"
    fi
    ${pkgs.coreutils}/bin/chmod 600 "$authorizedKeys"
    if ! ${pkgs.gnugrep}/bin/grep -Fqx "$key" "$authorizedKeys"; then
      printf '%s\n' "$key" >> "$authorizedKeys"
    fi
  '';

  # Disable Safe Mode for Zen/Firefox. I use the hyper key for launch and this causes issues.
  # https://github.com/zen-browser/desktop/issues/6538
  launchd.agents.MOZ_DISABLE_SAFE_MODE = {
    enable = true;
    config = {
      Label = "com.clburlison.MOZ_DISABLE_SAFE_MODE";
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "MOZ_DISABLE_SAFE_MODE_KEY"
        "1"
      ];
      RunAtLoad = true;
      ServiceIPC = false;
    };
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    initExtra = builtins.readFile ./dotfiles/bashrc + ''
      # source ${inputs.herdr-automatic-rename}/shell/hook.bash
    '';
  };

  programs.agent-skills = {
    enable = true;
    sources.matt-pocock-engineering = {
      input = "matt-pocock-skills";
      subdir = "skills/engineering";
    };
    sources.matt-pocock-productivity = {
      input = "matt-pocock-skills";
      subdir = "skills/productivity";
    };
    # sources.notion = {
    #   input = "notion-skills";
    #   subdir = "skills";
    # };
    sources.linear-cli = {
      input = "linear-cli-skills";
      subdir = "skills";
    };
    sources.cloudflare-security-audit = {
      input = "cloudflare-security-audit-skills";
      subdir = "skills";
    };
    skills = {
      # Set individual Matt Pocock skills to true as needed.
      enable = lib.attrNames (lib.filterAttrs (_: enabled: enabled) mattPocockSkills);
      enableAll = [
        # "notion"
        "linear-cli"
        "cloudflare-security-audit"
      ];
    };
    targets = {
      agents.enable = true;
      claude.enable = true;
      codex.enable = true;
      opencode.enable = true;
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
    silent = true;
    config.whitelist.prefix = [ "${config.home.homeDirectory}/dev/worktrees/" ];
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting ""

      if status is-interactive
        ${pkgs.worktrunk}/bin/wt config shell init fish | source
        # source ${inputs.herdr-automatic-rename}/shell/hook.fish
      end

      source ~/.config/fish/aliases.fish
      source ~/.config/fish/omp-vimmode.fish
      source ~/.config/fish/path.fish
      # Functions in ~/.config/fish/functions/ are auto-loaded if named properly

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

      # Homebrew
      if test -x /opt/homebrew/bin/brew
          eval "$(/opt/homebrew/bin/brew shellenv fish)"
      end
    '';
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

  programs.herdr = {
    enable = true;
    integrations = [
      "claude"
      "codex"
      "opencode"
    ];
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr;
    extraPackages = [
      pkgs.bash
      pkgs.fzf
      pkgs.jq
      pkgs.python3
      pkgs.worktrunk
    ];
    # plugins.automatic-rename.source = inputs.herdr-automatic-rename;
    plugins.herdr-bar.source =
      let
        version = "0.12.0";
        releases = {
          aarch64-darwin = {
            asset = "macos-aarch64";
            hash = "2b100b2be0456c38a8319ecbf44079b0d9e2e26bd5744593daa2e57aa7524651";
          };
          x86_64-darwin = {
            asset = "macos-x86_64";
            hash = "4d6a3b7ffabbf4c68b09587c5bd75e9b560dfd62ce0288e4512523779031eec5";
          };
          aarch64-linux = {
            asset = "linux-aarch64";
            hash = "df3050ad1d4c9c83691672492838116aa019fa21898818db123c26b09da3f0f0";
          };
          x86_64-linux = {
            asset = "linux-x86_64";
            hash = "59c4e3cbc8831808f2771f0d237250670c41f94c97a0a1bfdcb8b572f9b7beee";
          };
        };
        release = releases.${pkgs.stdenv.hostPlatform.system};
        binary = pkgs.fetchurl {
          url = "https://github.com/jeffarese/herdr-bar/releases/download/v${version}/herdr-bar-${release.asset}";
          sha256 = release.hash;
        };
      in
      pkgs.runCommand "herdr-bar-plugin-${version}" { } ''
        mkdir -p $out/bin
        cp ${inputs.herdr-bar}/herdr-plugin.toml $out/
        cp ${binary} $out/bin/herdr-bar
        chmod +x $out/bin/herdr-bar
      '';
    plugins.layouts.source = ./plugins/herdr-layouts;
    plugins.smart-splits.source = inputs.smart-splits-nvim;
    plugins.worktrunk.source = inputs.herdr-worktrunk;
    machines = lib.optionalAttrs (hostName != "clb-mini") {
      clb-mini = {
        id = "9197ad236dbec9f5a454ec297ab15b4c";
        target = "clb-mini";
      };
    };
    settings = {
      ui.prompt_new_tab_name = false;
      ui.sidebar_start_collapsed = true;
      ui.sidebar_collapsed_mode = "hidden";
      theme = {
        name = "tokyo-night";
        auto_switch = false;
      };
      keys = {
        focus_pane_left = [ ];
        focus_pane_down = [ ];
        focus_pane_up = [ ];
        focus_pane_right = [ ];
        new_worktree = [ ];
        open_worktree = [ ];
        remove_worktree = [ ];
      };
      keys.command = [
        {
          key = [
            "prefix+k"
            "cmd+k"
          ];
          type = "plugin_action";
          command = "herdr-bar.open";
          description = "command bar";
        }
        {
          key = "prefix+l";
          type = "plugin_action";
          command = "layouts.open";
          description = "layouts: open picker";
        }
        {
          key = "prefix+shift+g";
          type = "plugin_action";
          command = "worktrunk.open";
          description = "worktree: switch/create (worktrunk)";
        }
        {
          key = "prefix+shift+b";
          type = "plugin_action";
          command = "worktrunk.remove";
          description = "worktree: remove (worktrunk)";
        }
        {
          key = "ctrl+h";
          type = "plugin_action";
          command = "smart-splits.nvim.left";
          description = "navigate left (vim/herdr)";
        }
        {
          key = "ctrl+j";
          type = "plugin_action";
          command = "smart-splits.nvim.down";
          description = "navigate down (vim/herdr)";
        }
        {
          key = "ctrl+k";
          type = "plugin_action";
          command = "smart-splits.nvim.up";
          description = "navigate up (vim/herdr)";
        }
        {
          key = "ctrl+l";
          type = "plugin_action";
          command = "smart-splits.nvim.right";
          description = "navigate right (vim/herdr)";
        }
      ];
    };
  };

  # Replace the registries that were previously maintained by the Herdr CLI.
  xdg.configFile."herdr/plugins.json".force = true;
  xdg.configFile."herdr/plugins/config/herdr-bar/config.json".text = builtins.toJSON {
    auto_titles = true;
    tab_status = true;
    # Detection only scans the top of ~/Library/Fonts; Home Manager installs to a subdirectory.
    agent_icons = "font";
  };
  xdg.configFile."herdr/plugins/config/worktrunk/config.toml".text = ''
    show_remote_branches = true
    # picker_placement = "popup"
    # popup_width = "70%"
    # popup_height = "50%"
  '';
  home.file."${config.xdg.stateHome}/herdr/client/endpoints.json".force = true;

  # Ensure the worktrunk worktree root exists.
  home.file."dev/worktrees/.keep".text = "";

  xdg.configFile."worktrunk/config.toml" = {
    force = true;
    text = ''
      worktree-path = "~/dev/worktrees/{{ repo }}/{{ branch | sanitize }}"

      [commit.generation]
      command = "MAX_THINKING_TOKENS=0 claude -p --no-session-persistence --model=haiku --tools=''' --safe-mode --setting-sources='user' --system-prompt='''"
    '';
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

  # Activation does not inherit home.sessionPath. uv needs its executable
  # directory on PATH, plus Apple's install_name_tool and SDK on macOS.
  home.activation.uvEnvironment =
    lib.hm.dag.entryBefore
      [
        "uvPython"
        "uvTool"
      ]
      ''
        export PATH="${config.home.homeDirectory}/.local/bin:$PATH"
        ${lib.optionalString isDarwin ''
          export PATH="/usr/bin:$PATH"
          export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
        ''}
      '';

  programs.uv = {
    enable = true;
    settings.preview-features = [ "python-install-default" ];

    python = {
      versions = [ "3.14.7" ];
      default = [ "3.14.7" ];
      prune = true;
    };

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

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    initContent = ''
      # source ${inputs.herdr-automatic-rename}/shell/hook.zsh

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

      # source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      # zvm_after_init_commands+=("bindkey '^y' autosuggest-accept")
      bindkey '^y' autosuggest-accept

      # Better zsh history
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
    '';
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
