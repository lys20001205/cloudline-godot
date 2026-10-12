extends SceneTree
## Run: godot --headless --path . --script scripts/test_flight_model.gd
const Flight = preload("res://scripts/flight_model.gd")
const DT: float = 1.0 / 120.0
var results: Array = []

func _initialize() -> void:
	for aircraft_type: String in ["light", "jet", "a320"]:
		_test_takeoff(aircraft_type)
		_test_autopilot(aircraft_type)
		_test_manual_disconnect(aircraft_type)
		_test_stall(aircraft_type)
		_test_terrain_impact(aircraft_type)
		_test_landing(aircraft_type)
	_test_gear()
	_test_engine()
	_test_turbulence()
	_test_obstacles()
	_test_airports()
	_test_fixed_gear_and_ground_ap()
	_test_crash_reasons()
	_test_lesson_gate()
	_test_reset()
	_test_original_js_fidelity()
	var failed: int = 0
	for result: Dictionary in results:
		if not result.pass:
			failed += 1
	print("FLIGHT_MODEL_SUMMARY ", JSON.stringify({"passed": results.size() - failed, "failed": failed, "results": results}))
	quit(1 if failed else 0)

func _record(label: String, passed: bool, details: Dictionary = {}) -> void:
	results.append({"name": label, "pass": passed, "details": details})
	print("PASS " if passed else "FAIL ", label, " ", JSON.stringify(details))

func _flight(aircraft_type: String, start_mode: String = "free", weather_type: String = "clear"):
	var f = Flight.new()
	f.select_airport("island")
	f.reset(aircraft_type, start_mode, weather_type)
	return f

func _advance(f, seconds: float, controls: Dictionary = {}) -> void:
	for _i in range(roundi(seconds * 120.0)):
		f.step(DT, controls)
		if f.crashed:
			break

func _test_takeoff(aircraft_type: String) -> void:
	var f = _flight(aircraft_type, "runway")
	if aircraft_type == "a320":
		f.select_airport("bki")
		f.reset(aircraft_type, "runway")
	f.power = 1.0
	var took_off: bool = false
	var at: Dictionary = {}
	for _i in range(120 * 120):
		var cmd: float = 0.30 if not took_off and f.ias > f.spec.vr and f.pitch < 8.0 * Flight.DEG else 0.0
		f.step(DT, {"pitch": cmd})
		if not f.grounded and not took_off:
			took_off = true
			at = {"seconds": f.t, "knots": f.ias * 1.94384, "runway_z": f.p.z}
			f.toggle_ap()
			f.ap.alt = 350.0
			f.ap.speed = f.spec.cruise
		if took_off and f.agl > 45.0:
			f.flaps = 0
			if aircraft_type != "light":
				f.gear = false
		if f.crashed:
			break
	at["altitude"] = f.p.y
	at["reason"] = f.crash_reason
	_record(aircraft_type + " takeoff and climb", took_off and not f.crashed and f.p.y > 290.0 and f.ias > f.spec.vr, at)

func _test_autopilot(aircraft_type: String) -> void:
	var f = _flight(aircraft_type)
	f.toggle_ap()
	var desired_speed: float = f.ap.speed
	f.ap.heading = 45.0 * Flight.DEG
	_advance(f, 90.0)
	_record(aircraft_type + " autopilot altitude/speed/heading", not f.crashed and absf(f.p.y - 550.0) < 12.0 and absf(Flight.wrap_angle(f.yaw - 45.0 * Flight.DEG)) < 3.0 * Flight.DEG and absf(f.ias - desired_speed) < 3.0, {"altitude_error": f.p.y - 550.0, "heading": f.yaw / Flight.DEG, "speed_error": f.ias - desired_speed})

func _test_manual_disconnect(aircraft_type: String) -> void:
	var f = _flight(aircraft_type)
	f.toggle_ap()
	f.step(DT, {"roll": 0.5})
	_record(aircraft_type + " manual AP disconnect", not f.ap.on)

