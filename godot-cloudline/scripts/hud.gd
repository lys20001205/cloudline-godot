extends Control
class_name CloudlineHUD
const Navigation = preload("res://scripts/navigation_display.gd")

var game: Node3D
var stick := Vector2.ZERO
var stick_id := -1
var throttle_id := -1
var brake := false
var yaw_input := 0.0
var buttons: Dictionary = {}
var menu: PanelContainer
var modal_shade: ColorRect
var aircraft_select: OptionButton
var mode_select: OptionButton
var weather_select: OptionButton
var font: Font = ThemeDB.fallback_font
var title_label: Label
var data_label: Label
var secondary_label: Label
var hint_label: Label
var notice_label: Label
var guide_button: Button
var paused := false
var systems: PanelContainer
var environment_panel: PanelContainer
var map_panel: PanelContainer
var mini_map: Control
var pfd: Control
var big_map: Control
var light_select: OptionButton
var environment_controls: Dictionary = {}
var rotate_shade: ColorRect
var rotate_label: Label
var css_size := Vector2.ZERO
var responsive_timer := 0.0
var touch_height := 60.0
var compact_ui := false
var look_id := -1
var look_previous := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loaded = load("res://assets/cloudline-ui.otf")
	if loaded: font=loaded
	var theme_new := Theme.new()
	theme_new.default_font = font
	theme_new.default_font_size = 18
	theme = theme_new
	title_label = text_label(Vector2(24,14),24)
	data_label = text_label(Vector2(24,51),21)
	secondary_label = text_label(Vector2(24,79),15)
	hint_label = text_label(Vector2(24,105),17)
	notice_label = text_label(Vector2(24,135),17)
	add_button("menu","菜单 / MENU",Vector2(-150,16),Vector2(130,60),func(): show_menu())
	add_button("pause","暂停",Vector2(-292,16),Vector2(130,60),func(): toggle_pause())
	guide_button=add_button("guide","教学领航 OFF",Vector2(-180,90),Vector2(160,60),func():
		game.route.guide = not game.route.guide
		game.flight.ap.on = false)
	add_button("skip","下一航段 →",Vector2(-180,160),Vector2(160,60),func(): game.route.request_next(game.flight))
	add_button("ap","AP 保持",Vector2(-180,230),Vector2(160,60),func(): game.flight.toggle_ap())
	add_button("gear","起落架 G",Vector2(290,-70),Vector2(120,60),func(): game.flight.set_gear())
	add_button("flaps","襟翼 F",Vector2(418,-70),Vector2(120,60),func(): game.flight.flaps = (game.flight.flaps+1)%4)
	add_button("camera","视角 C",Vector2(546,-70),Vector2(120,60),func(): game.cycle_camera())
	var br := add_button("brake","刹车 / SPACE",Vector2(-292,-70),Vector2(146,60),func(): pass)
	br.button_down.connect(func(): brake=true; game.route.cancel_guide(game.flight))
	br.button_up.connect(func(): brake=false)
	var yl := add_button("yaw_l","◀ 舵",Vector2(24,-70),Vector2(100,60),func(): pass)
	var yr := add_button("yaw_r","舵 ▶",Vector2(134,-70),Vector2(100,60),func(): pass)
	yl.button_down.connect(func(): yaw_input=-1.0; game.route.cancel_guide(game.flight))
	yl.button_up.connect(func(): yaw_input=0.0)
	yr.button_down.connect(func(): yaw_input=1.0; game.route.cancel_guide(game.flight))
	yr.button_up.connect(func(): yaw_input=0.0)
	add_button("systems","系统 / SYS",Vector2(676,-70),Vector2(130,60),func(): show_systems())
	add_button("map","地图 / MAP",Vector2(816,-70),Vector2(142,60),func(): show_map("map"))
	build_instruments()
	build_menu()
	build_systems()
	build_environment()
	build_map()
	for panel in [menu,systems,environment_panel,map_panel]: wrap_modal(panel)
	build_rotate_guidance()
	resized.connect(layout)
	layout()

func text_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position=pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	l.add_theme_constant_override("shadow_offset_x",2)
	l.add_theme_constant_override("shadow_offset_y",2)
	add_child(l)
	return l

