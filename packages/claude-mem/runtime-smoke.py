"""Isolated smoke test: lazy startup, MCP, semantic recall, and smart parsing.

Usage: python3 packages/claude-mem/runtime-smoke.py /nix/store/...-claude-mem-13.40.0
Starts/stops only its own worker on a temporary port; no login/external model calls.
"""

import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request


root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='claude-mem-smoke-', dir=os.environ.get('TMPDIR')) as tmp:
    home = Path(tmp)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    env = {
        'HOME': tmp, 'PATH': os.environ['PATH'], 'TMPDIR': tmp,
        'CLAUDE_CONFIG_DIR': str(home / '.claude'),
        'CODEX_HOME': str(home / '.codex'),
        'CLAUDE_MEM_DATA_DIR': str(home / '.claude-mem'),
        'CLAUDE_MEM_WORKER_PORT': str(port),
        'DO_NOT_TRACK': '1', 'CI': '1',
    }
    guards = home / 'package-manager-guards'
    guards.mkdir()
    for command in ('uvx', 'uv', 'pip', 'pip3'):
        guard = guards / command
        guard.write_text(f'#!/bin/sh\necho "{command} $*" >> "{home}/unexpected-download"\nexit 99\n')
        guard.chmod(0o755)
    env['PATH'] = str(guards) + os.pathsep + env['PATH']
    data = home / '.claude-mem'
    data.mkdir()
    # Nix's enabled policy must supersede settings from the SQLite-only install.
    (data / 'settings.json').write_text('{"CLAUDE_MEM_CHROMA_ENABLED":"false"}')
    # Config overlays must leave existing mutable files byte-for-byte intact.
    (home / '.codex').mkdir()
    config = home / '.codex/config.toml'
    config.write_text('[features]\n')
    hooks = home / '.codex/hooks.json'
    hooks.write_text('{"hooks":{}}\n')
    # A higher-version mutable cache must not supersede the Nix runtime.
    cache = home / '.claude/plugins/cache/thedotmack/claude-mem/99999.0.0'
    (cache / 'scripts').mkdir(parents=True)
    (cache / 'package.json').write_text('{"version":"99999.0.0","dependencies":{}}')
    (cache / 'scripts/worker-service.cjs').write_text('throw new Error("stale cache selected");')
    listed = subprocess.run([str(root / 'bin/claude-mem-codex'), 'mcp', 'list', '--json'],
                            env=env, cwd=tmp, text=True, capture_output=True, check=True)
    assert 'claude-mem-mcp' in listed.stdout, listed
    assert config.read_text() == '[features]\n'
    assert hooks.read_text() == '{"hooks":{}}\n'

    source = home / 'sample.py'
    source.write_text('def nix_memory_example():\n    return 42\n')
    messages = queue.Queue()
    with (home / 'mcp-stderr.log').open('w+') as stderr:
        process = subprocess.Popen([str(root / 'bin/claude-mem-mcp')], cwd=tmp, env=env,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=stderr, text=True, bufsize=1)

        def read_messages():
            for line in process.stdout:
                try:
                    messages.put(json.loads(line))
                except json.JSONDecodeError:
                    messages.put({'invalid_stdout': line})
            messages.put({'eof': process.poll()})

        threading.Thread(target=read_messages, daemon=True).start()
        request_id = 0

        def request(method, params):
            global request_id
            request_id += 1
            process.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': request_id,
                                            'method': method, 'params': params}) + '\n')
            process.stdin.flush()
            while True:
                message = messages.get(timeout=90)
                assert 'invalid_stdout' not in message and 'eof' not in message, message
                if message.get('id') == request_id:
                    assert 'error' not in message, message
                    return message['result']

        def tool(name, arguments):
            result = request('tools/call', {'name': name, 'arguments': arguments})
            assert not result.get('isError'), result
            return json.dumps(result)

        try:
            request('initialize', {'protocolVersion': '2024-11-05', 'capabilities': {},
                                   'clientInfo': {'name': 'nix-smoke', 'version': '1'}})
            process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
            process.stdin.flush()
            tools = request('tools/list', {})
            assert {'mem_search', 'save_memory', 'smart_outline'} <= {
                t['name'] for t in tools['tools']
            }
            outline = tool('smart_outline', {'file_path': str(source)})
            assert 'nix_memory_example' in outline and 'Could not parse' not in outline, outline
            saved = tool('save_memory', {'text': 'Nix smoke durable memory quartzexample',
                                         'title': 'quartzexample', 'project': 'nix-smoke'})
            assert 'quartzexample' in saved, saved
            recalled = tool('search', {'query': 'quartzexample', 'project': 'nix-smoke'})
            assert 'quartzexample' in recalled, recalled
            tool('save_memory', {
                'text': 'Friends enjoy sandwiches and a picnic in the garden.',
                'title': 'garden-note', 'project': 'nix-vector-smoke',
            })
            # Sync is asynchronous. A query with no shared terms must retrieve
            # the note through Chroma, not SQLite's keyword fallback.
            deadline = time.monotonic() + 90
            while True:
                result = request('tools/call', {'name': 'search', 'arguments': {
                    'query': 'food eaten outdoors', 'project': 'nix-vector-smoke',
                }})
                if not result.get('isError') and 'garden-note' in json.dumps(result):
                    break
                assert time.monotonic() < deadline, result
                time.sleep(0.5)
            health = json.load(urllib.request.urlopen(f'http://127.0.0.1:{port}/api/health'))
            assert health['status'] == 'ok', health
            assert (home / '.claude-mem/claude-mem.db').is_file()
            assert not (home / '.claude-mem/tree-sitter-libs').exists()
            assert not (home / '.cache/uv').exists()
            assert not (home / '.cache/chroma').exists()
            assert not (home / 'unexpected-download').exists()
            assert (home / '.claude-mem/chroma/chroma.sqlite3').is_file()
            print('Codex preservation, lazy worker, MCP, SQLite/semantic recall, and smart_outline passed')
        except BaseException:
            if (home / 'unexpected-download').exists():
                print((home / 'unexpected-download').read_text(), file=sys.stderr)
            stderr.flush()
            stderr.seek(0)
            print(stderr.read(), file=sys.stderr)
            for log in (home / '.claude-mem/logs').glob('*.log'):
                print(log.read_text()[-12000:], file=sys.stderr)
            raise
        finally:
            subprocess.run([str(root / 'bin/claude-mem'), 'stop'], env=env, cwd=tmp,
                           capture_output=True, timeout=30)
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
