# Claude Code's MCP servers from the Obot gateway on ai-hub
# (hosts/ai-hub/obot.nix, docs/ai-hub.md step 15): one server per vMCP in
# clb.obot.vmcps, over Streamable HTTP on the tailnet. Each host has its own
# Obot API key, in the Agents vault item `obot-<host>`, so revoking one
# host's key leaves the others working. The key stays out of Nix and
# ~/.claude.json: Claude Code runs a headers helper at each connect.
# Darwin reads op-agents' keychain cache; Linux reads apiKeyFile.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.clb.obot;

  readKey =
    if isDarwin then
      config.clb.opAgents.secrets.obot-api-key.readCommand
    else
      "cat ${lib.escapeShellArg cfg.apiKeyFile} 2>/dev/null";
  headers = pkgs.writeShellScript "obot-mcp-headers" ''
    key="$(${readKey})" && [ -n "$key" ] || exit 1
    ${pkgs.jq}/bin/jq -n --arg key "$key" '{Authorization: ("Bearer " + $key)}'
  '';
  hasKey = isDarwin || cfg.apiKeyFile != null;
  enabled = cfg.vmcps != { } && hasKey;
in
{
  _class = "homeManager";

  options.clb.obot = {
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://mcp.mermaid-agama.ts.net";
      description = "Obot base URL (the gateway's tailnet node).";
    };
    vmcps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      # Filled in once the vMCPs exist in Obot (docs/ai-hub.md step 15).
      default = { };
      example = {
        personal = "ms1qc7nz";
      };
      description = ''
        Claude Code server name to vMCP ID: the path segment after
        /mcp-connect/ in the vMCP's Connect URL. Empty, no servers.
      '';
    };
    keyReference = lib.mkOption {
      type = lib.types.str;
      default = "op://Agents/obot-${config.clb.host.name}/credential";
      description = "Darwin: 1Password reference for this host's Obot API key.";
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Linux only: file holding this host's Obot API key. Unset, no servers.";
    };
  };

  config = lib.mkIf enabled {
    clb.opAgents.secrets = lib.mkIf isDarwin {
      obot-api-key.reference = cfg.keyReference;
    };

    programs.claude-code.mcpServers = lib.mapAttrs (_: id: {
      type = "http";
      url = "${cfg.url}/mcp-connect/${id}";
      headersHelper = "${headers}";
    }) cfg.vmcps;
  };
}
