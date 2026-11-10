# Host override file for clb-work (Home Manager).
{
  _class = "homeManager";

  # Remote herdr sessions on the Mac mini.
  programs.herdr.machines.clb-mini = {
    id = "9197ad236dbec9f5a454ec297ab15b4c";
    target = "clb-mini";
  };

  # Intercom MCP. OAuth tokens stay per device; authorize via /mcp.
  programs.claude-code.mcpServers.intercom = {
    type = "http";
    url = "https://mcp.intercom.com/mcp";
  };
}
