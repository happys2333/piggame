class_name SaveService
extends RefCounted

signal recovery_used(source: String)
signal save_failed(message: String)

const CURRENT_SCHEMA: int = 4

var base_dir: String
var save_path: String
var backup_1_path: String
var backup_2_path: String
var temp_path: String
var settings_path: String
var _known_ids: Dictionary = {}
var _known_room_slots: Dictionary = {}
var _furniture_placement_rules: Dictionary = {}
var _event_photo_ids: Dictionary = {}
var _life_plan_limits: Dictionary = {}
var _life_plan_levels: Dictionary = {}
var _life_plan_entry_requirements: Dictionary = {}


func _init(custom_base_dir: String = "user://piggy_did_nothing_today") -> void:
	base_dir = custom_base_dir.trim_suffix("/")
	save_path = base_dir + "/savegame.json"
	backup_1_path = base_dir + "/savegame.backup1.json"
	backup_2_path = base_dir + "/savegame.backup2.json"
	temp_path = base_dir + "/savegame.tmp.json"
	settings_path = base_dir + "/machine_settings.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))


func configure_content_ids(catalog: ContentCatalog, room_slots: Dictionary = {}) -> void:
	_known_ids.clear()
	_furniture_placement_rules.clear()
	for type: String in ["behaviors", "furniture", "snacks", "outfits", "expressions", "events", "achievements", "life_plans", "personalities"]:
		var ids: Dictionary = {}
		for item: Dictionary in catalog.get_all(type):
			var id: String = str(item.get("id", ""))
			if not id.is_empty():
				ids[id] = true
				if type == "furniture":
					_furniture_placement_rules[id] = {"area":str(item.get("area", "")), "slot":str(item.get("slot", ""))}
		_known_ids[type] = ids
	_known_room_slots.clear()
	for slot_value: Variant in room_slots:
		var slot_id: String = str(slot_value)
		if not slot_id.is_empty():
			_known_room_slots[slot_id] = str(room_slots[slot_value])
	_event_photo_ids.clear()
	for event: Dictionary in catalog.events:
		var event_id: String = str(event.get("id", ""))
		if not event_id.is_empty():
			_event_photo_ids[event_id] = str(event.get("photo_id", event_id))
	_life_plan_limits.clear()
	_life_plan_levels.clear()
	_life_plan_entry_requirements.clear()
	var entry_ids: Dictionary = {}
	for plan: Dictionary in catalog.life_plans:
		_life_plan_limits[str(plan.id)] = LifePlanRules.maximum_seconds(plan)
		_life_plan_levels[str(plan.id)] = int(plan.min_level)
		for entry: Dictionary in plan.entries as Array:
			entry_ids[str(entry.id)] = true
			_life_plan_entry_requirements[str(entry.id)] = {"plan":str(plan.id), "seconds":float(entry.seconds)}
	_known_ids["life_plan_entries"] = entry_ids


