# nixpkgs-unstable's cliproxyapi at a newer release. Its Claude cloaking
# pins a Claude Code version baseline; models that need a newer client
# (Fable 5.2 needs 2.1.290+) are refused until the baseline is bumped.
# v8.0.67 sends 2.1.321. Drop this once unstable catches up.
{
  cliproxyapi,
  fetchFromGitHub,
}:

cliproxyapi.overrideAttrs (
  finalAttrs: _: {
    version = "8.0.67";

    src = fetchFromGitHub {
      owner = "router-for-me";
      repo = "CLIProxyAPI";
      tag = "v${finalAttrs.version}";
      hash = "sha256-njk9i5JbHvJ3lTB7Bn0wTxFtmcJ5MEokgdOHNhzDPPY=";
    };

    vendorHash = "sha256-02Qqrs9lQ0kE+Tnk/SWvlkLXGSh8RQPxRawFZogRYNc=";
  }
)
