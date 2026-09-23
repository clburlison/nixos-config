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
      hash = "sha256-uavdS1rsFEWeQ0oomSA3V96K6EfwVerk8frue7H7wHg=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-CKuhmvTwBinl6JqwQBfTHRhXP7ydySIoCChwL9riej8=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-VcxKaySJpAOtnrgPYS36hBKHv6FrmDkLtNTgcteeI2E=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-u8udNlMIvDcooeyZE60YgPiMDOaHZzgyl+NIwFfzW40=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "linear-cli is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "linear-cli";
  version = "2.6.0";

  src = fetchurl {
    url = "https://github.com/schpet/linear-cli/releases/download/v${finalAttrs.version}/linear-${source.target}.tar.xz";
    inherit (source) hash;
  };

  sourceRoot = "linear-${source.target}";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 linear $out/bin/linear

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Command-line interface for Linear";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.mit;
    mainProgram = "linear";
    platforms = builtins.attrNames sources;
  };
})
