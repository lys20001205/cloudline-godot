#!/usr/bin/env python3
"""Check static mobile export contract using only the Python standard library."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import unittest
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'cloudline-godot'
SRC = ROOT / 'godot-cloudline/web-shell'

class MobileExportTests(unittest.TestCase):
    def test_scoped_manifest(self):
        manifest = json.loads((OUT / 'manifest.webmanifest').read_text())
        base = 'https://lys20001205.github.io/cloudline-godot/manifest.webmanifest'
        for key in ['id', 'start_url', 'scope']:
            self.assertEqual(urljoin(base, manifest[key]), 'https://lys20001205.github.io/cloudline-godot/')
        self.assertEqual(manifest['display'], 'standalone')
        for icon in manifest['icons']:
            width, height = struct.unpack('>II', (OUT / icon['src']).read_bytes()[16:24])
            self.assertEqual(icon['sizes'], f'{width}x{height}')

    def test_web_and_native_fullscreen_routes(self):
        hud = (ROOT / 'godot-cloudline/scripts/hud.gd').read_text()
        handler = hud.split('fullscreen.pressed.connect(func():', 1)[1].split('col.add_child(fullscreen)', 1)[0]
        self.assertIn('OS.has_feature("web")', handler)
        self.assertIn('JavaScriptBridge.eval("window.cloudlineDisplay.toggle()")', handler)
        self.assertIn('else:', handler)
        self.assertIn('DisplayServer.window_set_mode', handler)
        self.assertNotIn('await', handler)

    def test_source_assets_match(self):
        for name in ['manifest.webmanifest', 'cloudline-180.png', 'cloudline-192.png', 'cloudline-512.png']:
            self.assertEqual((SRC / name).read_bytes(), (OUT / name).read_bytes())
        self.assertFalse(list(OUT.glob('*.import')))

    def test_sync_is_idempotent_and_preserves_game(self):
        paths = [OUT / name for name in ['index.html', 'index.js', 'index.pck']]
        before = [hashlib.sha256(p.read_bytes()).digest() for p in paths]
        spec = importlib.util.spec_from_file_location('mobile_sync', Path(__file__).with_name('sync_mobile_shell.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.sync()
        self.assertEqual(before, [hashlib.sha256(p.read_bytes()).digest() for p in paths])
        html = (OUT / 'index.html').read_text()
        self.assertNotIn('$GODOT_', html)
        self.assertNotIn('serviceWorker.register', html)
        self.assertIn('GODOT_CONFIG.ensureCrossOriginIsolationHeaders = false;', html)
        self.assertIn('viewport-fit=cover', html)
        self.assertIn('apple-mobile-web-app-capable', html)

if __name__ == '__main__':
    unittest.main()
