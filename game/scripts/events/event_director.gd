class_name EventDirector
extends RefCounted

signal event_discovered(event_id: String, queued: bool)

const PENDING_LIMIT: int = 5
const RECENT_LIMIT: int = 5

var last_triggered_unix: Dictionary = {}
var recent_event_ids: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func discover_one(
	events: Array[Dictionary],
	state: PigState,
	unix_time: int,
	desktop_mode: bool = false,
	announce: bool = true
) -> Dictionary:
	var eligible: Array[Dictionary] = get_eligible(events, state, unix_time, desktop_mode)
	if eligible.is_empty():
		return {}
	var total_weight: float = 0.0
	var weights: Array[float] = []
	for event: Dictionary in eligible:
		var weight: float = calculate_weight(event, state, recent_event_ids)
		weights.append(weight)
		total_weight += weight
	var roll: float = _rng.randf_range(0.0, total_weight)
	var chosen: Dictionary = eligible[-1]
	for index: int in eligible.size():
		roll -= weights[index]
		if roll <= 0.0:
			chosen = eligible[index]
			break
	var chosen_id: String = str(chosen.id)
	last_triggered_unix[chosen_id] = unix_time
	recent_event_ids.append(chosen_id)
	while recent_event_ids.size() > RECENT_LIMIT:
		recent_event_ids.pop_front()
	var first_discovery: bool = not chosen_id in state.discovered_events
	if first_discovery:
		state.discovered_events.append(chosen_id)
	var queued: bool = false
	if not chosen_id in state.pending_events and not chosen_id in state.summarized_events:
		if state.pending_events.size() < PENDING_LIMIT:
			state.pending_events.append(chosen_id)
			queued = true
		else:
			state.summarized_events.append(chosen_id)
	var result: Dictionary = {"event": chosen, "first_discovery": first_discovery, "queued": queued}
	if announce:
		announce_discovery(result)
	return result


func announce_discovery(result: Dictionary) -> void:
	var event: Dictionary = result.get("event", {}) as Dictionary
	var event_id: String = str(event.get("id", ""))
	if not event_id.is_empty():
		event_discovered.emit(event_id, bool(result.get("queued", false)))


