# Hub models served once per reasoning effort, with the efforts each
# accepts (CLIProxyAPI's registry, internal/registry/models/models.json).
# Shared data: the hub (hosts/ai-hub/cliproxyapi.nix) serves the per-effort
# names, and agy (modules/common/programs/antigravity.nix) lists them.
#
# Names: the effort replaces a trailing effort in the upstream id, else is
# appended, e.g. gemini-4-neon-xhigh -> gemini-4-neon-low ... -xhigh. agy
# groups these names into one model with a Thinking Level setting, so no
# plain name may share a base with them (the Claude account's
# claude-opus-5-5 stays off agy's list).
# Upstream names stay listed for other clients. Gemini 3 models are hidden
# on the hub (`excluded`), so they're not listed.
#
# Only Antigravity models get per-effort names: agy lists the Antigravity
# account alone, and other clients list them too (/v1/models), so a
# per-effort GPT shows up in Codex as duplicate rows of one model.
{ lib }:

let
  # Per channel: the payload path that sets the effort, the paths it
  # replaces, and the models in agy's order. `default` is listed first, so
  # agy picks it. A model without `levels` is listed as is. `label` is the
  # name T3 Code shows for it (agy shows ids; see `labels`).
  channels = {
    antigravity = {
      param = "generationConfig.thinkingConfig.thinkingLevel";
      drop = [ "generationConfig.thinkingConfig.thinkingBudget" ];
      models = [
        {
          id = "gemini-4-neon-xhigh";
          label = "Gemini 4 Neon";
          levels = [
            "low"
            "medium"
            "high"
            "xhigh"
          ];
          default = "xhigh";
        }
        {
          id = "gemini-4-hydrogen-xhigh";
          label = "Gemini 4 Hydrogen";
          levels = [
            "low"
            "medium"
            "high"
            "xhigh"
          ];
          default = "high";
        }
        {
          id = "gemini-4-argon-high";
          label = "Gemini 4 Argon";
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        {
          id = "claude-opus-5-5-high";
          label = "Claude Opus 5.5";
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        {
          id = "claude-sonnet-5-5-high";
          label = "Claude Sonnet 5.5";
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        {
          id = "gpt-oss-120b-medium";
          label = "GPT-OSS 120B";
        }
      ];
    };
  };

  base =
    id:
    let
      m = builtins.match "(.*)-(minimal|low|medium|high|xhigh|max)" id;
    in
    if m == null then id else builtins.head m;

  # { protocol; name = upstream id; alias = client name; level = effort or
  # null; label; first = listed first in its model; }
  variants = lib.concatLists (
    lib.mapAttrsToList (
      protocol: c:
      lib.concatMap (
        m:
        if m ? levels then
          map (level: {
            inherit protocol level;
            inherit (m) label;
            name = m.id;
            alias = "${base m.id}-${level}";
            first = level == m.default;
          }) ([ m.default ] ++ lib.remove m.default m.levels)
        else
          [
            {
              inherit protocol;
              inherit (m) label;
              name = m.id;
              alias = m.id;
              level = null;
              first = true;
            }
          ]
      ) c.models
    ) channels
  );
  leveled = lib.filter (v: v.level != null) variants;
  agyVariants = lib.filter (v: v.protocol == "antigravity") variants;
  # agy's Thinking Level names.
  levelNames = {
    minimal = "Minimal";
    low = "Low";
    medium = "Medium";
    high = "High";
    xhigh = "Extra";
    max = "Max";
  };
  rule = v: {
    inherit (v) protocol;
    name = v.alias;
  };
in
{
  # Upstream models the hub hides (oauth excluded-models, wildcards).
  excluded.antigravity = [ "gemini-3*" ];

  # oauth model-alias entries per channel. `fork` keeps the upstream name.
  aliases = lib.mapAttrs (
    protocol: _:
    map (v: {
      inherit (v) name alias;
      fork = true;
    }) (lib.filter (v: v.protocol == protocol && v.alias != v.name) variants)
  ) channels;

  # requests.payload rules: each per-effort name sets its effort, replacing
  # the client's.
  payload = {
    override = map (v: {
      models = [ (rule v) ];
      params.${channels.${v.protocol}.param} = v.level;
    }) leveled;
    filter = lib.concatLists (
      lib.mapAttrsToList (
        protocol: c:
        lib.optional (c.drop != [ ]) {
          models = map rule (lib.filter (v: v.protocol == protocol) leveled);
          params = c.drop;
        }
      ) channels
    );
  };

  # Every per-effort and as-is name, in agy's order.
  names = map (v: v.alias) agyVariants;

  # Human names for agy's ACP model lists, keyed by the names agy shows
  # (the ids). agy labels a grouped model with its first-listed id, and
  # each effort with its own id. agy takes no display names, so its
  # wrapper rewrites them; the hub's ids stay as they are.
  labels = {
    models = lib.listToAttrs (
      map (v: lib.nameValuePair v.alias v.label) (lib.filter (v: v.first) agyVariants)
    );
    efforts = lib.listToAttrs (
      map (
        v:
        lib.nameValuePair v.alias (
          if v.level == null then v.label else "${v.label} (${levelNames.${v.level}})"
        )
      ) agyVariants
    );
  };
}
