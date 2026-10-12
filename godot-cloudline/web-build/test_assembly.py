#!/usr/bin/env python3
"""Build verification and fail-closed regression tests; Python standard library only."""
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from assemble_wasm import assemble


class EngineAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'engine-chunks').mkdir()
        self.output = self.root / 'out' / 'index.wasm'
        self.output.parent.mkdir()
        self.output.write_bytes(b'original')
        self.wasm = b'\x00asm\x01\x00\x00\x00' + b'fixture' * 20
        self.gzip = gzip.compress(self.wasm, mtime=0)
        self.name = 'engine-000.gzpart'
        (self.root / 'engine-chunks' / self.name).write_bytes(self.gzip)
        h = lambda b: hashlib.sha256(b).hexdigest()
        self.manifest = {'gzip_bytes': len(self.gzip), 'gzip_sha256': h(self.gzip),
                         'wasm_bytes': len(self.wasm), 'wasm_sha256': h(self.wasm),
                         'chunks': [{'name': self.name, 'bytes': len(self.gzip), 'sha256': h(self.gzip)}]}
        self.save()

    def tearDown(self):
        self.temp.cleanup()

    def save(self):
        (self.root / 'engine-manifest.json').write_text(json.dumps(self.manifest))

    def assert_rejected(self):
        with self.assertRaises((ValueError, FileNotFoundError, gzip.BadGzipFile)):
            assemble(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), b'original')
        self.assertEqual(list(self.output.parent.glob('.wasm-*')), [])

    def test_exact_reconstruction(self):
        assemble(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), self.wasm)

    def test_repeated_build(self):
        assemble(self.root, self.output)
        assemble(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), self.wasm)

    def test_corrupted_chunk(self):
        (self.root / 'engine-chunks' / self.name).write_bytes(b'corrupted')
        self.assert_rejected()

    def test_missing_chunk(self):
        (self.root / 'engine-chunks' / self.name).unlink()
        self.assert_rejected()

    def test_compressed_hash(self):
        self.manifest['gzip_sha256'] = '0' * 64
        self.save()
        self.assert_rejected()

    def test_decompressed_hash(self):
        self.manifest['wasm_sha256'] = '0' * 64
        self.save()
        self.assert_rejected()

    def test_output_size(self):
        self.manifest['wasm_bytes'] += 1
        self.save()
        self.assert_rejected()

    def test_path_traversal(self):
        self.manifest['chunks'][0]['name'] = '../outside'
        self.save()
        self.assert_rejected()

    def test_empty_chunks(self):
        self.manifest['chunks'] = []
        self.save()
        self.assert_rejected()

    def single_gzip(self):
        self.manifest.pop('chunks')
        self.manifest['gzip_file'] = 'engine.wasm.gz'
        (self.root / 'engine.wasm.gz').write_bytes(self.gzip)
        self.save()

    def test_single_gzip(self):
        self.single_gzip()
        assemble(self.root, self.output)
        self.assertEqual(self.output.read_bytes(), self.wasm)

    def test_corrupt_single_gzip(self):
        self.single_gzip()
        (self.root / 'engine.wasm.gz').write_bytes(b'corrupt')
        self.assert_rejected()

    def test_gzip_path_traversal(self):
        self.single_gzip()
        self.manifest['gzip_file'] = '../outside'
        self.save()
        self.assert_rejected()


if __name__ == '__main__':
    unittest.main()
