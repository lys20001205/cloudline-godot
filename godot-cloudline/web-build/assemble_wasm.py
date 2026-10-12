#!/usr/bin/env python3
"""Rebuild the exact Godot Web engine from verified repository chunks."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import tempfile


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def assemble(support_dir, output):
    support_dir, output = Path(support_dir), Path(output)
    manifest = json.loads((support_dir / 'engine-manifest.json').read_text())
    compressed = bytearray()
    if 'gzip_file' in manifest:
        name = manifest['gzip_file']
        if Path(name).name != name:
            raise ValueError('Invalid gzip filename')
        compressed.extend((support_dir / name).read_bytes())
    for entry in manifest.get('chunks', []):
        name = entry['name']
        if Path(name).name != name:
            raise ValueError('Invalid chunk name')
        data = (support_dir / 'engine-chunks' / name).read_bytes()
        if len(data) != entry['bytes'] or sha256(data) != entry['sha256']:
            raise ValueError('Engine chunk integrity failure: ' + name)
        compressed.extend(data)
    if len(compressed) != manifest['gzip_bytes'] or sha256(compressed) != manifest['gzip_sha256']:
        raise ValueError('Compressed engine integrity failure')
    wasm = gzip.decompress(compressed)
    if len(wasm) != manifest['wasm_bytes'] or sha256(wasm) != manifest['wasm_sha256']:
        raise ValueError('Decompressed engine integrity failure')
    if not wasm.startswith(b'\x00asm\x01\x00\x00\x00'):
        raise ValueError('Invalid WebAssembly header')
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix='.wasm-', delete=False) as target:
            temporary = target.name
            target.write(wasm)
        os.replace(temporary, output)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
    print('Verified Godot Web engine:', manifest['wasm_sha256'], len(wasm), 'bytes')
    return manifest['wasm_sha256']


if __name__ == '__main__':
    here = Path(__file__).resolve().parent
    assemble(here, here.parents[1] / 'cloudline-godot' / 'index.wasm')