func save_game(data: Dictionary) -> Error:
	var payload: Dictionary = data.duplicate(true)
	payload["schema_version"] = CURRENT_SCHEMA
	var text: String = JSON.stringify(payload, "\t", false)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail("Could not open temporary save", FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	file.close()
	var verified: Dictionary = _read_valid(temp_path)
	if not _is_valid_game_payload(verified):
		var cleanup_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		if cleanup_error != OK:
			return _fail("Could not remove invalid temporary save", cleanup_error)
		return _fail("Temporary save verification failed", ERR_FILE_CORRUPT)
	var error: Error = _rotate_and_replace()
	if error != OK:
		return _fail("Could not replace the main save", error)
	return OK


func load_game() -> Dictionary:
	var rotation_path: String = backup_2_path + ".rotate"
	var had_files: bool = FileAccess.file_exists(rotation_path)
	var rotation_error: Error = _recover_interrupted_rotation()
	if rotation_error != OK:
		_fail("Could not recover an interrupted save rotation", rotation_error)
	var paths: Array[String] = [save_path, backup_1_path, backup_2_path, rotation_path]
	for index: int in paths.size():
		had_files = had_files or FileAccess.file_exists(paths[index])
		var data: Dictionary = _read_valid(paths[index])
		if data.is_empty():
			continue
		var migrated: Dictionary = migrate(data)
		if not _is_valid_game_payload(migrated):
			continue
		if index > 0:
			recovery_used.emit(paths[index])
			# Restore a verified copy without rotating the damaged main into backups.
			var restore_error: Error = _write_atomic(save_path, migrated)
			if restore_error != OK:
				_fail("Could not restore the recovered main save", restore_error)
			return {
				"ok": true,
				"data": migrated,
				"source": paths[index],
				"recovered": true,
				"recovery_write_error": restore_error,
				"had_files": had_files,
			}
		return {
			"ok": true,
			"data": migrated,
			"source": paths[index],
			"recovered": false,
			"recovery_write_error": OK,
			"had_files": had_files,
		}
	return {"ok": false, "data": {}, "source": "", "recovered": false, "had_files": had_files}


func save_settings(settings: Dictionary) -> Error:
	var error: Error = _write_atomic(settings_path, settings)
	return _fail("Could not save machine settings", error) if error != OK else OK


func load_settings() -> Dictionary:
	return _read_valid(settings_path)


func migrate(source: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	var version_value: Variant = data.get("schema_version", 0)
	if not _number_in_range(version_value, 0, CURRENT_SCHEMA) or float(version_value) != floorf(float(version_value)):
		return {}
	var version: int = int(version_value)
	while version < CURRENT_SCHEMA:
		match version:
			0:
				if data.has("pig") and not data.has("pig_state"):
					data["pig_state"] = data.pig
					data.erase("pig")
				if not data.get("pig_state", null) is Dictionary:
					return {}
				version = 1
				data["schema_version"] = version
			1:
				var pig_value: Variant = data.get("pig_state", null)
				if not pig_value is Dictionary:
					return {}
				var pig_state: Dictionary = pig_value as Dictionary
				pig_state["life_photos"] = pig_state.get("life_photos", {})
				pig_state["ending_unlocked"] = pig_state.get("ending_unlocked", false)
				pig_state["ending_seen"] = pig_state.get("ending_seen", false)
				data["pig_state"] = pig_state
				version = 2
				data["schema_version"] = version
			2:
				var pig_value: Variant = data.get("pig_state", null)
				if not pig_value is Dictionary:
					return {}
				var pig_state: Dictionary = pig_value as Dictionary
				pig_state["current_photo_frame"] = str(pig_state.get("current_photo_frame", "plain"))
				var photos_value: Variant = pig_state.get("life_photos", {})
				if photos_value is Dictionary:
						for event_id_value: Variant in photos_value as Dictionary:
							var record_value: Variant = (photos_value as Dictionary)[event_id_value]
							if record_value is Dictionary and not (record_value as Dictionary).has("photo_id"):
								var event_id: String = str(event_id_value)
								(record_value as Dictionary)["photo_id"] = str(_event_photo_ids.get(event_id, event_id))
				data["pig_state"] = pig_state
				version = 3
				data["schema_version"] = version
			3:
				var pig_value: Variant = data.get("pig_state", null)
				if not pig_value is Dictionary:
					return {}
				var pig_state: Dictionary = pig_value as Dictionary
				pig_state["demo_completion_seen"] = pig_state.get("demo_completion_seen", false)
				data["pig_state"] = pig_state
				version = 4
				data["schema_version"] = version
			_:
				return {}
	return data


func _rotate_and_replace() -> Error:
	var recovery_error: Error = _recover_interrupted_rotation()
	if recovery_error != OK:
		return recovery_error
	var verified_temp: Dictionary = _read_valid(temp_path)
	var verified_main: Dictionary = _read_valid(save_path)
	if not verified_main.is_empty() and verified_main == verified_temp:
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	var backup_2_abs: String = ProjectSettings.globalize_path(backup_2_path)
	var backup_1_abs: String = ProjectSettings.globalize_path(backup_1_path)
	var save_abs: String = ProjectSettings.globalize_path(save_path)
	var temp_abs: String = ProjectSettings.globalize_path(temp_path)
	var rotation_path: String = backup_2_path + ".rotate"
	var rotation_abs: String = ProjectSettings.globalize_path(rotation_path)
	var staged_backup_abs: String = ""
	var moved_backup_1: bool = false
	var moved_save: bool = false
	var usable_save: bool = _is_valid_game_payload(migrate(verified_main))
	var usable_backup_1: bool = _is_valid_game_payload(migrate(_read_valid(backup_1_path)))
	if usable_save and usable_backup_1 and FileAccess.file_exists(backup_2_path):
		var staging_error: Error = DirAccess.rename_absolute(backup_2_abs, rotation_abs)
		if staging_error != OK:
			return staging_error
		staged_backup_abs = backup_2_abs
	elif usable_save and not usable_backup_1 and FileAccess.file_exists(backup_1_path):
		var staging_error: Error = DirAccess.rename_absolute(backup_1_abs, rotation_abs)
		if staging_error != OK:
			return staging_error
		staged_backup_abs = backup_1_abs
	if usable_save and usable_backup_1:
		var rotate_error: Error = DirAccess.rename_absolute(backup_1_abs, backup_2_abs)
		if rotate_error != OK:
			return _rollback_rotation(rotate_error, rotation_abs, staged_backup_abs, moved_backup_1, moved_save)
		moved_backup_1 = true
	if usable_save:
		var backup_error: Error = DirAccess.rename_absolute(save_abs, backup_1_abs)
		if backup_error != OK:
			return _rollback_rotation(backup_error, rotation_abs, staged_backup_abs, moved_backup_1, moved_save)
		moved_save = true
	var replace_error: Error = DirAccess.rename_absolute(temp_abs, save_abs)
	if replace_error != OK:
		return _rollback_rotation(replace_error, rotation_abs, staged_backup_abs, moved_backup_1, moved_save)
	if not staged_backup_abs.is_empty():
		DirAccess.remove_absolute(rotation_abs)
	return OK


func _recover_interrupted_rotation() -> Error:
	var rotation_path: String = backup_2_path + ".rotate"
	if not FileAccess.file_exists(rotation_path):
		return OK
	var save_abs: String = ProjectSettings.globalize_path(save_path)
	var backup_1_abs: String = ProjectSettings.globalize_path(backup_1_path)
	var backup_2_abs: String = ProjectSettings.globalize_path(backup_2_path)
	var rotation_abs: String = ProjectSettings.globalize_path(rotation_path)
	if not _is_valid_game_payload(migrate(_read_valid(rotation_path))):
		for path: String in [save_path, backup_1_path, backup_2_path]:
			if _is_valid_game_payload(migrate(_read_valid(path))):
				return DirAccess.remove_absolute(rotation_abs)
		return ERR_FILE_CORRUPT
	var has_save: bool = FileAccess.file_exists(save_path)
	var has_backup_1: bool = FileAccess.file_exists(backup_1_path)
	var has_backup_2: bool = FileAccess.file_exists(backup_2_path)
	var moves: Array[Dictionary] = []
	if has_save and has_backup_1 and has_backup_2:
		var backup_1_data: Dictionary = _read_valid(backup_1_path)
		var backup_2_data: Dictionary = _read_valid(backup_2_path)
		var usable_backup_1: bool = _is_valid_game_payload(migrate(backup_1_data))
		var usable_backup_2: bool = _is_valid_game_payload(migrate(backup_2_data))
		if usable_backup_1 and usable_backup_2 and backup_1_data != backup_2_data:
			return DirAccess.remove_absolute(rotation_abs)
		if not usable_backup_1 and usable_backup_2:
			var backup_2_bytes: PackedByteArray = FileAccess.get_file_as_bytes(backup_2_path)
			if backup_2_bytes.is_empty():
				return ERR_FILE_CORRUPT
			var copy_error: Error = _write_atomic(backup_1_path, backup_2_data, backup_2_bytes)
			if copy_error != OK:
				return copy_error
		moves.append({"source":rotation_abs, "destination":backup_2_abs})
	elif has_save and has_backup_1 and not has_backup_2:
		moves.append({"source":rotation_abs, "destination":backup_2_abs})
	elif has_save and not has_backup_1 and has_backup_2:
		moves.append({"source":backup_2_abs, "destination":backup_1_abs})
		moves.append({"source":rotation_abs, "destination":backup_2_abs})
	elif not has_save and has_backup_1 and has_backup_2:
		moves.append({"source":backup_1_abs, "destination":save_abs})
		moves.append({"source":backup_2_abs, "destination":backup_1_abs})
		moves.append({"source":rotation_abs, "destination":backup_2_abs})
	else:
		if has_backup_2:
			moves.append({"source":backup_2_abs, "destination":backup_1_abs})
		moves.append({"source":rotation_abs, "destination":backup_2_abs})
	var completed_moves: Array[Dictionary] = []
	for move: Dictionary in moves:
		var move_error: Error = DirAccess.rename_absolute(str(move.source), str(move.destination))
		if move_error == OK:
			completed_moves.append(move)
			continue
		var rollback_error: Error = OK
		while not completed_moves.is_empty():
			var completed: Dictionary = completed_moves.pop_back()
			var reverse_error: Error = DirAccess.rename_absolute(str(completed.destination), str(completed.source))
			if rollback_error == OK and reverse_error != OK:
				rollback_error = reverse_error
		return rollback_error if rollback_error != OK else move_error
	return OK


func _rollback_rotation(
	original_error: Error,
	rotation_abs: String,
	staged_backup_abs: String,
	moved_backup_1: bool,
	moved_save: bool
) -> Error:
	var rollback_error: Error = OK
	if moved_save:
		rollback_error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_1_path),
			ProjectSettings.globalize_path(save_path)
		)
	if moved_backup_1:
		var restore_backup_1_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_2_path),
			ProjectSettings.globalize_path(backup_1_path)
		)
		if rollback_error == OK and restore_backup_1_error != OK:
			rollback_error = restore_backup_1_error
	if not staged_backup_abs.is_empty():
		var restore_staged_error: Error = DirAccess.rename_absolute(
			rotation_abs,
			staged_backup_abs
		)
		if rollback_error == OK and restore_staged_error != OK:
			rollback_error = restore_staged_error
	return rollback_error if rollback_error != OK else original_error


