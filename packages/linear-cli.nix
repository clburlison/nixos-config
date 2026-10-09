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
      hash = "sha256-heuE55VUSld63Be5b4sAdxvOyU840mRC/X1WHNgjNvI=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-cjwy4ERFOBjwtTnC3Y2iCoFaloNEJJkFjhBppxH3Jqs=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-9lgBhfOgfFWMZN5EUG165WwTYVx9ITnlzSL/OwOCL80=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-UGSmOn5qi1iTpVDhOMCnujc6rWXUJd3msrZrUKbBAok=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "linear-cli is not supported on ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "linear-cli";
  version = "3.0.0";

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
