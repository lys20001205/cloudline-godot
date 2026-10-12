extends SceneTree
var checked := 0
func check(ok: bool, label_text: String) -> void:
	checked+=1
	if not ok:
		push_error("FAIL "+label_text)
		quit(1)
		return
	print("PASS "+label_text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var h=game.hud
	check(h.menu.visible and not game.running,"menu start paused")
	check(h.aircraft_select.disabled,"route aircraft visibly locked")
	check(h.modal_shade.mouse_filter==Control.MOUSE_FILTER_STOP,"modal blocks controls")
	game.start_flight("light","can_approach","clear")
	check(game.flight.type=="a320","invalid route aircraft prevented")
	h.menu.hide(); h.modal_shade.hide(); game.running=true
	var touch:=InputEventScreenTouch.new()
	touch.index=3; touch.pressed=true; touch.position=h.stick_center()+Vector2(0,60)
	h._input(touch)
	check(h.stick_id==3 and h.stick.y>.7,"touch pitch")
	var throttle:=InputEventScreenTouch.new()
	throttle.index=4; throttle.pressed=true; throttle.position=h.throttle_rect().position+Vector2(25,22)
	h._input(throttle)
	check(h.throttle_id==4 and h.stick_id==3 and game.flight.power>.8,"independent simultaneous throttle")
	h.toggle_pause()
	touch.pressed=false; h._input(touch)
	h.toggle_pause()
	check(h.stick_id==-1 and h.throttle_id==-1 and h.stick==Vector2.ZERO,"pause clears contacts even if released while paused")
	h.yaw_input=1; h.brake=true; h.show_menu()
	check(h.yaw_input==0 and not h.brake,"menu clears rudder and brake")
	game.start_flight("light","lesson","clear")
	check(game.flight.type=="light" and game.flight.mode=="lesson" and game.flight.grounded,"original island lesson runway start")
	check(game.gate_nodes.size()==game.flight.gates.size(),"original lesson gates rendered")
	game.start_flight("jet","landing","breeze")
	check(game.flight.type=="jet" and not game.flight.grounded and not game.is_route,"island landing aircraft and weather")
	h.menu.hide(); h.modal_shade.hide(); h.show_systems()
	check(h.systems.visible and not game.running,"systems pauses simulation")
	var col=h.get_content(h.systems)
	col.get_node("engine").button_pressed=false
	check(not game.flight.engine,"engine control")
	col.get_node("speedbrake").button_pressed=true
	check(game.flight.speedbrake,"speedbrake control")
	col.get_node("assist").button_pressed=false
	check(not game.flight.assist,"assist control")
	for row in col.get_children():
		if row is HBoxContainer and row.get_child_count()==3 and row.get_child(1) is HSlider:
			var slider=row.get_child(1)
			if slider.name=="trim": slider.value=.05
			if slider.name=="alt": slider.value=3000
			if slider.name=="heading": slider.value=90
			if slider.name=="speed": slider.value=180
	check(absf(game.flight.trim-.05)<.001,"trim control")
	check(absf(game.flight.ap.alt-3000/3.28084)<.001 and absf(game.flight.ap.heading-PI/2)<.001 and absf(game.flight.ap.speed-180/1.94384)<.001,"AP targets")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.running and h.stick==Vector2.ZERO,"focus loss pauses and clears input")
	print("UI_SUMMARY ",checked," checks passed")
	game.flight.route=null
	game.queue_free()
	await process_frame
	quit()
