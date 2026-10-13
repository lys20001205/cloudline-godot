class_name CloudlineNavigation
extends Control
## Read-only native navigation/PFD presentation of cloudline/app.js.
## BKI uses real north-up map coordinates with -X to runway-right in Godot.
## Other airport schematics retain their existing authored coordinate convention.
## Set game (with flight and optional route), mode, font, and size from the HUD.

const BKI_BEARING_DEG: float = 22.80738311997575
const MAP_EXTENT: float = 7500.0
const MAP_PIXELS: int = 200
const PFD_SIZE: Vector2 = Vector2(276.0, 108.0)
const AIRPORT_NAMES: Dictionary = {
	"island": "岛屿 01", "bki": "亚庇 BKI", "can": "广州 CAN · T3", "sea": "南海 · 巡航场景"
}
const RUNWAY_NAMES: Dictionary = {"island": "36 / 18", "bki": "02 / 20", "can": "01 / 19", "sea": "无跑道"}
const TAXI_PATH: Array[Vector2] = [Vector2(0, 100), Vector2(0, 900), Vector2(115, 900), Vector2(115, -440), Vector2(245, -440)]
const MINT: Color = Color("bbf3dd")
const MUTED: Color = Color("a6bdb9")
const GOLD: Color = Color("f1d391")

var game = null
var font: Font = null
@export_enum("mini", "map", "route", "pfd") var mode: String = "mini":
	set(value):
		mode = value
		queue_redraw()

static var _terrain_cache: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


static func heading_offset(airport_key: String) -> float:
	return deg_to_rad(BKI_BEARING_DEG if airport_key == "bki" else 10.0 if airport_key == "can" else 0.0)


static func heading_degrees(yaw: float, airport_key: String) -> float:
	return fposmod(rad_to_deg((-yaw if airport_key=="bki" else yaw) + heading_offset(airport_key)), 360.0)


static func airport_bearing_degrees(position_3d: Vector3, airport_key: String) -> float:
	if Vector2(position_3d.x, position_3d.z).length_squared() < 0.000001:
		return heading_degrees(0.0, airport_key)
	return heading_degrees(atan2(-position_3d.x, -position_3d.z), airport_key)


static func airport_distance_nm(position_3d: Vector3) -> float:
	return Vector2(position_3d.x, position_3d.z).length() / 1852.0


static func airport_pointer_angle(position_3d: Vector3, yaw: float, airport_key: String="") -> float:
	if airport_key=="bki":
		return -airport_pointer_angle(position_3d,yaw,"")
	# The same heading offset is applied to bearing and compass, so it cancels.
	if Vector2(position_3d.x, position_3d.z).length_squared() < 0.000001:
		return -yaw
	return atan2(-position_3d.x, -position_3d.z) - yaw


static func map_scale(dimensions: Vector2, big: bool = false) -> float:
	return maxf(0.0, minf(dimensions.x, dimensions.y)) / (15000.0 if big else 8500.0)


static func map_center(position_3d: Vector3, big: bool = false) -> Vector2:
	return Vector2.ZERO if big else Vector2(position_3d.x, position_3d.z) * 0.65


static func world_to_map(point: Vector2, dimensions: Vector2, position_3d: Vector3 = Vector3.ZERO, big: bool = false, airport_key: String="") -> Vector2:
	var offset: Vector2 = world_map_axes(point - map_center(position_3d, big),airport_key) * map_scale(dimensions, big)
	return dimensions * 0.5 + Vector2(offset.x, -offset.y)


static func map_to_world(point: Vector2, dimensions: Vector2, position_3d: Vector3 = Vector3.ZERO, big: bool = false, airport_key: String="") -> Vector2:
	var scale_factor: float = map_scale(dimensions, big)
	if is_zero_approx(scale_factor):
		return map_center(position_3d, big)
	var offset: Vector2 = (point - dimensions * 0.5) / scale_factor
	return map_center(position_3d, big) + map_axes_world(Vector2(offset.x, -offset.y),airport_key)