func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) == OK and parser.data is Dictionary:
		return parser.data as Dictionary
	return {}


func _is_valid_game_payload(data: Dictionary, validate_roster: bool = true) -> bool:
	if data.is_empty() or not _is_integer_number(data.get("schema_version", -1)) or int(data.get("schema_version", -1)) != CURRENT_SCHEMA:
		return false
	if not data.get("pig_state", null) is Dictionary:
		return false
	if data.has("last_saved_unix") and (not _is_integer_number(data.last_saved_unix) or int(data.last_saved_unix) < 0):
		return false
	for section: String in ["behavior_director", "event_director", "simulation"]:
		if data.has(section) and not data[section] is Dictionary:
			return false
	if data.has("behavior_director") and not _is_valid_behavior_director(data.behavior_director as Dictionary):
		return false
	if data.has("event_director") and not _is_valid_event_director(data.event_director as Dictionary):
		return false
	if data.has("simulation") and not _is_valid_simulation(data.simulation as Dictionary):
		return false
	var pig: Dictionary = data.pig_state as Dictionary
	for key: String in ["name", "personality_id", "tendency", "current_outfit", "current_room_palette", "current_photo_frame", "favorite_desktop_expression", "active_life_plan"]:
		if pig.has(key) and not pig[key] is String:
			return false
	if pig.has("personality_id") and not str(pig.personality_id).is_empty() and str(pig.personality_id) not in PersonalityRules.IDS:
		return false
	for key: String in ["satiety", "energy", "interest", "active_seconds"]:
		if pig.has(key) and not _is_number(pig[key]):
			return false
	for key: String in ["familiarity_xp", "familiarity_level", "daily_points", "tutorial_step"]:
		if pig.has(key) and not _is_integer_number(pig[key]):
			return false
	for key: String in ["satiety", "energy", "interest"]:
		if pig.has(key) and not _number_in_range(pig[key], 0.0, 100.0):
			return false
	if pig.has("familiarity_xp") and int(pig.familiarity_xp) < 0:
		return false
	if pig.has("familiarity_level") and not _number_in_range(pig.familiarity_level, 1.0, 10.0):
		return false
	if pig.has("active_seconds") and float(pig.active_seconds) < 0.0:
		return false
	if pig.has("daily_points") and int(pig.daily_points) < 0:
		return false
	if pig.has("tutorial_step") and not _number_in_range(pig.tutorial_step, 0.0, 7.0):
		return false
	if pig.has("tendency") and str(pig.tendency) not in ["rest", "food", "active", "explore"]:
		return false
	if pig.has("current_room_palette") and str(pig.current_room_palette) not in ["rose", "mint", "night"]:
		return false
	if pig.has("current_photo_frame") and str(pig.current_photo_frame) not in ["plain", "berry", "star"]:
		return false
	for key: String in ["owned_furniture", "owned_snacks", "owned_outfits", "unlocked_expressions", "discovered_events", "seen_events", "pending_events", "summarized_events", "unlocked_achievements", "life_plan_entries"]:
		if pig.has(key) and not _is_unique_string_array(pig[key]):
			return false
	for key: String in ["placed_furniture", "expression_unlock_dates", "life_photos", "interaction_counts", "life_plan_progress"]:
		if pig.has(key) and not pig[key] is Dictionary:
			return false
	for key: String in ["ending_unlocked", "ending_seen", "demo_completion_seen", "tutorial_skipped"]:
		if pig.has(key) and not pig[key] is bool:
			return false
	if pig.has("name"):
		var saved_name: String = str(pig.name)
		if saved_name.length() > 16:
			return false
		if (
			saved_name.strip_edges().is_empty()
			and int(pig.get("tutorial_step", 0)) != 0
			and not bool(pig.get("tutorial_skipped", false))
		):
			return false
	if pig.has("placed_furniture") and not _is_unique_string_map(pig.placed_furniture):
		return false
	if pig.has("placed_furniture") and pig.has("owned_furniture"):
		for furniture_id: Variant in (pig.placed_furniture as Dictionary).values():
			if furniture_id not in pig.owned_furniture:
				return false
	if pig.has("expression_unlock_dates") and not _is_non_negative_number_map(pig.expression_unlock_dates, true):
		return false
	if pig.has("interaction_counts") and not _is_non_negative_number_map(pig.interaction_counts, true):
		return false
	if not _is_valid_life_plan_state(pig):
		return false
	var pending: Array = pig.get("pending_events", []) as Array
	var summarized: Array = pig.get("summarized_events", []) as Array
	if pending.size() > 5 or pending.any(func(id: Variant) -> bool: return id in summarized):
		return false
	if pig.has("discovered_events"):
		var discovered: Array = pig.discovered_events as Array
		for key: String in ["seen_events", "pending_events", "summarized_events"]:
			if pig.has(key) and not _contains_all(discovered, pig[key] as Array):
				return false
	if pig.has("life_photos") and not _is_valid_life_photos(
		pig.life_photos as Dictionary,
		pig.get("discovered_events", []) as Array,
		pig.has("discovered_events")
	):
		return false
	if pig.has("current_outfit") and pig.has("owned_outfits"):
		var outfit_id: String = str(pig.current_outfit)
		if not outfit_id.is_empty() and outfit_id not in pig.owned_outfits:
			return false
	if pig.has("favorite_desktop_expression") and pig.has("unlocked_expressions"):
		var expression_id: String = str(pig.favorite_desktop_expression)
		if not expression_id.is_empty() and expression_id not in pig.unlocked_expressions:
			return false
	if pig.has("ending_seen") and bool(pig.ending_seen) and (not pig.has("ending_unlocked") or not bool(pig.ending_unlocked)):
		return false
	return _matches_configured_content(data) and (not validate_roster or _is_valid_companion_roster(data))


