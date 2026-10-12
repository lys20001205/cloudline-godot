class_name FlightModel
extends RefCounted
## Force-based, fictional flight model ported from cloudline/flight.js.
## SI units; radians; +X east, +Y up, +Z forward/north. Not a training device.
## Call step() at 120 Hz. Raw axes are pitch, roll, yaw in [-1, 1], plus brake.
## Airport geometry helpers are shared with the scene. No Node dependencies.

const DEG := PI / 180.0
const AIRCRAFT := {
	"light": {"name": "L-4 教练机", "mass": 1050.0, "wing": 16.2, "thrust": 2600.0, "cl0": 0.28, "slope": 4.9, "cd": 0.030, "k": 0.055, "vr": 30.0, "cruise": 48.0, "vne": 83.0, "gear_height": 1.35, "pitch_rate": 0.39, "roll_rate": 0.8, "cruise_power": 0.48, "stall_alpha": 0.27, "span": 10.8},
	"a320": {"name": "A320-216 · CFM56", "mass": 60000.0, "wing": 122.6, "thrust": 210000.0, "cl0": 0.25, "slope": 5.1, "cd": 0.024, "k": 0.047, "vr": 74.5, "cruise": 128.0, "vne": 180.0, "gear_height": 3.9, "pitch_rate": 0.17, "roll_rate": 0.35, "cruise_power": 0.50, "stall_alpha": 0.28, "span": 34.1},
	"jet": {"name": "J-120 双发客机", "mass": 41000.0, "wing": 112.0, "thrust": 145000.0, "cl0": 0.25, "slope": 5.1, "cd": 0.024, "k": 0.047, "vr": 67.0, "cruise": 128.0, "vne": 181.0, "gear_height": 3.9, "pitch_rate": 0.19, "roll_rate": 0.38, "cruise_power": 0.41, "stall_alpha": 0.28, "span": 33.0}
}
const AIRPORTS := {
	"bki": {"elevation": 3.0, "length": 3780.0},
	"can": {"elevation": 15.0, "length": 3600.0},
	"sea": {"elevation": 0.0, "length": 0.0},
	"island": {"elevation": 30.0, "length": 2100.0}
}
const LESSON_GATES := [
	{"x": 0.0, "y": 130.0, "z": 950.0, "r": 85.0, "name": "离地爬升"},
	{"x": 0.0, "y": 285.0, "z": 2600.0, "r": 100.0, "name": "保持爬升"},
	{"x": 700.0, "y": 420.0, "z": 3400.0, "r": 140.0, "name": "缓转右弯"},
	{"x": 1400.0, "y": 420.0, "z": 2400.0, "r": 140.0, "name": "进入下风边"},
	{"x": 1400.0, "y": 420.0, "z": -1100.0, "r": 150.0, "name": "平飞检查"},
	{"x": 1000.0, "y": 315.0, "z": -3100.0, "r": 150.0, "name": "转向跑道"},
	{"x": 0.0, "y": 230.0, "z": -4000.0, "r": 140.0, "name": "对正进近"},
	{"x": 0.0, "y": 120.0, "z": -2500.0, "r": 105.0, "name": "稳定下降"}
]

var type: String = "a320"
var spec: Dictionary = AIRCRAFT.a320.duplicate()
var mode: String = "runway"
var weather: String = "clear"
var assist: bool = true
var airport_key: String = "bki"
var elevation: float = 3.0
var runway_length: float = 3780.0
var obstacles: Array = []
var gates: Array = LESSON_GATES.duplicate(true)
var route = null
var t: float = 0.0
var p: Vector3 = Vector3.ZERO
var v: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var bank: float = 0.0
var pitch_rate: float = 0.0
var roll_rate: float = 0.0
var power: float = 0.0
var spool: float = 0.0
var engine: bool = true
var flaps: int = 1
var flap_actual: float = 1.0 / 3.0
var gear: bool = true
var gear_actual: float = 1.0
var brake: bool = false
var last_brake: bool = false
var speedbrake: bool = false
var trim: float = 0.0
var fuel: float = 85.0
var grounded: bool = true
var was_airborne: bool = false
var crashed: bool = false
var crash_reason: String = ""
var touchdown = null
var landing_complete: bool = false
var gate: int = 0
var ap: Dictionary = {}
var alpha: float = 0.0
var ias: float = 0.0
var tas: float = 0.0
var gs: float = 0.0
var agl: float = 0.0
var load_factor: float = 1.0
var stall: bool = false
var wind: Vector3 = Vector3.ZERO
var warnings: Array[String] = []
var travel: float = 0.0
var events: Array = []
var prev_p: Vector3 = Vector3.ZERO