static func route_curve_point(progress: float, dimensions: Vector2) -> Vector2:
	var t: float = clampf(progress, 0.0, 1.0)
	var origin: Vector2 = dimensions * Vector2(0.70, 0.79)
	var control: Vector2 = dimensions * Vector2(0.56, 0.50)
	var destination: Vector2 = dimensions * Vector2(0.34, 0.20)
	return origin * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + destination * t * t


static func route_marker_point(progress: float, dimensions: Vector2) -> Vector2:
	# Original mission progress is a linear airport-to-airport approximation.
	return (dimensions * Vector2(0.70, 0.79)).lerp(dimensions * Vector2(0.34, 0.20), clampf(progress, 0.0, 1.0))


static func terrain_color(height: float) -> Color:
	if height < 0.0:
		return Color8(26, 66, 77)
	if height < 35.0:
		return Color8(83, 109, 83)
	if height < 350.0:
		return Color8(61 + roundi(height * 0.035), 90 + roundi(height * 0.025), 69)
	return Color8(roundi(99 + minf(28.0, height * 0.015)), roundi(112 + minf(28.0, height * 0.015)), 98)


static func terrain_texture(flight) -> Texture2D:
	if flight == null:
		return null
	var key: String = flight.airport_key
	if not _terrain_cache.has(key):
		var terrain: Image = Image.create(MAP_PIXELS, MAP_PIXELS, false, Image.FORMAT_RGB8)
		for y in range(MAP_PIXELS):
			for x in range(MAP_PIXELS):
				var world: Vector2=map_axes_world(Vector2((float(x)/MAP_PIXELS-.5)*MAP_EXTENT*2.0,(.5-float(y)/MAP_PIXELS)*MAP_EXTENT*2.0),key)
				var height: float = flight.terrain_height(world.x,world.y)
				terrain.set_pixel(x, y, terrain_color(height))
		_terrain_cache[key] = ImageTexture.create_from_image(terrain)
	return _terrain_cache[key]


static func engine_readout(aircraft_type: String, engine_on: bool, spool: float) -> String:
	var amount: float = clampf(spool, 0.0, 1.0)
	if aircraft_type == "light":
		return str(roundi((650.0 if engine_on else 0.0) + amount * 2050.0))
	return "%d%%" % roundi((22.0 if engine_on else 0.0) + amount * 76.0)


static func gate_color(index: int, current: int) -> Color:
	return Color("607c70") if index < current else Color("e9c98f") if index == current else Color("b4dacf")


static func circle_clipped_line(start: Vector2, end: Vector2, radius: float) -> PackedVector2Array:
	# Endpoints relative to the instrument center. Never draw a ladder outside it.
	var direction: Vector2 = end - start
	var a: float = direction.length_squared()
	if a < 0.000001 or radius <= 0.0:
		return PackedVector2Array()
	var b: float = 2.0 * start.dot(direction)
	var c: float = start.length_squared() - radius * radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return PackedVector2Array()
	var root: float = sqrt(discriminant)
	var entry: float = maxf(0.0, (-b - root) / (2.0 * a))
	var leave: float = minf(1.0, (-b + root) / (2.0 * a))
	if entry >= leave:
		return PackedVector2Array()
	return PackedVector2Array([start + direction * entry, start + direction * leave])


func _draw() -> void:
	if game == null or not is_instance_valid(game) or game.flight == null or size.x <= 0.0 or size.y <= 0.0:
		return
	match mode:
		"pfd": _draw_pfd(game.flight)
		"route": _draw_route()
		"map": _draw_map(game.flight, true)
		_: _draw_map(game.flight, false)


