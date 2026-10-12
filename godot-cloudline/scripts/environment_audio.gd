class_name CloudlineEnvironmentAudio
extends Node
## Source parity for cloudline/app.js styles, initAudio() and soundUpdate().
## No audio resources or playback are created until set_audio_enabled(true).
## Call that method from a user gesture so browsers can unlock their audio context.

const STYLES := {
	"day": {"sky": Color(.24, .53, .71), "horizon": Color(.72, .83, .83), "sun": Vector3(-.45, .76, .3), "night": 0.0, "fog": .000072},
	"golden": {"sky": Color(.32, .48, .57), "horizon": Color(.89, .71, .51), "sun": Vector3(-.6, .22, -.5), "night": 0.0, "fog": .00009},
	"night": {"sky": Color(.025, .055, .10), "horizon": Color(.13, .21, .28), "sun": Vector3(.2, .46, .3), "night": .88, "fog": .000052}
}
const SAMPLE_RATE := 11025.0
const BUFFER_SECONDS := .12
const MIX_GAIN := .18
const GAIN_SMOOTH := 1.0 - exp(-1.0 / (SAMPLE_RATE * .12))
const OSC_SMOOTH := 1.0 - exp(-1.0 / (SAMPLE_RATE * .15))
const SUB_SMOOTH := 1.0 - exp(-1.0 / (SAMPLE_RATE * .20))
const LOWPASS_SMOOTH := SUB_SMOOTH
const SKY_SHADER := """
shader_type sky;
render_mode disable_fog;
uniform vec3 sky_color;
uniform vec3 horizon_color;
uniform vec3 sun_direction;
uniform float night_factor;
void sky() {
	float height = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 color = mix(horizon_color, sky_color, pow(height, .47));
	float sun = max(dot(EYEDIR, sun_direction), 0.0);
	color += vec3(1.0, .83, .54) * pow(sun, 500.0) * (1.0 - night_factor) * .75;
	color += vec3(.9, .65, .33) * pow(sun, 14.0) * (1.0 - night_factor) * .11;
	COLOR = color;
}
"""

var lighting := "day"
var weather := "clear"
var audio_enabled := false
var audio_available := true
var audio_error := ""
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback

# Public targets make source parity testable without an audio device.
var target_gain := 0.0
var target_osc_hz := 70.0
var target_sub_hz := 36.0
var target_lowpass_hz := 400.0
var _flight_running := false
var _flight_crashed := false
var _aircraft_type := "a320"
var _spool := 0.0
var _current_gain := 0.0
var _current_osc_hz := 70.0
var _current_sub_hz := 36.0
var _current_lowpass_hz := 400.0
var _osc_phase := 0.0
var _sub_phase := 0.0
var _filter_z1 := 0.0
var _filter_z2 := 0.0
var _filter_b0 := 0.0
var _filter_b1 := 0.0
var _filter_b2 := 0.0
var _filter_a1 := 0.0
var _filter_a2 := 0.0
var _filter_countdown := 0


func _init() -> void:
	set_process(false)
	audio_available = AudioServer.get_driver_name() != "Dummy"
	if not audio_available:
		audio_error = "No audio output device is available; flight remains playable silently."


func setup(environment_node: WorldEnvironment, sun_node: DirectionalLight3D) -> void:
	world_environment = environment_node
	sun = sun_node
	if is_instance_valid(world_environment):
		if world_environment.environment == null:
			world_environment.environment = Environment.new()
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.sky = Sky.new()
		env.sky.radiance_size = Sky.RADIANCE_SIZE_64
		sky_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SKY_SHADER
		sky_material.shader = shader
		env.sky.sky_material = sky_material
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.ambient_light_sky_contribution = 0.0
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.0
		env.fog_aerial_perspective = 0.0
	if is_instance_valid(sun):
		sun.shadow_enabled = false
		sun.light_color = Color.WHITE
	set_lighting(lighting)


