{ lib, pkgs, ... }:

{
  _class = "homeManager";

  programs.fish = {
    enable = true;
    # Run after Home Manager's shell integrations, as before the module split.
    shellInit = lib.mkOrder 1050 ''
      set fish_greeting ""

      if status is-interactive
        ${pkgs.worktrunk}/bin/wt config shell init fish | source
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
}
