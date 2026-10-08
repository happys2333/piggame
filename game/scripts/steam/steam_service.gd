extends Node

signal achievement_unlocked(id: String)
signal backend_ready
signal backend_failed(message: String)

const STATS_RETRY_SECONDS: float = 60.0
const STATS_RESULT_INVALID_PARAM: int = 8

var available: bool = false
var user_stats_ready: bool = false
var rich_presence: String = ""
var _unlocked: Dictionary = {}
var _stats: Dictionary = {}
var _submitted_achievements: Dictionary = {}
var _submitted_stats: Dictionary = {}
var _backend: Object
var _callback_elapsed: float = 0.0
var _stats_store_pending: bool = false
var _stats_store_in_flight: bool = false
var _stats_write_retry_pending: bool = false
var _stats_store_backoff: bool = false
var _stats_retry_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_optional_backend()


func _process(delta: float) -> void:
	if not available or _backend == null:
		return
	if user_stats_ready and (_stats_store_pending or _stats_write_retry_pending) and not _stats_store_in_flight:
		_stats_retry_elapsed += delta
		if _stats_retry_elapsed >= STATS_RETRY_SECONDS:
			_stats_retry_elapsed = 0.0
			_stats_store_backoff = false
			_flush_pending_progress()
	_callback_elapsed += delta
	if _callback_elapsed >= 0.1:
		_callback_elapsed = 0.0
		if _backend.has_method("run_callbacks"):
			_backend.call("run_callbacks")


func unlock_achievement(id: String) -> bool:
	if id.is_empty() or _unlocked.has(id):
		return false
	_unlocked[id] = true
	if _submit_achievement(id):
		_store_stats()
	achievement_unlocked.emit(id)
	return true


func set_rich_presence(activity_key: String) -> void:
	rich_presence = activity_key
	_submit_rich_presence()


func _submit_rich_presence() -> void:
	if available and _backend != null and _backend.has_method("setRichPresence"):
		_backend.call("setRichPresence", "activity", rich_presence)
		_backend.call("setRichPresence", "steam_display", "#%s" % rich_presence)


func is_achievement_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func set_stat(id: String, value: Variant) -> bool:
	if id.is_empty() or not (value is int or value is float):
		return false
	if _stats.get(id, null) == value:
		return false
	_stats[id] = value
	if _submit_stat(id, value):
		_store_stats()
	return true


func get_stat(id: String, fallback: Variant = 0) -> Variant:
	return _stats.get(id, fallback)


func sync_stats(values: Dictionary) -> void:
	var changed: bool = false
	for id: String in values:
		var value: Variant = values[id]
		if not (value is int or value is float) or _stats.get(id, null) == value:
			continue
		_stats[id] = value
		changed = _submit_stat(id, value) or changed
	if changed:
		_store_stats()


func cloud_save_relative_paths(for_profile: String = "") -> Array[String]:
	var root: String = ReleaseProfile.save_relative_root(for_profile)
	return [
		"%s/savegame.json" % root,
		"%s/savegame.backup1.json" % root,
		"%s/savegame.backup2.json" % root,
		"%s/photos/*.png" % root,
	]


func sync_achievements(ids: Array[String]) -> void:
	var changed: bool = false
	for id: String in ids:
		if not _unlocked.has(id):
			_unlocked[id] = true
		changed = _submit_achievement(id) or changed
	if changed:
		_store_stats()


func _submit_achievement(id: String) -> bool:
	if (
		not available
		or not user_stats_ready
		or _backend == null
		or _submitted_achievements.has(id)
		or not _backend.has_method("setAchievement")
	):
		return false
	var result: Variant = _backend.call("setAchievement", id)
	if result is bool and not bool(result):
		_stats_write_retry_pending = true
		return false
	_submitted_achievements[id] = true
	_stats_store_pending = true
	return true


func _submit_stat(id: String, value: Variant) -> bool:
	if not available or not user_stats_ready or _backend == null or _submitted_stats.get(id, null) == value:
		return false
	if value is int and _backend.has_method("setStatInt"):
		var result: Variant = _backend.call("setStatInt", id, int(value))
		if result is bool and not bool(result):
			_stats_write_retry_pending = true
			return false
	elif value is float and _backend.has_method("setStatFloat"):
		var result: Variant = _backend.call("setStatFloat", id, float(value))
		if result is bool and not bool(result):
			_stats_write_retry_pending = true
			return false
	else:
		return false
	_submitted_stats[id] = value
	_stats_store_pending = true
	return true


