extends SceneTree
const Mission = preload("res://scripts/route_mission.gd")
const Flight = preload("res://scripts/flight_model.gd")
func _initialize() -> void:
	for start in ["bki_can", "can_approach", "can_taxi"]:
		var f = Flight.new("a320", start, "clear", true)
		var m = Mission.new(start)
		m.configure(f, m.transfer)
		m.guide = true
		obstacles(f)
		var last_phase: String = ""
		for i in range(600000):
			if m.phase != last_phase:
				print(start, " phase=", m.phase, " t=", m.elapsed, " p=", f.p, " gs=", f.gs)
				last_phase = m.phase
			var input = m.guide_input(f, {}, 1.0/120.0)
			f.step(1.0/120.0, input)
			m.after_step(f, 1.0/120.0)
			if not m.transfer.is_empty():
				m.configure(f, m.transfer)
				obstacles(f)
			if f.crashed or m.finished:
				break
		print(start, " final=", m.phase, " finished=", m.finished, " crashed=", f.crashed, " reason=", f.crash_reason, " t=", m.elapsed, " p=", f.p)
		if not m.finished or f.crashed:
			quit(1)
			return
		f.route = null
	print("PASS: all three guided starts parked at T3")
	quit()

func obstacles(f) -> void:
	f.obstacles=[]
	if f.airport_key in ["bki","can"]:
		f.obstacles.append({"x":500.0 if f.airport_key=="can" else 405.0,"z":-440.0,"w":100.0 if f.airport_key=="can" else 67.5,"d":230.0 if f.airport_key=="can" else 220.0,"h":f.elevation+(24 if f.airport_key=="can" else 16)})
		f.obstacles.append({"x":440.0,"z":230.0,"w":16.5,"d":16.0,"h":f.elevation+48})
		if f.airport_key=="can":
			for z in [-600.0,-280.0]: f.obstacles.append({"x":405.0,"z":z,"w":87.5,"d":22.5,"h":f.elevation+12})
