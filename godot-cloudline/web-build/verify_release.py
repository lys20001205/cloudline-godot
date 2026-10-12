#!/usr/bin/env python3
"""Verify all frozen Godot source and playable files before publication."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
manifest = json.loads((root / 'cloudline-godot/release-manifest.json').read_text())
for name, expected in manifest['source'].items():
    data = (root / name).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit('Source checksum mismatch: ' + name)
for name, expected in manifest['artifacts'].items():
    data = (root / 'cloudline-godot' / name).read_bytes()
    if len(data) != expected['bytes'] or hashlib.sha256(data).hexdigest() != expected['sha256']:
        raise SystemExit('Artifact checksum mismatch: ' + name)
print('Verified', len(manifest['source']), 'source files and', len(manifest['artifacts']), 'Web artifacts')
