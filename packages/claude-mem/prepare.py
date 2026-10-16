"""Adapt the pinned release, failing rather than guessing if its layout changes."""

import json
from pathlib import Path
import re
import shlex
import subprocess
import sys


root = Path(sys.argv[1])
codex = sys.argv[2]
shell = sys.argv[3]
chroma = sys.argv[4]
plugin = root / 'share/claude-mem/plugin'


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


# Retain upstream event definitions, matchers, timeouts, async flags, and argv.
hooks_path = plugin / 'hooks/hooks.json'
hooks = json.loads(hooks_path.read_text())
del hooks['hooks']['Setup']
for event, groups in hooks['hooks'].items():
    for group in groups:
        for hook in group['hooks']:
            if hook['command'] == 'node':
                assert hook['args'] == ['${CLAUDE_PLUGIN_ROOT}/scripts/ensure-launcher.cjs']
        group['hooks'] = [h for h in group['hooks'] if h['command'] != 'node']
        for hook in group['hooks']:
            assert hook['command'] == 'claude-mem', (event, hook)
            hook['command'] = str(root / 'bin/claude-mem')
    hooks['hooks'][event] = [g for g in groups if g['hooks']]
write_json(hooks_path, hooks)
write_json(plugin / '.mcp.json', {
    'mcpServers': {'claude-mem': {
        'type': 'stdio', 'command': str(root / 'bin/claude-mem-mcp'),
    }},
})

# Codex accepts TOML config overrides on the command line. This adds inline
# hooks without taking ownership of existing config.toml or hooks.json files.
codex_path = plugin / 'hooks/codex-hooks.json'
codex_hooks = json.loads(codex_path.read_text())['hooks']
expected_events = {
    'SessionStart', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse', 'Stop', 'PostCompact',
}
assert set(codex_hooks) == expected_events
for groups in codex_hooks.values():
    for group in groups:
        for hook in group['hooks']:
            event = re.search(r' hook codex ([a-z-]+)$', hook['command'])
            assert event, hook
            # The launcher retains the environment-based tool-hook opt-outs.
            hook['command'] = f'{root}/bin/claude-mem-codex-hook {event[1]}'
            del hook['commandWindows']
write_json(codex_path, {'hooks': codex_hooks})


def toml(value):
    if isinstance(value, dict):
        return '{' + ', '.join(f'{json.dumps(k)} = {toml(v)}' for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '[' + ', '.join(map(toml, value)) + ']'
    return json.dumps(value)


overrides = ['features.hooks=true',
             f'mcp_servers.claude-mem.command={json.dumps(str(root / "bin/claude-mem-mcp"))}']
overrides.extend(f'hooks.{event}={toml(groups)}' for event, groups in codex_hooks.items())
args = [codex]
for override in overrides:
    args.extend(['--config', override])
wrapper = root / 'bin/claude-mem-codex'
wrapper.write_text(f'#!{shell}\nexec {shlex.join(args)} "$@"\n')
wrapper.chmod(0o755)

# Parser source/package mapping at 13.40.0 (src/services/smart-file-read/parser.ts).
# Compile the CLI-consumed C libraries, NOT the unused Node native bindings.
grammars = {
    'javascript': 'tree-sitter-javascript',
    'typescript': 'tree-sitter-typescript/typescript',
    'tsx': 'tree-sitter-typescript/tsx',
    'python': 'tree-sitter-python', 'go': 'tree-sitter-go',
    'rust': 'tree-sitter-rust', 'ruby': 'tree-sitter-ruby',
    'java': 'tree-sitter-java', 'c': 'tree-sitter-c', 'cpp': 'tree-sitter-cpp',
    'kotlin': 'tree-sitter-kotlin', 'swift': 'tree-sitter-swift',
    'php': 'tree-sitter-php/php', 'lua': '@tree-sitter-grammars/tree-sitter-lua',
    'scala': 'tree-sitter-scala', 'bash': 'tree-sitter-bash',
    'haskell': 'tree-sitter-haskell', 'zig': '@tree-sitter-grammars/tree-sitter-zig',
    'css': 'tree-sitter-css', 'scss': 'tree-sitter-scss',
    'toml': '@tree-sitter-grammars/tree-sitter-toml',
    'yaml': '@tree-sitter-grammars/tree-sitter-yaml', 'sql': '@derekstride/tree-sitter-sql',
    'markdown': '@tree-sitter-grammars/tree-sitter-markdown/tree-sitter-markdown',
}
lib_dir = root / 'share/claude-mem/grammars'
lib_dir.mkdir()
suffix = '.dylib' if sys.platform == 'darwin' else '.so'
for language, package in grammars.items():
    source = plugin / 'node_modules' / package
    assert (source / 'src/parser.c').is_file(), source
    subprocess.run(['tree-sitter', 'build', '-o', str(lib_dir / (language + suffix)),
                    str(source)], check=True)
write_json(lib_dir / 'languages.json', list(grammars))

# One deliberately narrow bundle patch: use immutable prebuilt grammars instead
# of compiling them into the user's data directory. This literal is tied to the
# fixed-output npm archive, not assumed stable across upstream releases.
mcp = plugin / 'scripts/mcp-server.cjs'
text = mcp.read_text()
old = '(0,Qe.join)(Gt(),"tree-sitter-libs")'
assert text.count(old) == 1, 'Recheck the grammar lookup patch for this release'
mcp.write_text(text.replace(old, json.dumps(str(lib_dir))))

# Keep Chroma's lifecycle, compatibility guard, prewarm, and MCP arguments, but
# launch our pinned Python bridge directly. No uvx resolution/provisioning is
# involved. The two command resolvers are manager spawn and dependency preflight.
worker = plugin / 'scripts/worker-service.cjs'
text = worker.read_text()
prefix = ('static buildLauncherPrefix(e){let r=vT.flatMap(n=>["--with",n]);'
          'return["--python",e,...r,"--from",`chroma-mcp==${YD}`,"chroma-mcp"]}')
assert text.count(prefix) == 1, 'Recheck the Chroma launcher-prefix patch'
text = text.replace(prefix, 'static buildLauncherPrefix(e){return[]}')
resolver = 'if(e!=="win32")return"uvx"'
assert text.count(resolver) == 2, 'Recheck the Chroma executable resolvers'
text = text.replace(resolver, 'if(e!=="win32")return' + json.dumps(chroma))
worker.write_text(text)
