extends RefCounted
var spec: Dictionary = {"gear_height":3.9,"mass":60000.0,"wing":122.6,"thrust":210000.0,"cl0":0.25,"slope":5.1,"cd":0.024,"k":0.047,"vr":74.5}
var airport_key: String = "bki"
var elevation: float = 3.0
var runway_length: float = 3780.0
var route
var mode: String = "bki_can"
var ap: Dictionary = {"on":false,"alt":0.0,"heading":0.0,"speed":128.0,"integral":0.5}
var crashed: bool = false
var landing_complete: bool = false
var crash_reason: String = ""
var events: Array = []
var bank: float = 0.0
var yaw: float = 0.0
var pitch_rate: float = 0.0
var roll_rate: float = 0.0
var trim: float = 0.0
var speedbrake: bool = false
var brake: bool = false
var touchdown = null
var engine: bool = true
var p: Vector3 = Vector3.ZERO
var v: Vector3 = Vector3.ZERO
var pitch: float = 0.0
var power: float = 0.0
var spool: float = 0.0
var flaps: int = 0
var gear: bool = true
var grounded: bool = true
var was_airborne: bool = false
var flap_actual: float = 0.0
var gear_actual: float = 1.0
var prev_p: Vector3 = Vector3.ZERO
var ias: float = 0.0
var tas: float = 0.0
var gs: float = 0.0
var agl: float = 0.0
var alpha: float = 0.0
var last_brake: bool = false
func refresh() -> void:
	gs = Vector2(v.x, v.z).length()
	tas = v.length()
	ias = tas * sqrt(exp(-p.y/10000.0))
	agl = maxf(0.0, p.y - elevation - spec.gear_height)
func emit(kind: String, data: Dictionary = {}) -> void:
	var event = data.duplicate()
	event["type"] = kind
	events.append(event)
