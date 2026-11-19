# Claude Code's MCP servers from the Obot gateway on ai-hub
# (hosts/ai-hub/obot.nix, docs/ai-hub.md step 15): one server per vMCP in
# clb.obot.vmcps, over Streamable HTTP on the tailnet. Each host has its own
# Obot API key, stored only on that host, so revoking one host's key cuts
# off that host alone; the shared Agents vault never holds it. The key stays
# out of Nix and ~/.claude.json: Claude Code runs a headers helper at each
# connect. Darwin reads the login keychain (set with `obot-set-key`); Linux
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
  keychainService = "obot-api-key";

  readKey =
    if isDarwin then
      ''/usr/bin/security find-generic-password -s ${keychainService} -a "$USER" -w 2>/dev/null''
    else
      "cat ${lib.escapeShellArg cfg.apiKeyFile} 2>/dev/null";
  # The key goes to jq on stdin, not in argv.
  headers = pkgs.writeShellScript "obot-mcp-headers" ''
    key="$(${readKey})" && [ -n "$key" ] || exit 1
    printf '%s' "$key" | ${pkgs.jq}/bin/jq -Rs '{Authorization: ("Bearer " + .)}'
  '';

  # Stores this host's key, typed or pasted at a hidden prompt, or from
  # stdin. `security -i` reads the command from stdin, keeping the key out
  # of argv. Not from the clipboard on purpose: Universal Clipboard would
  # hand it to your other Macs.
  setKey = pkgs.writeShellApplication {
    name = "obot-set-key";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ -t 0 ]; then
        read -rsp "Obot API key for this Mac (hidden): " key
        echo >&2
      else
        key="$(cat)"
      fi
      key="$(printf '%s' "$key" | tr -d '[:space:]')"
      case "$key" in
        ok1-*) ;;
        *)
          echo "Not an Obot API key (ok1-...)." >&2
          exit 1
          ;;
      esac
      /usr/bin/security delete-generic-password -s ${keychainService} -a "$USER" >/dev/null 2>&1 || true
      printf 'add-generic-password -s %s -a %s -T /usr/bin/security -w %s\n' \
        ${keychainService} "$USER" "$key" | /usr/bin/security -i
      unset key
      echo "Stored in keychain service ${keychainService}. Restart Claude Code." >&2
    '';
  };

  hasKey = isDarwin || cfg.apiKeyFile != null;
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
    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Linux only: file holding this host's Obot API key. Unset, no servers.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf isDarwin { home.packages = [ setKey ]; })
    (lib.mkIf (cfg.vmcps != { } && hasKey) {
      programs.claude-code.mcpServers = lib.mapAttrs (_: id: {
        type = "http";
        url = "${cfg.url}/mcp-connect/${id}";
        headersHelper = "${headers}";
      }) cfg.vmcps;
    })
  ];
}
