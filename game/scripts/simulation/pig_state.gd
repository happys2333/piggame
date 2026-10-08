class_name PigState
extends RefCounted

signal changed
signal familiarity_level_changed(level: int)
signal content_unlocked(type: String, id: String)

# Levels 2–5 deliberately land inside the final ten minutes of the 30-minute
# onboarding: desktop mode first, then the snack/activity areas and tendency.
# The longer tail keeps the theme ending in the 8–12 active-hour design target.
const FAMILIARITY_THRESHOLDS: Array[int] = [0, 70, 78, 86, 95, 200, 400, 750, 1250, 2000]

var name: String = ""
var personality_id: String = ""
var satiety: float = 72.0
var energy: float = 68.0
var interest: float = 64.0
var familiarity_xp: int = 0
var familiarity_level: int = 1
var active_seconds: float = 0.0
var daily_points: int = 70
var tendency: String = "explore"
var current_outfit: String = ""
var current_room_palette: String = "rose"
var current_photo_frame: String = "plain"
var owned_furniture: Array[String] = ["furn_bed_basic"]
var placed_furniture: Dictionary = {"sleep_1": "furn_bed_basic"}
var owned_snacks: Array[String] = ["snack_apple"]
var owned_outfits: Array[String] = []
var unlocked_expressions: Array[String] = []
var expression_unlock_dates: Dictionary = {}
var favorite_desktop_expression: String = ""
var discovered_events: Array[String] = []
var seen_events: Array[String] = []
var pending_events: Array[String] = []
var summarized_events: Array[String] = []
var life_photos: Dictionary = {}
var unlocked_achievements: Array[String] = []
var ending_unlocked: bool = false
var ending_seen: bool = false
var demo_completion_seen: bool = false
var tutorial_step: int = 0
var tutorial_skipped: bool = false
var interaction_counts: Dictionary = {}
var active_life_plan: String = ""
var life_plan_progress: Dictionary = {}
var life_plan_entries: Array[String] = []


func normalize() -> void:
	satiety = clampf(satiety, 0.0, 100.0)
	energy = clampf(energy, 0.0, 100.0)
	interest = clampf(interest, 0.0, 100.0)
	familiarity_xp = maxi(familiarity_xp, 0)
	active_seconds = maxf(active_seconds, 0.0)
	daily_points = maxi(daily_points, 0)
	var derived_level: int = 1
	for index: int in FAMILIARITY_THRESHOLDS.size():
		if familiarity_xp >= FAMILIARITY_THRESHOLDS[index]:
			derived_level = index + 1
	familiarity_level = maxi(familiarity_level, clampi(derived_level, 1, 10))
	changed.emit()


func add_familiarity(amount: int) -> bool:
	if amount <= 0 or familiarity_level >= 10:
		return false
	var old_level: int = familiarity_level
	familiarity_xp += amount
	normalize()
	if familiarity_level > old_level:
		familiarity_level_changed.emit(familiarity_level)
		return true
	return false


func add_points(amount: int) -> void:
	daily_points = maxi(daily_points + amount, 0)
	changed.emit()


func spend_points(amount: int) -> bool:
	if amount < 0 or daily_points < amount:
		return false
	daily_points -= amount
	changed.emit()
	return true


func record_daily_interaction(kind: String, date: String) -> int:
	var key: String = "%s:%s" % [kind, date]
	var count: int = int(interaction_counts.get(key, 0)) + 1
	interaction_counts[key] = count
	return count


func unlock(type: String, id: String, unix_time: int = 0) -> bool:
	var collection: Array[String]
	match type:
		"furniture": collection = owned_furniture
		"snack": collection = owned_snacks
		"outfit": collection = owned_outfits
		"expression": collection = unlocked_expressions
		"achievement": collection = unlocked_achievements
		_: return false
	if id in collection:
		return false
	collection.append(id)
	if type == "expression":
		expression_unlock_dates[id] = unix_time if unix_time > 0 else GameClock.now_unix()
	content_unlocked.emit(type, id)
	changed.emit()
	return true


func status_key() -> String:
	if energy < 24.0:
		return "STATUS_SLEEPY"
	if satiety < 28.0:
		return "STATUS_HUNGRY"
	if interest < 25.0:
		return "STATUS_BORED"
	if energy > 78.0 and interest > 60.0:
		return "STATUS_ENERGETIC"
	return "STATUS_CONTENT"


