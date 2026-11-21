# Hub models served once per reasoning effort, with the efforts each
# accepts (CLIProxyAPI's registry, internal/registry/models/models.json).
# Shared data: the hub (hosts/ai-hub/cliproxyapi.nix) serves the per-effort
# names, and agy (modules/common/programs/antigravity.nix) lists them.
#
# Names: the effort replaces a trailing effort in the upstream id, else is
# appended, e.g. gemini-4-neon-xhigh -> gemini-4-neon-low ... -xhigh and
# gpt-6.2-sol -> gpt-6.2-sol-low ... -max. agy groups these names into one
# model with a Thinking Level setting, so no plain name may share a base
# with them (the Claude account's claude-opus-5-5 stays off agy's list).
# Upstream names stay listed for other clients. Gemini 3 models are hidden
# on the hub (`excluded`), so they're not listed.
{ lib }:

let
  # Per channel: the payload path that sets the effort, the paths it
  # replaces, and the models in agy's order. `default` is listed first, so
  # agy picks it. A model without `levels` is listed as is.
  channels = {
    antigravity = {
      param = "generationConfig.thinkingConfig.thinkingLevel";
      drop = [ "generationConfig.thinkingConfig.thinkingBudget" ];
      models = [
        {
          id = "gemini-4-neon-xhigh";
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
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        {
          id = "claude-opus-5-5-high";
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        {
          id = "claude-sonnet-5-5-high";
          levels = [
            "low"
            "medium"
            "high"
          ];
          default = "high";
        }
        { id = "gpt-oss-120b-medium"; }
      ];
    };
    codex = {
      param = "reasoning.effort";
      drop = [ ];
      models = [
        {
          id = "gpt-6.2-sol";
          levels = [
            "low"
            "medium"
            "high"
            "xhigh"
            "max"
          ];
          default = "high";
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

  # { protocol; name = upstream id; alias = client name; level = effort or null; }
  variants = lib.concatLists (
    lib.mapAttrsToList (
      protocol: c:
      lib.concatMap (
        m:
        if m ? levels then
          map (level: {
            inherit protocol level;
            name = m.id;
            alias = "${base m.id}-${level}";
          }) ([ m.default ] ++ lib.remove m.default m.levels)
        else
          [
            {
              inherit protocol;
              name = m.id;
              alias = m.id;
              level = null;
            }
          ]
      ) c.models
    ) channels
  );
  leveled = lib.filter (v: v.level != null) variants;
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

  # Every per-effort and as-is name, in agy's order: antigravity, then codex.
  names = map (v: v.alias) (
    lib.filter (v: v.protocol == "antigravity") variants
    ++ lib.filter (v: v.protocol == "codex") variants
  );
}
