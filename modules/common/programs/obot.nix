# Claude Code's and Codex's MCP servers from the Obot gateway on ai-hub
# (hosts/ai-hub/obot.nix, docs/ai-hub.md step 15): one server per vMCP in
# clb.obot.vmcps, over Streamable HTTP on the tailnet. Each host has its own
# Obot API key in its own Agents vault item, so revoking one host's key in
# Obot cuts off that host alone. The key stays out of Nix and the clients'
# config files: both clients run the same headers helper, which reads it at
# connect. Darwin reads op-agents' keychain cache of apiKeyReference; Linux
# reads apiKeyFile.
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
  enabled = cfg.vmcps != { } && hasKey;

  # Codex's http_headers_helper takes the same JSON as Claude Code's.
  codexArgs = lib.concatLists (
    lib.mapAttrsToList (name: id: [
      "-c"
      ''mcp_servers.${name}.url="${cfg.url}/mcp-connect/${id}"''
      "-c"
      ''mcp_servers.${name}.http_headers_helper="${headers}"''
    ]) cfg.vmcps
  );
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
        MCP server name (Claude Code and Codex) to vMCP ID: the path segment
        after /mcp-connect/ in the vMCP's Connect URL. Empty, no servers.
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
    codexEnv = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = ''
        Shell snippet for the codex wrapper in claude-mem.nix: prepends the
        vMCPs' `-c` overrides to "$@".
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          # Bare TOML keys in Codex's -c paths.
          assertion = lib.all (n: builtins.match "[A-Za-z0-9_-]+" n != null) (lib.attrNames cfg.vmcps);
          message = "clb.obot.vmcps names may use only letters, digits, - and _.";
        }
      ];
      clb.obot.codexEnv = lib.optionalString enabled ''
        set -- ${lib.escapeShellArgs codexArgs} "$@"
      '';
    }
    (lib.mkIf (isDarwin && cfg.apiKeyReference != null) {
      clb.opAgents.secrets.obot-api-key.reference = cfg.apiKeyReference;
    })
    (lib.mkIf enabled {
      programs.claude-code.mcpServers = lib.mapAttrs (_: id: {
        type = "http";
        url = "${cfg.url}/mcp-connect/${id}";
        headersHelper = "${headers}";
      }) cfg.vmcps;
    })
  ];
}
