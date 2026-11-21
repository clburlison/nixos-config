# T3 Code provider instances. Activation merges them into T3's mutable
# settings.json, keeping every other setting and instance field. Claude
# Code, Codex, and Muse Code run the profile's wrappers (cliproxyapi.nix)
# by absolute path: the T3 app's PATH may lack the profile. Other modules
# add instances (antigravity.nix).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  bin = name: "${config.home.profileDirectory}/bin/${name}";
  settings = "${config.home.homeDirectory}/.t3/userdata/settings.json";
in
{
  _class = "homeManager";

  options.clb.t3.providerInstances = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = { };
    description = ''
      T3 Code provider instances by instance id, deep-merged into
      `.providerInstances` of ~/.t3/userdata/settings.json at activation.
      A built-in driver's default instance has the driver's id.
    '';
  };

  config = {
    clb.t3.providerInstances = {
      claudeAgent = {
        driver = "claudeAgent";
        enabled = true;
        config = {
          enabled = true;
          binaryPath = bin "claude";
        };
      };
      # "Use existing CLI": T3 runs this codex with its usual ~/.codex.
      codex = {
        driver = "codex";
        enabled = true;
        config = {
          enabled = true;
          setupMode = "existing";
          binaryPath = bin "codex";
        };
      };
      muse = {
        driver = "muse";
        enabled = true;
        config = {
          enabled = true;
          binaryPath = bin "muse";
        };
      };
    };

    home.activation.t3Providers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      t3=${lib.escapeShellArg settings}
      ${pkgs.coreutils}/bin/install -d -m 755 "''${t3%/*}"
      if [ ! -s "$t3" ]; then
        printf '{}\n' > "$t3"
      fi
      tmp="$(${pkgs.coreutils}/bin/mktemp "$t3.XXXXXX")"
      ${pkgs.jq}/bin/jq \
        --argjson instances ${lib.escapeShellArg (builtins.toJSON config.clb.t3.providerInstances)} \
        '.providerInstances = ((.providerInstances // {}) * $instances)' \
        "$t3" > "$tmp"
      if ${pkgs.diffutils}/bin/cmp -s "$tmp" "$t3"; then
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      else
        ${pkgs.coreutils}/bin/chmod 644 "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$t3"
      fi
    '';
  };
}
