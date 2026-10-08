class_name LifePlanRules
extends RefCounted

const FURNITURE_RATE_BONUS: float = 0.2
const MAX_INSPIRATION_FURNITURE: int = 2
const BEHAVIOR_INSPIRATION_SECONDS: float = 10.0
const MAX_PLAN_SECONDS: float = 86400.0


static func maximum_seconds(plan: Dictionary) -> float:
	var entries: Array = plan.get("entries", []) as Array
	return float((entries.back() as Dictionary).get("seconds", 0.0)) if not entries.is_empty() else 0.0


static func room_rate(plan: Dictionary, state: PigState) -> float:
	var placed: Array = state.placed_furniture.values()
	var matching: int = 0
	for furniture_id: String in plan.get("inspiration_furniture", []) as Array:
		if furniture_id in placed:
			matching += 1
	return 1.0 + float(mini(matching, MAX_INSPIRATION_FURNITURE)) * FURNITURE_RATE_BONUS


static func behavior_inspiration(plan: Dictionary, behavior: Dictionary) -> float:
	for tag: String in plan.get("behavior_tags", []) as Array:
		if tag in (behavior.get("tags", []) as Array):
			return BEHAVIOR_INSPIRATION_SECONDS
	return 0.0


static func earned_entries(plan: Dictionary, state: PigState) -> int:
	var count: int = 0
	for entry: Dictionary in plan.get("entries", []) as Array:
		if str(entry.id) in state.life_plan_entries:
			count += 1
	return count


static func is_complete(plan: Dictionary, state: PigState) -> bool:
	var entries: Array = plan.get("entries", []) as Array
	return not entries.is_empty() and earned_entries(plan, state) == entries.size()


static func preview_advance(plan: Dictionary, state: PigState, seconds: float, use_room_rate: bool = true) -> Dictionary:
	if plan.is_empty() or not is_finite(seconds) or seconds <= 0.0 or state.familiarity_level < int(plan.get("min_level", 1)):
		return {}
	var id: String = str(plan.id)
	var before: float = float(state.life_plan_progress.get(id, 0.0))
	var rate: float = room_rate(plan, state) if use_room_rate else 1.0
	var progress: float = minf(before + seconds * rate, maximum_seconds(plan))
	var new_entries: Array[String] = []
	for entry: Dictionary in plan.get("entries", []) as Array:
		if progress >= float(entry.seconds) and str(entry.id) not in state.life_plan_entries:
			new_entries.append(str(entry.id))
	if progress <= before and new_entries.is_empty():
		return {}
	return {"id":id, "progress":progress, "new_entries":new_entries}


static func apply_advance(update: Dictionary, state: PigState) -> void:
	if update.is_empty():
		return
	state.life_plan_progress[str(update.id)] = float(update.progress)
	for entry_id: String in update.new_entries as Array:
		if entry_id not in state.life_plan_entries:
			state.life_plan_entries.append(entry_id)


static func validate_content(plans: Array[Dictionary], behaviors: Array[Dictionary], furniture: Array[Dictionary], known_ids: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var animations: Array[String] = []
	var tags: Array[String] = []
	var furniture_ids: Array[String] = []
	var entry_ids: Dictionary = known_ids.duplicate()
	for behavior: Dictionary in behaviors:
		animations.append(str(behavior.get("animation", "")))
		for tag: String in behavior.get("tags", []) as Array:
			if tag not in tags:
				tags.append(tag)
	for item: Dictionary in furniture:
		furniture_ids.append(str(item.id))
	for plan: Dictionary in plans:
		var label: String = str(plan.get("id", "?"))
		if not _integer_in_range(plan.get("min_level", null), 2.0, 10.0):
			errors.append("Life plan %s needs a familiarity level from 2 to 10" % label)
		if plan.get("animation", "") not in animations:
			errors.append("Life plan %s references an unknown animation" % label)
		for field: String in ["name_key", "description_key"]:
			if not plan.get(field, null) is String or str(plan.get(field, "")).is_empty():
				errors.append("Life plan %s needs %s" % [label, field])
		for field: String in ["behavior_tags", "inspiration_furniture"]:
			var allowed: Array[String] = tags if field == "behavior_tags" else furniture_ids
			var values: Variant = plan.get(field, null)
			if not _unique_strings(values):
				errors.append("Life plan %s needs unique non-empty %s" % [label, field])
			else:
				for value: String in values as Array:
					if value not in allowed:
						errors.append("Life plan %s references unknown %s %s" % [label, field, value])
		var entries_value: Variant = plan.get("entries", null)
		if not entries_value is Array or (entries_value as Array).size() != 3:
			errors.append("Life plan %s requires three permanent diary entries" % label)
			continue
		var previous_seconds: float = 0.0
		for entry_value: Variant in entries_value as Array:
			if not entry_value is Dictionary:
				errors.append("Life plan %s diary entries must be objects" % label)
				continue
			var entry: Dictionary = entry_value as Dictionary
			for field: String in ["id", "title_key", "text_key"]:
				if not entry.get(field, null) is String or str(entry.get(field, "")).is_empty():
					errors.append("Life plan %s diary entry needs %s" % [label, field])
			var entry_id: String = str(entry.get("id", ""))
			if entry_ids.has(entry_id):
				errors.append("Duplicate life plan diary entry %s" % entry_id)
			entry_ids[entry_id] = true
			var seconds: Variant = entry.get("seconds", null)
			if not _integer_in_range(seconds, 1.0, MAX_PLAN_SECONDS) or float(seconds) <= previous_seconds:
				errors.append("Life plan %s diary thresholds must strictly increase within one day" % label)
			else:
				previous_seconds = float(seconds)
	return errors


static func _integer_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _unique_strings(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	var seen: Dictionary = {}
	for item: Variant in value as Array:
		if not item is String or str(item).is_empty() or seen.has(item):
			return false
		seen[item] = true
	return true
