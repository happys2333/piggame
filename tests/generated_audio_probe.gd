extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or DisplayServer.get_name() != "headless":
		printerr("Candidate probe requires an isolated headless project")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://candidates/manifest.json"))
	_expect(parsed is Dictionary, "candidate manifest decodes")
	if not parsed is Dictionary:
		quit(1)
		return
	var manifest: Dictionary = parsed
	_expect(not bool(manifest.get("production_audio_enabled", true)), "production audio remains disabled")
	_expect(not bool(manifest.get("final_audio_accepted", true)), "candidates are not final accepted assets")
	var entries: Array = manifest.get("files", [])
	_expect(entries.size() == 20, "complete twenty-candidate inventory")
	for entry: Dictionary in entries:
		var identifier: String = str(entry.id)
		var stream := load("res://candidates/" + str(entry.prepared_path)) as AudioStream
		_expect(stream != null, "Godot imports " + identifier)
		if stream == null:
			continue
		_expect(absf(stream.get_length() - float(entry.metrics.seconds)) < 0.08, "decoded duration " + identifier)
		if str(entry.prepared_path).ends_with(".ogg"):
			_expect(stream is AudioStreamOggVorbis, "Vorbis stream " + identifier)
			(stream as AudioStreamOggVorbis).loop = true
			_expect((stream as AudioStreamOggVorbis).loop, "full-stream loop supported " + identifier)
		else:
			_expect(stream is AudioStreamWAV, "WAV stream " + identifier)
			_expect((stream as AudioStreamWAV).mix_rate == 44100, "effect sample rate " + identifier)
		stream = null
	for failure: String in _failures:
		printerr(failure)
	print("CLOUD_AUDIO_PROBE: assertions=%d failures=%d candidates=%d physical_output=false" % [_assertions, _failures.size(), entries.size()])
	call_deferred("quit", 0 if _failures.is_empty() else 1)
