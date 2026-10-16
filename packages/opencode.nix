{
  opencode-v2,
  stdenv,
}:
let
  upstream = opencode-v2.packages.${stdenv.hostPlatform.system}.opencode;
in
upstream.overrideAttrs {
  # v2.0.31's source filter omits script/, required by packages/cli/script/build.ts.
  src = opencode-v2.outPath;
}
