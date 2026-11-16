# Host override file for clb-work (Home Manager).
{
  _class = "homeManager";

  # Intercom MCP. OAuth tokens stay per device; authorize via /mcp.
  programs.claude-code.mcpServers.intercom = {
    type = "http";
    url = "https://mcp.intercom.com/mcp";
  };
}
