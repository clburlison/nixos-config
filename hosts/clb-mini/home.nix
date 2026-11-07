# Host override file for clb-mini (Home Manager).
{
  _class = "homeManager";

  # MCP servers from the hub on srv-devbox (mcp-hub.nix).
  clb.mcp.servers = [
    "slack"
    "intercom"
    "zoom"
  ];
}