func _init(aircraft_type: String = "a320", start_mode: String = "runway", weather_type: String = "clear", assisted: bool = true) -> void:
	reset(aircraft_type, start_mode, weather_type, assisted)

func reset(aircraft_type: String = "a320", start_mode: String = "runway", weather_type: String = "clear", assisted: bool = true) -> FlightModel:
	route = null
	type = aircraft_type if AIRCRAFT.has(aircraft_type) else "a320"
	spec = AIRCRAFT[type].duplicate()
	mode = start_mode
	weather = weather_type
	assist = assisted
	t = 0.0
	var start_z: float = -890.0 if airport_key == "island" else -runway_length * 0.5 + 170.0
	p = Vector3(0.0, ground_height(0.0, start_z) + spec.gear_height, start_z)
	v = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	bank = 0.0
	pitch_rate = 0.0
	roll_rate = 0.0
	power = 0.0
	spool = 0.0
	engine = true
	flaps = 1 if mode == "runway" or mode == "lesson" else 0
	flap_actual = flaps / 3.0
	gear = true
	gear_actual = 1.0
	brake = false
	last_brake = false
	speedbrake = false
	trim = 0.0
	fuel = 85.0
	grounded = true
	was_airborne = false
	crashed = false
	crash_reason = ""
	touchdown = null
	landing_complete = false
	gate = 0
	ap = {"on": false, "alt": 0.0, "heading": 0.0, "speed": spec.cruise, "integral": spec.cruise_power}
	alpha = 0.0
	ias = 0.0
	tas = 0.0
	gs = 0.0
	agl = 0.0
	load_factor = 1.0
	stall = false
	wind = Vector3.ZERO
	warnings.clear()
	travel = 0.0
	events.clear()
	if mode == "free" or mode == "landing":
		var landing: bool = mode == "landing"
		var speed: float = (35.0 if type == "light" else 74.0) if landing else float(spec.cruise)
		p = Vector3(0.0, elevation + 202.0 if landing else 550.0, -4500.0 if landing else -300.0)
		v = Vector3(0.0, -speed * 0.047 if landing else 0.0, speed)
		grounded = false
		was_airborne = true
		flaps = 2 if landing else 0
		flap_actual = flaps / 3.0
		gear = type == "light" or landing
		gear_actual = 1.0 if gear else 0.0
		power = (0.39 if type == "light" else 0.25) if landing else float(spec.cruise_power)
		spool = power
		var q: float = 0.5 * 1.225 * exp(-p.y / 10000.0) * speed * speed * spec.wing
		var a: float = (spec.mass * 9.81 / q - spec.cl0 - flap_actual * 0.64) / spec.slope
		pitch = a + atan2(v.y, speed)
	prev_p = p
	refresh()
	return self

func select_airport(key: String) -> void:
	if not AIRPORTS.has(key):
		return
	airport_key = key
	elevation = AIRPORTS[key].elevation
	runway_length = AIRPORTS[key].length
	obstacles.clear()

