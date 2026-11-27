# https://nix-community.github.io/home-manager/options.xhtml
# Home Manager configuration shared by every host (workstation and server).

{
  config,
  pkgs,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/dev/me/nixos-config/dotfiles";
  mkLink = config.lib.file.mkOutOfStoreSymlink;
in
{
  _class = "homeManager";

  imports = [
    ./programs/fish.nix
    ./programs/ssh.nix
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

  # Core packages installed on every host, including servers.
  home.packages = [
    pkgs.curl
    pkgs.fzf
    pkgs.go-task
    pkgs.htop
    pkgs.jq
    pkgs.neovim
    pkgs.ripgrep
    pkgs.tree
    pkgs.wget
  ];

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
    # Remove duplicates and commands that start with space
    HISTCONTROL = "ignoreboth";
    # oh-my-posh fallback when the per-session config cache is lost (e.g.
    # after a switch); otherwise running shells render the default theme.
    POSH_CONFIG = "${config.home.homeDirectory}/.config/ohmyposh/clburlison.toml";
  };

  home.file = {
    ".aliases".source = ../../dotfiles/aliases;
    ".config/fish/aliases.fish".source = mkLink "${dotfiles}/config/fish/aliases.fish";
    ".config/fish/conf.d".source = mkLink "${dotfiles}/config/fish/config.d";
    ".config/fish/functions".source = mkLink "${dotfiles}/config/fish/functions";
    ".config/fish/omp-vimmode.fish".source = mkLink "${dotfiles}/config/fish/omp-vimmode.fish";
    ".config/fish/path.fish".source = mkLink "${dotfiles}/config/fish/path.fish";
    ".config/nvim".source = mkLink "${dotfiles}/config/nvim";
    ".config/ohmyposh".source = mkLink "${dotfiles}/config/ohmyposh";
    ".editorconfig".source = ../../dotfiles/editorconfig;
    ".functions".source = ../../dotfiles/functions;
    ".git-commit-template.txt".source = ../../dotfiles/git-commit-template.txt;
    ".gitconfig".source = ../../dotfiles/gitconfig;
    ".gitignore".source = ../../dotfiles/gitignore;
    ".inputrc".source = ../../dotfiles/inputrc;
    ".path".source = ../../dotfiles/path;
    ".ssh/allowed_signers".source = mkLink "${dotfiles}/ssh/allowed_signers";
    ".ssh/config".source = mkLink "${dotfiles}/ssh/config";
    ".ssh/hosts".source = mkLink "${dotfiles}/ssh/hosts";
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
    initExtra = builtins.readFile ../../dotfiles/bashrc;
  };

  programs.git = {
    enable = true;
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
}
