#!@python@
"""Run the pinned MCP bridge with store-backed, download-free ONNX embeddings."""

import os
from functools import partial
from pathlib import Path
import runpy
import sys

os.environ['ANONYMIZED_TELEMETRY'] = 'False'
os.environ['OTEL_SDK_DISABLED'] = 'true'

from chromadb.utils.embedding_functions.onnx_mini_lm_l6_v2 import ONNXMiniLM_L6_V2

MODEL = Path('@model@')
ONNXMiniLM_L6_V2.DOWNLOAD_PATH = MODEL


def require_packaged_model(self):
    # Fail closed if the packaged model is incomplete; never populate a user
    # cache or fall back to upstream's HTTP downloader/extractor.
    for name in ('config.json', 'model.onnx', 'special_tokens_map.json',
                 'tokenizer_config.json', 'tokenizer.json', 'vocab.txt'):
        if not (MODEL / 'onnx' / name).is_file():
            raise RuntimeError(f'Packaged Chroma model is incomplete: {name}')


ONNXMiniLM_L6_V2._download_model_if_not_exists = require_packaged_model

if sys.argv[1:] == ['--nix-self-test']:
    runpy.run_path('@check@', run_name='__main__')
else:
    from chroma_mcp import server

    # No unpinned hosted or image embedding SDKs are part of this package.
    server.mcp_known_embedding_functions = {'default': server.DefaultEmbeddingFunction}
    # Upstream's startup diagnostics use print(); keep stdout MCP-only.
    server.print = partial(print, file=sys.stderr)
    server.main()
