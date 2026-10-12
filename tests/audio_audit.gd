extends Node

const AUDIO_SCRIPT: Script = preload("res://game/scripts/audio/audio_service.gd")

class EnabledFixture extends "res://game/scripts/audio/audio_service.gd":
	func is_playback_enabled() -> bool:
		return true

var _assertions: int = 0
var _failures: Array[String] = []
var _streams: Array[Dictionary] = []
var _future_policy: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _bus_levels() -> Dictionary:
	var levels: Dictionary = {}
	for bus: String in AUDIO_SCRIPT.BUS_NAMES:
		levels[bus] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	return levels


func _expect_silent(label: String) -> void:
	for bus: String in AUDIO_SCRIPT.BUS_NAMES:
		var index: int = AudioServer.get_bus_index(bus)
		_expect(index >= 0 and AudioServer.get_bus_volume_db(index) <= -79.9, label + " silent " + bus)
	_expect(AudioService.get_child_count() == 0, label + " creates no playback nodes")


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	var output: String = OS.get_environment("PIGGAME_AUDIO_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or output.is_empty() or DisplayServer.get_name() != "headless" or OS.get_environment("PIGGAME_AUDIO_DUMMY_ONLY") != "1":
		printerr("Audio audit requires the isolated headless Dummy runner")
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	_expect(not AudioService.is_playback_enabled(), "production profile stays silent")
	_expect(AudioService.development_placeholder, "current manifest remains honest about development placeholders")
	_expect(AudioService.load_manifest().is_empty(), "all manifest routes validate")
	_expect(AudioService.music_ids().size() == 4, "four ordered BGM routes")
	var manifest: Dictionary = JsonStore.read_object(AUDIO_SCRIPT.MANIFEST_PATH)
	for kind: String in ["music", "sfx"]:
		var entries: Array = manifest[kind]
		_expect(entries.size() == (4 if kind == "music" else 30), "inventory count " + kind)
		for entry: Dictionary in entries:
			var identifier: String = str(entry.id)
			_expect(AudioService.audio_path(identifier) == str(entry.path), "runtime route " + identifier)
			var stream := load(str(entry.path)) as AudioStreamWAV
			_expect(stream != null and stream.get_length() > 0.0, "Godot decodes " + identifier)
			if stream != null:
				_streams.append({"id":identifier, "length":stream.get_length(), "mix_rate":stream.mix_rate, "stereo":stream.stereo, "format":stream.format, "imported_loop_begin":stream.loop_begin, "imported_loop_end":stream.loop_end, "imported_loop_mode":stream.loop_mode})
	for alias: String in AUDIO_SCRIPT.SFX_ALIASES:
		_expect(AudioService.audio_path(alias) == AudioService.audio_path(str(AUDIO_SCRIPT.SFX_ALIASES[alias])), "semantic alias " + alias)
	for animation: String in AUDIO_SCRIPT.EVENT_SFX:
		_expect(not AudioService.audio_path(str(AUDIO_SCRIPT.EVENT_SFX[animation])).is_empty(), "event route " + animation)
	_expect(AudioService.audio_path("missing_sound").is_empty(), "unknown route remains safe")
	for desktop: bool in [false, true]:
		for music_preference: bool in [false, true]:
			for focused: bool in [false, true]:
				for quiet: bool in [false, true]:
					for disturb: bool in [false, true]:
						GameSession.desktop_companion.set_application_focused(focused)
						GameSession.desktop_companion.load_settings({"desktop_quiet":quiet, "desktop_do_not_disturb":disturb})
						AudioService.configure({"music_volume":1.0, "ambient_volume":1.0, "interaction_volume":1.0, "desktop_music_enabled":music_preference})
						AudioService.set_desktop_mode(desktop)
						AudioService.play_music(0)
						AudioService.play_sfx("points")
						AudioService.play_event_step("weather")
						_expect_silent("production policy matrix")
	var fixture := EnabledFixture.new()
	add_child(fixture)
	_expect((fixture.get("_sfx_players") as Array).size() == 8, "future fixture retains bounded eight-voice interaction pool")
	_expect((fixture.get("_ambient_players") as Array).size() == 2, "future fixture retains bounded two-voice ambient pool")
	for index: int in 4:
		fixture.play_music(index)
		var player := fixture.get("_music_player") as AudioStreamPlayer
		var stream := player.stream as AudioStreamWAV
		_expect(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM loop requested " + str(index))
		_expect(stream != null and stream.loop_begin >= 0 and stream.loop_end > stream.loop_begin, "imported BGM loop has valid bounds " + str(index))
		await get_tree().create_timer(0.15).timeout
		_streams[index]["dummy_playback_position"] = player.get_playback_position()
		_streams[index]["playing_in_dummy_fixture"] = player.playing
		player.stop()
		player.stream = null
		var diagnostic_stream := stream.duplicate() as AudioStreamWAV
		diagnostic_stream.loop_end = roundi(diagnostic_stream.get_length() * diagnostic_stream.mix_rate)
		var diagnostic_player := AudioStreamPlayer.new()
		diagnostic_player.bus = "Music"
		diagnostic_player.stream = diagnostic_stream
		add_child(diagnostic_player)
		await get_tree().create_timer(0.1).timeout
		diagnostic_player.play()
		await get_tree().create_timer(0.25).timeout
		_streams[index]["diagnostic_loop_end"] = diagnostic_stream.loop_end
		_streams[index]["diagnostic_playback_position"] = diagnostic_player.get_playback_position()
		_streams[index]["diagnostic_full_length_loop_advances"] = diagnostic_player.get_playback_position() > 0.01
		diagnostic_player.stop()
		diagnostic_player.stream = null
		diagnostic_player.queue_free()
		diagnostic_stream = null
		stream = null
		await get_tree().create_timer(0.1).timeout
	for music_preference: bool in [false, true]:
		for focused: bool in [false, true]:
			for quiet: bool in [false, true]:
				for disturb: bool in [false, true]:
					GameSession.desktop_companion.set_application_focused(focused)
					GameSession.desktop_companion.load_settings({"desktop_quiet":quiet, "desktop_do_not_disturb":disturb})
					fixture.configure({"music_volume":0.7, "ambient_volume":0.75, "interaction_volume":0.8, "desktop_music_enabled":music_preference})
					fixture.set_desktop_mode(true)
					var levels: Dictionary = _bus_levels()
					_future_policy.append({"desktop_music_enabled":music_preference, "focused":focused, "quiet":quiet, "do_not_disturb":disturb, "bus_db":levels, "unsafe_autonomous_bus_eligibility":(not focused or quiet or disturb) and (float(levels.Music) > -79.9 or float(levels.Ambient) > -79.9 or float(levels.Interaction) > -79.9)})
	fixture.stop_all()
	var fixture_player := fixture.get("_music_player") as AudioStreamPlayer
	_expect(not fixture_player.playing and fixture_player.stream == null, "fixture cleanup stops music and clears stream")
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	AudioService.apply()
	_expect_silent("fixture teardown")
	var file := FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"completed":true, "assertions":_assertions, "failures":_failures, "physical_output_tested":false, "driver":"Dummy", "production_playback_enabled":false, "decoded_streams":_streams, "future_enabled_policy_observations":_future_policy}, "\t"))
	file.close()
	for failure: String in _failures:
		printerr(failure)
	print("AUDIO_AUDIT: assertions=%d failures=%d streams=%d production_silent=true physical_output=false" % [_assertions, _failures.size(), _streams.size()])
	get_tree().call_deferred("quit", 0 if _failures.is_empty() else 1)
