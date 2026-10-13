extends SceneTree
func _initialize() -> void:
	var folder="res://assets/geodata/bki/mobile/" if "--mobile" in OS.get_cmdline_user_args() else "res://assets/geodata/bki/"
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".bin"): continue
		var stream=FileAccess.open(folder+file,FileAccess.READ)
		var count=stream.get_32()
		var values=stream.get_buffer(count*40).to_float32_array()
		var vertices=PackedVector3Array(); var normals=PackedVector3Array();var colors=PackedColorArray()
		vertices.resize(count);normals.resize(count);colors.resize(count)
		for i in range(count):
			var j=i*10
			vertices[i]=Vector3(values[j],values[j+1],values[j+2])
			normals[i]=Vector3(values[j+3],values[j+4],values[j+5])
			colors[i]=Color(values[j+6],values[j+7],values[j+8],1)
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
		var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.95
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0,mat)
		var path=folder+file.replace(".bin",".res")
		var err=ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
		print(path," vertices=",count," save=",err)
		if err!=OK:quit(1);return
	quit()
