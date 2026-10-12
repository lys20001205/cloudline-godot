extends SceneTree

const Controller = preload("res://scripts/environment_audio.gd")
const Flight = preload("res://scripts/flight_model.gd")
var checked := 0
var failed := 0


func check(ok: bool, label_text: String) -> void:
	checked += 1
	if ok:
		print("PASS ", label_text)
	else:
		failed += 1
		push_error("FAIL " + label_text)


func near(a: float, b: float, tolerance: float = .00001) -> bool:
	return absf(a - b) <= tolerance


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var controller := Controller.new()
	var environment_node := WorldEnvironment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(environment_node)
	root.add_child(sun)
	root.add_child(controller)
	controller.setup(environment_node, sun)
	var env := environment_node.environment
	check(controller.lighting == "day", "lighting defaults to day")
	check(not controller.audio_enabled and controller.player == null, "no audio player or autoplay before consent")
	check(env.background_mode == Environment.BG_SKY and env.sky.sky_material is ShaderMaterial, "native shader sky installed")
	for key in ["day", "golden", "night"]:
		check(controller.set_lighting(key), key + " accepted")
		var expected: Dictionary = Controller.STYLES[key]
		var style: Dictionary = controller.get_lighting_style()
		check(style.sky == expected.sky and style.horizon == expected.horizon, key + " source sky and horizon")
		check(sun.basis.z.is_equal_approx(expected.sun.normalized()), key + " source sun direction")
		check(near(env.ambient_light_energy, .44 * (1.0 - float(expected.night) * .7)), key + " source night ambient")
		check(near(sun.light_energy, .6 * (1.0 - float(expected.night) * .7)), key + " source sun intensity")
		check(near(env.fog_density, expected.fog, .00000001), key + " source fog density")
		check(controller.sky_material.get_shader_parameter("sun_direction").is_equal_approx(style.sun), key + " shader sun matches native sun")
	check(not controller.set_lighting("unknown") and controller.lighting == "night", "invalid light preserves setting")
	controller.set_weather("turbulent")
	check(near(env.fog_density, .000052 * 1.55, .00000001), "turbulence increases haze 1.55x")
	controller.set_lighting("golden")
	check(near(env.fog_density, .00009 * 1.55, .00000001), "lighting changes preserve weather haze")
	controller.set_weather("clear")
	check(near(env.fog_density, .00009, .00000001), "clear weather restores source haze")
	var flight := Flight.new("a320", "free", "clear")
	flight.spool = .5
	controller.update_sound(flight, true)
	check(controller.target_gain == 0.0 and controller.sample_synth() == 0.0, "running stays silent without consent")
	check(controller.player == null, "flight updates do not initialize audio")
	controller.set_audio_enabled(true)
	controller.update_sound(flight, true)
	var target := controller.get_sound_targets()
	check(target.on and near(target.gain, .0505), "A320 half-spool source gain")
	check(near(target.osc_hz, 97) and near(target.sub_hz, 38) and near(target.lowpass_hz, 425), "A320 half-spool source frequencies")
	for type in ["light", "a320", "jet"]:
		flight.type = type
		for spool in [0.0, .5, 1.0]:
			flight.spool = spool
			controller.update_sound(flight, true)
			var targets := controller.get_sound_targets()
			var expected_osc: float = (38 + spool * 57) if type == "light" else (52 + spool * 90)
			check(near(targets.osc_hz, expected_osc) and near(targets.sub_hz, 26 + spool * 24), "%s spool %.1f oscillator parity" % [type, spool])
			check(near(targets.gain, .028 + spool * .045) and near(targets.lowpass_hz, 250 + spool * 350), "%s spool %.1f gain/filter parity" % [type, spool])
	flight.engine = false
	flight.spool = .4
	controller.update_sound(flight, true)
	check(near(controller.target_gain, .046), "engine shutdown follows remaining spool")
	var energy := 0.0
	var maximum := 0.0
	var finite := true
	for i in range(int(Controller.SAMPLE_RATE)):
		var sample := controller.sample_synth()
		finite = finite and is_finite(sample)
		energy += sample * sample
		maximum = maxf(maximum, absf(sample))
	check(finite and energy > .01 and maximum < .1, "one second of bounded nonzero synthesized engine audio")
	controller.update_sound(flight, false)
	check(controller.target_gain == 0.0 and controller.sample_synth() == 0.0, "pause immediately silences samples")
	check(controller.playback == null and not controller.is_processing(), "pause discards playback and stops generator CPU")
	controller.update_sound(flight, true)
	check(controller.target_gain > 0.0, "resume restores source targets")
	flight.crashed = true
	controller.update_sound(flight, true)
	check(controller.target_gain == 0.0 and controller.sample_synth() == 0.0, "crash immediately silences samples")
	flight.crashed = false
	controller.update_sound(flight, true)
	controller.set_audio_enabled(false)
	check(controller.sample_synth() == 0.0 and controller.playback == null, "mute immediately discards audio")
	controller.set_audio_enabled(true)
	controller.update_sound(null, true)
	check(controller.target_gain == 0.0, "missing flight safely stays silent")
	controller.update_sound({"type": "light", "spool": 99.0, "crashed": false}, true)
	check(near(controller.target_osc_hz, 95), "unexpected high spool is bounded")
	controller.update_sound({"type": "light", "spool": -2.0, "crashed": false}, true)
	check(near(controller.target_osc_hz, 38), "unexpected negative spool is bounded")
	if AudioServer.get_driver_name() == "Dummy":
		check(not controller.audio_available and controller.player == null and not controller.is_processing(), "no audio device degrades safely without playback")
	else:
		check(controller.player != null and not controller.player.autoplay, "user enabled a non-autoplay audio player")
		check(controller.player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "generated audio uses Web-compatible stream backend")
		check(controller.generator.mix_rate == 11025 and controller.generator.buffer_length <= .15, "low sample rate and bounded buffer")
	if controller.audio_available:
		check_stream_lifecycle(controller, flight)
	controller.set_audio_enabled(false)
	controller.setup(null, null)
	check(controller.set_lighting("day"), "missing environment and sun handled safely")
	controller.queue_free()
	environment_node.queue_free()
	sun.queue_free()
	await process_frame
	# AudioServer releases stopped stream references on its next mixer tick.
	await create_timer(.1).timeout
	print("ENVIRONMENT_AUDIO_SUMMARY ", checked, " checks, ", failed, " failures")
	quit(1 if failed else 0)


