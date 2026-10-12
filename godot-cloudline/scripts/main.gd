extends Node3D

const Flight = preload("res://scripts/flight_model.gd")
const Route = preload("res://scripts/route_mission.gd")
const World = preload("res://scripts/world_builder.gd")
const Atmosphere = preload("res://scripts/environment_audio.gd")
const HUD = preload("res://scripts/hud.gd")
var flight
var route
var builder = World.new()
var scenery: Node3D
var plane: Node3D
var camera: Camera3D
var hud: Control
var running := false
var is_route := true
var camera_mode := 0
var scene_key := ""
var gate_nodes: Array[Node3D] = []
var rings_passed := 0
var ambience
var light_mode := "day"
var sensitivity := .8
var invert_pitch := false
var look_x := 0.0
var look_y := 0.0
var zoom := 1.0
var clock_time := 0.0
var guidance_rings: Array[Node3D] = []
var taxi_marker: Node3D

func _ready() -> void:
	get_viewport().gui_embed_subwindows=true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("3c83af")
	sky_mat.sky_horizon_color=Color("bcd6d7")
	sky_mat.ground_bottom_color=Color("456f76")
	sky_mat.ground_horizon_color=Color("bcd6d7")
	sky.sky_material=sky_mat
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b9d7e3")
	env.ambient_light_energy=.7
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-42,-28,0)
	sun.light_energy=1.8
	sun.shadow_enabled=false
	add_child(sun)
	ambience=Atmosphere.new()
	add_child(ambience)
	ambience.setup(environment,sun)
	ambience.set_lighting(light_mode)
	camera=Camera3D.new()
	camera.far=80000
	camera.near=.25
	camera.fov=65
	add_child(camera)
	start_flight("a320","bki_can","clear")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud=HUD.new()
	hud.game=self
	canvas.add_child(hud)
	running=false

func start_flight(type: String, mode: String, weather: String) -> void:
	if mode in ["bki_can","can_approach","can_taxi"]: type="a320"
	if is_instance_valid(hud): hud.reset_controls()
	camera_mode=0
	look_x=0; look_y=0; zoom=1
	flight=Flight.new()
	flight.reset(type, mode if mode in ["free","lesson","runway","landing"] else "runway",weather,true)
	route=Route.new(mode)
	is_route=mode in ["bki_can","can_approach","can_taxi"]
	if is_route:
		route.configure(flight,route.transfer)
	else:
		flight.select_airport("island")
		flight.reset(type,mode,weather,true)
		route.scene="island"
	if plane: plane.queue_free()
	plane=builder.aircraft(self,type)
	rebuild_world(route.scene)
	rings_passed=0
	if mode=="lesson":
		for gate in flight.gates:
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius=gate.r-2
			mesh.outer_radius=gate.r
			mesh.rings=24
			mesh.ring_segments=8
			ring.mesh=mesh
			ring.material_override=builder.mat("6bebac")
			ring.rotation.x=PI/2
			ring.position=Vector3(gate.x,gate.y,gate.z)
			scenery.add_child(ring)
			gate_nodes.append(ring)
	build_guidance()
	update_visuals(1.0)

func rebuild_world(key: String) -> void:
	if scenery: scenery.queue_free()
	gate_nodes.clear()
	guidance_rings.clear()
	taxi_marker=null
	scenery=builder.build(self,key,flight)
	scene_key=key
	# Collision structures match the simplified terminals and control tower.
	flight.obstacles=[]
	if key in ["bki","can"]:
		flight.obstacles.append({"x":500.0 if key=="can" else 405.0,"z":-440.0,"w":100.0 if key=="can" else 67.5,"d":230.0 if key=="can" else 220.0,"h":flight.elevation+(24 if key=="can" else 16)})
		if key=="can":
			for z in [-600.0,-280.0]: flight.obstacles.append({"x":405.0,"z":z,"w":87.5,"d":22.5,"h":flight.elevation+12})
		flight.obstacles.append({"x":440.0,"z":230.0,"w":16.5,"d":16.0,"h":flight.elevation+48})
	build_guidance()

func _physics_process(dt: float) -> void:
	if running and not flight.crashed:
		var pitch_input: float=hud.stick.y*(-1 if invert_pitch else 1)
		var roll_input: float=hud.stick.x
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): pitch_input+=1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): pitch_input-=1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): roll_input-=1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): roll_input+=1
		var yaw_input: float=hud.yaw_input
		if Input.is_physical_key_pressed(KEY_Q): yaw_input-=1
		if Input.is_physical_key_pressed(KEY_E): yaw_input+=1
		var throttle_input:=0.0
		if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD): throttle_input+=1
		if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT): throttle_input-=1
		if throttle_input:
			route.cancel_guide(flight)
			flight.ap.on=false
			flight.power=clampf(flight.power+throttle_input*dt*.3,0,1)
		var inp := {"pitch":clampf(pitch_input*sensitivity,-1,1),"roll":clampf(roll_input*sensitivity,-1,1),"yaw":clampf(yaw_input,-1,1),"brake":hud.brake or Input.is_physical_key_pressed(KEY_SPACE)}
		if is_route: inp=route.guide_input(flight,inp,dt)
		flight.step(dt,inp)
		if is_route:
			route.after_step(flight,dt)
			if route.transfer!="":
				route.configure(flight,route.transfer)
				if scene_key!=route.scene: rebuild_world(route.scene)
				update_visuals(1.0)
		else:
			if flight.gate>rings_passed and rings_passed<gate_nodes.size():
				gate_nodes[rings_passed].hide()
				rings_passed=flight.gate
	if running: clock_time+=dt
	ambience.update_sound(flight,running)
	update_visuals(dt)

