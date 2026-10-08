class_name ContentCatalog
extends RefCounted

const PATHS := {
	"behaviors": "res://game/data/catalog/behaviors.json",
	"furniture": "res://game/data/furniture/furniture.json",
	"snacks": "res://game/data/catalog/snacks.json",
	"outfits": "res://game/data/catalog/outfits.json",
	"expressions": "res://game/data/expressions/expressions.json",
	"events": "res://game/data/events/events.json",
	"achievements": "res://game/data/catalog/achievements.json",
	"life_plans": "res://game/data/catalog/life_plans.json",
	"personalities": "res://game/data/catalog/personalities.json",
}

var behaviors: Array[Dictionary] = []
var furniture: Array[Dictionary] = []
var snacks: Array[Dictionary] = []
var outfits: Array[Dictionary] = []
var expressions: Array[Dictionary] = []
var events: Array[Dictionary] = []
var achievements: Array[Dictionary] = []
var life_plans: Array[Dictionary] = []
var personalities: Array[Dictionary] = []
var performances := PigPerformanceLibrary.new()
var _by_type: Dictionary = {}


func load_all() -> Array[String]:
	behaviors = JsonStore.read_array(PATHS.behaviors)
	furniture = JsonStore.read_array(PATHS.furniture)
	snacks = JsonStore.read_array(PATHS.snacks)
	outfits = JsonStore.read_array(PATHS.outfits)
	expressions = JsonStore.read_array(PATHS.expressions)
	events = JsonStore.read_array(PATHS.events)
	achievements = JsonStore.read_array(PATHS.achievements)
	life_plans = JsonStore.read_array(PATHS.life_plans)
	personalities = JsonStore.read_array(PATHS.personalities)
	performances.load_all()
	_rebuild_index()
	return validate()


func apply_demo_profile() -> void:
	life_plans = ReleaseProfile.select(life_plans, ReleaseProfile.DEMO_LIFE_PLAN_IDS)
	furniture = ReleaseProfile.select(furniture, ReleaseProfile.DEMO_FURNITURE_IDS)
	snacks = ReleaseProfile.select(snacks, ReleaseProfile.DEMO_SNACK_IDS)
	outfits = ReleaseProfile.select(outfits, ReleaseProfile.DEMO_OUTFIT_IDS)
	expressions = ReleaseProfile.select(expressions, ReleaseProfile.DEMO_EXPRESSION_IDS)
	events = ReleaseProfile.select(events, ReleaseProfile.DEMO_EVENT_IDS)
	for event: Dictionary in events:
		# A 20–40 minute demo must be completable regardless of the player's real schedule.
		event["time"] = "any"
		event["state_ranges"] = {"satiety":[0,100], "energy":[0,100], "interest":[0,100]}
		if str(event.get("id", "")) == "event_alarm_victory":
			event["min_active_seconds"] = 20 * 60
		var rewards: Dictionary = (event.get("rewards", {}) as Dictionary).duplicate(true)
		rewards["achievements"] = []
		event["rewards"] = rewards
	achievements = []
	_rebuild_index()


func get_item(type: String, id: String) -> Dictionary:
	var index: Dictionary = _by_type.get(type, {})
	return index.get(id, {}) as Dictionary


func has_item(type: String, id: String) -> bool:
	var index: Dictionary = _by_type.get(type, {})
	return index.has(id)


