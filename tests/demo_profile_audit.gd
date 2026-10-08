extends SceneTree

const AREA_IDS: Array[String] = ["sleep", "snack", "activity", "window"]
const CROSS_AREA_FURNITURE: Array[Dictionary] = [
	{"area":"snack", "id":"furn_table_snack", "slot":"snack_1"},
	{"area":"activity", "id":"furn_treadmill", "slot":"activity_1"},
	{"area":"window", "id":"furn_window_cushion", "slot":"window_1"},
]

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect_true(ReleaseProfile.is_demo(), "the exported custom feature activates the Demo profile")
	_expect_eq(ReleaseProfile.profile_id(), "demo", "the active release profile is Demo")
	_expect_eq(ReleaseProfile.DEMO_AREAS, ["sleep"], "Demo declares exactly one room area")
	_expect_eq(ReleaseProfile.save_relative_root(), ReleaseProfile.DEMO_SAVE_ROOT, "Demo selects its isolated save root")
	_expect_eq(ReleaseProfile.save_base_dir(), "user://%s" % ReleaseProfile.DEMO_SAVE_ROOT, "Demo save base uses the isolated relative root")
	_expect_eq(ReleaseProfile.desktop_docks(), ["bottom", "left"], "Demo exposes only the promised desktop docks")
	_expect_true(not "right" in ReleaseProfile.desktop_docks(), "Demo never exposes the full-only right dock")
	_expect_true(not ReleaseProfile.AUDIO_PLAYBACK_ENABLED, "development Demo audits remain silent")
	var steam_app_type: Variant = ProjectSettings.get_setting_with_override("steam/initialization/app_data/app_type") if ProjectSettings.has_setting("steam/initialization/app_data/app_type") else -1
	var steam_auto_init: Variant = ProjectSettings.get_setting("steam/initialization/processes/initialize_on_startup", true)
	var steam_embedded_callbacks: Variant = ProjectSettings.get_setting("steam/initialization/processes/embed_callbacks", true)
	_expect_true(steam_app_type is int and int(steam_app_type) == 1, "the exported Demo selects the native Demo App ID instead of the full game")
	_expect_true(steam_auto_init is bool and not bool(steam_auto_init), "the exported Demo keeps native initialization owned by SteamService")
	_expect_true(steam_embedded_callbacks is bool and not bool(steam_embedded_callbacks), "the exported Demo keeps native callback pumping owned by SteamService")
	for area_id: String in AREA_IDS:
		_expect_eq(ReleaseProfile.area_available(area_id), area_id == "sleep", "Demo area availability is exact: %s" % area_id)
	_expect_true(not ReleaseProfile.area_available("unknown"), "unknown room areas remain unavailable")

	var session: Node = get_root().get_node_or_null("GameSession")
	_expect_true(session != null, "the exported pack starts the production GameSession autoload")
	if session == null:
		_finish(null)
		return
	_expect_true(bool(session.get("loaded_successfully")), "the Demo session loads the validated content catalog")
	var catalog: ContentCatalog = session.get("catalog") as ContentCatalog
	var state: PigState = session.get("pig_state") as PigState
	var save_service: SaveService = session.get("save_service") as SaveService
	_expect_true(catalog != null and state != null and save_service != null, "the Demo session exposes its production model services")
	if catalog == null or state == null or save_service == null:
		_finish(catalog)
		return
	_expect_eq(save_service.base_dir, ReleaseProfile.save_base_dir(), "the production session uses the Demo save directory")
	_expect_eq(catalog.furniture.size(), 6, "the production Demo catalog exposes six furniture items")
	_expect_eq(catalog.snacks.size(), 3, "the production Demo catalog exposes three snacks")
	_expect_eq(catalog.outfits.size(), 2, "the production Demo catalog exposes two outfits")
	_expect_eq(catalog.expressions.size(), 8, "the production Demo catalog exposes eight expressions")
	_expect_eq(catalog.events.size(), 4, "the production Demo catalog exposes four memories")
	_expect_eq(catalog.achievements.size(), 0, "the production Demo catalog strips full-game achievements")
	_expect_eq(catalog.life_plans.size(), 1, "the real Demo exposes one optional sleep plan")
	_expect_eq(catalog.personalities.size(), 5, "the real Demo retains every initial personality without a purchase gate")
	_expect_eq(_sorted_ids(catalog.life_plans), _sorted(ReleaseProfile.DEMO_LIFE_PLAN_IDS), "the Demo plan permanent ID set is exact")
	_expect_true(not bool(session.call("select_life_plan", "plan_snack_reviews")), "full-only plans cannot be selected through the actual Demo session")
	_expect_eq(_sorted_ids(catalog.furniture), _sorted(ReleaseProfile.DEMO_FURNITURE_IDS), "the Demo furniture ID set is exact")
	_expect_eq(_sorted_ids(catalog.expressions), _sorted(ReleaseProfile.DEMO_EXPRESSION_IDS), "the Demo expression ID set is exact")
	_expect_eq(_sorted_ids(catalog.events), _sorted(ReleaseProfile.DEMO_EVENT_IDS), "the Demo memory ID set is exact")
	_expect_true(catalog.furniture.all(func(item: Dictionary) -> bool: return str(item.get("area", "")) == "sleep"), "every Demo furniture item belongs to the sleep corner")
	_expect_true(catalog.events.all(func(item: Dictionary) -> bool: return str(item.get("time", "")) == "any"), "every Demo memory is available independent of real-world time")
	_expect_true(catalog.events.all(func(item: Dictionary) -> bool: return (item.get("rewards", {}) as Dictionary).get("achievements", []).is_empty()), "Demo memories cannot award full-game achievements")

	state.familiarity_level = 10
	for area_id: String in AREA_IDS:
		_expect_eq(bool(session.call("is_room_area_unlocked", area_id)), area_id == "sleep", "familiarity level 10 cannot bypass the Demo area boundary: %s" % area_id)
	_expect_eq(session.call("compatible_furniture_slots", "furn_bed_basic"), ["sleep_1"], "large Demo furniture exposes only the compatible sleep slot")
	_expect_eq(session.call("compatible_furniture_slots", "furn_pillow_cloud"), ["sleep_2", "sleep_3"], "small Demo furniture exposes only compatible sleep slots")
	_expect_eq(session.call("compatible_furniture_slots", "furn_clock_sleepy"), ["sleep_2", "sleep_3"], "late Demo furniture remains inside compatible sleep slots")

	state.daily_points = 100000
	var points_before: int = state.daily_points
	for fixture: Dictionary in CROSS_AREA_FURNITURE:
		var area_id: String = str(fixture.get("area", ""))
		var furniture_id: String = str(fixture.get("id", ""))
		var slot_id: String = str(fixture.get("slot", ""))
		_expect_true(not catalog.has_item("furniture", furniture_id), "the Demo catalog omits %s furniture" % area_id)
		_expect_eq(session.call("compatible_furniture_slots", furniture_id), [], "the Demo catalog exposes no %s furniture slots" % area_id)
		_expect_true(not bool(session.call("purchase", "furniture", furniture_id)), "cross-area %s furniture purchase is rejected" % area_id)
		if not furniture_id in state.owned_furniture:
			state.owned_furniture.append(furniture_id)
		_expect_true(not bool(session.call("place_furniture", slot_id, furniture_id)), "cross-area %s furniture placement is rejected" % area_id)
		_expect_true(not bool(session.call("place_furniture", slot_id, "furn_bed_basic")), "sleep furniture cannot be dragged into the %s area" % area_id)
		state.placed_furniture[slot_id] = furniture_id
		_expect_true(not bool(session.call("can_invite_to_furniture", furniture_id)), "cross-area %s furniture cannot become a drag invitation target" % area_id)
		_expect_true(not bool(session.call("invite_to_furniture", furniture_id)), "dragging the pig onto %s furniture is rejected" % area_id)
		state.placed_furniture.erase(slot_id)
		state.owned_furniture.erase(furniture_id)
	_expect_eq(state.daily_points, points_before, "rejected cross-area purchases never spend Demo points")
	_test_legacy_completion_type(session, catalog)
	_finish(catalog)


