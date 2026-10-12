class_name RouteMission
extends RefCounted
## BKI → CAN T3 game mission, ported from cloudline/routes.js.
## All airport positions and procedures are game approximations, not navigation data.
## Simulation coordinates use positive Z forward; the view owns scene construction.

const ROUTE_ID: String = "bki-can"
const ROUTE_NAME: String = "BKI → CAN T3"
const ROUTE_DISTANCE: float = 1963170.863432416
const PHASE_NAMES: Dictionary = {
	"takeoff": "亚庇滑跑",
	"climb": "离场爬升",
	"cruise": "南海巡航",
	"descent": "广州下降",
	"approach": "稳定进近",
	"rollout": "着陆减速",
	"taxi": "滑行至 T3",
	"parked": "T3 停机完成",
}
const TAXI_POINTS: Array[Vector2] = [
	Vector2(0.0, 900.0), Vector2(115.0, 900.0),
	Vector2(115.0, -440.0), Vector2(245.0, -440.0),
]

var phase: String = "takeoff"
var scene: String = "bki"
var guide: bool = false
var progress: float = 0.0
var elapsed: float = 0.0
var phase_time: float = 0.0
var cruise_rate: int = 128
var cruise_distance: float = 0.0
var skips: int = 0
var taxi_index: int = 0
var finished: bool = false
var log: Array[Dictionary] = []
var start_mode: String = "bki_can"
# An empty string means no scene/state transfer is pending.
var transfer: String = "takeoff"

var phase_name: String:
	get:
		return PHASE_NAMES.get(phase, "")

var taxi_points: Array[Vector2]:
	get:
		return TAXI_POINTS


func _init(start: String = "bki_can") -> void:
	start_mode = start
	transfer = "approach" if start == "can_approach" else "taxi" if start == "can_taxi" else "takeoff"


func configure(f, next_phase: String) -> void:
	var s: Dictionary = f.spec
	phase = next_phase
	phase_time = 0.0
	transfer = ""
	scene = "sea" if phase == "cruise" else "can" if phase in ["descent", "approach", "rollout", "taxi", "parked"] else "bki"
	f.airport_key = scene
	f.elevation = 0.0 if scene == "sea" else 15.0 if scene == "can" else 3.0
	f.runway_length = 0.0 if scene == "sea" else 3600.0 if scene == "can" else 3780.0
	f.route = self
	f.mode = start_mode
	f.ap.on = false
	f.crashed = false
	f.landing_complete = false
	f.crash_reason = ""
	f.events.clear()
	f.bank = 0.0
	f.yaw = 0.0
	f.pitch_rate = 0.0
	f.roll_rate = 0.0
	f.trim = 0.0
	f.speedbrake = false
	f.brake = false
	f.touchdown = null
	f.engine = true
	var g: float = f.elevation + s.gear_height
	if phase == "takeoff":
		f.p = Vector3(0.0, g, -1720.0)
		f.v = Vector3.ZERO
		f.pitch = 0.0
		f.power = 0.0
		f.spool = 0.0
		f.flaps = 1
		f.gear = true
		f.grounded = true
		f.was_airborne = false
		progress = 0.0
	elif phase == "taxi":
		f.p = Vector3(0.0, g, 100.0)
		f.v = Vector3.ZERO
		f.pitch = 0.0
		f.power = 0.0
		f.spool = 0.0
		f.flaps = 0
		f.gear = true
		f.grounded = true
		f.was_airborne = true
		f.touchdown = {"sink": 0.0, "score": 0, "offset": 0.0, "practice": true}
		progress = 0.99
		taxi_index = 0
	else:
		var cruise: bool = phase == "cruise"
		var descent: bool = phase == "descent"
		var z: float = 0.0 if cruise else -21500.0 if descent else -7500.0
		var altitude: float = 10363.0 if cruise else 1100.0 if descent else g + (-1200.0 - z) * 0.052
		var ias: float = 135.0 if cruise else 95.0 if descent else 78.0
		var tas: float = ias / sqrt(exp(-altitude / 10000.0))
		f.p = Vector3(0.0, altitude, z)
		f.v = Vector3(0.0, 0.0 if cruise else -tas * 0.052, tas)
		f.power = 0.65 if cruise else 0.31 if descent else 0.40
		f.spool = f.power
		f.flaps = 0 if cruise else 1 if descent else 2
		f.gear = not cruise and not descent
		f.grounded = false
		f.was_airborne = true
		var q: float = 0.5 * 1.225 * ias * ias * s.wing
		f.pitch = atan2(f.v.y, tas) + (s.mass * 9.81 / q - s.cl0 - f.flaps / 3.0 * 0.64) / s.slope
		progress = 0.10 if cruise else 0.92 if descent else 0.97
		if cruise:
			cruise_distance = 0.0
			f.ap.on = true
			f.ap.alt = altitude
			f.ap.heading = 0.0
			f.ap.speed = ias
			f.ap.integral = f.power
	f.flap_actual = f.flaps / 3.0
	f.gear_actual = 1.0 if f.gear else 0.0
	f.refresh()
	f.prev_p = f.p
	log.append({"phase": phase, "t": roundi(elapsed)})


