extends RefCounted
class_name CloudlineWorld

const BKI = preload("res://scripts/bki_scenery.gd")

const A320_MODEL = preload("res://assets/models/a320/A320_nologo.glb")

var root: Node3D
var materials: Dictionary = {}
# Selected once before scene creation; imported A320 materials stay unchanged.
var conservative_materials := false
var compact_geography := false

func mat(color: String) -> StandardMaterial3D:
	if materials.has(color): return materials[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
	if color in ["ffe2a0","6bebac","59efb0"]:
		m.emission_enabled=true
		m.emission=Color(color)
		m.emission_energy_multiplier=1.5
	materials[color] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = pavement_material(color) if color in ["303b42","536165","596969"] else mat(color)
	n.position = pos
	parent.add_child(n)
	return n

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	n.mesh = mesh
	n.scale = size
	n.position = pos
	n.material_override = mat(color)
	parent.add_child(n)
	return n

func label(parent: Node3D, pos: Vector3, title: String, color: Color = Color.WHITE) -> void:
	var n := Label3D.new()
	n.text = title
	n.position = pos
	n.font_size = 48
	n.pixel_size = 0.18
	n.modulate = color
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = false
	parent.add_child(n)

func build(parent: Node3D, key: String, model) -> Node3D:
	root = Node3D.new()
	parent.add_child(root)
	var elevation := 3.0 if key == "bki" else 15.0
	var length := 3780.0 if key == "bki" else 3600.0
	if key == "island":
		elevation = 30.0
		length = 2100.0
	box(root, Vector3(0,-8,0), Vector3(120000,10,120000), "14617b")
	if key == "bki":
		BKI.new().build(root,compact_geography or conservative_materials)
		build_bki_runway(elevation,length)
	elif key != "sea":
		terrain(model)
		box(root,Vector3(0,elevation+0.05,0),Vector3(100,.1,length+180),"727d62")
		box(root,Vector3(0,elevation+.15,0),Vector3(45,.2,length),"303b42")
		box(root,Vector3(115,elevation+.15,0),Vector3(64,.2,length-120),"536165")
		box(root,Vector3(267,elevation+.15,-440),Vector3(345,.2,660),"596969")
		for z in [900,-1400,-500]:
			box(root,Vector3(60,elevation+.16,z),Vector3(170,.2,80),"536165")
			box(root,Vector3(62,elevation+.29,z),Vector3(120,.04,.9),"f3c857")
		box(root,Vector3(115,elevation+.28,0),Vector3(1,.04,length-160),"f3c857")
		for z in range(int(-length/2+60),int(length/2),64):
			box(root,Vector3(0,elevation+.29,z),Vector3(1.5,.04,31),"f2eee0")
		for x in [-21,21]: box(root,Vector3(x,elevation+.29,0),Vector3(.7,.04,length-40),"f2eee0")
		for sign_z in [-1,1]:
			for x in [-17,-12,-7,7,12,17]: box(root,Vector3(x,elevation+.3,sign_z*(length/2-48)),Vector3(2.8,.05,34),"f2eee0")
			for x in [-14,14]: box(root,Vector3(x,elevation+.3,sign_z*(length/2-290)),Vector3(5.5,.05,48),"f2eee0")
		for z in range(int(-length/2),int(length/2),100):
			for x in [-26,26]: box(root,Vector3(x,elevation+.8,z),Vector3(1.2,.6,1.2),"ffe2a0")
		box(root,Vector3(184,elevation+.3,-440),Vector3(138,.05,1),"f3c857")
		box(root,Vector3(245,elevation+.31,-440),Vector3(32,.05,2),"59efb0")
		box(root,Vector3(245,elevation+.31,-440),Vector3(2,.05,32),"59efb0")
		if key == "can":
			box(root,Vector3(500,elevation+12,-440),Vector3(200,24,460),"365d69")
			for z in range(-640,-239,40): ellipsoid(root,Vector3(500,elevation+25,z),Vector3(226,15,64),"e3e0ce")
			for z in [-600,-280]:
				box(root,Vector3(405,elevation+6,z),Vector3(175,12,45),"a4b7b3")
				box(root,Vector3(340,elevation+6,z),Vector3(70,4,12),"69898e")
			label(root,Vector3(500,elevation+65,-440),"GUANGZHOU · CAN T3")
			label(root,Vector3(245,elevation+15,-440),"SIM-T3",Color("59efb0"))
			box(root,Vector3(-2400,elevation+.12,450),Vector3(45,.2,3600),"34424a")
		else:
			box(root,Vector3(405,elevation+8,-440),Vector3(135,16,440),"a2b6b0")
			for z in range(-620,-259,60): box(root,Vector3(405,elevation+19,z),Vector3(147,4,45),"e6dcb8")
			label(root,Vector3(405,elevation+55,-440),"KOTA KINABALU · BKI" if key=="bki" else "CLOUDLINE ISLAND")
		box(root,Vector3(440,elevation+20,230),Vector3(20,40,20),"b2c4bc")
		box(root,Vector3(440,elevation+43,230),Vector3(33,9,32),"274c60")
		airport_details(elevation,key)
		var rng := RandomNumberGenerator.new()
		rng.seed = 210 if key=="bki" else 320
		for i in range(90):
			var h := rng.randf_range(10,75)
			box(root,Vector3(rng.randf_range(850,5000),elevation+h/2,rng.randf_range(-8500,8500)),Vector3(25,h,25),"8bada5")
	var rng := RandomNumberGenerator.new()
	rng.seed=777
	for i in range(28):
		var pos := Vector3(rng.randf_range(-17000,17000),rng.randf_range(1900,4100),rng.randf_range(-19000,19000))
		ellipsoid(root,pos,Vector3(650,180,400),"e9f1e9")
		ellipsoid(root,pos+Vector3(210,30,30),Vector3(450,190,350),"e9f1e9")
	batch_static_boxes()
	return root

func aircraft(parent: Node3D, type: String) -> Node3D:
	var plane := Node3D.new()
	parent.add_child(plane)
	if type == "a320":
		build_imported_a320(plane)
		return plane
	var light := type == "light"
	var len_f := 8.0 if light else 37.5
	var radius := .72 if light else 3.8
	ellipsoid(plane,Vector3.ZERO,Vector3(radius,radius,len_f),"f1eee5")
	ellipsoid(plane,Vector3(0,.6,len_f*.34),Vector3(radius*.75,radius*.45,len_f*.17),"244454")
	if light:
		box(plane,Vector3(0,-.4,-1),Vector3(10.8,.28,2),"e3e5de")
	else:
		for side in [-1.0,1.0]:
			wing(plane,[Vector3(side*1.4,-.4,5),Vector3(side*17.05,-.1,-4.5),Vector3(side*17.05,-.1,-6),Vector3(side*1.4,-.4,-3.5)],"e3e5de")
	box(plane,Vector3(0,0,-len_f*.39),Vector3(4 if light else 12,.22 if light else .4,1.4 if light else 3),"d94c4c")
	var tail := box(plane,Vector3(0,2 if light else 4,-len_f*.38),Vector3(.25 if light else .6,3 if light else 6,2 if light else 5),"d64343")
	tail.rotation.x = -.17
	if not light:
		for x in [-6.8,6.8]:
			ellipsoid(plane,Vector3(x,-2,2),Vector3(2.6,2.6,6),"d64343")
			ellipsoid(plane,Vector3(x,-2,4.4),Vector3(2.2,2.2,.4),"293741")
			box(plane,Vector3(signf(x)*16.8,0,-5),Vector3(.25,2.2,1.5),"d64343")
		for z in range(-10,11,2):
			for x in [-1.86,1.86]: box(plane,Vector3(x,.5,z),Vector3(.08,.5,.6),"344b5d")
	var gear_root := Node3D.new()
	gear_root.name="Gear"
	plane.add_child(gear_root)
	for pos in [Vector3(0,-radius*.9,len_f*.3),Vector3(-radius*.7,-radius*.9,-1),Vector3(radius*.7,-radius*.9,-1)]:
		box(gear_root,pos,Vector3(.25,1,.25),"758889")
		ellipsoid(gear_root,pos-Vector3(0,.5,0),Vector3(.65,.8,.8),"1b2732")
	return plane

func terrain(model) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extent := 27000.0
	var count := 106
	var step_size := extent*2/count
	for iz in range(count):
		for ix in range(count):
			var x := -extent+ix*step_size
			var z := -extent+iz*step_size
			var a := Vector3(x,model.terrain_height(x,z),z)
			var b := Vector3(x+step_size,model.terrain_height(x+step_size,z),z)
			var c := Vector3(x+step_size,model.terrain_height(x+step_size,z+step_size),z+step_size)
			var d := Vector3(x,model.terrain_height(x,z+step_size),z+step_size)
			for point in [a,b,c,a,c,d]: mesh.add_vertex(point)
	mesh.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh=mesh.commit()
	instance.material_override=ground_material()
	root.add_child(instance)

func wing(parent: Node3D, points: Array, color: String) -> void:
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indices in [[0,1,2],[0,2,3],[2,1,0],[3,2,0]]:
		for index in indices: surf.add_vertex(points[index])
	surf.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh=surf.commit()
	instance.material_override=mat(color)
	parent.add_child(instance)

# Genuine imported asset. Upstream GLB and embedded 1K atlas are preserved byte-for-byte.
# Its node transforms already encode meters and +Y up; rotate the +X nose to +Z.
func build_imported_a320(plane: Node3D) -> void:
	var imported: Node3D=A320_MODEL.instantiate()
	imported.name="ImportedA320"
	imported.rotation.y=-PI/2
	plane.add_child(imported)
	plane.set_meta("model_source","https://github.com/amvlab/aircraft-models")
	plane.set_meta("model_license","CC BY 4.0")
	# The source mesh has no landing gear or animated control surfaces. This small
	# procedural assembly is separate so existing G/gear behavior remains intact.
	var gear:=Node3D.new()
	gear.name="Gear"
	plane.add_child(gear)
	for pos in [Vector3(0,-2.5,11.7),Vector3(-3,-2.5,-2.0),Vector3(3,-2.5,-2.0)]:
		cylinder(gear,pos,.11,1.6,"9aa8ad")
		for side in [-1,1]:
			var wheel:=cylinder(gear,Vector3(pos.x+side*.3,-3.4,pos.z),.5,.32,"18232b")
			wheel.rotation.z=PI/2
			var hub:=cylinder(gear,Vector3(pos.x+side*.47,-3.4,pos.z),.23,.025,"91a0a5")
			hub.rotation.z=PI/2

func cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,color: String) -> MeshInstance3D:
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height
	mesh.radial_segments=12; mesh.rings=1
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh; instance.material_override=mat(color); instance.position=pos
	parent.add_child(instance)
	return instance

