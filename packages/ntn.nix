{
  lib,
  fetchurl,
  stdenvNoCC,
  versionCheckHook,
}:

let
  sources = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-ttsctmnAUpnCky2w6dJceur9lmPFk3u2G2QIZnxXUuc=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-HVzsIyzEhSaUD9/0mrWqsocpL+v/ssQHHrcuap266Es=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-ijFwjJiByh1+HqSaaRVr8Xqor/lAdZ/EpFI+AB6ndF4=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-+QSgmIOnCjDQDagXaQnz07cMsU13Mep9IiiRUhk8rn4=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "ntn is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ntn";
  version = "0.23.8";

  src = fetchurl {
    url = "https://ntn.dev/releases/v${finalAttrs.version}/ntn-${source.target}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = "ntn-${source.target}";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ntn $out/bin/ntn

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Official Notion CLI";
    homepage = "https://developers.notion.com/cli";
    license = lib.licenses.mit;
    mainProgram = "ntn";
    platforms = builtins.attrNames sources;
  };
})
