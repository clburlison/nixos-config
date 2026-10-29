"""Refresh claude-mem's published bundles and locked runtime dependencies.

Run through task packages:update-claude-mem -- [VERSION] [--dry-run]. Downloaded
JavaScript is inspected/patched, never executed. npm lifecycle scripts stay off.
"""

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request


HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
REGISTRY = 'https://registry.npmjs.org/claude-mem/'
VERSION_PATTERN = r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?'


def version(value):
    value = value.removeprefix('v')
    if not re.fullmatch(VERSION_PATTERN, value):
        raise argparse.ArgumentTypeError(f'Invalid claude-mem version: {value}')
    return value


def download(url):
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def verify_integrity(archive, integrity):
    for token in integrity.split():
        algorithm, _, expected = token.partition('-')
        if algorithm == 'sha512':
            actual = base64.b64encode(hashlib.sha512(archive).digest()).decode()
            if actual == expected:
                return
    raise ValueError('Release archive does not match registry SHA-512 integrity')


def merge(left, right):
    for name in left.keys() & right.keys():
        if left[name] != right[name]:
            raise ValueError(f'Conflicting root/plugin dependency policy for {name}; review manually')
    return left | right


def runtime_manifest(source, selected):
    root = json.loads((source / 'package.json').read_text())
    plugin = json.loads((source / 'plugin/package.json').read_text())
    if root['version'] != selected or plugin['version'] != selected:
        raise ValueError('Root/plugin versions do not match the selected release')
    return {
        'name': 'claude-mem', 'version': selected, 'private': True, 'type': 'module',
        'dependencies': merge(root.get('dependencies', {}), plugin.get('dependencies', {})),
        'overrides': merge(root.get('overrides', {}), plugin.get('overrides', {})),
        # Root engines describe the published package; plugin ranges may lag.
        'engines': plugin.get('engines', {}) | root.get('engines', {}),
    }


def validate_release(source, staging):
    required = [
        'plugin/scripts/worker-service.cjs', 'plugin/scripts/mcp-server.cjs',
        'plugin/scripts/claude-mem-launcher.cjs', 'plugin/bun.lock',
        'dist/opencode-plugin/index.js', 'plugin/skills/mem-search/SKILL.md',
        'plugin/skills/smart-explore/SKILL.md',
    ]
    for name in required:
        if not (source / name).is_file():
            raise ValueError(f'Release is missing {name}')
    # Storage-engine/bridge changes need an explicit Python/model packaging
    # update, not just new JavaScript hashes. Keep these tied to chroma.nix.
    worker = (source / required[0]).read_text()
    bridge_version = re.search(r'pname = "claude-mem-chroma";\s+version = "([^"]+)";',
                               (HERE / 'chroma.nix').read_text())[1]
    variable = re.search(r'`chroma-mcp==\$\{([A-Za-z_$][\w$]*)\}`', worker)
    if not variable or not re.search(r'\b' + re.escape(variable[1]) +
                                     r'="' + re.escape(bridge_version) + r'"', worker):
        raise ValueError('Chroma bridge pin changed; review chroma.nix before updating')
    for constraint in ('chromadb==1.5.9', 'onnxruntime>=1.20', 'pydantic<2.14'):
        if json.dumps(constraint) not in worker:
            raise ValueError(f'Chroma constraint changed: {constraint}; review manually')
    out = staging / 'validated'
    destination = out / 'share/claude-mem'
    destination.parent.mkdir(parents=True)
    shutil.copytree(source, destination)
    (out / 'bin').mkdir()
    # Run our actual adaptation assertions, but skip compilation/dependency
    # installation. Only our Python code executes; all writes are in staging.
    subprocess.run([sys.executable, str(HERE / 'prepare.py'), str(out),
                    '/nix/validation/codex', '/bin/sh', '/nix/validation/chroma-mcp',
                    '/nix/validation/ca-bundle.crt', '--validate-only'], check=True)


def replace_one(text, pattern, replacement):
    text, count = re.subn(pattern, lambda _: replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f'Expected exactly one package field matching {pattern!r}, got {count}')
    return text


def package_text(original, selected, archive_hash, dependency_hash):
    text = replace_one(original, r'^  version = .*;$', f'  version = "{selected}";')
    text = replace_one(text, r'^    hash = .*;$', f'    hash = "{archive_hash}";')
    return replace_one(text, r'^  npmDepsHash = .*;$', f'  npmDepsHash = "{dependency_hash}";')


