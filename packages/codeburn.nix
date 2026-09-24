{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
}:

buildNpmPackage (finalAttrs: {
  pname = "codeburn";
  version = "0.9.25";

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "d71c62de2e7f0d30c56932b10763a78431976766";
    hash = "sha256-MVgXl+fN9qZZmXhlgLXTX0toldDM1oH99Mc5bxScu7g=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-ucqpt5HTi8d8sD9eUl9ja7PyG0kyy1TASXgii/0xaNk=";
  npmBuildScript = "build:cli";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/codeburn $out/bin
    cp -R dist package.json node_modules $out/lib/node_modules/codeburn/
    ln -s $out/lib/node_modules/codeburn/dist/cli.js $out/bin/codeburn

    runHook postInstall
  '';

  meta = {
    description = "See where AI coding spend goes, by task, tool, model, and project";
    homepage = "https://github.com/getagentseal/codeburn";
    license = lib.licenses.mit;
    mainProgram = "codeburn";
    platforms = nodejs_24.meta.platforms;
  };
})