func _is_valid_companion_roster(data: Dictionary) -> bool:
	if not data.has("companions") and not data.has("active_companion_id"):
		return true
	if not data.get("companions", null) is Dictionary or not data.get("active_companion_id", null) is String:
		return false
	var companions: Dictionary = data.companions as Dictionary
	var active_id: String = str(data.active_companion_id)
	if companions.is_empty() or companions.size() > CompanionRules.IDS.size() or not companions.has(active_id) or not companions.has(CompanionRules.IDS[0]):
		return false
	for id_value: Variant in companions:
		if not id_value is String or str(id_value) not in CompanionRules.IDS or not companions[id_value] is Dictionary:
			return false
		var snapshot: Dictionary = companions[id_value] as Dictionary
		if snapshot.size() != CompanionRules.SNAPSHOT_FIELDS.size():
			return false
		for field: String in CompanionRules.SNAPSHOT_FIELDS:
			if not snapshot.has(field):
				return false
		var payload: Dictionary = snapshot.duplicate(true)
		payload["schema_version"] = CURRENT_SCHEMA
		if not _is_valid_game_payload(payload, false):
			return false
		var pig: Dictionary = snapshot.pig_state as Dictionary
		if str(id_value) != CompanionRules.IDS[0] and CompanionRules.clean_name(str(pig.get("name", ""))).is_empty():
			return false
		for event_id: String in pig.get("life_photos", {}) as Dictionary:
			var photo: Dictionary = (pig.life_photos as Dictionary)[event_id] as Dictionary
			var expected_path: String = "%s/photos/%s.png" % [CompanionRules.photo_base_dir(base_dir, str(id_value)), str(photo.photo_id)]
			if str(photo.path) != expected_path:
				return false
	return companions[active_id] == CompanionRules.snapshot(data)


