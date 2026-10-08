class_name BehaviorDirector
extends RefCounted

const RECENT_LIMIT: int = 5

var recent_ids: Array[String] = []
var cooldown_until: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func choose(
	behaviors: Array[Dictionary],
	state: PigState,
	unix_time: int,
	desktop_mode: bool = false,
	focus_mode: bool = false
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	var hour: int = GameClock.local_hour(unix_time)
	var placed: Array = state.placed_furniture.values()
	for behavior: Dictionary in behaviors:
		var id: String = str(behavior.get("id", ""))
		if id.is_empty() or (not recent_ids.is_empty() and recent_ids[-1] == id):
			continue
		if unix_time < int(cooldown_until.get(id, 0)):
			continue
		if desktop_mode and not bool(behavior.get("desktop_allowed", false)):
			continue
		var furniture_id: String = str(behavior.get("required_furniture", ""))
		if not furniture_id.is_empty() and not furniture_id in placed:
			continue
		if not _matches_time(str(behavior.get("time", "any")), hour):
			continue
		var tags: Array = behavior.get("tags", []) as Array
		if desktop_mode and focus_mode and not "quiet" in tags:
			continue
		var weight: float = maxf(float(behavior.get("weight", 1.0)), 0.0)
		weight *= _state_multiplier(tags, state)
		weight *= _tendency_multiplier(tags, state.tendency)
		if id in recent_ids:
			weight *= 0.25
		if weight <= 0.0:
			continue
		candidates.append(behavior)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return {}
	var roll: float = _rng.randf_range(0.0, total_weight)
	for index: int in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates[-1]


func record_completed(behavior: Dictionary, unix_time: int) -> void:
	var id: String = str(behavior.get("id", ""))
	if id.is_empty():
		return
	recent_ids.append(id)
	while recent_ids.size() > RECENT_LIMIT:
		recent_ids.pop_front()
	cooldown_until[id] = unix_time + int(behavior.get("cooldown_seconds", 60))


func to_dict() -> Dictionary:
	return {"recent_ids": recent_ids, "cooldown_until": cooldown_until}


func load_dict(data: Dictionary) -> void:
	recent_ids = PigState._to_strings(data.get("recent_ids", []))
	cooldown_until = (data.get("cooldown_until", {}) as Dictionary).duplicate(true)


func discard_future_timestamps(unix_time: int) -> void:
	var cutoff: int = maxi(unix_time, 0)
	for id: Variant in cooldown_until.keys():
		if int(cooldown_until[id]) > cutoff:
			cooldown_until.erase(id)


static func _matches_time(time_rule: String, hour: int) -> bool:
	match time_rule:
		"morning": return hour >= 5 and hour < 11
		"day": return hour >= 8 and hour < 18
		"evening": return hour >= 17 and hour < 23
		"night": return hour >= 21 or hour < 6
		_: return true


static func _state_multiplier(tags: Array, state: PigState) -> float:
	var result: float = 1.0
	if "sleep" in tags:
		result *= lerpf(0.45, 2.5, 1.0 - state.energy / 100.0)
	if "food" in tags:
		result *= lerpf(0.5, 2.6, 1.0 - state.satiety / 100.0)
	if "active" in tags:
		result *= lerpf(0.45, 1.8, state.energy / 100.0)
	if "curious" in tags:
		result *= lerpf(0.55, 1.8, state.interest / 100.0)
	if "idle" in tags and state.interest < 30.0:
		result *= 1.8
	return result


static func _tendency_multiplier(tags: Array, tendency: String) -> float:
	match tendency:
		"rest": return 1.65 if ("sleep" in tags or "quiet" in tags) else 0.85
		"food": return 1.75 if "food" in tags else 0.9
		"active": return 1.75 if "active" in tags else 0.9
		"explore": return 1.0
		_: return 1.0
