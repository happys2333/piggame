class_name PersonalityRules
extends RefCounted

const IDS: Array[String] = ["personality_lively", "personality_tsundere", "personality_lazy", "personality_shy", "personality_foodie"]
const RANDOM_CHOICE: String = "random"


static func resolve_choice(choice: String, profiles: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	if choice == RANDOM_CHOICE:
		return str(profiles[rng.randi_range(0, profiles.size() - 1)].id) if not profiles.is_empty() else ""
	for profile: Dictionary in profiles:
		if str(profile.get("id", "")) == choice:
			return choice
	return ""


static func validate_content(profiles: Array[Dictionary], expressions: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var seen: Array[String] = []
	for profile: Dictionary in profiles:
		var id: String = str(profile.get("id", ""))
		if id not in IDS or id in seen:
			errors.append("Personality requires a unique permanent ID: %s" % id)
		seen.append(id)
		for key: String in ["name_key", "description_key"]:
			if not profile.get(key, null) is String or str(profile.get(key, "")).is_empty():
				errors.append("Personality %s is missing %s" % [id, key])
		for kind: String in ["pet", "poke"]:
			if not profile.get(kind, null) is Dictionary:
				errors.append("Personality %s is missing %s reaction" % [id, kind])
				continue
			var response: Dictionary = profile[kind] as Dictionary
			var expression_id: String = str(response.get("expression_id", ""))
			var matches: Array[Dictionary] = expressions.filter(func(item: Dictionary) -> bool: return str(item.id) == expression_id and str(item.category) == str(response.get("category", "")))
			if matches.size() != 1 or not response.get("toast_key", null) is String or str(response.get("toast_key", "")).is_empty():
				errors.append("Personality %s has an invalid %s reaction" % [id, kind])
	if profiles.size() != IDS.size():
		errors.append("Personality catalog requires five profiles")
	return errors