func emit(event_type: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate()
	event["type"] = event_type
	events.append(event)
	if events.size() > 16:
		events.pop_front()

func refresh() -> void:
	gs = Vector2(v.x, v.z).length()
	tas = (v - wind).length()
	ias = tas * sqrt(exp(-p.y / 10000.0))
	agl = maxf(0.0, p.y - ground_height(p.x, p.z) - spec.gear_height)

func toggle_ap() -> void:
	if grounded or crashed:
		emit("notice", {"text": "离地后才可接通自动驾驶"})
		return
	ap.on = not ap.on
	if ap.on:
		ap.alt = p.y
		ap.heading = yaw
		ap.speed = ias
		ap.integral = power
		emit("notice", {"text": "自动驾驶：保持当前高度、航向和空速"})
	else:
		emit("notice", {"text": "自动驾驶已断开"})

func set_gear() -> void:
	if type == "light":
		emit("notice", {"text": "教练机使用固定起落架，无需收放"})
		return
	if grounded:
		emit("notice", {"text": "地面不能收起落架"})
		return
	gear = not gear
	emit("notice", {"text": "起落架正在放下" if gear else "起落架正在收起"})

func crash(reason: String) -> void:
	if crashed:
		return
	crashed = true
	ap.on = false
	power = 0.0
	crash_reason = reason
	emit("crash", {"reason": reason})

func step(dt: float, raw: Dictionary = {}) -> void:
	if crashed or dt <= 0.0 or not is_finite(dt):
		return
	t += dt
	prev_p = p
	var inp: Dictionary = {"pitch": float(raw.get("pitch", 0.0)), "roll": float(raw.get("roll", 0.0)), "yaw": float(raw.get("yaw", 0.0)), "brake": bool(raw.get("brake", false))}
	var rho: float = 1.225 * exp(-maxf(0.0, p.y) / 10000.0)
	if weather == "clear":
		wind = Vector3.ZERO
	elif weather == "breeze":
		wind = Vector3(3.3, 0.0, -1.6)
	else:
		var a: float = smooth(3.0, 35.0, agl)
		wind = Vector3(4.0 + sin(t * 0.43) * 1.9, (sin(t * 1.73) + 0.36 * sin(t * 3.61)) * 1.35 * a, -1.0 + sin(t * 0.69))
	flap_actual = lerpf(flap_actual, flaps / 3.0, minf(dt * 0.9, 1.0))
	gear_actual = lerpf(gear_actual, 1.0 if gear else 0.0, minf(dt * 0.8, 1.0))
	var air: Vector3 = v - wind
	var speed: float = maxf(0.1, air.length())
	var q: float = 0.5 * rho * speed * speed * spec.wing
	var b: Basis = aircraft_basis()
	var fwd: float = maxf(0.05, air.dot(b.z))
	var up_air: float = air.dot(b.y)
	alpha = atan2(-up_air, fwd)
	var flap: float = flap_actual
	var req_alpha: float = (spec.mass * 9.81 / (maxf(q, 500.0) * maxf(0.45, cos(bank))) - spec.cl0 - flap * 0.64) / spec.slope
	if ap.on:
		if absf(inp.pitch) > 0.22 or absf(inp.roll) > 0.22:
			ap.on = false
			emit("notice", {"text": "检测到手动操纵，自动驾驶已断开"})
		else:
			var max_vs: float = 5.0 if type == "light" else 9.0
			var desired_vs: float = clampf((ap.alt - p.y) * 0.12, -max_vs, max_vs)
			var energy_climb_limit: float = maxf(0.0, (ias - spec.vr * 1.03) * 0.40)
			desired_vs = minf(desired_vs, energy_climb_limit)
			var desired_pitch: float = atan2(desired_vs, speed) + clampf(req_alpha, -0.05, 0.20)
			inp.pitch = clampf((desired_pitch - pitch) * 5.2 - pitch_rate * 1.4, -1.0, 1.0)
			var target_bank: float = clampf(wrap_angle(ap.heading - yaw) * 1.5, -25.0 * DEG, 25.0 * DEG)
			inp.roll = clampf((target_bank - bank) * 3.0 - roll_rate, -1.0, 1.0)
			var error: float = ap.speed - ias
			ap.integral = clampf(ap.integral + error * dt * 0.003, 0.0, 1.0)
			power = clampf(ap.integral + error * 0.035, 0.0, 1.0)
	spool = lerpf(spool, power if engine and fuel > 0.0 else 0.0, minf(dt * (2.4 if type == "light" else 0.6), 1.0))
	fuel = maxf(0.0, fuel - dt * spool * (0.0022 if type == "light" else 0.0045))
	var thrust: float = spec.thrust * spool * ((0.50 + 0.50 / (1.0 + speed / 55.0)) if type == "light" else maxf(0.4, 1.0 - speed / 470.0)) * pow(rho / 1.225, 0.65)
	if grounded:
		_step_ground(dt, inp, speed, q, flap, thrust)
	else:
		_step_air(dt, inp, air, speed, q, flap, thrust, req_alpha, b, fwd)
	last_brake = inp.brake
	for o: Dictionary in obstacles:
		if absf(p.x - o.x) < o.w + 2.0 and absf(p.z - o.z) < o.d + 3.0 and p.y < o.h + 1.0:
			crash("碰到机场建筑或障碍物。")
			break
	refresh()
	travel += gs * dt
	if mode == "lesson" and gate < gates.size():
		var g: Dictionary = gates[gate]
		if p.distance_to(Vector3(g.x, g.y, g.z)) < g.r:
			gate += 1
			emit("gate", {"index": gate})
	warnings.clear()
	if stall and not grounded:
		warnings.append("失速 · 减小迎角")
	if ias > spec.vne:
		warnings.append("超速 · 减小动力")
	if flaps > 0 and ias > spec.vr * 1.7:
		warnings.append("襟翼超速")
	if agl < 65.0 and v.y < -2.5 and not grounded and (absf(p.x) > 90.0 or p.z > 1200.0):
		warnings.append("地形接近")
	if agl < 160.0 and not gear and not grounded and v.y < -1.0:
		warnings.append("检查起落架")
	if route == null and Vector2(p.x, p.z).length() > 12500.0:
		warnings.append("接近地图边界 · 请返航")
	if not p.is_finite() or not v.is_finite():
		crash("仿真状态异常，请重新开始。")

func _step_ground(dt: float, inp: Dictionary, speed: float, q: float, flap: float, thrust: float) -> void:
	var along: float = maxf(0.0, v.x * sin(yaw) + v.z * cos(yaw))
	yaw += (inp.yaw + inp.roll * 0.48) * 0.58 * along / (along + 10.0) * dt
	var effectiveness: float = clampf(speed / spec.vr, 0.0, 1.4)
	pitch += inp.pitch * spec.pitch_rate * 0.65 * effectiveness * dt
	if absf(inp.pitch) < 0.05:
		pitch *= exp(-dt * 0.7)
	pitch = clampf(pitch, -DEG, (14.0 if type == "light" else 12.0) * DEG)
	bank *= exp(-dt * 6.0)
	pitch_rate = 0.0
	roll_rate = 0.0
	alpha = pitch
	var cl: float = spec.cl0 + spec.slope * alpha + flap * 0.64
	var drag: float = q * (spec.cd + spec.k * cl * cl + flap * 0.035 + (0.09 if speedbrake else 0.0))
	var resistance: float = (7.8 if inp.brake or brake else 0.24) + (0.0 if is_paved(p.x, p.z) else 1.2)
	along = maxf(0.0, along + (thrust - drag) / spec.mass * dt - resistance * dt)
	v = Vector3(sin(yaw) * along, 0.0, cos(yaw) * along)
	p += v * dt
	p.y = ground_height(p.x, p.z) + spec.gear_height
	var lift: float = q * cl
	if lift > spec.mass * 9.81 * 1.025 and pitch > 3.5 * DEG and speed > spec.vr * 0.83:
		grounded = false
		was_airborne = true
		v.y = 0.5
		p.y += 0.06
		emit("takeoff")
	if touchdown != null and along < 2.5 and not landing_complete:
		landing_complete = true
		emit("landed", touchdown)
	if terrain_height(p.x, p.z) <= 0.0 and along > 3.0:
		crash("驶入海面。重新开始练习。")

func _step_air(dt: float, inp: Dictionary, air: Vector3, speed: float, q: float, flap: float, thrust: float, req_alpha: float, b: Basis, fwd: float) -> void:
	var effect: float = clampf(speed / (spec.vr * 1.25), 0.25, 1.7)
	var pitch_cmd: float = inp.pitch * spec.pitch_rate * effect
	var roll_cmd: float = inp.roll * spec.roll_rate * effect
	if not ap.on:
		if assist:
			if absf(inp.pitch) < 0.06:
				pitch_cmd += (clampf(req_alpha, -0.08, 0.20) + trim - alpha) * 0.66
			if absf(inp.roll) < 0.06:
				roll_cmd -= bank * 0.35
		elif absf(inp.pitch) < 0.05:
			var reference: float = (spec.mass * 9.81 / (0.5 * 1.225 * spec.cruise * spec.cruise * spec.wing) - spec.cl0) / spec.slope
			pitch_cmd += (reference + trim - alpha) * 0.25
	pitch_rate = lerpf(pitch_rate, pitch_cmd, minf(dt * 4.5, 1.0))
	roll_rate = lerpf(roll_rate, roll_cmd, minf(dt * 4.0, 1.0))
	pitch += pitch_rate * dt
	bank += roll_rate * dt
	if weather == "turbulent":
		bank += sin(t * 3.1) * 0.022 * dt
		pitch += sin(t * 4.4) * 0.008 * dt
	var bank_limit: float = (58.0 if assist else 86.0) * DEG
	var pitch_limit: float = (35.0 if assist else 72.0) * DEG
	bank = clampf(bank, -bank_limit, bank_limit)
	pitch = clampf(pitch, -pitch_limit, pitch_limit)
	var side_angle: float = atan2(air.dot(b.x), fwd)
	yaw += (9.81 * tan(clampf(bank, -1.2, 1.2)) / maxf(speed, 15.0) + inp.yaw * 0.20 + side_angle * 0.23) * dt
	yaw = wrap_angle(yaw)
	b = aircraft_basis()
	fwd = maxf(0.01, air.dot(b.z))
	alpha = atan2(-air.dot(b.y), fwd)
	var cl: float = spec.cl0 + spec.slope * alpha + flap * 0.64
	var stall_loss: float = 1.0 - 0.82 * smooth(spec.stall_alpha, spec.stall_alpha + 0.38, absf(alpha))
	cl = clampf(cl, -2.2, 2.4) * stall_loss
	stall = alpha > spec.stall_alpha or alpha < -0.25
	var extra_drag: float = smooth(spec.stall_alpha, spec.stall_alpha + 0.4, absf(alpha)) * 0.22
	var cd: float = spec.cd + spec.k * cl * cl + flap * 0.044 + (0.0 if type == "light" else gear_actual * 0.023) + (0.095 if speedbrake else 0.0) + extra_drag
	var direction: Vector3 = air.normalized()
	var lift_direction: Vector3 = (b.y - direction * b.y.dot(direction)).normalized()
	var lift: float = q * cl
	var drag: float = q * cd
	load_factor = lift / (spec.mass * 9.81)
	var accel: Vector3 = b.z * (thrust / spec.mass) + lift_direction * (lift / spec.mass) - direction * (drag / spec.mass)
	accel.y -= 9.81
	var side_velocity: float = air.dot(b.x)
	accel += b.x * (-side_velocity * 0.45)
	v += accel * dt
	p += v * dt
	if stall:
		pitch -= smooth(spec.stall_alpha, spec.stall_alpha + 0.25, alpha) * 0.075 * dt
	var ground: float = ground_height(p.x, p.z)
	var contact: float = ground + spec.gear_height
	if p.y <= contact:
		_contact_ground(contact)
	for o: Dictionary in obstacles:
		if absf(p.x - o.x) < o.w + 1.0 and absf(p.z - o.z) < o.d + 1.0 and p.y < o.h + 1.0 and p.y > ground_height(o.x, o.z):
			crash("碰到机场建筑或障碍物。")
			break

func _contact_ground(contact: float) -> void:
	var sink: float = maxf(0.0, -v.y)
	var bank_degrees: float = absf(bank / DEG)
	var heading_error: float = minf(absf(wrap_angle(yaw)), absf(wrap_angle(yaw - PI))) / DEG
	p.y = contact
	if terrain_height(p.x, p.z) <= 0.0:
		crash("接触海面。下次先对正跑道，再开始下降。")
	elif gear_actual < 0.94:
		crash("起落架尚未放妥，无法安全接地。")
	elif sink > (4.8 if type == "light" else 4.0):
		crash("下降率过大。接地前应逐步减小下降率。")
	elif bank_degrees > (14.0 if type == "light" else 9.0):
		crash("机翼倾斜过大。接地前保持机翼接近平。")
	elif pitch < -5.0 * DEG or pitch > 18.0 * DEG:
		crash("接地姿态超出范围。")
	elif not is_runway(p.x, p.z) and gs > 9.0:
		crash("在跑道外接地。对准标线后重新进近。")
	elif heading_error > 25.0 and gs > 10.0:
		crash("接地时未对正跑道方向。")
	else:
		grounded = true
		bank = 0.0
		v.y = 0.0
		ap.on = false
		var score: int = roundi(clampf(100.0 - sink * 11.0 - bank_degrees * 2.0 - absf(p.x) * 0.5 - heading_error, 0.0, 100.0))
		touchdown = {"sink": sink, "score": score, "offset": absf(p.x)}
		emit("touchdown", touchdown)

func aircraft_basis() -> Basis:
	return flight_basis(yaw, pitch, bank)

static func flight_basis(heading: float, attitude: float, roll: float) -> Basis:
	var sy: float = sin(heading)
	var cy: float = cos(heading)
	var sp: float = sin(attitude)
	var cp: float = cos(attitude)
	var sb: float = sin(roll)
	var cb: float = cos(roll)
	var forward: Vector3 = Vector3(sy * cp, sp, cy * cp)
	var right_zero: Vector3 = Vector3(cy, 0.0, -sy)
	var up_zero: Vector3 = Vector3(-sy * sp, cp, -cy * sp)
	return Basis(right_zero * cb - up_zero * sb, right_zero * sb + up_zero * cb, forward)

static func wrap_angle(angle: float) -> float:
	return atan2(sin(angle), cos(angle))

static func smooth(a: float, b: float, x: float) -> float:
	var value: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)

