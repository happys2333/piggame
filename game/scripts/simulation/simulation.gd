class_name Simulation
extends RefCounted

signal behavior_started(behavior: Dictionary)
signal behavior_completed(behavior: Dictionary, points: int)

const SLEEP_ENERGY_GAIN: float = 0.18
const FOOD_SATIETY_GAIN: float = 0.10
const BASIC_FOOD_SATIETY_GAIN: float = 0.35
const ACTIVE_ENERGY_COST: float = 0.15
const ACTIVE_INTEREST_GAIN: float = 0.065
const CURIOUS_INTEREST_GAIN: float = 0.0325

var current_behavior: Dictionary = {}
var remaining_seconds: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func advance(
	delta: float,
	state: PigState,
	behaviors: Array[Dictionary],
	director: BehaviorDirector,
	unix_time: int,
	desktop_mode: bool,
	focus_mode: bool
) -> void:
	var time_left: float = maxf(delta, 0.0)
	var safety: int = 0
	while time_left > 0.0 and safety < 8:
		safety += 1
		if current_behavior.is_empty():
			current_behavior = director.choose(behaviors, state, unix_time, desktop_mode, focus_mode)
			if current_behavior.is_empty():
				return
			remaining_seconds = float(current_behavior.get("duration_seconds", 20.0))
			behavior_started.emit(current_behavior)
		var consumed: float = minf(time_left, remaining_seconds)
		remaining_seconds -= consumed
		time_left -= consumed
		_apply_passive_state(state, consumed)
		if remaining_seconds <= 0.0:
			_complete_current(state, director, unix_time)


func apply_offline(state: PigState, settlement: Dictionary) -> Dictionary:
	var elapsed: int = int(settlement.get("elapsed_seconds", 0))
	if elapsed <= 0:
		return settlement
	state.add_points(int(settlement.get("points", 0)))
	var hours: float = float(elapsed) / 3600.0
	state.satiety = maxf(35.0, state.satiety - hours * 3.2)
	state.energy = clampf(state.energy + hours * 2.5, 35.0, 92.0)
	state.interest = clampf(state.interest + hours * 1.4, 30.0, 90.0)
	state.add_familiarity(mini(roundi(hours * 2.0), 20))
	state.normalize()
	return settlement


func to_dict() -> Dictionary:
	return {"current_behavior_id": current_behavior.get("id", ""), "remaining_seconds": remaining_seconds}


func load_dict(data: Dictionary, catalog: ContentCatalog) -> void:
	var id: String = str(data.get("current_behavior_id", ""))
	current_behavior = catalog.get_item("behaviors", id) if not id.is_empty() else {}
	remaining_seconds = maxf(float(data.get("remaining_seconds", 0.0)), 0.0) if not current_behavior.is_empty() else 0.0


func invite_behavior(behavior: Dictionary, announce: bool = true) -> bool:
	if behavior.is_empty():
		return false
	current_behavior = behavior
	remaining_seconds = maxf(float(behavior.get("duration_seconds", 20.0)), 1.0)
	if announce:
		behavior_started.emit(current_behavior)
	return true


func announce_current_behavior() -> void:
	if not current_behavior.is_empty():
		behavior_started.emit(current_behavior)


func _complete_current(state: PigState, director: BehaviorDirector, unix_time: int) -> void:
	var behavior: Dictionary = current_behavior
	var tags: Array = behavior.get("tags", []) as Array
	if "sleep" in tags:
		state.energy = minf(state.energy + SLEEP_ENERGY_GAIN, 100.0)
	if "food" in tags:
		var satiety_gain: float = BASIC_FOOD_SATIETY_GAIN if str(behavior.get("id", "")) == "behavior_seek_food" else FOOD_SATIETY_GAIN
		state.satiety = minf(state.satiety + satiety_gain, 100.0)
	if "active" in tags:
		state.energy = maxf(state.energy - ACTIVE_ENERGY_COST, 0.0)
		state.interest = minf(state.interest + ACTIVE_INTEREST_GAIN, 100.0)
	if "curious" in tags:
		state.interest = minf(state.interest + CURIOUS_INTEREST_GAIN, 100.0)
	var points: int = _rng.randi_range(int(behavior.get("points_min", 2)), int(behavior.get("points_max", 5)))
	state.add_points(points)
	# Commit the behavior state machine and cooldown before familiarity signals.
	# A level-up observer may save synchronously, so it must never persist a
	# zero-duration behavior that can be completed again after reload.
	director.record_completed(behavior, unix_time)
	current_behavior = {}
	remaining_seconds = 0.0
	state.add_familiarity(1)
	behavior_completed.emit(behavior, points)


static func _apply_passive_state(state: PigState, seconds: float) -> void:
	state.active_seconds += seconds
	state.satiety = maxf(state.satiety - seconds * 0.0022, 0.0)
	state.energy = maxf(state.energy - seconds * 0.0012, 0.0)
	state.interest = maxf(state.interest - seconds * 0.0010, 0.0)
