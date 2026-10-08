extends Node

signal settings_changed

const BUS_NAMES: Array[String] = ["Music", "Ambient", "Interaction"]
const MANIFEST_PATH: String = "res://game/assets/audio/audio_manifest.json"
const SFX_ALIASES := {
	"pet": "pet_1",
	"feed": "bite",
	"purchase": "unlock",
}

const EVENT_SFX := {
	"walk": "step_1", "run": "treadmill", "sleep": "snore_1", "bed_nap": "snore_2",
	"window_nap": "snore_1", "fridge": "fridge_open", "table_snack": "bite", "cookie_guard": "bag_rustle",
	"drink": "sip", "tea": "sip", "yoga": "yoga_roll", "blanket_roll": "yoga_roll", "paint": "paint",
	"water_plant": "water", "radio": "radio_click", "wind_chime": "wind_chime", "robot_ride": "robot",
	"weather": "water", "ball": "soft_bump", "alarm": "soft_bump",
	"mirror_pose": "hum_1", "stare": "hum_2",
}

var music_volume: float = 0.7
var ambient_volume: float = 0.75
var interaction_volume: float = 0.8
var desktop_music_enabled: bool = false
var desktop_mode: bool = false
var development_placeholder: bool = true
var _music_ids: Array[String] = []
var _audio_paths: Dictionary = {}
var _music_index: int = 0
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_cursor: int = 0


func _ready() -> void:
	var manifest_errors: Array[String] = load_manifest()
	for error: String in manifest_errors:
		push_error("Audio manifest: %s" % error)
	for bus_name: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	apply()
	if not is_playback_enabled():
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.finished.connect(_next_music)
	add_child(_music_player)
	for index: int in 8:
		var player := AudioStreamPlayer.new()
		player.bus = "Interaction"
		_sfx_players.append(player)
		add_child(player)
	for index: int in 2:
		var ambient_player := AudioStreamPlayer.new()
		ambient_player.bus = "Ambient"
		_ambient_players.append(ambient_player)
		add_child(ambient_player)
	if DisplayServer.get_name() != "headless":
		call_deferred("play_music", 0)


func load_manifest(path: String = MANIFEST_PATH) -> Array[String]:
	var errors: Array[String] = []
	var data: Dictionary = JsonStore.read_object(path)
	_music_ids.clear()
	_audio_paths.clear()
	if data.is_empty():
		errors.append("could not read %s" % path)
		return errors
	development_placeholder = bool(data.get("development_placeholder", true))
	_load_manifest_entries(data.get("music", []), "music", _music_ids, errors)
	var sfx_ids: Array[String] = []
	_load_manifest_entries(data.get("sfx", []), "sfx", sfx_ids, errors)
	if _music_ids.size() != 4:
		errors.append("expected 4 music entries, found %d" % _music_ids.size())
	if sfx_ids.size() != 30:
		errors.append("expected 30 sound-effect entries, found %d" % sfx_ids.size())
	for alias: String in SFX_ALIASES:
		if not _audio_paths.has(str(SFX_ALIASES[alias])):
			errors.append("alias %s references missing audio id %s" % [alias, SFX_ALIASES[alias]])
	for animation_id: String in EVENT_SFX:
		if not _audio_paths.has(str(EVENT_SFX[animation_id])):
			errors.append("event sound %s references missing audio id %s" % [animation_id, EVENT_SFX[animation_id]])
	return errors


func audio_path(id: String) -> String:
	var resolved_id: String = str(SFX_ALIASES.get(id, id))
	return str(_audio_paths.get(resolved_id, ""))


func music_ids() -> Array[String]:
	return _music_ids.duplicate()


func is_playback_enabled() -> bool:
	return ReleaseProfile.AUDIO_PLAYBACK_ENABLED


func _load_manifest_entries(value: Variant, kind: String, ordered_ids: Array[String], errors: Array[String]) -> void:
	if not value is Array:
		errors.append("%s entries must be an array" % kind)
		return
	for raw: Variant in value as Array:
		if not raw is Dictionary:
			errors.append("%s entry must be an object" % kind)
			continue
		var entry: Dictionary = raw as Dictionary
		var id: String = str(entry.get("id", ""))
		var resource_path: String = str(entry.get("path", ""))
		if id.is_empty() or _audio_paths.has(id):
			errors.append("%s entry has an empty or duplicate id %s" % [kind, id])
			continue
		if not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path):
			errors.append("%s references missing resource %s" % [id, resource_path])
			continue
		_audio_paths[id] = resource_path
		ordered_ids.append(id)


func configure(data: Dictionary) -> void:
	music_volume = _bounded_float(data.get("music_volume", music_volume), music_volume, 0.0, 1.0)
	ambient_volume = _bounded_float(data.get("ambient_volume", ambient_volume), ambient_volume, 0.0, 1.0)
	interaction_volume = _bounded_float(data.get("interaction_volume", interaction_volume), interaction_volume, 0.0, 1.0)
	desktop_music_enabled = _safe_bool(data.get("desktop_music_enabled", desktop_music_enabled), desktop_music_enabled)
	apply()


func set_desktop_mode(enabled: bool) -> void:
	desktop_mode = enabled
	apply()


func apply() -> void:
	var playback_enabled: bool = is_playback_enabled()
	_set_bus("Music", (0.0 if desktop_mode and not desktop_music_enabled else music_volume) if playback_enabled else 0.0)
	_set_bus("Ambient", ambient_volume if playback_enabled else 0.0)
	_set_bus("Interaction", interaction_volume if playback_enabled else 0.0)
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {
		"music_volume": music_volume,
		"ambient_volume": ambient_volume,
		"interaction_volume": interaction_volume,
		"desktop_music_enabled": desktop_music_enabled,
	}


func play_music(index: int = -1) -> void:
	if not is_playback_enabled() or _music_ids.is_empty() or not is_instance_valid(_music_player):
		return
	if index >= 0:
		_music_index = index % _music_ids.size()
	var stream: AudioStream = load(audio_path(_music_ids[_music_index]))
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player.stream = stream
	_music_player.play()


func play_sfx(id: String) -> void:
	if not is_playback_enabled() or DisplayServer.get_name() == "headless":
		return
	var path: String = audio_path(id)
	if path.is_empty() or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = load(path)
	player.play()


func play_event_step(animation_id: String) -> void:
	if not is_playback_enabled() or DisplayServer.get_name() == "headless":
		return
	var sound_id: String = str(EVENT_SFX.get(animation_id, ""))
	if sound_id.is_empty():
		return
	var path: String = audio_path(sound_id)
	if path.is_empty():
		return
	var ambient: bool = animation_id in ["weather", "wind_chime", "water_plant", "window_nap"]
	var player: AudioStreamPlayer
	if ambient and not _ambient_players.is_empty():
		player = _ambient_players[_ambient_cursor]
		_ambient_cursor = (_ambient_cursor + 1) % _ambient_players.size()
	else:
		player = _sfx_players[_sfx_cursor]
		_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = load(path)
	player.play()


func _next_music() -> void:
	if _music_ids.is_empty():
		return
	_music_index = (_music_index + 1) % _music_ids.size()
	play_music(_music_index)


func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for player: AudioStreamPlayer in _ambient_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


static func _bounded_float(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return clampf(float(value), minimum, maximum)


static func _safe_bool(value: Variant, fallback: bool) -> bool:
	return bool(value) if value is bool else fallback


static func _linear_to_db_safe(value: float) -> float:
	return linear_to_db(value) if value > 0.0001 else -80.0


func _set_bus(bus_name: String, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, _linear_to_db_safe(value))