func _matches_configured_content(data: Dictionary) -> bool:
	if _known_ids.is_empty():
		return true
	if data.has("release_profile") and (
		not data.release_profile is String
		or str(data.release_profile) not in ["full", "demo"]
	):
		return false
	var pig: Dictionary = data.pig_state as Dictionary
	if not str(pig.get("personality_id", "")).is_empty() and not _id_known(str(pig.personality_id), "personalities"):
		return false
	var collection_types := {
		"owned_furniture": "furniture",
		"owned_snacks": "snacks",
		"owned_outfits": "outfits",
		"unlocked_expressions": "expressions",
		"discovered_events": "events",
		"seen_events": "events",
		"pending_events": "events",
		"summarized_events": "events",
		"unlocked_achievements": "achievements",
		"life_plan_entries": "life_plan_entries",
	}
	for field: String in collection_types:
		if pig.has(field) and not _all_ids_known(pig[field] as Array, str(collection_types[field])):
			return false
	if pig.has("current_outfit"):
		var outfit_id: String = str(pig.current_outfit)
		if not outfit_id.is_empty() and not _id_known(outfit_id, "outfits"):
			return false
	if pig.has("favorite_desktop_expression"):
		var favorite_id: String = str(pig.favorite_desktop_expression)
		if not favorite_id.is_empty() and not _id_known(favorite_id, "expressions"):
			return false
	if pig.has("placed_furniture"):
		for slot_value: Variant in pig.placed_furniture as Dictionary:
			var slot_id: String = str(slot_value)
			var furniture_id: String = str((pig.placed_furniture as Dictionary)[slot_value])
			if (
				not _known_room_slots.is_empty()
				and not _known_room_slots.has(slot_id)
			) or not _id_known(furniture_id, "furniture"):
				return false
			var rule: Dictionary = _furniture_placement_rules.get(furniture_id, {}) as Dictionary
			if not rule.is_empty():
				if not slot_id.begins_with(str(rule.area) + "_"):
					return false
				if _known_room_slots.has(slot_id) and str(_known_room_slots[slot_id]) != str(rule.slot):
					return false
	if pig.has("expression_unlock_dates"):
		var unlocked: Array = pig.get("unlocked_expressions", []) as Array
		for expression_value: Variant in pig.expression_unlock_dates as Dictionary:
			var expression_id: String = str(expression_value)
			if not _id_known(expression_id, "expressions") or expression_id not in unlocked:
				return false
	if pig.has("life_photos"):
		for event_value: Variant in pig.life_photos as Dictionary:
			var event_id: String = str(event_value)
			var record: Dictionary = (pig.life_photos as Dictionary)[event_value] as Dictionary
			if (
				not _id_known(event_id, "events")
				or str(record.get("photo_id", "")) != str(_event_photo_ids.get(event_id, ""))
			):
				return false
	if data.has("behavior_director"):
		var behavior_state: Dictionary = data.behavior_director as Dictionary
		if (
			behavior_state.has("recent_ids")
			and not _all_ids_known(behavior_state.recent_ids as Array, "behaviors")
		) or (
			behavior_state.has("cooldown_until")
			and not _all_dictionary_keys_known(behavior_state.cooldown_until as Dictionary, "behaviors")
		):
			return false
	if data.has("event_director"):
		var event_state: Dictionary = data.event_director as Dictionary
		if (
			event_state.has("recent_event_ids")
			and not _all_ids_known(event_state.recent_event_ids as Array, "events")
		) or (
			event_state.has("last_triggered_unix")
			and not _all_dictionary_keys_known(event_state.last_triggered_unix as Dictionary, "events")
		):
			return false
	if data.has("simulation"):
		var behavior_id: String = str((data.simulation as Dictionary).get("current_behavior_id", ""))
		if not behavior_id.is_empty() and not _id_known(behavior_id, "behaviors"):
			return false
	return true


