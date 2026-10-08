class_name PigPerformance
extends RefCounted

signal changed

var selected_face: String = "face_dot"
var active_id: String = ""
var elapsed_seconds: float = 0.0
var remaining_seconds: float = 0.0
var manual: bool = false
var _definition: Dictionary = {}
var _last_signature: String = ""
var _outfit_id: String = ""
var _auto_elapsed: float = 0.0


func start(id: String, library: PigPerformanceLibrary, outfit_id: String, explicit_request: bool = true) -> bool:
	var entry: Dictionary = library.item(id)
	var kind: String = library.kind_for(id)
	if entry.is_empty() or kind == "clips":
		return false
	if kind == "outfit_actions" and str(entry.get("outfit_id", "")) != outfit_id:
		return false
	if kind == "faces":
		selected_face = id
	active_id = id
	_definition = entry
	manual = explicit_request
	elapsed_seconds = 0.0
	remaining_seconds = float(entry.get("duration_seconds", 120.0))
	_last_signature = _signature(library)
	changed.emit()
	return true


func stop(reset_face: bool = false) -> void:
	var was_active: bool = not active_id.is_empty()
	active_id = ""
	_definition = {}
	elapsed_seconds = 0.0
	remaining_seconds = 0.0
	manual = false
	_last_signature = ""
	_auto_elapsed = 0.0
	if reset_face:
		selected_face = "face_dot"
	if was_active:
		changed.emit()


func snapshot(library: PigPerformanceLibrary) -> Dictionary:
	if active_id.is_empty():
		return {}
	var kind: String = library.kind_for(active_id)
	var face_id: String = selected_face
	var body_id: String = str(library.configuration.get("base", "body_base"))
	if kind in ["poses", "forms"]:
		body_id = str(_definition.clip_id)
	elif kind == "outfit_actions":
		body_id = str(library.item(str(_definition.pose_id)).get("clip_id", body_id))
		face_id = str(_definition.face_id)
	elif kind == "states":
		var phase: int = floori(elapsed_seconds / float((library.configuration.settings as Dictionary).phase_seconds))
		var faces: Array = _definition.face_ids as Array
		face_id = str(faces[phase % faces.size()])
		if _definition.has("form_id"):
			body_id = str(library.item(str(_definition.form_id)).get("clip_id", body_id))
		else:
			var poses: Array = _definition.pose_ids as Array
			body_id = str(library.item(str(poses[phase % poses.size()])).get("clip_id", body_id))
	return {"id":active_id, "body_id":body_id, "face_id":face_id, "manual":manual}


func advance(delta: float, library: PigPerformanceLibrary, outfit_id: String, proactive_allowed: bool, frequency: String, rng: RandomNumberGenerator, presentation_allowed: bool = false) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if outfit_id != _outfit_id:
		_outfit_id = outfit_id
		_auto_elapsed = 0.0
	if not active_id.is_empty():
		elapsed_seconds += delta
		remaining_seconds = maxf(remaining_seconds - delta, 0.0)
		if remaining_seconds <= 0.0:
			active_id = ""
			_definition = {}
			manual = false
			_auto_elapsed = 0.0
	var signature: String = _signature(library)
	if (proactive_allowed or presentation_allowed) and signature != _last_signature:
		_last_signature = signature
		changed.emit()
	if not proactive_allowed:
		_auto_elapsed = 0.0
	if not proactive_allowed or not active_id.is_empty() or frequency not in ["frequent", "normal", "rare"]:
		return
	var action: Dictionary = library.outfit_action(outfit_id)
	if action.is_empty():
		return
	_auto_elapsed += delta
	var interval: float = float((library.configuration.settings.auto_interval_seconds as Dictionary)[frequency])
	if _auto_elapsed < interval:
		return
	_auto_elapsed = 0.0
	if rng.randf() < float(action.chance):
		start(str(action.id), library, outfit_id, false)


func _signature(library: PigPerformanceLibrary) -> String:
	var value: Dictionary = snapshot(library)
	return "%s:%s:%s" % [value.get("id", ""), value.get("body_id", ""), value.get("face_id", "")]
