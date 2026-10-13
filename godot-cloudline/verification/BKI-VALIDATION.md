# BKI scenery validation

Base commit d6d6c352e7ea636e3ceb066db6de9cb05b7be507. No deployment is implied by this staged report.

## Correctness

All9 Godot regression suites passed: flight44 checks, route52, route-start integration3 scenarios, UI18, navigation74, environment/audio62 (headless, not heard), parity UI131, asset26, and new geographic70. The three route starts finish at the gate without crashing. Geographic tests cover OSM endpoint alignment, offshore masking, runway elevation, compact-profile selection, map triangle and building budgets, spatial collision lookup, and StandardMaterial geometry.

Web controller74 checks, static export4, verified engine assembly12 checks passed. Existing shell unchanged apart from generated PCK file size. Native exported pack startup smoke test passed. Chromium shell integration could not launch because the executor disallows its Unix socket; this is a test-environment limitation, not a passing browser test. Actual Safari/iOS GPU performance remains unverified.

Independent geometry review checked land/water bounds, source licensing and data access, exact runway transform, duplicate-free source ways, upward normals, no runway-overlapping building bounds, and clipped roads. OSM and terrain source/derivative data are distributed in the separate map-data ZIP linked from credits.

## Native rendering measurements

Compatibility renderer, Godot4.6.3, Mesa llvmpipe software rendering,1280×720=921,600 pixels, conservative materials and3D scale1.0. Capture positions are in tests/capture_bki.gd; geographic survey-camera X values were reflected with the corrected coordinate basis. Measurements are illustrative snapshots, not a controlled device benchmark.

Original / dense real-world / compact real-world:
- Ground aircraft draws:34 /31 /31; rendered primitives33,737 /18,032 /14,104
- Airport overview draws:50 /39 /39; rendered primitives33,009 /58,102 /26,528
- Coastal overview draws:58 /53 /53; rendered primitives35,313 /104,569 /48,356
- Reported GPU memory bytes:23,740,691 /28,249,257 /23,968,281
- Observed software FPS, ground:52 /57 /66; airport:45 /31 /47; coastal:44 /19 /32

These early compact measurements preceded the final airport-edge terrain split (+72 compact triangles). Final exact-pack independent captures should be consulted alongside this report. The dense desktop version increases geometry and costs software-renderer performance; Safari/mobile therefore automatically uses600 mapped buildings and approximately39k map triangles. Ordinary desktop keeps approximately96k map triangles. No new runtime textures, shaders, satellite tiles, APIs or streaming are used.

The source PCK grows from1,029,444 bytes to 4,347,656 bytes because it contains both selectable offline detail levels. The separate source ZIP is user-triggered, not fetched at startup. The37,700,666-byte Web engine is byte-identical. The old1M-pixel/DPR1.5 Safari cap and standard-material fallback are intact.

Native runs show the same two349,524-byte GL texture shutdown-leak warnings seen in the earlier baseline; no script/shader errors were observed. The warning is recorded rather than presented as a clean GL shutdown. Native geometry QA does not prove Safari startup or mobile frame rate.

## Handedness and final controls

Independent actual-camera review identified and corrected the early geographic X-handedness before release. Godot camera-right is−X when flying+Z; BKI projection, coastline side classification, mesh normals, terrain inverse, airport grading, colliders, pavement classification and map/compass/AP presentation now share that convention. The map is true-north-up and the source runway bearing is22.807383°, with displayed heading equal to this reference minus simulation yaw. New camera/cardinal/AP round-trip tests pass.

BKI manual roll/rudder commands are bridged once at the UI boundary, before route guidance/AP computation; the physics model and other scene inputs are unchanged. Left and right tests check ground motion, heading, actual banked-wing geometry and PFD sign. The complete geography/control suite has70 assertions. This is more specific than claiming all historical scene control conventions were reworked.

The earlier benchmark snapshots in this report are pre-final-orientation comparative measurements. The final exact-PCK independent capture/report supersedes them for the released scene. No Web/iOS hardware validation is implied.

## Final exact-pack evidence (release candidate)

PCK SHA256:7777f1490be334b6b708325817a80fa04264f0b78a0c3634438c8124c0cc894d. Independent verification is in `bki-independent-native.json`; final renderer samples are in `bki-final-pack-native.json`.

The independent final run passed startup/menu/assets, both runway approach directions, sea-left on02 departure / sea-right on20 approach, unobstructed runway, and actual HUD values injected through main._physics_process for both rudder and roll directions. Right rudder increased geographic heading by11.86° and moved physically right; left rudder did the opposite. Right roll lowered the real right wing; left did the opposite.

Final GPU-reported memory24,903,341 bytes (startup24,924,029). Ground/airport/coastal draws34/31/54, primitives23,849/33,690/48,506, observed software FPS52/47/33. The pre-change samples were34/50/58draws and52/45/44FPS. Ground camera is unchanged; survey-camera X values were reflected with the corrected coordinate basis to retain geographic viewpoints. These single observations vary and are not hardware-device measurements.

Final native startup menu observed19FPS without a same-menu pre-change baseline. No runtime loading/script/shader errors were observed; the known shutdown texture warnings remain. Browser/Safari/iOS device testing and the eventual public ZIP URL are still release-environment checks, not claimed passed here.
