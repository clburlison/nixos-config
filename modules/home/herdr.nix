{ inputs, hostName }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Index tabs/workspaces as "1-name" instead of "[1] name".
  herdrAutomaticRename = pkgs.applyPatches {
    name = "herdr-automatic-rename";
    src = inputs.herdr-automatic-rename;
    patches = [ ../../patches/herdr-automatic-rename-dash-index.patch ];
  };
in
{
  imports = [ inputs.herdr-nix.homeModules.default ];

  home.packages = [ pkgs.herdr-agent-icons ];

  programs.bash.initExtra = ''
    source ${herdrAutomaticRename}/shell/hook.bash
  '';

  programs.fish.interactiveShellInit = ''
    source ${herdrAutomaticRename}/shell/hook.fish
  '';

  programs.zsh.initContent = ''
    source ${herdrAutomaticRename}/shell/hook.zsh
  '';

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
    plugins.automatic-rename.source = herdrAutomaticRename;
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
    plugins.layouts.source = ../../plugins/herdr-layouts;
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
    # herdr-automatic-rename owns tab naming; herdr-bar is only the command bar.
    auto_titles = false;
    tab_status = false;
    # Detection only scans the top of ~/Library/Fonts; Home Manager installs to a subdirectory.
    agent_icons = "font";
  };
  xdg.configFile."herdr-automatic-rename/config.sh".text = ''
    ICONS_ENABLED=1
    # Herdr Agent Icons Max logos (mapped in Ghostty via font-codepoint-map).
    ICON_MAP=(
      "claude="
      "codex="
    )
  '';
  xdg.configFile."herdr/plugins/config/worktrunk/config.toml".text = ''
    show_remote_branches = true
    # picker_placement = "popup"
    # popup_width = "70%"
    # popup_height = "50%"
  '';
  home.file."${config.xdg.stateHome}/herdr/client/endpoints.json".force = true;
}