func validate() -> Array[String]:
	var errors: Array[String] = []
	var expected := {
		"furniture": 32,
		"snacks": 10,
		"outfits": 12,
		"expressions": 48,
		"events": 24,
		"achievements": 24,
		"life_plans": 6,
		"personalities": 5,
	}
	for type: String in expected:
		var items: Array = get_all(type)
		if items.size() != int(expected[type]):
			errors.append("%s requires %d items, found %d" % [type, expected[type], items.size()])
	var all_ids: Dictionary = {}
	for type: String in _by_type:
		var index: Dictionary = _by_type[type]
		for id: String in index:
			if all_ids.has(id):
				errors.append("Duplicate permanent id across catalogs: %s" % id)
			all_ids[id] = type
	for item: Dictionary in furniture:
		var behavior_id: String = str(item.get("behavior_id", ""))
		var area_id: String = str(item.get("area", ""))
		var area_unlock_level: int = ReleaseProfile.area_unlock_level(area_id)
		if area_unlock_level > 0 and int(item.get("min_level", 1)) < area_unlock_level:
			errors.append(
				"Furniture %s unlocks before its %s area at familiarity level %d"
				% [item.get("id", "?"), area_id, area_unlock_level]
			)
		if not behavior_id.is_empty() and not has_item("behaviors", behavior_id):
			errors.append("Furniture %s references missing behavior %s" % [item.get("id", "?"), behavior_id])
	var level_eight_combination_events: int = 0
	var camera_shake_steps: int = 0
	for item: Dictionary in events:
		var required_furniture: Array = item.get("required_furniture", []) as Array
		var distinct_required: Dictionary = {}
		var includes_level_eight_furniture: bool = false
		for furniture_id: Variant in required_furniture:
			if not has_item("furniture", str(furniture_id)):
				errors.append("Event %s references missing furniture %s" % [item.get("id", "?"), furniture_id])
			else:
				distinct_required[str(furniture_id)] = true
				if int(get_item("furniture", str(furniture_id)).get("min_level", 1)) == 8:
					includes_level_eight_furniture = true
		for expression_id: Variant in item.get("rewards", {}).get("expressions", []):
			if not has_item("expressions", str(expression_id)):
				errors.append("Event %s references missing expression %s" % [item.get("id", "?"), expression_id])
		for step_value: Variant in item.get("steps", []):
			if not step_value is Dictionary:
				continue
			var camera_shake_value: Variant = (step_value as Dictionary).get("camera_shake", false)
			if not camera_shake_value is bool:
				errors.append("Event %s camera_shake flags must be boolean" % item.get("id", "?"))
			elif bool(camera_shake_value):
				camera_shake_steps += 1
		if int(item.get("min_level", 1)) == 8 and distinct_required.size() >= 2 and includes_level_eight_furniture:
			level_eight_combination_events += 1
	if level_eight_combination_events == 0:
		errors.append("Familiarity level 8 requires at least one multi-furniture combination event")
	if camera_shake_steps == 0:
		errors.append("Event content requires at least one data-driven camera-shake step")
	var functional_count: int = 0
	for item: Dictionary in furniture:
		if not str(item.get("behavior_id", "")).is_empty():
			functional_count += 1
	if functional_count < 16:
		errors.append("At least 16 furniture items must add behaviors, found %d" % functional_count)
	errors.append_array(LifePlanRules.validate_content(life_plans, behaviors, furniture, all_ids))
	errors.append_array(PersonalityRules.validate_content(personalities, expressions))
	errors.append_array(performances.validate(outfits))
	for plan_id: String in ReleaseProfile.DEMO_LIFE_PLAN_IDS:
		if not has_item("life_plans", plan_id):
			errors.append("Demo life plan %s is missing" % plan_id)
		else:
			for furniture_id: String in get_item("life_plans", plan_id).get("inspiration_furniture", []) as Array:
				if furniture_id not in ReleaseProfile.DEMO_FURNITURE_IDS:
					errors.append("Demo life plan inspiration must remain available in the Demo")
	return errors


func get_all(type: String) -> Array:
	match type:
		"behaviors": return behaviors
		"furniture": return furniture
		"snacks": return snacks
		"outfits": return outfits
		"expressions": return expressions
		"events": return events
		"achievements": return achievements
		"life_plans": return life_plans
		"personalities": return personalities
		_: return []


func _index(items: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for item: Dictionary in items:
		var id: String = str(item.get("id", ""))
		if id.is_empty():
			continue
		result[id] = item
	return result


func _rebuild_index() -> void:
	_by_type = {
		"behaviors": _index(behaviors),
		"furniture": _index(furniture),
		"snacks": _index(snacks),
		"outfits": _index(outfits),
		"expressions": _index(expressions),
		"events": _index(events),
		"achievements": _index(achievements),
		"life_plans": _index(life_plans),
		"personalities": _index(personalities),
	}
