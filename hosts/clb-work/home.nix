# Host override file for clb-work (Home Manager).
{
  _class = "homeManager";

  # MCP servers from the hub on srv-devbox (mcp-hub.nix).
  clb.mcp.servers = [
    "slack"
    "intercom"
    "zoom"
  ];

  # Remote herdr sessions on the Mac mini.
  programs.herdr.machines.clb-mini = {
    id = "9197ad236dbec9f5a454ec297ab15b4c";
    target = "clb-mini";
  };
}
