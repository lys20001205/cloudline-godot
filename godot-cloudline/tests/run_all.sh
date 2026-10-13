#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for test in scripts/test_flight_model.gd tests/test_route.gd tests/integration.gd tests/test_ui.gd tests/test_navigation.gd tests/test_environment_audio.gd tests/test_parity_ui.gd tests/test_art_assets.gd tests/test_bki_geodata.gd; do
  godot --headless --path . --script "$test"
done