func check_stream_lifecycle(controller: Controller, flight: Flight) -> void:
	check(controller.player != null and not controller.player.autoplay, "stream lifecycle creates only a non-autoplay player")
	check(controller.player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "stream lifecycle bypasses unsupported Web sample playback")
	check(controller.generator.mix_rate == 11025 and controller.generator.buffer_length <= .15, "stream lifecycle uses low-rate bounded buffer")
	check(controller.player.playing and controller.playback is AudioStreamGeneratorPlayback, "stream lifecycle starts generated playback")
	check(controller.is_processing(), "stream lifecycle enables refill processing")
	var queued_playback := controller.playback
	controller._process(.016)
	check(controller.playback == queued_playback, "stream lifecycle reuses active generator on refill")
	controller.update_sound(flight, false)
	check(not controller.player.playing and controller.playback == null, "stream lifecycle stops and discards pause buffer")
	controller.update_sound(flight, true)
	check(controller.player.playing and controller.playback != queued_playback, "stream lifecycle resumes with fresh buffer")
	flight.crashed = true
	controller.update_sound(flight, true)
	check(not controller.player.playing and controller.playback == null, "stream lifecycle stops crash buffer")
	flight.crashed = false
	controller.update_sound(flight, true)
	controller.set_audio_enabled(false)
	check(not controller.player.playing and not controller.is_processing(), "stream lifecycle mute stops playback and work")
	queued_playback = null
