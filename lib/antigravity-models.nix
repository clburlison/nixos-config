# The Antigravity account's models on the CLIProxyAPI hub, with the
# reasoning efforts each accepts (CLIProxyAPI's registry,
# internal/registry/models/models.json). Shared data: the hub
# (hosts/ai-hub/cliproxyapi.nix) serves one model per effort, and agy
# (modules/common/programs/antigravity.nix) lists them.
#
# Names: a trailing effort in the upstream id is replaced by each level,
# e.g. gemini-4-neon-xhigh -> gemini-4-neon-low ... gemini-4-neon-xhigh.
# Claude and GPT models get an `agy-` prefix so they never share a name
# with the Claude and Codex accounts, and their upstream names are hidden.
# Gemini models keep their upstream names. A model Antigravity adds later
# shows under its upstream name until it is listed here.
{ lib }:

let
  efforts = {
    "claude-opus-5-5-high" = [
      "low"
      "medium"
      "high"
    ];
    "claude-sonnet-5-5-high" = [
      "low"
      "medium"
      "high"
    ];
    "gpt-oss-120b-medium" = [ ];
    "gemini-4-neon-xhigh" = [
      "low"
      "medium"
      "high"
      "xhigh"
    ];
    "gemini-4-hydrogen-xhigh" = [
      "low"
      "medium"
      "high"
      "xhigh"
    ];
    "gemini-4-argon-high" = [
      "low"
      "medium"
      "high"
    ];
    "gemini-3.8-flash-high" = [
      "low"
      "medium"
      "high"
    ];
    "gemini-3.8-flash-tiered" = [
      "low"
      "medium"
      "high"
    ];
    "gemini-3-flash" = [
      "minimal"
      "low"
      "medium"
      "high"
    ];
    "gemini-3.1-flash-lite" = [
      "minimal"
      "low"
      "medium"
      "high"
    ];
    "gemini-3.5-flash-lite" = [
      "minimal"
      "low"
      "medium"
      "high"
    ];
    "gemini-3.1-flash-image" = [
      "minimal"
      "high"
    ];
  };

  prefixed = id: lib.hasPrefix "claude-" id || lib.hasPrefix "gpt-" id;
  prefix = id: lib.optionalString (prefixed id) "agy-";
  base =
    id:
    let
      m = builtins.match "(.*)-(minimal|low|medium|high|xhigh)" id;
    in
    if m == null then id else builtins.head m;

  # { name = upstream id; alias = client name; level = effort or null; }
  # Gemini keeps its upstream name (`fork`); an alias equal to it is the
  # upstream model itself.
  variants = lib.concatLists (
    lib.mapAttrsToList (
      id: levels:
      if levels == [ ] then
        lib.optional (prefixed id) {
          name = id;
          alias = prefix id + id;
          level = null;
        }
      else
        map (level: {
          name = id;
          alias = "${prefix id}${base id}-${level}";
          inherit level;
        }) levels
    ) efforts
  );
in
{
  # model-alias entries for the antigravity channel.
  aliases = map (v: {
    inherit (v) name alias;
    fork = !prefixed v.name;
  }) (lib.filter (v: v.alias != v.name) variants);

  # Aliases that pin an effort.
  levels = lib.filter (v: v.level != null && v.alias != v.name) variants;

  # Every client-visible name.
  names = lib.unique (
    map (v: v.alias) variants ++ lib.filter (id: !prefixed id) (lib.attrNames efforts)
  );
}
