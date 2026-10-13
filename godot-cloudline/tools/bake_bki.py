#!/usr/bin/env python3
"""Deterministic offline OSM/DEM derivative. Requires numpy, scipy, shapely.
No runtime network. Source and all modifications are documented in geodata/bki.
"""
import json, math, struct, sys, hashlib
from pathlib import Path
import numpy as np
from scipy.ndimage import median_filter
from shapely.geometry import Polygon, LineString, Point, box
from shapely.geometry.polygon import orient
from shapely.ops import triangulate, unary_union, polygonize
ROOT=Path(__file__).resolve().parents[1]; SRC=Path(sys.argv[1]); MOBILE='--mobile' in sys.argv; OUT=ROOT/'assets/geodata/bki'; OUT=OUT/'mobile' if MOBILE else OUT; OUT.mkdir(parents=True,exist_ok=True)
data=json.load(open(SRC/'bki_osm_raw.json' if (SRC/'bki_osm_raw.json').exists() else SRC/'bki_core_osm.json'))
ways={e['id']:e for e in data['elements'] if e['type']=='way' and len(e.get('geometry',[]))>1}
south=(116.0431317,5.9182265); north=(116.0554894,5.9474563)
lon0=(south[0]+north[0])/2;lat0=(south[1]+north[1])/2
mx=111195.08*math.cos(math.radians(lat0));mz=111195.08
d=np.array([(north[0]-south[0])*mx,(north[1]-south[1])*mz]); length=np.linalg.norm(d); axis=d/length;scale=3780/length

def project(lon,lat):
 e=(lon-lon0)*mx;n=(lat-lat0)*mz
 return np.array([(n*axis[0]-e*axis[1])*scale,(e*axis[0]+n*axis[1])*scale])
def inverse(x,z):
 return lon0+(-x*axis[1]+z*axis[0])/scale/mx,lat0+(x*axis[0]+z*axis[1])/scale/mz
bounds=[115.98,5.88,116.12,6.04]
clip=Polygon([project(bounds[i],bounds[j]) for i,j in [(0,1),(2,1),(2,3),(0,3)]])
geo={k:LineString([project(p['lon'],p['lat']) for p in w['geometry']]) for k,w in ways.items()}
coasts=[geo[k] for k,w in ways.items() if w.get('tags',{}).get('natural')=='coastline']
# Polygonize against the exact data boundary. OSM coastline has land on its left.
coastunion=unary_union(coasts) if coasts else None
landparts=[]
if coasts:
 for poly in polygonize(unary_union([clip.boundary]+[g.intersection(clip) for g in coasts])):
  p=poly.representative_point();q=np.array(p.coords[0]);best=(1e100,False)
  for g in coasts:
   a=np.array(g.coords[:-1]);b=np.array(g.coords[1:]);v=b-a;t=np.clip(np.sum((q-a)*v,axis=1)/np.maximum(np.sum(v*v,axis=1),1e-9),0,1);delta=q-(a+t[:,None]*v);ds=np.sum(delta*delta,axis=1);i=ds.argmin()
   if ds[i]<best[0]:best=(ds[i],(v[i][0]*(q-a[i])[1]-v[i][1]*(q-a[i])[0])<0)
  if best[1]:landparts.append(poly)
land=unary_union(landparts)
if MOBILE:land=land.simplify(8,preserve_topology=True).intersection(clip)
if land.is_empty:raise SystemExit('No verified OSM coastline land polygon; require complete coastal source')
grid=json.load(open(SRC/'bki_elevation_grid.json')); heights=np.array(grid['elevations']); filtered=median_filter(heights,size=5)
# Reject isolated high outliers, retaining original regional relief otherwise.
bad=(heights-filtered)>80;heights[bad]=filtered[bad]
west,southb,east,northb=grid['bounds_wsen']
airport=box(-760,-2000,85,2000)
def elevation(x,z):
 if not land.covers(Point(x,z)):return -2.
 lon,lat=inverse(x,z);u=np.clip((lon-west)/(east-west)*(grid['width']-1),0,grid['width']-1);v=np.clip((northb-lat)/(northb-southb)*(grid['height']-1),0,grid['height']-1)
 ix=min(int(u),grid['width']-2);iz=min(int(v),grid['height']-2);fx=u-ix;fz=v-iz
 h=float(heights[iz,ix]*(1-fx)*(1-fz)+heights[iz,ix+1]*fx*(1-fz)+heights[iz+1,ix]*(1-fx)*fz+heights[iz+1,ix+1]*fx*fz)
 # Explicit airport grading joins the simulation's existing 3 m runway datum.
 dist=airport.distance(Point(x,z));blend=min(1,dist/450)
 return 3+(max(1,h)-3)*blend