func is_runway(x: float, z: float) -> bool:
	return airport_key != "sea" and absf(x) < (24.0 if airport_key == "island" else 22.5) and absf(z) < runway_length * 0.5

func is_paved(x: float, z: float) -> bool:
	if is_runway(x, z):
		return true
	if airport_key == "sea":
		return false
	if airport_key == "island":
		if (absf(x - 92.0) < 14.0 and absf(z) < 1040.0) or (x > 25.0 and x < 215.0 and z > -700.0 and z < -240.0):
			return true
		for cross_z: float in [-890.0, -480.0, 250.0, 920.0]:
			if absf(z - cross_z) < 14.0 and x >= 15.0 and x < 107.0:
				return true
		return false
	if (absf(x - 115.0) < 35.0 and absf(z) < 1800.0) or (x >= 95.0 and x < 440.0 and z > -770.0 and z < -110.0):
		return true
	for cross_z: float in [900.0, -1400.0, -500.0]:
		if x >= -25.0 and x <= 150.0 and absf(z - cross_z) < 42.0:
			return true
	return false

func ground_height(x: float, z: float) -> float:
	return maxf(0.0, terrain_height(x, z))

func terrain_height(x: float, z: float) -> float:
	if airport_key == "sea":
		return -80.0
	if airport_key == "can":
		return elevation + 160.0 * exp(-(pow((x - 7500.0) / 1700.0, 2.0) + pow((z - 6000.0) / 2500.0, 2.0)))
	if airport_key == "island":
		return _island_height(x, z)
	var shore: float = elevation - 100.0 * (1.0 - smooth(-450.0, -70.0, x))
	var mountain: float = 1050.0 * exp(-(pow((x - 6200.0) / 2300.0, 2.0) + pow((z - 4500.0) / 4200.0, 2.0)))
	return shore + mountain