func ground_material() -> Material:
	if conservative_materials: return mat("536342")
	if materials.has("terrain_shader"): return materials.terrain_shader
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float macro=noise(world.xz*.0017);float field=noise(world.xz*.009);float grain=noise(world.xz*.4);vec3 low=mix(vec3(.19,.26,.16),vec3(.37,.39,.22),macro);vec3 high=vec3(.32,.35,.28);ALBEDO=mix(low,high,smoothstep(700.0,2800.0,world.y))*(.86+field*.2+grain*.06);ROUGHNESS=.98;}
"""
	var material:=ShaderMaterial.new(); material.shader=shader
	materials.terrain_shader=material
	return material

func pavement_material(color: String) -> Material:
	if conservative_materials: return mat(color)
	var key: String="pavement_"+color
	if materials.has(key): return materials[key]
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
uniform vec4 tint : source_color;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=hash(floor(world.xz*10.0));float slabs=step(.12,mod(world.x,16.0))*step(.1,mod(world.z,22.0));float touchdown=1.0-smoothstep(120.0,500.0,abs(abs(world.z)-1400.0));float d=(abs(world.x)-3.7)*.7;float skid=exp(-(d*d))*.045*touchdown;float fade=1.0-smoothstep(70.0,500.0,distance(CAMERA_POSITION_WORLD,world));ALBEDO=tint.rgb*(.92+grain*.12*fade)*(.9+.1*slabs)-vec3(skid*fade);ROUGHNESS=.94;}
"""
	var material:=ShaderMaterial.new(); material.shader=shader
	material.set_shader_parameter("tint",Color(color))
	materials[key]=material
	return material

