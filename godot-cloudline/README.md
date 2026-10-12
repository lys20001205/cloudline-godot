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
| A320 visual | Imported CC BY 4.0 mesh by amvlab; textured fuselage, engine fans, windows, doors and panel lines |
| L-4/J-120, BKI/CAN terminals, runway/taxi markings, terrain/clouds | Procedural game approximations; airport facades/materials refined |
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

## Mobile display shell (Android + iPhone)

- The HTML toolbar is available during loading and after exiting fullscreen. On browsers
  exposing the Fullscreen API, its button requests fullscreen synchronously on the user's tap.
  Rejections display retry and home-screen guidance; unsupported browsers get home-screen help.
- iPhone: open in Safari, Share → Add to Home Screen (enable Open as Web App if offered),
  then launch the Cloudline icon. Android also supports its browser's install/add-to-home-screen flow.
  This is standalone browser-chrome removal, not a promise to hide every system status/gesture bar.
- The manifest uses relative `id`, `scope`, `start_url`, and icon URLs, resolving beneath
  `/cloudline-godot/`. No service worker or offline asset cache is installed. Internet is required.
  Single-threaded rendering stays unchanged and needs no new COOP/COEP headers.
- Safe-area padding and a reserved 44 px toolbar protect the game from cutouts and toolbar overlap.
  Canvas backing dimensions follow the available viewport using Godot resize policy 0.
- `web-shell/index.html` is the persistent custom export template. After any Godot export run:
  `python3 godot-cloudline/web-build/sync_mobile_shell.py`
  This also copies the manifest and icons, and can update the shell without repacking the game.
  Freeze checksums only after this sync. The Web SYS fullscreen button uses the same shell controller; native fullscreen stays unchanged.
  Only HUD routing and its small PCK were rebuilt; engine JS/WASM and flight logic are unchanged.
  For pack-only updates: `godot --headless --path godot-cloudline --export-pack Web ../cloudline-godot/index.pck`,
  then run the sync script (it also refreshes PCK file size).
- Shell state regression: `node godot-cloudline/web-build/test_mobile_state.cjs`
  Browser smoke (Playwright/Chromium required): `node godot-cloudline/web-build/test_mobile_shell.cjs`
  These test the HTML shell, not Godot WebGL rendering or real-device performance.

The mobile shell has passed deterministic controller tests and the original headless Godot suites.
The browser smoke could not run in this executor (Chromium local socket creation is restricted;
its localhost is unreachable from the separate cloud browser). Real Android Chrome and iPhone
Safari/home-screen installation, safe-area rendering, audio, and 3D touch/performance still need testing.

Implementation references: [Godot custom HTML shell](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html),
[WebKit home-screen web apps](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/),
[Safari 26 home-screen behavior](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/).

Fullscreen and installed standalone play hide the page toolbar and its blue background. Only device safe-area insets remain (black) to protect edge controls. Browser/system exit or the in-game SYS fullscreen toggle leaves fullscreen and restores the ordinary toolbar. In an installed app, SYS can still open installation/display help. The shell uses the available safe-area viewport without changing the game aspect policy.


## Real-model art slice (A320)

This release replaces only the A320 primitive placeholder with a genuine imported
GLB by [amvlab](https://github.com/amvlab/aircraft-models), licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Original GLB bytes are
unchanged. See `assets/models/a320/ATTRIBUTION.txt` and the game's menu credits.
The asset has one mesh/material, 5,229 triangles, a 1,024² atlas, and is 250,472 bytes.
Godot generated mesh LODs. The model has static control surfaces; procedural gear
is separately attached so the existing G/touch gear behavior still works.
The generic visual is not a certified A320-216 configuration. Physics, controls,
runway checks, collision geometry and camera settings are unchanged.

L-4 and J-120 remain the existing procedural approximations. Airport buildings are
also procedural, with facade glazing/mullions, stand lines and taxi edge lights.
Terrain gets multi-scale color variation; pavement gets grain, slab seams and
subtle touchdown rubber marks. There are no new downloaded airport assets.
Static airport boxes are batched by material into MultiMeshes rather than
individual draw calls; their original positions and collision definitions remain.

### Art verification

- All existing headless suites pass: 44 physics, 52 route, 18 core UI, 74 navigation,
  62 environment/audio, 131 parity UI, and three full collision-aware route starts
- 15 new `tests/test_art_assets.gd` checks validate actual imported topology,
  atlas dimensions, meter scale, nose orientation, gear separation, fallback planes,
  batching and unchanged simulation state
- 36 deterministic mobile-shell checks pass; prior immersive fullscreen source is unchanged
- Deterministic native screenshots at 1280×720 use `tests/capture_visuals.gd`
  (requires a graphical renderer; explicitly rejects headless)
- Native graphical renderer: Godot 4.6.3 Compatibility, X11, Mesa llvmpipe software
- Browser WebGL, real iPhone/Android graphics, thermal behavior, touch responsiveness
  and device frame rate remain unverified; native rendering is not a mobile pass
- Existing cloud-native renderer emits two small texture cleanup warnings at exit in
  both before and after builds; no new model import or shader errors were observed

Native draw calls / triangles for identical camera views (before → after):

| View | Draw calls | Visible primitives |
| --- | --- | --- |
| A320 ground view | 97 → 34 | 28,576 → 33,737 |
| CAN approach with HUD | 439 → 191 | 51,018 → 55,411 |
| CAN airport | 176 → 48 | 31,500 → 35,585 |

These are scene measurements, not a general performance guarantee. The full 1K
A320 atlas needs about 5.33 MiB RGBA8 including mipmaps before renderer compression.
The shipped Web engine is unchanged; only the content PCK and its size/checksum are
updated. Exact download sizes and frozen source/artifact SHA-256 values are in
`cloudline-godot/release-manifest.json`.