func _test_legacy_completion_type(session: Node, catalog: ContentCatalog) -> void:
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	var service := SaveService.new("user://demo_legacy_completion_type_tests")
	service.configure_content_ids(catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var fixture := PigState.new()
	fixture.name = "Demo Pig"
	fixture.daily_points = 321
	fixture.tutorial_skipped = true
	fixture.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[4]
	fixture.familiarity_level = 5
	for event: Dictionary in catalog.events:
		fixture.discovered_events.append(str(event.id))
		fixture.seen_events.append(str(event.id))
	var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"demo", "last_saved_unix":3000, "pig_state":fixture.to_dict()}
	_expect_true(bool(service.call("_is_valid_game_payload", payload)), "actual Demo legacy fixture has legitimate completed progress and an unacknowledged completion page")
	_expect_eq(service.save_game(payload), OK, "actual Demo legacy fixture commits a valid backup generation")
	_expect_eq(DirAccess.rename_absolute(ProjectSettings.globalize_path(service.save_path), ProjectSettings.globalize_path(service.backup_1_path)), OK, "actual Demo legacy fixture retains its valid current-schema backup1")
	var original_backup: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
	var invalid: Dictionary = payload.duplicate(true)
	invalid.schema_version = 3
	invalid.pig_state.daily_points = 17
	invalid.pig_state.demo_completion_seen = 1
	var file := FileAccess.open(service.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	session.last_save_error = ""
	session.last_recovery_source = ""
	session.last_offline_summary = {}
	session.call("_load_or_create_game", false)
	_expect_true(not session.save_recovery_required and not session.demo_save_imported, "actual Demo rejects malformed acknowledgement and recovers its own backup without cross-profile import")
	_expect_true(not session.pig_state.demo_completion_seen, "actual Demo integer acknowledgement cannot suppress the unseen completion page")
	_expect_true(session.should_show_demo_complete(), "actual exported Demo retains its promised completion page after legacy recovery")
	_expect_true(session.pig_state.name == "Demo Pig" and session.pig_state.daily_points == 321, "actual Demo legacy recovery retains exact identity and balance")
	_expect_eq(session.last_recovery_source, service.backup_1_path, "actual Demo legacy recovery reports the valid current-schema backup1")
	_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), original_backup, "actual Demo legacy recovery preserves backup1 bytes")
	var loaded: Dictionary = service.load_game()
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var state: Dictionary = data.get("pig_state", {}) as Dictionary
	_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and str(data.get("release_profile", "")) == "demo" and state.get("demo_completion_seen", true) == false and int(state.get("daily_points", 0)) == 321, "actual Demo recovered main reloads current-schema unacknowledged completion progress")
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.backup_1_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))


func _sorted_ids(items: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in items:
		result.append(str(item.get("id", "")))
	result.sort()
	return result


func _sorted(values: Array[String]) -> Array[String]:
	var result: Array[String] = values.duplicate()
	result.sort()
	return result


func _expect_true(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _finish(catalog: ContentCatalog) -> void:
	if _failures.is_empty() and catalog != null:
		print("PASS: %d demo profile assertions" % _assertions)
		print("PASS-CONTRACT: demo profile feature=true areas=sleep furniture=%d expressions=%d events=%d docks=bottom,left save_root=%s assertions=%d" % [
			catalog.furniture.size(), catalog.expressions.size(), catalog.events.size(), ReleaseProfile.save_relative_root(), _assertions,
		])
		quit(0)
		return
	printerr("FAIL: %d of %d demo profile assertions failed" % [_failures.size(), _assertions])
	for failure: String in _failures:
		printerr("- %s" % failure)
	quit(1)
