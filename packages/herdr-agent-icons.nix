{
  lib,
  fetchurl,
  stdenvNoCC,
}:

let
  rev = "79a81bbddc017a4349713e282b1a01ee360c46de";
in
stdenvNoCC.mkDerivation {
  pname = "herdr-agent-icons";
  version = "0-unstable-2026-10-27";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/hhdebb/herdr-radar/${rev}/dist/HerdrAgentIconsMax-Regular.ttf";
    hash = "sha256-G4GZSWsiPQdh/DpJ1bJRC9o43quCyzdYvzmASVvwUnI=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/share/fonts/truetype/HerdrAgentIconsMax-Regular.ttf
    runHook postInstall
  '';

  meta = {
    description = "Herdr Agent Icons Max font used by herdr-radar and herdr-bar";
    homepage = "https://github.com/hhdebb/herdr-radar";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
