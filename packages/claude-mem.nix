{
  lib,
  callPackage,
  cacert,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
  bun,
  claude-code,
  codex,
  tree-sitter,
  python3,
  makeWrapper,
  which,
  coreutils,
  git,
  lsof,
  bash,
}:

let
  chroma = callPackage ./claude-mem/chroma.nix { };
in
buildNpmPackage (finalAttrs: {
  pname = "claude-mem";
  version = "15.6.0";

  # Reuse published bundles (including the OpenCode adapter). This is not a
  # from-source build. Root + plugin runtime dependencies are locked together.
  src = fetchurl {
    url = "https://registry.npmjs.org/claude-mem/-/claude-mem-${finalAttrs.version}.tgz";
    hash = "sha256-Fjwpm6gySNQK98kic+hSuxvGFrbfwpTiK7mOVNsS/rQ=";
  };
  nodejs = nodejs_24;
  npmDepsHash = "sha256-qFJKHnJrYgs1pDbqrKAqUkkGzoixJeiP7+u+Waxxuv0=";
  postPatch = ''
    cp ${./claude-mem/package.json} package.json
    cp ${./claude-mem/package-lock.json} package-lock.json
  '';
  # Grammar packages have conflicting Node-binding peers. We use their C
  # sources with the Nix CLI, never their bindings or npm download scripts.
  npmFlags = [ "--legacy-peer-deps" ];
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nativeBuildInputs = [
    python3
    makeWrapper
    tree-sitter
  ];

  installPhase = ''
    runHook preInstall

    root=$out/share/claude-mem
    plugin=$root/plugin
    mkdir -p "$root" "$out/bin" "$out/libexec"
    ln -s ${lib.getExe chroma} "$out/libexec/chroma-mcp"
    cp -R plugin dist package.json node_modules "$root/"
    ln -s ../node_modules "$plugin/node_modules"
    # The npm install script normally downloads this binary. Supply Nix's CLI.
    ln -sf ${lib.getExe tree-sitter} "$root/node_modules/tree-sitter-cli/tree-sitter"

    ${python3}/bin/python ${./claude-mem/prepare.py} \
      "$out" ${lib.getExe codex} ${lib.getExe bash} "$out/libexec/chroma-mcp" \
      ${cacert}/etc/ssl/certs/ca-bundle.crt

    for entry in claude-mem claude-mem-mcp claude-mem-codex-hook; do
      case "$entry" in
        claude-mem) script=claude-mem-launcher.cjs; args= ;;
        claude-mem-mcp) script=mcp-server.cjs; args= ;;
        claude-mem-codex-hook) script=claude-mem-launcher.cjs; args="hook codex" ;;
      esac
      makeWrapper ${lib.getExe nodejs_24} "$out/bin/$entry" \
        --add-flags "$plugin/scripts/$script $args" \
        --set CLAUDE_PLUGIN_ROOT "$plugin" \
        --set PLUGIN_ROOT "$plugin" \
        --set CLAUDE_MEM_WORKER_SCRIPT_PATH "$plugin/scripts/worker-service.cjs" \
        --set CLAUDE_MEM_CHROMA_ENABLED true \
        --set CLAUDE_MEM_CHROMA_MODE local \
        --set CLAUDE_MEM_CHROMA_EMBEDDING_FUNCTION default \
        --set-default CLAUDE_MEM_TELEMETRY false \
        --set CLAUDE_MEM_PROVIDER claude \
        --set CLAUDE_CODE_PATH ${lib.getExe claude-code} \
        --prefix PATH : ${
          lib.makeBinPath [
            bun
            nodejs_24
            which
            coreutils
            git
            lsof
            bash
            tree-sitter
          ]
        }
    done
    wrapProgram "$out/bin/claude-mem-codex-hook" --set CLAUDE_MEM_CODEX_HOOK 1

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/claude-mem-check"
    mkdir -p "$HOME"
    test "$("$out/bin/claude-mem" --version)" = 2
    ${python3}/bin/python ${./claude-mem/check.py} "$out"
    ${lib.getExe nodejs_24} ${./claude-mem/check-opencode.mjs} "$out"
    runHook postInstallCheck
  '';

  passthru = {
    inherit chroma;
    pluginRoot = "${finalAttrs.finalPackage}/share/claude-mem/plugin";
    opencodePlugin = "${finalAttrs.finalPackage}/share/claude-mem/dist/opencode-plugin/index.js";
  };

  meta = {
    description = "Shared coding-agent memory with Nix-owned hooks and local vector search";
    homepage = "https://github.com/thedotmack/claude-mem";
    license = lib.licenses.asl20;
    mainProgram = "claude-mem";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
