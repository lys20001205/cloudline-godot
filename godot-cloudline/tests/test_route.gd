extends SceneTree
const Mission = preload("res://scripts/route_mission.gd")
const Flight = preload("res://tests/flight_stub.gd")
var checked: int = 0
func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		push_error("FAILED: " + label)
		quit(1)
func _initialize() -> void:
	var f = Flight.new()
	var m = Mission.new()
	check(not m.guide and m.transfer == "takeoff", "manual takeoff default")
	m.configure(f, m.transfer)
	check(m.scene == "bki" and f.airport_key == "bki" and f.runway_length == 3780.0, "BKI airport configuration")
	check(f.p.is_equal_approx(Vector3(0,6.9,-1720)) and f.grounded and f.flaps == 1, "takeoff state")
	check(m.transfer == "" and f.prev_p == f.p, "transfer acknowledged and previous position reset")
	var raw = {"pitch":0.3,"roll":0.1,"yaw":-0.2,"brake":false}
	check(m.guide_input(f, raw, 1.0/60.0) == raw and not m.guide, "manual input unchanged")
	m.guide = true
	var input = m.guide_input(f, {}, 1.0/60.0)
	check(f.power == 1.0 and input.pitch == 0.0, "guided takeoff throttle")
	f.ias = 80.0
	check(m.guide_input(f, {}, 1.0/60.0).pitch > 0, "guided rotation")
	f.ap.on = true
	check(m.guide_input(f, raw, 1.0/60.0) == raw and not m.guide and not f.ap.on, "manual guide takeover")
	check(f.events.back().text == "已接管：教学领航断开", "manual takeover notice")
	m.guide = true
	f.grounded = false
	f.agl = 100.0
	m.after_step(f, 1.0)
	check(m.phase == "climb" and m.phase_time == 0.0, "takeoff to climb")
	f.agl = 1310.0
	m.after_step(f, 1.0)
	check(m.transfer == "cruise", "guided climb to cruise transfer")
	m.configure(f, "cruise")
	check(m.scene == "sea" and f.elevation == 0.0 and f.runway_length == 0.0, "sea configuration")
	check(f.p.y == 10363.0 and f.ap.on and not f.gear and f.flaps == 0, "cruise start")
	check(absf(f.ias - 135.0) < 0.001 and m.progress == 0.1, "cruise indicated speed and progress")
	m.cruise_distance = m.ROUTE_DISTANCE * 0.82 - 1.0
	f.p.z = 10000.0
	m.after_step(f, 1.0)
	check(m.transfer == "descent" and absf(m.progress - 0.92) < 0.0001, "cruise x128 reaches descent")
	check(f.p.x == 0 and f.p.z == 0 and f.prev_p == f.p, "cruise recenter")
	m.configure(f, "descent")
	check(m.scene == "can" and f.p.z == -21500 and f.p.y == 1100.0 and not f.gear, "CAN descent configuration")
	f.p.z = -8999.0
	m.after_step(f, 1.0)
	check(m.phase == "approach", "descent to approach")
	m.guide_input(f, {}, 1.0/60.0)
	check(f.gear and f.flaps == 2, "approach gear and flaps")
	f.touchdown = {"sink":1.0}
	f.grounded = true
	f.gs = 20.0
	m.after_step(f, 1.0)
	check(m.phase == "rollout", "touchdown to rollout")
	input = m.guide_input(f, {}, 1.0/60.0)
	check(input.brake and f.speedbrake and f.power == 0.0, "rollout deceleration")
	f.gs = 2.0
	m.after_step(f, 1.0)
	check(m.phase == "taxi" and m.progress == 0.99 and not f.speedbrake and f.flaps == 0, "rollout to taxi")
	for i in range(3):
		f.p.x = m.taxi_points[i].x
		f.p.z = m.taxi_points[i].y
		m.guide_input(f, {}, 1.0/60.0)
		check(m.taxi_index == i+1, "taxi waypoint " + str(i))
	f.p = Vector3(244, 18.9, -440)
	input = m.guide_input(f, {}, 1.0/60.0)
	check(input.brake and f.power == 0.0, "taxi parking brake")
	f.gs = 0.5
	m.after_step(f, 1.0)
	check(m.finished and m.phase == "parked" and m.progress == 1.0 and f.brake, "T3 mission complete")
	check(f.events.back().type == "parked" and not m.request_next(f), "parked event and skip disabled")
	var elapsed: float = m.elapsed
	m.after_step(f, 1.0)
	check(m.elapsed == elapsed, "finished mission clock stopped")
	for start in ["can_approach", "can_taxi"]:
		m = Mission.new(start)
		m.configure(f, m.transfer)
		check(m.phase == ("approach" if start == "can_approach" else "taxi") and not m.guide, start)
		check(f.airport_key == "can" and f.gear and f.elevation == 15.0, start + " airport")
	m = Mission.new()
	for phase in ["takeoff", "climb", "cruise", "descent", "approach", "rollout", "taxi", "parked"]:
		m.phase = phase
		m.transfer = ""
		var allowed: bool = m.request_next(f)
		check(allowed == (phase in ["takeoff", "climb", "cruise", "descent", "approach"]), "skip " + phase)
		check(not m.phase_name.is_empty() and not m.hint(f).is_empty(), "label and hint " + phase)
	check(m.skips == 5, "skip count")
	m.phase = "taxi"
	m.guide = false
	f.power = 0.0
	f.gs = 0.0
	f.p = Vector3(245,18.9,-440)
	f.brake = false
	f.last_brake = false
	m.after_step(f, 1.0)
	check(not m.finished, "manual parking requires brake")
	f.last_brake = true
	m.after_step(f, 1.0)
	check(m.finished, "manual parking with input brake")
	f.route = null
	print("PASS: ", checked, " RouteMission checks")
	quit()