colors={'land':(0.36,0.43,0.28),'forest':(.22,.34,.23),'roof':(.65,.64,.54),'wall':(.68,.72,.66),'road':(.31,.34,.33),'apron':(.43,.47,.45),'sand':(.70,.69,.48),'water':(.11,.39,.44),'urban':(.45,.49,.36)}
chunks={};counts={};colliders=[]
def tri(a,b,c,color,key=None):
 a,b,c=np.array(a),np.array(b),np.array(c);normal=np.cross(b-a,c-a);ln=np.linalg.norm(normal)
 if ln<1e-6:return
 normal/=ln;center=(a+b+c)/3
 key=key or (int((center[0]+14000)//5000),int((center[2]+14000)//5000))
 out=chunks.setdefault(key,[])
 for p in [a,b,c]:out.append((*p,*normal,*color,1.))
def flat_poly(poly,col,lift=.2):
 if poly.is_empty:return
 if poly.geom_type=='MultiPolygon':
  for p in poly.geoms:flat_poly(p,col,lift)
  return
 if poly.geom_type!='Polygon':return
 for t in triangulate(poly):
  if not poly.covers(t):continue
  p=list(t.exterior.coords)[:3];v=[(x,elevation(x,z)+lift,z) for x,z in p];tri(v[0],v[2],v[1],col)
# Terrain grid uses exact clipped OSM coast at boundary cells.
xmin,zmin,xmax,zmax=clip.bounds;step=320 if MOBILE else 180
for x in np.arange(xmin,xmax,step):
 for z in np.arange(zmin,zmax,step):
  cell=box(x,z,x+step,z+step);p=cell.intersection(land)
  if p.is_empty:continue
  h=elevation(x+step/2,z+step/2);base=np.array(colors['land']);base*=1+0.045*math.sin(x*.003)*math.cos(z*.002)
  if h>70:base=np.array(colors['forest'])*(1+min(h,700)/3500)
  flat_poly(p.intersection(airport),tuple(base),0)
  flat_poly(p.difference(airport),tuple(base),0)
ranked=[]
for id,w in ways.items():
 if w.get('tags',{}).get('building'):
  g=geo[id]
  if g.is_ring:
   p=Polygon(g);ranked.append((p.area/(1+p.centroid.distance(Point(0,0))/1200)**2,id))
selected_buildings={id for score,id in sorted(ranked,reverse=True)[:600 if MOBILE else 1800]}
for id,w in sorted(ways.items()):
 t=w.get('tags',{});g=geo[id];pts=list(g.coords);closed=pts[0]==pts[-1]
 if t.get('natural')=='coastline':
  flat_poly(g.simplify(8 if MOBILE else 0,preserve_topology=True).buffer(12,quad_segs=1 if MOBILE else 8).intersection(land),colors['sand'],.12);continue
 if closed and len(pts)>=4:
  poly=Polygon(pts)
  if not poly.is_valid:poly=poly.buffer(0)
  poly=poly.intersection(clip)
  if MOBILE:poly=poly.simplify(1.5,preserve_topology=True)
  if poly.is_empty:continue
  if t.get('building') and poly.geom_type=='Polygon':
   if id not in selected_buildings:continue
   # Limit distant tiny structures; actual retained footprint remains exact.
   center=poly.centroid
   if poly.area<40 or (center.distance(Point(0,0))>6500 and poly.area<240):continue
   try:h=float(t.get('height',str(float(t.get('building:levels','2'))*3)).replace(' m',''))
   except ValueError:h=8
   h=max(3,min(h,120));base=elevation(center.x,center.y)+.3
   if base<0:continue
   roof=tuple(c*(.92+(id%9)*.018) for c in colors['roof']) if t.get('aeroway')!='terminal' else (.74,.77,.70)
   for tt in triangulate(poly):
    if poly.covers(tt):
     v=[(x,base+h,z) for x,z in list(tt.exterior.coords)[:3]];tri(v[0],v[2],v[1],roof)
   ring=list(orient(poly,sign=-1.0).exterior.coords)
   for a,b in zip(ring,ring[1:]):
    p=(a[0],base,a[1]);q=(b[0],base,b[1]);r=(b[0],base+h,b[1]);s=(a[0],base+h,a[1]);tri(p,q,r,colors['wall']);tri(p,r,s,colors['wall'])
   counts['buildings']=counts.get('buildings',0)+1
   if center.distance(Point(0,0))<2500:colliders.append({'x':center.x,'z':center.y,'w':(poly.bounds[2]-poly.bounds[0])/2,'d':(poly.bounds[3]-poly.bounds[1])/2,'h':base+h})
  elif t.get('aeroway') in ['apron','taxiway']:flat_poly(poly,colors['apron'],.18);counts['aprons']=counts.get('aprons',0)+1
  elif t.get('landuse') in ['forest','grass','meadow','recreation_ground'] or t.get('natural') in ['wood','wetland','scrub']:flat_poly(poly,colors['forest'],.12)
  elif t.get('natural')=='water' or t.get('water'):flat_poly(poly,colors['water'],.16)
 elif t.get('highway') or t.get('aeroway')=='taxiway':
  is_taxi=t.get('aeroway')=='taxiway';kind=t.get('highway','')
  if not is_taxi and kind not in ['motorway','trunk','primary','secondary','tertiary','residential','unclassified','motorway_link','trunk_link','primary_link','secondary_link']:continue
  if not is_taxi and kind=='residential' and g.distance(Point(0,0))>(1700 if MOBILE else 3500):continue
  pts=list(g.simplify(28 if MOBILE else 12,preserve_topology=True).coords)
  width=22 if is_taxi else 14 if kind in ['trunk','primary','secondary'] else 8 if kind in ['tertiary','residential','unclassified'] else 4
  if kind in ['footway','path','steps','cycleway','track']:continue
  # Segment long ways so road elevation tracks real relief.
  for a,b in zip(pts,pts[1:]):
   a=np.array(a);b=np.array(b);length=np.linalg.norm(b-a)
   if length<.1:continue
   side=np.array([-(b-a)[1],(b-a)[0]])/length*width/2
   for j in range(max(1,math.ceil(length/(160 if MOBILE else 80)))):
    n=max(1,math.ceil(length/(160 if MOBILE else 80)));p=a+(b-a)*j/n;q=a+(b-a)*(j+1)/n
    vs=[(c[0],elevation(*c)+(.22 if is_taxi else .3),c[1]) for c in [p-side,p+side,q+side,q-side]]
    roadpoly=Polygon([(v[0],v[2]) for v in vs]).intersection(land).intersection(clip)
    flat_poly(roadpoly,colors['apron' if is_taxi else 'road'],.22 if is_taxi else .3)
  counts['taxiways' if is_taxi else 'roads']=counts.get('taxiways' if is_taxi else 'roads',0)+1
# Collision terrain is baked from the same function at a denser 100 m grid.
cs=100;w=math.ceil((xmax-xmin)/cs)+1;h=math.ceil((zmax-zmin)/cs)+1
collision={'x':xmin,'z':zmin,'step':cs,'width':w,'height':h,'values':[[round(elevation(xmin+ix*cs,zmin+iz*cs),2) for ix in range(w)] for iz in range(h)]}
(OUT/'heights.json').write_text(json.dumps(collision,separators=(',',':')))
(OUT/'obstacles.json').write_text(json.dumps(colliders,separators=(',',':')))
# Ground roll follows the same real taxiway/apron footprints as the visual map.
pavements=[]
for id,way in sorted(ways.items()):
 kind=way.get('tags',{}).get('aeroway')
 if kind not in ['taxiway','apron']:continue
 g=geo[id]
 p=Polygon(g) if g.is_ring else g.buffer(11,quad_segs=2)
 if not p.is_valid:p=p.buffer(0)
 p=p.intersection(land).intersection(clip)
 polys=list(p.geoms) if p.geom_type=='MultiPolygon' else [p]
 for poly in polys:
  if poly.geom_type=='Polygon' and not poly.is_empty:pavements.append(list(poly.exterior.coords))
(OUT/'pavement.json').write_text(json.dumps(pavements,separators=(',',':')))

for key,verts in chunks.items():
 with open(OUT/('chunk_%s_%s.bin'%key),'wb') as f:
  f.write(struct.pack('<I',len(verts)));f.write(np.array(verts,dtype='<f4').tobytes())
meta={'detail_profile':'mobile-safe' if MOBILE else 'desktop','building_budget':600 if MOBILE else 1800,'source':'OpenStreetMap contributors / Mapzen Terrain Tiles','bounds_wsen':bounds,'coordinate_handedness':'Godot +Y up, +Z runway02, -X right/east of runway','runway_true_bearing_deg':math.degrees(math.atan2(axis[0],axis[1])),'origin_lon_lat':[lon0,lat0],'axis_east_north':axis.tolist(),'scale':scale,'source_runway_length_m':float(np.linalg.norm(d)),'game_runway_length_m':3780,'runway_way_id':48760813,'runway_ref':'02/20','source_endpoints_lon_lat':[south,north],'counts':counts,'chunks':len(chunks),'mesh_files':['chunk_%s_%s.res'%k for k in sorted(chunks)],'triangles':sum(len(v)//3 for v in chunks.values()),'dem_outliers_filtered':int(bad.sum()),'airport_grading':'3m inside [-760,-2000,85,2000], 450m blend','buildings':'OSM footprints, tagged height/levels where present; otherwise estimated 6m, not photogrammetry'}
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta,indent=2))

# Only remove obsolete outputs owned by this baker, never input/source files.
valid={'chunk_%s_%s'%k for k in chunks}
for old in OUT.glob('chunk_*'):
 if old.suffix in ['.bin','.res'] and old.stem not in valid:old.unlink()
