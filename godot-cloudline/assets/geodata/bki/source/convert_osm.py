import xml.etree.ElementTree as ET,json,pathlib,collections,hashlib
p=pathlib.Path(__file__).parent
nodes={}; ways={}; rels={}; sources=[]
for f in sorted(p.glob('*.xml')):
 try: root=ET.parse(f).getroot()
 except ET.ParseError: continue
 if root.tag!='osm':continue
 sources.append({'file':f.name,'bounds':root.find('bounds').attrib,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
 for el in root:
  if el.tag=='node': nodes[el.get('id')]=el
  elif el.tag=='way': ways[el.get('id')]=el
  elif el.tag=='relation':rels[el.get('id')]=el
els=[];counts=collections.Counter();heightcounts=collections.Counter()
for id,w in ways.items():
 tags={t.get('k'):t.get('v') for t in w.findall('tag')}
 if not any(k in tags for k in ['aeroway','highway','building','landuse','natural','waterway','leisure']):continue
 ns=[n.get('ref') for n in w.findall('nd')];missing=[n for n in ns if n not in nodes]
 geom=[{'lat':float(nodes[n].get('lat')),'lon':float(nodes[n].get('lon'))} for n in ns if n in nodes]
 el={'type':'way','id':int(id),'version':int(w.get('version','0')),'timestamp':w.get('timestamp'),'tags':tags,'nodes':[int(n) for n in ns],'geometry':geom}
 if missing:el['missing_nodes']=missing
 els.append(el)
 for k in ['aeroway','highway','building','landuse','natural','waterway','leisure']:
  if k in tags:counts[k]+=1
 if 'building' in tags:
  for k in ['height','building:levels','min_height','roof:height']:
   if k in tags:heightcounts[k]+=1
# Retain relation membership for multipolygon assembly; some off-bbox members may be unavailable.
for id,r in rels.items():
 tags={t.get('k'):t.get('v') for t in r.findall('tag')}
 if tags.get('type')=='multipolygon' and any(k in tags for k in ['aeroway','building','landuse','natural','leisure']):
  els.append({'type':'relation','id':int(id),'tags':tags,'members':[m.attrib for m in r.findall('member')]})
out={'schema':'bki-osm-extract-v1','copyright':'© OpenStreetMap contributors','license':'https://opendatacommons.org/licenses/odbl/1-0/','attribution':'https://www.openstreetmap.org/copyright','requested_bounds_wsen':[115.98,5.88,116.12,6.04],'retrieved_utc':'2026-10-12','sources':sources,'counts':dict(counts),'building_height_tag_counts':dict(heightcounts),'elements':els}
(p/'bki_osm_raw.json').write_text(json.dumps(out,separators=(',',':')))
print('sources',len(sources),'elements',len(els),'counts',counts,'heights',heightcounts,'missing',sum(bool(e.get('missing_nodes')) for e in els))
