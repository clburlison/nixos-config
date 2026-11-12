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
      hash = "sha256-fS64wGh7cMoDqdNUmDgYUtN5KYNYnoLR+xgxwI8LIwE=";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha256-UgI7xXKKTe5N42Gtb+98I28e+ydC/yXinVxV4vtmLuo=";
    };
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-AUECUzXaM0dZzs2Ns0g+CXcvNgDKA2dGmFJOfZQpE2I=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "t3 is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3";
  version = "0.1.9";

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
