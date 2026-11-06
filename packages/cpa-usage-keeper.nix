{
  lib,
  autoPatchelfHook,
  fetchurl,
  stdenv,
  versionCheckHook,
}:

let
  sources = {
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-oaWIKtmuEjE95p0gDPhhVLdABj3VGk4OvrggCcy5z8s=";
    };
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-SH9AiuXexHNr+SWoKQJh1xCLLuWrB12De6wqcmFI1B4=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "cpa-usage-keeper is not supported on ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "cpa-usage-keeper";
  version = "2.0.3";

  src = fetchurl {
    url = "https://github.com/Willxup/cpa-usage-keeper/releases/download/v${finalAttrs.version}/cpa-usage-keeper_v${finalAttrs.version}_linux_${source.arch}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = "cpa-usage-keeper_v${finalAttrs.version}_linux_${source.arch}";

  # Dynamically linked against glibc (cgo).
  nativeBuildInputs = [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 cpa-usage-keeper $out/bin/cpa-usage-keeper

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Usage history, cost, and quota dashboard for CLIProxyAPI";
    homepage = "https://github.com/Willxup/cpa-usage-keeper";
    license = lib.licenses.mit;
    mainProgram = "cpa-usage-keeper";
    platforms = builtins.attrNames sources;
  };
})