func update_visuals(dt: float) -> void:
	if not plane: return
	plane.position=flight.p
	# +Z forward, right-handed banking and pitch match original force basis.
	var forward := Vector3(sin(flight.yaw)*cos(flight.pitch),sin(flight.pitch),cos(flight.yaw)*cos(flight.pitch))
	var right := Vector3(cos(flight.yaw),0,-sin(flight.yaw))
	var up := forward.cross(right)
	var bank_right := right*cos(flight.bank)-up*sin(flight.bank)
	var bank_up := right*sin(flight.bank)+up*cos(flight.bank)
	plane.basis=Basis(bank_right,bank_up,forward)
	plane.get_node("Gear").visible=flight.gear
	var jet: bool=flight.type!="light"
	var desired: Vector3
	var target: Vector3
	var camera_up:=Vector3.UP
	if camera_mode==1:
		desired=flight.p+forward*(13.0 if jet else .9)+bank_up*(2.75 if jet else 1.52)
		var look: Vector3=(forward*cos(look_x)+bank_right*sin(look_x)-bank_up*look_y).normalized()
		target=desired+look*100
		camera_up=bank_up
		plane.visible=false
	elif camera_mode==2:
		desired=flight.p+bank_right*(29 if jet else 10)*zoom-forward*(9 if jet else 3)+Vector3.UP*(4 if jet else 2.5)
		target=flight.p+forward*(8 if jet else 2)
		plane.visible=true
	elif camera_mode==3:
		var angle:=clock_time*.12+look_x
		var distance: float=(69 if jet else 24)*zoom
		desired=flight.p+Vector3(sin(angle)*distance,distance*(.30+look_y),cos(angle)*distance)
		target=flight.p
		plane.visible=true
	else:
		var angle: float=flight.yaw+look_x
		var distance: float=(64 if jet else 23)*zoom
		desired=flight.p+Vector3(-sin(angle)*distance,(17 if jet else 7)+look_y*distance*.65,-cos(angle)*distance)
		target=flight.p+forward*(20 if jet else 7)+Vector3.UP*(3 if jet else 1.2)
		plane.visible=true
	camera.position=camera.position.lerp(desired,minf(1,dt*5)) if dt<.5 and camera_mode!=1 else desired
	camera.look_at(target,camera_up)
	for ring in guidance_rings:
		ring.visible=ring.position.z>flight.p.z+40 and (not is_route or route.phase in ["descent","approach"])
	if is_instance_valid(taxi_marker):
		taxi_marker.visible=is_route and route.phase=="taxi"
		if taxi_marker.visible:
			var point: Vector2=route.taxi_points[route.taxi_index]
			taxi_marker.position=Vector3(point.x,flight.elevation+7,point.y)

func cycle_camera() -> void:
	camera_mode=(camera_mode+1)%4
	look_x=0; look_y=0; zoom=1
	update_visuals(1)

func heading_offset() -> float:
	return deg_to_rad(20 if scene_key=="bki" else 10 if scene_key=="can" else 0)

func set_lighting(value: String) -> void:
	light_mode=value
	ambience.set_lighting(value)

func build_guidance() -> void:
	if not scenery or not flight: return
	# Called on scene transfer and initial mode selection; avoid duplicates.
	for ring in guidance_rings: ring.queue_free()
	guidance_rings.clear()
	if is_instance_valid(taxi_marker): taxi_marker.queue_free()
	taxi_marker=null
	if is_route and scene_key=="can":
		for z in range(-20000,-1250,650):
			guidance_rings.append(make_ring(Vector3(0,flight.elevation+flight.spec.gear_height+(-1200-z)*.052,z),54))
		taxi_marker=make_ring(Vector3(0,flight.elevation+7,900),10)
	elif not is_route and flight.mode=="landing":
		for z in range(-4500,-750,450):
			guidance_rings.append(make_ring(Vector3(0,46+maxf(0,-850-z)*.052,z),56 if flight.type!="light" else 30))

func make_ring(pos: Vector3, radius: float) -> Node3D:
	var ring:=MeshInstance3D.new()
	var mesh:=TorusMesh.new()
	mesh.inner_radius=radius*.98
	mesh.outer_radius=radius
	mesh.rings=24; mesh.ring_segments=6
	ring.mesh=mesh
	ring.material_override=builder.mat("6bebac")
	ring.rotation.x=PI/2
	ring.position=pos
	scenery.add_child(ring)
	return ring

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		running=false
		hud.paused=true
		hud.buttons.pause.text="继续"
		hud.reset_controls()
