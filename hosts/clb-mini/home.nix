# Host override file for clb-mini (Home Manager).
{
  _class = "homeManager";

  # agy over the hub's tailnet HTTPS port: it rejects the LAN name's plain
  # http. Other clients keep the LAN URL.
  clb.antigravity = {
    enable = true;
    hubUrl = "https://ai-hub.mermaid-agama.ts.net:8443";
  };

  # Obot gateway (docs/ai-hub.md step 15): this host's key, and the vMCPs
  # it grants.
  clb.obot = {
    apiKeyReference = "op://Agents/MCP hub token clb-mini/credential";
    vmcps = {
      personal = "vmcp1vqt8x";
      gl = "vmcp1rtvnp";
      ls = "vmcp14xk66";
    };
  };
}
