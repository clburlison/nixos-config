# Claude Code's MCP servers, from the MCP hub on srv-devbox
# (hosts/srv-devbox/mcp-hub.nix, docs/srv-devbox.md step 13), on the hosts
# that list them in `clb.mcp.servers`. Replaces the claude.ai connectors,
# which an ANTHROPIC_BASE_URL setup can't reach.
#
# The servers go in through Home Manager's programs.claude-code.mcpServers,
# which loads them as a plugin, so ~/.claude.json stays untouched. The hub's
# access token is a secret, so it stays out of Nix: the claude wrapper
# (cliproxyapi.nix) reads it from 1Password at each run, with the same
# service account token agent-git uses (agent-git.nix), and exports it as
# MCP_HUB_TOKEN for the server config to expand. A host without that token
# still starts Claude Code; its hub servers just fail to connect.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  cfg = config.clb.mcp;
  enabled = cfg.servers != [ ];

  # The service account token, as agent-git.nix reads it.
  readOpToken =
    if isDarwin then
      ''/usr/bin/security find-generic-password -s op-agents-service-account -a "$USER" -w 2>/dev/null''
    else
      "cat ${lib.escapeShellArg cfg.opTokenFile} 2>/dev/null";
in
{
  _class = "homeManager";

  options.clb.mcp = {
    hubUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://srv-devbox.mermaid-agama.ts.net:8319";
      description = "MCP hub base URL. Servers are at <hubUrl>/<name>/mcp.";
    };
    servers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "slack"
        "intercom"
      ];
      description = ''
        Hub servers this host gets, by the names in mcp-hub.nix. Empty by
        default: a host only reaches the servers listed in its override
        file.
      '';
    };
    tokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://Agents/mcp-hub/credential";
      description = "1Password reference for the hub's access token.";
    };
    opTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/agent-git-token";
      description = "Linux only: file holding the 1Password service account token. Darwin uses the keychain.";
    };
    claudeEnv = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = ''
        Shell snippet for the claude wrapper in cliproxyapi.nix: exports
        MCP_HUB_TOKEN when this host has hub servers and the token is
        readable. Empty otherwise.
      '';
    };
  };

  config = lib.mkMerge [
    {
      clb.mcp.claudeEnv = lib.optionalString enabled ''
        if mcp_op_token="$(${readOpToken})" && [ -n "$mcp_op_token" ]; then
          if mcp_hub_token="$(OP_SERVICE_ACCOUNT_TOKEN="$mcp_op_token" \
            ${pkgs.coreutils}/bin/timeout 10 ${pkgs._1password-cli}/bin/op read --no-newline ${lib.escapeShellArg cfg.tokenRef} 2>/dev/null)"; then
            export MCP_HUB_TOKEN="$mcp_hub_token"
          fi
        fi
        unset mcp_op_token mcp_hub_token
      '';
    }

    (lib.mkIf enabled {
      programs.claude-code.mcpServers = lib.genAttrs cfg.servers (name: {
        type = "http";
        url = "${cfg.hubUrl}/${name}/mcp";
        # Claude Code expands ${VAR} in server headers.
        headers.Authorization = "Bearer \${MCP_HUB_TOKEN:-}";
      });
    })
  ];
}