func _test_stall(aircraft_type: String) -> void:
	var f = _flight(aircraft_type)
	f.assist = false
	f.pitch = 0.50
	f.v = Vector3(0.0, 0.0, f.spec.vr * 0.9)
	f.step(DT)
	_record(aircraft_type + " angle-of-attack stall", f.stall and f.alpha > f.spec.stall_alpha, {"alpha": f.alpha / Flight.DEG})

func _test_terrain_impact(aircraft_type: String) -> void:
	var f = _flight(aircraft_type)
	f.p = Vector3(0.0, 30.0 + f.spec.gear_height + 0.01, 0.0)
	f.v = Vector3(0.0, -14.0, 20.0)
	f.step(DT)
	_record(aircraft_type + " terrain collision", f.crashed and f.p.y >= 30.0 + f.spec.gear_height - 0.01, {"reason": f.crash_reason})

func _test_landing(aircraft_type: String) -> void:
	var f = _flight(aircraft_type, "landing")
	var target_speed: float = 35.0 if aircraft_type == "light" else 74.0
	for _i in range(120 * 250):
		if f.grounded:
			f.power = 0.0
			f.step(DT, {"brake": true})
			if f.landing_complete:
				break
			continue
		var speed: float = f.tas
		var s: Dictionary = f.spec
		var q: float = 0.5 * 1.225 * exp(-f.p.y / 10000.0) * speed * speed * s.wing
		var flap: float = f.flap_actual
		var target_alt: float = 30.0 + s.gear_height + maxf(0.0, -650.0 - f.p.z) * 0.052
		var vs: float = clampf((target_alt - f.p.y) * 0.18 - speed * 0.052, -5.0, 2.0)
		if f.agl < 8.0:
			vs = -0.55 if aircraft_type == "light" else -0.80
		var alpha: float = (s.mass * 9.81 / maxf(1.0, q) - s.cl0 - flap * 0.64) / s.slope
		var pitch_goal: float = atan2(vs, speed) + alpha
		var cl: float = s.cl0 + s.slope * f.alpha + flap * 0.64
		var cd: float = s.cd + s.k * cl * cl + flap * 0.044 + (0.0 if aircraft_type == "light" else f.gear_actual * 0.023)
		var factor: float = ((0.5 + 0.5 / (1.0 + speed / 55.0)) if aircraft_type == "light" else maxf(0.4, 1.0 - speed / 470.0)) * pow(exp(-f.p.y / 10000.0), 0.65)
		f.power = clampf((q * cd + s.mass * 9.81 * vs / maxf(speed, 1.0)) / (s.thrust * factor) + (target_speed - f.ias) * 0.06, 0.0, 1.0)
		if f.agl < 3.0:
			f.power = 0.0
		f.step(DT, {"pitch": clampf((pitch_goal - f.pitch) * 5.2 - f.pitch_rate * 1.4, -1.0, 1.0)})
		if f.crashed:
			break
	_record(aircraft_type + " landing and full stop", not f.crashed and f.touchdown != null and f.landing_complete, {"seconds": f.t, "touchdown": f.touchdown, "reason": f.crash_reason, "runway_z": f.p.z})

func _test_gear() -> void:
	var f = _flight("jet", "runway")
	f.set_gear()
	var inhibited: bool = f.gear
	f = _flight("jet")
	f.set_gear()
	_advance(f, 5.0)
	var deployed: bool = f.gear_actual > 0.97
	f.set_gear()
	_advance(f, 5.0)
	_record("gear ground inhibit and air actuation", inhibited and deployed and f.gear_actual < 0.03)

func _test_engine() -> void:
	var f = _flight("light")
	f.engine = false
	_advance(f, 4.0)
	_record("engine shutdown spools down", f.spool < 0.001)
	f = _flight("jet")
	f.fuel = 0.0
	_advance(f, 15.0)
	_record("fuel exhaustion spools down", f.spool < 0.001 and f.fuel == 0.0)

