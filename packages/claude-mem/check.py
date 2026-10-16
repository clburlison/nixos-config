"""Offline package-contract checks; never starts a worker or a model session."""

import ctypes
import json
from pathlib import Path
import shlex
import subprocess
import sys
import tomllib


root = Path(sys.argv[1])
plugin = root / 'share/claude-mem/plugin'
hooks = json.loads((plugin / 'hooks/hooks.json').read_text())['hooks']
assert set(hooks) == {
    'SessionStart', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse',
    'PostToolUseFailure', 'Stop', 'SessionEnd',
}
for groups in hooks.values():
    for group in groups:
        for hook in group['hooks']:
            assert hook['command'] == str(root / 'bin/claude-mem')
            assert hook['args'][0] in ('hook', 'start')
assert len(hooks['SessionStart']) == 2
mcp = json.loads((plugin / '.mcp.json').read_text())['mcpServers']['claude-mem']
assert mcp['command'] == str(root / 'bin/claude-mem-mcp')
codex = json.loads((plugin / 'hooks/codex-hooks.json').read_text())['hooks']
assert len(codex) == 6
assert codex['PostToolUse'][0]['hooks'][0]['timeout'] == 120
assert 'CLAUDE_MEM_CODEX_HOOK' in (root / 'bin/claude-mem-codex-hook').read_text()
assert (plugin / 'node_modules/zod/package.json').is_file()
assert (plugin / 'node_modules/better-auth/package.json').is_file()
assert (root / 'share/claude-mem/dist/opencode-plugin/index.js').is_file()
worker = (plugin / 'scripts/worker-service.cjs').read_text()
assert 'static buildLauncherPrefix(e){return[]}' in worker
assert 'if(e!=="win32")return"uvx"' not in worker
assert worker.count(str(root / 'libexec/chroma-mcp')) == 2
assert (root / 'libexec/chroma-mcp').is_file()

# Round-trip the actual CLI override arguments through a TOML parser. JSON
# objects are not TOML inline tables; a malformed overlay would disable hooks.
command = shlex.split((root / 'bin/claude-mem-codex').read_text().splitlines()[1])
overrides = command[3:-1:2]
settings = tomllib.loads('\n'.join(overrides))
assert settings['hooks'] == codex
assert settings['features']['hooks'] is True
assert settings['mcp_servers']['claude-mem']['command'] == mcp['command']

# Loading each C library catches linking errors without invoking a compiler or
# a model. Query-level and host-level tests are separate runtime smoke tests.
lib_dir = root / 'share/claude-mem/grammars'
suffix = '.dylib' if sys.platform == 'darwin' else '.so'
for language in json.loads((lib_dir / 'languages.json').read_text()):
    library = ctypes.CDLL(str(lib_dir / (language + suffix)))
    getattr(library, 'tree_sitter_' + language.replace('-', '_'))

subprocess.run(['node', '--check', str(plugin / 'scripts/mcp-server.cjs')], check=True)
print('claude-mem package contracts and grammar libraries passed')
