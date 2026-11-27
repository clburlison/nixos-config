# Host override file for devbox (Home Manager).
{
  _class = "homeManager";

  # Point at /run/op-agents/* once op-agents is enabled in system.nix
  # (docs/op-agents.md). Until those files exist, wrappers fall back cleanly.
  clb.claudeMem.apiKeyFile = "/run/op-agents/claude-mem-api-key";
  clb.cliproxyapi.apiKeyFile = "/run/op-agents/cliproxyapi-api-key";
}