func _test_turbulence() -> void:
	var a = _flight("light", "free", "turbulent")
	var b = _flight("light", "free", "turbulent")
	a.toggle_ap()
	b.toggle_ap()
	_advance(a, 30.0)
	for _frame in range(900):
		for _step in range(4):
			b.step(DT)
	_record("repeatable finite turbulent flight", a.p == b.p and a.p.is_finite() and not a.crashed)
	var f = _flight("a320", "free", "breeze")
	f.step(DT)
	_record("steady breeze vector", f.wind.is_equal_approx(Vector3(3.3, 0.0, -1.6)))

func _test_obstacles() -> void:
	var f = _flight("light")
	f.obstacles.append({"x": 0.0, "z": f.p.z + 1.0, "w": 15.0, "d": 15.0, "h": 600.0})
	f.step(DT)
	_record("building collision", f.crashed and f.crash_reason.contains("障碍物"))

func _test_airports() -> void:
	var f = _flight("a320")
	f.select_airport("bki")
	var bki: bool = f.is_runway(0.0, 1800.0) and not f.is_runway(30.0, 0.0) and f.is_paved(115.0, 300.0) and f.is_paved(245.0, -440.0) and f.terrain_height(-1000.0, 0.0) < 0.0
	f.select_airport("can")
	var can: bool = f.elevation == 15.0 and f.is_runway(0.0, 1700.0) and not f.is_runway(0.0, 1900.0)
	f.select_airport("sea")
	_record("BKI CAN and sea geometry", bki and can and f.ground_height(0.0, 0.0) == 0.0 and not f.is_paved(0.0, 0.0))

func _test_fixed_gear_and_ground_ap() -> void:
	var f = _flight("light", "runway")
	f.toggle_ap()
	f.set_gear()
	_record("fixed landing gear and grounded AP inhibit", f.gear and not f.ap.on and f.events.size() == 2)

func _test_crash_reasons() -> void:
	for scenario: String in ["gear", "bank", "attitude", "off_runway", "heading", "sea"]:
		var f = _flight("a320")
		f.gear = true
		f.gear_actual = 1.0
		f.v = Vector3(0.0, -1.0, 50.0)
		f.p = Vector3(0.0, 33.901, 0.0)
		f.pitch = 0.05
		if scenario == "gear":
			f.gear_actual = 0.5
		elif scenario == "bank":
			f.bank = 0.2
		elif scenario == "attitude":
			f.pitch = -0.15
		elif scenario == "off_runway":
			f.p.x = 80.0
		elif scenario == "heading":
			f.yaw = 0.6
		elif scenario == "sea":
			f.select_airport("sea")
			f.p.y = 3.901
		f.refresh()
		f.step(DT)
		_record(scenario + " unsafe touchdown crash", f.crashed, {"reason": f.crash_reason})

func _test_lesson_gate() -> void:
	var f = _flight("light", "lesson")
	f.grounded = false
	f.p = Vector3(0.0, 130.0, 950.0)
	f.v = Vector3(0.0, 0.0, 48.0)
	f.step(DT)
	_record("lesson gates advance", f.gate == 1 and f.events.back().type == "gate")

func _test_reset() -> void:
	var f = _flight("jet")
	f.crash("test")
	f.reset()
	_record("reset clears crash and restores default A320", not f.crashed and f.crash_reason == "" and f.type == "a320" and f.touchdown == null and f.events.is_empty() and f.grounded and f.fuel == 85.0)
	var b: Basis = Flight.flight_basis(0.0, 0.0, 0.0)
	_record("native basis preserves positive Z forward", b.is_equal_approx(Basis.IDENTITY))