func set_lighting(key: String) -> bool:
	if not STYLES.has(key):
		return false
	lighting = key
	var style: Dictionary = get_lighting_style()
	if is_instance_valid(sky_material):
		# Vector3 uniforms intentionally avoid source_color conversion: the source
		# WebGL sky shader writes these exact display-space values.
		var sky_color: Color = style.sky
		var horizon_color: Color = style.horizon
		sky_material.set_shader_parameter("sky_color", Vector3(sky_color.r, sky_color.g, sky_color.b))
		sky_material.set_shader_parameter("horizon_color", Vector3(horizon_color.r, horizon_color.g, horizon_color.b))
		sky_material.set_shader_parameter("sun_direction", style.sun)
		sky_material.set_shader_parameter("night_factor", style.night)
	var dimming: float = 1.0 - float(style.night) * .7
	if is_instance_valid(world_environment) and world_environment.environment != null:
		var env := world_environment.environment
		env.ambient_light_energy = .44 * dimming
		env.fog_density = style.fog
		env.fog_light_color = style.horizon
		env.fog_light_energy = 1.0
	if is_instance_valid(sun):
		# Light travels along local -Z; +Z therefore points toward the source sun.
		sun.basis = Basis.looking_at(-style.sun, Vector3.UP)
		sun.light_energy = .60 * dimming
	return true


func set_weather(key: String) -> void:
	if key == weather:
		return
	weather = key
	set_lighting(lighting)


func get_lighting_style() -> Dictionary:
	var style: Dictionary = STYLES[lighting].duplicate()
	style.sun = (style.sun as Vector3).normalized()
	style.fog = float(style.fog) * (1.55 if weather == "turbulent" else 1.0)
	return style


func set_audio_enabled(enabled: bool) -> bool:
	## A false return means the requested sound cannot currently reach a device.
	## The requested preference stays set, and synthesis remains testable headlessly.
	audio_enabled = enabled
	_refresh_targets()
	if enabled:
		audio_available = AudioServer.get_driver_name() != "Dummy"
		if audio_available:
			audio_error = ""
			_ensure_player()
	_sync_playback()
	return not enabled or audio_available


func update_sound(flight, running: bool) -> void:
	## Engine-off sound follows the flight model's decaying spool, as in JS.
	## Call while paused as well: no paused/menu/crashed samples may remain queued.
	var valid_flight: bool = flight != null and (flight is Dictionary or is_instance_valid(flight))
	_flight_running = running and valid_flight
	_flight_crashed = bool(flight.crashed) if valid_flight else false
	if valid_flight:
		_aircraft_type = str(flight.type)
		_spool = clampf(float(flight.spool), 0.0, 1.0)
		if not is_finite(_spool):
			_spool = 0.0
		var flight_weather = flight.get("weather")
		if flight_weather != null:
			set_weather(str(flight_weather))
	_refresh_targets()
	_sync_playback()


func get_sound_targets() -> Dictionary:
	return {"on": _sound_is_on(), "gain": target_gain, "osc_hz": target_osc_hz,
		"sub_hz": target_sub_hz, "lowpass_hz": target_lowpass_hz, "mix_gain": MIX_GAIN}


func _sound_is_on() -> bool:
	return audio_enabled and _flight_running and not _flight_crashed


func _refresh_targets() -> void:
	target_gain = .028 + _spool * .045 if _sound_is_on() else 0.0
	if _sound_is_on():
		var jet := _aircraft_type != "light"
		target_osc_hz = (52.0 if jet else 38.0) + _spool * (90.0 if jet else 57.0)
		target_sub_hz = 26.0 + _spool * 24.0
		target_lowpass_hz = 250.0 + _spool * 350.0


func _ensure_player() -> void:
	if is_instance_valid(player) or not audio_enabled or not audio_available:
		return
	generator = AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = BUFFER_SECONDS
	player = AudioStreamPlayer.new()
	player.name = "CloudlineEngineAudio"
	player.autoplay = false
	# The Web sample backend cannot play a generated stream. Explicitly choose
	# mixer streaming; no threads, extra audio buses, files or extensions needed.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.stream = generator
	add_child(player)