func add_button(id: String, title: String, pos: Vector2, dim: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text=title
	b.custom_minimum_size=dim
	b.size=dim
	b.set_meta("layout_pos",pos)
	b.set_meta("base_size",dim)
	b.pressed.connect(callback)
	b.focus_mode=Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color=Color("173343d9")
	style.border_color=Color("74bca675")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	b.add_theme_stylebox_override("normal",style)
	buttons[id]=b
	add_child(b)
	return b

func layout() -> void:
	for b in buttons.values():
		var p: Vector2=b.get_meta("layout_pos")
		b.position=Vector2(size.x+p.x if p.x<0 else p.x,size.y+p.y if p.y<0 else p.y)
		if p.y<0: b.position.y=size.y-touch_height-16
		if b in [buttons.guide,buttons.skip,buttons.ap]:
			var index=[buttons.guide,buttons.skip,buttons.ap].find(b)
			b.position.y=touch_height+30+index*(touch_height+10)
	if mini_map:
		mini_map.position=Vector2(24,176)
		mini_map.size=Vector2(215,170)
	if pfd:
		pfd.position=Vector2(320,size.y-touch_height-192)
		pfd.size=Vector2(440,145)
	if map_panel:
		map_panel.size=Vector2(740,640)
		map_panel.position=(size-map_panel.size)/2
	if environment_panel:
		environment_panel.size=Vector2(700,620)
		environment_panel.position=(size-environment_panel.size)/2
	if systems:
		systems.size=Vector2(700,650)
		systems.position=(size-systems.size)/2
	if menu:
		menu.size=Vector2(680,540)
		menu.position=(size-menu.size)/2
	apply_viewport_layout()

func build_menu() -> void:
	modal_shade=ColorRect.new()
	modal_shade.color=Color(0,0,0,.22)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(modal_shade)
	menu=PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color=Color("102c3df5")
	style.set_corner_radius_all(22)
	style.content_margin_left=32
	style.content_margin_right=32
	style.content_margin_top=22
	style.content_margin_bottom=22
	menu.add_theme_stylebox_override("panel",style)
	add_child(menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	menu.add_child(col)
	var title := Label.new()
	title.text="云际飞行 / CLOUDLINE"
	title.add_theme_font_size_override("font_size",32)
	col.add_child(title)
	var subtitle := Label.new()
	subtitle.text="GODOT NATIVE + WEB PREVIEW · 0.2.0\nBKI → 南海 → CAN T3 · 建议横屏游玩"
	col.add_child(subtitle)
	aircraft_select=OptionButton.new()
	aircraft_select.custom_minimum_size.y=48
	for item in ["A320-216 · CFM56","L-4 教练机","J-120 双发客机"]: aircraft_select.add_item(item)
	col.add_child(aircraft_select)
	mode_select=OptionButton.new()
	mode_select.custom_minimum_size.y=48
	for item in ["A320 · BKI → CAN T3 完整航线","A320 · CAN 进近练习","A320 · CAN 滑行至 T3","岛屿 · 自由飞行","岛屿 · 引导圈挑战","岛屿 · 跑道起飞","岛屿 · 着陆练习"]: mode_select.add_item(item)
	col.add_child(mode_select)
	aircraft_select.disabled=true
	mode_select.item_selected.connect(func(index):
		aircraft_select.disabled=index<3
		if index<3: aircraft_select.select(0))
	weather_select=OptionButton.new()
	weather_select.custom_minimum_size.y=48
	for item in ["晴空无风","轻风","阵风 / 颠簸"]: weather_select.add_item(item)
	var environment_row := HBoxContainer.new()
	weather_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	environment_row.add_child(weather_select)
	light_select=OptionButton.new()
	for item in ["日间 DAY","黄昏 GOLDEN","夜航 NIGHT"]: light_select.add_item(item)
	light_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	light_select.custom_minimum_size.y=48
	environment_row.add_child(light_select)
	col.add_child(environment_row)
	var help := Label.new()
	help.text="左摇杆下拉抬头，左右压坡度；右滑杆油门\n键盘：方向键 / WASD · Q/E 方向舵 · +/- 油门\nG 起落架 · F 襟翼 · Space 刹车 · C 视角 · Esc 暂停\n教学领航默认关闭；操纵摇杆、油门或刹车可接管"
	help.add_theme_font_size_override("font_size",16)
	col.add_child(help)
	var start := Button.new()
	start.text="开始飞行 / START FLIGHT"
	start.custom_minimum_size.y=48
	start.pressed.connect(func():
		game.set_lighting(["day","golden","night"][light_select.selected])
		game.start_flight(["a320","light","jet"][aircraft_select.selected],["bki_can","can_approach","can_taxi","free","lesson","runway","landing"][mode_select.selected],["clear","breeze","turbulent"][weather_select.selected])
		menu.hide(); modal_shade.hide(); paused=false; game.running=true)
	col.add_child(start)
	var resume := Button.new()
	resume.text="继续当前飞行 / RESUME"
	resume.custom_minimum_size.y=40
	resume.pressed.connect(func(): menu.hide(); modal_shade.hide(); paused=false; game.running=true)
	col.add_child(resume)
	var disclaimer := Label.new()
	disclaimer.text="游戏近似 / 非训练用途 · 简化机场 / SIM-T3 虚构机位"
	disclaimer.add_theme_font_size_override("font_size",14)
	col.add_child(disclaimer)

func show_menu() -> void:
	game.running=false
	reset_controls()
	if systems: systems.hide()
	if environment_panel: environment_panel.hide()
	if map_panel: map_panel.hide()
	modal_shade.show()
	menu.show()

func toggle_pause() -> void:
	if menu.visible: return
	reset_controls()
	paused=not paused
	game.running=not paused
	buttons.pause.text="继续" if paused else "暂停"

func stick_center() -> Vector2:
	return Vector2(130,size.y-192)

func throttle_rect() -> Rect2:
	var top:=maxf(size.y-328,touch_height*4+90)
	return Rect2(size.x-114,top,72,maxf(120,size.y-106-top))

func _input(event: InputEvent) -> void:
	if rotate_shade and rotate_shade.visible: return
	if menu.visible or (systems and systems.visible) or (environment_panel and environment_panel.visible) or (map_panel and map_panel.visible): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE,KEY_P]:
			toggle_pause()
			return
		if not game.running: return
		match event.physical_keycode:
			KEY_G: game.flight.set_gear()
			KEY_F: game.flight.flaps=(game.flight.flaps+1)%4
			KEY_C, KEY_V: game.cycle_camera()
			KEY_H: game.flight.toggle_ap()
			KEY_R: game.start_flight(game.flight.type,game.flight.mode,game.flight.weather)
	if not game.running: return
	if event is InputEventScreenTouch:
		if event.pressed:
			# GUI buttons own new contacts, even when enlarged into analog hit areas.
			# Do not mark handled: the normal GUI path must receive this press.
			for button in buttons.values():
				if button.is_visible_in_tree() and button.get_rect().has_point(event.position): return
			if event.position.distance_to(stick_center())<100 and stick_id<0:
				stick_id=event.index
				stick=((event.position-stick_center())/75.0).limit_length(1.0)
			elif throttle_rect().grow(15).has_point(event.position):
				throttle_id=event.index
				set_throttle(event.position.y)
			elif event.position.x>250 and event.position.x<size.x-220 and event.position.y>160 and event.position.y<size.y-270:
				look_id=event.index
				look_previous=event.position
				if event.double_tap: game.look_x=0; game.look_y=0
		else:
			if event.index==stick_id: stick_id=-1; stick=Vector2.ZERO
			if event.index==throttle_id: throttle_id=-1
			if event.index==look_id: look_id=-1
	if event is InputEventScreenDrag:
		if event.index==stick_id: stick=((event.position-stick_center())/75.0).limit_length(1.0)
		if event.index==throttle_id: set_throttle(event.position.y)
		if event.index==look_id:
			var delta_pos: Vector2=event.position-look_previous
			game.look_x=clampf(game.look_x+delta_pos.x*.008,-2.8,2.8)
			game.look_y=clampf(game.look_y+delta_pos.y*.006,-.8,.8)
			look_previous=event.position
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: game.zoom=clampf(game.zoom-.1,.6,2.3)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: game.zoom=clampf(game.zoom+.1,.6,2.3)

func set_throttle(y: float) -> void:
	game.route.cancel_guide(game.flight)
	game.flight.ap.on=false
	var r := throttle_rect()
	game.flight.power=clampf(1.0-(y-r.position.y)/r.size.y,0,1)

func _process(_dt: float) -> void:
	responsive_timer+=_dt
	if OS.has_feature("web") and responsive_timer>.25:
		responsive_timer=0
		var current_css:=Vector2(float(JavaScriptBridge.eval("window.innerWidth")),float(JavaScriptBridge.eval("window.innerHeight")))
		if current_css!=css_size: css_size=current_css; layout()
	if not game or not game.flight: return
	var f=game.flight
	var r=game.route
	title_label.text="CLOUDLINE  /  %s  ·  %s" % [f.spec.name,r.phase_name if game.is_route else "自由飞行 / FREE FLIGHT"]
	data_label.text="%03d kt   |   %05d ft   |   V/S %+.0f ft/min   |   HDG %03d°" % [f.ias*1.94384,f.p.y*3.28084,f.v.y*196.85,fposmod(rad_to_deg(f.yaw+game.heading_offset()),360)]
	secondary_label.text="GS %d kt  ·  AGL %d ft  ·  %.1f G  ·  %02d:%02d" % [f.gs*1.94384,f.agl*3.28084,1.0 if f.grounded else f.load_factor,int(f.t)/60,int(f.t)%60]
	hint_label.text=r.hint(f) if game.is_route else ("引导圈 %d / %d · %s" % [f.gate,f.gates.size(),f.gates[mini(f.gate,f.gates.size()-1)].name] if f.mode=="lesson" else "探索岛屿 · 在跑道内安全着陆")
	notice_label.text="PAUSED · 点击继续" if paused else (f.crash_reason+" · 菜单可重新开始" if f.crashed else "  ".join(f.warnings))
	if f.touchdown and not f.crashed: notice_label.text="接地评分 %d / 100 · 下降率 %.1f m/s" % [f.touchdown.score,f.touchdown.sink]
	if r.finished: notice_label.text="BKI → CAN T3 完成 · 已在 SIM-T3 停稳"
	guide_button.text="教学领航 ON" if r.guide else "教学领航 OFF"
	buttons.gear.text="起落架 DOWN" if f.gear else "起落架 UP"
	buttons.flaps.text="襟翼 %d / 3" % f.flaps
	buttons.camera.text=["追尾 / C","驾驶舱 / C","翼侧 / C","环绕 / C"][game.camera_mode]
	buttons.ap.text="AP ON" if f.ap.on else "AP OFF"
	if compact_ui:
		buttons.menu.text="菜单"
		buttons.guide.text="领航 ON" if r.guide else "领航 OFF"
		buttons.skip.text="下一航段"
		buttons.gear.text="起落架"
		buttons.flaps.text="襟翼 %d/3" % f.flaps
		buttons.camera.text=["追尾","驾驶舱","翼侧","环绕"][game.camera_mode]
		buttons.systems.text="系统"
		buttons.map.text="地图"
		buttons.brake.text="刹车"
		buttons.yaw_l.text="◀ 舵"; buttons.yaw_r.text="舵 ▶"
	else:
		buttons.menu.text="菜单 / MENU"
		buttons.skip.text="下一航段 →"
		buttons.systems.text="系统 / SYS"
		buttons.map.text="地图 / MAP"
		buttons.brake.text="刹车 / SPACE"
	guide_button.disabled=not game.is_route
	buttons.skip.disabled=not game.is_route
	queue_redraw()

func _draw() -> void:
	if not game or not game.flight: return
	var f=game.flight
	draw_rect(Rect2(0,0,size.x,166),Color(0.025,.07,.10,.45))
	draw_circle(stick_center(),88,Color(.03,.12,.17,.55))
	draw_arc(stick_center(),88,0,TAU,64,Color(.5,.8,.75,.7),2,true)
	draw_line(stick_center()-Vector2(60,0),stick_center()+Vector2(60,0),Color(.6,.8,.8,.3),1)
	draw_line(stick_center()-Vector2(0,60),stick_center()+Vector2(0,60),Color(.6,.8,.8,.3),1)
	draw_circle(stick_center()+stick*65,22,Color(.55,.94,.79,.8))
	draw_string(font,stick_center()+Vector2(-42,115),"PITCH / ROLL",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	var r := throttle_rect()
	draw_rect(r,Color(.03,.12,.17,.65))
	draw_rect(Rect2(r.position+Vector2(9,r.size.y*(1-f.power)),Vector2(r.size.x-18,r.size.y*f.power)),Color(.4,.85,.67,.65))
	draw_rect(r,Color(.5,.8,.75,.8),false,2)
	draw_string(font,r.position+Vector2(-2,-12),"THR %d%%" % (f.power*100),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	var c := size/2
	draw_line(c+Vector2(-36,0),c+Vector2(-10,0),Color(.75,1,.9,.8),2)
	draw_line(c+Vector2(10,0),c+Vector2(36,0),Color(.75,1,.9,.8),2)
	draw_circle(c,3,Color(.75,1,.9,.8))
	if game.camera_mode==1:
		var origin:=Vector2(size.x/2,size.y*.43)
		var angle: float=-f.bank
		for degree in range(-30,31,5):
			var y: float=(rad_to_deg(f.pitch)-degree)*2.7
			var half_length:=40.0 if degree%10==0 else 19.0
			var a:=origin+Vector2(-half_length,y).rotated(angle)
			var b:=origin+Vector2(half_length,y).rotated(angle)
			if absf(a.y-origin.y)<72 and absf(b.y-origin.y)<72:
				draw_line(a,b,Color(.8,1,.85,.65),1.5)
				if degree!=0 and degree%10==0: draw_string(font,b+Vector2(5,4),str(absi(degree)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	if not f.grounded and f.gs>5 and game.camera_mode<2:
		var world_point: Vector3=f.p+f.v.normalized()*700
		if not game.camera.is_position_behind(world_point):
			var point: Vector2=game.camera.unproject_position(world_point)
			if point.x>245 and point.x<size.x-195 and point.y>170 and point.y<size.y-265:
				draw_arc(point,6,0,TAU,24,Color(.8,1,.85,.8),1.5)
				draw_line(point-Vector2(17,0),point-Vector2(6,0),Color(.8,1,.85,.8),1.5)
				draw_line(point+Vector2(6,0),point+Vector2(17,0),Color(.8,1,.85,.8),1.5)
	if game.is_route:
		draw_rect(Rect2(290,size.y-touch_height-36,size.x-610,4),Color(.1,.3,.35,.7))
		draw_rect(Rect2(290,size.y-touch_height-36,(size.x-610)*game.route.progress,4),Color(.4,.9,.72))

func reset_controls() -> void:
	stick=Vector2.ZERO
	stick_id=-1
	throttle_id=-1
	brake=false
	yaw_input=0.0
	look_id=-1

func build_systems() -> void:
	systems=PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color=Color("102c3df9")
	style.set_corner_radius_all(18)
	style.content_margin_left=28
	style.content_margin_right=28
	style.content_margin_top=24
	style.content_margin_bottom=24
	systems.add_theme_stylebox_override("panel",style)
	add_child(systems)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	systems.add_child(col)
	var title := Label.new()
	title.text="飞行系统 / FLIGHT SYSTEMS"
	title.add_theme_font_size_override("font_size",25)
	col.add_child(title)
	for item in [["发动机 / ENGINE","engine"],["减速板 / SPEEDBRAKE","speedbrake"],["辅助稳定 / STABILITY ASSIST","assist"]]:
		var check := CheckButton.new()
		check.text=item[0]
		check.name=item[1]
		check.custom_minimum_size.y=48
		check.toggled.connect(func(value): game.flight.set(item[1],value))
		col.add_child(check)
	add_system_slider(col,"配平 TRIM","trim",-.12,.12,.005)
	add_system_slider(col,"AP 高度 FT","alt",300,41000,100)
	add_system_slider(col,"AP 航向 °","heading",0,359,1)
	add_system_slider(col,"AP 空速 kt","speed",60,340,5)
	var action_row := HBoxContainer.new()
	for item in [["应用 AP 目标",apply_ap],["返机场航向",return_to_airport],["环境 / 操纵",show_environment]]:
		var action:=Button.new()
		action.text=item[0]
		action.custom_minimum_size=Vector2(200,48)
		action.pressed.connect(item[1])
		action_row.add_child(action)
	col.add_child(action_row)
	var explain := Label.new()
	explain.text="AP 只保持高度、航向、空速；不执行自动着陆
空中接通 AP 后可在此调整目标；手动操纵立即断开"
	explain.add_theme_font_size_override("font_size",16)
	col.add_child(explain)
	var close := Button.new()
	close.text="返回飞行 / RETURN"
	close.custom_minimum_size.y=56
	close.pressed.connect(func(): systems.hide(); modal_shade.hide(); game.running=true; paused=false)
	col.add_child(close)
	systems.hide()

func add_system_slider(col: VBoxContainer, title: String, id: String, low: float, high: float, step_size: float) -> void:
	var row := HBoxContainer.new()
	var label_node := Label.new()
	label_node.text=title
	label_node.custom_minimum_size.x=180
	row.add_child(label_node)
	var slider := HSlider.new()
	slider.name=id
	slider.min_value=low
	slider.max_value=high
	slider.step=step_size
	slider.custom_minimum_size=Vector2(290,44)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x=70
	row.add_child(value_label)
	slider.value_changed.connect(func(value):
		value_label.text="%.3f" % value if id=="trim" else "%d" % value
		if id=="trim": game.flight.trim=value
		elif id=="heading": game.flight.ap.heading=deg_to_rad(value)-game.heading_offset()
		elif id=="speed": game.flight.ap.speed=value/1.94384
		else: game.flight.ap.alt=value/3.28084)
	col.add_child(row)

func show_systems() -> void:
	if not game.flight.ap.on:
		game.flight.ap.alt=game.flight.p.y
		game.flight.ap.heading=game.flight.yaw
		game.flight.ap.speed=game.flight.ias
	reset_controls()
	game.running=false
	modal_shade.show()
	systems.show()
	var col=get_content(systems)
	for key in ["engine","speedbrake","assist"]: col.get_node(key).set_pressed_no_signal(game.flight.get(key))
	for child in col.get_children():
		if child is HBoxContainer and child.get_child_count()==3 and child.get_child(1) is HSlider:
			var slider=child.get_child(1)
			var id=slider.name
			var value=game.flight.trim if id=="trim" else game.flight.ap[id]
			if id=="heading": value=fposmod(rad_to_deg(value+game.heading_offset()),360)
			if id=="speed": value*=1.94384
			if id=="alt": value*=3.28084
			slider.set_value_no_signal(value)
			child.get_child(2).text="%.3f" % value if id=="trim" else "%d" % value
	layout()

func build_instruments() -> void:
	mini_map=Navigation.new()
	mini_map.game=game; mini_map.mode="mini"; mini_map.font=font
	mini_map.mouse_filter=Control.MOUSE_FILTER_STOP
	mini_map.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: show_map("map"))
	add_child(mini_map)
	pfd=Navigation.new()
	pfd.game=game; pfd.mode="pfd"; pfd.font=font
	pfd.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(pfd)

func build_map() -> void:
	map_panel=make_panel(Vector2(740,640))
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	map_panel.add_child(col)
	var title:=Label.new()
	title.text="导航 / NAVIGATION"
	title.add_theme_font_size_override("font_size",26)
	col.add_child(title)
	big_map=Navigation.new()
	big_map.game=game; big_map.font=font; big_map.mode="map"
	big_map.custom_minimum_size=Vector2(670,440)
	col.add_child(big_map)
	var row:=HBoxContainer.new()
	for item in [["机场局部","map"],["BKI → CAN 航路","route"]]:
		var button:=Button.new()
		button.text=item[0]
		button.custom_minimum_size=Vector2(210,52)
		button.pressed.connect(func(): big_map.mode=item[1]; big_map.queue_redraw())
		row.add_child(button)
	var close:=Button.new()
	close.text="返回飞行"
	close.custom_minimum_size=Vector2(210,52)
	close.pressed.connect(func(): map_panel.hide(); modal_shade.hide(); game.running=true; paused=false)
	row.add_child(close)
	col.add_child(row)
	map_panel.hide()

func show_map(mode: String) -> void:
	if menu.visible: return
	reset_controls()
	game.running=false
	modal_shade.show(); map_panel.show()
	big_map.mode=mode
	big_map.queue_redraw()
	layout()

func make_panel(dim: Vector2) -> PanelContainer:
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("102c3df9")
	style.set_corner_radius_all(18)
	style.content_margin_left=28; style.content_margin_right=28
	style.content_margin_top=22; style.content_margin_bottom=22
	panel.add_theme_stylebox_override("panel",style)
	panel.size=dim
	add_child(panel)
	return panel

func build_environment() -> void:
	environment_panel=make_panel(Vector2(700,620))
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	environment_panel.add_child(col)
	var title:=Label.new()
	title.text="环境与操纵 / ENVIRONMENT"
	title.add_theme_font_size_override("font_size",25)
	col.add_child(title)
	for item in [["天气","weather",["晴空无风","微风侧风","轻度颠簸"]],["光照","light",["日间 DAY","黄昏 GOLDEN","夜航 NIGHT"]],["画质","quality",["省电","均衡","高清"]]]:
		var row:=HBoxContainer.new()
		var label_node:=Label.new()
		label_node.text=item[0]
		label_node.custom_minimum_size.x=180
		row.add_child(label_node)
		var select:=OptionButton.new()
		select.custom_minimum_size=Vector2(380,48)
		for choice in item[2]: select.add_item(choice)
		select.item_selected.connect(func(index):
			if item[1]=="weather": game.flight.weather=["clear","breeze","turbulent"][index]
			elif item[1]=="light": game.set_lighting(["day","golden","night"][index])
			else: get_viewport().scaling_3d_scale=[.8,1.0,1.3][index])
		environment_controls[item[1]]=select
		row.add_child(select)
		col.add_child(row)
	for item in [["发动机声音 / SOUND","sound"],["反转摇杆俯仰 / INVERT","invert"]]:
		var check:=CheckButton.new()
		check.text=item[0]
		check.custom_minimum_size.y=48
		check.toggled.connect(func(value):
			if item[1]=="sound":
				var available: bool=game.ambience.set_audio_enabled(value)
				environment_controls.sound.text="声音不可用 / NO OUTPUT" if value and not available else "发动机声音 / SOUND"
			else: game.invert_pitch=value)
		environment_controls[item[1]]=check
		col.add_child(check)
	var sensitivity_label:=Label.new()
	sensitivity_label.text="操纵灵敏度 / SENSITIVITY 0.45–1.50"
	col.add_child(sensitivity_label)
	var slider:=HSlider.new()
	slider.min_value=.45; slider.max_value=1.5; slider.step=.05
	slider.custom_minimum_size.y=44
	slider.value_changed.connect(func(value): game.sensitivity=value)
	environment_controls.sensitivity=slider
	col.add_child(slider)
	var fullscreen:=Button.new()
	fullscreen.text="切换全屏 / FULLSCREEN"
	fullscreen.custom_minimum_size.y=48
	fullscreen.pressed.connect(func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	col.add_child(fullscreen)
	var close:=Button.new()
	close.text="返回飞行系统"
	close.custom_minimum_size.y=52
	close.pressed.connect(func(): environment_panel.hide(); systems.show())
	col.add_child(close)
	environment_panel.hide()

func show_environment() -> void:
	systems.hide()
	environment_panel.show()
	environment_controls.weather.select(["clear","breeze","turbulent"].find(game.flight.weather))
	environment_controls.light.select(["day","golden","night"].find(game.light_mode))
	environment_controls.quality.select(0 if get_viewport().scaling_3d_scale<.9 else 2 if get_viewport().scaling_3d_scale>1.1 else 1)
	environment_controls.invert.set_pressed_no_signal(game.invert_pitch)
	environment_controls.sound.set_pressed_no_signal(game.ambience.audio_enabled)
	environment_controls.sensitivity.set_value_no_signal(game.sensitivity)
	layout()

func apply_ap() -> void:
	if game.flight.grounded: return
	game.flight.ap.on=true
	game.flight.ap.integral=game.flight.power
	game.flight.ap.alt=clampf(game.flight.ap.alt,300/3.28084,(41000 if game.flight.type=="a320" else 20000)/3.28084)
	game.flight.ap.speed=clampf(game.flight.ap.speed,(60 if game.flight.type=="light" else 140)/1.94384,(155 if game.flight.type=="light" else 340)/1.94384)
	game.route.guide=false
	systems.hide(); modal_shade.hide(); game.running=true; paused=false

func return_to_airport() -> void:
	if game.flight.grounded: return
	game.flight.ap.alt=maxf(game.flight.p.y,1500)
	game.flight.ap.heading=atan2(-game.flight.p.x,-game.flight.p.z)
	game.flight.ap.speed=game.flight.spec.cruise
	apply_ap()

func wrap_modal(panel: PanelContainer) -> void:
	var content=panel.get_child(0)
	panel.remove_child(content)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	panel.set_meta("content",content)

func get_content(panel: PanelContainer):
	return panel.get_meta("content") if panel.has_meta("content") else panel.get_child(0)

func build_rotate_guidance() -> void:
	rotate_shade=ColorRect.new()
	rotate_shade.color=Color("102c3d")
	rotate_shade.mouse_filter=Control.MOUSE_FILTER_STOP
	rotate_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rotate_shade)
	rotate_label=Label.new()
	rotate_label.text="请将手机横屏
ROTATE TO LANDSCAPE
横屏后点击继续飞行"
	rotate_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	rotate_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rotate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_shade.add_child(rotate_label)
	rotate_shade.hide()

func apply_viewport_layout(override_css: Vector2 = Vector2.ZERO) -> void:
	var pixels:=override_css
	if pixels==Vector2.ZERO:
		pixels=size if DisplayServer.get_name()=="headless" else css_size if css_size!=Vector2.ZERO else Vector2(DisplayServer.window_get_size())
	if pixels.x<=0 or pixels.y<=0 or size.x<=0 or size.y<=0: return
	var factor:=minf(pixels.x/size.x,pixels.y/size.y)
	if rotate_shade and pixels.y>pixels.x:
		if not rotate_shade.visible:
			game.running=false; paused=true; reset_controls(); buttons.pause.text="继续"
		rotate_shade.show()
		rotate_label.add_theme_font_size_override("font_size",maxi(26,ceili(22/maxf(factor,.1))))
		return
	if rotate_shade: rotate_shade.hide()
	compact_ui=factor<.75
	touch_height=maxf(60,ceilf(44/maxf(factor,.1)))
	var font_size:=maxi(18,ceili(13/maxf(factor,.1)))
	if compact_ui:
		for key in {"menu":"菜单","guide":"领航 OFF","skip":"下一航段","gear":"起落架","flaps":"襟翼 0/3","camera":"追尾","systems":"系统","map":"地图","brake":"刹车"}:
			buttons[key].text={"menu":"菜单","guide":"领航 OFF","skip":"下一航段","gear":"起落架","flaps":"襟翼 0/3","camera":"追尾","systems":"系统","map":"地图","brake":"刹车"}[key]
	for b in buttons.values():
		b.custom_minimum_size.y=touch_height
		b.size=Vector2(b.get_meta("base_size").x,touch_height)
		b.add_theme_font_size_override("font_size",font_size)
		var pos: Vector2=b.get_meta("layout_pos")
		if pos.y<0: b.position.y=size.y-touch_height-16
	for i in range(3): buttons[["guide","skip","ap"][i]].position.y=touch_height+30+i*(touch_height+10)
	for panel in [menu,systems,environment_panel,map_panel]:
		if not panel or not panel.has_meta("content"): continue
		panel.custom_minimum_size.y=0
		panel.size.y=minf(panel.size.y,size.y-32)
		panel.position.y=(size.y-panel.size.y)/2
		apply_touch_sizes(get_content(panel),touch_height,font_size)
	if pfd: pfd.position.y=size.y-touch_height-192
	if rotate_shade:
		var portrait:=pixels.y>pixels.x
		if portrait and not rotate_shade.visible:
			game.running=false; paused=true; reset_controls()
			buttons.pause.text="继续"
		rotate_shade.visible=portrait
		rotate_label.add_theme_font_size_override("font_size",maxi(26,ceili(22/maxf(factor,.1))))

func apply_touch_sizes(node: Node, min_height: float, font_size: int) -> void:
	if node is BaseButton or node is Slider:
		node.custom_minimum_size.y=min_height
		if node is BaseButton: node.add_theme_font_size_override("font_size",font_size)
	if node is Label:
		if not node.has_meta("base_font_size"): node.set_meta("base_font_size",node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size",maxi(font_size,node.get_meta("base_font_size")))
	for child in node.get_children(): apply_touch_sizes(child,min_height,font_size)
