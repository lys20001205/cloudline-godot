# BKI real-world slice: geographic data and modifications

This scenery is a bounded visual approximation for a game, not flight-navigation data or a surveyed digital twin. Data bounds: WGS84 115.98–116.12 E, 5.88–6.04 N. Beyond this rectangle the BKI scene has ocean/background; CAN and the compressed BKI–CAN mission remain authored simulations.

## Rights and attribution

© OpenStreetMap contributors. Geographic source extract and derived geographic assets in this directory are available under the Open Database License 1.0 (ODbL), not the surrounding game's code license. Full license is `source/ODbL-1.0.txt`; https://www.openstreetmap.org/copyright . The losslessly compressed machine-readable OSM extract is `source/bki_osm_raw.json.gz`. The derived geographic database, coordinate transform, binary mesh resources, sampled collision elevations, building bounds and reproduction algorithms are distributed here without charge. Godot mesh resources contain the complete modified geometry and vertex colors. Unrelated A320 and game code keep their existing licenses.

Terrain: Mapzen Terrain Tiles; SRTM/GMTED2010 courtesy of USGS; ETOPO1 courtesy of NOAA. See `source/terrain_attribution_source.md`, `source/terrain_source_manifest.json`, and `source/PROVENANCE.md` for upstream notices, URLs, dates and checksums. Source elevation sample grid is included. No Google, Apple or Bing imagery, paid tiles, accounts or runtime APIs are used.

## Honest adaptations

- OSM retrieved 2026-10-12; actual survey dates vary. The terrain mosaic objects date to 2017 and SRTM observations are predominantly from 2000
- A local east/north plane is rotated so the OSM 02/20 runway centerline points along game +Z. The midpoint is the origin. Source geometry endpoints measure approximately 3525.883 m, although the OSM length tag says3780 m. An explicit uniform similarity scale of approximately1.0720719 places them at Z=−1890/+1890 m, preserving the existing3780 m runway/gameplay contract. Relative map geometry is preserved; distance is therefore deliberately enlarged7.2%
- The OSM coastline supplies the land/ocean mask. Land polygons are formed from directed coastline edges and the exact data boundary; OSM's land-on-left convention determines the land side
- Terrain is sampled from the actual Terrarium elevation tiles. A5×5 median comparison replaces only isolated positive outliers exceeding the local median by80 m (84 source samples). Ocean is masked by the actual OSM coast. These remove an implausible1342 m source spike in ocean; the resulting collision grid's maximum is213.71 m, not a claimed independent terrain survey
- Airport ground is deliberately graded to the existing3 m game elevation inside local X=[−760,85], Z=[−2000,2000], blending over450 m. Runway markings, lights, palettes, estimated roof/facade appearance are authored illustration
- Up to1800 building footprints are selected by area and distance, then tiny/distant candidates culled. Tagged height is used when present; floor count×3 m is an estimate, and missing heights default to6 m. All heights are bounded3–120 m. These are extruded map footprints, not photogrammetry or modeled real facades. Nearby building collision bounds are conservative axis-aligned approximations, indexed into500 m cells to avoid checking every building each frame
- Roads use actual OSM centerlines, simplified12 m, with estimated widths and limited road classes. Residential roads beyond3.5 km and footpaths are omitted. Road polygons are clipped to the data boundary and actual land mask; bridges over water are omitted in this build. Taxiways/aprons are derived from OSM; runway strip and markings retain the game's exact centerline
- Terrain and detailed overlays share a baked terrain sampler. Visual land is triangulated at approximately180 m; collision height is bilinearly sampled at100 m. Coast contact between samples can differ; this is not an exact collision mesh
- All terrain, roads and buildings are offline-baked into spatial5 km district meshes with one StandardMaterial3D vertex-color surface per district. Frustum culling operates by district; this build has no dynamic per-building LOD and no texture/satellite streaming. Source statistics and final triangle count are in `metadata.json`

## Reproduction

Use Python with numpy, scipy, shapely. Decompress the source OSM extract into a staging folder as bki_osm_raw.json and copy bki_elevation_grid.json beside it. Run `python tools/bake_bki.py STAGING_FOLDER`, then `godot --headless --path . --script tools/bake_bki_meshes.gd`. Intermediate `.bin` files are reproducible and excluded from exports. Source manifests identify the original API and elevation tile checksums. Building palette and estimated heights are deterministic. The bake makes no web requests.

## Conservative Safari/mobile geometry

Safari/iOS and the existing mobile-bounded browser profile load only the separately baked `mobile/` district resources. The ordinary desktop profile keeps the full scenery. Native `--cloudline-safe-render` selects this same compact geometry for QA, in addition to its existing standard-material fallback. The shell's existing1,000,000-pixel Safari budget, DPR1.5 ceiling and3D scale1.0 are unchanged.

The compact version selects600 mapped building footprints (simplified with1.5 m tolerance), retains the runway and airport apron/taxiway layout, simplifies the resulting OSM land polygon with8 m tolerance, uses320 m terrain cells, road simplification28 m and residential-road selection within1.7 km. Road surface elevations are sampled in segments no longer than160 m. Tiny/distant footprint filtering leaves600 buildings. It contains39,257 geographic triangles, down from96,258 on desktop. Collision building cells are rebuilt from the selected profile, avoiding collisions with omitted invisible buildings; the common100 m heightfield and exact runway datum remain unchanged. The resulting surface/heightfield differences are game approximations.

Reproduce this version with `python tools/bake_bki.py STAGING_FOLDER --mobile`, then `godot --headless --path . --script tools/bake_bki_meshes.gd -- --mobile`. The OSM coast is polygonized before simplifying the final land polygon so shared coastline topology remains connected. Both profiles' complete derived geometry are included in the separate `bki-map-data.zip` download linked in credits. BKI map and compass now use the source runway bearing22.807383° with true-heading display equal to that reference minus the game yaw. BKI AP heading sliders use the exact inverse mapping. This remains a scaled, approximated game, not a navigation simulator; other airports retain their authored conventions.

Airport terrain cells are additionally cut at the grading rectangle before triangulation, preventing coarse surrounding slopes from covering the runway pavement.

### 3D handedness

Godot uses+Y up and the game flies along+Z. A camera looking+Z has local screen-right−X. Therefore map projection uses X=(north×axis_east−east×axis_north)×scale, Z=(east×axis_east+north×axis_north)×scale. Its inverse, coastline land-side classification, graded airport rectangle, building meshes/normals, collision grid and obstacle positions are baked consistently. BKI navigation converts this basis back to actual east/north for a true-north-up map; east appears on map-right and sea appears left on runway02 departure. This is a coordinate-basis conversion, not mirrored geographic scenery. Building exterior rings are consistently oriented before wall-normal calculation.

BKI taxiway/apron ground-roll classification uses the same OSM source polygons and buffered taxiway centerlines, indexed spatially. It no longer uses the old synthetic+115/+245 m taxi grid; CAN retains its existing mission taxi path.

BKI manual roll/rudder input is converted once at the UI-to-flight boundary so a right command moves toward camera-right and increases the geographic heading. The underlying force model, guided route and autopilot control math are unchanged; BKI attitude display uses the matching physical bank sign. CAN/island input conventions remain unchanged. Tests verify both left/right rudder and roll against actual camera/wing geometry.
