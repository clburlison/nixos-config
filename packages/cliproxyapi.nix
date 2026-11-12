# nixpkgs-unstable's cliproxyapi at a newer release. Its Claude cloaking
# pins a Claude Code version baseline; models that need a newer client
# (Fable 5.2 needs 2.1.290+) are refused until the baseline is bumped.
# v8.0.67 sends 2.1.321. Drop this once unstable catches up.
#
# The patch serves the Muse Code client endpoints (/muse-code/models and
# friends), which the muse CLI needs before it will use the hub. Upstream PR
# https://github.com/router-for-me/CLIProxyAPI/pull/6563, rebased on v8.0.67;
# drop it once that ships.
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

    patches = [ ../patches/cliproxyapi-muse-code-relay.patch ];
  }
)
