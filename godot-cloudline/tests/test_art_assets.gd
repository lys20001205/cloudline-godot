extends SceneTree
const World=preload("res://scripts/world_builder.gd")
const Flight=preload("res://scripts/flight_model.gd")
var checks:=0
var failures:=0
var triangles:=0
var meshes:=0
var surfaces:=0
var textures: Dictionary={}
var bounds:=AABB()
var first:=true
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1
	print("PASS " if value else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func inspect_mesh(node: Node, relative: Node3D) -> void:
	if node is MeshInstance3D:
		meshes+=1
		for surface in range(node.mesh.get_surface_count()):
			surfaces+=1
			var arrays=node.mesh.surface_get_arrays(surface)
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
			var material=node.get_active_material(surface)
			check(material is StandardMaterial3D,"imported PBR material")
			if material is StandardMaterial3D and material.albedo_texture:
				var tex=material.albedo_texture
				textures[str(tex.get_rid())]=[tex.get_width(),tex.get_height()]
		var local_box: AABB=relative.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
		bounds=local_box if first else bounds.merge(local_box)
		first=false
	for child in node.get_children(): inspect_mesh(child,relative)
func run() -> void:
	var host:=Node3D.new(); root.add_child(host)
	var builder=World.new()
	var plane: Node3D=builder.aircraft(host,"a320")
	check(plane.has_node("ImportedA320"),"A320 loads genuine imported PackedScene")
	check(plane.has_node("Gear"),"gear control contract preserved")
	inspect_mesh(plane.get_node("ImportedA320"),plane)
	check(meshes==1 and surfaces==1,"imported body uses one mesh and one surface")
	check(triangles==5229,"A320 original topology: 5229 triangles")
	check(textures.size()==1 and textures.values()[0]==[1024,1024],"single 1024-square texture atlas")
	check(bounds.size.z>37 and bounds.size.z<39,"meters preserved: 37.7 m length")
	check(bounds.size.x>35 and bounds.size.x<36,"meters preserved: 35.5 m visual span")
	check(abs(plane.get_node("ImportedA320").rotation.y+PI/2)<.001,"asset +X nose transformed to game +Z forward")
	check(plane.get_node("Gear").get_child_count()==15,"separate three struts and six wheel/hub pairs")
	plane.get_node("Gear").visible=false
	check(not plane.get_node("Gear").visible and plane.get_node("ImportedA320").visible,"gear retract leaves imported body visible")
	for type in ["light","jet"]:
		var fallback=builder.aircraft(host,type)
		check(fallback.has_node("Gear") and not fallback.has_node("ImportedA320"),type+" honest unchanged procedural fallback")
	var flight=Flight.new(); flight.reset("a320","runway","clear",true)
	var start_position: Vector3=flight.p
	var world: Node3D=builder.build(host,"bki",flight)
	var batches:=0
	var individual_boxes:=0
	for child in world.get_children():
		if child is MultiMeshInstance3D: batches+=1
		if child is MeshInstance3D and child.mesh is BoxMesh: individual_boxes+=1
	check(batches>0 and batches<25 and individual_boxes==0,"static airport geometry batched by material")
	check(flight.p==start_position,"art building does not mutate flight state")
	print("ART_ASSET_METRICS ",JSON.stringify({"triangles":triangles,"mesh_surfaces":surfaces,"textures":textures.values(),"bounds_meters":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]},"static_material_batches":batches}))
	print("ART_ASSETS_SUMMARY ",checks," checks; ",failures," failures")
	host.queue_free()
	await process_frame
	quit(1 if failures else 0)
