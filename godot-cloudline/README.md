# Cloudline Godot migration preview 0.2.0

A real Godot 4.6.3 / GDScript port of Cloudline, based on PortFWeb main
`7e5c0cb345ba98faf98fddf263a325ae2103eb94` (existing `/cloudline/` production unchanged).
Native desktop is the primary development/QA target. `/cloudline-godot/` is an independent,
single-threaded Compatibility Web export for phone playtesting.

## Run

Open `project.godot` in Godot 4.6.3 and press F6/F5, or `godot --path godot-cloudline`.
Use landscape on phones. Portrait shows rotation guidance and pauses until explicitly resumed.
Compact controls target at least 44 CSS pixels at 844×390; settings/menu content scrolls.
This layout is tested synthetically/native-size, not accepted on a real phone. Web requires WebGL 2 and WASM; no COOP/COEP isolation headers are required.
The engine WASM is about 36 MiB uncompressed, so the first load may take time.

## Play

- A320 BKI → CAN T3, CAN approach, CAN taxi starts
- Three aircraft (A320, L-4, J-120) in island free flight, original ring lesson, runway takeoff and landing practice
- Left stick: pull down to pitch up, left/right bank; right slider: throttle; independent touch contacts
- Keyboard: arrows/WASD, Q/E rudder, +/- throttle, Space brake, G gear, F flaps, C camera, Esc pause
- Tutorial guide defaults OFF; stick/rudder/brake/throttle takes over. Route shortcuts preserve phase setup
- AP holds altitude, heading and IAS, never automatic landing or obstacle avoidance
- SYS panel: engine, speedbrake, stability assist, trim, AP targets/apply and airport-bearing return
- SYS → ENVIRONMENT: live weather, day/golden/night, opt-in engine sound, inversion, sensitivity, quality, fullscreen
- MAP/minimap: terrain, runway, taxi path and lesson gates; BKI → CAN schematic is illustrative, not real ATC navigation
- PFD: attitude, magnetic-style airport-offset heading, airport bearing, engine spool and fuel
- Focus loss pauses; resume explicitly. Menu/restart/pause clear held touch controls
- Four cameras with drag look/zoom; landing safety checks and scoring; airport collision geometry; SIM-T3 taxi/parking completion

Route guidance is intentionally A320-only: it uses source A320 speeds/procedures. Other aircraft remain selectable in island modes.

## Migration status

| Area | Preview status |
| --- | --- |
| Force-based flight / 3 aircraft / weather / AP / fuel / stalls / crashes | Ported from original JS |
| BKI → CAN route, all 8 phases, ×128 cruise progress, guide, skips, parking | Ported |
| Original island lessons / runway / landing / free modes | Ported |
| Touch HUD, keyboard, pause/focus, menu | Rebuilt natively |
| Aircraft, BKI/CAN terminals, runway/taxi markings, terrain/clouds | Native procedural approximations; not mesh-identical |
| Engine, speedbrake, trim, assist, adjustable AP | Available in SYS |
| Terrain minimap, airport map, BKI/CAN route schematic | Ported |
| Attitude/compass, airport bearing, engine N1/RPM, fuel/AP PFD | Ported |
| Opt-in engine sound, day/golden/night, live weather | Ported; native rendered lighting checked, device audio listening unverified |
| Sensitivity/inversion, camera drag/zoom, quality and fullscreen controls | Ported |
| Exact mesh appearance, elaborate end-of-flight report/help and saved preferences | Simplified/not yet identical |
| Browser WebGL / real iPhone/Safari/Android graphics + performance | Not verified in this cloud environment |

This is a playable migration preview, not full UI/visual parity. Airports, route procedures,
aircraft dynamics and SIM-T3 are simplified game approximations, not real flight training.
Native terrain uses the source analytic height functions; decorative city buildings have no collisions,
while main terminals, CAN pier buildings and tower do. Water/ground and runway checks remain in flight model.

## Verification

```
godot --headless --path godot-cloudline --script scripts/test_flight_model.gd
godot --headless --path godot-cloudline --script tests/test_route.gd
godot --headless --path godot-cloudline --script tests/integration.gd
godot --headless --path godot-cloudline --script tests/test_ui.gd
godot --headless --path godot-cloudline --script tests/test_navigation.gd
godot --headless --path godot-cloudline --script tests/test_environment_audio.gd
godot --headless --path godot-cloudline --script tests/test_parity_ui.gd
```

- 44 physics checks, including nine comparisons to original JavaScript; max position difference 1.35 cm after 30 s
- 52 route state/control checks
- A320 all three route starts complete and park with terminal/tower/CAN wing collision geometry enabled
- 18 core UI/control checks, including dual-touch and pause/release/resume regression
- 74 navigation checks, including all airport/mode drawing callbacks and read-only simulation state
- 62 environment/audio headless checks; 74 with ALSA null sink (no speakers) to test stream lifecycle
- 127 additional parity UI checks for maps, settings, cameras, AP, approach guidance, 44-CSS-pixel touch targets at 844×390, no button overlap, scrollable modals, and portrait pause/rotation guard
- Native Godot renderer manually inspected; menu/start/guide takeoff, systems, cameras and phase navigation exercised
- Browser graphics are explicitly untested, not passed

## Export

Install official Godot 4.6.3 export templates, then:

```
godot --headless --path godot-cloudline --export-release Web
```

Export preset outputs `../cloudline-godot/index.html` and companion files. Deploy the whole directory
atomically beneath the existing static repository root. Do not replace `/cloudline/` or change Render settings.
Do not serve `godot-cloudline/.godot` caches. `release-manifest.json` records exact artifact checksums.
Tests are excluded from Web export. Templates are not committed.

The subset UI font is derived from Noto Sans CJK (SIL OFL 1.1); see assets/FONT-LICENSE.txt.
Godot engine is MIT licensed; see https://godotengine.org/license/.