static func _hash(x: float, z: float) -> float:
	var a: float = sin(x * 127.1 + z * 311.7) * 43758.5453
	return a - floor(a)

static func _noise(x: float, z: float) -> float:
	var a: float = floor(x)
	var b: float = floor(z)
	var u: float = smooth(0.0, 1.0, x - a)
	var value: float = smooth(0.0, 1.0, z - b)
	return lerpf(lerpf(_hash(a, b), _hash(a + 1.0, b), u), lerpf(_hash(a, b + 1.0), _hash(a + 1.0, b + 1.0), u), value)

static func _gauss(x: float, z: float, cx: float, cz: float, sx: float, sz: float, h: float) -> float:
	return exp(-pow((x - cx) / sx, 2.0) - pow((z - cz) / sz, 2.0)) * h

static func _island_height(x: float, z: float) -> float:
	var h: float = 170.0 * exp(-pow((x + 1400.0) / 2600.0, 4.0) - pow((z - 500.0) / 4800.0, 4.0)) - 68.0
	h += _gauss(x, z, -2350.0, 2350.0, 950.0, 1350.0, 1080.0) + _gauss(x, z, -2550.0, -1550.0, 900.0, 1400.0, 720.0) + _gauss(x, z, -1000.0, 4650.0, 1250.0, 700.0, 380.0)
	var land: float = smooth(-50.0, 70.0, h)
	h += (_noise(x * 0.0019, z * 0.0019) * 90.0 + _noise(x * 0.006, z * 0.006) * 25.0 - 48.0) * land
	h = maxf(h, maxf(_gauss(x, z, 4000.0, 4300.0, 1400.0, 2200.0, 330.0) - 75.0, _gauss(x, z, 4800.0, -3600.0, 1250.0, 1200.0, 290.0) - 65.0))
	var approach: float = (1.0 - smooth(120.0, 620.0, absf(x))) * (1.0 - smooth(-1500.0, -1100.0, z)) * smooth(-5200.0, -4500.0, z)
	h = lerpf(h, minf(h, 25.0), approach)
	var airport: float = (1.0 - smooth(340.0, 650.0, absf(x))) * (1.0 - smooth(1180.0, 1570.0, absf(z)))
	return lerpf(h, 30.0, airport)
