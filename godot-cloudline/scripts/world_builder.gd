extends RefCounted
class_name CloudlineWorld

var root: Node3D
var materials: Dictionary = {}

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
	n.material_override = mat(color)
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
	if key != "sea":
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
	return root

func aircraft(parent: Node3D, type: String) -> Node3D:
	var plane := Node3D.new()
	parent.add_child(plane)
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
	instance.material_override=mat("607d59")
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
