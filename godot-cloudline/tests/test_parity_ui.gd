extends SceneTree
var count:=0
func check(value: bool,label_text: String) -> void:
	count+=1
	if not value: push_error(label_text); quit(1)
	else: print("PASS ",label_text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var h=g.hud
	check(is_instance_valid(h.mini_map) and is_instance_valid(h.pfd),"navigation and PFD exist")
	check(not g.ambience.audio_enabled,"audio opt-in default")
	g.start_flight("a320","can_approach","clear")
	h.menu.hide(); h.modal_shade.hide(); g.running=true
	check(g.guidance_rings.size()>20,"route approach guidance rings")
	check(is_equal_approx(g.heading_offset(),deg_to_rad(10)),"CAN reference heading")
	h.show_map("map")
	check(not g.running and h.map_panel.visible and h.big_map.mode=="map","map pauses")
	h.big_map.mode="route"
	check(h.big_map.mode=="route","route diagram mode")
	h.map_panel.hide(); h.modal_shade.hide()
	h.show_systems(); h.show_environment()
	check(h.environment_panel.visible and not h.systems.visible,"environment panel flow")
	h.environment_controls.weather.select(2); h.environment_controls.weather.item_selected.emit(2)
	check(g.flight.weather=="turbulent","live weather")
	h.environment_controls.light.select(2); h.environment_controls.light.item_selected.emit(2)
	check(g.light_mode=="night","live night selection")
	h.environment_controls.invert.button_pressed=true
	h.environment_controls.sensitivity.value=1.25
	check(g.invert_pitch and is_equal_approx(g.sensitivity,1.25),"inversion sensitivity")
	h.environment_panel.hide(); h.systems.hide(); h.modal_shade.hide()
	g.running=true
	var event:=InputEventScreenTouch.new()
	event.index=5;event.pressed=true;event.position=Vector2(600,260)
	h._input(event)
	var drag:=InputEventScreenDrag.new()
	drag.index=5;drag.position=Vector2(650,280)
	h._input(drag)
	check(g.look_x>.3 and g.look_y>.1,"camera drag")
	h.toggle_pause(); event.pressed=false;h._input(event);h.toggle_pause()
	check(h.look_id==-1,"camera drag reset across pause")
	for i in range(4): g.cycle_camera();check(g.look_x==0 and g.look_y==0 and g.zoom==1,"camera cycle reset "+str(i))
	check(g.camera_mode==0,"four camera modes cycle")
	h.show_systems()
	g.flight.ap.alt=1000;g.flight.ap.heading=.3;g.flight.ap.speed=80
	h.apply_ap()
	check(g.flight.ap.on and not g.route.guide and g.running,"AP apply engages and resumes")
	h.show_systems();h.return_to_airport()
	check(g.flight.ap.alt>=1500 and g.flight.ap.on,"return airport safe altitude target")
	g.start_flight("light","landing","clear")
	check(g.guidance_rings.size()>0 and not g.is_route,"island landing guides")
	h.apply_viewport_layout(Vector2(844,390))
	await process_frame
	await process_frame
	var scale:=minf(844.0/h.size.x,390.0/h.size.y)
	for key in h.buttons:
		var button=h.buttons[key]
		check(button.size.y*scale>=43.9,"44 CSS-px touch target "+key)
		check(button.position.y>=0 and button.position.y+button.size.y<=h.size.y,"button in bounds "+key)
	for a in h.buttons:
		for b in h.buttons:
			if a<b: check(not h.buttons[a].get_rect().intersects(h.buttons[b].get_rect()),"no touch overlap "+a+" "+b)
	g.running=true
	h.apply_viewport_layout(Vector2(390,844))
	check(h.rotate_shade.visible and not g.running,"portrait pauses and asks rotation")
	h.apply_viewport_layout(Vector2(844,390))
	check(not h.rotate_shade.visible and not g.running,"landscape requires explicit resume")
	check(h.menu.get_child(0) is ScrollContainer and h.systems.get_child(0) is ScrollContainer,"modal controls scroll on compact layout")
	h.apply_viewport_layout(Vector2(667,320))
	await process_frame
	await process_frame
	h.menu.hide();h.systems.hide();h.environment_panel.hide();h.map_panel.hide();h.modal_shade.hide()
	g.running=true;h.reset_controls()
	var rudder_touch:=InputEventScreenTouch.new()
	rudder_touch.index=4;rudder_touch.pressed=true
	rudder_touch.position=Vector2(100,h.buttons.yaw_l.position.y+4)
	h._input(rudder_touch)
	check(h.stick_id==-1 and h.stick==Vector2.ZERO,"667x320 rudder press never captures joystick")
	check(h.throttle_id==-1 and h.look_id==-1,"button press never captures throttle or camera")
	var stick_touch:=InputEventScreenTouch.new()
	stick_touch.index=5;stick_touch.pressed=true;stick_touch.position=h.stick_center()
	h._input(stick_touch)
	check(h.stick_id==5,"analog contact still captures outside GUI")
	stick_touch.pressed=false;stick_touch.position=rudder_touch.position;h._input(stick_touch)
	check(h.stick_id==-1 and h.stick==Vector2.ZERO,"existing analog release over button clears contact")
	g.flight.route=null
	print("PARITY_UI_SUMMARY ",count," checks")
	g.queue_free();await process_frame;quit()
