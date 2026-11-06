# nixpkgs-unstable's cliproxyapi at a newer release: CPA Usage Keeper needs
# CLIProxyAPI 8.0.12 or later. 8.0.39 and later need Go 1.26.10, newer than
# unstable's Go. Drop this once unstable catches up.
{
  cliproxyapi,
  fetchFromGitHub,
}:

cliproxyapi.overrideAttrs (
  finalAttrs: _: {
    version = "8.0.38";

    src = fetchFromGitHub {
      owner = "router-for-me";
      repo = "CLIProxyAPI";
      tag = "v${finalAttrs.version}";
      hash = "sha256-oRCObfhjVvUo4jebEHm2x6G4AqbYq5SlWy7LcEOnHGU=";
    };

    vendorHash = "sha256-r3yWkdMcM40G9jV7MxW/qNv3E9WrHavFilW24quEf+8=";
  }
)
