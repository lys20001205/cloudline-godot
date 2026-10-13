# BKI geographic reference data

Retrieved 2026-10-12 UTC for a bounded visual game scene near Kota Kinabalu International Airport, Malaysia. Requested extent (W,S,E,N): (115.98,5.88,116.12,6.04). Coordinates are WGS84 longitude/latitude degrees. No navigation or engineering accuracy is promised.

## OpenStreetMap

Source: https://api.openstreetmap.org/api/0.6/map?bbox=WEST,SOUTH,EAST,NORTH . Exact successful query bounds and source checksums are recorded in `bki_osm_raw.json` → sources; raw XML retains original bounds and object versions/timestamps. Data retrieval date is not the survey date. API responses include complete ways intersecting each query and therefore geometry can extend beyond requested bounds. Multipolygon relations may reference members outside these extracts; handle missing members explicitly.

Copyright: © OpenStreetMap contributors
License: Open Database License 1.0 (ODbL), https://opendatacommons.org/licenses/odbl/1-0/
Attribution/source information: https://www.openstreetmap.org/copyright
License text: ODbL-1.0.txt

The raw XML and extracted geographic JSON are OSM-derived databases under ODbL. For public game/repository release, include visible map-data attribution in credits/menu/splash or another suitable location, link to the copyright page and license, and provide the machine-readable derived database (including baked/modified geometry) or all modifications/reproduction algorithms under ODbL, downloadable without charge. Keep these geographic assets expressly excepted from any blanket code license. ODbL need not relicense unrelated game code. This is a practical compliance recommendation, not a determination that every arbitrary mesh is or is not a database.

Primary guidance reviewed:
- https://osmfoundation.org/wiki/Attribution_Guidelines
- https://osmfoundation.org/wiki/Licence/Community_Guidelines/Produced_Work_-_Guideline
- ODbL sections 4.2–4.6 above

`convert_osm.py` merges raw API chunks, deduplicates IDs, retains relevant ways and multipolygon membership, and adds per-way WGS84 geometry. Raw data is not geometrically simplified. Each way preserves tags and node IDs. Additional game simplification, clipping, heights, runway flattening and coordinate transforms must be documented by the implementer and included in the derivative data/reproduction method.

### Runway and building accuracy

OSM runway way https://www.openstreetmap.org/way/48760813 has ref/name 02/20, length=3780, width=45, surface=asphalt. Its current line endpoints are south lat5.9182265 lon116.0431317 and north lat5.9474563 lon116.0554894. Geometry length differs from its nominal length tag; don't quietly equate mapped line endpoints with surveyed physical pavement ends. A game alignment scaled to 3780m is an explicit artistic/gameplay adaptation. OSM accuracy and completeness vary.

`building_height_tag_counts` records actual tag presence. `height` is mapped contributor input, not a verified survey measurement. `building:levels` is floor count; converting to meters is an estimate. Missing height/level buildings need clearly labeled estimated heights. Building footprint does not imply photorealistic facade, roof, material, or use.

## Open terrain

Downloaded six zoom12 RGB Terrarium PNGs from public Mapzen/Terrain Tiles AWS (no account, API key, paid service or map imagery). Exact URLs, checksums, Last-Modified and upstream source headers are in `terrain_source_manifest.json`.

Registry: https://registry.opendata.aws/terrain-tiles/
Provider licensing/attribution: https://github.com/tilezen/joerd/blob/master/docs/attribution.md
Source/resolution documentation: https://github.com/tilezen/joerd/blob/master/docs/data-sources.md
Encoding: https://github.com/tilezen/joerd/blob/master/docs/formats.md
Template: https://s3.amazonaws.com/elevation-tiles-prod/terrarium/12/{x}/{y}.png
Tiles x3367–3369, y1979–1980.

Actual object headers identify SRTM, GMTED2010 and ETOPO1 source rasters. This is an old terrain mosaic (observed Last-Modified dates in 2017), not a 2026 survey. SRTM nominal land spacing is ~30m, with output pixel spacing ~38m at this latitude; resampling does not add accuracy. SRTM primarily dates to February2000. Coastal fill/new pavement and building surfaces can differ substantially from current OSM.

Provider describes applicable USGS SRTM/GMTED and NOAA ETOPO1 datasets as public domain and requests attribution. Retain the provider's full attribution source (`terrain_attribution_source.md`) with redistribution. Recommended scene credit: “Terrain: Mapzen; SRTM/GMTED2010 courtesy of USGS; ETOPO1 courtesy of NOAA.” NOAA formal credit: DOC/NOAA/NESDIS/NCEI, National Centers for Environmental Information, NESDIS, NOAA, U.S. Department of Commerce. USGS/NOAA material is not subject to copyright protection within the United States. Provider SRTM notes discuss historical overseas copyright; retain their notices and source metadata rather than claiming your own exclusive worldwide copyright over those data.

`bki_elevation_grid.json` samples unmodified decoded source values onto a257×257 regular WGS84 grid with north-to-south rows and west-to-east columns. Values are meters; formula R*256+G+B/256-32768. Nearest native pixel sampling, no smoothing/flattening. Source PNGs are native RGB, not indexed palette. Vertical reference must not be interpreted as ellipsoidal GPS height; upstream SRTM uses EGM96, mosaic has multiple sources.

QUALITY WARNING: decoded source contains a suspicious ~1342m spike near lon116.0265 lat6.0044 (Gaya Island vicinity). This is present in the source RGB pixels, not a palette/decoding issue. Do not present it as validated terrain. Use coastline ocean masking and explicitly documented artistic clamping/filtering or exclude suspect region. Airport ground likewise requires gameplay runway flattening and a smooth transition. Do not claim survey/flight-training fidelity.

No Google/Bing/Apple satellite imagery or proprietary map tiles were used. No source artwork/logos are bundled. This package is data/provenance only, not publication approval.

## Final acquisition summary

Complete requested bbox acquired via13 geographic API tiles plus overlapping airport-core request. `osm_source_manifest.json` records exact download URLs/checksums. Final extracted data: {'aeroway': 147, 'highway': 17832, 'building': 13716, 'waterway': 1734, 'landuse': 660, 'leisure': 354, 'natural': 287}. Building tag counts: {'building:levels': 944, 'height': 51, 'min_height': 12, 'roof:height': 1}. Every retained way has all referenced nodes; relation completeness is not guaranteed. bki_osm_raw.json.gz is lossless compressed equivalent. Straight endpoint distance of mapped runway is approximately 3525.9m; uniform game3780m scaling factor approximately 1.072072.