func _sync_playback() -> void:
	if not _sound_is_on() or not audio_available or not is_inside_tree():
		_stop_playback()
		return
	_ensure_player()
	if not is_instance_valid(player):
		return
	if not player.playing:
		player.play()
		if player.has_stream_playback():
			playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback == null:
			audio_available = false
			audio_error = "Audio playback could not start; flight remains playable silently."
			_stop_playback()
			return
		_fill_audio_buffer()
	set_process(true)


func _stop_playback() -> void:
	set_process(false)
	if is_instance_valid(player) and player.playing:
		# Stop discards queued pre-pause/pre-crash samples; restart fades from zero.
		player.stop()
	playback = null
	_current_gain = 0.0
	_filter_z1 = 0.0
	_filter_z2 = 0.0


func _process(_delta: float) -> void:
	if _sound_is_on() and is_instance_valid(playback):
		_fill_audio_buffer()
	else:
		_stop_playback()


func _fill_audio_buffer() -> void:
	if not is_instance_valid(playback):
		return
	var count := mini(playback.get_frames_available(), ceili(SAMPLE_RATE * BUFFER_SECONDS))
	if count <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in range(count):
		frames[i] = Vector2.ONE * sample_synth()
	playback.push_buffer(frames)


func sample_synth() -> float:
	## One deterministic mono sample at SAMPLE_RATE; safe without a player/device.
	if not _sound_is_on():
		_current_gain = 0.0
		_filter_z1 = 0.0
		_filter_z2 = 0.0
		return 0.0
	_current_gain = lerpf(_current_gain, target_gain, GAIN_SMOOTH)
	_current_osc_hz = lerpf(_current_osc_hz, target_osc_hz, OSC_SMOOTH)
	_current_sub_hz = lerpf(_current_sub_hz, target_sub_hz, SUB_SMOOTH)
	_current_lowpass_hz = lerpf(_current_lowpass_hz, target_lowpass_hz, LOWPASS_SMOOTH)
	var increment := _current_osc_hz / SAMPLE_RATE
	var saw := 2.0 * _osc_phase - 1.0 - _poly_blep(_osc_phase, increment)
	var triangle := 1.0 - 4.0 * absf(_sub_phase - .5)
	_osc_phase = fposmod(_osc_phase + increment, 1.0)
	_sub_phase = fposmod(_sub_phase + _current_sub_hz / SAMPLE_RATE, 1.0)
	if _filter_countdown <= 0:
		_update_filter()
		_filter_countdown = 32
	_filter_countdown -= 1
	var mixed := (saw + triangle) * MIX_GAIN
	var filtered := _filter_b0 * mixed + _filter_z1
	_filter_z1 = _filter_b1 * mixed - _filter_a1 * filtered + _filter_z2
	_filter_z2 = _filter_b2 * mixed - _filter_a2 * filtered
	return clampf(filtered * _current_gain, -1.0, 1.0)


func _update_filter() -> void:
	var omega := TAU * _current_lowpass_hz / SAMPLE_RATE
	var cosine := cos(omega)
	# Web Audio lowpass Q defaults to 1 dB, converted to a resonance multiplier.
	var alpha := sin(omega) / (2.0 * pow(10.0, 1.0 / 20.0))
	var inverse_a0 := 1.0 / (1.0 + alpha)
	_filter_b0 = (1.0 - cosine) * .5 * inverse_a0
	_filter_b1 = (1.0 - cosine) * inverse_a0
	_filter_b2 = _filter_b0
	_filter_a1 = -2.0 * cosine * inverse_a0
	_filter_a2 = (1.0 - alpha) * inverse_a0


func _poly_blep(phase: float, increment: float) -> float:
	# Band-limit the saw discontinuity at the low CPU-friendly sample rate.
	if phase < increment:
		var x := phase / increment
		return x + x - x * x - 1.0
	if phase > 1.0 - increment:
		var x := (phase - 1.0) / increment
		return x * x + x + x + 1.0
	return 0.0


func _exit_tree() -> void:
	_stop_playback()