func _label(value: String, at: Vector2, font_size: int = 12, color: Color = MUTED, centered: bool = false) -> void:
	var face: Font = font if font != null else ThemeDB.fallback_font
	var origin: Vector2 = at
	if centered:
		origin.x -= face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(face, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _map_point(point: Vector2, flight, big: bool) -> Vector2:
	return world_to_map(point, size, flight.p, big,flight.airport_key)


func _draw_map(flight, big: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("153945"))
	var top_left: Vector2 = _map_point(map_axes_world(Vector2(-MAP_EXTENT,MAP_EXTENT),flight.airport_key), flight, big)
	var extent: float = MAP_EXTENT * 2.0 * map_scale(size, big)
	draw_texture_rect(terrain_texture(flight), Rect2(top_left, Vector2.ONE * extent), false)
	for coordinate in range(-15000, 15001, 2000):
		var grid: Vector2 = _map_point(map_axes_world(Vector2(coordinate,coordinate),flight.airport_key), flight, big)
		draw_line(Vector2(grid.x, 0), Vector2(grid.x, size.y), Color("a4c8b21f"))
		draw_line(Vector2(0, grid.y), Vector2(size.x, grid.y), Color("a4c8b21f"))
	var length: float = flight.runway_length
	if length > 0.0:
		var south: Vector2 = _map_point(Vector2(0, -length * 0.5), flight, big)
		var north: Vector2 = _map_point(Vector2(0, length * 0.5), flight, big)
		draw_line(south, north, Color("f2e6b5"), 5.0 if big else 3.0, true)
		_label(str(RUNWAY_NAMES.get(flight.airport_key, "RWY")).split(" / ")[0], south + Vector2(8, 10), 16 if big else 13, Color("e5ecd7"))
	if flight.airport_key == "can" and flight.route != null:
		for index in range(1, TAXI_PATH.size()):
			draw_line(_map_point(TAXI_PATH[index - 1], flight, big), _map_point(TAXI_PATH[index], flight, big), Color("ffdb80"), 3.0, true)
		_label("SIM-T3", _map_point(TAXI_PATH[-1], flight, big) + Vector2(8, -4), 14 if big else 11, Color("b8ffca"))
	if flight.mode == "lesson":
		for index in range(flight.gates.size()):
			var gate: Dictionary = flight.gates[index]
			var point: Vector2 = _map_point(Vector2(gate.x, gate.z), flight, big)
			if index > 0:
				var previous: Dictionary = flight.gates[index - 1]
				draw_dashed_line(_map_point(Vector2(previous.x, previous.z), flight, big), point, Color("abe1c39a"), 2.0 if big else 1.6, 5.0, true)
			draw_circle(point, 5.0 if big else 3.0, gate_color(index, flight.gate))
			if index == flight.gate:
				draw_arc(point, 9.0 if big else 6.0, 0.0, TAU, 32, GOLD, 1.0, true)
			if big:
				_label(str(index + 1), point + Vector2(8, -6), 14, gate_color(index, flight.gate))
	_draw_aircraft(_map_point(Vector2(flight.p.x, flight.p.z), flight, big), (deg_to_rad(heading_degrees(flight.yaw,"bki")) if flight.airport_key=="bki" else flight.yaw), 13.0 if big else 10.0)
	draw_rect(Rect2(0, 0, 54, 30), Color("102d3bcc"))
	_label("N ↑", Vector2(10, 22), 17 if big else 15, Color("cde4d8"))
	var footer_height: float = 48.0 if big else 23.0
	draw_rect(Rect2(0, size.y - footer_height, size.x, footer_height), Color("102d3be6"))
	if big:
		_label(str(AIRPORT_NAMES.get(flight.airport_key, flight.airport_key)) + " · 机场布局简化", Vector2(12, size.y - 29), 14, Color("b6cdc0"))
	var distance: String = "%.1f NM · BRG %03d°" % [airport_distance_nm(flight.p), roundi(airport_bearing_degrees(flight.p, flight.airport_key)) % 360]
	_label(distance if flight.airport_key != "sea" else "SOUTH CHINA SEA · 巡航", Vector2(10, size.y - 7), 12 if big else 11, MINT)
	draw_rect(Rect2(Vector2.ONE * 0.5, size - Vector2.ONE), Color("74bca675"), false, 1.0)


func _draw_aircraft(center: Vector2, yaw: float, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point in [Vector2(0, -radius), Vector2(radius * 0.6, radius * 0.65), Vector2(0, radius * 0.28), Vector2(-radius * 0.6, radius * 0.65)]:
		points.append(center + point.rotated(yaw))
	draw_colored_polygon(points, MINT)
	points.append(points[0])
	draw_polyline(points, Color("072d32"), 1.5, true)


func _draw_route() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("102d3b"))
	for index in range(1, 8):
		var x: float = index * size.x / 8.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("2d5260"))
	var origin: Vector2 = route_curve_point(0.0, size)
	var destination: Vector2 = route_curve_point(1.0, size)
	for index in range(0, 60, 2):
		draw_line(route_curve_point(index / 60.0, size), route_curve_point((index + 1) / 60.0, size), Color("a6e3cd"), 3.0, true)
	var factor: float = clampf(minf(size.x / 600.0, size.y / 420.0), 0.5, 1.6)
	_label("BKI · 亚庇", origin + Vector2(-40, 35) * factor, roundi(22 * factor), Color("def6e7"))
	_label("CAN · 广州 T3", destination + Vector2(-60, -25) * factor, roundi(22 * factor), Color("def6e7"))
	_label("南海 / SOUTH CHINA SEA", size * Vector2(0.16, 0.53), roundi(17 * factor), Color("def6e7"))
	draw_circle(origin, 7.0 * factor, MINT)
	draw_circle(destination, 7.0 * factor, MINT)
	var mission = game.flight.route
	var progress: float = float(mission.progress) if mission != null else 0.0
	var marker: Vector2 = route_marker_point(progress, size)
	draw_circle(marker, 9.0 * factor, GOLD)
	_label("%d%%" % roundi(clampf(progress, 0.0, 1.0) * 100), marker + Vector2(13, 5) * factor, roundi(13 * factor), GOLD)
	_label("大圆方向示意 · 非真实 ATC 航路或实时航迹", Vector2(20, size.y - 18), roundi(13 * factor), MUTED)


