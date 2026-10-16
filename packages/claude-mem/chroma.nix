{
  lib,
  python313,
  fetchPypi,
  fetchurl,
  runCommand,
}:

let
  # Match upstream's protobuf<7 constraint throughout the Python dependency
  # graph rather than mixing two protobuf installations in one environment.
  python = python313.override {
    packageOverrides = _: prev: {
      protobuf = prev.protobuf6;
    };
  };
  ps = python.pkgs;

  modelArchive = fetchurl {
    url = "https://chroma-onnx-models.s3.amazonaws.com/all-MiniLM-L6-v2/onnx.tar.gz";
    # SHA-256 recorded by chromadb 1.5.9's ONNXMiniLM_L6_V2 implementation.
    hash = "sha256-kT1zAM6uOy28LFDR3kuqyrS+e5OASRwn+rdBhhahbsM=";
  };
  model = runCommand "claude-mem-all-MiniLM-L6-v2" { } ''
    mkdir -p "$out"
    tar -xzf ${modelArchive} -C "$out"
    for file in config.json model.onnx special_tokens_map.json tokenizer_config.json tokenizer.json vocab.txt; do
      test -s "$out/onnx/$file"
    done
  '';

  # chroma-mcp 0.2.6 requires this SDK, not the newer nixpkgs MCP package.
  mcp = ps.buildPythonPackage {
    pname = "mcp";
    version = "1.6.0";
    pyproject = true;
    src = fetchPypi {
      pname = "mcp";
      version = "1.6.0";
      hash = "sha256-2TJIdt4sVjc2n0MWHNce6/2APfWpXkYiXKuNKA42ZyM=";
    };
    build-system = [
      ps.hatchling
      ps.uv-dynamic-versioning
    ];
    dependencies = with ps; [
      anyio
      httpx
      httpx-sse
      pydantic
      pydantic-settings
      sse-starlette
      starlette
      uvicorn
      python-dotenv
      typer
    ];
    pythonImportsCheck = [ "mcp.server.fastmcp" ];
    doCheck = false;
    meta.license = lib.licenses.mit;
  };
in
assert ps.chromadb.version == "1.5.9";
assert lib.versionAtLeast ps.onnxruntime.version "1.20";
assert lib.versionOlder ps.protobuf.version "7";
assert lib.versionOlder ps.pydantic.version "2.14";
ps.buildPythonApplication {
  pname = "claude-mem-chroma";
  version = "0.2.6";
  pyproject = true;
  src = fetchPypi {
    pname = "chroma_mcp";
    version = "0.2.6";
    hash = "sha256-0fCX0jVo5TI13BDC+o7O+9Vj+C8cGIRpeLpoea+xnhc=";
  };
  build-system = [ ps.hatchling ];
  dependencies = [
    ps.chromadb
    mcp
    ps.httpx
    ps.python-dotenv
    ps.typing-extensions
  ];
  # Only the default local ONNX embedder is exposed by our entrypoint. These
  # SDKs are for upstream's optional hosted/image embedding providers.
  pythonRemoveDeps = [
    "cohere"
    "openai"
    "pillow"
    "voyageai"
  ];
  postInstall = ''
    substitute ${./chroma-entry.py} "$out/bin/chroma-mcp" \
      --subst-var-by python ${python.interpreter} \
      --subst-var-by model ${model} \
      --subst-var-by check ${./check-chroma.py}
    chmod +x "$out/bin/chroma-mcp"
  '';
  pythonImportsCheck = [ "chroma_mcp" ];
  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
    export HOME="$TMPDIR/chroma-check"
    mkdir -p "$HOME"
    export ANONYMIZED_TELEMETRY=False
    "$out/bin/chroma-mcp" --help > /dev/null
    "$out/bin/chroma-mcp" --nix-self-test
  '';
  passthru = { inherit model; };
  meta = {
    description = "Pinned local Chroma MCP bridge and offline MiniLM embeddings for claude-mem";
    homepage = "https://github.com/chroma-core/chroma-mcp";
    license = lib.licenses.asl20;
    mainProgram = "chroma-mcp";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}
