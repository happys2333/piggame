class_name CompanionRules
extends RefCounted

const IDS: Array[String] = ["pig_1", "pig_2", "pig_3", "pig_4"]
const SNAPSHOT_FIELDS: Array[String] = ["pig_state", "behavior_director", "event_director", "simulation", "last_saved_unix"]


static func clean_name(value: String) -> String:
	var cleaned: String = value.strip_edges()
	if cleaned.is_empty() or cleaned.length() > 16:
		return ""
	for index: int in cleaned.length():
		var codepoint: int = cleaned.unicode_at(index)
		if codepoint < 32 or codepoint == 127 or codepoint in [0x2028, 0x2029]:
			return ""
	return cleaned


static func photo_base_dir(base_dir: String, id: String) -> String:
	return base_dir if id == IDS[0] else base_dir + "/companions/" + id


static func snapshot(payload: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in SNAPSHOT_FIELDS:
		result[field] = payload.get(field, 0 if field == "last_saved_unix" else {})
	return result.duplicate(true)