def tools():
    # Use this repository's locked nixpkgs for Node, the dependency fetcher's
    # cache format, and nixfmt. Never resolve a moving nixpkgs channel here.
    expression = (
        'let f = builtins.getFlake ' + json.dumps(str(REPO)) + '; '
        'p = f.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; '
        'in p.symlinkJoin { name = "claude-mem-update-tools"; '
        'paths = [ p.nodejs_24 p.prefetch-npm-deps p.nixfmt ]; }'
    )
    output = subprocess.check_output([
        'nix', '--extra-experimental-features', 'nix-command flakes', 'build',
        '--impure', '--no-link', '--print-out-paths', '--expr', expression,
    ], text=True).strip()
    return Path(output) / 'bin'


def publish(candidates, originals):
    # Do all network, lock/hash generation, formatting, and validation before
    # replacing anything. Refuse to overwrite edits made during the update.
    if any(path.read_bytes() != old for path, old in originals.items()):
        raise ValueError('Package files changed during the update; refusing to overwrite them')
    staged = {}
    try:
        for path, content in candidates.items():
            with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name + '.',
                                              delete=False) as output:
                staged[path] = Path(output.name)
                output.write(content)
            staged[path].chmod(path.stat().st_mode & 0o777)
        for path, temporary in staged.items():
            os.replace(temporary, path)
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version', nargs='?', type=version, help='release version (default: latest)')
    parser.add_argument('--dry-run', action='store_true', help='validate/generate without replacing files')
    args = parser.parse_args(argv)
    if not hasattr(tarfile, 'data_filter'):
        raise ValueError('The updater requires Python with tarfile.data_filter (Python 3.12+)')
    metadata = json.loads(download(REGISTRY + (args.version or 'latest')))
    selected = version(metadata['version'])
    if args.version and selected != args.version:
        raise ValueError('Registry returned a different release version')
    # Construct the official URL instead of trusting an arbitrary metadata URL.
    archive = download(REGISTRY + f'-/claude-mem-{selected}.tgz')
    verify_integrity(archive, metadata['dist']['integrity'])
    archive_hash = 'sha256-' + base64.b64encode(hashlib.sha256(archive).digest()).decode()
    targets = [HERE.parent / 'claude-mem.nix', HERE / 'package.json', HERE / 'package-lock.json']
    originals = {path: path.read_bytes() for path in targets}
    with tempfile.TemporaryDirectory(prefix='claude-mem-update-') as temporary:
        staging = Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as release:
            release.extractall(staging, filter='data')
        source = staging / 'package'
        manifest = runtime_manifest(source, selected)
        validate_release(source, staging)
        tool_bin = tools()
        locked = staging / 'locked'
        locked.mkdir()
        manifest_path = locked / 'package.json'
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        lock_path = locked / 'package-lock.json'
        lock_path.write_bytes(originals[targets[2]])
        subprocess.run([str(tool_bin / 'npm'), 'install', '--package-lock-only',
                        '--ignore-scripts', '--legacy-peer-deps', '--engine-strict',
                        '--no-audit', '--no-fund'], cwd=locked, check=True,
                       env=os.environ | {'PATH': str(tool_bin) + os.pathsep + os.environ['PATH']})
        dependency_hash = subprocess.check_output([
            str(tool_bin / 'prefetch-npm-deps'), str(lock_path),
        ], text=True).strip()
        if not re.fullmatch(r'sha256-[A-Za-z0-9+/]{43}=', dependency_hash):
            raise ValueError('Dependency fetcher did not return a SHA-256 SRI hash')
        updated = staging / 'claude-mem.nix'
        updated.write_text(package_text(originals[targets[0]].decode(), selected,
                                         archive_hash, dependency_hash))
        subprocess.run([str(tool_bin / 'nixfmt'), str(updated)], check=True)
        candidates = dict(zip(targets, [updated.read_bytes(), manifest_path.read_bytes(), lock_path.read_bytes()]))
        if not args.dry_run:
            publish(candidates, originals)
    print(f'{"Validated (dry run)" if args.dry_run else "Updated"} claude-mem {selected}')
    print('Build the individual package and run packages/claude-mem/runtime-smoke.py before applying.')
    print('Back up memory state before upgrades; review changed Codex hook definitions after activation.')


if __name__ == '__main__':
    try:
        main(sys.argv[1:] or shlex.split(os.environ.get('CLAUDE_MEM_UPDATE_ARGS', '')))
    except (OSError, ValueError, AssertionError, argparse.ArgumentTypeError,
            tarfile.TarError, subprocess.CalledProcessError) as error:
        sys.exit(f'claude-mem update failed: {error}')
