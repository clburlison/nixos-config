# AI usage analytics. Setup lives in the private ai-analytics repo.
{ inputs, ... }:

{
  imports = [ inputs.ai-analytics.nixosModules.default ];

  services.cliproxyapi.settings.observability.logs.request-log = true;
  services.cpa-clickhouse.enable = true;
}
