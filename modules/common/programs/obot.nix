# Claude Code's MCP servers from the Obot gateway on ai-hub
# (hosts/ai-hub/obot.nix, docs/ai-hub.md step 15): one server per vMCP in
# clb.obot.vmcps, over Streamable HTTP on the tailnet. Each host has its own
# Obot API key in its own Agents vault item, so revoking one host's key in
# Obot cuts off that host alone. The key stays out of Nix and
# ~/.claude.json: Claude Code runs a headers helper at each connect. Darwin
# reads op-agents' keychain cache of apiKeyReference; Linux reads apiKeyFile.
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
  # The key goes to jq on stdin, not in argv.
  headers = pkgs.writeShellScript "obot-mcp-headers" ''
    key="$(${readKey})" && [ -n "$key" ] || exit 1
    printf '%s' "$key" | ${pkgs.jq}/bin/jq -Rs '{Authorization: ("Bearer " + .)}'
  '';

  hasKey = if isDarwin then cfg.apiKeyReference != null else cfg.apiKeyFile != null;
in
{
  _class = "homeManager";

  options.clb.obot = {
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://ai-hub-mcp.mermaid-agama.ts.net";
      description = "Obot base URL (the gateway's tailnet node).";
    };
    vmcps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      # Set per host in its override file (docs/ai-hub.md step 15).
      default = { };
      example = {
        personal = "ms1qc7nz";
      };
      description = ''
        Claude Code server name to vMCP ID: the path segment after
        /mcp-connect/ in the vMCP's Connect URL. Empty, no servers.
      '';
    };
    apiKeyReference = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "op://Agents/MCP hub token clb-work/credential";
      description = ''
        Darwin only: 1Password reference to this host's Obot API key, cached
        by op-agents. Set in the host override file. Unset, no servers.
      '';
    };
    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Linux only: file holding this host's Obot API key. Unset, no servers.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (isDarwin && cfg.apiKeyReference != null) {
      clb.opAgents.secrets.obot-api-key.reference = cfg.apiKeyReference;
    })
    (lib.mkIf (cfg.vmcps != { } && hasKey) {
      programs.claude-code.mcpServers = lib.mapAttrs (_: id: {
        type = "http";
        url = "${cfg.url}/mcp-connect/${id}";
        headersHelper = "${headers}";
      }) cfg.vmcps;
    })
  ];
}
