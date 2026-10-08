class_name PigPerformanceLibrary
extends RefCounted

const PATH: String = "res://game/data/catalog/pig_performances.json"
const COUNTS := {"faces":9, "clips":12, "poses":9, "states":6, "forms":2, "outfit_actions":12}

var configuration: Dictionary = {}
var _by_id: Dictionary = {}
var _kinds: Dictionary = {}
var _outfit_actions: Dictionary = {}


func load_all() -> void:
	configuration = JsonStore.read_object(PATH)
	_by_id.clear()
	_kinds.clear()
	_outfit_actions.clear()
	for kind: String in COUNTS:
		for item: Dictionary in entries(kind):
			_by_id[str(item.get("id", ""))] = item
			_kinds[str(item.get("id", ""))] = kind
			if kind == "outfit_actions":
				_outfit_actions[str(item.get("outfit_id", ""))] = item


func entries(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var items: Variant = configuration.get(kind, [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func item(id: String) -> Dictionary:
	return (_by_id.get(id, {}) as Dictionary).duplicate(true)


func kind_for(id: String) -> String:
	return str(_kinds.get(id, ""))


func outfit_action(outfit_id: String) -> Dictionary:
	return (_outfit_actions.get(outfit_id, {}) as Dictionary).duplicate(true)


func validate(outfits: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var seen: Array[String] = []
	for kind: String in COUNTS:
		var items: Array[Dictionary] = entries(kind)
		if items.size() != int(COUNTS[kind]):
			errors.append("Performance %s requires %d entries" % [kind, COUNTS[kind]])
		for entry: Dictionary in items:
			var id: String = str(entry.get("id", ""))
			if id.is_empty() or id in seen:
				errors.append("Duplicate/empty performance ID: %s" % id)
			seen.append(id)
			if kind not in ["clips", "outfit_actions"] and str(entry.get("name_key", "")).is_empty():
				errors.append("Performance %s needs a localized name" % id)
			if kind in ["poses", "forms"] and kind_for(str(entry.get("clip_id", ""))) != "clips":
				errors.append("Performance %s has an unknown clip" % id)
			if kind in ["poses", "forms", "states", "outfit_actions"]:
				var seconds: Variant = entry.get("duration_seconds", 0)
				if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or float(seconds) < 1.0 or float(seconds) > 120.0:
					errors.append("Performance %s duration must be 1..120 seconds" % id)
			if kind == "clips":
				var snouts: Variant = entry.get("snouts", null)
				if not snouts is Array or (snouts as Array).size() != 4:
					errors.append("Performance %s needs four head anchors" % id)
				else:
					for anchor: Variant in snouts as Array:
						if not anchor is Array or (anchor as Array).size() != 2:
							errors.append("Performance %s has an invalid head anchor" % id)
						else:
							for coordinate: Variant in anchor as Array:
								if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate) < 0.0 or float(coordinate) > 256.0:
									errors.append("Performance %s head anchors must stay in the sprite" % id)
			if kind == "states":
				if str(entry.get("line_key", "")).is_empty():
					errors.append("Performance %s needs a localized line" % id)
				if not entry.get("face_ids", null) is Array or not entry.get("pose_ids", []) is Array:
					errors.append("Performance %s requires array sequences" % id)
					continue
				var face_ids: Array = entry.get("face_ids", []) as Array
				if face_ids.is_empty():
					errors.append("Performance %s needs expressions" % id)
				for face_id: Variant in face_ids:
					if kind_for(str(face_id)) != "faces":
						errors.append("Performance %s has an unknown face" % id)
				var form_id: String = str(entry.get("form_id", ""))
				if not form_id.is_empty() and kind_for(form_id) != "forms":
					errors.append("Performance %s has an unknown form" % id)
				var pose_ids: Array = entry.get("pose_ids", []) as Array
				if form_id.is_empty() and pose_ids.is_empty():
					errors.append("Performance %s needs poses or a form" % id)
				for pose_id: Variant in pose_ids:
					if kind_for(str(pose_id)) != "poses":
						errors.append("Performance %s has an unknown pose" % id)
			if kind == "outfit_actions":
				var outfit_id: String = str(entry.get("outfit_id", ""))
				if not outfits.any(func(outfit: Dictionary) -> bool: return str(outfit.id) == outfit_id) or kind_for(str(entry.get("pose_id", ""))) != "poses" or kind_for(str(entry.get("face_id", ""))) != "faces":
					errors.append("Performance %s has an invalid outfit combination" % id)
				var chance: Variant = entry.get("chance", 0)
				if not (chance is int or chance is float) or not is_finite(float(chance)) or float(chance) <= 0.0 or float(chance) > 1.0:
					errors.append("Performance %s chance must be in (0,1]" % id)
	if kind_for(str(configuration.get("base", ""))) != "clips":
		errors.append("Performance library needs one shared base clip")
	var settings_value: Variant = configuration.get("settings", null)
	if not settings_value is Dictionary:
		errors.append("Performance settings must be an object")
	else:
		var settings: Dictionary = settings_value as Dictionary
		var phase: Variant = settings.get("phase_seconds", null)
		if settings.size() != 2 or not (phase is int or phase is float) or float(phase) != 8.0:
			errors.append("Performance phase interval must remain eight seconds")
		var intervals_value: Variant = settings.get("auto_interval_seconds", null)
		if not intervals_value is Dictionary:
			errors.append("Performance auto intervals must be an object")
		else:
			var intervals: Dictionary = intervals_value as Dictionary
			if intervals.size() != 3:
				errors.append("Performance auto intervals require three frequencies")
			for frequency: String in ["frequent", "normal", "rare"]:
				var interval: Variant = intervals.get(frequency, null)
				var expected: float = {"frequent":60.0, "normal":120.0, "rare":240.0}[frequency]
				if not (interval is int or interval is float) or float(interval) != expected:
					errors.append("Performance %s interval must retain its low-interruption default" % frequency)
	return errors
