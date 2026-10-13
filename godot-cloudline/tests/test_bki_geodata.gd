extends SceneTree
const BKI=preload("res://scripts/bki_scenery.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Navigation=preload("res://scripts/navigation_display.gd")
const World=preload("res://scripts/world_builder.gd")
var checks=0
var failures=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1
	print("PASS " if value else "FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	BKI.ensure_data()
	var south=BKI.project(116.0431317,5.9182265)
	var north=BKI.project(116.0554894,5.9474563)
	check(south.distance_to(Vector2(0,-1890))<.01,"OSM south endpoint aligns to game runway")
	check(north.distance_to(Vector2(0,1890))<.01,"OSM north endpoint aligns to game runway")
	check(absf(float(BKI.metadata.scale)-1.07207)<.001,"uniform explicit map scale")
	var origin: Array=BKI.metadata.origin_lon_lat
	var east=BKI.project(float(origin[0])+.01,float(origin[1]))
	var west=BKI.project(float(origin[0])-.01,float(origin[1]))
	var north_cardinal=BKI.project(float(origin[0]),float(origin[1])+.01)
	check(east.x<0 and west.x>0,"east is physical right when camera faces +Z")
	var camera_right=Vector3.FORWARD # replaced below by actual camera basis
	var camera=Camera3D.new();root.add_child(camera);camera.look_at(Vector3(0,0,100),Vector3.UP)
	camera_right=camera.global_basis.x
	check(camera_right.dot(Vector3(east.x,0,east.y))>0,"Godot camera projects east on right")
	camera.queue_free()
	var dimensions=Vector2(600,400)
	var map_east=Navigation.world_to_map(east,dimensions,Vector3.ZERO,true,"bki")
	var map_north=Navigation.world_to_map(north_cardinal,dimensions,Vector3.ZERO,true,"bki")
	check(map_east.x>300 and absf(map_east.y-200)<.01,"BKI true east points right on north-up map")
	check(map_north.y<200 and absf(map_north.x-300)<.01,"BKI true north points up on map")
	check(Navigation.map_to_world(map_east,dimensions,Vector3.ZERO,true,"bki").distance_to(east)<.01,"BKI north-up inverse map")
	for heading in [0.0,90.0,180.0,270.0]:
		check(absf(Navigation.heading_degrees(Navigation.heading_to_yaw(heading,"bki"),"bki")-heading)<.001,"BKI AP/cardinal heading round trip "+str(heading))
	check(BKI.metadata.runway_ref=="02/20","source runway designation retained")
	check(BKI.metadata.counts.buildings<=1800 and BKI.metadata.counts.buildings>1000,"bounded real footprint selection")
	check(BKI.metadata.triangles<160000,"mobile geographic triangle budget")
	check(BKI.metadata.mesh_files.size()<=30,"district batching budget")
	for z in [-1720.0,0.0,1720.0]:check(BKI.height_at(0,z)==3,"runway collision datum "+str(z))
	var sea=BKI.project(116.0,5.92)
	check(BKI.height_at(sea.x,sea.y)<0,"OSM west offshore water mask")
	var taxi=BKI.project(116.0498362,5.9266158)
	check(BKI.is_paved(taxi.x,taxi.y),"OSM taxiway117168817 remains paved after projection")
	check(not BKI.is_paved(sea.x,sea.y),"offshore geographic point is not paved")
	var f=Flight.new();f.reset("a320","runway","clear",true);f.select_airport("bki")
	check(f.terrain_height(0,0)==3,"flight uses same terrain dataset")
	for direction in [-1.0,1.0]:
		var manual=Flight.new();manual.reset("a320","runway","clear",true);manual.select_airport("bki")
		manual.p=Vector3(0,6.9,0);manual.v=Vector3(0,0,25);manual.grounded=true
		var initial=Navigation.heading_degrees(manual.yaw,"bki")
		for tick in range(60):manual.step(1.0/120.0,{"pitch":0.0,"roll":0.0,"yaw":Navigation.manual_axis(direction,"bki"),"brake":false})
		check(signf(manual.p.x)==-direction,"manual rudder moves physical camera-right/left "+str(direction))
		check(signf(Navigation.heading_degrees(manual.yaw,"bki")-initial)==direction,"manual rudder agrees with geographic heading "+str(direction))
		manual.p=Vector3(0,500,0);manual.v=Vector3(0,0,100);manual.grounded=false;manual.bank=0;manual.yaw=0
		for tick in range(60):manual.step(1.0/120.0,{"pitch":0.0,"roll":Navigation.manual_axis(direction,"bki"),"yaw":0.0,"brake":false})
		check(signf((-manual.aircraft_basis().x).y)==-direction,"physical right wing lowers for right roll "+str(direction))
		check(signf(Navigation.attitude_bank(manual.bank,"bki"))==direction,"BKI attitude agrees with physical bank "+str(direction))
	check(Navigation.manual_axis(1,"can")==1 and Navigation.manual_axis(1,"island")==1,"other scene input conventions unchanged")
	var host=Node3D.new();root.add_child(host)
	var builder=World.new();builder.conservative_materials=true
	var scene=builder.build(host,"bki",f)
	check(scene.has_node("BKIRealWorld"),"genuine map scene replaces random city")
	check(scene.get_node("BKIRealWorld").get_meta("detail_profile")=="mobile-safe","conservative profile selects separately baked mobile scenery")
	check(int(scene.get_node("BKIRealWorld").get_meta("triangles"))<45000,"conservative geographic triangle budget")
	var compact=JSON.parse_string(FileAccess.get_file_as_string(BKI.PATH+"mobile/metadata.json"))
	check(compact.counts.buildings<=600 and compact.counts.buildings>400,"mobile retains bounded mapped buildings")
	check(compact.scale==BKI.metadata.scale,"mobile preserves same runway alignment")
	check(BKI.nearby_obstacles(0,0).size()<100,"spatial obstacle broadphase")
	for node in scene.get_node("BKIRealWorld").get_children():
		check(node.mesh.get_surface_count()==1,"one draw surface per district")
		var mat=node.mesh.surface_get_material(0)
		check(mat is StandardMaterial3D and mat.vertex_color_use_as_albedo,"shader-free vertex-colored geometry")
	print("BKI_GEODATA_SUMMARY ",checks," checks; ",failures," failures")
	host.queue_free();await process_frame;quit(1 if failures else 0)