func _draw_pfd(flight) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a2029dc"))
	draw_rect(Rect2(Vector2.ONE * 0.5, size - Vector2.ONE), Color("74bca675"), false, 1.0)
	var factor: float = minf(size.x / PFD_SIZE.x, size.y / PFD_SIZE.y)
	draw_set_transform((size - PFD_SIZE * factor) * 0.5, 0.0, Vector2.ONE * factor)
	_draw_attitude(flight)
	_draw_compass(flight)
	draw_line(Vector2(197, 12), Vector2(197, 94), Color("729493"), 0.5)
	_label("RPM / 转速" if flight.type == "light" else "N1 / 双发", Vector2(209, 20), 8, Color("9dbfba"))
	_label(engine_readout(flight.type, flight.engine, flight.spool), Vector2(208, 41), 17, Color("c7eee0"))
	draw_rect(Rect2(209, 48, 50, 4), Color("365951"))
	draw_rect(Rect2(209, 48, 50 * clampf(flight.spool, 0.0, 1.0), 4), Color("a7dbc3"))
	_label("FUEL / 燃油", Vector2(209, 66), 8, Color("91b6ae"))
	_label("%d%%" % roundi(flight.fuel), Vector2(209, 82), 12, Color("d8e9d7"))
	_label("AP · ALT HDG SPD" if flight.ap.on else "MANUAL / 手动", Vector2(207, 99), 8, Color("a6e3cd") if flight.ap.on else Color("849d9c"))
	draw_set_transform(Vector2.ZERO)


