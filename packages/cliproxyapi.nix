# nixpkgs-unstable's cliproxyapi at a newer release. Its Claude cloaking
# pins a Claude Code version baseline; models that need a newer client
# (Fable 5.2 needs 2.1.290+) are refused until the baseline is bumped.
# v8.0.80 sends 2.1.321. Drop this once unstable catches up.
#
# The patch limits /muse-code/models to models a Meta credential serves.
# Upstream lists every provider's models there, so the Muse CLI's picker
# shows GPT, Claude and Gemini too. Keep it while the hub serves Muse.
#
# The soonest-reset patch is upstream PR #7206, rebased onto v8.0.80. It
# adds `routing.strategy = "soonest-reset"`: spend the account whose weekly
# window resets first, so its quota is not lost at the reset. Rebase it on
# each bump; drop it once upstream merges the PR.
# https://github.com/router-for-me/CLIProxyAPI/pull/7206
{
  cliproxyapi,
  fetchFromGitHub,
}:

cliproxyapi.overrideAttrs (
  finalAttrs: prevAttrs: {
    version = "8.0.80";

    src = fetchFromGitHub {
      owner = "router-for-me";
      repo = "CLIProxyAPI";
      tag = "v${finalAttrs.version}";
      hash = "sha256-FsFBrVYvXpUgkkJMPmIbfoui/JT6xrlTy1e8DDA4Kw4=";
    };

    vendorHash = "sha256-89DZv8uj0rD5fgbfLZk6TuoYw2SfX1vhV88T4degwg8=";

    patches = (prevAttrs.patches or [ ]) ++ [
      ../patches/cliproxyapi-muse-catalog-meta-only.patch
      ../patches/cliproxyapi-soonest-reset-routing.patch
    ];
  }
)
