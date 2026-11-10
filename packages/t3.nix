{
  lib,
  fetchurl,
  stdenvNoCC,
}:

# The `t3` npm package is a launcher that downloads this release archive into
# ~/.t3/runtime at first run. Fetch the archive directly instead.
let
  sources = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-qVvmGgJg+Nr2Lw4hi9PmA4amZ00yo/xG4tO8FZ+bfao=";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha256-K/+/YI7vc2xcNeNDGn5SYdDJCeM9io/rg+8mo3R8+PQ=";
    };
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-ucSdwAwj+7xZYb2v8tiOVW2WyNvWOMRQHik3xwZQqeU=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "t3 is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3";
  version = "0.1.8";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-${source.target}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = "t3-${finalAttrs.version}-${source.target}";

  dontConfigure = true;
  dontBuild = true;
  # Self-contained Bun executable with an embedded payload; leave it untouched.
  dontFixup = true;

  # The executable loads client/, node_modules/ and resource-monitor/ beside it.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec $out/bin
    cp -R . $out/libexec/t3
    ln -s $out/libexec/t3/t3 $out/bin/t3

    runHook postInstall
  '';

  meta = {
    description = "T3 Code CLI";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