func _draw_attitude(flight) -> void:
	var display_bank: float=attitude_bank(flight.bank,flight.airport_key)
	var center: Vector2 = Vector2(56, 50)
	var radius: float = 38.0
	var pitch_shift: float = rad_to_deg(flight.pitch) * 1.35
	draw_circle(center, radius, Color("377083"))
	# Clip the rotated ground half-plane to a circular 96-vertex instrument.
	var ground: PackedVector2Array = PackedVector2Array()
	var previous: Vector2 = Vector2(radius, 0)
	var previous_distance: float = previous.rotated(display_bank).y - pitch_shift
	for index in range(1, 97):
		var current: Vector2 = Vector2.from_angle(index * TAU / 96.0) * radius
		var distance: float = current.rotated(display_bank).y - pitch_shift
		if (distance >= 0.0) != (previous_distance >= 0.0):
			ground.append(center + previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance >= 0.0:
			ground.append(center + current)
		previous = current
		previous_distance = distance
	if ground.size() >= 3:
		draw_colored_polygon(ground, Color("775c41"))
	for angle in range(-20, 21, 10):
		var half_width: float = 100.0 if angle == 0 else 12.0
		var height: float = -angle * 1.35 + pitch_shift
		var segment: PackedVector2Array = circle_clipped_line(Vector2(-half_width, height).rotated(-display_bank), Vector2(half_width, height).rotated(-display_bank), radius)
		if segment.size() == 2:
			draw_line(center + segment[0], center + segment[1], Color("e3e8d6"), 1.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, Color("729797"), 1.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(-24, 0), center + Vector2(-8, 0), center + Vector2(0, 5), center + Vector2(8, 0), center + Vector2(24, 0)]), GOLD, 2.0, true)
	_label("ATTITUDE / 姿态", Vector2(56, 99), 8, MUTED, true)


func _draw_compass(flight) -> void:
	var center: Vector2 = Vector2(149, 49)
	var rotation_angle: float = -deg_to_rad(heading_degrees(flight.yaw,flight.airport_key))
	draw_arc(center, 34.0, 0.0, TAU, 80, Color("64888b"), 1.0, true)
	for index in range(12):
		var direction: Vector2 = Vector2(sin(index * PI / 6.0), -cos(index * PI / 6.0)).rotated(rotation_angle)
		draw_line(center + direction * 27, center + direction * 31, Color("64888b"), 1.0, true)
	for index in range(4):
		var direction: Vector2 = Vector2(sin(index * PI / 2.0), -cos(index * PI / 2.0)).rotated(rotation_angle)
		_label(["N", "E", "S", "W"][index], center + direction * 23 + Vector2(0, 3), 9, Color("d8e8d9"), true)
	var bearing: float = airport_pointer_angle(flight.p, flight.yaw,flight.airport_key)
	var needle: PackedVector2Array = PackedVector2Array()
	for point in [Vector2(0, 29), Vector2(0, -29), Vector2(-4, -20), Vector2(0, -29), Vector2(4, -20)]:
		needle.append(center + point.rotated(bearing))
	draw_polyline(needle, Color("a6e3cd"), 1.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(-5, 7), center + Vector2(5, 7)]), GOLD)
	_label("%03d°" % (roundi(heading_degrees(flight.yaw, flight.airport_key)) % 360), Vector2(149, 9), 8, GOLD, true)
	_label("NAV / 导航", Vector2(149, 99), 8, MUTED, true)

static func heading_to_yaw(degrees: float,airport_key: String) -> float:
	var relative=deg_to_rad(degrees)-heading_offset(airport_key)
	return -relative if airport_key=="bki" else relative

static func world_map_axes(point: Vector2,airport_key: String) -> Vector2:
	return Vector2(-point.x,point.y).rotated(-heading_offset("bki")) if airport_key=="bki" else point

static func map_axes_world(point: Vector2,airport_key: String) -> Vector2:
	if airport_key!="bki":return point
	var rotated=point.rotated(heading_offset("bki"))
	return Vector2(-rotated.x,rotated.y)

static func manual_axis(value: float,airport_key: String) -> float:
	# Force-model yaw/bank is unchanged; BKI's real-world camera-right is -X.
	return -value if airport_key=="bki" else value

static func attitude_bank(bank: float,airport_key: String) -> float:
	return -bank if airport_key=="bki" else bank
