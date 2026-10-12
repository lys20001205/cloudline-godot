extends SceneTree
## Run: godot --headless --path godot-cloudline --script tests/test_navigation.gd
const Navigation = preload("res://scripts/navigation_display.gd")
const Flight = preload("res://scripts/flight_model.gd")
const Mission = preload("res://scripts/route_mission.gd")

class GameStub extends Node:
	var flight
	var route

class TerrainProbe extends RefCounted:
	var airport_key: String = "navigation_test_probe"
	var samples: int = 0
	func terrain_height(_x: float, _z: float) -> float:
		samples += 1
		return -20.0

var checked: int = 0
var failed: bool = false
var render_count: int = 0


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failed = true
		push_error("FAILED: " + label)


func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00001, label)


func _initialize() -> void:
	call_deferred("run")


func snapshot(flight, mission) -> String:
	var state: Dictionary = {}
	for property in flight.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			state[property.name] = flight.get(property.name)
	var route_state: Dictionary = {}
	for property in mission.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			route_state[property.name] = mission.get(property.name)
	return var_to_str([state, route_state])


func run() -> void:
	near(Navigation.heading_degrees(0.0, "bki"), 20.0, "BKI heading offset")
	near(Navigation.heading_degrees(0.0, "can"), 10.0, "CAN heading offset")
	near(Navigation.heading_degrees(0.0, "island"), 0.0, "island heading offset")
	near(Navigation.heading_degrees(0.0, "sea"), 0.0, "sea heading offset")
	near(Navigation.heading_degrees(deg_to_rad(-30), "bki"), 350.0, "negative heading wraps")
	near(Navigation.heading_degrees(TAU, "can"), 10.0, "full-turn heading wraps")
	near(Navigation.airport_distance_nm(Vector3(1852, 12345, 0)), 1.0, "distance ignores altitude")
	near(Navigation.airport_distance_nm(Vector3.ZERO), 0.0, "origin distance")
	near(Navigation.airport_bearing_degrees(Vector3(0, 0, -1000), "bki"), 20.0, "airport ahead bearing")
	near(Navigation.airport_bearing_degrees(Vector3(1000, 0, 0), "can"), 280.0, "airport west bearing")
	near(Navigation.airport_bearing_degrees(Vector3.ZERO, "island"), 0.0, "coincident bearing defined")
	near(Navigation.airport_pointer_angle(Vector3(0, 0, -1000), 0.0), 0.0, "airport pointer ahead")
	near(Navigation.airport_pointer_angle(Vector3(0, 0, -1000), PI / 2), -PI / 2, "airport pointer relative to yaw")
	var dimensions: Vector2 = Vector2(600, 420)
	check(Navigation.world_to_map(Vector2.ZERO, dimensions, Vector3(1200, 0, 600), true) == dimensions * 0.5, "large map anchored to airport")
	near(Navigation.map_scale(dimensions, true), 420.0 / 15000.0, "large map span")
	near(Navigation.map_scale(Vector2(215, 160)), 160.0 / 8500.0, "mini map span")
	check(Navigation.map_center(Vector3(1000, 0, 2000)) == Vector2(650, 1300), "mini map aircraft follow factor")
	check(Navigation.world_to_map(Vector2(0, 100), dimensions).y < dimensions.y / 2, "north projects up")
	check(Navigation.world_to_map(Vector2(100, 0), dimensions).x > dimensions.x / 2, "east projects right")
	for big in [false, true]:
		var point: Vector2 = Vector2(2300, -4100)
		var position_3d: Vector3 = Vector3(890, 1200, -4500)
		var projected: Vector2 = Navigation.world_to_map(point, dimensions, position_3d, big)
		check(Navigation.map_to_world(projected, dimensions, position_3d, big).is_equal_approx(point), "projection inverse " + str(big))
	check(Navigation.map_to_world(Vector2.ONE, Vector2.ZERO).is_finite(), "zero-size projection safe")
	check(Navigation.route_curve_point(0, dimensions).is_equal_approx(Vector2(420, 331.8)), "route starts BKI")
	check(Navigation.route_curve_point(1, dimensions).is_equal_approx(Vector2(204, 84)), "route ends CAN")
	check(Navigation.route_marker_point(-2, dimensions) == Navigation.route_marker_point(0, dimensions), "route lower bound")
	check(Navigation.route_marker_point(2, dimensions) == Navigation.route_marker_point(1, dimensions), "route upper bound")
	check(Navigation.route_marker_point(0.5, dimensions).is_equal_approx(Vector2(312, 207.9)), "original linear progress marker")
	check(Navigation.engine_readout("a320", true, 0.0) == "22%", "jet idle N1")
	check(Navigation.engine_readout("jet", true, 1.0) == "98%", "jet full N1")
	check(Navigation.engine_readout("light", true, 0.0) == "650", "light idle RPM")
	check(Navigation.engine_readout("light", true, 1.0) == "2700", "light full RPM")
	check(Navigation.engine_readout("a320", false, 0.0) == "0%", "engine stopped")
	check(Navigation.engine_readout("a320", false, 0.5) == "38%", "engine shutdown spool visible")
	check(Navigation.gate_color(1, 2) == Color("607c70"), "passed gate dimmed")
	check(Navigation.gate_color(2, 2) == Color("e9c98f"), "current gate highlighted")
	check(Navigation.gate_color(3, 2) == Color("b4dacf"), "future gate mint")
	var segment: PackedVector2Array = Navigation.circle_clipped_line(Vector2(-100, 0), Vector2(100, 0), 38)
	check(segment.size() == 2 and segment[0].is_equal_approx(Vector2(-38, 0)) and segment[1].is_equal_approx(Vector2(38, 0)), "horizon clipped to circle")
	check(Navigation.circle_clipped_line(Vector2(-100, 50), Vector2(100, 50), 38).is_empty(), "outside ladder hidden")
	check(Navigation.circle_clipped_line(Vector2.ZERO, Vector2.ZERO, 38).is_empty(), "zero-length clipping safe")
	for angle in [-1.0, 0.0, 1.0]:
		segment = Navigation.circle_clipped_line(Vector2(-100, 10).rotated(angle), Vector2(100, 10).rotated(angle), 38)
		check(segment.size() == 2 and absf(segment[0].length() - 38) < 0.0001 and absf(segment[1].length() - 38) < 0.0001, "banked horizon clipping " + str(angle))
	check(Navigation.terrain_color(-1) == Color8(26, 66, 77), "water terrain color")
	check(Navigation.terrain_color(0) == Color8(83, 109, 83), "low terrain color")
	check(Navigation.terrain_color(100) == Color8(65, 93, 69), "middle terrain color")
	check(Navigation.terrain_color(3000) == Color8(127, 140, 98), "high terrain color bounded")
	var probe := TerrainProbe.new()
	var cached: Texture2D = Navigation.terrain_texture(probe)
	check(probe.samples == 40000 and cached.get_size() == Vector2(200, 200), "terrain generated at original resolution")
	check(Navigation.terrain_texture(probe) == cached and probe.samples == 40000, "terrain cache avoids resampling")
	probe.airport_key = "navigation_test_second_airport"
	check(Navigation.terrain_texture(probe) != cached and probe.samples == 80000, "airport change uses separate terrain cache")
	check(Navigation.terrain_texture(null) == null, "missing flight texture safe")
	var game := GameStub.new()
	game.flight = Flight.new()
	game.route = Mission.new()
	game.route.configure(game.flight, "takeoff")
	root.add_child(game)
	var navigation := Navigation.new()
	navigation.game = game
	navigation.size = Vector2(420, 160)
	navigation.draw.connect(func(): render_count += 1)
	root.add_child(navigation)
	check(navigation.clip_contents and navigation.mouse_filter == Control.MOUSE_FILTER_IGNORE, "clipped non-interactive control")
	var loaded_font = load("res://assets/cloudline-ui.otf")
	if loaded_font != null:
		navigation.font = loaded_font
	for airport in ["island", "bki", "can", "sea"]:
		game.flight.select_airport(airport)
		game.flight.mode = "lesson" if airport == "island" else "bki_can"
		game.flight.gate = 2
		var before: String = snapshot(game.flight, game.route)
		for display_mode in ["mini", "map", "route", "pfd"]:
			var previous_renders: int = render_count
			navigation.mode = display_mode
			navigation.size = Vector2(215, 160) if display_mode == "mini" else Vector2(420, 160) if display_mode == "pfd" else Vector2(600, 420)
			navigation.queue_redraw()
			await process_frame
			await process_frame
			check(render_count > previous_renders, "draw callback " + airport + "/" + display_mode)
		check(snapshot(game.flight, game.route) == before, "all displays leave flight and mission unchanged " + airport)
	navigation.mode = "pfd"
	var previous_renders: int = render_count
	for pitch in [-PI / 2, -0.2, 0.0, 0.2, PI / 2]:
		game.flight.pitch = pitch
		game.flight.bank = 0.7
		game.flight.yaw = -0.5
		navigation.queue_redraw()
		await process_frame
		await process_frame
	check(render_count >= previous_renders + 5, "extreme attitude render smoke")
	previous_renders = render_count
	navigation.font = null
	navigation.size = Vector2(138, 54)
	navigation.queue_redraw()
	await process_frame
	await process_frame
	check(render_count > previous_renders, "compact fallback font render smoke")
	previous_renders = render_count
	navigation.game = null
	navigation.queue_redraw()
	await process_frame
	await process_frame
	check(render_count > previous_renders, "missing game render safe")
	navigation.queue_free()
	game.queue_free()
	await process_frame
	print("Navigation: %d checks, %s" % [checked, "FAILED" if failed else "PASS"])
	quit(1 if failed else 0)
