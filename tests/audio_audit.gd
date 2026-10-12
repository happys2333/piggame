extends Node

const AUDIO_SCRIPT: Script = preload("res://game/scripts/audio/audio_service.gd")

class DummyFixture extends "res://game/scripts/audio/audio_service.gd":
	var requests: Array[String] = []
	var minimized: bool = false

	func _output_available() -> bool:
		return DisplayServer.get_name() == "headless" and OS.get_environment("PIGGAME_AUDIO_DUMMY_ONLY") == "1"

	func _window_minimized() -> bool:
		return minimized

	func play_sfx(id: String, origin: String = "autonomous") -> bool:
		requests.append(id + ":" + origin)
		return super.play_sfx(id, origin)

var _assertions: int = 0
var _failures: Array[String] = []
var _streams: Array[Dictionary] = []
var _policy: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _reset_rate(fixture: Node) -> void:
	fixture.set("_last_feedback_ms", -10000)
	(fixture.get("_last_sound_ms") as Dictionary).clear()


func _idle(fixture: Node) -> bool:
	for player: AudioStreamPlayer in fixture.get("_sfx_players") as Array:
		if player.playing or player.stream != null:
			return false
	return true


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	var output: String = OS.get_environment("PIGGAME_AUDIO_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or output.is_empty() or DisplayServer.get_name() != "headless" or OS.get_environment("PIGGAME_AUDIO_DUMMY_ONLY") != "1":
		printerr("Audio audit requires the isolated headless Dummy runner")
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	Engine.max_fps = 60
	_expect(AudioService.is_playback_enabled(), "approved feedback enabled")
	_expect(not AudioService.development_placeholder, "generated feedback replaces synthesized placeholders")
	_expect(AudioService.get_child_count() == 0, "production headless service cannot emit sound")
	_expect(AudioService.load_manifest().is_empty(), "manifest validates")
	var manifest: Dictionary = JsonStore.read_object(AUDIO_SCRIPT.MANIFEST_PATH)
	_expect(manifest.music == [] and manifest.sfx.size() == 13, "SFX-only inventory")
	for entry: Dictionary in manifest.sfx as Array:
		var stream := load(str(entry.path)) as AudioStreamWAV
		_expect(stream != null and stream.get_length() > 0.0, "Godot decodes " + str(entry.id))
		_expect(stream != null and stream.mix_rate == 44100 and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "one-shot mono import " + str(entry.id))
		if stream != null:
			_streams.append({"id":str(entry.id), "length":stream.get_length(), "mix_rate":stream.mix_rate, "stereo":stream.stereo, "loop_mode":stream.loop_mode})
	for alias: String in AUDIO_SCRIPT.SFX_ALIASES:
		_expect(AudioService.audio_path(alias) == AudioService.audio_path(str(AUDIO_SCRIPT.SFX_ALIASES[alias])), "semantic alias " + alias)
	var fixture := DummyFixture.new()
	add_child(fixture)
	_expect(fixture.get_child_count() == AUDIO_SCRIPT.VOICE_LIMIT, "only three feedback voices")
	_expect(not fixture.has_method("play_music") and not fixture.has_method("play_event_step"), "no background or timeline audio entry")
	for focused: bool in [false, true]:
		for quiet: bool in [false, true]:
			for disturb: bool in [false, true]:
				for visible: bool in [false, true]:
					for mute: bool in [false, true]:
						fixture.stop_all()
						_reset_rate(fixture)
						fixture.configure({"interaction_volume":1.0, "muted":mute})
						fixture.set_protection(focused, quiet, disturb, visible)
						var allowed: bool = focused and visible and not quiet and not disturb and not mute
						var bus: int = AudioServer.get_bus_index("Interaction")
						var blocked: bool = AudioServer.is_bus_mute(bus) and AudioServer.get_bus_volume_db(bus) <= -79.9
						_expect(blocked == not allowed, "bus gate mirrors policy")
						_expect(not fixture.play_sfx("pet_content"), "implicit background request rejected")
						_expect(not fixture.play_sfx("pet_content", "event"), "timeline request rejected")
						_expect(fixture.play_sfx("pet_content", "player") == allowed, "player request mirrors policy")
						if not allowed:
							_expect(_idle(fixture), "blocked requests never queue")
						_policy.append({"focused":focused, "quiet":quiet, "do_not_disturb":disturb, "visible":visible, "muted":mute, "allowed":allowed, "unsafe_autonomous_bus_eligibility":false})
	fixture.set_protection(true, false, false, true)
	fixture.configure({"interaction_volume":1.0, "muted":false})
	fixture.stop_all()
	_reset_rate(fixture)
	_expect(fixture.play_sfx("pet_content", "player"), "active request starts")
	_expect(not fixture.play_sfx("ui_click", "player"), "same gesture cannot double up generic UI click")
	await get_tree().create_timer(0.16).timeout
	while Time.get_ticks_msec() - int(fixture.get("_last_feedback_ms")) < 180:
		await get_tree().process_frame
	fixture.set_protection(true, false, false, true)
	_expect(not fixture.play_sfx("pet_content", "player"), "identical feedback is debounced")
	_expect(fixture.play_sfx("accessory", "player"), "different gesture can overlap after short cooldown")
	fixture.set_protection(false, false, false, true)
	_expect(_idle(fixture), "focus loss interrupts and clears every voice")
	fixture.set_protection(true, false, false, true)
	_expect(_idle(fixture), "refocus never replays dropped feedback")
	for interruption: String in ["quiet", "disturb", "hidden", "mute", "zero_volume"]:
		fixture.stop_all()
		fixture.configure({"interaction_volume":1.0, "muted":false})
		fixture.set_protection(true, false, false, true)
		_reset_rate(fixture)
		_expect(fixture.play_sfx("bite", "player"), "start before " + interruption)
		if interruption == "mute":
			fixture.configure({"muted":true})
		elif interruption == "zero_volume":
			fixture.configure({"interaction_volume":0.0})
		else:
			fixture.set_protection(true, interruption == "quiet", interruption == "disturb", interruption != "hidden")
		_expect(_idle(fixture), "interrupt immediately for " + interruption)
	fixture.configure({"interaction_volume":0.6, "muted":false})
	fixture.set_protection(true, false, false, true)
	fixture.stop_all()
	for id: String in ["bite", "sip", "blanket"]:
		_reset_rate(fixture)
		_expect(fixture.play_sfx(id, "player"), "voice capacity " + id)
	_reset_rate(fixture)
	_expect(not fixture.play_sfx("unlock", "player"), "saturated pool drops feedback rather than stealing or queueing")
	fixture.stop_all()
	_expect(not fixture.play_sfx("unknown", "player"), "unknown ID is safe")
	fixture.minimized = true
	_expect(not fixture.play_sfx("bite", "player"), "minimized window rejects active feedback")
	fixture.minimized = false
	fixture.configure({"interaction_volume":INF, "muted":1, "desktop_music_enabled":true, "music_volume":1.0})
	_expect(fixture.to_dict() == {"interaction_volume":0.6, "muted":false}, "legacy preferences cannot resurrect BGM")
	await _test_session_routes(fixture)
	fixture.stop_all()
	fixture.queue_free()
	await get_tree().process_frame
	AudioService.apply()
	var file := FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"completed":true, "assertions":_assertions, "failures":_failures, "physical_output_tested":false, "driver":"Dummy", "production_playback_enabled":true, "decoded_streams":_streams, "policy_observations":_policy}, "\t"))
	file.close()
	for failure: String in _failures:
		printerr(failure)
	print("AUDIO_AUDIT: assertions=%d failures=%d streams=%d feedback_only=true physical_output=false" % [_assertions, _failures.size(), _streams.size()])
	get_tree().call_deferred("quit", 0 if _failures.is_empty() else 1)


