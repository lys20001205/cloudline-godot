extends RefCounted
## Offline OSM coast/roads/footprints + openly licensed elevation; no web requests.
const PATH="res://assets/geodata/bki/"
static var heights: Dictionary={}
static var metadata: Dictionary={}
static var obstacles: Array=[]
static var obstacle_cells: Dictionary={}
static var pavement_cells: Dictionary={}
static func ensure_data() -> void:
	if not heights.is_empty():return
	heights=JSON.parse_string(FileAccess.get_file_as_string(PATH+"heights.json"))
	metadata=JSON.parse_string(FileAccess.get_file_as_string(PATH+"metadata.json"))
	obstacles=JSON.parse_string(FileAccess.get_file_as_string(PATH+"obstacles.json"))
	index_obstacles(obstacles)
	var paved: Array=JSON.parse_string(FileAccess.get_file_as_string(PATH+"pavement.json"))
	for points in paved:
		var polygon=PackedVector2Array()
		for point in points:polygon.append(Vector2(point[0],point[1]))
		var bounds=Rect2(polygon[0],Vector2.ZERO)
		for point in polygon:bounds=bounds.expand(point)
		for ix in range(int(floor(bounds.position.x/500)),int(floor(bounds.end.x/500))+1):
			for iz in range(int(floor(bounds.position.y/500)),int(floor(bounds.end.y/500))+1):
				var cell=Vector2i(ix,iz)
				if not pavement_cells.has(cell):pavement_cells[cell]=[]
				pavement_cells[cell].append(polygon)
static func index_obstacles(items: Array) -> void:
	obstacle_cells.clear()
	for o in items:
		for ix in range(int(floor((o.x-o.w-3)/500)),int(floor((o.x+o.w+3)/500))+1):
			for iz in range(int(floor((o.z-o.d-3)/500)),int(floor((o.z+o.d+3)/500))+1):
				var cell=Vector2i(ix,iz)
				if not obstacle_cells.has(cell):obstacle_cells[cell]=[]
				obstacle_cells[cell].append(o)
static func height_at(x: float,z: float) -> float:
	ensure_data()
	var u=(x-float(heights.x))/float(heights.step)
	var v=(z-float(heights.z))/float(heights.step)
	if u<0 or v<0 or u>=float(heights.width)-1 or v>=float(heights.height)-1:return -2.0
	var ix=int(u);var iz=int(v);var fx=u-ix;var fz=v-iz
	var a=lerpf(float(heights.values[iz][ix]),float(heights.values[iz][ix+1]),fx)
	var b=lerpf(float(heights.values[iz+1][ix]),float(heights.values[iz+1][ix+1]),fx)
	# Keep the flight runway contract exact despite a coarse shoreline grid.
	if absf(x)<30 and absf(z)<1890:return 3.0
	return lerpf(a,b,fz)
static func project(lon: float,lat: float) -> Vector2:
	ensure_data()
	var origin: Array=metadata.origin_lon_lat
	var e=(lon-float(origin[0]))*111195.08*cos(deg_to_rad(float(origin[1])))
	var n=(lat-float(origin[1]))*111195.08
	var axis: Array=metadata.axis_east_north
	return Vector2(n*float(axis[0])-e*float(axis[1]),e*float(axis[0])+n*float(axis[1]))*float(metadata.scale)
func build(root: Node3D,compact: bool=false) -> void:
	ensure_data()
	var district=Node3D.new();district.name="BKIRealWorld"
	root.add_child(district)
	# The explicit list survives PCK remapping; DirAccess .res names do not.
	var detail: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH+"mobile/metadata.json")) if compact else metadata
	var folder=PATH+"mobile/" if compact else PATH
	index_obstacles(JSON.parse_string(FileAccess.get_file_as_string(folder+"obstacles.json")))
	var files: Array=detail.mesh_files
	for file in files:
		var instance=MeshInstance3D.new();instance.mesh=load(folder+str(file))
		instance.name=str(file).get_basename()
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		district.add_child(instance)
	district.set_meta("detail_profile",detail.get("detail_profile","desktop"))
	district.set_meta("triangles",detail.triangles)
	district.set_meta("attribution","© OpenStreetMap contributors · ODbL 1.0; Mapzen Terrain Tiles")
	district.set_meta("real_data_bounds",metadata.bounds_wsen)

static func nearby_obstacles(x: float,z: float) -> Array:
	ensure_data()
	return obstacle_cells.get(Vector2i(int(floor(x/500)),int(floor(z/500))),[])

static func is_paved(x: float,z: float) -> bool:
	ensure_data()
	for polygon in pavement_cells.get(Vector2i(int(floor(x/500)),int(floor(z/500))),[]):
		if Geometry2D.is_point_in_polygon(Vector2(x,z),polygon):return true
	return false