func request_next(f) -> bool:
	if f.crashed or finished:
		return false
	if phase == "takeoff" or phase == "climb":
		transfer = "cruise"
	elif phase == "cruise":
		transfer = "descent"
	elif phase == "descent" or phase == "approach":
		transfer = "approach"
	else:
		return false
	skips += 1
	return true


func cancel_guide(f) -> void:
	if guide:
		guide = false
		f.ap.on = false
		f.emit("notice", {"text": "已接管：教学领航断开"})


func guide_input(f, raw: Dictionary, _dt: float) -> Dictionary:
	var inp: Dictionary = raw.duplicate()
	if not guide:
		return inp
	if absf(raw.get("pitch", 0.0)) > 0.15 or absf(raw.get("roll", 0.0)) > 0.15 or absf(raw.get("yaw", 0.0)) > 0.15 or raw.get("brake", false):
		cancel_guide(f)
		return inp
	var s: Dictionary = f.spec
	f.ap.on = false
	inp = {"pitch": 0.0, "roll": 0.0, "yaw": 0.0, "brake": false}
	if phase == "takeoff":
		f.power = 1.0
		f.flaps = 1
		f.gear = true
		inp.yaw = clampf(-f.yaw * 3.0 - f.p.x * 0.02, -1.0, 1.0)
		if f.ias > s.vr:
			inp.pitch = clampf((0.145 - f.pitch) * 2.0, -0.4, 0.40)
		return inp
	if phase == "rollout":
		f.power = 0.0
		f.speedbrake = true
		inp.brake = true
		inp.yaw = clampf(-f.yaw * 3.0 - f.p.x * 0.02, -1.0, 1.0)
		return inp
	if phase == "taxi":
		f.flaps = 0
		f.speedbrake = false
		var target: Vector2 = TAXI_POINTS[taxi_index]
		var dx: float = target.x - f.p.x
		var dz: float = target.y - f.p.z
		var distance: float = Vector2(dx, dz).length()
		var err: float = _wrap_angle(atan2(dx, dz) - f.yaw)
		var last: bool = taxi_index == TAXI_POINTS.size() - 1
		if not last and distance < 22.0:
			taxi_index += 1
			return inp
		var desired: float = clampf(distance * 0.13, 0.0, 4.0) if last else 3.5 if absf(err) > 0.3 else 6.0
		if last and distance < 9.0:
			f.power = 0.0
			inp.brake = true
			return inp
		f.power = clampf(0.078 + (desired - f.gs) * 0.075, 0.0, 0.30)
		inp.brake = f.gs > desired + 0.65
		inp.yaw = clampf(err * 2.4, -1.0, 1.0)
		return inp
	if phase == "parked":
		f.power = 0.0
		inp.brake = true
		return inp
	var target_ias: float = 122.0
	var vs: float = 7.0
	var desired_yaw: float = 0.0
	if phase == "climb":
		target_ias = 115.0
		vs = clampf((1450.0 - f.p.y) * 0.08, 0.0, 9.0)
		vs = minf(vs, maxf(1.0, (f.ias - s.vr) * 0.45))
		if f.agl > 120.0:
			f.flaps = 0
			f.gear = false
	if phase == "cruise":
		target_ias = 135.0
		vs = clampf((10363.0 - f.p.y) * 0.10, -5.0, 5.0)
		f.flaps = 0
		f.gear = false
	if phase == "descent" or phase == "approach":
		var target_altitude: float = f.elevation + s.gear_height + maxf(0.0, -1200.0 - f.p.z) * 0.052
		target_ias = 95.0 if phase == "descent" else 78.0
		f.flaps = 1 if phase == "descent" else 2
		f.gear = phase == "approach"
		vs = clampf((target_altitude - f.p.y) * 0.18 - f.tas * 0.052, -8.0, 2.0)
		if f.agl < 9.0:
			vs = -0.8
		desired_yaw = clampf(-f.p.x * 0.00035, -0.12, 0.12)
	var speed: float = maxf(20.0, f.tas)
	var q: float = 0.5 * 1.225 * exp(-f.p.y / 10000.0) * speed * speed * s.wing
	var alpha: float = (s.mass * 9.81 / maxf(1.0, q) - s.cl0 - f.flap_actual * 0.64) / s.slope
	var pitch_goal: float = atan2(vs, speed) + alpha
	inp.pitch = clampf((pitch_goal - f.pitch) * 5.2 - f.pitch_rate * 1.4, -1.0, 1.0)
	var target_bank: float = clampf(_wrap_angle(desired_yaw - f.yaw) * 1.5, -0.28, 0.28)
	inp.roll = clampf((target_bank - f.bank) * 3.0 - f.roll_rate, -1.0, 1.0)
	var cl: float = s.cl0 + s.slope * f.alpha + f.flap_actual * 0.64
	var cd: float = s.cd + s.k * cl * cl + f.flap_actual * 0.044 + f.gear_actual * 0.023 + (0.095 if f.speedbrake else 0.0)
	var factor: float = maxf(0.4, 1.0 - speed / 470.0) * pow(exp(-f.p.y / 10000.0), 0.65)
	f.power = clampf((q * cd + s.mass * 9.81 * vs / speed) / (s.thrust * factor) + (target_ias - f.ias) * 0.045, 0.0, 1.0)
	if phase == "approach" and f.agl < 3.0:
		f.power = 0.0
	return inp


