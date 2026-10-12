extends SceneTree

const GameSessionScript = preload("res://game/scripts/core/game_session.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty():
		expected = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not expected.begins_with("PiggameGodotChecks-") or not OS.get_user_data_dir().ends_with(expected):
		quit(1)
		return
	(root.get_node("GameSession") as Node).set_process(false)
	var catalog := ContentCatalog.new()
	_check(catalog.load_all().is_empty(), "active and retired catalogues validate")
	_check(catalog.outfits.size() == 8 and catalog.retired_outfits.size() == 4, "eight active accessories and four compatibility-only IDs")
	var retired_ids: Array[String] = []
	for attire: Dictionary in catalog.retired_outfits:
		retired_ids.append(str(attire.id))
		_check(not catalog.has_item("outfits", str(attire.id)), "retired item is absent from wardrobe and shop")
		_check(catalog.performances.outfit_action(str(attire.id)).is_empty(), "retired item cannot trigger an outfit action")
	var service := SaveService.new("user://outfit_retirement_audit")
	service.configure_content_ids(catalog)
	var old_pig := PigState.new()
	old_pig.name = "老朋友"
	old_pig.daily_points = 17
	old_pig.earned_points = 99
	old_pig.owned_outfits = retired_ids.duplicate()
	old_pig.owned_outfits.append("outfit_berry_beret")
	old_pig.unlocked_achievements.append("ach_outfits_6")
	var legacy: Dictionary = {"schema_version":SaveService.CURRENT_SCHEMA, "pig_state":old_pig.to_dict()}
	for worn_id: String in retired_ids + ["outfit_berry_beret"]:
		legacy.pig_state.current_outfit = worn_id
		var original: Dictionary = legacy.duplicate(true)
		var migrated: Dictionary = service.migrate(legacy)
		_check(service._is_valid_game_payload(migrated), "migrated legacy save remains valid")
		_check(legacy == original, "migration never mutates the caller's payload")
		_check(migrated.pig_state.owned_outfits == ["outfit_berry_beret"], "only the purchased head accessory remains")
		_check(int(migrated.pig_state.daily_points) == 1057, "all four original prices are refunded once")
		_check(int(migrated.pig_state.earned_points) == 99, "refund is not lifetime income or postcard progress")
		_check(str(migrated.pig_state.current_outfit) == (worn_id if worn_id == "outfit_berry_beret" else ""), "retired wear is removed without changing an active hat")
		_check(migrated.pig_state.unlocked_achievements == old_pig.unlocked_achievements, "earned achievements are never revoked")
		_check(service.migrate(migrated) == migrated, "repeat migration cannot refund twice")
	var oldest: Dictionary = legacy.duplicate(true)
	oldest.pig_state.erase("earned_points")
	var migrated_oldest: Dictionary = service.migrate(oldest)
	_check(int(migrated_oldest.pig_state.earned_points) == 0, "old saves reconstruct earned points before the refund")
	var restored := PigState.new()
	restored.load_dict(migrated_oldest.pig_state)
	_check(PostcardRules.deliver(catalog.postcards, restored, 123).is_empty(), "retirement refunds never unlock letters on old saves")
	for corruption: String in ["duplicate", "unknown", "unowned_current", "negative_balance", "fractional_balance"]:
		var invalid: Dictionary = legacy.duplicate(true)
		match corruption:
			"duplicate": invalid.pig_state.owned_outfits.append(retired_ids[0])
			"unknown": invalid.pig_state.owned_outfits.append("outfit_unknown_corruption")
			"unowned_current": invalid.pig_state.current_outfit = "outfit_round_glasses"
			"negative_balance": invalid.pig_state.daily_points = -1
			"fractional_balance": invalid.pig_state.daily_points = 0.5
		_check(not service._is_valid_game_payload(service.migrate(invalid)), "retirement must not sanitize corrupt save data: " + corruption)
	var roster: Dictionary = {"schema_version":SaveService.CURRENT_SCHEMA, "active_companion_id":"pig_3", "companions":{}}
	for index: int in CompanionRules.IDS.size():
		var id: String = CompanionRules.IDS[index]
		var resident := PigState.new()
		resident.name = "猪友%d" % index
		resident.daily_points = index * 11
		resident.earned_points = 90
		resident.owned_outfits = [retired_ids[index], "outfit_round_glasses"]
		resident.current_outfit = retired_ids[index]
		roster.companions[id] = CompanionRules.snapshot({"pig_state":resident.to_dict()})
	for field: String in CompanionRules.SNAPSHOT_FIELDS:
		roster[field] = roster.companions.pig_3[field].duplicate(true) if roster.companions.pig_3[field] is Dictionary else roster.companions.pig_3[field]
	var roster_original: Dictionary = roster.duplicate(true)
	var roster_migrated: Dictionary = service.migrate(roster)
	_check(service._is_valid_game_payload(roster_migrated), "whole-roster migration preserves the active snapshot invariant")
	_check(roster == roster_original, "every original resident payload remains unchanged")
	for index: int in CompanionRules.IDS.size():
		var pig: Dictionary = roster_migrated.companions[CompanionRules.IDS[index]].pig_state
		_check(int(pig.daily_points) == index * 11 + 260, "each resident receives only its own purchase refund")
		_check(int(pig.earned_points) == 90 and pig.owned_outfits == ["outfit_round_glasses"] and str(pig.current_outfit).is_empty(), "resident income and active accessory ownership are preserved")
	_check(service.migrate(roster_migrated) == roster_migrated, "whole-roster migration is idempotent")
	_check(service.save_game(roster) == OK, "an actual legacy whole-roster save can still be written and read")
	var loaded: Dictionary = service.load_game()
	_check(bool(loaded.ok) and _same_disk_payload(loaded.data, roster_migrated), "legacy disk load applies the refund without rejecting the save")
	_check(service.save_game(loaded.data) == OK, "migrated data commits through the atomic rotating writer")
	_check(_same_disk_payload(service.load_game().data, roster_migrated), "reload does not compound a refund")
	var checkpoint: Dictionary = roster_migrated.duplicate(true)
	checkpoint.last_saved_unix = 1
	checkpoint.companions.pig_3.last_saved_unix = 1
	_check(service.save_game(checkpoint) == OK, "a subsequent checkpoint rotates both backup generations")
	_check(FileAccess.file_exists(service.backup_1_path) and FileAccess.file_exists(service.backup_2_path), "both rotating backups remain present")
	for path: String in [service.save_path, service.backup_1_path]:
		var damaged := FileAccess.open(path, FileAccess.WRITE)
		damaged.store_string("broken fixture")
		damaged.close()
	var recovered: Dictionary = service.load_game()
	_check(bool(recovered.ok) and bool(recovered.recovered) and str(recovered.source) == service.backup_2_path, "a raw legacy backup remains a valid recovery source")
	_check(_same_disk_payload(recovered.data, roster_migrated) and _same_disk_payload(service.load_game().data, roster_migrated), "backup recovery persists the migration and cannot repeat the refund")
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new("user://outfit_retirement_session")
	session.save_service.configure_content_ids(session.catalog)
	session.pig_state.owned_outfits = retired_ids.duplicate()
	session.pig_state.daily_points = 2000
	session.pig_state.familiarity_level = 10
	for retired_id: String in retired_ids:
		_check(not session.purchase("outfits", retired_id), "retired purchases are rejected by GameSession")
		_check(not session.equip_outfit(retired_id), "even stale in-memory ownership cannot re-equip retired wear")
	_check(session.pig_state.daily_points == 2000 and session.pig_state.current_outfit == "", "rejected retired actions do not spend points or change wear")
	session.free()
	print("OUTFIT_RETIREMENT: assertions=%d failures=%d" % [_assertions, _failures.size()])
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("PASS: head and face wardrobe retirement")
	quit(0 if _failures.is_empty() else 1)


func _same_disk_payload(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