func _test_session_routes(fixture: DummyFixture) -> void:
	var production: Node = get_node("/root/AudioService")
	production.name = "ProductionAudio"
	remove_child(fixture)
	fixture.name = "AudioService"
	get_tree().root.add_child(fixture)
	GameSession.desktop_companion.set_application_focused(true)
	GameSession.desktop_companion.load_settings({"desktop_quiet":false, "desktop_do_not_disturb":false})
	fixture.set_protection(true, false, false, true)
	_expect(GameSession.initialize_current_companion("Audio Pig", "personality_shy", true), "initialize valid companion fixture")
	fixture.requests.clear()
	GameSession.pet_pig()
	_expect("pet_shy:player" in fixture.requests, "petting personality selects shy feedback")
	fixture.requests.clear()
	GameSession.poke_pig()
	_expect("pet_question:player" in fixture.requests, "poking selects question feedback")
	GameSession.pig_state.add_familiarity(2000)
	GameSession.pig_state.add_points(5000)
	fixture.requests.clear()
	_expect(GameSession.feed("snack_berry_milk"), "manual milk purchase commits")
	_expect(fixture.requests == ["sip:player"], "feeding plays only one semantic sound")
	fixture.requests.clear()
	GameSession.pig_state.owned_outfits.append("outfit_round_glasses")
	_expect(GameSession.equip_outfit("outfit_round_glasses"), "outfit commits")
	_expect(fixture.requests == ["accessory:player"], "outfit feedback is post-save")
	fixture.requests.clear()
	GameSession.call("_on_behavior_completed", {}, 1)
	GameSession.call("_on_familiarity_level_changed", 8)
	GameSession.call("_announce_event_photo", "event_move_in")
	GameSession.save_game()
	_expect(fixture.requests.is_empty(), "automatic points, level, event photos and mail stay silent")
	GameSession.set_sound_muted(true)
	GameSession.set_sound_volume(0.35)
	var settings: Dictionary = GameSession.save_service.load_settings()
	_expect(settings.get("audio", {}) == {"interaction_volume":0.35, "muted":true}, "volume and mute persist in machine settings")
	GameSession.set_sound_muted(false)
	GameSession.set_sound_volume(0.65)
	var state_before: Dictionary = GameSession.pig_state.to_dict().duplicate(true)
	var save_before: String = GameSession.save_service.temp_path
	var blocker: String = GameSession.save_service.base_dir + "/blocker"
	var blocked_file := FileAccess.open(blocker, FileAccess.WRITE)
	blocked_file.store_string("fixture")
	blocked_file.close()
	GameSession.save_service.temp_path = blocker + "/savegame.tmp.json"
	fixture.requests.clear()
	_expect(not GameSession.feed("snack_apple"), "failed save rolls back the action")
	_expect(fixture.requests.is_empty() and GameSession.pig_state.to_dict() == state_before, "failed transaction has no success sound")
	GameSession.save_service.temp_path = save_before
	get_tree().root.remove_child(fixture)
	production.name = "AudioService"
	add_child(fixture)
	await get_tree().process_frame
