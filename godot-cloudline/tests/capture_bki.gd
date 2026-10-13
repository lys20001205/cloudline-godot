extends SceneTree
## Native graphical capture. Headless cannot validate rendering.
var game
var output := "/tmp/cloudline-art"
var metrics := {}
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Graphical renderer required for visual evidence")
		quit(2)
		return
	if OS.get_cmdline_user_args().size(): output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.running=false
	game.set_physics_process(false)
	game.hud.hide()
	game.start_flight("a320","bki_can","clear")
	game.flight.p=Vector3(0,game.flight.elevation+3.9,-900)
	game.flight.yaw=0; game.flight.pitch=0; game.flight.bank=0
	game.update_visuals(1.0)
	game.camera.position=game.flight.p+Vector3(42,14,49)
	game.camera.look_at(game.flight.p+Vector3(0,1,-1),Vector3.UP)
	game.camera.fov=48
	await shot("aircraft-ground")
	game.camera.position=Vector3(1900,1500,-3800)
	game.camera.look_at(Vector3(-400,0,0),Vector3.UP)
	game.camera.fov=65
	await shot("bki-coastal")
	game.camera.position=Vector3(-1200,650,900)
	game.camera.look_at(Vector3(-250,0,-400),Vector3.UP)
	game.camera.fov=65
	await shot("bki-airport")
	var file=FileAccess.open(output+"/native-render-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	file.close()
	game.queue_free()
	game=null
	for frame in range(4): await process_frame
	quit()
func shot(label: String) -> void:
	for frame in range(90): await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(output+"/"+label+".png")
	metrics[label]={"png_error":error,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"fps_observed":Performance.get_monitor(Performance.TIME_FPS),"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"viewport":[1280,720]}
	print("CAPTURE ",label," ",JSON.stringify(metrics[label]))