func after_step(f, dt: float) -> void:
	if f.crashed or finished:
		return
	elapsed += dt
	phase_time += dt
	if phase == "takeoff" and not f.grounded:
		phase = "climb"
		phase_time = 0.0
		f.emit("notice", {"text": "亚庇离地。稳定爬升后收起落架与襟翼。"})
	if phase == "climb":
		progress = clampf(f.agl / 1450.0 * 0.10, 0.0, 0.10)
		if guide and f.agl > 1300.0:
			transfer = "cruise"
	if phase == "cruise":
		cruise_distance += f.gs * dt * cruise_rate
		progress = 0.10 + 0.82 * clampf(cruise_distance / (ROUTE_DISTANCE * 0.82), 0.0, 1.0)
		if cruise_distance >= ROUTE_DISTANCE * 0.82:
			transfer = "descent"
		if Vector2(f.p.x, f.p.z).length() > 9500.0:
			f.p.x = 0.0
			f.p.z = 0.0
			f.prev_p = f.p
	if phase == "descent":
		progress = clampf(0.92 + (f.p.z + 21500.0) / 12500.0 * 0.05, 0.92, 0.97)
		if f.p.z > -9000.0:
			phase = "approach"
			phase_time = 0.0
			f.emit("notice", {"text": "进入广州进近段。检查襟翼、起落架与空速。"})
	if phase == "approach":
		progress = clampf(0.97 + (f.p.z + 9000.0) / 8500.0 * 0.018, 0.97, 0.988)
		if f.touchdown != null:
			phase = "rollout"
			phase_time = 0.0
	if phase == "rollout" and f.grounded and f.gs < 2.5:
		phase = "taxi"
		phase_time = 0.0
		progress = 0.99
		taxi_index = 0
		f.speedbrake = false
		f.flaps = 0
		f.emit("notice", {"text": "着陆完成。沿黄色滑行线和绿色标记进入 T3 模拟机位。"})
	if phase == "taxi" and f.grounded:
		var distance: float = Vector2(f.p.x - 245.0, f.p.z + 440.0).length()
		if distance < 12.0 and f.gs < 1.0 and f.power < 0.06 and (f.brake or guide or f.last_brake):
			phase = "parked"
			progress = 1.0
			finished = true
			f.power = 0.0
			f.brake = true
			f.emit("parked", {"text": "BKI → CAN T3 完成"})


func hint(_f = null) -> String:
	var hints: Dictionary = {
		"takeoff": "油门推满；约 145 kt 轻拉抬头。可点「教学领航」观看完整示范。",
		"climb": "保持速度、收起落架和襟翼；「跳至巡航」可直接体验南海上空。",
		"cruise": "FL340 场景 · 航程推进 ×" + str(cruise_rate) + "，飞行动力学 1×。可跳至广州下降。",
		"descent": "沿引导线下降。逐步减速，准备襟翼与起落架。",
		"approach": "参考 152 kt，襟翼 2 / 3，起落架放妥。小幅修正，近地轻拉减小下降率。",
		"rollout": "收油门，按住刹车。先减速，再退出跑道。",
		"taxi": "沿黄线经跑道北侧出口至 SIM-T3。保持低速，机位内收油并刹停。",
		"parked": "飞机已在 T3 模拟机位停稳。",
	}
	return hints.get(phase, "")


static func _wrap_angle(angle: float) -> float:
	return atan2(sin(angle), cos(angle))
