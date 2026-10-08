class_name ReleaseProfile
extends RefCounted

const DEMO_FURNITURE_IDS: Array[String] = [
	"furn_bed_basic", "furn_pillow_cloud", "furn_nightlight_moon",
	"furn_blanket_roll", "furn_bookshelf_low", "furn_clock_sleepy",
]
const DEMO_SNACK_IDS: Array[String] = ["snack_apple", "snack_berry_milk", "snack_cloud_bun"]
const DEMO_OUTFIT_IDS: Array[String] = ["outfit_berry_beret", "outfit_round_glasses"]
const DEMO_EXPRESSION_IDS: Array[String] = [
	"expr_happy_soft", "expr_shocked_new_home", "expr_sleepy_pillow", "expr_hungry_drool",
	"expr_sleepy_dream", "expr_happy_relaxed", "expr_sleepy_alarm", "expr_wronged_alarm",
]
const DEMO_EVENT_IDS: Array[String] = [
	"event_move_in", "event_pillow_migration", "event_dream_meeting", "event_alarm_victory",
]
const AREA_UNLOCK_LEVELS := {
	"sleep": 1,
	"snack": 3,
	"activity": 4,
	"window": 6,
}
const DEMO_AREAS: Array[String] = ["sleep"]
const DEMO_LIFE_PLAN_IDS: Array[String] = ["plan_pillow_notes"]
const DEMO_DESKTOP_DOCKS: Array[String] = ["bottom", "left"]
const FULL_DESKTOP_DOCKS: Array[String] = ["bottom", "left", "right"]
const FULL_SAVE_ROOT: String = "piggy_did_nothing_today"
const DEMO_SAVE_ROOT: String = "piggy_did_nothing_today_demo"
# The user has frozen background music and sound-effect work until dedicated
# assets are supplied. Keep every development build silent even if placeholder
# files remain in the manifest for routing and final-asset validation.
const AUDIO_PLAYBACK_ENABLED: bool = false


static func is_demo() -> bool:
	return OS.has_feature("demo")


static func profile_id() -> String:
	return "demo" if is_demo() else "full"


static func save_relative_root(for_profile: String = "") -> String:
	var selected: String = profile_id() if for_profile.is_empty() else for_profile
	return DEMO_SAVE_ROOT if selected == "demo" else FULL_SAVE_ROOT


static func save_base_dir(for_profile: String = "") -> String:
	return "user://%s" % save_relative_root(for_profile)


static func select(items: Array[Dictionary], ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if str(item.get("id", "")) in ids:
			result.append(item.duplicate(true))
	return result


static func area_available(area_id: String) -> bool:
	return AREA_UNLOCK_LEVELS.has(area_id) and (not is_demo() or area_id in DEMO_AREAS)


static func area_unlock_level(area_id: String) -> int:
	return int(AREA_UNLOCK_LEVELS.get(area_id, 0))


static func desktop_docks() -> Array[String]:
	var result: Array[String] = []
	result.assign(DEMO_DESKTOP_DOCKS if is_demo() else FULL_DESKTOP_DOCKS)
	return result
