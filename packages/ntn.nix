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
      hash = "sha256-l1XK+f6qqiYrANqE2U0FcaHn3VVMjFMZLAw5454MZkM=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-Ed6euf0o4El9sNBenDWMQ8z8PZCVk65WV10yi7gPVHE=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-xcsq26txS7wNzIOkAhb74xzXQt+X+Ry3KUrRUx91KTE=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-y73AMRe3hsMeHJJE+I1TWL7y+QkW/s2cLgYDre8C+2Q=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "ntn is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ntn";
  version = "0.23.28";

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
