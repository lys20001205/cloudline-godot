#!/usr/bin/env python3
"""Sync persistent mobile shell/assets after Godot export, without repacking game.

Uses the exported Engine configuration; never changes the PCK, JS engine or WASM.
Run before freezing release-manifest.json. Relative URLs preserve project scope.
"""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'godot-cloudline/web-shell'
OUTPUT = ROOT / 'cloudline-godot'

def sync():
    exported = (OUTPUT / 'index.html').read_text()
    match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', exported)
    if not match:
        raise SystemExit('Exported GODOT_CONFIG was not found; export with Godot first')
    config = json.loads(match.group(1))
    # A pack-only Godot export can change PCK size without rewriting index.html.
    for name in config.get('fileSizes', {}):
        artifact = OUTPUT / name
        if artifact.exists():
            config['fileSizes'][name] = artifact.stat().st_size
    config['canvasResizePolicy'] = 0
    config['ensureCrossOriginIsolationHeaders'] = False
    if config.get('serviceWorker'):
        raise SystemExit('Unexpected service worker; this online-only shell does not use one')
    preset = (ROOT / 'godot-cloudline/export_presets.cfg').read_text()
    head = json.loads(re.search(r'^html/head_include=(.*)$', preset, re.M).group(1))
    project = (ROOT / 'godot-cloudline/project.godot').read_text()
    title = json.loads(re.search(r'^config/name=(.*)$', project, re.M).group(1))
    html = (SOURCE / 'index.html').read_text()
    for key, value in {'$GODOT_PROJECT_NAME': title, '$GODOT_HEAD_INCLUDE': head,
                       '$GODOT_URL': config['executable'] + '.js',
                       '$GODOT_CONFIG': json.dumps(config, separators=(',', ':'))}.items():
        html = html.replace(key, value)
    (OUTPUT / 'index.html').write_text(html)
    for name in ['manifest.webmanifest', 'cloudline-180.png', 'cloudline-192.png', 'cloudline-512.png']:
        shutil.copyfile(SOURCE / name, OUTPUT / name)
    print('Synced mobile shell and assets; game and engine binaries unchanged')

if __name__ == '__main__':
    sync()
