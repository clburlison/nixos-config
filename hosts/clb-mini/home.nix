# Host override file for clb-mini (Home Manager).
{
  _class = "homeManager";

  # Intercom MCP. OAuth tokens stay per device; authorize via /mcp.
  programs.claude-code.mcpServers.intercom = {
    type = "http";
    url = "https://mcp.intercom.com/mcp";
  };

  # Obot gateway (docs/ai-hub.md step 15): this host's key, and the vMCPs
  # it grants.
  clb.obot = {
    apiKeyReference = "op://Agents/MCP hub token clb-mini/credential";
    vmcps.personal = "vmcp1vqt8x";
  };
}