func airport_details(elevation: float,key: String) -> void:
	# Architectural accents stay within existing terminal collider volumes.
	var facade_x:=399.4 if key=="can" else 337.0
	var top:=22.0 if key=="can" else 14.0
	box(root,Vector3(facade_x,elevation+top*.55,-440),Vector3(.4,top*.55,425),"244c5d")
	for z in range(-640,-239,12):
		box(root,Vector3(facade_x-.3,elevation+top*.55,z),Vector3(.7,top*.6,.6),"a6b8b8")
	for level in [top*.3,top*.58,top*.82]:
		box(root,Vector3(facade_x-.3,elevation+level,-440),Vector3(.7,.45,425),"a6b8b8")
	# Apron stand centerlines and restrained inset edge lights, no new obstacles.
	for z in [-620,-530,-350,-260]:
		box(root,Vector3(274,elevation+.31,z),Vector3(75,.04,.65),"f3c857")
		box(root,Vector3(238,elevation+.32,z),Vector3(.65,.04,20),"f3c857")
	for z in range(-1400,1401,120):
		box(root,Vector3(83,elevation+.5,z),Vector3(.55,.25,.55),"61aed8")

func batch_static_boxes() -> void:
	# One unit-cube MultiMesh per material replaces hundreds of individual boxes.
	# Geometry and collisions remain in their exact original world positions.
	var groups: Dictionary={}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var material=child.material_override
			if not groups.has(material): groups[material]=[]
			groups[material].append(child)
	for material in groups:
		var objects: Array=groups[material]
		var mesh:=BoxMesh.new(); mesh.size=Vector3.ONE
		var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=mesh; multi.instance_count=objects.size()
		for i in range(objects.size()):
			var object: MeshInstance3D=objects[i]
			var transform: Transform3D=object.transform
			transform.basis=transform.basis.scaled(object.mesh.size)
			multi.set_instance_transform(i,transform)
			root.remove_child(object); object.free()
		var batch:=MultiMeshInstance3D.new(); batch.multimesh=multi
		batch.material_override=material; batch.name="StaticBatch"
		root.add_child(batch)

func build_bki_runway(elevation: float,length: float) -> void:
	# Markings are authored game detail; the centerline/endpoints align to OSM.
	box(root,Vector3(0,elevation+.15,0),Vector3(45,.2,length),"303b42")
	for z in range(int(-length/2+60),int(length/2),64):
		box(root,Vector3(0,elevation+.29,z),Vector3(1.5,.04,31),"f2eee0")
	for x in [-21,21]: box(root,Vector3(x,elevation+.29,0),Vector3(.7,.04,length-40),"f2eee0")
	for sign_z in [-1,1]:
		for x in [-17,-12,-7,7,12,17]: box(root,Vector3(x,elevation+.3,sign_z*(length/2-48)),Vector3(2.8,.05,34),"f2eee0")
		for x in [-14,14]: box(root,Vector3(x,elevation+.3,sign_z*(length/2-290)),Vector3(5.5,.05,48),"f2eee0")
	for z in range(int(-length/2),int(length/2),100):
		for x in [-26,26]: box(root,Vector3(x,elevation+.8,z),Vector3(1.2,.6,1.2),"ffe2a0")
