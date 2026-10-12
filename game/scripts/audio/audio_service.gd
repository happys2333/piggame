extends Node

signal settings_changed

const BUS_NAMES: Array[String] = ["Interaction"]
const MANIFEST_PATH: String = "res://game/assets/audio/audio_manifest.json"
const VOICE_LIMIT: int = 3
const FEEDBACK_GAP_MS: int = 140
const SAME_SOUND_GAP_MS: int = 500
const SFX_ALIASES := {"pet": "pet_content", "pet_1": "pet_content", "feed": "bite", "purchase": "unlock"}

var interaction_volume: float = 0.65
var muted: bool = false
var development_placeholder: bool = true
var _manifest_valid: bool = false
var _audio_paths: Dictionary = {}
var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _last_feedback_ms: int = -SAME_SOUND_GAP_MS
var _last_sound_ms: Dictionary = {}
var _focused: bool = false
var _quiet: bool = false
var _do_not_disturb: bool = false
var _visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for error: String in load_manifest():
		push_error("Audio manifest: %s" % error)
	for bus_name: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var session: Node = get_node_or_null("/root/GameSession")
	if session != null:
		session.desktop_companion_changed.connect(_sync_protection)
	get_window().visibility_changed.connect(_sync_protection)
	_sync_protection()
	if not is_playback_enabled() or not _output_available():
		return
	for index: int in VOICE_LIMIT:
		var player := AudioStreamPlayer.new()
		player.bus = "Interaction"
		_sfx_players.append(player)
		add_child(player)


func load_manifest(path: String = MANIFEST_PATH) -> Array[String]:
	var errors: Array[String] = []
	var data: Dictionary = JsonStore.read_object(path)
	stop_all()
	_audio_paths.clear()
	_streams.clear()
	_manifest_valid = false
	if data.is_empty():
		errors.append("could not read %s" % path)
		return errors
	development_placeholder = bool(data.get("development_placeholder", true))
	if data.get("playback_policy", "") != "player_feedback_only" or data.get("music", []) != []:
		errors.append("only player feedback is supported; music must be empty")
	var entries: Variant = data.get("sfx", [])
	if not entries is Array or (entries as Array).is_empty():
		errors.append("sfx must be a nonempty array")
		return errors
	for raw: Variant in entries as Array:
		if not raw is Dictionary:
			errors.append("sfx entry must be an object")
			continue
		var entry: Dictionary = raw as Dictionary
		var id: String = str(entry.get("id", ""))
		var resource_path: String = str(entry.get("path", ""))
		if id.is_empty() or _audio_paths.has(id):
			errors.append("empty or duplicate audio id %s" % id)
			continue
		if not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path):
			errors.append("%s references missing resource %s" % [id, resource_path])
			continue
		_audio_paths[id] = resource_path
	for alias: String in SFX_ALIASES:
		if not _audio_paths.has(str(SFX_ALIASES[alias])):
			errors.append("missing alias target %s" % alias)
	_manifest_valid = errors.is_empty()
	return errors


func audio_path(id: String) -> String:
	return str(_audio_paths.get(str(SFX_ALIASES.get(id, id)), ""))


func is_playback_enabled() -> bool:
	return ReleaseProfile.AUDIO_PLAYBACK_ENABLED


func configure(data: Dictionary) -> void:
	var value: Variant = data.get("interaction_volume", interaction_volume)
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
		interaction_volume = clampf(float(value), 0.0, 1.0)
	var mute_value: Variant = data.get("muted", muted)
	if mute_value is bool:
		muted = mute_value
	apply()


func to_dict() -> Dictionary:
	return {"interaction_volume": interaction_volume, "muted": muted}


func set_protection(focused: bool, quiet: bool, do_not_disturb: bool, visible: bool) -> void:
	_focused = focused
	_quiet = quiet
	_do_not_disturb = do_not_disturb
	_visible = visible
	apply()


func _sync_protection() -> void:
	var session: Node = get_node_or_null("/root/GameSession")
	if session == null:
		set_protection(false, true, true, false)
		return
	var policy: DesktopCompanionPolicy = session.desktop_companion
	set_protection(policy.application_focused, policy.quiet, policy.do_not_disturb, get_window().visible)


func feedback_allowed(origin: String = "autonomous") -> bool:
	return origin == "player" and _manifest_valid and is_playback_enabled() and _focused and _visible and not _quiet and not _do_not_disturb and not muted and interaction_volume > 0.0001


func _output_available() -> bool:
	return DisplayServer.get_name() != "headless"


func _window_minimized() -> bool:
	return get_window().mode == Window.MODE_MINIMIZED


func apply() -> void:
	var enabled: bool = feedback_allowed("player") and _output_available()
	var bus_index: int = AudioServer.get_bus_index("Interaction")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not enabled)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(interaction_volume) if enabled else -80.0)
	if not enabled:
		stop_all()
	settings_changed.emit()


func play_sfx(id: String, origin: String = "autonomous") -> bool:
	if not feedback_allowed(origin) or not _output_available() or _window_minimized():
		return false
	var resolved_id: String = str(SFX_ALIASES.get(id, id))
	var path: String = audio_path(resolved_id)
	var now: int = Time.get_ticks_msec()
	if path.is_empty() or now - _last_feedback_ms < FEEDBACK_GAP_MS or now - int(_last_sound_ms.get(resolved_id, -SAME_SOUND_GAP_MS)) < SAME_SOUND_GAP_MS:
		return false
	var available: AudioStreamPlayer
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			available = player
			break
	if available == null:
		return false
	if not _streams.has(resolved_id):
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			return false
		_streams[resolved_id] = stream
	available.stream = _streams[resolved_id] as AudioStream
	available.play()
	_last_feedback_ms = now
	_last_sound_ms[resolved_id] = now
	return true


func stop_all() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_focused = false
		apply()


func _exit_tree() -> void:
	stop_all()