func _store_stats() -> void:
	if not available or not user_stats_ready or _backend == null or not _stats_store_pending or _stats_store_in_flight or _stats_store_backoff or not _backend.has_method("storeStats"):
		return
	_stats_retry_elapsed = 0.0
	_stats_store_pending = false
	_stats_store_in_flight = _backend.has_signal("user_stats_stored")
	var result: Variant = _backend.call("storeStats")
	if result is bool and not bool(result):
		_stats_store_in_flight = false
		_stats_store_pending = true
		_stats_store_backoff = true


func _on_user_stats_stored(_game_id: Variant, result: Variant) -> void:
	if not _stats_store_in_flight:
		return
	_stats_store_in_flight = false
	_stats_retry_elapsed = 0.0
	if not _stats_result_succeeded(result):
		_stats_store_pending = true
		_stats_store_backoff = true
		if result is int and int(result) == STATS_RESULT_INVALID_PARAM:
			_submitted_achievements.clear()
			_submitted_stats.clear()
		backend_failed.emit("Steamworks could not store progress; local progress is retained for retry")


func _initialize_optional_backend() -> void:
	available = false
	user_stats_ready = false
	if not Engine.has_singleton("Steam"):
		return
	_initialize_backend(Engine.get_singleton("Steam"))


func _initialize_backend(backend: Object) -> void:
	_backend = backend
	if _backend.has_signal("user_stats_stored"):
		var callback := Callable(self, "_on_user_stats_stored")
		if not _backend.is_connected("user_stats_stored", callback):
			_backend.connect("user_stats_stored", callback)
	var result: Variant
	if _backend.has_method("steamInitEx"):
		result = _backend.call("steamInitEx", 0, false)
	elif _backend.has_method("steamInit"):
		result = _backend.call("steamInit")
	else:
		backend_failed.emit("Steam singleton has no supported initialization method")
		return
	available = _init_succeeded(result)
	if available:
		_submit_rich_presence()
		_request_current_stats()
	else:
		backend_failed.emit("Steamworks initialization failed; continuing in offline stub mode")


func _request_current_stats() -> void:
	if _backend == null:
		backend_failed.emit("Steamworks user-stat API is unavailable; progression remains local")
		return
	if not _backend.has_method("requestCurrentStats"):
		# GodotSteam 4.12+ removed this legacy request because current-user stats
		# are synchronized during successful Steam initialization.
		_mark_user_stats_ready()
		return
	var waits_for_callback: bool = _backend.has_signal("current_stats_received")
	if waits_for_callback:
		var callback := Callable(self, "_on_current_stats_received")
		if not _backend.is_connected("current_stats_received", callback):
			_backend.connect("current_stats_received", callback)
	var result: Variant = _backend.call("requestCurrentStats")
	if result is bool and not bool(result):
		backend_failed.emit("Steamworks rejected the current-stat request; progression remains local")
		return
	# Steamworks SDK 1.61+ synchronizes at boot and GodotSteam may omit the
	# legacy callback. A successful request is then the readiness boundary.
	if not waits_for_callback:
		_mark_user_stats_ready()


func _on_current_stats_received(_game_id: Variant, result: Variant, _user_id: Variant) -> void:
	if not _stats_result_succeeded(result):
		backend_failed.emit("Steamworks current stats could not be received; progression remains local")
		return
	_mark_user_stats_ready()


func _mark_user_stats_ready() -> void:
	if user_stats_ready:
		return
	user_stats_ready = true
	_flush_pending_progress()
	backend_ready.emit()


func _flush_pending_progress() -> void:
	_stats_write_retry_pending = false
	for id: String in _unlocked:
		_submit_achievement(id)
	for id: String in _stats:
		_submit_stat(id, _stats[id])
	_store_stats()


static func _init_succeeded(result: Variant) -> bool:
	if result is bool:
		return result
	if result is int:
		return int(result) == 0
	if result is Dictionary:
		var data: Dictionary = result as Dictionary
		if data.has("success"):
			return bool(data.success)
		if data.has("status"):
			return int(data.status) == 0
		return false
	return false


static func _stats_result_succeeded(result: Variant) -> bool:
	if result is bool:
		return bool(result)
	if result is int:
		return int(result) == 1
	if result is Dictionary:
		var data: Dictionary = result as Dictionary
		if data.has("success"):
			return bool(data.success)
		if data.has("result"):
			return int(data.result) == 1
	return false


func _exit_tree() -> void:
	if available and _backend != null:
		if _backend.has_method("clearRichPresence"):
			_backend.call("clearRichPresence")
		if _backend.has_method("steamShutdown"):
			_backend.call("steamShutdown")