## Source snapshots from original JavaScript at 120 Hz for 30 seconds with
## heading-hold 0.35 rad. Tolerance allows Godot Vector3 single precision.
const JS_REFERENCE = [{"type":"light","weather":"clear","p":[437.01310362504245,550.1507365482623,1066.961066924933],"v":[16.4854410801981,-0.0021401455629104717,45.162817935073555],"yaw":0.34999541242999826,"pitch":0.039314213028979,"bank":0.000009045451614721103,"ias":46.77306938444165,"power":0.47687475657169925,"crashed":false},{"type":"light","weather":"breeze","p":[527.7040580556943,550.137220833194,1028.0230400490661],"v":[19.63990684595737,-0.0016319563082452602,43.16427488660654],"yaw":0.34999449356540124,"pitch":0.0410464735934911,"bank":0.000010906386724903688,"ias":46.360328805472285,"power":0.46818063441348096,"crashed":false},{"type":"light","weather":"turbulent","p":[551.0996524969796,549.5973998170381,1050.863548562569],"v":[19.76757207985457,0.9023049238258724,44.0919760143324],"yaw":0.3475916776479623,"pitch":0.04426347476217763,"bank":-0.005180593574678295,"ias":45.40170593245767,"power":0.4875762507590423,"crashed":false},{"type":"jet","weather":"clear","p":[939.7034408538009,550.2223747652758,3435.9054880047984],"v":[43.02428520263089,-0.0257347683193621,121.30208623535835],"yaw":0.34127180756312314,"pitch":0.024006424797523136,"bank":0.014750101718533224,"ias":125.21361118996424,"power":0.2931297657822943,"crashed":false},{"type":"jet","weather":"breeze","p":[1021.0501979432854,550.2078626196957,3394.782131097021],"v":[46.11268069859073,-0.022136547407380587,119.22668153429012],"yaw":0.34098198821342457,"pitch":0.024625214098040075,"bank":0.015253500552178754,"ias":124.70899350764606,"power":0.2981482288071231,"crashed":false},{"type":"jet","weather":"turbulent","p":[1042.1130956766658,549.743294643757,3415.150951799925],"v":[46.366484823162,0.28610582054853534,119.95510604538758],"yaw":0.3415365849504926,"pitch":0.02380733157972049,"bank":0.008035481066721627,"ias":123.61228227726812,"power":0.33197222920566627,"crashed":false},{"type":"a320","weather":"clear","p":[934.7057853945352,550.2975981990975,3485.557690372704],"v":[43.233749818801876,-0.06329358418365137,122.26882221167945],"yaw":0.3407750509006059,"pitch":0.046900693618047114,"bank":0.01581533761869975,"ias":126.16772684046904,"power":0.2105821168996101,"crashed":false},{"type":"a320","weather":"breeze","p":[1015.3929422098998,550.2498255514633,3444.6843155840047],"v":[46.306154706118356,-0.054957090221898236,120.16123604699484],"yaw":0.34047194535959524,"pitch":0.04778786038142409,"bank":0.01635277122878448,"ias":125.62865438866343,"power":0.216183842063556,"crashed":false},{"type":"a320","weather":"turbulent","p":[1036.4767774911058,549.8582637374739,3464.8866442006524],"v":[46.57057177339658,0.06000532854520659,120.90060011680539],"yaw":0.3410388017374802,"pitch":0.046943873601721836,"bank":0.009271449629134124,"ias":124.54842691442452,"power":0.2498065055865778,"crashed":false}]

func _test_original_js_fidelity() -> void:
	for fixture: Dictionary in JS_REFERENCE:
		var f = _flight(fixture.type, "free", fixture.weather)
		f.toggle_ap()
		f.ap.heading = 0.35
		_advance(f, 30.0)
		var position_error: float = f.p.distance_to(Vector3(fixture.p[0], fixture.p[1], fixture.p[2]))
		var velocity_error: float = f.v.distance_to(Vector3(fixture.v[0], fixture.v[1], fixture.v[2]))
		_record(fixture.type + " " + fixture.weather + " original JavaScript fidelity", not f.crashed and position_error < 0.1 and velocity_error < 0.005 and absf(f.yaw - fixture.yaw) < 0.001, {"position_error_m": position_error, "velocity_error_mps": velocity_error})
