{
  config,
  lib,
  pkgs,
  ...
}:

{
  _class = "homeManager";

  # Backport declarative Python/tool management to the released Home Manager.
  disabledModules = [ "programs/uv.nix" ];

  imports = [
    (builtins.fetchurl {
      url = "https://raw.githubusercontent.com/nix-community/home-manager/f53f3267f5d009dd8f99443505e609389d7ff267/modules/programs/uv.nix";
      sha256 = "sha256-rvf6gkV/jDiaxHaeXA25tpQ+2gw2VPQGsRwPjrYI0K4=";
    })
  ];

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
        ${lib.optionalString pkgs.stdenv.isDarwin ''
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
}