func get_eligible(events: Array[Dictionary], state: PigState, unix_time: int, desktop_mode: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var placed: Array = state.placed_furniture.values()
	var hour: int = GameClock.local_hour(unix_time)
	for event: Dictionary in events:
		var id: String = str(event.get("id", ""))
		if id.is_empty() or state.familiarity_level < int(event.get("min_level", 1)):
			continue
		if desktop_mode and not bool(event.get("desktop_allowed", false)):
			continue
		if state.active_seconds < float(event.get("min_active_seconds", 0.0)):
			continue
		if id in state.pending_events or id in state.summarized_events:
			continue
		if last_triggered_unix.has(id) and unix_time < int(last_triggered_unix[id]) + int(event.get("cooldown_seconds", 3600)):
			continue
		if not _contains_all(placed, event.get("required_furniture", []) as Array):
			continue
		if not _contains_all(state.seen_events, event.get("prerequisite_events", []) as Array):
			continue
		if not BehaviorDirector._matches_time(str(event.get("time", "any")), hour):
			continue
		if not _matches_state_ranges(event.get("state_ranges", {}) as Dictionary, state):
			continue
		result.append(event)
	return result


func resolve_branch(event: Dictionary, state: PigState, requested_id: String = "") -> Dictionary:
	var branches: Array = event.get("branches", []) as Array
	if branches.is_empty():
		return {"id": "default", "variant_keys": event.get("variants", []), "reward_bonus": {}}
	if not requested_id.is_empty():
		for value: Variant in branches:
			var requested: Dictionary = value as Dictionary
			if str(requested.get("id", "")) == requested_id:
				return requested
	for value: Variant in branches:
		var branch: Dictionary = value as Dictionary
		if _branch_matches(branch.get("conditions", {}) as Dictionary, state):
			return branch
	return branches[-1] as Dictionary


func mark_watched(event: Dictionary, state: PigState, unix_time: int, branch_id: String = "") -> Dictionary:
	var id: String = str(event.get("id", ""))
	last_triggered_unix[id] = maxi(int(last_triggered_unix.get(id, 0)), unix_time)
	state.pending_events.erase(id)
	state.summarized_events.erase(id)
	var first_watch: bool = not id in state.seen_events
	if first_watch:
		state.seen_events.append(id)
	var rewards: Dictionary = event.get("rewards", {}) as Dictionary
	var branch: Dictionary = resolve_branch(event, state, branch_id)
	var bonus: Dictionary = branch.get("reward_bonus", {}) as Dictionary
	var awarded_points: int = (int(rewards.get("points", 0)) + int(bonus.get("points", 0))) if first_watch else 0
	if awarded_points > 0:
		state.add_points(awarded_points)
	if first_watch:
		state.add_familiarity(int(rewards.get("familiarity", 10)) + int(bonus.get("familiarity", 0)))
		for expression_id: Variant in rewards.get("expressions", []):
			if state.unlock("expression", str(expression_id), unix_time):
				state.add_points(10)
	var unlocked_achievements: Array[String] = []
	if first_watch:
		for achievement_id: Variant in rewards.get("achievements", []):
			if state.unlock("achievement", str(achievement_id), unix_time):
				unlocked_achievements.append(str(achievement_id))
	return {
		"first_watch": first_watch,
		"points": awarded_points,
		"branch_id": str(branch.get("id", "default")),
		"achievements": unlocked_achievements,
	}


func to_dict() -> Dictionary:
	return {"last_triggered_unix": last_triggered_unix, "recent_event_ids": recent_event_ids}


func load_dict(data: Dictionary) -> void:
	last_triggered_unix = (data.get("last_triggered_unix", {}) as Dictionary).duplicate(true)
	recent_event_ids = PigState._to_strings(data.get("recent_event_ids", []))


func discard_future_timestamps(unix_time: int) -> void:
	var cutoff: int = maxi(unix_time, 0)
	for id: Variant in last_triggered_unix.keys():
		if int(last_triggered_unix[id]) > cutoff:
			last_triggered_unix.erase(id)
	while recent_event_ids.size() > RECENT_LIMIT:
		recent_event_ids.pop_front()


static func _contains_all(haystack: Array, needles: Array) -> bool:
	for item: Variant in needles:
		if not item in haystack:
			return false
	return true


static func calculate_weight(event: Dictionary, state: PigState, recent_ids: Array[String] = []) -> float:
	var id: String = str(event.get("id", ""))
	var weight: float = maxf(float(event.get("weight", 1.0)), 0.0)
	var unseen: bool = not id in state.discovered_events
	if unseen:
		weight *= maxf(float(event.get("unseen_multiplier", 4.0)), 0.0)
	weight *= _tendency_multiplier(event, state.tendency, unseen)
	if id in recent_ids:
		weight *= 0.18
	return weight


static func _tendency_multiplier(event: Dictionary, tendency: String, unseen: bool) -> float:
	var category: String = str(event.get("category", ""))
	var anchor: String = str(event.get("anchor", ""))
	match tendency:
		"rest": return 1.6 if category == "sleep" or anchor == "window" else 0.9
		"food": return 1.7 if category == "food" else 0.9
		"active": return 1.7 if category == "sport" else 0.9
		"explore": return 1.35 if unseen else 1.0
		_: return 1.0


static func _matches_state_ranges(ranges: Dictionary, state: PigState) -> bool:
	for key: String in ["satiety", "energy", "interest"]:
		var limits: Array = ranges.get(key, [0, 100]) as Array
		if limits.size() < 2:
			return false
		var value: float = float(state.get(key))
		if value < float(limits[0]) or value > float(limits[1]):
			return false
	return true


static func _branch_matches(conditions: Dictionary, state: PigState) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("satiety_max") and state.satiety > float(conditions.satiety_max):
		return false
	if conditions.has("satiety_min") and state.satiety < float(conditions.satiety_min):
		return false
	if conditions.has("energy_max") and state.energy > float(conditions.energy_max):
		return false
	if conditions.has("energy_min") and state.energy < float(conditions.energy_min):
		return false
	if conditions.has("interest_max") and state.interest > float(conditions.interest_max):
		return false
	if conditions.has("interest_min") and state.interest < float(conditions.interest_min):
		return false
	if conditions.has("tendency") and state.tendency != str(conditions.tendency):
		return false
	if conditions.has("required_furniture") and not _contains_all(state.placed_furniture.values(), conditions.required_furniture as Array):
		return false
	if conditions.has("seen_events_min") and state.seen_events.size() < int(conditions.seen_events_min):
		return false
	return true