func _id_known(id: String, type: String) -> bool:
	return (_known_ids.get(type, {}) as Dictionary).has(id)


func _all_ids_known(ids: Array, type: String) -> bool:
	for id_value: Variant in ids:
		if not _id_known(str(id_value), type):
			return false
	return true


func _all_dictionary_keys_known(values: Dictionary, type: String) -> bool:
	for id_value: Variant in values:
		if not _id_known(str(id_value), type):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_valid_life_plan_state(pig: Dictionary) -> bool:
	var progress: Dictionary = pig.get("life_plan_progress", {}) as Dictionary
	if not _is_non_negative_number_map(progress):
		return false
	var active_id: String = str(pig.get("active_life_plan", ""))
	if not active_id.is_empty() and not _known_ids.is_empty():
		if not _id_known(active_id, "life_plans") or int(pig.get("familiarity_level", 1)) < int(_life_plan_levels.get(active_id, 2)):
			return false
	for plan_id: String in progress:
		if not _known_ids.is_empty() and not _id_known(plan_id, "life_plans"):
			return false
		if float(progress[plan_id]) > float(_life_plan_limits.get(plan_id, LifePlanRules.MAX_PLAN_SECONDS)):
			return false
	for entry_id: String in pig.get("life_plan_entries", []) as Array:
		if not _known_ids.is_empty():
			var requirement: Dictionary = _life_plan_entry_requirements.get(entry_id, {}) as Dictionary
			if requirement.is_empty() or float(progress.get(str(requirement.plan), 0.0)) < float(requirement.seconds):
				return false
	return true