func to_dict() -> Dictionary:
	return {
		"name": name,
		"personality_id": personality_id,
		"satiety": satiety,
		"energy": energy,
		"interest": interest,
		"familiarity_xp": familiarity_xp,
		"familiarity_level": familiarity_level,
		"active_seconds": active_seconds,
		"daily_points": daily_points,
		"tendency": tendency,
		"current_outfit": current_outfit,
		"current_room_palette": current_room_palette,
		"current_photo_frame": current_photo_frame,
		"owned_furniture": owned_furniture,
		"placed_furniture": placed_furniture,
		"owned_snacks": owned_snacks,
		"owned_outfits": owned_outfits,
		"unlocked_expressions": unlocked_expressions,
		"expression_unlock_dates": expression_unlock_dates,
		"favorite_desktop_expression": favorite_desktop_expression,
		"discovered_events": discovered_events,
		"seen_events": seen_events,
		"pending_events": pending_events,
		"summarized_events": summarized_events,
		"life_photos": life_photos,
		"unlocked_achievements": unlocked_achievements,
		"ending_unlocked": ending_unlocked,
		"ending_seen": ending_seen,
		"demo_completion_seen": demo_completion_seen,
		"tutorial_step": tutorial_step,
		"tutorial_skipped": tutorial_skipped,
		"interaction_counts": interaction_counts,
		"active_life_plan": active_life_plan,
		"life_plan_progress": life_plan_progress,
		"life_plan_entries": life_plan_entries,
	}


func load_dict(data: Dictionary) -> void:
	name = str(data.get("name", name))
	personality_id = str(data.get("personality_id", ""))
	satiety = float(data.get("satiety", satiety))
	energy = float(data.get("energy", energy))
	interest = float(data.get("interest", interest))
	familiarity_xp = int(data.get("familiarity_xp", familiarity_xp))
	familiarity_level = int(data.get("familiarity_level", familiarity_level))
	active_seconds = float(data.get("active_seconds", active_seconds))
	daily_points = int(data.get("daily_points", daily_points))
	tendency = str(data.get("tendency", tendency))
	current_outfit = str(data.get("current_outfit", current_outfit))
	current_room_palette = str(data.get("current_room_palette", current_room_palette))
	current_photo_frame = str(data.get("current_photo_frame", current_photo_frame))
	owned_furniture = _to_strings(data.get("owned_furniture", owned_furniture))
	placed_furniture = (data.get("placed_furniture", placed_furniture) as Dictionary).duplicate(true)
	owned_snacks = _to_strings(data.get("owned_snacks", owned_snacks))
	owned_outfits = _to_strings(data.get("owned_outfits", owned_outfits))
	unlocked_expressions = _to_strings(data.get("unlocked_expressions", unlocked_expressions))
	expression_unlock_dates = (data.get("expression_unlock_dates", {}) as Dictionary).duplicate(true)
	favorite_desktop_expression = str(data.get("favorite_desktop_expression", favorite_desktop_expression))
	discovered_events = _to_strings(data.get("discovered_events", discovered_events))
	seen_events = _to_strings(data.get("seen_events", seen_events))
	pending_events = _to_strings(data.get("pending_events", pending_events))
	summarized_events = _to_strings(data.get("summarized_events", summarized_events))
	life_photos = (data.get("life_photos", {}) as Dictionary).duplicate(true)
	unlocked_achievements = _to_strings(data.get("unlocked_achievements", unlocked_achievements))
	ending_unlocked = bool(data.get("ending_unlocked", ending_unlocked))
	ending_seen = bool(data.get("ending_seen", ending_seen))
	demo_completion_seen = bool(data.get("demo_completion_seen", demo_completion_seen))
	tutorial_step = int(data.get("tutorial_step", tutorial_step))
	tutorial_skipped = bool(data.get("tutorial_skipped", tutorial_skipped))
	interaction_counts = (data.get("interaction_counts", {}) as Dictionary).duplicate(true)
	active_life_plan = str(data.get("active_life_plan", ""))
	life_plan_progress = (data.get("life_plan_progress", {}) as Dictionary).duplicate(true)
	life_plan_entries = _to_strings(data.get("life_plan_entries", []))
	normalize()


static func _to_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value as Array:
			result.append(str(item))
	return result
