# Host override file for clb-work (Home Manager).
{
  _class = "homeManager";

  # Standalone Tailscale app; clb-mini runs the nix-darwin daemon instead.
  clb.homebrew.casks = [ "tailscale-app" ];

  # The local failover proxy to ai-hub (hub-proxy.nix): LAN when home,
  # else the tailnet.
  clb.cliproxyapi.url = "http://127.0.0.1:8317";
  home.sessionVariables.CLAUDE_MEM_SERVER_URL = "http://127.0.0.1:37877";

  # agy through the hub (loopback, so agy accepts plain http).
  clb.antigravity.enable = true;

  # Obot gateway (docs/ai-hub.md step 15): this host's key, and the vMCPs
  # it grants.
  clb.obot = {
    apiKeyReference = "op://Agents/MCP hub token clb-work/credential";
    vmcps = {
      personal = "vmcp1vqt8x";
      gl = "vmcp1rtvnp";
    };
  };
}
