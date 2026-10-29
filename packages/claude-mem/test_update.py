import argparse
import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import update


class UpdateTests(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(update.version('v13.40.0'), '13.40.0')
        self.assertEqual(update.version('13.41.0-beta.1'), '13.41.0-beta.1')
        for value in ('latest', '../13.40.0', '13.40.0;echo bad', '13.40', ''):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                update.version(value)

    def test_archive_integrity(self):
        data = b'published archive'
        integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
        update.verify_integrity(data, integrity)
        with self.assertRaises(ValueError):
            update.verify_integrity(b'changed archive', integrity)
        with self.assertRaises(ValueError):
            update.verify_integrity(data, 'sha1-not-strong-enough')

    def test_dependency_conflicts_require_review(self):
        self.assertEqual(update.merge({'a': '1'}, {'a': '1', 'b': '2'}), {'a': '1', 'b': '2'})
        with self.assertRaises(ValueError):
            update.merge({'a': '1'}, {'a': '2'})

    def test_root_engines_win(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            (source / 'plugin').mkdir()
            (source / 'package.json').write_text(json.dumps({
                'version': '1.0.0', 'engines': {'node': '^20.19.0 || >=22.12.0'},
            }))
            (source / 'plugin/package.json').write_text(json.dumps({
                'version': '1.0.0', 'engines': {'node': '>=20.12.0', 'bun': '>=1.1.31'},
            }))
            self.assertEqual(update.runtime_manifest(source, '1.0.0')['engines'], {
                'node': '^20.19.0 || >=22.12.0', 'bun': '>=1.1.31',
            })

    def test_combined_runtime_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            (source / 'plugin').mkdir()
            (source / 'package.json').write_text(json.dumps({
                'version': '13.40.0', 'dependencies': {'auth': '^1'},
                'devDependencies': {'bundler': '*'}, 'overrides': {'tmp': '^2'},
            }))
            plugin = source / 'plugin/package.json'
            plugin.write_text(json.dumps({'version': '13.40.0', 'dependencies': {'parser': '2'}}))
            manifest = update.runtime_manifest(source, '13.40.0')
            self.assertEqual(manifest['dependencies'], {'auth': '^1', 'parser': '2'})
            self.assertEqual(manifest['overrides'], {'tmp': '^2'})
            self.assertNotIn('devDependencies', manifest)
            plugin.write_text('{"version":"13.39.0"}')
            with self.assertRaises(ValueError):
                update.runtime_manifest(source, '13.40.0')

    def test_nix_updates_are_scoped(self):
        original = ('  version = "13.40.0";\n    hash = "old-source";\n'
                    '  npmDepsHash = "old-deps";\n  description = "keep me";\n')
        result = update.package_text(original, '13.41.0', 'new-source', 'new-deps')
        self.assertIn('version = "13.41.0";', result)
        self.assertIn('hash = "new-source";', result)
        self.assertIn('npmDepsHash = "new-deps";', result)
        self.assertIn('description = "keep me";', result)
        for malformed in ('', original + '    hash = "ambiguous";\n'):
            with self.assertRaises(ValueError):
                update.package_text(malformed, '13.41.0', 'new', 'new')

    def test_publish_refuses_concurrent_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = [Path(tmp) / 'package.nix', Path(tmp) / 'package-lock.json']
            for path in paths:
                path.write_bytes(b'original')
            originals = {path: path.read_bytes() for path in paths}
            paths[1].write_bytes(b'user edit')
            with self.assertRaises(ValueError):
                update.publish({path: b'updated' for path in paths}, originals)
            self.assertEqual(paths[0].read_bytes(), b'original')
            self.assertEqual(paths[1].read_bytes(), b'user edit')

    def test_publish_preserves_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'package.nix'
            path.write_bytes(b'original')
            path.chmod(0o640)
            update.publish({path: b'updated'}, {path: b'original'})
            self.assertEqual(path.read_bytes(), b'updated')
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
            self.assertEqual(list(Path(tmp).iterdir()), [path])


if __name__ == '__main__':
    unittest.main()