static func _is_integer_number(value: Variant) -> bool:
	return (
		value is int
		or (
			value is float
			and is_finite(float(value))
			and float(value) >= -9223372036854775808.0
			and float(value) < 9223372036854775808.0
			and float(value) == floorf(float(value))
		)
	)


static func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	return _is_number(value) and float(value) >= minimum and float(value) <= maximum


static func _is_unique_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen: Dictionary = {}
	for item: Variant in value as Array:
		if not item is String:
			return false
		var id: String = str(item)
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true


static func _is_unique_string_map(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var seen_values: Dictionary = {}
	for raw_key: Variant in value as Dictionary:
		var raw_value: Variant = (value as Dictionary)[raw_key]
		if not raw_key is String or str(raw_key).is_empty() or not raw_value is String or str(raw_value).is_empty():
			return false
		if seen_values.has(str(raw_value)):
			return false
		seen_values[str(raw_value)] = true
	return true


static func _is_non_negative_number_map(value: Variant, integers_only: bool = false) -> bool:
	if not value is Dictionary:
		return false
	for raw_key: Variant in value as Dictionary:
		var raw_value: Variant = (value as Dictionary)[raw_key]
		if not raw_key is String or str(raw_key).is_empty():
			return false
		if integers_only and not _is_integer_number(raw_value):
			return false
		if not _is_number(raw_value) or float(raw_value) < 0.0:
			return false
	return true


static func _is_bounded_string_array(value: Variant, maximum: int) -> bool:
	if not value is Array or (value as Array).size() > maximum:
		return false
	for item: Variant in value as Array:
		if not item is String or str(item).is_empty():
			return false
	return true


static func _is_valid_behavior_director(data: Dictionary) -> bool:
	if data.has("recent_ids") and not _is_bounded_string_array(data.recent_ids, BehaviorDirector.RECENT_LIMIT):
		return false
	if data.has("cooldown_until") and not _is_non_negative_number_map(data.cooldown_until, true):
		return false
	return true


static func _is_valid_event_director(data: Dictionary) -> bool:
	if data.has("recent_event_ids") and not _is_bounded_string_array(data.recent_event_ids, EventDirector.RECENT_LIMIT):
		return false
	if data.has("last_triggered_unix") and not _is_non_negative_number_map(data.last_triggered_unix, true):
		return false
	return true


static func _is_valid_simulation(data: Dictionary) -> bool:
	if data.has("current_behavior_id") and not data.current_behavior_id is String:
		return false
	if data.has("remaining_seconds") and (not _is_number(data.remaining_seconds) or float(data.remaining_seconds) < 0.0):
		return false
	if data.has("current_behavior_id") and data.has("remaining_seconds"):
		var behavior_id: String = str(data.current_behavior_id)
		var remaining: float = float(data.remaining_seconds)
		if behavior_id.is_empty() != is_zero_approx(remaining):
			return false
	return true


static func _is_valid_life_photos(data: Dictionary, discovered_events: Array, require_discovery: bool) -> bool:
	for event_id_value: Variant in data:
		if not event_id_value is String or str(event_id_value).is_empty():
			return false
		var event_id: String = str(event_id_value)
		if require_discovery and event_id not in discovered_events:
			return false
		var record_value: Variant = data[event_id_value]
		if not record_value is Dictionary:
			return false
		var record: Dictionary = record_value as Dictionary
		for key: String in ["photo_id", "path"]:
			if not record.get(key, null) is String or str(record[key]).is_empty():
				return false
		if not _is_integer_number(record.get("captured_unix", -1)) or int(record.captured_unix) < 0:
			return false
	return true


static func _contains_all(haystack: Array, needles: Array) -> bool:
	for item: Variant in needles:
		if item not in haystack:
			return false
	return true


func _write_atomic(path: String, data: Dictionary, raw_bytes: PackedByteArray = PackedByteArray()) -> Error:
	var contents: PackedByteArray = JSON.stringify(data, "\t", false).to_utf8_buffer() if raw_bytes.is_empty() else raw_bytes
	var staging_path: String = path + ".tmp"
	var file := FileAccess.open(staging_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(contents)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		var stored_bytes: PackedByteArray = FileAccess.get_file_as_bytes(staging_path)
		var parser := JSON.new()
		if stored_bytes != contents or parser.parse(stored_bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
			error = ERR_FILE_CORRUPT
		elif not raw_bytes.is_empty() and parser.data != data:
			error = ERR_FILE_CORRUPT
	if error == OK:
		error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(staging_path),
			ProjectSettings.globalize_path(path)
		)
	if error != OK:
		var cleanup_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))
		return cleanup_error if cleanup_error != OK else error
	return OK


func _fail(message: String, error: Error) -> Error:
	save_failed.emit("%s (%s)" % [message, error_string(error)])
	return error
