# Host override file for clb-work (Home Manager).
{
  _class = "homeManager";

  # The local failover proxy to ai-hub (hub-proxy.nix): LAN when home,
  # else the tailnet.
  clb.cliproxyapi.url = "http://127.0.0.1:8317";
  home.sessionVariables.CLAUDE_MEM_SERVER_URL = "http://127.0.0.1:37877";

  # Intercom MCP. OAuth tokens stay per device; authorize via /mcp.
  programs.claude-code.mcpServers.intercom = {
    type = "http";
    url = "https://mcp.intercom.com/mcp";
  };

  # Obot gateway (docs/ai-hub.md step 15): this host's key, and the vMCPs
  # it grants.
  clb.obot = {
    apiKeyReference = "op://Agents/MCP hub token clb-work/credential";
    vmcps.personal = "vmcp1vqt8x";
  };
}
