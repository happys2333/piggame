extends SceneTree

const GameSessionScript = preload("res://game/scripts/core/game_session.gd")
const AudioServiceScript = preload("res://game/scripts/audio/audio_service.gd")
const SteamServiceScript = preload("res://game/scripts/steam/steam_service.gd")
const DesktopFramePolicyScript = preload("res://game/scripts/desktop/desktop_frame_policy.gd")
const VisualFramePolicyScript = preload("res://game/scripts/ui/visual_frame_policy.gd")

class RecoveryProfileSession:
	extends "res://game/scripts/core/game_session.gd"

	var profile_import_source: SaveService

	func _load_game_with_profile_import(for_profile: String = "", import_service: SaveService = null) -> Dictionary:
		var source: SaveService = profile_import_source if profile_import_source != null else import_service
		return super._load_game_with_profile_import(for_profile, source)

class LostTemporarySaveService:
	extends SaveService

	var discard_temporary_before_rotation: bool = false

	func _init(custom_base_dir: String) -> void:
		super(custom_base_dir)

	func _rotate_and_replace() -> Error:
		if discard_temporary_before_rotation:
			var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			if error != OK:
				return error
		return super._rotate_and_replace()

class FakeSteamStatsBackend:
	extends RefCounted

	signal current_stats_received(game_id: int, result: int, user_id: int)

	var request_count: int = 0
	var achievements: Array[String] = []
	var integer_stats: Dictionary = {}
	var rich_presence: Dictionary = {}
	var store_count: int = 0
	var clear_presence_count: int = 0
	var shutdown_count: int = 0

	func requestCurrentStats() -> bool:
		request_count += 1
		return true

	func setAchievement(id: String) -> bool:
		achievements.append(id)
		return true

	func setStatInt(id: String, value: int) -> bool:
		integer_stats[id] = value
		return true

	func setRichPresence(key: String, value: String) -> bool:
		rich_presence[key] = value
		return true

	func clearRichPresence() -> void:
		clear_presence_count += 1

	func steamShutdown() -> void:
		shutdown_count += 1

	func storeStats() -> bool:
		store_count += 1
		return true


class FakeModernSteamStatsBackend:
	extends RefCounted

	var init_status: int = 0
	var init_app_id: int = -1
	var embed_callbacks: bool = true
	var achievements: Array[String] = []
	var integer_stats: Dictionary = {}
	var rich_presence: Dictionary = {}
	var store_count: int = 0

	func steamInitEx(app_id: int = 0, should_embed_callbacks: bool = false) -> Dictionary:
		init_app_id = app_id
		embed_callbacks = should_embed_callbacks
		return {"status":init_status, "verbal":"fixture"}

	func setAchievement(id: String) -> bool:
		achievements.append(id)
		return true

	func setStatInt(id: String, value: int) -> bool:
		integer_stats[id] = value
		return true

	func setRichPresence(key: String, value: String) -> bool:
		rich_presence[key] = value
		return true

	func storeStats() -> bool:
		store_count += 1
		return true


class FakeRetrySteamStatsBackend:
	extends FakeModernSteamStatsBackend

	var reject_store: bool = true

	func storeStats() -> bool:
		store_count += 1
		return not reject_store


class FakeAsyncSteamStatsBackend:
	extends FakeRetrySteamStatsBackend

	signal user_stats_stored(game_id: int, result: int)


class FakeRejectedSteamWritesBackend:
	extends FakeModernSteamStatsBackend

	var reject_writes: bool = true
	var achievement_attempts: int = 0
	var stat_attempts: int = 0

	func setAchievement(id: String) -> bool:
		achievement_attempts += 1
		return false if reject_writes else super.setAchievement(id)

	func setStatInt(id: String, value: int) -> bool:
		stat_attempts += 1
		return false if reject_writes else super.setStatInt(id, value)


class RecordingEventDirector:
	extends EventDirector

	var discovery_modes: Array[bool] = []

	func discover_one(
		_events: Array[Dictionary],
		_state: PigState,
		_unix_time: int,
		desktop_mode: bool = false,
		_announce: bool = true
	) -> Dictionary:
		discovery_modes.append(desktop_mode)
		return {}


var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_content_catalog()
	_test_final_asset_runtime_catalog()
	_test_texture_cache_budget()
	_test_desktop_platform_policy()
	_test_desktop_companion_policy()
	_test_focus_companion_timer()
	_test_desktop_companion_session()
	_test_life_plans()
	_test_pig_only_policy()
	_test_companions()
	_test_personalities()
	_test_pig_performances()
	_test_demo_profile()
	_test_profile_save_migration()
	await _test_unrecoverable_startup_write_guard()
	await _test_recovery_retry_profile_boundary()
	_test_audio_manifest_routes()
	_test_clock_boundaries()
	_test_pig_state_boundaries()
	_test_behavior_director()
	_test_focus_mode_session_routing()
	_test_behavior_weight_rules()
	_test_behavior_state_deltas()
	_test_simulation_mode_parity()
	_test_mode_switch_time_integrity()
	await _test_behavior_completion_checkpoint()
	_test_event_queue()
	_test_event_conditions_and_branches()
	_test_session_event_branch_handoff()
	_test_level_eight_combination_event()
	_test_event_rewards()
	_test_event_director_persistence()
	_test_event_discovery_save_transaction()
	_test_offline_simulation()
	_test_runtime_resume_settlement()
	_test_startup_offline_checkpoint()
	_test_daily_interaction_decay()
	_test_session_daily_interaction_clock()
	_test_session_facade_commands()
	_test_pig_touch_interactions()
	_test_onboarding_expression_unlock()
	_test_tutorial_progression()
	_test_state_roundtrip()
	await _test_important_unlock_autosave()
	await _test_exit_checkpoint()
	_test_furniture_slots()
	_test_furniture_invitation()
	_test_outfit_rules()
	_test_room_palette_rules()
	_test_photo_frame_rules()
	_test_desktop_expression_favorite_rules()
	_test_ending_trigger()
	_test_steam_adapter()
	_test_steam_store_retry()
	_test_steam_async_store_retry()
	_test_steam_rejected_write_retry()
	_test_steam_retry_backoff_updates()
	_test_steam_rejected_server_values()
	_test_desktop_frame_throttling()
	_test_desktop_roaming_policy()
	_test_animation_frame_cadence()
	_test_event_camera_shake_policy()
	_test_desktop_passthrough_polygon()
	_test_desktop_control_rail()
	_test_desktop_visibility_recovery()
	_test_photo_store_and_export()
	_test_content_reachability()
	_test_save_semantic_invariants()
	_test_unnamed_save_type_recovery()
	_test_integer_save_boundary()
	_test_legacy_boolean_migration()
	_test_schema_version_migration_boundary()
	_test_save_placement_recovery()
	_test_save_rotation_and_recovery()
	_test_save_rotation_missing_generations()
	_test_save_rotation_damaged_generations()
	_test_interrupted_save_rotation_recovery()
	_test_rotation_staging_salvage()
	_test_mixed_rotation_backup_repair()
	_test_atomic_rewrites()
	_test_save_write_failures()
	_test_player_command_save_failure_transactions()
	_test_first_launch_and_reinstall()
	_test_release_configuration()
	if _failures.is_empty():
		print("PASS: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("FAIL: %d of %d assertions failed" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("- %s" % failure)
		quit(1)


func _test_unrecoverable_startup_write_guard() -> void:
	var base := "user://unrecoverable_startup_guard_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var valid := {
		"schema_version":SaveService.CURRENT_SCHEMA,
		"release_profile":ReleaseProfile.profile_id(),
		"last_saved_unix":3000,
		"pig_state":PigState.new().to_dict(),
	}
	var future: Dictionary = valid.duplicate(true)
	future.schema_version = SaveService.CURRENT_SCHEMA + 1
	var semantic: Dictionary = valid.duplicate(true)
	semantic.pig_state.daily_points = -1
	var cases: Dictionary = {
		"broken_json":"{broken",
		"future_schema":JSON.stringify(future),
		"invalid_progression":JSON.stringify(semantic),
	}
	for label: String in cases:
		var service := SaveService.new(base + "/" + label)
		var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
		var original: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(str(cases[label]))
			file.close()
			original.append(FileAccess.get_file_as_bytes(path))
		var session: Node = GameSessionScript.new()
		session.save_service = service
		session.clock = GameClock.new(func() -> int: return 3000)
		get_root().add_child(session)
		session.set_process(false)
		_expect_true(not str(session.last_save_error).is_empty(), "%s startup reports an unreadable three-generation save" % label)
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_process", 61.0)
		_expect_eq(session.pig_state.to_dict(), state_before, "%s cannot simulate a replacement pig while existing progress is unreadable" % label)
		var after_autosave: Array[PackedByteArray] = []
		for path: String in paths:
			after_autosave.append(FileAccess.get_file_as_bytes(path))
		_expect_true(after_autosave == original, "%s autosave preserves all three original generations" % label)
		_expect_true(session.save_game() != OK, "%s explicit save cannot overwrite unreadable existing progress" % label)
		_expect_true(not session.set_pig_name("Replacement Pig"), "%s naming cannot silently turn failed load into a fresh save" % label)
		_expect_eq(session.pig_state.to_dict(), state_before, "%s rejected naming preserves the in-memory boundary" % label)
		var after_commands: Array[PackedByteArray] = []
		for path: String in paths:
			after_commands.append(FileAccess.get_file_as_bytes(path))
		_expect_true(after_commands == original, "%s explicit commands preserve all three original generations" % label)
		_expect_true(not FileAccess.file_exists(service.temp_path), "%s rejected writes leave no temporary save" % label)
		_expect_true(session.save_recovery_required, "%s startup records a persistent write barrier" % label)
		_expect_true(not session.retry_save_recovery(), "%s retry cannot dismiss an unresolved load failure" % label)
		_expect_true(session.save_recovery_required, "%s failed retry keeps the write barrier" % label)
		var after_retry: Array[PackedByteArray] = []
		for path: String in paths:
			after_retry.append(FileAccess.get_file_as_bytes(path))
		_expect_true(after_retry == original, "%s failed retry cannot rotate or rewrite existing generations" % label)
		session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		session.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		var exit_checkpoint: Dictionary = session.checkpoint_for_exit()
		_expect_eq(exit_checkpoint.get("progression_error", OK), ERR_FILE_CORRUPT, "%s normal exit checkpoint refuses to treat unreadable progression as saved" % label)
		var after_exit: Array[PackedByteArray] = []
		for path: String in paths:
			after_exit.append(FileAccess.get_file_as_bytes(path))
		_expect_true(after_exit == original and not FileAccess.file_exists(service.temp_path), "%s focus loss and exit checkpoints preserve all original generations" % label)
		for path: String in paths:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		_expect_true(not session.retry_save_recovery() and session.save_recovery_required, "%s temporarily moving damaged files aside cannot turn retry into a new-game command" % label)
		_expect_true(session.save_game() != OK, "%s recovery still refuses writes while the original generations are temporarily absent" % label)
		_expect_true(not FileAccess.file_exists(service.save_path) and not FileAccess.file_exists(service.backup_1_path) and not FileAccess.file_exists(service.backup_2_path) and not FileAccess.file_exists(service.temp_path), "%s absent-file retry creates no replacement generations" % label)
		for path_index: int in paths.size():
			var file := FileAccess.open(paths[path_index], FileAccess.WRITE)
			file.store_buffer(original[path_index])
			file.close()
		var recovered: Dictionary = valid.duplicate(true)
		recovered.pig_state.name = "Recovered Pig"
		recovered.pig_state.daily_points = 321
		recovered.pig_state.tutorial_skipped = true
		_expect_true(bool(service.call("_is_valid_game_payload", recovered)), "%s recovery fixture satisfies the real save schema" % label)
		var restored := FileAccess.open(service.backup_2_path, FileAccess.WRITE)
		restored.store_string(JSON.stringify(recovered))
		restored.close()
		var restored_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
		_expect_true(session.retry_save_recovery(), "%s retry can recover the actual second backup without relaunching" % label)
		_expect_true(not session.save_recovery_required and session.last_save_error.is_empty(), "%s successful recovery releases the write barrier and old error" % label)
		_expect_eq(session.last_recovery_source, service.backup_2_path, "%s successful retry reports the real recovery source" % label)
		_expect_eq(session.pig_state.name, "Recovered Pig", "%s restores the original pig instead of the failed-load replacement" % label)
		_expect_eq(session.pig_state.daily_points, 321, "%s restores original progression without blocked-time rewards" % label)
		_expect_true(FileAccess.get_file_as_bytes(service.backup_1_path) == original[1] and FileAccess.get_file_as_bytes(service.backup_2_path) == restored_bytes, "%s recovery preserves both backups rather than rotating the broken main" % label)
		session.call("_process", 61.0)
		_expect_true(session.pig_state.active_seconds >= 61.0 and session.pig_state.daily_points > 321, "%s successfully restored pig resumes normal simulation" % label)
		_expect_eq(session.save_game(), OK, "%s recovered progression can save normally" % label)
		var continued: Dictionary = session.pig_state.to_dict().duplicate(true)
		_expect_true(not session.retry_save_recovery() and session.pig_state.to_dict() == continued, "%s retry is unavailable after recovery and cannot rewind current progression" % label)
		session.queue_free()
		await process_frame
	for backup_index: int in [1, 2]:
		var service := SaveService.new(base + "/valid_backup_%d" % backup_index)
		var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
		var recovered: Dictionary = valid.duplicate(true)
		recovered.pig_state.name = "Existing Pig"
		recovered.pig_state.daily_points = 432
		recovered.pig_state.tutorial_skipped = true
		var original: Array[PackedByteArray] = []
		for path_index: int in paths.size():
			var file := FileAccess.open(paths[path_index], FileAccess.WRITE)
			file.store_string(JSON.stringify(recovered) if path_index == backup_index else "{broken original")
			file.close()
			original.append(FileAccess.get_file_as_bytes(paths[path_index]))
		var session: Node = GameSessionScript.new()
		session.save_service = service
		session.clock = GameClock.new(func() -> int: return 3000)
		get_root().add_child(session)
		session.set_process(false)
		_expect_true(not session.save_recovery_required, "valid backup%d startup never enters the unrecoverable write barrier" % backup_index)
		_expect_true(session.pig_state.name == "Existing Pig" and session.pig_state.daily_points == 432, "valid backup%d startup restores actual progress without retry" % backup_index)
		_expect_eq(session.last_recovery_source, paths[backup_index], "valid backup%d startup reports the selected recovery generation" % backup_index)
		_expect_true(FileAccess.get_file_as_bytes(paths[1]) == original[1] and FileAccess.get_file_as_bytes(paths[2]) == original[2], "valid backup%d startup preserves both backup generations" % backup_index)
		_expect_eq(session.save_game(), OK, "valid backup%d startup can use the normal save facade" % backup_index)
		session.queue_free()
		await process_frame
	var empty_service := SaveService.new(base + "/empty")
	var empty_session: Node = GameSessionScript.new()
	empty_session.save_service = empty_service
	empty_session.clock = GameClock.new(func() -> int: return 3000)
	get_root().add_child(empty_session)
	empty_session.set_process(false)
	_expect_true(not empty_session.save_recovery_required, "genuinely empty profile still permits first-launch onboarding")
	_expect_true(empty_session.set_pig_name("New Pig"), "genuinely empty profile can create its first progression save")
	_expect_true(FileAccess.file_exists(empty_service.save_path), "first-launch onboarding writes a real save instead of entering recovery")
	empty_session.queue_free()
	await process_frame
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_recovery_retry_profile_boundary() -> void:
	var base := "user://recovery_profile_boundary_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var full_pig := PigState.new()
	full_pig.name = "Full Pig"
	full_pig.daily_points = 432
	full_pig.tutorial_skipped = true
	var full_payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"full", "last_saved_unix":3000, "pig_state":full_pig.to_dict()}
	var demo_payload: Dictionary = full_payload.duplicate(true)
	demo_payload.release_profile = "demo"
	demo_payload.pig_state.name = "Demo Pig"
	demo_payload.pig_state.daily_points = 17
	var source := SaveService.new(base + "/demo")
	_expect_eq(source.save_game(demo_payload), OK, "profile recovery fixture writes a real valid Demo generation")
	var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source.save_path)
	var future: Dictionary = full_payload.duplicate(true)
	future.schema_version = SaveService.CURRENT_SCHEMA + 1
	var semantic: Dictionary = full_payload.duplicate(true)
	semantic.pig_state.daily_points = -1
	var cases: Dictionary = {"broken_json":"{broken Full progress", "future_schema":JSON.stringify(future), "invalid_progression":JSON.stringify(semantic)}
	for label: String in cases:
		var target := SaveService.new(base + "/" + label)
		var paths: Array[String] = [target.save_path, target.backup_1_path, target.backup_2_path]
		var original: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(str(cases[label]))
			file.close()
			original.append(FileAccess.get_file_as_bytes(path))
		var session := RecoveryProfileSession.new()
		session.save_service = target
		session.profile_import_source = source
		session.clock = GameClock.new(func() -> int: return 3000)
		var import_notices: Array[bool] = []
		session.demo_progress_imported.connect(func() -> void: import_notices.append(true))
		get_root().add_child(session)
		session.set_process(false)
		_expect_true(session.save_recovery_required and not session.demo_save_imported, "%s existing Full progression enters recovery rather than Demo import" % label)
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		var moved_all: bool = true
		for path: String in paths:
			moved_all = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".held")) == OK and moved_all
		_expect_true(moved_all, "%s fixture moves all original generations aside without deleting them" % label)
		_expect_true(not session.retry_save_recovery() and session.save_recovery_required, "%s retry cannot substitute valid Demo progress while Full originals are moved aside" % label)
		_expect_true(not session.demo_save_imported and import_notices.is_empty(), "%s blocked retry emits no misleading Demo-import success" % label)
		_expect_eq(session.pig_state.to_dict(), state_before, "%s blocked retry cannot replace the current in-memory boundary with the Demo pig" % label)
		_expect_true(not FileAccess.file_exists(target.save_path) and not FileAccess.file_exists(target.backup_1_path) and not FileAccess.file_exists(target.backup_2_path) and not FileAccess.file_exists(target.temp_path), "%s blocked retry creates no Full generation from the older Demo" % label)
		session.call("_process", 61.0)
		_expect_eq(session.pig_state.to_dict(), state_before, "%s unrelated Demo cannot restart simulation during Full recovery" % label)
		var held_unchanged: bool = true
		for path_index: int in paths.size():
			held_unchanged = FileAccess.get_file_as_bytes(paths[path_index] + ".held") == original[path_index] and held_unchanged
		_expect_true(held_unchanged, "%s retry preserves all moved original generations byte-for-byte" % label)
		_expect_eq(FileAccess.get_file_as_bytes(source.save_path), source_bytes, "%s retry preserves the real Demo source generation" % label)
		var restored := FileAccess.open(target.backup_2_path, FileAccess.WRITE)
		restored.store_string(JSON.stringify(full_payload))
		restored.close()
		_expect_true(session.retry_save_recovery(), "%s retry resumes only after the actual Full backup is restored" % label)
		_expect_true(not session.save_recovery_required and not session.demo_save_imported, "%s valid Full recovery releases the barrier without claiming Demo import" % label)
		_expect_true(session.pig_state.name == "Full Pig" and session.pig_state.daily_points == 432, "%s recovery restores Full identity and progression rather than the Demo's 17 points" % label)
		_expect_eq(session.last_recovery_source, target.backup_2_path, "%s reports the current-profile recovery source" % label)
		_expect_true(import_notices.is_empty(), "%s actual Full recovery emits no cross-profile import notice" % label)
		_expect_eq(session.save_game(), OK, "%s restored Full progress can save normally" % label)
		var persisted: Dictionary = target.load_game()
		_expect_true(bool(persisted.get("ok", false)) and str(persisted.data.release_profile) == "full" and int(persisted.data.pig_state.daily_points) == 432, "%s persisted Full generation retains the restored progression" % label)
		session.queue_free()
		await process_frame
	var first_launch := RecoveryProfileSession.new()
	first_launch.save_service = SaveService.new(base + "/genuine_empty_full")
	first_launch.profile_import_source = source
	first_launch.clock = GameClock.new(func() -> int: return 3000)
	var first_launch_notices: Array[bool] = []
	first_launch.demo_progress_imported.connect(func() -> void: first_launch_notices.append(true))
	get_root().add_child(first_launch)
	first_launch.set_process(false)
	_expect_true(not first_launch.save_recovery_required and first_launch.demo_save_imported, "genuinely empty Full startup still imports existing Demo progress")
	_expect_true(first_launch.pig_state.name == "Demo Pig" and first_launch.pig_state.daily_points == 17, "first-launch import retains actual Demo progression")
	_expect_eq(first_launch_notices.size(), 1, "first-launch Demo migration still announces exactly one real success")
	_expect_eq(str(first_launch.save_service.load_game().data.release_profile), "full", "first-launch migration persists the Full profile tag")
	first_launch.queue_free()
	await process_frame
	var legacy_target := SaveService.new(base + "/restored_legacy_demo")
	for path: String in [legacy_target.save_path, legacy_target.backup_1_path, legacy_target.backup_2_path]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("{broken original")
		file.close()
	var legacy_session := RecoveryProfileSession.new()
	legacy_session.save_service = legacy_target
	legacy_session.profile_import_source = source
	legacy_session.clock = GameClock.new(func() -> int: return 3000)
	get_root().add_child(legacy_session)
	legacy_session.set_process(false)
	_expect_true(legacy_session.save_recovery_required, "legacy-target fixture begins behind the real startup recovery barrier")
	var legacy_payload: Dictionary = demo_payload.duplicate(true)
	legacy_payload.pig_state.name = "Legacy Pig"
	legacy_payload.pig_state.daily_points = 121
	var legacy_backup := FileAccess.open(legacy_target.backup_2_path, FileAccess.WRITE)
	legacy_backup.store_string(JSON.stringify(legacy_payload))
	legacy_backup.close()
	_expect_true(legacy_session.retry_save_recovery() and not legacy_session.save_recovery_required, "valid legacy Demo data restored inside the current target can still migrate during recovery")
	_expect_true(legacy_session.pig_state.name == "Legacy Pig" and legacy_session.pig_state.daily_points == 121, "legacy target migration uses the restored target rather than the unrelated Demo source")
	_expect_eq(str(legacy_target.load_game().data.release_profile), "full", "legacy target migration retains the supported Full profile conversion")
	_expect_eq(FileAccess.get_file_as_bytes(source.save_path), source_bytes, "all recovery and first-launch paths preserve the separate Demo source bytes")
	legacy_session.queue_free()
	await process_frame
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_life_plans() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "life plans load with the full content catalog")
	_expect_eq(catalog.life_plans.size(), 6, "six permanent optional life plans are available")
	for plan: Dictionary in catalog.life_plans:
		var state := PigState.new()
		state.familiarity_level = 10
		var unrelated: Dictionary = state.to_dict().duplicate(true)
		for field: String in ["active_life_plan", "life_plan_progress", "life_plan_entries"]:
			unrelated.erase(field)
		var update: Dictionary = LifePlanRules.preview_advance(plan, state, 599.0)
		_expect_true((update.new_entries as Array).is_empty(), "%s cannot record a note before its threshold" % plan.id)
		LifePlanRules.apply_advance(update, state)
		update = LifePlanRules.preview_advance(plan, state, 1.0)
		_expect_eq(update.new_entries, [str((plan.entries as Array)[0].id)], "%s records its first permanent note exactly once" % plan.id)
		LifePlanRules.apply_advance(update, state)
		_expect_eq(LifePlanRules.earned_entries(plan, state), 1, "%s retains the first note" % plan.id)
		_expect_eq(LifePlanRules.preview_advance(plan, state, 1.0).new_entries, [], "%s cannot record the same first note twice" % plan.id)
		LifePlanRules.apply_advance(LifePlanRules.preview_advance(plan, state, GameClock.MAX_OFFLINE_SECONDS), state)
		_expect_eq(state.life_plan_progress[str(plan.id)], 5400.0, "%s caps progress at its final entry" % plan.id)
		_expect_true(LifePlanRules.is_complete(plan, state), "%s records all three entries without a claim window" % plan.id)
		_expect_eq(LifePlanRules.preview_advance(plan, state, 86400.0), {}, "%s cannot overflow into another plan or repeat its notes" % plan.id)
		var after: Dictionary = state.to_dict().duplicate(true)
		for field: String in ["active_life_plan", "life_plan_progress", "life_plan_entries"]:
			after.erase(field)
		_expect_eq(after, unrelated, "%s changes no currency, familiarity, simulation state or original collections" % plan.id)
		for invalid_seconds: float in [-1.0, 0.0, INF, NAN]:
			_expect_eq(LifePlanRules.preview_advance(plan, state, invalid_seconds), {}, "%s rejects invalid elapsed time without losing progress" % plan.id)
	var pillow: Dictionary = catalog.get_item("life_plans", "plan_pillow_notes")
	var state := PigState.new()
	state.familiarity_level = 8
	state.owned_furniture.append_array(["furn_pillow_cloud", "furn_nightlight_moon", "furn_blanket_roll"])
	_expect_eq(LifePlanRules.room_rate(pillow, state), 1.0, "unplaced owned furniture grants no plan inspiration")
	state.placed_furniture["sleep_2"] = "furn_pillow_cloud"
	_expect_true(is_equal_approx(LifePlanRules.room_rate(pillow, state), 1.2), "a placed inspiration item gently boosts progress")
	state.placed_furniture["sleep_wall"] = "furn_nightlight_moon"
	state.placed_furniture["sleep_3"] = "furn_blanket_roll"
	_expect_true(is_equal_approx(LifePlanRules.room_rate(pillow, state), 1.4), "room inspiration caps at two matching items")
	_expect_eq(LifePlanRules.behavior_inspiration(pillow, {"tags":["sleep", "quiet"]}), 10.0, "matching completed behaviors grant one bounded inspiration bonus")
	_expect_eq(LifePlanRules.behavior_inspiration(pillow, {"tags":["food"]}), 0.0, "unrelated behavior does not grant inspiration")
	var base := "user://piggy_life_plan_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog = catalog
	session.loaded_successfully = true
	session.clock = GameClock.new(func() -> int: return 3000)
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(catalog, session.ROOM_SLOTS)
	_expect_true(not session.select_life_plan("plan_pillow_notes"), "new pigs are not assigned plans before familiarity two")
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[7]
	session.pig_state.familiarity_level = 8
	session.pig_state.tutorial_skipped = true
	_expect_true(session.select_life_plan("plan_pillow_notes"), "the facade persists an unlocked chosen plan")
	_expect_true(not session.select_life_plan("missing_plan"), "unknown permanent plan IDs cannot be selected")
	var economy_before: Array = [session.pig_state.daily_points, session.pig_state.familiarity_xp]
	session.call("_advance_life_plan", 600.0)
	_expect_eq(session.pig_state.life_plan_entries, ["note_pillow_1"], "the real session commits a milestone note")
	_expect_eq(session.save_service.load_game().data.pig_state.life_plan_entries, ["note_pillow_1"], "a visible milestone is already durable")
	_expect_eq([session.pig_state.daily_points, session.pig_state.familiarity_xp], economy_before, "plans do not accelerate the progression economy")
	_expect_true(session.select_life_plan("plan_snack_reviews"), "plans can be switched without reset or penalty")
	_expect_eq(session.pig_state.life_plan_progress["plan_pillow_notes"], 600.0, "switching keeps another plan's accumulated progress")
	_expect_true(session.pause_life_plan(), "the facade can pause the optional plan")
	_expect_eq(session.call("_advance_life_plan", 86400.0), {}, "paused plans do not invent progress")
	_expect_true(session.select_life_plan("plan_pillow_notes"), "paused plans can be resumed")
	var report: Dictionary = session.handle_runtime_resume(3000, 4800)
	_expect_eq(session.pig_state.life_plan_progress["plan_pillow_notes"], 2400.0, "runtime resume uses the accepted offline interval")
	_expect_eq(report.get("life_plan_entries", []), ["note_pillow_2"], "offline summaries report only newly earned plan notes")
	var persisted: Dictionary = session.save_service.load_game().data
	_expect_true(bool(session.save_service.call("_is_valid_game_payload", persisted)), "plan state is part of the validated atomic progression payload")
	var reloaded: Node = GameSessionScript.new()
	reloaded.catalog = catalog
	reloaded.loaded_successfully = true
	reloaded.save_service = session.save_service
	reloaded.clock = GameClock.new(func() -> int: return 4800)
	reloaded.call("_load_or_create_game")
	_expect_eq(reloaded.pig_state.life_plan_progress, session.pig_state.life_plan_progress, "reopening consumes the same offline anchor without duplicate plan time")
	_expect_eq(reloaded.pig_state.life_plan_entries, session.pig_state.life_plan_entries, "reopening cannot duplicate durable notes")
	var before_clock_rewind: Dictionary = reloaded.pig_state.to_dict().duplicate(true)
	reloaded.handle_runtime_resume(4800, 4700)
	_expect_eq(reloaded.pig_state.to_dict(), before_clock_rewind, "clock reversal cannot reset or reduce plan progress")
	for invalid: Dictionary in [
		{"active_life_plan":17}, {"active_life_plan":"missing_plan"}, {"life_plan_progress":[]},
		{"life_plan_progress":{"missing_plan":1.0}}, {"life_plan_progress":{"plan_pillow_notes":-1.0}},
		{"life_plan_progress":{"plan_pillow_notes":INF}}, {"life_plan_progress":{"plan_pillow_notes":5401.0}},
		{"life_plan_entries":["missing_note"]}, {"life_plan_entries":["note_pillow_1", "note_pillow_1"]},
		{"life_plan_entries":["note_pillow_3"]},
	]:
		var malformed: Dictionary = persisted.duplicate(true)
		(malformed.pig_state as Dictionary).merge(invalid, true)
		_expect_true(not bool(session.save_service.call("_is_valid_game_payload", malformed)), "invalid plan types, IDs, progress or unearned notes cannot displace valid saves")
	var legacy: Dictionary = persisted.duplicate(true)
	for field: String in ["active_life_plan", "life_plan_progress", "life_plan_entries"]:
		(legacy.pig_state as Dictionary).erase(field)
	for schema: int in 5:
		legacy["schema_version"] = schema
		_expect_true(bool(session.save_service.call("_is_valid_game_payload", session.save_service.migrate(legacy))), "legacy schema %d remains compatible without new plan fields" % schema)
	var state_before_failure: Dictionary = session.pig_state.to_dict().duplicate(true)
	var bytes_before_failure: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(session.save_service.temp_path))
	_expect_true(not session.select_life_plan("plan_snack_reviews"), "plan selection rolls back if the atomic checkpoint cannot be opened")
	_expect_eq(session.pig_state.to_dict(), state_before_failure, "failed plan selection preserves every progression field")
	_expect_true(not session.pause_life_plan(), "failed pause cannot silently stop the saved plan")
	_expect_eq(session.pig_state.to_dict(), state_before_failure, "failed pause preserves progress and entries")
	_expect_eq(session.call("_advance_life_plan", 3000.0), {}, "failed new-note commit does not announce an earned entry")
	_expect_eq(session.pig_state.to_dict(), state_before_failure, "failed new-note commit rolls back the whole proposed advancement")
	_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), bytes_before_failure, "failed plan commands preserve committed save bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_service.temp_path))
	session.set("_life_plan_checkpoint_retry", 0.0)
	session.call("_advance_life_plan", 3000.0)
	_expect_true(LifePlanRules.is_complete(pillow, session.pig_state), "a recovered checkpoint can finish the same plan without lost earlier notes")
	var demo := ContentCatalog.new()
	demo.load_all()
	demo.apply_demo_profile()
	_expect_eq(demo.life_plans.size(), 1, "the Demo exposes one sleep-only plan")
	_expect_true(not demo.has_item("life_plans", "plan_snack_reviews"), "full-only plans cannot leak into the Demo catalog")
	session.free()
	reloaded.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_pig_only_policy() -> void:
	for factor: float in [0.5, 0.75, 1.0, 1.25, 1.5]:
		var full_size: Vector2i = DesktopFramePolicy.companion_window_size(factor)
		var size: Vector2i = DesktopFramePolicy.companion_window_size(factor, true)
		_expect_eq(full_size.x - size.x, 188, "pig-only windows remove the entire control rail")
		var minimum: Vector2i = DesktopFramePolicy.minimum_companion_window_size(factor, true)
		_expect_true(minimum.x >= ceili(280.0 * factor) + 16 and minimum.y >= ceili(230.0 * factor) + 16, "pig-only minimum geometry keeps the scaled character whole")
		_expect_eq(DesktopFramePolicy.character_area_width(float(size.x), true), float(size.x), "pig-only roaming uses the compact window without an invisible rail")
		var rect := Rect2(8, 8, 280.0 * factor, 230.0 * factor)
		var polygon: PackedVector2Array = DesktopFramePolicy.mouse_passthrough_polygon(rect, size, true, true)
		_expect_eq(polygon.size(), 4, "pig-only mouse capture has no hidden control or memory corridor")
		_expect_true(Geometry2D.is_point_in_polygon(rect.get_center(), polygon), "the standalone pig keeps an interactive center")
		_expect_true(not Geometry2D.is_point_in_polygon(Vector2(size.x - 4, 4), polygon), "empty desktop space is not captured by hidden controls")
	var screens: Array[Rect2i] = [Rect2i(0, 0, 1280, 720)]
	_expect_true(DesktopFramePolicy.pig_has_accessible_region(Rect2i(100, 100, 140, 115), screens), "visible small standalone pigs stay accessible")
	_expect_true(not DesktopFramePolicy.pig_has_accessible_region(Rect2i(-280, 200, 280, 230), screens), "offscreen standalone pigs require docking recovery")
	var singleton: Node = root.get_node("GameSession")
	var state_before: bool = singleton.desktop_mode
	singleton.desktop_mode = true
	var pig_script: Script = load("res://game/scripts/ui/pig_visual.gd") as Script
	var pig: Control = pig_script.new() as Control
	pig.size = Vector2(280, 230)
	pig.dragging_enabled = false
	root.add_child(pig)
	pig.set_process(false)
	var context_requests: Array[Vector2] = []
	var drag_requests: Array[bool] = []
	var interactions: Array[String] = []
	pig.desktop_context_requested.connect(func(point: Vector2) -> void: context_requests.append(point))
	pig.desktop_drag_requested.connect(func() -> void: drag_requests.append(true))
	pig.pressed.connect(func(kind: String) -> void: interactions.append(kind))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(140, 115)
	pig.call("_gui_input", right)
	_expect_eq(context_requests.size(), 1, "right-click requests the desktop menu instead of interacting")
	_expect_eq(interactions, [], "desktop menu requests cannot farm interactions")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(140, 115)
	pig.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.global_position = Vector2(160, 115)
	pig.call("_gui_input", motion)
	pig.call("_gui_input", motion)
	_expect_eq(drag_requests.size(), 1, "desktop dragging requests one native window gesture")
	_expect_eq(interactions, [], "dragging the standalone window cannot become a pet click")
	press.pressed = false
	pig.call("_gui_input", press)
	_expect_eq(interactions, [], "a release after native dragging cannot become a pet click")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(140, 115)
	pig.call("_gui_input", touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.relative = Vector2(12, 0)
	pig.call("_gui_input", touch_drag)
	pig.call("_gui_input", touch_drag)
	touch.pressed = false
	pig.call("_gui_input", touch)
	_expect_eq(drag_requests.size(), 2, "touch requests exactly one native gesture after its threshold")
	_expect_eq(interactions, [], "touch dragging and release cannot become a pet click")
	singleton.desktop_mode = false
	pig.call("_gui_input", right)
	_expect_eq(context_requests.size(), 1, "room right-clicks cannot invoke a desktop menu")
	singleton.desktop_mode = state_before
	pig.free()
	var base := "user://piggy_pig_only_settings_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.save_service = SaveService.new(base)
	for invalid: Variant in [1, 0, 0.5, "true", "false", null, [], {}]:
		session.save_service.save_settings({"desktop_pig_only":invalid})
		_expect_eq(session.desktop_window_settings().desktop_pig_only, false, "invalid pig-only setting types cannot hide the desktop controls")
	for enabled: bool in [true, false]:
		session.save_service.save_settings({"desktop_pig_only":enabled})
		_expect_eq(session.desktop_window_settings().desktop_pig_only, enabled, "legal pig-only preferences round-trip without affecting progression")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_companions() -> void:
	for value: String in ["", "   ", "名字\n换行", "名字\t制表", "abcdefghijklmnopq"]:
		_expect_eq(CompanionRules.clean_name(value), "", "names reject empty, multiline, control or overlong input")
	_expect_eq(CompanionRules.clean_name("  馒头🐷  "), "馒头🐷", "Unicode names trim only surrounding whitespace")
	_expect_eq(CompanionRules.clean_name("abcdefghijklmnop"), "abcdefghijklmnop", "names accept exactly sixteen characters")
	var base := "user://piggy_companions_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var now: Array[int] = [1000]
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.clock = GameClock.new(func() -> int: return now[0])
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	_expect_true(session.set_pig_name("小云"), "the first pig can be named through the facade")
	var before_rename: Dictionary = session.pig_state.to_dict().duplicate(true)
	_expect_true(session.set_pig_name("云朵"), "the same resident can be renamed after onboarding")
	before_rename.name = "云朵"
	_expect_eq(session.pig_state.to_dict(), before_rename, "renaming changes no progression, collection or onboarding state")
	session.pig_state.daily_points = 321
	session.pig_state.familiarity_xp = 750
	session.pig_state.familiarity_level = 8
	session.select_life_plan("plan_pillow_notes")
	session.call("_advance_life_plan", 600.0)
	var first: Dictionary = session.pig_state.to_dict().duplicate(true)
	_expect_true(session.add_companion("馒头"), "a second pig can join without replacing the first")
	_expect_eq(session.pig_state.to_dict(), first, "admitting a resident keeps the current pig unchanged")
	_expect_eq(session.companion_summaries().size(), 2, "both residents appear in the persistent roster")
	_expect_true(session.switch_companion("pig_2"), "the facade switches to a permanent resident ID")
	_expect_eq(session.pig_state.name, "馒头", "new residents keep their chosen names")
	_expect_eq(session.pig_state.daily_points, 70, "new pigs cannot inherit another resident's points")
	_expect_eq(session.pig_state.familiarity_level, 1, "new pigs start their independent familiarity")
	_expect_eq(session.pig_state.life_plan_entries, [], "new pigs cannot inherit another resident's journal")
	_expect_true(session.set_pig_name(" 馒头🐷 "), "the current second pig can be renamed independently")
	session.pig_state.daily_points = 91
	session.save_game()
	var photo_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	photo_image.fill(Color.PINK)
	session.pig_state.discovered_events.append("event_move_in")
	_expect_true(session.store_event_photo("event_move_in", photo_image), "a second resident can durably store an event photo")
	var second_photo: String = session.event_photo_path("event_move_in")
	_expect_true(second_photo.begins_with(base + "/companions/pig_2/photos/"), "per-resident photos cannot overwrite legacy pig photos")
	_expect_eq(session.manual_screenshot_directory(), base + "/companions/pig_2/screenshots", "manual screenshot directories are resident-specific")
	now[0] = 4600
	_expect_true(session.switch_companion("pig_1"), "the original pig remains selectable after time away")
	_expect_eq(session.pig_state.name, "云朵", "switching restores the correct renamed original pig")
	_expect_eq(session.pig_state.daily_points, 334, "a waiting resident receives only the accepted one-hour offline reward")
	_expect_eq(session.pig_state.life_plan_entries, ["note_pillow_1", "note_pillow_2"], "a waiting resident advances its own saved project")
	_expect_eq(session.event_photo_path("event_move_in"), "", "another resident's photo cannot appear in the current album")
	_expect_true(FileAccess.file_exists(second_photo), "switching keeps the other resident's photo bytes")
	var roster_before: Dictionary = (session.get("_companions") as Dictionary).duplicate(true)
	var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(session.save_service.temp_path))
	_expect_true(not session.switch_companion("pig_2"), "failed switch checkpoints cannot activate the target")
	_expect_eq(session.active_companion_id, "pig_1", "failed switching restores the current permanent ID")
	_expect_eq(session.pig_state.to_dict(), state_before, "failed switching rolls back every live progression field")
	_expect_eq(session.get("_companions"), roster_before, "failed switching preserves all resident snapshots")
	_expect_true(not session.add_companion("小满"), "failed admission cannot create a phantom resident")
	_expect_true(not session.set_pig_name("改名失败"), "failed rename cannot change the displayed name")
	_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), bytes_before, "failed group commands preserve the committed main bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_service.temp_path))
	_expect_true(session.switch_companion("pig_2"), "switching succeeds after storage recovers")
	_expect_eq(session.pig_state.daily_points, 104, "the outgoing pig's one-hour wake interval is settled once, not reclaimed on switching back")
	_expect_true(session.switch_companion("pig_1"), "switching back at the same clock anchor works")
	_expect_eq(session.pig_state.daily_points, 334, "repeated switching cannot farm offline points")
	_expect_true(session.add_companion("馒头🐷"), "same display names are allowed because identities are permanent IDs")
	_expect_true(session.add_companion("小满"), "four residents can coexist without shared rewards")
	_expect_true(not session.add_companion("第五只"), "admission respects the explicit four-resident capacity")
	_expect_true(not session.switch_companion("../pig_2"), "unknown or path-like IDs cannot switch residents")
	session.desktop_mode = true
	_expect_true(not session.switch_companion("pig_2"), "desktop switching cannot leave a locked new pig in a native companion window")
	session.desktop_mode = false
	var payload: Dictionary = session.save_service.load_game().data
	_expect_eq(payload.companions.size(), 4, "all residents share one atomic save and rotating backups")
	for patch: Dictionary in [{"companions":[]}, {"companions":{}}, {"active_companion_id":"pig_missing"}, {"active_companion_id":2}]:
		var invalid: Dictionary = payload.duplicate(true)
		invalid.merge(patch, true)
		_expect_true(not bool(session.save_service.call("_is_valid_game_payload", invalid)), "malformed group metadata cannot displace a valid generation")
	var invalid: Dictionary = payload.duplicate(true)
	invalid.companions.pig_3.pig_state.daily_points = -1
	_expect_true(not bool(session.save_service.call("_is_valid_game_payload", invalid)), "inactive resident progress receives the same semantic validation")
	invalid = payload.duplicate(true)
	invalid.companions.pig_1.pig_state.name = "stale mirror"
	_expect_true(not bool(session.save_service.call("_is_valid_game_payload", invalid)), "active mirrors cannot disagree with the resident snapshot")
	invalid = payload.duplicate(true)
	invalid.companions.pig_2.life_photos = {}
	_expect_true(not bool(session.save_service.call("_is_valid_game_payload", invalid)), "resident snapshots cannot nest or add arbitrary payload sections")
	invalid = payload.duplicate(true)
	invalid.companions.pig_2.pig_state.life_photos.event_move_in.path = base + "/photos/photo_move_in.png"
	_expect_true(not bool(session.save_service.call("_is_valid_game_payload", invalid)), "a resident's album cannot alias another resident's canonical photo path")
	var reloaded: Node = GameSessionScript.new()
	reloaded.catalog = session.catalog
	reloaded.loaded_successfully = true
	reloaded.clock = session.clock
	reloaded.save_service = session.save_service
	reloaded.call("_load_or_create_game")
	_expect_eq(reloaded.companion_summaries(), session.companion_summaries(), "reopening restores all four resident names and independent progress")
	_expect_true(reloaded.switch_companion("pig_2"), "reopened resident IDs remain selectable")
	_expect_eq(reloaded.event_photo_path("event_move_in"), second_photo, "the reopened second pig retains its own canonical album")
	now[0] = 8200
	reloaded.set("_last_process_unix", 4600)
	reloaded.switch_companion("pig_1")
	_expect_eq((reloaded.get("_companions") as Dictionary).pig_2.pig_state.daily_points, 117, "switching immediately after wake still settles the outgoing pig's runtime gap")
	reloaded.switch_companion("pig_2")
	_expect_eq(reloaded.pig_state.daily_points, 117, "the outgoing wake interval cannot be reclaimed on switching back")
	var recoverable: Dictionary = session.save_service.load_game().data
	_expect_eq(session.save_service.save_game(recoverable), OK, "the recovery fixture commits the latest whole-roster checkpoint")
	var expected_backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.save_service.backup_1_path)) as Dictionary
	invalid = recoverable.duplicate(true)
	invalid.companions.pig_3.pig_state.daily_points = -1
	var corrupted := FileAccess.open(session.save_service.save_path, FileAccess.WRITE)
	corrupted.store_string(JSON.stringify(invalid))
	corrupted.close()
	var recovered: Dictionary = session.save_service.load_game()
	_expect_true(bool(recovered.ok) and bool(recovered.recovered), "damage in an inactive pig restores a valid whole-roster backup")
	_expect_eq(recovered.data, expected_backup, "whole-roster recovery preserves every resident, active selection and clock anchor of the latest valid backup")
	session.free()
	reloaded.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_pig_performances() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "shared pig performance library loads with ordinary content")
	var library: PigPerformanceLibrary = catalog.performances
	_expect_eq(library.validate(catalog.outfits), [], "performance references and head anchors are valid")
	for kind: String in PigPerformanceLibrary.COUNTS:
		_expect_eq(library.entries(kind).size(), int(PigPerformanceLibrary.COUNTS[kind]), "performance catalog preserves %s count" % kind)
	var model := PigPerformance.new()
	var changed := [0]
	model.changed.connect(func() -> void: changed[0] += 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4512
	_expect_true(not model.start("missing", library, ""), "unknown performance cannot mutate the model")
	_expect_true(not model.start("body_base", library, ""), "raw rig clips cannot be requested as player actions")
	for face: Dictionary in library.entries("faces"):
		_expect_true(model.start(str(face.id), library, ""), "manual %s selects a modular face" % face.id)
		_expect_eq(str(model.snapshot(library).body_id), "body_base", "face uses the same base pig")
		_expect_eq(str(model.snapshot(library).face_id), str(face.id), "face ID remains separate from the body")
		model.stop(true)
	for kind: String in ["poses", "states", "forms"]:
		for entry: Dictionary in library.entries(kind):
			_expect_true(model.start(str(entry.id), library, ""), "%s is available without new currency or a new resident" % entry.id)
			var first: Dictionary = model.snapshot(library)
			_expect_eq(library.kind_for(str(first.body_id)), "clips", "performance uses a real four-frame body clip")
			_expect_eq(library.kind_for(str(first.face_id)), "faces", "performance uses a separate facial rig")
			model.advance(float(entry.duration_seconds) + 0.1, library, "", true, "normal", rng)
			_expect_eq(model.snapshot(library), {}, "temporary %s expires without a reward or penalty" % entry.id)
	for action: Dictionary in library.entries("outfit_actions"):
		_expect_true(not model.start(str(action.id), library, ""), "%s needs the worn outfit" % action.id)
		_expect_true(model.start(str(action.id), library, str(action.outfit_id)), "%s unlocks its cosmetic combination when equipped" % action.id)
		_expect_eq(str(model.snapshot(library).face_id), str(action.face_id), "outfit combo supplies its particular facial response")
		model.stop(true)
	var signals_before: int = changed[0]
	_expect_true(model.start("meme_worker", library, ""), "manual work meme starts an office form")
	model.advance(100.0, library, "", false, "normal", rng)
	_expect_eq(model.active_id, "", "hidden state expires on wall time rather than becoming a burden")
	_expect_eq(changed[0], signals_before + 1, "background expiry never emits a proactive presentation update")
	model.advance(0.1, library, "", true, "normal", rng)
	_expect_eq(changed[0], signals_before + 2, "returning to foreground synchronizes the ordinary pig once")
	_expect_true(model.start("meme_worker", library, ""), "an explicit performance can play during a focus timer")
	var display_signals: int = changed[0]
	model.advance(100.0, library, "outfit_sleepy_cap", false, "normal", rng, true)
	_expect_eq(model.active_id, "", "focus timer suppresses automatic starts but not manual performance expiry")
	_expect_eq(changed[0], display_signals + 1, "visible manual performance returns to normal on time while automatic scheduling stays blocked")
	var focus_rng_state: int = rng.state
	model.advance(1000.0, library, "outfit_sleepy_cap", false, "normal", rng, true)
	_expect_eq(rng.state, focus_rng_state, "foreground focus work never consumes random automatic outfit opportunities")
	var rng_before: int = rng.state
	for frequency: String in ["frequent", "normal", "rare", "off"]:
		model.advance(1000.0, library, "outfit_sleepy_cap", false, frequency, rng)
		_expect_eq(model.active_id, "", "background %s never starts an outfit performance" % frequency)
	_expect_eq(rng.state, rng_before, "background inactivity does not consume random outfit decisions")
	model.advance(1.0, library, "outfit_sleepy_cap", true, "frequent", rng)
	_expect_eq(model.active_id, "", "foreground return cannot catch up a missed background action")
	var sleepy: Dictionary = library.outfit_action("outfit_sleepy_cap")
	var ordinary: Dictionary = library.outfit_action("outfit_round_glasses")
	_expect_true(float(sleepy.chance) > float(ordinary.chance) and str(sleepy.pose_id) == "pose_flat", "sleepwear increases only its cosmetic floor-nap probability")
	var successes: int = 0
	for attempt: int in 100:
		model.stop()
		model.advance(60.0, library, "outfit_sleepy_cap", true, "frequent", rng)
		if model.active_id == str(sleepy.id):
			successes += 1
	_expect_true(successes > 0 and successes < 100, "foreground outfit combinations occur sometimes rather than continuously")
	var session := GameSessionScript.new()
	_expect_eq(session.catalog.load_all(), [], "performance API fixture loads real catalogs")
	_expect_eq(session.performance_frequency(), "normal", "performance frequency inherits the modern companion preference")
	session.reduce_desktop_action_frequency = true
	_expect_eq(session.performance_frequency(), "rare", "legacy reduced actions also reduce new outfit performances")
	session.desktop_companion.frequency = "off"
	_expect_eq(session.performance_frequency(), "off", "legacy reduction cannot turn off-frequency performances back on")
	session.desktop_companion.frequency = "normal"
	var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var simulation_before: Dictionary = session.simulation.to_dict().duplicate(true)
	_expect_true(session.perform_pig("meme_ruler"), "GameSession exposes a manual meme request")
	_expect_eq(session.pig_state.to_dict(), state_before, "meme request never writes progression or appearance to save data")
	_expect_eq(session.simulation.to_dict(), simulation_before, "meme request never replaces the reward-bearing simulated behavior")
	_expect_true(not session.perform_pig("action_star_glasses"), "GameSession rejects outfit action without its equipped outfit")
	session.stop_pig_performance()
	_expect_eq(session.pig_performance.snapshot(session.catalog.performances), {}, "manual return clears only the cosmetic state")
	session.save_service = SaveService.new("user://performance_residents")
	session.save_service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	session.clock = GameClock.new(func() -> int: return 1000)
	session.pig_state.name = "First Pig"
	_expect_eq(session.save_game(), OK, "performance resident fixture saves ordinary progress")
	_expect_true(session.add_companion("Second Pig", "personality_shy"), "performance fixture creates a separate named personality")
	_expect_true(session.perform_pig("meme_slack"), "first resident can play a temporary meme")
	_expect_true(session.switch_companion("pig_2"), "resident switching remains available after a performance")
	_expect_eq(session.pig_performance.snapshot(session.catalog.performances), {}, "switching never carries another resident's meme or face phase")
	_expect_eq(session.pig_state.name, "Second Pig", "shared art does not merge resident names")
	_expect_eq(session.pig_state.personality_id, "personality_shy", "shared art preserves each resident's independent personality")
	session.free()


func _test_personalities() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "personality catalog validates with all content")
	_expect_eq(catalog.personalities.size(), 5, "five equal-access personalities are available")
	var rng := RandomNumberGenerator.new()
	rng.seed = 916
	var rolls: Array[String] = []
	for draw: int in 100:
		rolls.append(PersonalityRules.resolve_choice("random", catalog.personalities, rng))
	_expect_true(rolls.all(func(id: String) -> bool: return id in PersonalityRules.IDS), "random personality never yields an unknown or unassigned ID")
	_expect_true(PersonalityRules.IDS.all(func(id: String) -> bool: return id in rolls), "seeded random generation reaches all five personalities")
	rng.seed = 916
	var replay: Array[String] = []
	for draw: int in 100:
		replay.append(PersonalityRules.resolve_choice("random", catalog.personalities, rng))
	_expect_eq(replay, rolls, "injected random source is deterministic for regression tests")
	_expect_eq(PersonalityRules.resolve_choice("unknown", catalog.personalities, rng), "", "unknown player choice cannot silently become random")
	var base: String = "user://personality_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	for profile: Dictionary in catalog.personalities:
		var session: Node = GameSessionScript.new()
		session.catalog.load_all()
		session.loaded_successfully = true
		session.clock = GameClock.new(func() -> int: return 1000)
		session.save_service = SaveService.new(base + "/" + str(profile.id))
		session.save_service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
		var original: Dictionary = session.pig_state.to_dict().duplicate(true)
		_expect_true(session.initialize_current_companion("小猪", str(profile.id)), "%s initial setup is atomic" % profile.id)
		original.name = "小猪"
		original.personality_id = profile.id
		original.tutorial_step = 1
		_expect_eq(session.pig_state.to_dict(), original, "%s setup changes only name, personality and introductory step" % profile.id)
		_expect_true(not session.choose_initial_personality("random"), "%s cannot be rerolled after adoption" % profile.id)
		_expect_true(session.set_pig_name("新名字"), "%s can still be renamed" % profile.id)
		_expect_eq(session.pig_state.personality_id, profile.id, "%s renaming preserves personality" % profile.id)
		for kind: String in ["pet", "poke"]:
			var reaction: Dictionary = session.interact_with_pig(kind)
			var expected: Dictionary = (profile[kind] as Dictionary).duplicate(true)
			expected.kind = kind
			_expect_eq(reaction, expected, "%s %s uses its own expression and wording" % [profile.id, kind])
		_expect_true(session.pig_state.daily_points == 72 and session.pig_state.familiarity_xp == 2 and session.pig_state.satiety == 72.0 and session.pig_state.energy == 68.0, "%s has exactly the same rewards and needs as every other pig" % profile.id)
		var before_reload: Dictionary = session.pig_state.to_dict().duplicate(true)
		before_reload.interaction_counts = JSON.parse_string(JSON.stringify(before_reload.interaction_counts)) as Dictionary
		session.call("_load_or_create_game")
		_expect_eq(session.pig_state.to_dict(), before_reload, "%s restart never rerolls or resets progress" % profile.id)
		session.free()
	var group: Node = GameSessionScript.new()
	group.catalog.load_all()
	group.loaded_successfully = true
	group.clock = GameClock.new(func() -> int: return 1000)
	group.save_service = SaveService.new(base + "/group")
	group.save_service.configure_content_ids(group.catalog, group.ROOM_SLOTS)
	_expect_true(group.initialize_current_companion("甲", "personality_lively"), "first resident can explicitly choose lively")
	_expect_true(group.add_companion("乙", "personality_tsundere"), "second resident independently chooses tsundere")
	_expect_true(group.add_companion("丙"), "omitting a newcomer choice rolls a personality once")
	_expect_true(group.add_companion("丁", "personality_shy"), "fourth resident independently chooses shy")
	var summaries: Array[Dictionary] = group.companion_summaries()
	_expect_true(summaries[0].personality_id == "personality_lively" and summaries[1].personality_id == "personality_tsundere" and summaries[2].personality_id in PersonalityRules.IDS and summaries[3].personality_id == "personality_shy", "all resident summaries carry independent permanent personalities")
	for summary: Dictionary in summaries:
		if str(summary.id) != group.active_companion_id:
			_expect_true(group.switch_companion(str(summary.id)), "personality-bearing resident switches through the facade")
		_expect_eq(group.pig_state.personality_id, summary.personality_id, "switching keeps each pig's personality")
		_expect_true(group.set_pig_name("同名"), "same display names do not collapse personalities")
	_expect_true(group.switch_companion("pig_1"), "personality roster can return to the first resident")
	var committed: Dictionary = group.save_service.load_game().data
	for invalid: Variant in [null, true, 1, [], {}, "random", "personality_unknown"]:
		var malformed: Dictionary = committed.duplicate(true)
		malformed.pig_state.personality_id = invalid
		malformed.companions.pig_1.pig_state.personality_id = invalid
		_expect_true(not bool(group.save_service.call("_is_valid_game_payload", malformed)), "invalid active personality type or ID cannot override a safe backup")
		malformed = committed.duplicate(true)
		malformed.companions.pig_2.pig_state.personality_id = invalid
		_expect_true(not bool(group.save_service.call("_is_valid_game_payload", malformed)), "invalid inactive personality also invalidates the whole roster")
	var expected_backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(group.save_service.backup_1_path)) as Dictionary
	var damaged: Dictionary = committed.duplicate(true)
	damaged.pig_state.personality_id = "personality_unknown"
	damaged.companions.pig_1.pig_state.personality_id = "personality_unknown"
	var file := FileAccess.open(group.save_service.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(damaged))
	file.close()
	var recovered: Dictionary = group.save_service.load_game()
	_expect_true(bool(recovered.ok) and recovered.data == expected_backup, "corrupt personality restores the entire valid roster backup")
	group.free()
	var legacy: Node = GameSessionScript.new()
	legacy.catalog.load_all()
	legacy.loaded_successfully = true
	legacy.clock = GameClock.new(func() -> int: return 1000)
	legacy.save_service = SaveService.new(base + "/legacy")
	legacy.save_service.configure_content_ids(legacy.catalog, legacy.ROOM_SLOTS)
	var old_pig: Dictionary = legacy.pig_state.to_dict().duplicate(true)
	old_pig.name = "旧猪"
	old_pig.tutorial_skipped = true
	old_pig.erase("personality_id")
	_expect_eq(legacy.save_service.save_game({"last_saved_unix":1000, "pig_state":old_pig}), OK, "legacy save without personality remains valid schema four")
	legacy.pig_state.personality_id = "personality_foodie"
	legacy.call("_load_or_create_game")
	_expect_eq(legacy.pig_state.personality_id, "", "missing legacy field clears a previous pig's personality instead of inheriting it")
	var legacy_before: Dictionary = legacy.pig_state.to_dict().duplicate(true)
	_expect_true(legacy.choose_initial_personality("personality_lazy"), "legacy resident can opt into one personality without renaming")
	legacy_before.personality_id = "personality_lazy"
	_expect_eq(legacy.pig_state.to_dict(), legacy_before, "legacy personality choice changes no other saved field")
	_expect_true(not legacy.choose_initial_personality("personality_foodie"), "legacy opt-in is also permanent")
	legacy.free()
	var blocked: Node = GameSessionScript.new()
	blocked.catalog.load_all()
	blocked.loaded_successfully = true
	blocked.save_service = SaveService.new(base + "/blocked")
	blocked.save_service.configure_content_ids(blocked.catalog, blocked.ROOM_SLOTS)
	_expect_eq(blocked.save_game(), OK, "failed adoption fixture has committed original progress")
	var before: Dictionary = blocked.pig_state.to_dict().duplicate(true)
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(blocked.save_service.save_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked.save_service.temp_path))
	_expect_true(not blocked.initialize_current_companion("新猪", "personality_foodie", true), "failed adoption cannot commit a name, personality or skipped intro")
	_expect_eq(blocked.pig_state.to_dict(), before, "failed adoption rolls back every field")
	_expect_true(not blocked.choose_initial_personality("random"), "failed legacy opt-in cannot commit a random personality")
	_expect_eq(blocked.pig_state.to_dict(), before, "failed random selection leaves the previous pig intact")
	_expect_eq(FileAccess.get_file_as_bytes(blocked.save_service.save_path), bytes_before, "failed setup preserves original save bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked.save_service.temp_path))
	_expect_true(blocked.initialize_current_companion("", "random", true), "skip onboarding still rolls and saves personality for an unnamed pig")
	var chosen: String = blocked.pig_state.personality_id
	blocked.call("_load_or_create_game")
	_expect_true(blocked.pig_state.name.is_empty() and blocked.pig_state.tutorial_skipped and blocked.pig_state.personality_id == chosen and chosen in PersonalityRules.IDS, "unnamed skipped pig keeps its generated personality on restart")
	blocked.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_content_catalog() -> void:
	var catalog := ContentCatalog.new()
	var errors: Array[String] = catalog.load_all()
	_expect_eq(errors, [], "catalog validates")
	_expect_eq(catalog.furniture.size(), 32, "furniture budget")
	_expect_eq(catalog.snacks.size(), 10, "snack budget")
	_expect_eq(catalog.outfits.size(), 12, "outfit budget")
	_expect_eq(catalog.expressions.size(), 48, "expression budget")
	_expect_eq(catalog.events.size(), 24, "event budget")
	_expect_eq(catalog.achievements.size(), 24, "achievement budget")


func _test_desktop_platform_policy() -> void:
	for server: String in ["Windows", "macOS", "X11", "Wayland", "headless", "web", "unknown"]:
		for transparency_feature: bool in [false, true]:
			for drag_feature: bool in [false, true]:
				var result: Dictionary = DesktopPlatformPolicy.resolve(server, transparency_feature, drag_feature, true, true)
				var positioning: bool = server in ["Windows", "macOS", "X11"]
				var dragging: bool = drag_feature and server in ["Windows", "macOS", "X11", "Wayland"]
				_expect_eq(result.positioning, positioning, "%s only positions windows where global positioning is supported" % server)
				_expect_eq(result.transparency, positioning and transparency_feature, "%s requires implemented polygon passthrough as well as transparency" % server)
				_expect_eq(result.pig_only, positioning and transparency_feature and dragging, "%s cannot hide controls without a safe native-drag/transparent path" % server)
				_expect_eq(result.native_drag, dragging, "%s respects the native drag capability flag" % server)
	for server: String in ["Windows", "macOS", "X11"]:
		var normal: Dictionary = DesktopPlatformPolicy.resolve(server, true, true, false, true)
		_expect_true(not normal.transparency and not normal.pig_only, "an explicit normal-window preference always keeps the controls")
		var controlled: Dictionary = DesktopPlatformPolicy.resolve(server, true, true, true, false)
		_expect_true(controlled.transparency and not controlled.pig_only, "supported transparency does not opt into pig-only mode")
	_expect_eq(DesktopFramePolicy.recommended_fps("run", false, false, true), 4, "minimized desktop throttles rendering without stopping simulation")
	_expect_eq(DesktopFramePolicy.recommended_fps("run", false, false, false), 30, "restoring a minimized active desktop restores its presentation budget")


func _test_texture_cache_budget() -> void:
	var assets := FinalAssetCatalog.new()
	_expect_eq(assets.load_manifest(), [], "texture-budget fixture loads all generated visual routes")
	var data: Dictionary = JsonStore.read_object(FinalAssetCatalog.MANIFEST_PATH)
	var entries: Array = data.entries as Array
	var first_token: String = str(entries[0].covers[0])
	var second_token: String = str(entries[1].covers[0])
	var first: Texture2D = assets.texture_for(first_token)
	var first_size: Vector2 = first.get_size()
	for index: int in range(1, FinalAssetCatalog.MAX_CACHED_ATLASES):
		assets.texture_for(str(entries[index].covers[0]))
	_expect_eq((assets.get("_atlas_cache") as Dictionary).size(), 8, "eight distinct source atlases fit the catalogue-owned cache budget")
	_expect_eq(assets.texture_for(first_token), first, "an unexpired cached texture retains object identity")
	assets.texture_for(str(entries[8].covers[0]))
	_expect_true((assets.get("_atlas_cache") as Dictionary).has(assets.path_for(first_token)), "a recently accessed atlas survives the next eviction")
	_expect_true(not (assets.get("_atlas_cache") as Dictionary).has(assets.path_for(second_token)), "the least recently used source is released instead of the active source")
	for entry: Dictionary in entries:
		var token: String = str(entry.covers[0])
		_expect_true(assets.texture_for(token) != null, "eviction preserves every source's permanent visual route")
		_expect_true((assets.get("_atlas_cache") as Dictionary).size() <= 8, "catalogue strong references stay bounded while browsing all art")
	_expect_eq(first.get_size(), first_size, "external TextureRect owners keep valid textures after catalogue eviction")
	_expect_eq(assets.texture_for(first_token).get_size(), first_size, "an evicted source reloads with the same logical canvas")
	var paths: Dictionary = assets.get("_texture_paths") as Dictionary
	var retained: Dictionary = assets.get("_atlas_cache") as Dictionary
	for path: String in paths.values():
		_expect_true(retained.has(path), "atlas eviction also drops all catalogue-owned frame wrappers for that source")
	_expect_eq(assets.texture_for("behavior:idle", 2), assets.texture_for("performance_body:body_base", 2), "behavior aliases share the same body-frame wrapper rather than allocating another one")
	_expect_eq(assets.texture_for("performance_face:face_quake_left"), assets.texture_for("performance_face:face_shock_left"), "the retired white-eye face ID shares a black-eye glyph without another texture")
	_expect_true(assets.texture_for("missing:token") == null, "missing routes do not consume the cache budget")
	var invalid_manifest_path: String = "user://runtime-cache-invalid-manifest.json"
	var invalid_manifest := FileAccess.open(invalid_manifest_path, FileAccess.WRITE)
	invalid_manifest.store_string(JSON.stringify({"schema_version":0, "ready":false, "provided_by_user":false, "entries":[]}))
	invalid_manifest.close()
	assets.load_manifest(invalid_manifest_path)
	_expect_true((assets.get("_atlas_cache") as Dictionary).is_empty() and (assets.get("_texture_cache") as Dictionary).is_empty(), "a failed manifest reload releases both source and wrapper caches and enables fallback")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_manifest_path))


func _test_final_asset_runtime_catalog() -> void:
	_expect_eq(FinalAssetCatalog.expected_coverage_tokens().size(), 252, "runtime resolver derives the complete permanent final-asset coverage set")
	var base := "user://piggy_final_asset_catalog_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var manifest_path := base + "/manifest.json"
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[{
			"path":"res://game/assets/ui/app_icon.svg",
			"covers":["expression:fixture"],
			"regions":{"expression:fixture":[0, 0, 16, 16]},
		}],
	}))
	manifest.close()
	var assets := FinalAssetCatalog.new()
	_expect_eq(assets.load_manifest(manifest_path, ["expression:fixture"]), [], "ready final-asset manifest loads into the runtime resolver")
	_expect_true(assets.enabled, "ready user-provided final assets enable runtime replacement")
	_expect_eq(assets.path_for("expression:fixture"), "res://game/assets/ui/app_icon.svg", "coverage token resolves to its dedicated resource path")
	_expect_true(assets.texture_for("expression:fixture") is AtlasTexture, "sprite-sheet region resolves to an atlas texture")
	var disabled := FileAccess.open(manifest_path, FileAccess.WRITE)
	disabled.store_string(JSON.stringify({"schema_version":1, "ready":false, "provided_by_user":false, "entries":[]}))
	disabled.close()
	_expect_eq(assets.load_manifest(manifest_path), [], "intentionally pending final assets are not a runtime content error")
	_expect_true(not assets.enabled and assets.texture_for("expression:fixture") == null, "development placeholders remain active while the final manifest is pending")
	var incomplete := FileAccess.open(manifest_path, FileAccess.WRITE)
	incomplete.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[{"path":"res://game/assets/ui/app_icon.svg", "covers":["event:fixture"]}],
	}))
	incomplete.close()
	_expect_true(not assets.load_manifest(manifest_path, ["event:fixture", "behavior:fixture"]).is_empty(), "incomplete runtime coverage rejects a ready manifest")
	_expect_true(not assets.enabled, "incomplete dedicated coverage cannot enable a partial visual replacement")
	var duplicate := FileAccess.open(manifest_path, FileAccess.WRITE)
	duplicate.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[
			{"path":"res://game/assets/ui/app_icon.svg", "covers":["event:fixture"]},
			{"path":"res://game/assets/ui/app_icon.svg", "covers":["event:fixture"]},
		],
	}))
	duplicate.close()
	_expect_true(not assets.load_manifest(manifest_path, ["event:fixture"]).is_empty(), "duplicate runtime coverage tokens reject the ready manifest")
	_expect_true(not assets.enabled, "a malformed ready manifest cannot partially replace visuals")
	var generated_data := {
		"schema_version":1, "ready":false, "provided_by_user":false,
		"visual_ready":true, "generation_authorized":true,
		"entries":[{
			"path":"res://game/assets/ui/app_icon.svg", "covers":["behavior:fixture"],
			"frames":{"behavior:fixture":[[0, 0, 16, 16], [16, 0, 16, 16]]},
			"placements":{"behavior:fixture":[20, 30, 40, 50]}, "full_character":true,
		}],
	}
	var generated := FileAccess.open(manifest_path, FileAccess.WRITE)
	generated.store_string(JSON.stringify(generated_data))
	generated.close()
	_expect_eq(assets.load_manifest(manifest_path, ["behavior:fixture", "audio:fixture"]), [], "authorized visual-only artwork loads without pretending missing audio is complete")
	_expect_true(assets.enabled and not assets.has_token("audio:fixture"), "generated artwork enables only its visual routes")
	_expect_true(assets.is_full_character("behavior:fixture"), "full-character metadata is preserved for expression replacement")
	_expect_eq(assets.placement_for("behavior:fixture"), Rect2(20, 30, 40, 50), "accessory canvas registration is data-driven")
	_expect_eq((assets.texture_for("behavior:fixture", 0) as AtlasTexture).region, Rect2(0, 0, 16, 16), "animation first frame resolves the first atlas region")
	_expect_eq((assets.texture_for("behavior:fixture", 1) as AtlasTexture).region, Rect2(16, 0, 16, 16), "animation next frame resolves a distinct atlas region")
	_expect_eq(assets.texture_for("behavior:fixture", 2), assets.texture_for("behavior:fixture", 0), "animation wraps with a bounded texture cache")
	generated_data.entries[0]["frame_trims"] = {"behavior:fixture":[[2, 3, 10, 11], [20, 2, 8, 12]]}
	generated = FileAccess.open(manifest_path, FileAccess.WRITE)
	generated.store_string(JSON.stringify(generated_data))
	generated.close()
	_expect_eq(assets.load_manifest(manifest_path, ["behavior:fixture"]), [], "trimmed animation frames load into the runtime resolver")
	_expect_eq(assets.texture_for("behavior:fixture", 0).get_size(), Vector2(16, 16), "trimming keeps the original logical canvas size")
	_expect_eq((assets.texture_for("behavior:fixture", 0) as AtlasTexture).region, Rect2(2, 3, 10, 11), "first animation frame excludes empty alpha padding")
	_expect_eq((assets.texture_for("behavior:fixture", 0) as AtlasTexture).margin, Rect2(2, 3, 6, 5), "first frame keeps its original registration")
	_expect_eq((assets.texture_for("behavior:fixture", 1) as AtlasTexture).region, Rect2(20, 2, 8, 12), "next animation frame uses its own trimmed region")
	_expect_eq((assets.texture_for("behavior:fixture", 1) as AtlasTexture).margin, Rect2(4, 2, 8, 4), "next frame keeps independent canvas margins")
	for bad_trims: Array in [[[0, 0, 17, 16], [16, 0, 16, 16]], [[0, 0, 16, 16]], [[0, 0, 0, 16], [16, 0, 16, 16]]]:
		generated_data.entries[0].frame_trims["behavior:fixture"] = bad_trims
		generated = FileAccess.open(manifest_path, FileAccess.WRITE)
		generated.store_string(JSON.stringify(generated_data))
		generated.close()
		_expect_true(not assets.load_manifest(manifest_path, ["behavior:fixture"]).is_empty(), "malformed or out-of-frame trims are rejected")
		_expect_true(not assets.enabled, "invalid trim metadata cannot enable partial visuals")
	generated_data.entries[0].erase("frame_trims")
	generated_data.generation_authorized = false
	generated = FileAccess.open(manifest_path, FileAccess.WRITE)
	generated.store_string(JSON.stringify(generated_data))
	generated.close()
	_expect_true(not assets.load_manifest(manifest_path, ["behavior:fixture"]).is_empty(), "unauthorized generated artwork is rejected")
	_expect_true(not assets.enabled, "generation authorization cannot be bypassed by visual readiness")
	generated_data.generation_authorized = true
	generated_data.entries[0].frames["behavior:fixture"] = [["bad", 0, 16, 16]]
	generated = FileAccess.open(manifest_path, FileAccess.WRITE)
	generated.store_string(JSON.stringify(generated_data))
	generated.close()
	_expect_true(not assets.load_manifest(manifest_path, ["behavior:fixture"]).is_empty(), "malformed animation rectangles are rejected without numeric conversion errors")
	_expect_true(not assets.enabled, "invalid animation metadata cannot enable a partial visual set")
	_expect_true(not assets.is_full_character("behavior:fixture"), "failed loads clear full-character routing")
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_demo_profile() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "demo fixture starts from the validated full catalog")
	catalog.apply_demo_profile()
	_expect_eq(catalog.furniture.size(), 6, "demo exposes six furniture items")
	_expect_eq(catalog.expressions.size(), 8, "demo exposes eight expressions")
	_expect_eq(catalog.events.size(), 4, "demo exposes four memories")
	_expect_eq(catalog.achievements.size(), 0, "demo does not submit full-game Steam achievements")
	for event: Dictionary in catalog.events:
		_expect_eq(str(event.get("time", "")), "any", "demo memory is independent of the player's real-world schedule: %s" % event.id)
		_expect_eq((event.get("rewards", {}) as Dictionary).get("achievements", []), [], "demo memory strips full-game platform rewards: %s" % event.id)
	for furniture: Dictionary in catalog.furniture:
		_expect_eq(str(furniture.get("area", "")), "sleep", "demo furniture remains inside its single room area: %s" % furniture.id)
	_expect_eq(ReleaseProfile.DEMO_DESKTOP_DOCKS, ["bottom", "left"], "demo desktop mode intentionally limits dock appearances")
	_expect_eq(ReleaseProfile.desktop_docks(), ["bottom", "left", "right"], "full desktop profile exposes all three supported dock positions as typed strings")
	_expect_true(ReleaseProfile.save_relative_root("full") != ReleaseProfile.save_relative_root("demo"), "full and demo use isolated relative save roots")
	_expect_true(ReleaseProfile.save_base_dir("full") != ReleaseProfile.save_base_dir("demo"), "full and demo use isolated user directories")
	var base := "user://piggy_demo_migration_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var demo_state := PigState.new()
	demo_state.unlocked_expressions.append("expr_sleepy_pillow")
	demo_state.discovered_events.append("event_pillow_migration")
	demo_state.seen_events.append("event_pillow_migration")
	var service := SaveService.new(base)
	_expect_eq(service.save_game({"release_profile":"demo","last_saved_unix":1,"pig_state":demo_state.to_dict()}), OK, "demo uses the production save schema")
	var loaded: Dictionary = service.load_game()
	var restored := PigState.new()
	restored.load_dict(loaded.data.pig_state)
	var full_catalog := ContentCatalog.new()
	_expect_eq(full_catalog.load_all(), [], "full catalog remains available for demo migration")
	_expect_true(full_catalog.has_item("expressions", restored.unlocked_expressions[0]), "full game recognizes a demo expression ID")
	_expect_true(full_catalog.has_item("events", restored.seen_events[0]), "full game recognizes a demo event ID")
	var completion_session: Node = GameSessionScript.new()
	completion_session.catalog = catalog
	completion_session.save_service = service
	for event: Dictionary in catalog.events:
		var event_id: String = str(event.get("id", ""))
		completion_session.pig_state.discovered_events.append(event_id)
		completion_session.pig_state.seen_events.append(event_id)
	_expect_true(completion_session.is_demo_complete("demo"), "Demo completion requires every profiled memory")
	_expect_true(completion_session.should_show_demo_complete("demo"), "unacknowledged Demo completion remains pending")
	var completion_announcements: Array[bool] = []
	completion_session.demo_complete_ready.connect(func() -> void: completion_announcements.append(true))
	completion_session.call("_sync_demo_state", true, "demo")
	_expect_eq(completion_announcements.size(), 1, "Demo completion announces once when the final memory is complete")
	_expect_true(completion_session.mark_demo_completion_seen("demo"), "continuing from Demo completion commits its acknowledgement")
	_expect_true(completion_session.pig_state.demo_completion_seen, "Demo completion acknowledgement remains in session state")
	var completion_save: Dictionary = service.load_game()
	_expect_true(
		bool(completion_save.get("ok", false)) and bool(completion_save.data.pig_state.demo_completion_seen),
		"Demo completion acknowledgement persists in the progression save"
	)
	_expect_true(not completion_session.should_show_demo_complete("demo"), "acknowledged Demo completion no longer blocks startup")
	completion_session.call("_sync_demo_state", true, "demo")
	_expect_eq(completion_announcements.size(), 1, "later Demo events do not reopen an acknowledged completion page")
	_expect_true(not completion_session.mark_demo_completion_seen("demo"), "Demo completion acknowledgement is idempotent")
	completion_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_profile_save_migration() -> void:
	var base := "user://piggy_profile_migration_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var demo_service := SaveService.new(base + "/demo")
	var demo_state := PigState.new()
	demo_state.name = "试玩猪咪"
	demo_state.daily_points = 321
	demo_state.discovered_events = ["event_move_in"]
	var demo_photo_dir := demo_service.base_dir + "/photos"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(demo_photo_dir))
	var demo_photo_path := demo_photo_dir + "/photo_move_in.png"
	var demo_photo := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	demo_photo.fill(Color("#d9879b"))
	_expect_eq(demo_photo.save_png(demo_photo_path), OK, "demo migration fixture stores a real event photo")
	demo_state.life_photos = {
		"event_move_in": {
			"photo_id":"photo_move_in",
			"path":demo_photo_path,
			"captured_unix":1,
		},
	}
	_expect_eq(demo_service.save_game({"release_profile":"demo", "last_saved_unix":1, "pig_state":demo_state.to_dict()}), OK, "demo migration fixture saves isolated progress")
	var full_service := SaveService.new(base + "/full")
	var session: Node = GameSessionScript.new()
	session.save_service = full_service
	var import_signal := [false]
	session.demo_progress_imported.connect(func() -> void: import_signal[0] = true)
	var imported: Dictionary = session.call("_load_game_with_profile_import", "full", demo_service) as Dictionary
	_expect_true(bool(imported.get("ok", false)), "empty full profile imports valid demo progress")
	_expect_true(session.demo_save_imported and bool(import_signal[0]), "successful demo-to-full import records its startup notice and emits the production visibility signal")
	_expect_eq(str(imported.data.get("release_profile", "")), "full", "imported save is relabeled as full profile data")
	_expect_eq(str(imported.data.pig_state.name), "试玩猪咪", "demo pig identity survives one-way import")
	_expect_eq(int(imported.data.pig_state.daily_points), 321, "demo progression balance survives one-way import")
	var imported_photo_path: String = str(imported.data.pig_state.life_photos.event_move_in.path)
	_expect_true(imported_photo_path.begins_with(full_service.base_dir + "/photos/") and FileAccess.file_exists(imported_photo_path), "demo event photo is copied into the full profile directory")
	_expect_eq(str(demo_service.load_game().data.get("release_profile", "")), "demo", "one-way import does not rewrite the source demo save")
	var full_state := PigState.new()
	full_state.name = "正式猪咪"
	_expect_eq(full_service.save_game({"release_profile":"full", "last_saved_unix":2, "pig_state":full_state.to_dict()}), OK, "existing full progress fixture replaces the imported target")
	demo_state.name = "更新的试玩猪咪"
	_expect_eq(demo_service.save_game({"release_profile":"demo", "last_saved_unix":3, "pig_state":demo_state.to_dict()}), OK, "demo source can continue independently after import")
	var target_wins: Dictionary = session.call("_load_game_with_profile_import", "full", demo_service) as Dictionary
	_expect_eq(str(target_wins.data.pig_state.name), "正式猪咪", "existing full progress is never overwritten by a later demo save")
	_expect_true(not session.demo_save_imported, "normal full-profile load does not report a repeated migration")
	var full_source := SaveService.new(base + "/full_source")
	_expect_eq(full_source.save_game({"release_profile":"full", "last_saved_unix":4, "pig_state":full_state.to_dict()}), OK, "reverse-import fixture stores full progress")
	var demo_target := SaveService.new(base + "/demo_target")
	var reverse_session: Node = GameSessionScript.new()
	reverse_session.save_service = demo_target
	var reverse_result: Dictionary = reverse_session.call("_load_game_with_profile_import", "demo", full_source) as Dictionary
	_expect_true(not bool(reverse_result.get("ok", false)) and not FileAccess.file_exists(demo_target.save_path), "demo refuses to import or mutate full-profile progress")
	var legacy_demo_target := SaveService.new(base + "/legacy_demo_target")
	reverse_session.save_service = legacy_demo_target
	var legacy_demo: Dictionary = reverse_session.call("_load_game_with_profile_import", "demo", demo_service) as Dictionary
	_expect_true(bool(legacy_demo.get("ok", false)), "new isolated demo directory can migrate a legacy demo-profile save")
	_expect_eq(str(legacy_demo.data.get("release_profile", "")), "demo", "legacy demo migration remains a demo-profile save")
	var damaged_target := SaveService.new(base + "/damaged_full")
	var damaged_file := FileAccess.open(damaged_target.save_path, FileAccess.WRITE)
	damaged_file.store_string("{broken")
	damaged_file.close()
	var damaged_session: Node = GameSessionScript.new()
	damaged_session.save_service = damaged_target
	var damaged_result: Dictionary = damaged_session.call("_load_game_with_profile_import", "full", demo_service) as Dictionary
	_expect_true(not bool(damaged_result.get("ok", false)) and bool(damaged_result.get("had_files", false)), "damaged full-profile files block automatic demo import for explicit recovery")
	_expect_true(not damaged_session.demo_save_imported, "damaged target is not mislabeled as a successful migration")
	var missing_photo_service := SaveService.new(base + "/missing_photo_demo")
	var missing_photo_state := PigState.new()
	missing_photo_state.discovered_events = ["event_move_in"]
	missing_photo_state.life_photos = {
		"event_move_in": {
			"photo_id":"photo_move_in",
			"path":missing_photo_service.base_dir + "/photos/photo_move_in.png",
			"captured_unix":1,
		},
	}
	_expect_eq(missing_photo_service.save_game({"release_profile":"demo", "last_saved_unix":1, "pig_state":missing_photo_state.to_dict()}), OK, "demo migration fixture accepts metadata for a locally missing photo")
	var missing_photo_target := SaveService.new(base + "/missing_photo_full")
	var missing_photo_session: Node = GameSessionScript.new()
	missing_photo_session.save_service = missing_photo_target
	var missing_photo_import: Dictionary = missing_photo_session.call("_load_game_with_profile_import", "full", missing_photo_service) as Dictionary
	_expect_true(bool(missing_photo_import.get("ok", false)), "missing demo photo does not discard otherwise valid progression")
	_expect_true((missing_photo_import.data.pig_state.life_photos as Dictionary).is_empty(), "missing demo photo metadata is omitted instead of retaining a cross-profile path")
	var unsafe_photo_service := SaveService.new(base + "/unsafe_photo_demo")
	var unsafe_photo_state := PigState.new()
	unsafe_photo_state.discovered_events = ["event_move_in"]
	unsafe_photo_state.life_photos = {
		"event_move_in": {
			"photo_id":"photo_move_in",
			"path":unsafe_photo_service.save_path,
			"captured_unix":1,
		},
	}
	_expect_eq(unsafe_photo_service.save_game({"release_profile":"demo", "last_saved_unix":1, "pig_state":unsafe_photo_state.to_dict()}), OK, "demo migration fixture accepts an existing but non-photo profile path")
	var unsafe_photo_target := SaveService.new(base + "/unsafe_photo_full")
	var unsafe_photo_session: Node = GameSessionScript.new()
	unsafe_photo_session.save_service = unsafe_photo_target
	var unsafe_photo_import: Dictionary = unsafe_photo_session.call("_load_game_with_profile_import", "full", unsafe_photo_service) as Dictionary
	_expect_true(bool(unsafe_photo_import.get("ok", false)), "unsafe demo photo path does not discard otherwise valid progression")
	_expect_true(
		(unsafe_photo_import.data.pig_state.life_photos as Dictionary).is_empty()
			and not FileAccess.file_exists(unsafe_photo_target.base_dir + "/photos/photo_move_in.png"),
		"noncanonical demo paths cannot copy arbitrary profile files into the full photo directory"
	)
	session.free()
	reverse_session.free()
	damaged_session.free()
	missing_photo_session.free()
	unsafe_photo_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_audio_manifest_routes() -> void:
	var service: Node = AudioServiceScript.new()
	_expect_eq(service.load_manifest(), [], "audio runtime manifest validates")
	_expect_true(not service.is_playback_enabled(), "development runtime is explicitly silent until dedicated audio is supplied")
	_expect_eq(service.music_ids().size(), 4, "audio runtime loads four ordered music entries")
	var manifest: Dictionary = JsonStore.read_object(AudioServiceScript.MANIFEST_PATH)
	for kind: String in ["music", "sfx"]:
		for entry: Dictionary in manifest.get(kind, []) as Array:
			var id: String = str(entry.get("id", ""))
			_expect_eq(service.audio_path(id), str(entry.get("path", "")), "audio manifest route is live: %s" % id)
	_expect_eq(service.audio_path("pet"), service.audio_path("pet_1"), "semantic pet sound resolves through the manifest")
	_expect_eq(service.audio_path("feed"), service.audio_path("bite"), "semantic feed sound resolves through the manifest")
	for animation_id: String in AudioServiceScript.EVENT_SFX:
		_expect_true(not service.audio_path(str(AudioServiceScript.EVENT_SFX[animation_id])).is_empty(), "event sound resolves through the manifest: %s" % animation_id)
	var runtime_audio: Node = root.get_node_or_null("AudioService")
	_expect_true(runtime_audio != null and runtime_audio.get_child_count() == 0, "silent development runtime creates no playback nodes")
	for bus_name: String in AudioServiceScript.BUS_NAMES:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		_expect_true(bus_index >= 0 and AudioServer.get_bus_volume_db(bus_index) <= -79.9, "silent development runtime mutes the %s bus" % bus_name)
	service.music_volume = 0.35
	service.ambient_volume = 0.45
	service.interaction_volume = 0.55
	service.desktop_music_enabled = true
	service.configure({
		"music_volume": [],
		"ambient_volume": "loud",
		"interaction_volume": {},
		"desktop_music_enabled": 1,
	})
	_expect_true(is_equal_approx(service.music_volume, 0.35), "malformed music volume preserves the last safe value")
	_expect_true(is_equal_approx(service.ambient_volume, 0.45), "malformed ambient volume preserves the last safe value")
	_expect_true(is_equal_approx(service.interaction_volume, 0.55), "malformed interaction volume preserves the last safe value")
	_expect_eq(service.desktop_music_enabled, true, "malformed desktop music flag preserves the last safe value")
	service.configure({
		"music_volume": -2,
		"ambient_volume": 3.0,
		"interaction_volume": 0.25,
		"desktop_music_enabled": false,
	})
	_expect_eq(service.music_volume, 0.0, "numeric music volume clamps to the lower bound")
	_expect_eq(service.ambient_volume, 1.0, "numeric ambient volume clamps to the upper bound")
	_expect_eq(service.interaction_volume, 0.25, "valid interaction volume is restored exactly")
	_expect_eq(service.desktop_music_enabled, false, "valid desktop music flag restores exactly")
	service.free()


func _test_clock_boundaries() -> void:
	var supplied_times: Array[int] = [1234]
	var supplied_clock := GameClock.new(func() -> int: return supplied_times[0])
	_expect_eq(supplied_clock.current_unix(), 1234, "session clock accepts an injected Unix-time source")
	supplied_times[0] = 5678
	_expect_eq(supplied_clock.current_unix(), 5678, "session clock reads the injected source for every operation")
	var east_boundary: int = int(Time.get_unix_time_from_datetime_string("2026-08-09T16:30:00"))
	_expect_eq(GameClock.date_string_with_timezone_bias(east_boundary, 0), "2026-08-09", "UTC date conversion retains its calendar day")
	_expect_eq(GameClock.date_string_with_timezone_bias(east_boundary, 8 * 60), "2026-08-10", "eastward timezone conversion crosses into the local next day")
	var west_boundary: int = int(Time.get_unix_time_from_datetime_string("2026-08-10T03:30:00"))
	_expect_eq(GameClock.date_string_with_timezone_bias(west_boundary, -4 * 60), "2026-08-09", "westward timezone conversion crosses into the local previous day")
	var zero: Dictionary = GameClock.settle(100, 100)
	_expect_eq(zero.elapsed_seconds, 0, "zero offline time")
	_expect_eq(zero.points, 0, "zero offline points")
	var backwards: Dictionary = GameClock.settle(200, 100)
	_expect_eq(backwards.elapsed_seconds, 0, "backward clock clamps to zero")
	_expect_true(backwards.clock_went_backwards, "backward clock is reported")
	_expect_eq(GameClock.hour_with_timezone_bias(0, 480), 8, "UTC epoch converts to China local morning")
	_expect_eq(GameClock.hour_with_timezone_bias(0, -300), 19, "negative timezone bias wraps into the previous local evening")
	var one_hour: Dictionary = GameClock.settle(0, 3600)
	_expect_eq(one_hour.elapsed_seconds, 3600, "one hour preserved")
	_expect_true(one_hour.points > 0 and one_hour.points < 100, "one hour receives partial points")
	var eight: Dictionary = GameClock.settle(0, 8 * 3600)
	_expect_eq(eight.points, 100, "eight hour full-rate cap")
	var day: Dictionary = GameClock.settle(0, 24 * 3600)
	_expect_eq(day.elapsed_seconds, 24 * 3600, "twenty-four hour cap")
	_expect_eq(day.points, 140, "full and low-rate point caps")
	var many_days: Dictionary = GameClock.settle(0, 30 * 24 * 3600)
	_expect_eq(many_days.elapsed_seconds, 24 * 3600, "many days clamp to one day")
	_expect_true(many_days.was_capped, "long absence reports cap")
	var sample_times: Array[int] = GameSessionScript.offline_event_sample_times(day, 36 * 3600)
	_expect_eq(sample_times.size(), 6, "twenty-four hour offline discovery uses the capped sample budget")
	var sample_hours: Array[int] = []
	for sample_unix: int in sample_times:
		sample_hours.append(GameClock.local_hour(sample_unix))
	_expect_true(sample_hours.any(func(hour: int) -> bool: return BehaviorDirector._matches_time("morning", hour)), "offline samples cover a morning window")
	_expect_true(sample_hours.any(func(hour: int) -> bool: return BehaviorDirector._matches_time("day", hour)), "offline samples cover a daytime window")
	_expect_true(sample_hours.any(func(hour: int) -> bool: return BehaviorDirector._matches_time("evening", hour)), "offline samples cover an evening window")
	_expect_true(sample_hours.any(func(hour: int) -> bool: return BehaviorDirector._matches_time("night", hour)), "offline samples cover a night window")


func _test_pig_state_boundaries() -> void:
	var state := PigState.new()
	state.satiety = -20
	state.energy = 140
	state.interest = -2
	state.familiarity_xp = 99999
	state.normalize()
	_expect_eq(state.satiety, 0.0, "satiety lower bound")
	_expect_eq(state.energy, 100.0, "energy upper bound")
	_expect_eq(state.interest, 0.0, "interest lower bound")
	_expect_eq(state.familiarity_level, 10, "familiarity upper level")
	var before: int = state.familiarity_level
	state.familiarity_xp = 0
	state.normalize()
	_expect_eq(state.familiarity_level, before, "familiarity never decreases")
	state.daily_points = 10
	_expect_true(not state.spend_points(11), "cannot overspend")
	_expect_true(state.spend_points(10), "can spend exact balance")
	_expect_eq(state.daily_points, 0, "spend updates balance")
	var onboarding := PigState.new()
	onboarding.familiarity_xp = 100
	onboarding.normalize()
	_expect_eq(onboarding.familiarity_level, 5, "first thirty-minute familiarity budget reaches tendency unlock")
	var cadence := PigState.new()
	cadence.familiarity_xp = 69
	cadence.normalize()
	_expect_eq(cadence.familiarity_level, 1, "desktop mode stays locked before the twenty-minute familiarity threshold")
	for milestone: Array in [[70, 2], [78, 3], [86, 4], [95, 5]]:
		cadence.familiarity_xp = int(milestone[0])
		cadence.normalize()
		_expect_eq(cadence.familiarity_level, int(milestone[1]), "onboarding familiarity threshold unlocks level %d in order" % int(milestone[1]))
	var long_tail := PigState.new()
	long_tail.familiarity_xp = 1999
	long_tail.normalize()
	_expect_eq(long_tail.familiarity_level, 9, "long-tail familiarity stays below level ten before the ending threshold")
	long_tail.familiarity_xp = 2000
	long_tail.normalize()
	_expect_eq(long_tail.familiarity_level, 10, "long-tail familiarity reaches level ten at the ending threshold")


func _test_behavior_director() -> void:
	var state := PigState.new()
	var director := BehaviorDirector.new(42)
	var behaviors: Array[Dictionary] = [
		{"id":"a","weight":1.0,"tags":["quiet"],"desktop_allowed":true,"cooldown_seconds":1},
		{"id":"b","weight":100.0,"tags":["active"],"desktop_allowed":false,"cooldown_seconds":1},
		{"id":"c","weight":1.0,"tags":["quiet"],"desktop_allowed":true,"required_furniture":"furn_x","cooldown_seconds":1},
	]
	var desktop_choice: Dictionary = director.choose(behaviors, state, 1000, true, true)
	_expect_eq(desktop_choice.id, "a", "desktop focus mode filters behaviors")
	var main_focus_director := BehaviorDirector.new(42)
	var main_focus_choice: Dictionary = main_focus_director.choose([behaviors[1]], state, 1000, false, true)
	_expect_eq(main_focus_choice.id, "b", "saved focus mode does not filter main-room behaviors")
	director.record_completed(desktop_choice, 1000)
	var none: Dictionary = director.choose(behaviors, state, 1000, true, true)
	_expect_true(none.is_empty(), "immediate repeats and unavailable furniture are excluded")
	state.placed_furniture["activity_1"] = "furn_x"
	var furniture_choice: Dictionary = director.choose(behaviors, state, 1002, true, true)
	_expect_eq(furniture_choice.id, "c", "placed furniture adds behavior")
	_expect_eq(director.recent_ids.size(), 1, "recent queue records completion")
	for index: int in 7:
		director.record_completed({"id":"extra_%d" % index,"cooldown_seconds":1}, 1010 + index)
	_expect_eq(director.recent_ids.size(), BehaviorDirector.RECENT_LIMIT, "behavior recent queue stays capped")
	_expect_eq(director.recent_ids[0], "extra_2", "behavior recent queue evicts oldest entries")


func _test_focus_mode_session_routing() -> void:
	var base := "user://piggy_focus_routing_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	var quiet_behavior: Dictionary = {
		"id":"focus_quiet", "weight":1.0, "tags":["quiet", "sleep"],
		"desktop_allowed":true, "duration_seconds":20.0,
	}
	var noisy_behavior: Dictionary = {
		"id":"focus_noisy", "weight":100.0, "tags":["active"],
		"desktop_allowed":true, "duration_seconds":20.0,
	}
	var catalog := ContentCatalog.new()
	var focus_behaviors: Array[Dictionary] = [quiet_behavior, noisy_behavior]
	catalog.behaviors = focus_behaviors
	session.catalog = catalog
	session.behavior_director = BehaviorDirector.new(20260810)
	session.simulation = Simulation.new(20260810)
	session.desktop_mode = true
	session.focus_mode = true
	session.set("_last_process_unix", 1000)
	session.call("_advance_runtime_frame", 0.1, 1000)
	_expect_eq(str(session.simulation.current_behavior.get("id", "")), "focus_quiet", "session runtime forwards desktop focus mode to quiet behavior selection")
	session.simulation.current_behavior = {}
	session.simulation.remaining_seconds = 0.0
	var ordinary_behaviors: Array[Dictionary] = [noisy_behavior]
	catalog.behaviors = ordinary_behaviors
	session.focus_mode = false
	session.call("_advance_runtime_frame", 0.1, 1001)
	_expect_eq(str(session.simulation.current_behavior.get("id", "")), "focus_noisy", "session runtime restores ordinary desktop behavior selection when focus mode is disabled")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_behavior_weight_rules() -> void:
	var state := PigState.new()
	state.energy = 20.0
	state.satiety = 20.0
	state.interest = 80.0
	_expect_true(BehaviorDirector._state_multiplier(["sleep"], state) > 1.5, "low energy favors sleep")
	_expect_true(BehaviorDirector._state_multiplier(["food"], state) > 1.5, "low satiety favors food")
	_expect_true(BehaviorDirector._tendency_multiplier(["quiet"], "rest") > 1.0, "rest tendency favors quiet")
	_expect_true(BehaviorDirector._tendency_multiplier(["active"], "active") > 1.0, "active tendency favors activity")
	_expect_true(BehaviorDirector._tendency_multiplier(["food"], "active") < 1.0, "tendency remains a soft down-weight")
	_expect_eq(BehaviorDirector._tendency_multiplier(["curious"], "explore"), BehaviorDirector._tendency_multiplier(["quiet"], "explore"), "explore tendency leaves ordinary behavior categories evenly weighted")


func _test_behavior_state_deltas() -> void:
	var state := PigState.new()
	state.satiety = 50.0
	state.energy = 50.0
	state.interest = 50.0
	var simulation := Simulation.new(20260717)
	var director := BehaviorDirector.new(20260717)
	simulation.invite_behavior({
		"id":"balanced_state_delta", "duration_seconds":1.0,
		"tags":["sleep", "food", "active", "curious"],
		"points_min":2, "points_max":2, "cooldown_seconds":1,
	})
	simulation.advance(1.0, state, [], director, 1000, false, false)
	_expect_true(state.satiety > 50.0 and state.satiety < 50.5, "frequent food behaviors change satiety gradually instead of saturating it")
	_expect_true(state.energy > 50.0 and state.energy < 50.1, "sleep and active behavior energy effects remain gently balanced")
	_expect_true(state.interest > 50.0 and state.interest < 50.2, "active and curious behavior interest effects remain gradual")
	var level_state := PigState.new()
	level_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1] - 1
	var level_simulation := Simulation.new(20260718)
	var level_director := BehaviorDirector.new(20260718)
	var transition_snapshot: Dictionary = {}
	level_state.familiarity_level_changed.connect(func(_level: int) -> void:
		transition_snapshot["behavior_id"] = str(level_simulation.current_behavior.get("id", ""))
		transition_snapshot["recent_ids"] = level_director.recent_ids.duplicate()
	)
	level_simulation.invite_behavior({
		"id":"level_commit", "duration_seconds":1.0, "tags":["quiet"],
		"points_min":2, "points_max":2, "cooldown_seconds":60,
	})
	level_simulation.advance(1.0, level_state, [], level_director, 2000, false, false)
	_expect_eq(str(transition_snapshot.get("behavior_id", "missing")), "", "level-up observers see the completed behavior cleared before persistence")
	_expect_true("level_commit" in transition_snapshot.get("recent_ids", []), "level-up observers see behavior cooldown history committed before persistence")


func _test_simulation_mode_parity() -> void:
	var behavior := {
		"id":"mode_parity", "duration_seconds":10.0, "tags":["quiet"],
		"points_min":3, "points_max":3, "cooldown_seconds":60,
	}
	var room_state := PigState.new()
	var desktop_state := PigState.new()
	var room_simulation := Simulation.new(20260728)
	var desktop_simulation := Simulation.new(20260728)
	var room_director := BehaviorDirector.new(20260728)
	var desktop_director := BehaviorDirector.new(20260728)
	room_simulation.invite_behavior(behavior)
	desktop_simulation.invite_behavior(behavior)
	room_simulation.advance(10.0, room_state, [], room_director, 1000, false, false)
	desktop_simulation.advance(10.0, desktop_state, [], desktop_director, 1000, true, false)
	_expect_eq(desktop_state.active_seconds, room_state.active_seconds, "desktop and room simulation consume the same real-time duration")
	_expect_eq(desktop_state.daily_points, room_state.daily_points, "desktop behaviors grant the same ordinary daily points as room behaviors")
	_expect_eq(desktop_state.familiarity_xp, room_state.familiarity_xp, "desktop and room behavior completion grant identical familiarity progress")
	_expect_eq(desktop_simulation.to_dict(), room_simulation.to_dict(), "desktop and room simulations finish the same invited behavior at the same boundary")


func _test_mode_switch_time_integrity() -> void:
	var base := "user://piggy_mode_switch_time_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.pig_state.name = "Mode Pig"
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
	session.pig_state.familiarity_level = 2
	var active_behavior: Dictionary = session.catalog.get_item("behaviors", "behavior_idle_stand").duplicate(true)
	session.simulation.invite_behavior(active_behavior)
	var before_active_seconds: float = session.pig_state.active_seconds
	var before_points: int = session.pig_state.daily_points
	var before_familiarity: int = session.pig_state.familiarity_xp
	var before_simulation: Dictionary = session.simulation.to_dict()
	_expect_true(session.set_desktop_mode(true), "mode integrity fixture enters desktop mode")
	_expect_true(session.set_desktop_mode(false), "mode integrity fixture returns to the room")
	_expect_eq(session.pig_state.active_seconds, before_active_seconds, "mode switching does not duplicate simulated time")
	_expect_eq(session.pig_state.daily_points, before_points, "mode switching does not grant duplicate daily points")
	_expect_eq(session.pig_state.familiarity_xp, before_familiarity, "mode switching does not grant duplicate familiarity progress")
	_expect_eq(session.simulation.to_dict(), before_simulation, "mode switching preserves the active behavior timer exactly")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(bool(persisted.get("ok", false)), "mode-switch autosave remains a valid progression payload")
	var persisted_data: Dictionary = persisted.get("data", {}) as Dictionary
	_expect_eq(persisted_data.get("simulation", {}), before_simulation, "mode-switch autosave persists the unchanged simulation boundary")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_behavior_completion_checkpoint() -> void:
	var base := "user://piggy_behavior_checkpoint_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.call("_connect_modules")
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1] - 1
	var behavior: Dictionary = session.catalog.get_item("behaviors", "behavior_idle_stand").duplicate(true)
	behavior["duration_seconds"] = 1.0
	behavior["points_min"] = 2
	behavior["points_max"] = 2
	session.simulation.invite_behavior(behavior)
	session.simulation.advance(1.0, session.pig_state, session.catalog.behaviors, session.behavior_director, 3000, false, false)
	await process_frame
	var persisted: Dictionary = session.save_service.load_game()
	_expect_eq(str(persisted.data.simulation.current_behavior_id), "", "level-up checkpoint stores no completed active behavior")
	_expect_true("behavior_idle_stand" in persisted.data.behavior_director.recent_ids, "level-up checkpoint stores completed behavior history")
	var restored_state := PigState.new()
	restored_state.load_dict(persisted.data.pig_state)
	var restored_director := BehaviorDirector.new(20260719)
	restored_director.load_dict(persisted.data.behavior_director)
	var restored_simulation := Simulation.new(20260719)
	restored_simulation.load_dict(persisted.data.simulation, session.catalog)
	var restored_points: int = restored_state.daily_points
	restored_simulation.advance(0.25, restored_state, session.catalog.behaviors, restored_director, 3001, false, false)
	_expect_eq(restored_state.daily_points, restored_points, "reloading a level-up checkpoint cannot complete the same behavior twice")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_event_queue() -> void:
	var state := PigState.new()
	state.familiarity_level = 10
	var director := EventDirector.new(7)
	var events: Array[Dictionary] = []
	for index: int in 6:
		events.append({
			"id": "test_event_%d" % index,
			"min_level": 1,
			"required_furniture": [],
			"prerequisite_events": [],
			"time": "any",
			"weight": 1.0,
			"unseen_multiplier": 2.0,
			"cooldown_seconds": 99999,
			"rewards": {"points": 25, "familiarity": 1, "expressions": []},
		})
	for index: int in 6:
		director.discover_one(events, state, 1000 + index)
	_expect_eq(state.discovered_events.size(), 6, "all discovered events retained")
	_expect_eq(state.pending_events.size(), 5, "pending queue capped at five")
	_expect_eq(state.summarized_events.size(), 1, "overflow event becomes summary")
	var first_id: String = state.pending_events[0]
	var event: Dictionary = events[int(first_id.get_slice("_", 2))]
	var reward: Dictionary = director.mark_watched(event, state, 2000)
	_expect_true(reward.first_watch, "first event watch is identified")
	_expect_true(first_id in state.seen_events, "watched event enters history")
	_expect_true(not first_id in state.pending_events, "watched event leaves pending queue")
	director.discover_one([event], state, 200000)
	_expect_true(first_id in state.pending_events, "a watched event can return after its cooldown for another variant")
	var repeated: Dictionary = director.mark_watched(event, state, 200001)
	_expect_true(not repeated.first_watch and repeated.points == 0, "returning event variants never repeat first-watch rewards")


func _test_event_conditions_and_branches() -> void:
	var state := PigState.new()
	state.familiarity_level = 6
	state.energy = 35.0
	state.satiety = 50.0
	state.interest = 50.0
	state.placed_furniture["window_4"] = "furn_weather_charm"
	state.placed_furniture["snack_3"] = "furn_kettle_round"
	var event := {
		"id":"event_rule_test", "min_level":6, "required_furniture":["furn_weather_charm"],
		"category":"food", "anchor":"snack",
		"prerequisite_events":[], "time":"any", "weight":1.0, "unseen_multiplier":10.0,
		"desktop_allowed":false,
		"cooldown_seconds":100, "state_ranges":{"satiety":[0,80],"energy":[0,60],"interest":[20,100]},
		"variants":["A","B"],
		"branches":[
			{"id":"warm","conditions":{"required_furniture":["furn_kettle_round"],"energy_max":40},"variant_keys":["B"],"reward_bonus":{"points":2}},
			{"id":"default","conditions":{},"variant_keys":["A"],"reward_bonus":{}},
		],
	}
	var director := EventDirector.new(12)
	_expect_eq(director.get_eligible([event], state, 1000).size(), 1, "event state and furniture conditions pass")
	_expect_eq(director.get_eligible([event], state, 1000, true).size(), 0, "room-only events cannot be discovered by the live desktop loop")
	var desktop_event: Dictionary = event.duplicate(true)
	desktop_event["desktop_allowed"] = true
	_expect_eq(director.get_eligible([desktop_event], state, 1000, true).size(), 1, "desktop-enabled events remain eligible for the companion memory bubble")
	var session: Node = GameSessionScript.new()
	var recording_director := RecordingEventDirector.new()
	session.event_director = recording_director
	session.desktop_mode = true
	session.call("_try_discover_event", 1000)
	session.call("_discover_offline_events", {"elapsed_seconds":7200}, 7200)
	_expect_eq(recording_director.discovery_modes, [true, false], "session distinguishes live desktop discovery from mode-independent offline sampling")
	session.free()
	_expect_eq(director.resolve_branch(event, state).id, "warm", "matching event branch is selected")
	_expect_eq(EventDirector.calculate_weight(event, state), 13.5, "explore tendency adds a soft boost to unseen events")
	state.discovered_events.append("event_rule_test")
	_expect_eq(EventDirector.calculate_weight(event, state), 1.0, "seen event loses unseen multiplier")
	_expect_true(is_equal_approx(EventDirector.calculate_weight(event, state, ["event_rule_test"]), 0.18), "recent events are down-weighted")
	state.tendency = "food"
	_expect_true(EventDirector.calculate_weight(event, state) > 1.0, "food tendency favors food events")
	var sleep_event: Dictionary = event.duplicate(true)
	sleep_event["id"] = "event_sleep_test"
	sleep_event["category"] = "sleep"
	state.discovered_events.append("event_sleep_test")
	_expect_true(EventDirector.calculate_weight(event, state) > EventDirector.calculate_weight(sleep_event, state), "food tendency remains a soft event preference")
	state.energy = 75.0
	_expect_eq(director.get_eligible([event], state, 1000).size(), 0, "event state range blocks ineligible state")
	state.energy = 50.0
	_expect_eq(director.resolve_branch(event, state).id, "default", "event falls back to default branch")


func _test_session_event_branch_handoff() -> void:
	var base := "user://piggy_event_branch_handoff_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	var errors: Array[String] = session.catalog.load_all()
	session.loaded_successfully = errors.is_empty()
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, GameSession.ROOM_SLOTS)
	session.clock = GameClock.new(func() -> int: return 2000)
	var event_id := "event_rainy_window"
	var event: Dictionary = session.catalog.get_item("events", event_id)
	session.pig_state.familiarity_xp = 200
	session.pig_state.familiarity_level = 6
	session.pig_state.daily_points = 0
	session.pig_state.owned_furniture.append("furn_kettle_round")
	session.pig_state.placed_furniture["snack_3"] = "furn_kettle_round"
	session.pig_state.discovered_events.append(event_id)
	session.pig_state.pending_events.append(event_id)
	for expression_id: Variant in (event.get("rewards", {}) as Dictionary).get("expressions", []):
		session.pig_state.unlocked_expressions.append(str(expression_id))
	var prepared: Dictionary = session.prepare_event(event_id)
	_expect_eq(str(prepared.get("resolved_branch_id", "")), "warm_drink", "session prepares the matching event branch before playback")
	_expect_eq(prepared.get("variants", []), ["EVENT_RAINY_WINDOW_LINE_2"], "prepared event exposes only the matching branch copy")
	session.pig_state.placed_furniture.erase("snack_3")
	_expect_eq(session.event_director.resolve_branch(event, session.pig_state).id, "default", "event conditions can change while the prepared playback is open")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#efb8c8"))
	var result: Dictionary = session.complete_event_with_photo(
		event_id,
		image,
		str(prepared.get("resolved_branch_id", ""))
	)
	_expect_true(
		str(result.get("branch_id", "")) == "warm_drink" and result.get("save_error", FAILED) == OK,
		"event completion commits the branch prepared for the displayed playback"
	)
	_expect_true(
		session.pig_state.daily_points == 34 and session.pig_state.familiarity_xp == 215,
		"prepared branch grants its matching base and familiarity rewards after conditions change"
	)
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_level_eight_combination_event() -> void:
	var catalog := ContentCatalog.new()
	catalog.load_all()
	var event: Dictionary = catalog.get_item("events", "event_robot_knight").duplicate(true)
	var required_furniture: Array = event.get("required_furniture", []) as Array
	_expect_true(required_furniture.size() == 2 and "furn_cleaning_robot" in required_furniture and "furn_pillow_cloud" in required_furniture, "level-eight robot knight is a two-furniture combination event")
	event["time"] = "any"
	event["prerequisite_events"] = []
	var state := PigState.new()
	state.familiarity_level = 7
	state.placed_furniture["snack_3"] = "furn_cleaning_robot"
	state.placed_furniture["sleep_2"] = "furn_pillow_cloud"
	var director := EventDirector.new(20260728)
	_expect_eq(director.get_eligible([event], state, 1000).size(), 0, "combination event stays locked before familiarity level eight")
	state.familiarity_level = 8
	state.placed_furniture.erase("sleep_2")
	_expect_eq(director.get_eligible([event], state, 1000).size(), 0, "advanced robot alone cannot trigger the combination event")
	state.placed_furniture["sleep_2"] = "furn_pillow_cloud"
	_expect_eq(director.get_eligible([event], state, 1000).size(), 1, "robot and soft pillow together unlock the level-eight combination event")


func _test_event_rewards() -> void:
	var state := PigState.new()
	state.daily_points = 0
	state.energy = 25.0
	var event := {
		"id":"event_reward_test",
		"variants":["A"],
		"branches":[
			{"id":"tired","conditions":{"energy_max":30},"variant_keys":["A"],"reward_bonus":{"points":3,"familiarity":2}},
			{"id":"default","conditions":{},"variant_keys":["A"],"reward_bonus":{}},
		],
		"rewards":{"points":25,"familiarity":10,"expressions":["expr_test"],"achievements":["ach_test"]},
	}
	state.pending_events.append("event_reward_test")
	var director := EventDirector.new(5)
	var result: Dictionary = director.mark_watched(event, state, 2000, "tired")
	_expect_true(result.first_watch, "first event watch grants rewards")
	_expect_eq(result.branch_id, "tired", "watched result records branch")
	_expect_eq(result.points, 28, "branch point bonus is granted")
	_expect_eq(state.daily_points, 38, "event and expression rewards are both applied")
	_expect_eq(state.familiarity_xp, 12, "branch familiarity bonus is granted")
	_expect_true("expr_test" in state.unlocked_expressions, "event expression is unlocked")
	_expect_true("ach_test" in state.unlocked_achievements, "event achievement reward is unlocked")
	var replay: Dictionary = director.mark_watched(event, state, 2100, "tired")
	_expect_true(not replay.first_watch, "event replay is identified")
	_expect_eq(replay.points, 0, "event replay does not grant points")


func _test_event_director_persistence() -> void:
	var state := PigState.new()
	state.familiarity_level = 10
	var event := {
		"id":"event_persist_test", "min_level":1, "required_furniture":[], "prerequisite_events":[],
		"time":"any", "weight":1.0, "unseen_multiplier":1.0, "cooldown_seconds":100,
		"rewards":{"points":0,"familiarity":0,"expressions":[]},
	}
	var director := EventDirector.new(17)
	var result: Dictionary = director.discover_one([event], state, 1000)
	_expect_eq(str(result.get("event", {}).get("id", "")), "event_persist_test", "event is discovered before persistence")
	director.mark_watched(event, state, 1050)
	var restored := EventDirector.new(18)
	restored.load_dict(director.to_dict())
	_expect_eq(restored.last_triggered_unix.get("event_persist_test", 0), 1050, "event cooldown restarts when watched and survives roundtrip")
	_expect_eq(restored.recent_event_ids, ["event_persist_test"], "event recent queue survives roundtrip")
	_expect_eq(restored.get_eligible([event], state, 1149).size(), 0, "restored cooldown blocks early retrigger")
	_expect_eq(restored.get_eligible([event], state, 1150).size(), 1, "restored cooldown expires at its boundary")


func _test_event_discovery_save_transaction() -> void:
	var base := "user://piggy_event_discovery_transaction_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	var catalog_errors: Array[String] = session.catalog.load_all()
	session.loaded_successfully = catalog_errors.is_empty()
	var event: Dictionary = session.catalog.get_item("events", "event_move_in").duplicate(true)
	event["min_level"] = 1
	event["min_active_seconds"] = 0
	event["required_furniture"] = []
	event["prerequisite_events"] = []
	event["time"] = "any"
	event["state_ranges"] = {"satiety":[0, 100], "energy":[0, 100], "interest":[0, 100]}
	var discovery_events: Array[Dictionary] = [event]
	session.catalog.events = discovery_events
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, GameSession.ROOM_SLOTS)
	session.call("_connect_modules")
	session.pig_state.name = "Discovery Pig"
	_expect_eq(session.save_game(), OK, "event discovery fixture commits its stable baseline")
	var save_path: String = session.save_service.save_path
	_expect_eq(
		_read_event_discovery_checkpoint(save_path),
		{"discovered_events":[], "pending_events":[], "summarized_events":[], "event_director":{"last_triggered_unix":{}, "recent_event_ids":[]}},
		"event discovery baseline has no committed event or cooldown"
	)
	var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var director_before: Dictionary = session.event_director.to_dict().duplicate(true)
	var disk_before: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
	var blocker_path := base + "/not_a_directory"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("block child paths")
	blocker.close()
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = blocker_path + "/savegame.tmp.json"
	var queued_events: Array[String] = []
	var memory_notifications: Array[bool] = []
	var success_toasts: Array[String] = []
	var queue_checkpoints: Array[Dictionary] = []
	var memory_checkpoints: Array[Dictionary] = []
	var toast_checkpoints: Array[Dictionary] = []
	session.event_queued.connect(func(event_id: String) -> void:
		queued_events.append(event_id)
		queue_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	)
	session.memory_queue_changed.connect(func() -> void:
		memory_notifications.append(true)
		memory_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	)
	session.toast_requested.connect(func(key: String, _values: Dictionary) -> void:
		success_toasts.append(key)
		toast_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	)
	var failed_result: Dictionary = session.call("_try_discover_event", 1000)
	_expect_true(failed_result.is_empty(), "failed automatic discovery reports no committed memory")
	_expect_eq(session.pig_state.to_dict(), state_before, "failed automatic discovery restores the full pig state")
	_expect_eq(session.event_director.to_dict(), director_before, "failed automatic discovery restores cooldown and recent-event state")
	_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), disk_before, "failed automatic discovery preserves the committed disk generation")
	_expect_eq(queued_events, [], "failed automatic discovery emits no queue success signal")
	_expect_eq(memory_notifications.size(), 0, "failed automatic discovery emits no memory-count change")
	_expect_eq(success_toasts, [], "failed automatic discovery emits no new-memory toast")
	session.save_service.temp_path = normal_temp_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	var retry_result: Dictionary = session.call("_try_discover_event", 1000)
	_expect_eq(str((retry_result.get("event", {}) as Dictionary).get("id", "")), "event_move_in", "automatic discovery retries after storage recovers")
	_expect_true("event_move_in" in session.pig_state.pending_events, "successful discovery commits the pending memory")
	_expect_eq(queued_events, ["event_move_in"], "successful discovery announces the committed queue exactly once")
	_expect_eq(memory_notifications.size(), 1, "successful discovery updates the memory count exactly once")
	_expect_eq(success_toasts, ["TOAST_MEMORY_WAITING"], "successful discovery shows one committed-memory toast")
	var expected_checkpoint: Dictionary = JSON.parse_string(JSON.stringify({
		"discovered_events":["event_move_in"],
		"pending_events":["event_move_in"],
		"summarized_events":[],
		"event_director":session.event_director.to_dict().duplicate(true),
	})) as Dictionary
	_expect_eq(queue_checkpoints, [expected_checkpoint], "queue success observes the discovered event and cooldown in the committed main file")
	_expect_eq(memory_checkpoints, [expected_checkpoint], "memory-count success observes the discovered event and cooldown in the committed main file")
	_expect_eq(toast_checkpoints, [expected_checkpoint], "new-memory toast observes the discovered event and cooldown in the committed main file")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(bool(persisted.get("ok", false)) and "event_move_in" in persisted.data.pig_state.pending_events, "successful event discovery remains readable through the production loader")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


static func _read_event_discovery_checkpoint(save_path: String) -> Dictionary:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not payload is Dictionary:
		return {}
	var state: Dictionary = payload.get("pig_state", {}) as Dictionary
	return {
		"discovered_events":state.get("discovered_events", []),
		"pending_events":state.get("pending_events", []),
		"summarized_events":state.get("summarized_events", []),
		"event_director":payload.get("event_director", {}),
	}


func _test_offline_simulation() -> void:
	var state := PigState.new()
	var simulation := Simulation.new(9)
	var settlement: Dictionary = GameClock.settle(0, 8 * 3600)
	var before: int = state.daily_points
	simulation.apply_offline(state, settlement)
	_expect_eq(state.daily_points, before + 100, "offline simulation awards settlement points")
	_expect_true(state.satiety >= 35.0, "offline satiety has a non-punitive floor")
	_expect_true(state.energy >= 35.0 and state.energy <= 92.0, "offline energy remains comfortable")


func _test_runtime_resume_settlement() -> void:
	var base := "user://piggy_runtime_resume_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	_expect_true(GameSessionScript.runtime_gap_requires_settlement(1000, 4600), "runtime detects a forward wall-clock gap")
	_expect_true(GameSessionScript.runtime_gap_requires_settlement(4600, 4000), "runtime detects a backward wall-clock jump")
	_expect_true(not GameSessionScript.runtime_gap_requires_settlement(1000, 1014), "runtime ignores ordinary sub-threshold frame timing")
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.simulation.invite_behavior({"id":"resume_behavior","duration_seconds":30.0})
	var before_points: int = session.pig_state.daily_points
	var before_remaining: float = session.simulation.remaining_seconds
	var settlement: Dictionary = session.handle_runtime_resume(1000, 4600)
	_expect_eq(settlement.elapsed_seconds, 3600, "runtime resume settles the real elapsed hour")
	_expect_true(session.pig_state.daily_points > before_points, "runtime resume awards offline points")
	_expect_eq(str(session.simulation.current_behavior.get("id", "")), "resume_behavior", "runtime resume does not replay behavior completions")
	_expect_eq(session.simulation.remaining_seconds, before_remaining, "runtime resume keeps the active behavior timer stable")
	_expect_eq(session.last_offline_summary.elapsed_seconds, 3600, "runtime resume exposes one summary")
	session.behavior_director.cooldown_until = {"future_behavior":9000, "past_behavior":3500}
	session.event_director.last_triggered_unix = {"future_event":9000, "past_event":3500}
	var rollback_points: int = session.pig_state.daily_points
	var rollback: Dictionary = session.handle_runtime_resume(4600, 4000)
	_expect_eq(rollback.elapsed_seconds, 0, "runtime clock rollback grants no elapsed simulation time")
	_expect_true(rollback.clock_went_backwards, "runtime clock rollback is reported")
	_expect_eq(session.pig_state.daily_points, rollback_points, "runtime clock rollback grants no points")
	_expect_eq(session.simulation.remaining_seconds, before_remaining, "runtime clock rollback preserves the active behavior timer")
	_expect_true(not session.behavior_director.cooldown_until.has("future_behavior") and session.behavior_director.cooldown_until.has("past_behavior"), "runtime clock rollback discards only future behavior cooldowns")
	_expect_true(not session.event_director.last_triggered_unix.has("future_event") and session.event_director.last_triggered_unix.has("past_event"), "runtime clock rollback discards only future event timestamps")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(bool(persisted.get("ok", false)) and int(persisted.data.last_saved_unix) == 4000, "runtime clock rollback checkpoints the safe current time anchor")
	session.free()
	var frame_session: Node = GameSessionScript.new()
	frame_session.catalog.load_all()
	frame_session.loaded_successfully = true
	frame_session.save_service = SaveService.new(base + "/frame")
	var completed_behavior_ids: Array[String] = []
	frame_session.simulation.behavior_completed.connect(
		func(behavior: Dictionary, _points: int) -> void: completed_behavior_ids.append(str(behavior.get("id", "")))
	)
	frame_session.simulation.invite_behavior({"id":"resume_frame_behavior", "duration_seconds":0.5})
	frame_session.set("_last_process_unix", 1000)
	frame_session.set("_event_elapsed", 12.0)
	var frame_points_before: int = frame_session.pig_state.daily_points
	var frame_active_before: float = frame_session.pig_state.active_seconds
	var frame_remaining_before: float = frame_session.simulation.remaining_seconds
	frame_session.call("_advance_runtime_frame", 3600.0, 4600)
	_expect_eq(frame_session.last_offline_summary.elapsed_seconds, 3600, "runtime frame applies the forward gap through offline settlement")
	_expect_true(frame_session.pig_state.daily_points > frame_points_before, "runtime frame retains the offline settlement reward")
	_expect_eq(str(frame_session.simulation.current_behavior.get("id", "")), "resume_frame_behavior", "settled resume frame does not complete a near-finished behavior")
	_expect_eq(frame_session.simulation.remaining_seconds, frame_remaining_before, "settled resume frame does not consume the wall-clock gap twice")
	_expect_eq(frame_session.pig_state.active_seconds, frame_active_before, "settled resume frame does not count duplicate active time")
	_expect_true(completed_behavior_ids.is_empty(), "settled resume frame emits no foreground behavior completion")
	_expect_eq(frame_session.get("_event_elapsed"), 12.0, "settled resume frame does not reuse raw delta for a foreground event check")
	_expect_eq(frame_session.get("_last_process_unix"), 4600, "settled resume frame advances the runtime time anchor")
	frame_session.simulation.invite_behavior({"id":"rollback_frame_behavior", "duration_seconds":0.5})
	frame_session.set("_event_elapsed", 20.0)
	var rollback_frame_points: int = frame_session.pig_state.daily_points
	var rollback_frame_active: float = frame_session.pig_state.active_seconds
	var rollback_frame_remaining: float = frame_session.simulation.remaining_seconds
	frame_session.call("_advance_runtime_frame", 1.0, 4000)
	_expect_eq(str(frame_session.simulation.current_behavior.get("id", "")), "rollback_frame_behavior", "clock rollback frame does not complete a near-finished behavior")
	_expect_eq(frame_session.simulation.remaining_seconds, rollback_frame_remaining, "clock rollback frame preserves the active behavior timer")
	_expect_eq(frame_session.pig_state.daily_points, rollback_frame_points, "clock rollback frame cannot award foreground behavior points")
	_expect_eq(frame_session.pig_state.active_seconds, rollback_frame_active, "clock rollback frame cannot add active simulation time")
	_expect_true(completed_behavior_ids.is_empty(), "clock rollback frame emits no behavior completion")
	_expect_eq(frame_session.get("_event_elapsed"), 20.0, "clock rollback frame does not advance the foreground event timer")
	_expect_eq(frame_session.get("_last_process_unix"), 4000, "clock rollback frame resets the runtime time anchor")
	frame_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_startup_offline_checkpoint() -> void:
	var base := "user://piggy_startup_checkpoint_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var source := PigState.new()
	source.daily_points = 100
	var resumed_at: int = GameClock.now_unix()
	var saved_at: int = resumed_at - 3600
	_expect_eq(service.save_game({"last_saved_unix": saved_at, "pig_state": source.to_dict()}), OK, "startup checkpoint fixture saves an hour-old state")
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return resumed_at)
	session.call("_connect_modules")
	session.call("_load_or_create_game")
	var settled_points: int = session.pig_state.daily_points
	_expect_eq(settled_points, source.daily_points + 13, "startup applies the exact pending one-hour offline settlement")
	_expect_eq(session.pig_state.familiarity_xp, source.familiarity_xp + 2, "startup applies the exact pending one-hour familiarity reward")
	var persisted: Dictionary = service.load_game()
	_expect_eq(int(persisted.data.pig_state.daily_points), settled_points, "startup checkpoints settled points before the next autosave")
	_expect_eq(int(persisted.data.last_saved_unix), resumed_at, "startup advances the persisted offline time anchor to the injected current time")
	var settled_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	session.free()
	var restarted_session: Node = GameSessionScript.new()
	restarted_session.catalog.load_all()
	restarted_session.loaded_successfully = true
	restarted_session.save_service = service
	restarted_session.clock = GameClock.new(func() -> int: return resumed_at)
	restarted_session.call("_connect_modules")
	restarted_session.call("_load_or_create_game")
	_expect_eq(restarted_session.pig_state.to_dict(), settled_state, "restart from the committed anchor cannot grant the consumed offline rewards again")
	_expect_eq(restarted_session.last_offline_summary, {}, "restart at the committed time emits no second offline summary")
	_expect_eq(int(restarted_session.get("_last_saved_unix")), resumed_at, "restart retains the same consumed time anchor")
	restarted_session.free()
	var future_state := PigState.new()
	future_state.daily_points = 200
	var rollback_now: int = GameClock.now_unix()
	var future_anchor: int = rollback_now + 3600
	var future_behavior_cooldown: int = future_anchor + 1800
	var future_event_timestamp: int = future_anchor + 2400
	var past_behavior_cooldown: int = rollback_now - 20
	var past_event_timestamp: int = rollback_now - 10
	_expect_eq(service.save_game({
		"last_saved_unix": future_anchor,
		"pig_state": future_state.to_dict(),
		"behavior_director": {
			"recent_ids":["behavior_idle_stand"],
			"cooldown_until":{"future_behavior":future_behavior_cooldown, "past_behavior":past_behavior_cooldown},
		},
		"event_director": {
			"last_triggered_unix":{"future_event":future_event_timestamp, "past_event":past_event_timestamp},
			"recent_event_ids":["event_move_in"],
		},
	}), OK, "clock rollback fixture saves a future time anchor and director timestamps")
	var rollback_session: Node = GameSessionScript.new()
	rollback_session.catalog.load_all()
	rollback_session.loaded_successfully = true
	rollback_session.save_service = service
	rollback_session.clock = GameClock.new(func() -> int: return rollback_now)
	rollback_session.call("_load_or_create_game")
	var rollback_persisted: Dictionary = service.load_game()
	_expect_eq(int(rollback_session.pig_state.daily_points), 200, "clock rollback grants no offline points")
	_expect_true(int(rollback_persisted.data.last_saved_unix) < future_anchor, "clock rollback checkpoints a safe current anchor")
	var repaired_behavior_cooldowns: Dictionary = rollback_session.behavior_director.cooldown_until
	var repaired_event_timestamps: Dictionary = rollback_session.event_director.last_triggered_unix
	var persisted_behavior_cooldowns: Dictionary = rollback_persisted.data.behavior_director.cooldown_until
	var persisted_event_timestamps: Dictionary = rollback_persisted.data.event_director.last_triggered_unix
	_expect_true(not repaired_behavior_cooldowns.has("future_behavior") and int(repaired_behavior_cooldowns.get("past_behavior", 0)) == past_behavior_cooldown, "startup clock rollback discards only future behavior cooldowns")
	_expect_true(not repaired_event_timestamps.has("future_event") and int(repaired_event_timestamps.get("past_event", 0)) == past_event_timestamp, "startup clock rollback discards only future event timestamps")
	_expect_true(not persisted_behavior_cooldowns.has("future_behavior") and int(persisted_behavior_cooldowns.get("past_behavior", 0)) == past_behavior_cooldown, "startup clock rollback checkpoints repaired behavior cooldowns")
	_expect_true(not persisted_event_timestamps.has("future_event") and int(persisted_event_timestamps.get("past_event", 0)) == past_event_timestamp, "startup clock rollback checkpoints repaired event timestamps")
	rollback_session.free()
	var unsafe_base := base + "/unsafe_photo"
	var unsafe_service := SaveService.new(unsafe_base)
	var unsafe_state := PigState.new()
	unsafe_state.daily_points = 345
	unsafe_state.discovered_events = ["event_move_in"]
	unsafe_state.seen_events = ["event_move_in"]
	var foreign_path := unsafe_base + "/foreign.png"
	var foreign_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	foreign_image.fill(Color("#d9879b"))
	foreign_image.save_png(foreign_path)
	unsafe_state.life_photos = {
		"event_move_in": {
			"photo_id":"photo_move_in",
			"path":foreign_path,
			"captured_unix":GameClock.now_unix(),
		},
	}
	_expect_eq(unsafe_service.save_game({"last_saved_unix":GameClock.now_unix(), "pig_state":unsafe_state.to_dict()}), OK, "startup photo repair fixture stores noncanonical metadata")
	var unsafe_session: Node = GameSessionScript.new()
	unsafe_session.catalog.load_all()
	unsafe_session.loaded_successfully = true
	unsafe_session.save_service = unsafe_service
	unsafe_session.call("_load_or_create_game")
	_expect_true(unsafe_session.pig_state.daily_points == 345 and unsafe_session.pig_state.life_photos.is_empty(), "startup removes only noncanonical photo metadata and preserves progression")
	_expect_true(FileAccess.file_exists(foreign_path), "startup photo repair never deletes the referenced arbitrary file")
	_expect_true((unsafe_service.load_game().data.pig_state.life_photos as Dictionary).is_empty(), "startup persists repaired photo metadata before play continues")
	unsafe_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_daily_interaction_decay() -> void:
	var state := PigState.new()
	_expect_eq(state.record_daily_interaction("feed", "2026-07-16"), 1, "first daily feed is first reward opportunity")
	_expect_eq(state.record_daily_interaction("feed", "2026-07-16"), 2, "repeat feed is recorded without another first reward")
	_expect_eq(state.record_daily_interaction("pet", "2026-07-16"), 1, "interaction types decay independently")
	_expect_eq(state.record_daily_interaction("feed", "2026-07-17"), 1, "daily interaction reward resets on a new date")


func _test_session_daily_interaction_clock() -> void:
	var base := "user://piggy_session_daily_interaction_clock_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var timezone_bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local_midnight: int = int(Time.get_unix_time_from_datetime_string("2026-08-10T00:00:00")) - timezone_bias * 60
	var supplied_times: Array[int] = [local_midnight + 60]
	var session: Node = GameSessionScript.new()
	session.clock = GameClock.new(func() -> int: return supplied_times[0])
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, GameSession.ROOM_SLOTS)
	session.pig_state.name = "Clock Pig"
	session.pig_state.tutorial_skipped = true
	session.pig_state.daily_points = 100
	session.pig_state.unlock("expression", "expr_happy_soft", supplied_times[0])
	session.pet_pig()
	_expect_true(
		session.pig_state.daily_points == 102 and session.pig_state.familiarity_xp == 2,
		"first touch uses the injected local date and grants its daily reward"
	)
	supplied_times[0] = local_midnight + 23 * 60 * 60
	session.poke_pig()
	_expect_true(
		session.pig_state.daily_points == 102 and session.pig_state.familiarity_xp == 2,
		"later touch on the same injected local date receives no repeated reward"
	)
	_expect_eq(int(session.pig_state.interaction_counts.get("pet:2026-08-10", 0)), 2, "pet and poke share the fixed same-day decay key")
	supplied_times[0] = local_midnight + 24 * 60 * 60 + 60
	session.pet_pig()
	_expect_true(
		session.pig_state.daily_points == 104 and session.pig_state.familiarity_xp == 4,
		"touch reward resets after the injected clock crosses local midnight"
	)
	_expect_true(
		int(session.pig_state.interaction_counts.get("pet:2026-08-10", 0)) == 2
			and int(session.pig_state.interaction_counts.get("pet:2026-08-11", 0)) == 1,
		"touch counters retain distinct permanent local-date keys across midnight"
	)
	var points_before_feed: int = session.pig_state.daily_points
	var xp_before_feed: int = session.pig_state.familiarity_xp
	var first_feed_ok: bool = session.feed("snack_apple")
	_expect_true(
		first_feed_ok
			and session.pig_state.daily_points == points_before_feed - 7
			and session.pig_state.familiarity_xp == xp_before_feed + 3,
		"first feed uses the injected local date and applies only its daily reward plus snack cost"
	)
	var repeat_feed_ok: bool = session.feed("snack_apple")
	_expect_true(
		repeat_feed_ok
			and session.pig_state.daily_points == points_before_feed - 17
			and session.pig_state.familiarity_xp == xp_before_feed + 3,
		"repeat feed on the same injected local date pays the snack cost without another reward"
	)
	supplied_times[0] = local_midnight + 48 * 60 * 60 + 60
	var next_day_feed_ok: bool = session.feed("snack_apple")
	_expect_true(
		next_day_feed_ok
			and session.pig_state.daily_points == points_before_feed - 24
			and session.pig_state.familiarity_xp == xp_before_feed + 6,
		"feed reward resets after a second injected local-midnight crossing"
	)
	_expect_true(
		int(session.pig_state.interaction_counts.get("feed:2026-08-11", 0)) == 2
			and int(session.pig_state.interaction_counts.get("feed:2026-08-12", 0)) == 1,
		"feed counters retain independent local-date keys across midnight"
	)
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_session_facade_commands() -> void:
	var base := "user://piggy_session_facade_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.save_service = SaveService.new(base)
	var toast_keys: Array[String] = []
	session.toast_requested.connect(func(key: String, _values: Dictionary) -> void: toast_keys.append(key))
	session.set_ui_scale(4.0)
	session.set_bubble_duration_scale(0.2)
	_expect_eq(session.ui_scale, 1.5, "session facade clamps UI scale before UI rendering")
	_expect_eq(session.bubble_duration_scale, 0.75, "session facade clamps bubble duration before persistence")
	_expect_true(session.set_locale("en"), "session facade accepts a supported locale")
	_expect_true(not session.set_locale("invalid"), "session facade rejects an unsupported locale")
	_expect_eq(session.locale, "en", "invalid locale input preserves the last supported locale")
	_expect_eq(session.save_service.save_settings({
		"desktop_scale":0.75,
		"desktop_dock":"right",
		"desktop_screen":2,
		"desktop_always_on_top":false,
		"desktop_transparent_mode":false,
	}), OK, "desktop settings fixture writes through the storage module")
	var desktop: Dictionary = session.desktop_window_settings()
	_expect_eq(desktop.desktop_scale, 0.75, "session facade exposes the persisted desktop scale")
	_expect_eq(desktop.desktop_dock, "right", "session facade exposes an allowed desktop dock")
	_expect_eq(desktop.desktop_screen, 2, "session facade exposes the persisted machine-local desktop screen")
	_expect_eq(desktop.desktop_always_on_top, false, "session facade exposes the desktop stacking preference")
	_expect_eq(desktop.desktop_transparent_mode, false, "session facade exposes the normal-window fallback preference")
	_expect_eq(session.save_service.save_settings({
		"desktop_scale":[],
		"desktop_dock":42,
		"desktop_screen":[],
		"desktop_always_on_top":{},
		"desktop_transparent_mode":"false",
	}), OK, "malformed desktop-window fixture writes as valid JSON")
	var safe_desktop: Dictionary = session.desktop_window_settings()
	_expect_eq(safe_desktop.desktop_scale, 1.0, "malformed desktop scale falls back to 100 percent")
	_expect_eq(safe_desktop.desktop_dock, "bottom", "malformed desktop dock falls back to the profile-safe bottom edge")
	_expect_true(
		safe_desktop.desktop_screen == -1
			and safe_desktop.desktop_always_on_top
			and safe_desktop.desktop_transparent_mode,
		"malformed desktop screen and flags retain their safe defaults"
	)
	session.pig_state.name = "Facade Pig"
	session.notify_pig_placed()
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color("#d9879b"))
	var first: Dictionary = session.save_manual_screenshot(image)
	var second: Dictionary = session.save_manual_screenshot(image)
	_expect_eq(int(first.error), OK, "session facade writes a manual screenshot")
	_expect_eq(int(second.error), OK, "session facade writes a second manual screenshot in the same second")
	_expect_true(str(first.path) != str(second.path), "same-second manual screenshots receive collision-free permanent paths")
	_expect_true(FileAccess.file_exists(str(first.path)) and FileAccess.file_exists(str(second.path)), "session facade returns two existing screenshot paths")
	_expect_eq(toast_keys, ["TOAST_PIG_PLACED", "TOAST_SCREENSHOT_SAVED", "TOAST_SCREENSHOT_SAVED"], "session facade owns drag and screenshot result notifications")
	TranslationServer.set_locale("zh_CN")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_pig_touch_interactions() -> void:
	var base := "user://piggy_touch_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.pig_state.name = "Touch Pig"
	session.pig_state.tutorial_skipped = true
	var touch_unix: int = int(Time.get_unix_time_from_datetime_string("2026-08-10T12:00:00"))
	session.clock = GameClock.new(func() -> int: return touch_unix)
	var toast_keys: Array[String] = []
	session.toast_requested.connect(func(key: String, _values: Dictionary) -> void: toast_keys.append(key))
	var points_before: int = session.pig_state.daily_points
	var pet_reaction: Dictionary = session.pet_pig()
	_expect_eq(str(pet_reaction.get("kind", "")), "pet", "body touch resolves to the pet interaction")
	_expect_eq(str(pet_reaction.get("category", "")), "happy", "pet interaction requests an immediate happy expression")
	_expect_eq(str(pet_reaction.get("expression_id", "")), "expr_happy_soft", "pet reaction uses a permanent expression ID")
	_expect_true(not "expr_happy_soft" in session.pig_state.unlocked_expressions, "first pig touch previews feedback without collecting the first expression early")
	_expect_eq(session.pig_state.daily_points, points_before + 2, "first daily pig touch grants only its ordinary interaction reward")
	var points_after_pet: int = session.pig_state.daily_points
	var poke_reaction: Dictionary = session.poke_pig()
	_expect_eq(str(poke_reaction.get("kind", "")), "poke", "snout touch resolves to the poke interaction")
	_expect_eq(str(poke_reaction.get("category", "")), "wronged", "poke interaction requests an immediate wronged expression")
	_expect_eq(str(poke_reaction.get("expression_id", "")), "expr_wronged_poke", "poke reaction uses a permanent expression ID without unlocking it early")
	_expect_true(not "expr_wronged_poke" in session.pig_state.unlocked_expressions, "poke feedback does not bypass the collectible expression condition")
	_expect_eq(session.pig_state.daily_points, points_after_pet, "pet and poke share one daily reward decay path instead of adding a click-farming route")
	var interaction_key := "pet:%s" % GameClock.local_date_string(touch_unix)
	_expect_eq(int(session.pig_state.interaction_counts.get(interaction_key, 0)), 2, "pet and poke are counted together for repeat-interaction decay")
	_expect_eq(toast_keys, ["TOAST_PET", "TOAST_POKE"], "both touch types emit their own localized short phrase")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_onboarding_expression_unlock() -> void:
	var base := "user://piggy_onboarding_expression_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.pig_state.name = "Onboarding Pig"
	session.pig_state.tutorial_step = 1
	var starting_points: int = session.pig_state.daily_points
	var starting_xp: int = session.pig_state.familiarity_xp
	session.pet_pig()
	_expect_true(not "expr_happy_soft" in session.pig_state.unlocked_expressions, "onboarding pet leaves the first collectible expression for the feed step")
	_expect_eq(session.pig_state.tutorial_step, 2, "onboarding pet advances to the feed step")
	_expect_true(session.feed("snack_apple"), "first onboarding feed succeeds")
	_expect_true("expr_happy_soft" in session.pig_state.unlocked_expressions, "first onboarding feed unlocks the first collectible expression")
	_expect_true("ach_first_expression" in session.pig_state.unlocked_achievements, "first-feed expression unlock also evaluates the first-expression achievement")
	_expect_eq(session.pig_state.daily_points, starting_points + 5, "pet, snack cost, first-feed reward and expression reward preserve the 75-point onboarding balance")
	_expect_eq(session.pig_state.familiarity_xp, starting_xp + 5, "pet and first feed preserve the five-XP onboarding balance")
	_expect_eq(session.pig_state.tutorial_step, 3, "first feed advances the tutorial to furniture")
	var first_unlock_date: int = int(session.pig_state.expression_unlock_dates.get("expr_happy_soft", 0))
	var points_after_first_feed: int = session.pig_state.daily_points
	var xp_after_first_feed: int = session.pig_state.familiarity_xp
	_expect_true(session.feed("snack_apple"), "repeat onboarding feed remains available")
	_expect_eq(session.pig_state.daily_points, points_after_first_feed - 10, "repeat feed pays only the snack cost without another point reward")
	_expect_eq(session.pig_state.familiarity_xp, xp_after_first_feed, "repeat feed grants no duplicate familiarity reward")
	_expect_eq(int(session.pig_state.expression_unlock_dates.get("expr_happy_soft", 0)), first_unlock_date, "repeat feed does not duplicate the first expression unlock")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_tutorial_progression() -> void:
	var base := "user://piggy_tutorial_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	_expect_true(session.skip_tutorial(), "unnamed first launch can skip the optional naming tutorial")
	_expect_true(session.pig_state.tutorial_skipped and session.pig_state.name.is_empty(), "skipping first-run naming keeps the persisted identity empty")
	var persisted_skip: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted_skip.get("ok", false))
			and bool(persisted_skip.data.pig_state.tutorial_skipped)
			and str(persisted_skip.data.pig_state.name).is_empty(),
		"first-run tutorial skip persists with the localized default display-name contract"
	)
	_expect_true(session.restart_tutorial(), "an unnamed skipped tutorial can be reopened from help")
	_expect_true(session.set_pig_name("Tutorial Pig"), "naming command accepts the first localized onboarding choice")
	for completed_step: int in 5:
		session.complete_tutorial_step(completed_step)
		_expect_eq(session.pig_state.tutorial_step, completed_step + 1, "tutorial advances one action at a time through album step %d" % completed_step)
	var persisted_album_step: Dictionary = session.save_service.load_game()
	_expect_eq(int(persisted_album_step.data.pig_state.tutorial_step), 5, "opening the album commits its onboarding step immediately")
	_expect_true(not session.set_desktop_mode(true), "desktop mode remains locked before familiarity level two")
	session.pig_state.familiarity_level = 2
	_expect_true(session.set_desktop_mode(true), "desktop mode accepts entry at familiarity level two")
	_expect_eq(session.pig_state.tutorial_step, 6, "entering desktop mode completes the desktop tutorial step")
	var persisted_desktop_step: Dictionary = session.save_service.load_game()
	_expect_eq(int(persisted_desktop_step.data.pig_state.tutorial_step), 6, "entering desktop mode commits its onboarding step before the window transition")
	_expect_true(not session.set_tendency("rest"), "today's tendency remains locked before familiarity level five")
	session.pig_state.familiarity_level = 5
	_expect_true(session.set_tendency("rest"), "unlocked tendency accepts a tutorial selection")
	_expect_eq(session.pig_state.tutorial_step, 7, "selecting a tendency completes the onboarding sequence")
	session.restart_tutorial()
	_expect_eq(session.pig_state.tutorial_step, 1, "help replay restarts after naming an existing pig")
	session.skip_tutorial()
	var skipped_step: int = session.pig_state.tutorial_step
	session.complete_tutorial_step(6)
	_expect_eq(session.pig_state.tutorial_step, skipped_step, "skipped tutorial does not advance behind the player")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_state_roundtrip() -> void:
	var source := PigState.new()
	source.life_photos["event_move_in"] = {"path":"user://photo.png","captured_unix":123}
	source.active_seconds = 1234.5
	source.ending_unlocked = true
	source.ending_seen = true
	source.favorite_desktop_expression = "expr_happy_soft"
	source.current_photo_frame = "berry"
	var restored := PigState.new()
	restored.load_dict(source.to_dict())
	_expect_eq(restored.life_photos.event_move_in.path, "user://photo.png", "life photo metadata survives save roundtrip")
	_expect_eq(restored.active_seconds, 1234.5, "active companion time survives save roundtrip")
	_expect_true(restored.ending_unlocked and restored.ending_seen, "ending state survives save roundtrip")
	_expect_eq(restored.favorite_desktop_expression, "expr_happy_soft", "desktop expression favorite survives roundtrip")
	_expect_eq(restored.current_photo_frame, "berry", "selected album photo frame survives roundtrip")


func _test_important_unlock_autosave() -> void:
	var base := "user://piggy_important_unlock_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.call("_connect_modules")
	_expect_true(session.pig_state.unlock("achievement", "ach_robot_knight", GameClock.now_unix()), "important unlock fixture adds new permanent content")
	await process_frame
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(bool(persisted.get("ok", false)), "important content unlock autosaves after its transaction")
	if bool(persisted.get("ok", false)):
		_expect_true("ach_robot_knight" in persisted.data.pig_state.unlocked_achievements, "important unlock autosave contains the permanent content ID")
	else:
		_expect_true(false, "important unlock autosave contains the permanent content ID")
	_expect_true(session.pig_state.unlock("achievement", "ach_first_expression", GameClock.now_unix()), "explicit save coalescing fixture adds a second unlock")
	_expect_eq(session.save_game(), OK, "transaction-end save commits a pending important unlock immediately")
	await process_frame
	_expect_true(FileAccess.file_exists(session.save_service.backup_1_path), "explicit transaction save rotates one verified backup")
	_expect_true(not FileAccess.file_exists(session.save_service.backup_2_path), "deferred unlock save coalesces instead of rotating a redundant second backup")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_exit_checkpoint() -> void:
	var base := "user://piggy_exit_checkpoint_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.save_service = SaveService.new(base)
	root.add_child(session)
	session.pig_state.name = "Generation One"
	session.pig_state.daily_points = 101
	_expect_eq(session.call("_save_game_at", 1), OK, "exit checkpoint fixture writes its oldest recovery generation")
	session.pig_state.name = "Generation Two"
	session.pig_state.daily_points = 202
	_expect_eq(session.call("_save_game_at", 2), OK, "exit checkpoint fixture writes its newest recovery generation")
	while fmod(Time.get_unix_time_from_system(), 1.0) > 0.1:
		await process_frame
	session.pig_state.name = "Safe Exit"
	session.pig_state.daily_points = 321
	session.ui_scale = 1.25
	session.reduce_motion = true
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var backup_1_before: Dictionary = session.save_service.call("_read_valid", session.save_service.backup_1_path) as Dictionary
	var backup_2_before: Dictionary = session.save_service.call("_read_valid", session.save_service.backup_2_path) as Dictionary
	_expect_eq(int(backup_1_before.pig_state.daily_points), 202, "focus-out checkpoint retains the immediately previous progression generation")
	_expect_eq(int(backup_2_before.pig_state.daily_points), 101, "focus-out checkpoint retains the oldest recovery generation")
	session.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var result: Dictionary = session.checkpoint_for_exit()
	_expect_eq(result.get("progression_error", FAILED), OK, "normal exit checkpoints progression before closing")
	_expect_eq(result.get("settings_error", FAILED), OK, "normal exit checkpoints machine settings before closing")
	var backup_1_after: Dictionary = session.save_service.call("_read_valid", session.save_service.backup_1_path) as Dictionary
	var backup_2_after: Dictionary = session.save_service.call("_read_valid", session.save_service.backup_2_path) as Dictionary
	_expect_eq(backup_1_after, backup_1_before, "close notification and exit command do not rotate duplicate progression into backup1")
	_expect_eq(backup_2_after, backup_2_before, "close notification and exit command do not displace the oldest recovery backup")
	_expect_true(not FileAccess.file_exists(session.save_service.temp_path), "repeated exit checkpoints leave no temporary progression file")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(bool(persisted.get("ok", false)), "normal exit checkpoint writes a valid progression payload")
	_expect_eq(str(persisted.data.pig_state.name), "Safe Exit", "normal exit checkpoint preserves the current pig identity")
	_expect_eq(int(persisted.data.pig_state.daily_points), 321, "normal exit checkpoint preserves current progression")
	var settings: Dictionary = session.save_service.load_settings()
	_expect_eq(float(settings.get("ui_scale", 0.0)), 1.25, "normal exit checkpoint preserves machine UI scale")
	_expect_true(bool(settings.get("reduce_motion", false)), "normal exit checkpoint preserves machine accessibility settings")
	var blocker_path := base + "/not_a_directory"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	_expect_true(blocker != null, "failed exit fixture creates a file that blocks child save paths")
	if blocker != null:
		blocker.store_string("block child paths")
		blocker.close()
	var exit_failures: Array[Dictionary] = []
	session.exit_checkpoint_failed.connect(func(failure: Dictionary) -> void:
		exit_failures.append(failure.duplicate(true))
	)
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = blocker_path + "/savegame.tmp.json"
	_expect_true(not session.request_exit(), "progression checkpoint failure refuses to quit")
	_expect_eq(exit_failures.size(), 1, "progression checkpoint failure emits one structured exit failure")
	var progression_failure: Dictionary = exit_failures[0] if exit_failures.size() == 1 else {}
	_expect_true(int(progression_failure.get("progression_error", OK)) != OK, "exit failure reports the progression write error")
	_expect_eq(progression_failure.get("settings_error", FAILED), OK, "progression failure still checkpoints machine settings")
	await process_frame
	_expect_true(session.is_inside_tree(), "failed progression checkpoint keeps the process running")
	session.save_service.temp_path = normal_temp_path
	var normal_settings_path: String = session.save_service.settings_path
	session.save_service.settings_path = blocker_path + "/machine_settings.json"
	_expect_true(not session.request_exit(), "machine-settings checkpoint failure refuses to quit")
	_expect_eq(exit_failures.size(), 2, "machine-settings checkpoint failure emits one additional structured exit failure")
	var settings_failure: Dictionary = exit_failures[1] if exit_failures.size() == 2 else {}
	_expect_eq(settings_failure.get("progression_error", FAILED), OK, "settings failure still checkpoints progression")
	_expect_true(int(settings_failure.get("settings_error", OK)) != OK, "exit failure reports the machine-settings write error")
	await process_frame
	_expect_true(session.is_inside_tree(), "failed settings checkpoint keeps the process running")
	session.save_service.settings_path = normal_settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_furniture_slots() -> void:
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	var bed_slots: Array[String] = session.compatible_furniture_slots("furn_bed_basic")
	var pillow_slots: Array[String] = session.compatible_furniture_slots("furn_pillow_cloud")
	_expect_true("sleep_1" in bed_slots and bed_slots.size() == 1, "large sleep furniture has an explicit slot")
	_expect_true("sleep_2" in pillow_slots and "sleep_3" in pillow_slots, "small sleep furniture exposes both compatible slots")
	_expect_true(not session.is_room_area_unlocked("snack"), "snack area remains locked before familiarity level three")
	_expect_true(session.compatible_furniture_slots("furn_weather_charm").is_empty(), "locked window furniture exposes no placement slots")
	session.pig_state.owned_furniture.append("furn_table_snack")
	_expect_true(not session.place_furniture("snack_1", "furn_table_snack"), "session facade rejects placement inside a locked room area")
	session.pig_state.familiarity_level = 6
	var charm_slots: Array[String] = session.compatible_furniture_slots("furn_weather_charm")
	_expect_true(session.is_room_area_unlocked("window"), "window area opens at familiarity level six")
	_expect_true("window_4" in charm_slots and charm_slots.size() == 1, "wall furniture cannot enter floor slots")
	session.free()


func _test_furniture_invitation() -> void:
	var base := "user://piggy_furniture_invitation_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	var now: Array[int] = [1000]
	session.clock = GameClock.new(func() -> int: return now[0])
	var before_interest: float = session.pig_state.interest
	_expect_true(session.invite_to_furniture("furn_bed_basic"), "placed behavior furniture accepts an invitation")
	var bed: Dictionary = session.catalog.get_item("furniture", "furn_bed_basic")
	_expect_eq(str(session.simulation.current_behavior.get("id", "")), str(bed.get("behavior_id", "")), "furniture invitation starts its linked behavior")
	_expect_eq(session.pig_state.interest, before_interest + 1.0, "furniture invitation grants the small interest response")
	var persisted_invitation: Dictionary = session.save_service.load_game()
	_expect_true(
		str(persisted_invitation.data.simulation.current_behavior_id) == str(bed.get("behavior_id", ""))
			and float(persisted_invitation.data.pig_state.interest) == session.pig_state.interest,
		"furniture invitation commits its behavior timer and interest response together"
	)
	session.simulation.advance(1.0, session.pig_state, session.catalog.behaviors, session.behavior_director, now[0], false, false)
	var remaining_before_repeat: float = session.simulation.remaining_seconds
	var interest_after_first_invitation: float = session.pig_state.interest
	_expect_true(not session.invite_to_furniture("furn_bed_basic"), "an active furniture behavior cannot be restarted for repeat interaction gains")
	_expect_eq(session.simulation.remaining_seconds, remaining_before_repeat, "rejected active invitation preserves the current behavior timer")
	_expect_eq(session.pig_state.interest, interest_after_first_invitation, "rejected active invitation grants no repeat interest")
	session.simulation.advance(remaining_before_repeat, session.pig_state, session.catalog.behaviors, session.behavior_director, now[0], false, false)
	var behavior_id: String = str(bed.get("behavior_id", ""))
	var cooldown_until: int = int(session.behavior_director.cooldown_until.get(behavior_id, 0))
	_expect_true(cooldown_until > now[0], "completed invited behavior records its normal anti-farming cooldown")
	var interest_before_cooldown_retry: float = session.pig_state.interest
	_expect_true(not session.invite_to_furniture("furn_bed_basic"), "furniture invitation respects the completed behavior cooldown")
	_expect_eq(session.pig_state.interest, interest_before_cooldown_retry, "rejected cooldown invitation grants no repeat interest")
	now[0] = cooldown_until
	_expect_true(session.invite_to_furniture("furn_bed_basic"), "furniture invitation becomes available at the cooldown boundary")
	_expect_true(not session.invite_to_furniture("furn_camera"), "unplaced furniture cannot receive an invitation")
	session.pig_state.placed_furniture["sleep_2"] = "furn_robot_dock"
	var reaction_key: Array[String] = [""]
	session.toast_requested.connect(func(key: String, _values: Dictionary) -> void: reaction_key[0] = key)
	var points_before_reaction: int = session.pig_state.daily_points
	_expect_true(session.react_to_furniture("furn_robot_dock"), "placed decoration furniture provides its data-driven short reaction")
	_expect_eq(reaction_key[0], "FURN_ROBOT_DOCK_REACTION", "decoration reaction uses its localized content key")
	_expect_eq(session.pig_state.daily_points, points_before_reaction, "decoration reactions never become a point-farming action")
	_expect_true(not session.react_to_furniture("furn_fruit_bowl"), "unplaced decoration cannot be reacted to")
	_expect_true(not session.react_to_furniture("furn_bed_basic"), "functional furniture without a reaction key stays on the invitation path")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_outfit_rules() -> void:
	var base := "user://piggy_outfit_rule_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	_expect_eq(session.catalog.load_all(), [], "outfit rule catalog loads")
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	_expect_true(not session.equip_outfit("outfit_berry_beret"), "an unowned outfit cannot be equipped")
	session.pig_state.owned_outfits.append("outfit_berry_beret")
	_expect_true(session.equip_outfit("outfit_berry_beret"), "an owned outfit can be equipped")
	_expect_eq(session.pig_state.current_outfit, "outfit_berry_beret", "equipped outfit is stored by permanent ID")
	_expect_true(session.equip_outfit(""), "the player can return to the undecorated pig")
	_expect_eq(session.pig_state.current_outfit, "", "removing an outfit clears the equipped slot")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_room_palette_rules() -> void:
	var base := "user://piggy_palette_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.pig_state.familiarity_level = 6
	_expect_eq(session.unlocked_room_palettes(), ["rose"], "only rose palette is available before level seven")
	_expect_true(not session.set_room_palette("mint"), "mint palette rejects an early selection")
	session.pig_state.familiarity_level = 7
	_expect_true("mint" in session.unlocked_room_palettes(), "mint palette unlocks at level seven")
	_expect_true(session.set_room_palette("mint"), "unlocked mint palette can be selected")
	for index: int in 35:
		session.pig_state.unlocked_expressions.append(str(session.catalog.expressions[index].id))
	_expect_true(not "night" in session.unlocked_room_palettes(), "night palette stays locked below 36 expressions")
	session.pig_state.unlocked_expressions.append(str(session.catalog.expressions[35].id))
	_expect_true("night" in session.unlocked_room_palettes(), "night palette unlocks with 36 expressions")
	_expect_true(session.set_room_palette("night"), "unlocked night palette can be selected")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and str((persisted.get("data", {}) as Dictionary).get("pig_state", {}).get("current_room_palette", "")) == "night",
		"selected room palette persists through the production save boundary"
	)
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_photo_frame_rules() -> void:
	var base := "user://piggy_photo_frame_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	for index: int in 15:
		session.pig_state.unlocked_expressions.append(str(session.catalog.expressions[index].id))
	_expect_eq(session.unlocked_photo_frames(), ["plain"], "only the plain album frame is available below the first collection threshold")
	_expect_true(not session.set_photo_frame("berry"), "berry album frame rejects an early selection")
	session.pig_state.unlocked_expressions.append(str(session.catalog.expressions[15].id))
	_expect_true("berry" in session.unlocked_photo_frames(), "collecting 16 expressions unlocks the berry album frame")
	_expect_true(session.set_photo_frame("berry"), "an unlocked album frame can be selected")
	_expect_eq(session.pig_state.current_photo_frame, "berry", "selected album frame is stored in progression state")
	for index: int in range(16, 48):
		session.pig_state.unlocked_expressions.append(str(session.catalog.expressions[index].id))
	_expect_true("star" in session.unlocked_photo_frames(), "collecting all 48 expressions unlocks the star album frame")
	_expect_true(session.set_photo_frame("star"), "the completion album frame can be selected")
	_expect_true(not session.set_photo_frame("unknown"), "unknown album frame IDs are rejected")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and str((persisted.get("data", {}) as Dictionary).get("pig_state", {}).get("current_photo_frame", "")) == "star",
		"selected album frame persists through the production save boundary"
	)
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_desktop_expression_favorite_rules() -> void:
	var base := "user://piggy_expression_favorite_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	var expression_id := "expr_happy_snack"
	_expect_true(not session.set_favorite_desktop_expression(expression_id), "locked expressions cannot become the desktop idle favorite")
	session.pig_state.unlocked_expressions.append("expr_missing")
	_expect_true(not session.set_favorite_desktop_expression("expr_missing"), "unknown expression IDs cannot become the desktop idle favorite")
	session.pig_state.unlocked_expressions.erase("expr_missing")
	session.pig_state.unlocked_expressions.append(expression_id)
	_expect_true(session.set_favorite_desktop_expression(expression_id), "an unlocked expression can become the desktop idle favorite")
	_expect_eq(session.pig_state.favorite_desktop_expression, expression_id, "desktop idle favorite is stored in progression state")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and str((persisted.get("data", {}) as Dictionary).get("pig_state", {}).get("favorite_desktop_expression", "")) == expression_id,
		"desktop idle favorite is committed through the session facade"
	)
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_ending_trigger() -> void:
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.pig_state.familiarity_level = 10
	for event: Dictionary in session.catalog.events:
		session.pig_state.seen_events.append(str(event.id))
	var last_event_id: String = session.pig_state.seen_events.pop_back()
	session.call("_sync_ending_state", false)
	_expect_true(not session.pig_state.ending_unlocked, "ending waits for every core event")
	session.pig_state.seen_events.append(last_event_id)
	session.call("_sync_ending_state", false)
	_expect_true(session.pig_state.ending_unlocked, "level ten plus all events unlocks the ending")
	session.pig_state.ending_seen = true
	_expect_true(session.pig_state.ending_unlocked and session.pig_state.ending_seen, "ending completion retains free companion mode state")
	session.free()


func _test_steam_adapter() -> void:
	var full_app_type: Variant = ProjectSettings.get_setting("steam/initialization/app_data/app_type", -1)
	var demo_app_type: Variant = ProjectSettings.get_setting("steam/initialization/app_data/app_type.demo", -1)
	var active_app_type: Variant = ProjectSettings.get_setting_with_override("steam/initialization/app_data/app_type") if ProjectSettings.has_setting("steam/initialization/app_data/app_type") else -1
	var auto_init: Variant = ProjectSettings.get_setting("steam/initialization/processes/initialize_on_startup", true)
	var embedded_callbacks: Variant = ProjectSettings.get_setting("steam/initialization/processes/embed_callbacks", true)
	_expect_true(full_app_type is int and int(full_app_type) == 0, "full Steam profile declares the game App ID selector")
	_expect_true(demo_app_type is int and int(demo_app_type) == 1, "demo Steam profile declares a separate Demo App ID selector")
	_expect_true(active_app_type is int and int(active_app_type) == (1 if ReleaseProfile.is_demo() else 0), "the active export feature selects the correct Steam application type")
	_expect_true(auto_init is bool and not bool(auto_init), "only SteamService may initialize the native backend")
	_expect_true(embedded_callbacks is bool and not bool(embedded_callbacks), "only SteamService may pump native callbacks")
	var steam: Node = SteamServiceScript.new()
	_expect_true(not steam.available, "Steam adapter starts in offline stub mode")
	_expect_true(steam.unlock_achievement("ach_stub"), "offline stub records an achievement")
	_expect_true(not steam.unlock_achievement("ach_stub"), "offline stub deduplicates achievements")
	_expect_true(steam.is_achievement_unlocked("ach_stub"), "offline stub exposes recorded achievements")
	steam.set_rich_presence("RICH_ROOM")
	_expect_eq(steam.rich_presence, "RICH_ROOM", "offline stub retains rich-presence state")
	_expect_true(steam.set_stat("stat_events", 4), "offline stub records an integer statistic")
	_expect_true(not steam.set_stat("stat_events", 4), "offline stub deduplicates unchanged statistics")
	steam.sync_stats({"stat_events":8,"stat_familiarity_level":5})
	_expect_eq(steam.get_stat("stat_events"), 8, "offline stub updates a synchronized statistic")
	_expect_eq(steam.get_stat("stat_familiarity_level"), 5, "offline stub retains synchronized progress statistics")
	var full_cloud: Array[String] = steam.cloud_save_relative_paths("full")
	var demo_cloud: Array[String] = steam.cloud_save_relative_paths("demo")
	_expect_eq(full_cloud.size(), 4, "full Steam Auto-Cloud manifest covers saves, backups and event photos")
	_expect_eq(demo_cloud.size(), 4, "demo Steam Auto-Cloud manifest covers its isolated saves, backups and event photos")
	_expect_true(full_cloud.all(func(path: String) -> bool: return path.begins_with(ReleaseProfile.save_relative_root("full") + "/")), "full cloud paths stay inside the full profile root")
	_expect_true(demo_cloud.all(func(path: String) -> bool: return path.begins_with(ReleaseProfile.save_relative_root("demo") + "/")), "demo cloud paths stay inside the demo profile root")
	_expect_true(not full_cloud.any(func(path: String) -> bool: return path in demo_cloud), "full and demo Auto-Cloud paths are disjoint")
	_expect_true(full_cloud[-1].ends_with("photos/*.png") and demo_cloud[-1].ends_with("photos/*.png"), "event album photos are included in both cloud manifests")
	_expect_true(SteamServiceScript._init_succeeded(true), "Steam bool success is parsed")
	_expect_true(SteamServiceScript._init_succeeded(0), "GodotSteam zero status is parsed")
	_expect_true(not SteamServiceScript._init_succeeded(1), "GodotSteam generic initialization failure is rejected")
	_expect_true(SteamServiceScript._init_succeeded({"success":true}), "Steam dictionary success is parsed")
	_expect_true(not SteamServiceScript._init_succeeded({"status":2}), "Steam failure status is rejected")
	_expect_true(SteamServiceScript._stats_result_succeeded(1), "Steam current-stat success result is parsed")
	_expect_true(not SteamServiceScript._stats_result_succeeded(0), "Steam no-result status is not mistaken for current-stat success")
	var modern := SteamServiceScript.new()
	modern.unlock_achievement("ach_modern")
	modern.set_stat("stat_events", 9)
	modern.set_rich_presence("RICH_ROOM")
	var modern_fake := FakeModernSteamStatsBackend.new()
	modern.call("_initialize_backend", modern_fake)
	_expect_true(modern.available and modern.user_stats_ready, "GodotSteam 4.20 initialization is the modern current-stat readiness boundary")
	_expect_true(modern_fake.init_app_id == 0 and not modern_fake.embed_callbacks, "GodotSteam 4.20 initialization preserves the configured App ID and manual callback pump")
	_expect_eq(modern_fake.achievements, ["ach_modern"], "modern initialization flushes queued achievements")
	_expect_eq(modern_fake.integer_stats.get("stat_events"), 9, "modern initialization flushes queued statistics")
	_expect_eq(modern_fake.store_count, 1, "modern initialization commits queued Steam state once")
	_expect_eq(modern_fake.rich_presence.get("steam_display"), "#RICH_ROOM", "modern initialization restores queued rich presence")
	var failed_modern := SteamServiceScript.new()
	var failed_modern_fake := FakeModernSteamStatsBackend.new()
	failed_modern_fake.init_status = 1
	failed_modern.call("_initialize_backend", failed_modern_fake)
	_expect_true(not failed_modern.available and not failed_modern.user_stats_ready, "failed GodotSteam initialization remains in offline mode")
	var queued := SteamServiceScript.new()
	var fake := FakeSteamStatsBackend.new()
	queued.set("_backend", fake)
	queued.set("available", true)
	queued.set_rich_presence("RICH_DESKTOP")
	_expect_eq(fake.rich_presence.get("activity"), "RICH_DESKTOP", "available Steam backend receives the broad activity token")
	_expect_eq(fake.rich_presence.get("steam_display"), "#RICH_DESKTOP", "available Steam backend receives the localized display token")
	_expect_true(queued.unlock_achievement("ach_after_stats"), "pre-handshake achievement is retained locally")
	_expect_true(queued.set_stat("stat_events", 7), "pre-handshake statistic is retained locally")
	_expect_true(fake.achievements.is_empty() and fake.integer_stats.is_empty(), "Steam writes wait for current stats readiness")
	queued.call("_request_current_stats")
	_expect_eq(fake.request_count, 1, "Steam adapter requests current stats exactly once")
	_expect_true(fake.achievements.is_empty() and fake.integer_stats.is_empty(), "Steam writes remain queued before the callback")
	fake.current_stats_received.emit(123, 1, 456)
	_expect_true(queued.user_stats_ready, "current stats callback marks the backend ready")
	_expect_eq(fake.achievements, ["ach_after_stats"], "queued achievement flushes after current stats arrive")
	_expect_eq(fake.integer_stats.get("stat_events"), 7, "queued statistic flushes after current stats arrive")
	_expect_eq(fake.store_count, 1, "queued Steam changes are committed in one store operation")
	queued.sync_achievements(["ach_after_stats"])
	queued.sync_stats({"stat_events":7})
	_expect_eq(fake.store_count, 1, "already submitted Steam state is not redundantly stored")
	queued.call("_exit_tree")
	_expect_eq(fake.clear_presence_count, 1, "Steam rich presence is cleared during adapter shutdown")
	_expect_eq(fake.shutdown_count, 1, "Steam backend is shut down during adapter teardown")
	queued.free()
	failed_modern.free()
	modern.free()
	steam.free()


func _test_steam_store_retry() -> void:
	var steam := SteamServiceScript.new()
	var backend := FakeRetrySteamStatsBackend.new()
	steam.unlock_achievement("ach_retry")
	steam.set_stat("stat_events", 12)
	steam.call("_initialize_backend", backend)
	_expect_eq(backend.store_count, 1, "Steam queued writes attempt their first store once")
	_expect_true(steam.is_achievement_unlocked("ach_retry") and steam.get_stat("stat_events") == 12, "a rejected Steam store preserves authoritative local progress")
	steam.call("_process", 59.0)
	_expect_eq(backend.store_count, 1, "a rejected Steam store waits sixty seconds instead of retrying each frame")
	backend.reject_store = false
	steam.call("_process", 1.0)
	_expect_eq(backend.store_count, 2, "a rejected Steam store retries without requiring new gameplay changes")
	steam.call("_process", 60.0)
	_expect_eq(backend.store_count, 2, "successful Steam stores without an async callback do not repeat forever")
	_expect_eq(backend.achievements, ["ach_retry"], "Steam store retries do not duplicate achievement writes")
	steam.free()


func _test_steam_async_store_retry() -> void:
	var steam := SteamServiceScript.new()
	var backend := FakeAsyncSteamStatsBackend.new()
	backend.reject_store = false
	steam.unlock_achievement("ach_async_retry")
	steam.set_stat("stat_events", 14)
	steam.call("_initialize_backend", backend)
	steam.call("_process", 60.0)
	_expect_eq(backend.store_count, 1, "an accepted asynchronous Steam store waits for its result instead of sending duplicates")
	backend.user_stats_stored.emit(123, 2)
	steam.call("_process", 59.0)
	_expect_eq(backend.store_count, 1, "an asynchronous Steam store failure starts a fresh sixty-second retry delay")
	steam.call("_process", 1.0)
	_expect_eq(backend.store_count, 2, "Steam retries a failed asynchronous store without a new unlock")
	backend.user_stats_stored.emit(123, 1)
	steam.call("_process", 60.0)
	_expect_eq(backend.store_count, 2, "a confirmed successful asynchronous Steam store clears its pending retry")
	_expect_true(steam.is_achievement_unlocked("ach_async_retry") and steam.get_stat("stat_events") == 14, "Steam asynchronous failures never roll back local achievements or statistics")
	steam.free()


func _test_steam_rejected_write_retry() -> void:
	var steam := SteamServiceScript.new()
	var backend := FakeRejectedSteamWritesBackend.new()
	steam.unlock_achievement("ach_set_retry")
	steam.set_stat("stat_events", 18)
	steam.call("_initialize_backend", backend)
	_expect_true(backend.achievements.is_empty() and backend.integer_stats.is_empty() and backend.store_count == 0, "rejected Steam setters are not represented as committed backend progress")
	steam.call("_process", 59.0)
	_expect_true(backend.achievement_attempts == 1 and backend.stat_attempts == 1, "rejected Steam setters do not retry each frame")
	backend.reject_writes = false
	steam.call("_process", 1.0)
	_expect_eq(backend.achievements, ["ach_set_retry"], "rejected Steam achievements retry without another local unlock")
	_expect_eq(backend.integer_stats.get("stat_events"), 18, "rejected Steam statistics retry without another local value change")
	_expect_eq(backend.store_count, 1, "recovered Steam setter writes are batched into one store operation")
	steam.call("_process", 60.0)
	_expect_eq(backend.store_count, 1, "recovered Steam setter writes stop retrying after success")
	_expect_true(steam.is_achievement_unlocked("ach_set_retry") and steam.get_stat("stat_events") == 18, "Steam setter failures retain authoritative local achievements and statistics")
	steam.free()


func _test_steam_retry_backoff_updates() -> void:
	var steam := SteamServiceScript.new()
	var backend := FakeRetrySteamStatsBackend.new()
	steam.unlock_achievement("ach_before_backoff")
	steam.set_stat("stat_events", 12)
	steam.call("_initialize_backend", backend)
	steam.call("_process", 30.0)
	steam.set_stat("stat_events", 13)
	_expect_eq(backend.store_count, 1, "a new Steam statistic cannot bypass a failed-store backoff")
	steam.unlock_achievement("ach_during_backoff")
	_expect_eq(backend.store_count, 1, "a new achievement cannot bypass a failed-store backoff")
	steam.call("_process", 29.0)
	_expect_eq(backend.store_count, 1, "new local progress does not shorten the pending retry delay")
	backend.reject_store = false
	steam.call("_process", 1.0)
	_expect_eq(backend.store_count, 2, "new local progress does not postpone the original retry boundary")
	_expect_true(backend.integer_stats.get("stat_events") == 13 and backend.achievements == ["ach_before_backoff", "ach_during_backoff"], "one recovered Steam store includes all latest local progress")
	steam.call("_process", 60.0)
	_expect_eq(backend.store_count, 2, "the recovered latest-progress batch stops retrying")
	steam.free()


func _test_steam_rejected_server_values() -> void:
	var steam := SteamServiceScript.new()
	var backend := FakeAsyncSteamStatsBackend.new()
	backend.reject_store = false
	steam.set_stat("stat_events", 21)
	steam.call("_initialize_backend", backend)
	backend.integer_stats["stat_events"] = 2
	backend.user_stats_stored.emit(123, 8)
	_expect_eq(steam.get_stat("stat_events"), 21, "Steam server constraint rejection never replaces authoritative local game progress")
	steam.call("_process", 60.0)
	_expect_eq(backend.integer_stats.get("stat_events"), 21, "Steam server constraint rejection invalidates the accepted-value cache before retry")
	_expect_eq(backend.store_count, 2, "corrected Steam backend values are retried in one store batch")
	backend.user_stats_stored.emit(123, 1)
	steam.call("_process", 60.0)
	_expect_true(backend.store_count == 2 and backend.integer_stats.get("stat_events") == 21, "confirmed Steam server recovery stops retries while retaining the intended progress")
	steam.free()


func _test_desktop_frame_throttling() -> void:
	_expect_eq(DesktopFramePolicyScript.recommended_fps("run", false, false), DesktopFramePolicyScript.DESKTOP_ACTIVE_FPS, "active desktop behavior keeps 30 FPS")
	_expect_eq(DesktopFramePolicyScript.recommended_fps("sleep", false, false), DesktopFramePolicyScript.DESKTOP_IDLE_FPS, "sleeping desktop behavior throttles below 30 FPS")
	_expect_eq(DesktopFramePolicyScript.recommended_fps("idle", false, true), DesktopFramePolicyScript.DESKTOP_IDLE_FPS, "reduced-motion static idle throttles below 30 FPS")
	_expect_eq(DesktopFramePolicyScript.recommended_fps("walk", true, false), DesktopFramePolicyScript.DESKTOP_IDLE_FPS, "paused animation uses the idle frame limit")
	_expect_true(not DesktopFramePolicyScript.action_transition_ready(44.9, true), "reduced desktop action frequency holds visual changes for the full quiet interval")
	_expect_true(DesktopFramePolicyScript.action_transition_ready(45.0, true), "reduced desktop action frequency releases a pending visual change at the boundary")
	_expect_true(DesktopFramePolicyScript.action_transition_ready(0.0, false), "normal desktop action frequency presents every simulated behavior immediately")


func _test_desktop_roaming_policy() -> void:
	var full: Vector2 = DesktopFramePolicyScript.roaming_bounds(430.0, 280.0, false)
	var reduced: Vector2 = DesktopFramePolicyScript.roaming_bounds(430.0, 280.0, true)
	_expect_true(full.x >= 0.0 and full.y <= 430.0 - 280.0, "desktop roaming stays inside the transparent companion window")
	_expect_true(reduced.y - reduced.x < full.y - full.x, "reduced roaming narrows the desktop companion range")
	_expect_true(is_equal_approx((reduced.x + reduced.y) * 0.5, (full.x + full.y) * 0.5), "reduced roaming remains centered in the available range")
	_expect_true(DesktopFramePolicyScript.roaming_speed(1.0, true) < DesktopFramePolicyScript.roaming_speed(1.0, false), "reduced roaming also lowers desktop walking speed")
	var settings_session: Node = GameSessionScript.new()
	_expect_true(not settings_session.desktop_roaming_reduced(), "desktop roaming remains full when both accessibility options are off")
	settings_session.reduce_desktop_roaming = true
	_expect_true(settings_session.desktop_roaming_reduced(), "the dedicated desktop roaming option activates reduced roaming independently")
	settings_session.reduce_desktop_roaming = false
	settings_session.reduce_motion = true
	_expect_true(settings_session.desktop_roaming_reduced(), "the broader reduced-motion option also activates the low-roaming policy")
	settings_session.free()
	var bounced: Vector2 = DesktopFramePolicyScript.advance_roaming_x(full.y - 1.0, 1.0, 1.0, full, DesktopFramePolicyScript.roaming_speed(1.0, false))
	_expect_true(bounced.x >= full.x and bounced.x <= full.y and bounced.y < 0.0, "desktop walking reflects at the right roaming boundary")
	var long_step: Vector2 = DesktopFramePolicyScript.advance_roaming_x(full.x, -1.0, 600.0, full, DesktopFramePolicyScript.roaming_speed(1.0, false))
	_expect_true(long_step.x >= full.x and long_step.x <= full.y, "long frame gaps cannot move the desktop pig outside its roaming range")


func _test_animation_frame_cadence() -> void:
	_expect_eq(VisualFramePolicyScript.FRAME_STEP, 0.1, "main pig and event staging share a ten-frame-per-second visual cadence")


func _test_event_camera_shake_policy() -> void:
	var active: Vector2 = VisualFramePolicyScript.camera_shake_offset(true, 0.5, 5.0, true, false)
	_expect_true(active != Vector2.ZERO, "a marked event step produces a subtle camera offset when enabled")
	_expect_eq(VisualFramePolicyScript.camera_shake_offset(true, 0.5, 5.0, false, false), Vector2.ZERO, "the independent camera-shake setting disables marked event motion")
	_expect_eq(VisualFramePolicyScript.camera_shake_offset(true, 0.5, 5.0, true, true), Vector2.ZERO, "reduced motion overrides camera shake as the broader accessibility policy")
	_expect_eq(VisualFramePolicyScript.camera_shake_offset(false, 0.5, 5.0, true, false), Vector2.ZERO, "unmarked event steps never shake the camera")


func _test_desktop_passthrough_polygon() -> void:
	var pig_rect := Rect2(24, 42, 280, 230)
	var polygon: PackedVector2Array = DesktopFramePolicyScript.mouse_passthrough_polygon(pig_rect, Vector2i(430, 280), false)
	_expect_true(polygon.size() >= 4, "desktop passthrough policy produces a non-empty interaction polygon")
	_expect_true(not Geometry2D.triangulate_polygon(polygon).is_empty(), "desktop passthrough interaction polygon is simple and triangulatable")
	_expect_true(Geometry2D.is_point_in_polygon(pig_rect.get_center(), polygon), "desktop pig remains inside the clickable region")
	_expect_true(Geometry2D.is_point_in_polygon(Vector2(367, 35), polygon), "desktop control point remains inside the clickable region")
	_expect_true(not Geometry2D.is_point_in_polygon(Vector2(5, 5), polygon), "transparent top-left desktop area remains mouse-passable")
	_expect_true(not Geometry2D.is_point_in_polygon(Vector2(420, 220), polygon), "transparent bottom-right desktop area remains mouse-passable")
	var compact: PackedVector2Array = DesktopFramePolicyScript.mouse_passthrough_polygon(Rect2(12, 17, 140, 115), Vector2i(215, 140), true)
	for percentage: int in [50, 75, 100, 125, 150]:
		var factor: float = float(percentage) / 100.0
		var window_size := Vector2i(Vector2(430, 280) * factor)
		var scaled_pig := Rect2(Vector2(24.0 * factor, window_size.y - 230.0 * factor - 8.0), Vector2(280, 230) * factor)
		for show_bubble: bool in [false, true]:
			var scaled_polygon: PackedVector2Array = DesktopFramePolicyScript.mouse_passthrough_polygon(scaled_pig, window_size, show_bubble)
			var label: String = "scale=%d%% bubble=%s" % [percentage, show_bubble]
			_expect_true(not Geometry2D.triangulate_polygon(scaled_polygon).is_empty(), "%s produces a single valid native hit polygon even when pig and controls overlap" % label)
			_expect_true(
				Geometry2D.is_point_in_polygon(scaled_pig.position + scaled_pig.size * Vector2(0.27, 0.50), scaled_polygon)
					and Geometry2D.is_point_in_polygon(scaled_pig.position + scaled_pig.size * Vector2(0.72, 0.50), scaled_polygon),
				"%s preserves both scaled character hit regions" % label
			)
			_expect_true(not Geometry2D.is_point_in_polygon(Vector2(1, 1), scaled_polygon), "%s does not swallow the transparent corner" % label)
	var compact_inside: bool = not compact.is_empty()
	for point: Vector2 in compact:
		compact_inside = compact_inside and point.x >= 0.0 and point.y >= 0.0 and point.x <= 215.0 and point.y <= 140.0
	_expect_true(compact_inside, "compact desktop event-bubble polygon stays inside the minimum window")
	_expect_eq(DesktopFramePolicyScript.event_bubble_rect(Vector2i(215, 140)), Rect2(27, 68, 180, 52), "desktop event bubble keeps its readable width and eight-pixel margin even for a compact geometry input")


func _test_desktop_control_rail() -> void:
	for percentage: int in [50, 75, 100, 125, 150]:
		var factor: float = float(percentage) / 100.0
		var window_size: Vector2i = DesktopFramePolicyScript.companion_window_size(factor)
		var minimum: Vector2i = DesktopFramePolicyScript.minimum_companion_window_size(factor)
		var original_area := Vector2i(Vector2(430, 280) * factor)
		var character_size: Vector2 = Vector2(280, 230) * factor
		_expect_eq(DesktopFramePolicyScript.character_area_width(float(window_size.x)), float(original_area.x), "scale=%d%% reserves controls without reducing the original walking area" % percentage)
		_expect_true(minimum.x <= window_size.x and minimum.y <= window_size.y, "scale=%d%% preferred companion size respects its complete-content native resize floor" % percentage)
		for actual_size: Vector2i in [window_size, minimum]:
			var bounds: Vector2 = DesktopFramePolicyScript.roaming_bounds(DesktopFramePolicyScript.character_area_width(float(actual_size.x)), character_size.x, false)
			var pig_rect := Rect2(Vector2(bounds.y, actual_size.y - character_size.y - 8.0), character_size)
			var bubble: Rect2 = DesktopFramePolicyScript.event_bubble_rect(actual_size)
			var bar := Rect2(DesktopFramePolicyScript.control_bar_rect(actual_size))
			var label: String = "scale=%d%% window=%s" % [percentage, actual_size]
			_expect_true(pig_rect.position.x >= 0.0 and pig_rect.position.y >= 0.0 and pig_rect.end.x <= actual_size.x and pig_rect.end.y <= actual_size.y, "%s keeps the selected character size wholly visible even after resizing" % label)
			_expect_true(not pig_rect.intersects(bubble) and not pig_rect.intersects(bar), "%s reserves the whole roaming envelope outside both control regions" % label)
			for show_bubble: bool in [false, true]:
				var polygon: PackedVector2Array = DesktopFramePolicyScript.mouse_passthrough_polygon(pig_rect, actual_size, show_bubble)
				_expect_true(not Geometry2D.triangulate_polygon(polygon).is_empty() and Geometry2D.is_point_in_polygon(pig_rect.get_center(), polygon) and Geometry2D.is_point_in_polygon(bar.get_center(), polygon) and (not show_bubble or Geometry2D.is_point_in_polygon(bubble.get_center(), polygon)), "%s bubble=%s keeps all real targets in one native hit polygon" % [label, show_bubble])
				_expect_true(not Geometry2D.is_point_in_polygon(Vector2(actual_size.x - 170, 20), polygon), "%s bubble=%s does not turn empty rail space into an invisible desktop blocker" % [label, show_bubble])


func _test_desktop_visibility_recovery() -> void:
	var screens: Array[Rect2i] = [Rect2i(0, 0, 1920, 1080), Rect2i(1920, 0, 2560, 1440)]
	_expect_eq(DesktopFramePolicyScript.resolve_screen(1, 0, 0, screens.size()), 1, "desktop screen policy restores a valid persisted display")
	_expect_eq(DesktopFramePolicyScript.resolve_screen(2, 1, 0, screens.size()), 1, "removed persisted display falls back to the current display")
	_expect_eq(DesktopFramePolicyScript.resolve_screen(2, -1, 0, screens.size()), 0, "invalid persisted and current displays fall back to the primary display")
	_expect_eq(DesktopFramePolicyScript.resolve_screen(2, 1, 0, 0), -1, "screen policy remains safe when no display is available")
	_expect_true(DesktopFramePolicyScript.window_has_accessible_region(Rect2i(1500, 800, 430, 280), screens), "desktop window with a usable interaction region remains in place")
	_expect_true(DesktopFramePolicyScript.window_has_accessible_region(Rect2i(2100, 400, 430, 280), screens), "desktop window remains visible on a secondary display")
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(1900, 1420, 430, 280), screens), "tiny cross-screen slivers trigger visibility recovery")
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(5000, 400, 430, 280), screens), "removed display position triggers visibility recovery")
	var single_screen: Array[Rect2i] = [Rect2i(0, 0, 1920, 1080)]
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(1800, 200, 430, 280), single_screen), "visible desktop pig sliver cannot hide the off-screen return and menu controls")
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(400, -210, 430, 280), single_screen), "visible desktop bottom area cannot hide the off-screen top controls")
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(400, -20, 430, 280), single_screen), "partially clipped desktop control buttons trigger recovery")
	_expect_true(DesktopFramePolicyScript.window_has_accessible_region(Rect2i(-220, 200, 430, 280), single_screen), "accessible desktop return and menu controls remain usable when the left window area is clipped")
	_expect_eq(DesktopFramePolicyScript.control_bar_rect(Vector2i(430, 280)), Rect2i(294, 8, 128, 52), "desktop recovery shares the production localized return/menu panel geometry")
	_expect_eq(DesktopFramePolicyScript.control_bar_rect(Vector2i(215, 140)), Rect2i(79, 8, 128, 52), "compact desktop recovery keeps the same reachable localized return/menu panel")
	_expect_true(not DesktopFramePolicyScript.window_has_accessible_region(Rect2i(0, 0, 0, 0), single_screen), "invalid desktop geometry does not report accessible controls")
	var usable := Rect2i(50, 30, 1920, 1040)
	_expect_eq(DesktopFramePolicyScript.docked_window_position(Vector2i(430, 280), usable, "bottom"), Vector2i(795, 782), "normal bottom docking preserves the centered eight-pixel margin")
	_expect_eq(DesktopFramePolicyScript.docked_window_position(Vector2i(430, 280), usable, "left"), Vector2i(58, 782), "normal left docking preserves the eight-pixel margin")
	_expect_eq(DesktopFramePolicyScript.docked_window_position(Vector2i(430, 280), usable, "right"), Vector2i(1532, 782), "normal right docking preserves the eight-pixel margin")
	var small_usable := Rect2i(-1600, -200, 320, 180)
	var small_screens: Array[Rect2i] = [small_usable]
	for dock: String in ["bottom", "left", "right"]:
		var recovered_position: Vector2i = DesktopFramePolicyScript.docked_window_position(Vector2i(645, 420), small_usable, dock)
		_expect_eq(recovered_position, Vector2i(-1925, -200), "oversized %s desktop docking places its controls inside a negative-coordinate work area" % dock)
		_expect_true(DesktopFramePolicyScript.window_has_accessible_region(Rect2i(recovered_position, Vector2i(645, 420)), small_screens), "oversized %s desktop window remains recoverable through its actual controls" % dock)
	_expect_true(GameSessionScript.main_window_has_accessible_title_region(Rect2i(200, 120, 1280, 720), screens), "main window keeps a fully accessible primary-display title region")
	_expect_true(GameSessionScript.main_window_has_accessible_title_region(Rect2i(2200, 160, 1280, 720), screens), "main window keeps an accessible secondary-display title region")
	_expect_true(not GameSessionScript.main_window_has_accessible_title_region(Rect2i(4479, 1439, 960, 540), screens), "one-pixel main-window overlap triggers visibility recovery")
	_expect_true(not GameSessionScript.main_window_has_accessible_title_region(Rect2i(4360, 200, 960, 540), screens), "a narrow main-window side strip cannot masquerade as an accessible title region")
	_expect_true(not GameSessionScript.main_window_has_accessible_title_region(Rect2i(200, -40, 960, 540), screens), "a mostly off-screen main-window title triggers visibility recovery")


func _test_photo_store_and_export() -> void:
	var default_base := "user://piggy_did_nothing_today"
	var save_base := "user://piggy_photo_tests"
	_remove_tree(ProjectSettings.globalize_path(default_base))
	_remove_tree(ProjectSettings.globalize_path(save_base))
	var session: Node = GameSessionScript.new()
	root.add_child(session)
	session.loaded_successfully = true
	session.save_service = SaveService.new(save_base)
	session.pig_state.discovered_events.append("event_move_in")
	var image := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color("#d9879b"))
	_expect_true(session.store_event_photo("event_move_in", image), "real PNG event photo is stored")
	var record: Dictionary = session.pig_state.life_photos.get("event_move_in", {}) as Dictionary
	_expect_eq(str(record.get("photo_id", "")), "photo_move_in", "event photo record uses the permanent photo ID")
	var stored_path: String = str(record.get("path", ""))
	_expect_true(FileAccess.file_exists(stored_path), "stored event photo path exists")
	var export_path: String = session.export_event_photo("event_move_in")
	_expect_true(not export_path.is_empty() and FileAccess.file_exists(export_path), "stored event photo exports to a real file")
	var exported := Image.load_from_file(export_path)
	_expect_true(exported != null and exported.get_size() == Vector2i(64, 48), "exported event photo preserves image dimensions")
	_expect_eq(session.event_photo_path("event_move_in"), stored_path, "session resolves a canonical existing album photo")
	var canonical_record: Dictionary = record.duplicate(true)
	session.pig_state.life_photos.event_move_in.path = session.save_service.save_path
	_expect_eq(session.event_photo_path("event_move_in"), "", "session rejects an existing noncanonical album path")
	_expect_eq(session.export_event_photo("event_move_in"), "", "album export cannot copy an arbitrary profile file")
	_expect_true(not session.record_event_photo("event_move_in", session.save_service.save_path), "photo metadata cannot record an arbitrary profile file")
	session.pig_state.life_photos.event_move_in = canonical_record
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored_path))
	_expect_eq(session.event_photo_path("event_move_in"), "", "session hides canonical photo metadata while its PNG is missing")
	image.save_png(stored_path)
	var transaction_event_id := "event_rainy_window"
	session.pig_state.discovered_events.append(transaction_event_id)
	session.pig_state.pending_events.append(transaction_event_id)
	var transaction_state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var transaction_director: EventDirector = session.get("event_director") as EventDirector
	var transaction_director_before: Dictionary = transaction_director.to_dict().duplicate(true)
	var normal_photo_base: String = session.save_service.base_dir
	var blocker_path: String = save_base + "/not_a_photo_directory"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("block event photo child paths")
	blocker.close()
	session.save_service.base_dir = blocker_path
	var failed_completion: Dictionary = session.complete_event_with_photo(transaction_event_id, image)
	_expect_true(failed_completion.is_empty(), "event completion reports an automatic-photo write failure")
	_expect_true(
		session.pig_state.to_dict() == transaction_state_before
			and transaction_director.to_dict() == transaction_director_before,
		"automatic-photo failure leaves rewards, queues, and event cooldown state untouched"
	)
	session.save_service.base_dir = normal_photo_base
	var retried_completion: Dictionary = session.complete_event_with_photo(transaction_event_id, image)
	_expect_true(
		not retried_completion.is_empty() and retried_completion.get("save_error", FAILED) == OK,
		"pending event completes after automatic-photo storage becomes writable"
	)
	_expect_true(
		transaction_event_id in session.pig_state.seen_events
			and not transaction_event_id in session.pig_state.pending_events,
		"successful retry consumes the pending event exactly once"
	)
	var retried_photo: Dictionary = session.pig_state.life_photos.get(transaction_event_id, {}) as Dictionary
	_expect_true(
		str(retried_photo.get("photo_id", "")) == "photo_rainy_window"
			and FileAccess.file_exists(str(retried_photo.get("path", ""))),
		"successful retry records the required automatic life-album photo"
	)
	var save_failure_event_id := "event_yoga_blanket"
	session.pig_state.discovered_events.append(save_failure_event_id)
	session.pig_state.pending_events.append(save_failure_event_id)
	var save_failure_state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var save_failure_director_before: Dictionary = transaction_director.to_dict().duplicate(true)
	var save_failure_event: Dictionary = session.catalog.get_item("events", save_failure_event_id)
	var save_failure_photo_path: String = "%s/photos/%s.png" % [
		session.save_service.base_dir,
		str(save_failure_event.get("photo_id", save_failure_event_id)),
	]
	var committed_photo_events: Array[String] = []
	session.event_photo_recorded.connect(func(event_id: String) -> void: committed_photo_events.append(event_id))
	var save_blocker_path: String = save_base + "/not_a_save_directory"
	var save_blocker := FileAccess.open(save_blocker_path, FileAccess.WRITE)
	save_blocker.store_string("block progression temp paths after the photo write")
	save_blocker.close()
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = save_blocker_path + "/savegame.tmp.json"
	var failed_save_completion: Dictionary = session.complete_event_with_photo(save_failure_event_id, image)
	_expect_true(
		not failed_save_completion.is_empty() and failed_save_completion.get("save_error", OK) != OK,
		"event completion reports a progression-save failure after writing its automatic photo"
	)
	_expect_true(
		session.pig_state.to_dict() == save_failure_state_before
			and transaction_director.to_dict() == save_failure_director_before,
		"progression-save failure rolls back rewards, queues, photo metadata, and event cooldown state"
	)
	_expect_true(
		not FileAccess.file_exists(save_failure_photo_path),
		"progression-save failure removes an uncommitted automatic photo"
	)
	_expect_eq(committed_photo_events, [], "progression-save failure does not announce an uncommitted album photo")
	session.save_service.temp_path = normal_temp_path
	var retried_save_completion: Dictionary = session.complete_event_with_photo(save_failure_event_id, image)
	_expect_true(
		not retried_save_completion.is_empty()
			and retried_save_completion.get("save_error", FAILED) == OK
			and save_failure_event_id in session.pig_state.seen_events
			and not save_failure_event_id in session.pig_state.pending_events,
		"event remains retryable and commits once progression storage recovers"
	)
	_expect_eq(committed_photo_events, [save_failure_event_id], "successful retry announces the committed album photo exactly once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_blocker_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	var audio: Node = root.get_node_or_null("AudioService")
	if audio != null:
		audio.call("stop_all")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(default_base))
	_remove_tree(ProjectSettings.globalize_path(save_base))


func _test_content_reachability() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "reachability catalog loads")
	var reachable: Array[String] = []
	var changed: bool = true
	while changed:
		changed = false
		for event: Dictionary in catalog.events:
			var id: String = str(event.id)
			if id in reachable:
				continue
			if EventDirector._contains_all(reachable, event.get("prerequisite_events", []) as Array):
				reachable.append(id)
				changed = true
	_expect_eq(reachable.size(), catalog.events.size(), "every core event has a prerequisite path")
	var rewarded_expressions: Array[String] = []
	for event: Dictionary in catalog.events:
		for expression_id: Variant in event.get("rewards", {}).get("expressions", []):
			rewarded_expressions.append(str(expression_id))
	_expect_eq(rewarded_expressions.size(), catalog.expressions.size(), "all expressions have an event reward path")
	for expression: Dictionary in catalog.expressions:
		_expect_true(str(expression.id) in rewarded_expressions, "expression is reachable: %s" % expression.id)


func _test_save_semantic_invariants() -> void:
	var service := SaveService.new("user://piggy_save_semantic_unit_tests")
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "semantic save fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var state := PigState.new()
	state.discovered_events = ["event_move_in"]
	state.pending_events = ["event_move_in"]
	state.life_photos = {
		"event_move_in": {
			"photo_id": "photo_move_in",
			"path": "user://piggy_did_nothing_today/photos/photo_move_in.png",
			"captured_unix": 1,
		},
	}
	var payload := {
		"schema_version": SaveService.CURRENT_SCHEMA,
		"last_saved_unix": 1,
		"pig_state": state.to_dict(),
		"behavior_director": {},
		"event_director": {},
		"simulation": {},
	}
	_expect_true(bool(service.call("_is_valid_game_payload", payload)), "unnamed first-launch progression satisfies semantic save invariants")
	var unnamed_advanced: Dictionary = payload.duplicate(true)
	unnamed_advanced.pig_state.tutorial_step = 1
	_expect_true(not bool(service.call("_is_valid_game_payload", unnamed_advanced)), "an active naming tutorial cannot advance while the persisted name is empty")
	var unnamed_skipped: Dictionary = payload.duplicate(true)
	unnamed_skipped.pig_state.tutorial_skipped = true
	_expect_true(bool(service.call("_is_valid_game_payload", unnamed_skipped)), "an explicitly skipped naming tutorial preserves a valid empty identity")
	var bad_range: Dictionary = payload.duplicate(true)
	bad_range.pig_state.satiety = 120.0
	_expect_true(not bool(service.call("_is_valid_game_payload", bad_range)), "out-of-range pig state is semantically invalid")
	var duplicate_ids: Dictionary = payload.duplicate(true)
	duplicate_ids.pig_state.owned_furniture = ["furn_bed_basic", "furn_bed_basic"]
	_expect_true(not bool(service.call("_is_valid_game_payload", duplicate_ids)), "duplicate permanent IDs are semantically invalid")
	var fractional_counter: Dictionary = payload.duplicate(true)
	fractional_counter.pig_state.daily_points = 70.5
	_expect_true(not bool(service.call("_is_valid_game_payload", fractional_counter)), "fractional progression counters are semantically invalid")
	var unknown_favorite: Dictionary = payload.duplicate(true)
	unknown_favorite.pig_state.favorite_desktop_expression = "expr_not_unlocked"
	_expect_true(not bool(service.call("_is_valid_game_payload", unknown_favorite)), "desktop favorite must reference an unlocked expression")
	var unknown_permanent_id: Dictionary = payload.duplicate(true)
	unknown_permanent_id.pig_state.owned_furniture.append("furn_removed_or_corrupt")
	_expect_true(not bool(service.call("_is_valid_game_payload", unknown_permanent_id)), "owned collections reject unknown permanent content IDs")
	var unknown_history_id: Dictionary = payload.duplicate(true)
	unknown_history_id.event_director.last_triggered_unix = {"event_removed_or_corrupt":20}
	_expect_true(not bool(service.call("_is_valid_game_payload", unknown_history_id)), "event history rejects unknown permanent content IDs")
	var unknown_slot: Dictionary = payload.duplicate(true)
	unknown_slot.pig_state.owned_furniture.append("furn_pillow_cloud")
	unknown_slot.pig_state.placed_furniture = {"sleep_removed":"furn_pillow_cloud"}
	_expect_true(not bool(service.call("_is_valid_game_payload", unknown_slot)), "furniture placement rejects unknown permanent slot IDs")
	for placement: Dictionary in [
		{"snack_1":"furn_bed_basic"},
		{"sleep_3":"furn_bed_basic"},
		{"sleep_4":"furn_bed_basic"},
		{"sleep_1":"furn_pillow_cloud"},
	]:
		var incompatible_slot: Dictionary = payload.duplicate(true)
		incompatible_slot.pig_state.owned_furniture.append("furn_pillow_cloud")
		incompatible_slot.pig_state.placed_furniture = placement
		_expect_true(not bool(service.call("_is_valid_game_payload", incompatible_slot)), "saved furniture rejects incompatible area or slot class: %s" % placement)
	var all_furniture: Array[String] = []
	for furniture: Dictionary in catalog.furniture:
		all_furniture.append(str(furniture.id))
	for furniture: Dictionary in catalog.furniture:
		var compatible_slot: String = ""
		for slot_id: String in GameSessionScript.ROOM_SLOTS:
			if slot_id.begins_with(str(furniture.area) + "_") and str(GameSessionScript.ROOM_SLOTS[slot_id]) == str(furniture.slot):
				compatible_slot = slot_id
				break
		var valid_slot: Dictionary = payload.duplicate(true)
		valid_slot.pig_state.familiarity_level = 10
		valid_slot.pig_state.owned_furniture = all_furniture.duplicate()
		valid_slot.pig_state.placed_furniture = {compatible_slot:str(furniture.id)}
		_expect_true(not compatible_slot.is_empty() and bool(service.call("_is_valid_game_payload", valid_slot)), "saved furniture preserves a legal catalogue placement: %s" % furniture.id)
	var wrong_photo_id: Dictionary = payload.duplicate(true)
	wrong_photo_id.pig_state.life_photos.event_move_in.photo_id = "photo_wrong_for_event"
	_expect_true(not bool(service.call("_is_valid_game_payload", wrong_photo_id)), "album records retain the permanent photo ID declared by their event")
	var invalid_ending: Dictionary = payload.duplicate(true)
	invalid_ending.pig_state.ending_seen = true
	invalid_ending.pig_state.ending_unlocked = false
	_expect_true(not bool(service.call("_is_valid_game_payload", invalid_ending)), "seen ending cannot exist without the ending unlock")
	var malformed_demo_completion: Dictionary = payload.duplicate(true)
	malformed_demo_completion.pig_state.demo_completion_seen = "yes"
	_expect_true(not bool(service.call("_is_valid_game_payload", malformed_demo_completion)), "Demo completion acknowledgement requires a strict boolean")
	var duplicate_placement: Dictionary = payload.duplicate(true)
	duplicate_placement.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic", "sleep_2":"furn_bed_basic"}
	_expect_true(not bool(service.call("_is_valid_game_payload", duplicate_placement)), "one furniture ID cannot occupy multiple saved slots")
	var unowned_placement: Dictionary = payload.duplicate(true)
	unowned_placement.pig_state.placed_furniture = {"sleep_1":"furn_not_owned"}
	_expect_true(not bool(service.call("_is_valid_game_payload", unowned_placement)), "placed furniture must belong to the saved owned collection")
	var malformed_photo: Dictionary = payload.duplicate(true)
	malformed_photo.pig_state.life_photos.event_move_in.path = 42
	_expect_true(not bool(service.call("_is_valid_game_payload", malformed_photo)), "album photo metadata requires a string path")
	var orphan_photo: Dictionary = payload.duplicate(true)
	orphan_photo.pig_state.life_photos = {
		"event_not_discovered": {
			"photo_id": "photo_orphan",
			"path": "user://orphan.png",
			"captured_unix": 1,
		},
	}
	_expect_true(not bool(service.call("_is_valid_game_payload", orphan_photo)), "album photos must reference discovered memories")
	var invalid_behavior_state: Dictionary = payload.duplicate(true)
	invalid_behavior_state.behavior_director = {
		"recent_ids": ["a", "b", "c", "d", "e", "f"],
		"cooldown_until": {"a": 20},
	}
	_expect_true(not bool(service.call("_is_valid_game_payload", invalid_behavior_state)), "behavior director rejects an oversized recent-history queue")
	var invalid_event_state: Dictionary = payload.duplicate(true)
	invalid_event_state.event_director = {
		"last_triggered_unix": {"event_move_in": -1},
		"recent_event_ids": ["event_move_in"],
	}
	_expect_true(not bool(service.call("_is_valid_game_payload", invalid_event_state)), "event director rejects negative trigger timestamps")
	var invalid_simulation_state: Dictionary = payload.duplicate(true)
	invalid_simulation_state.simulation = {"current_behavior_id":"behavior_idle", "remaining_seconds":-0.5}
	_expect_true(not bool(service.call("_is_valid_game_payload", invalid_simulation_state)), "simulation rejects negative remaining behavior time")
	var recovered_simulation := Simulation.new()
	recovered_simulation.load_dict({"current_behavior_id":"behavior_removed_in_this_profile", "remaining_seconds":15.0}, catalog)
	_expect_eq(recovered_simulation.to_dict(), {"current_behavior_id":"", "remaining_seconds":0.0}, "unknown saved behavior clears its stale transaction time")


func _test_unnamed_save_type_recovery() -> void:
	var base := "user://unnamed_save_type_recovery_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "unnamed type fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var pig := PigState.new()
	pig.name = "Backup Pig"
	pig.daily_points = 432
	var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"full", "last_saved_unix":3000, "pig_state":pig.to_dict()}
	for generation: int in [1, 2, 3]:
		var data: Dictionary = payload.duplicate(true)
		data.pig_state.daily_points = 430 + generation
		_expect_eq(service.save_game(data), OK, "unnamed type fixture commits generation %d" % generation)
	var backup_1_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
	var backup_2_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
	var invalid_fields: Dictionary = {
		"tutorial_step":[null, [], {}, "1", true, 0.5, -1],
		"tutorial_skipped":[null, [], {}, "false", 0, 1, 0.5],
	}
	for version: int in [0, SaveService.CURRENT_SCHEMA]:
		for saved_name: String in ["", " \t "]:
			for field: String in invalid_fields:
				for value: Variant in invalid_fields[field]:
					var label: String = "schema %d name %s %s %s" % [version, var_to_str(saved_name), field, var_to_str(value)]
					var invalid: Dictionary = payload.duplicate(true)
					invalid.schema_version = version
					invalid.pig_state.name = saved_name
					invalid.pig_state.daily_points = 17
					invalid.pig_state.tutorial_step = 1
					invalid.pig_state[field] = value
					var unchanged: Dictionary = invalid.duplicate(true)
					var migrated: Dictionary = service.migrate(invalid)
					_expect_true(not bool(service.call("_is_valid_game_payload", migrated)), "%s is rejected before name consistency can convert malformed fields" % label)
					_expect_eq(invalid, unchanged, "%s validation leaves the input object unchanged" % label)
					var file := FileAccess.open(service.save_path, FileAccess.WRITE)
					file.store_string(JSON.stringify(invalid))
					file.close()
					var loaded: Dictionary = service.load_game()
					var data: Dictionary = loaded.get("data", {}) as Dictionary
					var restored: Dictionary = data.get("pig_state", {}) as Dictionary
					_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)) and loaded.get("source", "") == service.backup_1_path and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA, "%s restores the newest legitimate backup without a script exception" % label)
					_expect_true(restored.get("name", "") == "Backup Pig" and int(restored.get("daily_points", 0)) == 432 and restored.get("tutorial_step", -1) == 0 and restored.get("tutorial_skipped", true) == false, "%s retains exact legitimate identity, balance and onboarding state" % label)
					var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
					_expect_eq(service.save_game(invalid), ERR_FILE_CORRUPT, "%s invalid save is explicitly rejected" % label)
					_expect_true(FileAccess.get_file_as_bytes(service.save_path) == main_bytes and FileAccess.get_file_as_bytes(service.backup_1_path) == backup_1_bytes and FileAccess.get_file_as_bytes(service.backup_2_path) == backup_2_bytes and not FileAccess.file_exists(service.temp_path), "%s failed save preserves all three generations and leaves no temporary file" % label)
	for version: int in [0, 1, 2, 3, SaveService.CURRENT_SCHEMA]:
		for saved_name: String in ["", " \t ", "Named Pig"]:
			for step: int in [0, 1, 7]:
				for skipped: bool in [false, true]:
					var valid: Dictionary = payload.duplicate(true)
					valid.schema_version = version
					valid.pig_state.name = saved_name
					valid.pig_state.tutorial_step = step
					valid.pig_state.tutorial_skipped = skipped
					var expected_valid: bool = not saved_name.strip_edges().is_empty() or step == 0 or skipped
					_expect_eq(bool(service.call("_is_valid_game_payload", service.migrate(valid))), expected_valid, "schema %d legitimate name/onboarding %s/%d/%s keeps its existing validity" % [version, var_to_str(saved_name), step, str(skipped)])
		var omitted: Dictionary = payload.duplicate(true)
		omitted.schema_version = version
		omitted.pig_state.name = ""
		omitted.pig_state.erase("tutorial_step")
		omitted.pig_state.erase("tutorial_skipped")
		_expect_true(bool(service.call("_is_valid_game_payload", service.migrate(omitted))), "schema %d missing onboarding fields retain unnamed first-run compatibility" % version)
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_integer_save_boundary() -> void:
	var base := "user://integer_save_boundary_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "integer save fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var pig := PigState.new()
	pig.name = "Backup Pig"
	pig.daily_points = 432
	pig.unlocked_expressions = ["expr_happy_soft"]
	pig.expression_unlock_dates = {"expr_happy_soft":2}
	pig.discovered_events = ["event_move_in"]
	pig.life_photos = {"event_move_in":{"photo_id":"photo_move_in", "path":"user://piggy_did_nothing_today/photos/photo_move_in.png", "captured_unix":2}}
	pig.interaction_counts = {"pet:2026-10-05":2}
	var behavior_id: String = str(catalog.behaviors[0].id)
	var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"full", "last_saved_unix":3000, "pig_state":pig.to_dict(), "behavior_director":{"cooldown_until":{behavior_id:2}}, "event_director":{"last_triggered_unix":{"event_move_in":2}}}
	for generation: int in [1, 2, 3]:
		var data: Dictionary = payload.duplicate(true)
		data.pig_state.daily_points = 430 + generation
		_expect_eq(service.save_game(data), OK, "integer save fixture commits generation %d" % generation)
	var backup_1_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
	var backup_2_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
	var fields: Array[String] = ["pig_state.daily_points", "pig_state.familiarity_xp", "pig_state.familiarity_level", "pig_state.tutorial_step", "last_saved_unix", "pig_state.expression_unlock_dates.expr_happy_soft", "pig_state.interaction_counts.pet:2026-10-05", "behavior_director.cooldown_until." + behavior_id, "event_director.last_triggered_unix.event_move_in", "pig_state.life_photos.event_move_in.captured_unix"]
	for version: int in [0, SaveService.CURRENT_SCHEMA]:
		for field: String in fields:
			for value: float in [1.9999999, 2.0000001, 2.5, 1e20]:
				var label: String = "schema %d %s=%s" % [version, field, var_to_str(value)]
				var invalid: Dictionary = payload.duplicate(true)
				invalid.schema_version = version
				invalid.pig_state.daily_points = 17
				_set_save_number_field(invalid, field, value)
				var unchanged: Dictionary = invalid.duplicate(true)
				_expect_true(not bool(service.call("_is_valid_game_payload", service.migrate(invalid))), "%s cannot pass as an approximately integral save field" % label)
				_expect_eq(invalid, unchanged, "%s validation preserves the original object" % label)
				var file := FileAccess.open(service.save_path, FileAccess.WRITE)
				file.store_string(JSON.stringify(invalid))
				file.close()
				var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.save_path)) as Dictionary
				_expect_eq(float(_save_number_field(parsed, field)), value, "%s real JSON retains the exact malformed numeric value" % label)
				var loaded: Dictionary = service.load_game()
				var data: Dictionary = loaded.get("data", {}) as Dictionary
				var restored: Dictionary = data.get("pig_state", {}) as Dictionary
				_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)) and loaded.get("source", "") == service.backup_1_path and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA, "%s recovers the latest legitimate backup" % label)
				_expect_true(restored.get("name", "") == "Backup Pig" and int(restored.get("daily_points", 0)) == 432, "%s retains legitimate balance instead of approximate main progress" % label)
				var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
				_expect_eq(service.save_game(invalid), ERR_FILE_CORRUPT, "%s cannot be committed or rounded into a valid save" % label)
				_expect_true(FileAccess.get_file_as_bytes(service.save_path) == main_bytes and FileAccess.get_file_as_bytes(service.backup_1_path) == backup_1_bytes and FileAccess.get_file_as_bytes(service.backup_2_path) == backup_2_bytes and not FileAccess.file_exists(service.temp_path), "%s failed save preserves all generations and removes its temporary file" % label)
	for version: int in [0, 1, 2, 3, SaveService.CURRENT_SCHEMA]:
		for field: String in fields:
			for value: Variant in [2, 2.0]:
				var valid: Dictionary = payload.duplicate(true)
				valid.schema_version = version
				_set_save_number_field(valid, field, value)
				_expect_true(bool(service.call("_is_valid_game_payload", service.migrate(valid))), "schema %d %s legitimate integral %s remains compatible" % [version, field, var_to_str(value)])
	var helper_cases: Array[Dictionary] = [
		{"value":0, "valid":true}, {"value":2, "valid":true}, {"value":2.0, "valid":true}, {"value":8e18, "valid":true}, {"value":-2, "valid":true}, {"value":-2.0, "valid":true},
		{"value":2.0000001, "valid":false}, {"value":1.9999999, "valid":false}, {"value":2.5, "valid":false}, {"value":1e20, "valid":false}, {"value":9223372036854775808.0, "valid":false}, {"value":NAN, "valid":false}, {"value":INF, "valid":false}, {"value":-INF, "valid":false}, {"value":true, "valid":false}, {"value":"2", "valid":false}, {"value":null, "valid":false}, {"value":[], "valid":false}, {"value":{}, "valid":false},
	]
	for test_case: Dictionary in helper_cases:
		_expect_eq(bool(service.call("_is_integer_number", test_case.value)), test_case.valid, "integer helper classifies %s without approximation or overflow" % var_to_str(test_case.value))
	var continuous: Dictionary = payload.duplicate(true)
	continuous.pig_state.satiety = 72.25
	continuous.pig_state.energy = 68.75
	continuous.pig_state.interest = 64.125
	continuous.pig_state.active_seconds = 12.5
	_expect_true(bool(service.call("_is_valid_game_payload", continuous)), "continuous simulation state remains legitimately fractional")
	_expect_eq(service.save_game(continuous), OK, "continuous fractional state still saves normally")
	var continuous_loaded: Dictionary = service.load_game()
	var continuous_state: Dictionary = (continuous_loaded.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary
	_expect_true(float(continuous_state.get("satiety", 0)) == 72.25 and float(continuous_state.get("energy", 0)) == 68.75 and float(continuous_state.get("interest", 0)) == 64.125 and float(continuous_state.get("active_seconds", 0)) == 12.5, "integer strictness does not round continuous simulation fields")
	_remove_tree(ProjectSettings.globalize_path(base))


func _set_save_number_field(data: Dictionary, field: String, value: Variant) -> void:
	var parts: PackedStringArray = field.split(".")
	var parent: Dictionary = data
	for index: int in parts.size() - 1:
		parent = parent[parts[index]] as Dictionary
	parent[parts[parts.size() - 1]] = value


func _save_number_field(data: Dictionary, field: String) -> Variant:
	var result: Variant = data
	for part: String in field.split("."):
		result = (result as Dictionary)[part]
	return result


func _test_legacy_boolean_migration() -> void:
	var base := "user://legacy_boolean_migration_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "legacy boolean fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var pig := PigState.new()
	pig.name = "Backup Pig"
	pig.daily_points = 432
	pig.tutorial_skipped = true
	var payload := {"release_profile":"full", "last_saved_unix":3000, "pig_state":pig.to_dict()}
	for generation: int in [1, 2, 3]:
		var data: Dictionary = payload.duplicate(true)
		data.pig_state.daily_points = 430 + generation
		_expect_eq(service.save_game(data), OK, "legacy boolean fixture commits generation %d" % generation)
	var backup_1_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
	var backup_2_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
	var fields: Dictionary = {"ending_unlocked":1, "ending_seen":1, "demo_completion_seen":3}
	var invalid_values: Array[Variant] = [0, 1, 0.5, "false", null, [], {}]
	for field: String in fields:
		for value: Variant in invalid_values:
			var label: String = "%s %s" % [field, var_to_str(value)]
			var invalid: Dictionary = payload.duplicate(true)
			invalid["schema_version"] = int(fields[field])
			invalid.pig_state.name = "Damaged Pig"
			invalid.pig_state.daily_points = 17
			if field == "ending_seen":
				invalid.pig_state.ending_unlocked = true
			invalid.pig_state[field] = value
			var unchanged: Dictionary = invalid.duplicate(true)
			var current_control: Dictionary = invalid.duplicate(true)
			current_control.schema_version = SaveService.CURRENT_SCHEMA
			_expect_true(not bool(service.call("_is_valid_game_payload", current_control)), "%s is already rejected by current-schema semantic validation" % label)
			var migrated: Dictionary = service.migrate(invalid)
			_expect_true(not bool(service.call("_is_valid_game_payload", migrated)), "%s cannot be normalized into a valid legacy milestone" % label)
			_expect_eq(invalid, unchanged, "%s migration keeps the original input object untouched" % label)
			var file := FileAccess.open(service.save_path, FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			var loaded: Dictionary = service.load_game()
			var data: Dictionary = loaded.get("data", {}) as Dictionary
			var restored: Dictionary = data.get("pig_state", {}) as Dictionary
			_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA, "%s malformed legacy field falls back without a script exception" % label)
			_expect_eq(str(loaded.get("source", "")), service.backup_1_path, "%s selects the newest valid backup instead of malformed legacy data" % label)
			_expect_true(restored.get("name", "") == "Backup Pig" and int(restored.get("daily_points", 0)) == 432 and restored.get("ending_unlocked", true) == false and restored.get("ending_seen", true) == false and restored.get("demo_completion_seen", true) == false, "%s restores exact identity, balance and unacknowledged milestones" % label)
			_expect_true(FileAccess.get_file_as_bytes(service.backup_1_path) == backup_1_bytes and FileAccess.get_file_as_bytes(service.backup_2_path) == backup_2_bytes and not FileAccess.file_exists(service.temp_path), "%s recovery preserves both backup generations and leaves no temporary save" % label)
	for version: int in [0, 1, 2, 3]:
		for flag: bool in [false, true]:
			var legacy: Dictionary = payload.duplicate(true)
			legacy["schema_version"] = version
			for field: String in fields:
				legacy.pig_state[field] = flag
			var unchanged: Dictionary = legacy.duplicate(true)
			var migrated: Dictionary = service.migrate(legacy)
			_expect_true(bool(service.call("_is_valid_game_payload", migrated)) and int(migrated.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA, "schema %d legitimate boolean %s remains migratable" % [version, str(flag)])
			_expect_eq(migrated.get("pig_state", {}), legacy.pig_state, "schema %d preserves legitimate boolean %s progression exactly" % [version, str(flag)])
			_expect_eq(legacy, unchanged, "schema %d legitimate boolean %s migration does not mutate the input" % [version, str(flag)])
		var missing: Dictionary = payload.duplicate(true)
		missing["schema_version"] = version
		for field: String in fields:
			missing.pig_state.erase(field)
		var migrated_missing: Dictionary = service.migrate(missing)
		_expect_true(bool(service.call("_is_valid_game_payload", migrated_missing)), "schema %d omitted legacy milestone fields remain supported" % version)
		var restored_missing := PigState.new()
		restored_missing.load_dict(migrated_missing.get("pig_state", {}) as Dictionary)
		_expect_true(not restored_missing.ending_unlocked and not restored_missing.ending_seen and not restored_missing.demo_completion_seen, "schema %d omitted legacy milestone fields retain safe false defaults" % version)
	var alias := {"schema_version":0, "pig":pig.to_dict(), "last_saved_unix":3000}
	var alias_before: Dictionary = alias.duplicate(true)
	var alias_migrated: Dictionary = service.migrate(alias)
	_expect_true(bool(service.call("_is_valid_game_payload", alias_migrated)), "version-zero pig alias remains migratable after boolean type preservation")
	_expect_eq(alias_migrated.get("pig_state", {}), pig.to_dict(), "version-zero pig alias retains exact legitimate milestone flags and progression")
	_expect_eq(alias, alias_before, "version-zero pig alias migration leaves the original object untouched")
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_schema_version_migration_boundary() -> void:
	var base := "user://schema_version_migration_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "schema boundary fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var pig := PigState.new()
	pig.name = "Stable Pig"
	pig.daily_points = 432
	pig.tutorial_skipped = true
	var payload := {"release_profile":"full", "last_saved_unix":3000, "pig_state":pig.to_dict()}
	var invalid_versions: Dictionary = {
		"fractional":3.5, "near_integer_lower":2.9999999, "near_integer_upper":3.0000001,
		"negative_fraction":-0.2, "negative":-1, "future":5,
		"numeric_string":"3", "true":true, "false":false, "null":null,
		"array":[], "object":{},
	}
	for label: String in invalid_versions:
		var invalid: Dictionary = payload.duplicate(true)
		invalid["schema_version"] = invalid_versions[label]
		var unchanged: Dictionary = invalid.duplicate(true)
		_expect_true(service.migrate(invalid).is_empty(), "%s source schema is rejected before conversion or migration" % label)
		_expect_eq(invalid, unchanged, "%s rejected migration leaves the source object untouched" % label)
	var valid_versions: Array[Variant] = [0, 1, 2, 3, 4, 0.0, 1.0, 2.0, 3.0, 4.0]
	for version: Variant in valid_versions:
		var legacy: Dictionary = payload.duplicate(true)
		legacy["schema_version"] = version
		var unchanged: Dictionary = legacy.duplicate(true)
		var migrated: Dictionary = service.migrate(legacy)
		_expect_true(int(migrated.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and (migrated.get("pig_state", {}) as Dictionary) == pig.to_dict(), "valid numeric schema %s migrates without changing progression" % str(version))
		_expect_eq(legacy, unchanged, "valid numeric schema %s preserves the original source object" % str(version))
	var unversioned: Dictionary = service.migrate(payload)
	_expect_true(int(unversioned.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and (unversioned.get("pig_state", {}) as Dictionary) == pig.to_dict(), "missing legacy schema still uses the supported version-zero migration")
	_expect_true(not payload.has("schema_version"), "unversioned migration does not inject a schema into its source")
	for generation: int in [1, 2, 3]:
		var data: Dictionary = payload.duplicate(true)
		data.pig_state.daily_points = 430 + generation
		_expect_eq(service.save_game(data), OK, "schema recovery fixture commits generation %d" % generation)
	var backup_1_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
	var backup_2_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
	for label: String in invalid_versions:
		var invalid: Dictionary = payload.duplicate(true)
		invalid["schema_version"] = invalid_versions[label]
		invalid.pig_state.name = "Damaged Pig"
		invalid.pig_state.daily_points = 17
		for backup_index: int in [1, 2]:
			for path: String in [service.save_path, service.backup_1_path]:
				var file := FileAccess.open(path, FileAccess.WRITE)
				if path == service.backup_1_path and backup_index == 1:
					file.store_buffer(backup_1_bytes)
				else:
					file.store_string(JSON.stringify(invalid))
				file.close()
			var original_backup_1: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
			var loaded: Dictionary = service.load_game()
			var data: Dictionary = loaded.get("data", {}) as Dictionary
			var state: Dictionary = data.get("pig_state", {}) as Dictionary
			var expected_source: String = service.backup_1_path if backup_index == 1 else service.backup_2_path
			_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA, "%s malformed schema falls back to valid backup%d without a script exception" % [label, backup_index])
			_expect_eq(str(loaded.get("source", "")), expected_source, "%s selects the newest valid schema generation at backup%d" % [label, backup_index])
			_expect_true(state.get("name", "") == "Stable Pig" and int(state.get("daily_points", 0)) == 433 - backup_index, "%s backup%d restores exact identity and balance instead of damaged 17-point data" % [label, backup_index])
			_expect_true(FileAccess.get_file_as_bytes(service.backup_1_path) == original_backup_1 and FileAccess.get_file_as_bytes(service.backup_2_path) == backup_2_bytes and not FileAccess.file_exists(service.temp_path), "%s backup%d recovery preserves both original backup bytes and leaves no temporary save" % [label, backup_index])
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_save_placement_recovery() -> void:
	var base := "user://piggy_save_placement_tests"
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "placement recovery fixture loads current furniture metadata")
	for placement: Dictionary in [
		{"snack_1":"furn_bed_basic"},
		{"sleep_3":"furn_bed_basic"},
		{"sleep_4":"furn_bed_basic"},
	]:
		_remove_tree(ProjectSettings.globalize_path(base))
		var service := SaveService.new(base)
		service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
		var state := PigState.new()
		state.name = "Placement Pig"
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "last_saved_unix":1, "pig_state":state.to_dict()}
		var seeded: bool = true
		for generation: int in range(1, 4):
			payload.last_saved_unix = generation
			payload.pig_state.daily_points = generation * 10
			seeded = service.save_game(payload) == OK and seeded
		_expect_true(seeded, "placement recovery seeds three valid save generations")
		var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
		var before: Array[PackedByteArray] = []
		for path: String in paths:
			before.append(FileAccess.get_file_as_bytes(path))
		var invalid: Dictionary = payload.duplicate(true)
		invalid.pig_state.placed_furniture = placement
		_expect_true(service.save_game(invalid) != OK, "an incompatible placement cannot be atomically committed: %s" % placement)
		var after: Array[PackedByteArray] = []
		for path: String in paths:
			after.append(FileAccess.get_file_as_bytes(path))
		_expect_eq(after, before, "rejected placement writes preserve all three original save generations")
		for index: int in paths.size():
			var restored := FileAccess.open(paths[index], FileAccess.WRITE)
			restored.store_buffer(before[index])
			restored.close()
		var corrupted := FileAccess.open(service.save_path, FileAccess.WRITE)
		corrupted.store_string(JSON.stringify(invalid))
		corrupted.close()
		var loaded: Dictionary = service.load_game()
		_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)) and str(loaded.get("source", "")) == service.backup_1_path, "incompatible placement in valid JSON recovers the newest valid backup")
		var recovered_state: Dictionary = (loaded.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary
		_expect_true(int(recovered_state.get("daily_points", -1)) == 20 and recovered_state.get("placed_furniture", {}) == {"sleep_1":"furn_bed_basic"}, "placement recovery restores the backup's exact progression and legal room")
		_expect_true(FileAccess.get_file_as_bytes(service.backup_1_path) == before[1] and FileAccess.get_file_as_bytes(service.backup_2_path) == before[2], "placement recovery leaves both valid backups byte-identical")
		_expect_true(not FileAccess.file_exists(service.temp_path), "placement rejection and recovery leave no temporary save")
		_remove_tree(ProjectSettings.globalize_path(base))


func _test_save_rotation_and_recovery() -> void:
	var base := "user://piggy_did_nothing_today_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "save recovery fixture loads permanent content IDs")
	service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
	var first_payload := {"last_saved_unix":1,"pig_state":{"name":"one"}}
	_expect_eq(service.save_game(first_payload), OK, "first atomic save")
	_expect_eq(service.save_game(first_payload), OK, "an identical verified save is accepted idempotently")
	_expect_true(not FileAccess.file_exists(service.backup_1_path), "an identical save does not rotate a duplicate into backup1")
	_expect_true(not FileAccess.file_exists(service.temp_path), "an identical save consumes its verified temporary file")
	_expect_eq(service.save_game({"last_saved_unix":2,"pig_state":{"name":"two"}}), OK, "second atomic save")
	_expect_eq(service.save_game({"last_saved_unix":3,"pig_state":{"name":"three"}}), OK, "third atomic save")
	_expect_true(FileAccess.file_exists(service.backup_1_path), "first rotating backup exists")
	_expect_true(FileAccess.file_exists(service.backup_2_path), "second rotating backup exists")
	var broken := FileAccess.open(service.save_path, FileAccess.WRITE)
	broken.store_string("{not-json")
	broken.close()
	var loaded: Dictionary = service.load_game()
	_expect_true(loaded.ok, "backup recovery succeeds")
	_expect_true(loaded.recovered, "backup recovery is reported")
	_expect_eq(loaded.data.pig_state.name, "two", "newest valid backup is restored")
	var structurally_broken := FileAccess.open(service.save_path, FileAccess.WRITE)
	structurally_broken.store_string('{"schema_version":2,"pig_state":[]}')
	structurally_broken.close()
	var semantic_recovery: Dictionary = service.load_game()
	_expect_true(semantic_recovery.ok and semantic_recovery.recovered, "valid JSON with a damaged game structure falls back to a backup")
	_expect_eq(semantic_recovery.data.pig_state.name, "two", "semantic save recovery retains the newest valid progression")
	var invalid_state := PigState.new()
	invalid_state.name = "semantic-broken"
	invalid_state.discovered_events = ["event_0", "event_1", "event_2", "event_3", "event_4", "event_5"]
	invalid_state.pending_events = invalid_state.discovered_events.duplicate()
	invalid_state.summarized_events = ["event_0"]
	var semantic_broken := FileAccess.open(service.save_path, FileAccess.WRITE)
	semantic_broken.store_string(JSON.stringify({
		"schema_version": SaveService.CURRENT_SCHEMA,
		"last_saved_unix": 4,
		"pig_state": invalid_state.to_dict(),
		"behavior_director": {},
		"event_director": {},
		"simulation": {},
	}))
	semantic_broken.close()
	var invariant_recovery: Dictionary = service.load_game()
	_expect_true(invariant_recovery.ok and invariant_recovery.recovered, "structurally valid save with broken queue invariants falls back to a backup")
	_expect_eq(invariant_recovery.data.pig_state.name, "two", "queue invariant recovery retains the newest valid progression")
	var component_broken := FileAccess.open(service.save_path, FileAccess.WRITE)
	component_broken.store_string(JSON.stringify({
		"schema_version": SaveService.CURRENT_SCHEMA,
		"last_saved_unix": 4,
		"pig_state": PigState.new().to_dict(),
		"behavior_director": {"recent_ids":[], "cooldown_until":{}},
		"event_director": {"last_triggered_unix":{}, "recent_event_ids":[]},
		"simulation": {"current_behavior_id":"behavior_idle", "remaining_seconds":-1},
	}))
	component_broken.close()
	var component_recovery: Dictionary = service.load_game()
	_expect_true(component_recovery.ok and component_recovery.recovered, "semantically damaged simulation state falls back to a backup")
	_expect_eq(component_recovery.data.pig_state.name, "two", "component-state recovery retains the newest valid progression")
	for path: String in [service.save_path, service.backup_1_path, service.backup_2_path]:
		var invalid := FileAccess.open(path, FileAccess.WRITE)
		invalid.store_string('{"schema_version":2,"pig_state":[]}')
		invalid.close()
	var exhausted: Dictionary = service.load_game()
	_expect_true(not exhausted.ok and exhausted.had_files, "exhausted recovery distinguishes damaged files from first launch")
	var migrated: Dictionary = service.migrate({"schema_version":0,"pig":{"name":"legacy"}})
	_expect_eq(migrated.schema_version, SaveService.CURRENT_SCHEMA, "legacy save migrates to current schema")
	_expect_eq(migrated.pig_state.name, "legacy", "legacy pig data is retained")
	_expect_true(migrated.pig_state.has("life_photos"), "legacy migration adds life photo metadata")
	var version_one: Dictionary = service.migrate({"schema_version":1,"pig_state":{"name":"v1"}})
	_expect_eq(version_one.schema_version, SaveService.CURRENT_SCHEMA, "schema one migrates to current schema")
	_expect_eq(version_one.pig_state.ending_unlocked, false, "schema one receives ending defaults")
	_expect_eq(version_one.pig_state.current_photo_frame, "plain", "schema one receives the default album photo frame")
	var version_two: Dictionary = service.migrate({
		"schema_version":2,
		"pig_state":{
			"name":"v2",
			"life_photos":{
				"event_move_in":{"path":"user://legacy-photo.png", "captured_unix":123},
			},
		},
	})
	_expect_eq(version_two.schema_version, SaveService.CURRENT_SCHEMA, "schema two migrates to current schema")
	_expect_eq(version_two.pig_state.current_photo_frame, "plain", "schema two receives the default album photo frame")
	_expect_eq(version_two.pig_state.life_photos.event_move_in.photo_id, "photo_move_in", "schema two photo metadata migrates to the event's permanent photo ID")
	var version_three: Dictionary = service.migrate({"schema_version":3, "pig_state":{"name":"v3"}})
	_expect_eq(version_three.schema_version, SaveService.CURRENT_SCHEMA, "schema three migrates to current schema")
	_expect_eq(version_three.pig_state.demo_completion_seen, false, "schema three receives an unacknowledged Demo completion default")
	_expect_eq(service.save_settings({"ui_scale":1.25,"desktop_dock":"right","desktop_screen":1}), OK, "machine settings write succeeds")
	var settings: Dictionary = service.load_settings()
	_expect_eq(settings.ui_scale, 1.25, "machine UI scale persists separately")
	_expect_eq(settings.desktop_dock, "right", "machine desktop dock persists separately")
	_expect_eq(settings.desktop_screen, 1, "machine desktop screen persists separately")
	var detached_session: Node = GameSessionScript.new()
	detached_session.save_service = service
	detached_session.main_window_fullscreen = true
	detached_session.main_window_size = Vector2i(1440, 900)
	detached_session.main_window_position = Vector2i(123, 234)
	detached_session.reduce_motion = true
	detached_session.camera_shake_enabled = false
	detached_session.reduce_desktop_roaming = true
	detached_session.reduce_desktop_action_frequency = true
	detached_session.bubble_duration_scale = 1.75
	_expect_eq(detached_session.save_machine_settings(), OK, "detached session saves settings without querying the scene tree")
	var merged_settings: Dictionary = service.load_settings()
	_expect_eq(merged_settings.desktop_dock, "right", "general settings saves preserve desktop-specific fields")
	_expect_eq(merged_settings.desktop_screen, 1, "general settings saves preserve the desktop target screen")
	_expect_true(int(merged_settings.main_window_size.x) == 1440 and int(merged_settings.main_window_size.y) == 900, "main window size persists in machine settings")
	_expect_true(int(merged_settings.main_window_position.x) == 123 and int(merged_settings.main_window_position.y) == 234, "main window position persists in machine settings")
	_expect_eq(merged_settings.main_window_fullscreen, true, "main fullscreen state persists in machine settings")
	_expect_eq(merged_settings.reduce_motion, true, "reduced motion persists in machine settings")
	_expect_eq(merged_settings.camera_shake_enabled, false, "the independent camera-shake preference persists in machine settings")
	_expect_eq(merged_settings.reduce_desktop_roaming, true, "the independent desktop roaming preference persists in machine settings")
	_expect_eq(merged_settings.reduce_desktop_action_frequency, true, "the independent desktop action-frequency preference persists in machine settings")
	_expect_eq(merged_settings.bubble_duration_scale, 1.75, "the accessible bubble duration persists in machine settings")
	detached_session.catalog.load_all()
	detached_session.loaded_successfully = true
	detached_session.pig_state.name = "Settings Pig"
	detached_session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
	detached_session.pig_state.familiarity_level = 2
	_expect_true(detached_session.set_desktop_mode(true), "machine settings test enters desktop mode")
	_expect_eq(service.load_settings().desktop_mode, true, "entering desktop mode persists the active mode")
	detached_session.set_focus_mode(true)
	_expect_eq(detached_session.focus_mode, true, "focus mode changes through the session boundary")
	_expect_eq(service.load_settings().focus_mode, true, "focus mode persists as a machine-local setting")
	_expect_true(detached_session.set_desktop_mode(false), "machine settings test returns to the room")
	_expect_eq(service.load_settings().desktop_mode, false, "returning to the room persists the cleared desktop mode")
	_expect_eq(service.load_settings().desktop_dock, "right", "mode transitions retain the chosen desktop dock")
	_expect_eq(service.load_settings().desktop_screen, 1, "mode transitions retain the chosen desktop screen")
	detached_session.reduce_motion = false
	detached_session.camera_shake_enabled = true
	detached_session.reduce_desktop_roaming = false
	detached_session.reduce_desktop_action_frequency = false
	detached_session.bubble_duration_scale = 0.75
	detached_session.call("_load_machine_settings")
	_expect_true(detached_session.reduce_motion and detached_session.reduce_desktop_roaming, "both accessibility preferences restore independently from machine settings")
	_expect_eq(detached_session.camera_shake_enabled, false, "the camera-shake preference restores independently from reduced motion")
	_expect_eq(detached_session.reduce_desktop_action_frequency, true, "the desktop action-frequency preference restores independently from simulation state")
	_expect_eq(detached_session.bubble_duration_scale, 1.75, "the accessible bubble duration restores from machine settings")
	_expect_eq(service.save_settings({
		"ui_scale":[],
		"reduce_motion":"yes",
		"camera_shake_enabled":1,
		"reduce_desktop_roaming":{},
		"reduce_desktop_action_frequency":[],
		"bubble_duration_scale":"wide",
		"locale":"invalid",
		"desktop_mode":"yes",
		"focus_mode":1,
		"main_window_fullscreen":[],
		"main_window_size":{"x":[], "y":"large"},
		"main_window_position":{"x":{}, "y":[]},
		"audio":[],
	}), OK, "semantically malformed machine settings fixture writes as valid JSON")
	detached_session.call("_load_machine_settings")
	_expect_eq(detached_session.locale, "zh_CN", "malformed machine locale falls back safely")
	_expect_eq(detached_session.ui_scale, 1.0, "malformed machine UI scale preserves the last safe value")
	_expect_eq(detached_session.bubble_duration_scale, 1.75, "malformed bubble duration preserves the last safe value")
	_expect_true(
		detached_session.reduce_motion
			and not detached_session.camera_shake_enabled
			and detached_session.reduce_desktop_roaming
			and detached_session.reduce_desktop_action_frequency
			and not detached_session.desktop_mode
			and detached_session.focus_mode
			and detached_session.main_window_fullscreen,
		"malformed machine booleans preserve every independent safe preference"
	)
	_expect_eq(detached_session.main_window_size, Vector2i(1440, 900), "malformed machine geometry keeps the last safe in-memory size")
	_expect_eq(detached_session.main_window_position, Vector2i(123, 234), "malformed machine position keeps the last safe in-memory coordinates")
	detached_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_save_rotation_missing_generations() -> void:
	for mask: int in range(8):
		var label: String = "save generation mask %d" % mask
		var base: String = "user://piggy_save_gap_%d" % mask
		_remove_tree(ProjectSettings.globalize_path(base))
		var service := SaveService.new(base)
		var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
		for generation: int in range(1, 4):
			_expect_eq(service.save_game({"last_saved_unix":generation,"pig_state":{"name":"v%d" % generation,"daily_points":generation * 111}}), OK, "%s creates committed generation %d" % [label, generation])
		var original: Array[PackedByteArray] = []
		for index: int in paths.size():
			if mask & (1 << index) == 0:
				_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(paths[index])), OK, "%s removes only unavailable generation %d" % [label, index])
			original.append(FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray())
		var failures: Array[String] = []
		var recoveries: Array[String] = []
		service.save_failed.connect(func(message: String) -> void: failures.append(message))
		service.recovery_used.connect(func(source: String) -> void: recoveries.append(source))
		var blocked: String = service.save_path if mask & 1 == 0 else (service.backup_1_path if mask & 2 == 0 else (service.backup_2_path if mask & 4 == 0 else service.backup_2_path + ".rotate"))
		_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked)), OK, "%s blocks a required replacement path" % label)
		var next := {"last_saved_unix":4,"pig_state":{"name":"v4","daily_points":444}}
		_expect_true(service.save_game(next) != OK, "%s blocked commit reports failure" % label)
		_expect_eq(failures.size(), 1, "%s failed commit reports exactly one error" % label)
		for index: int in paths.size():
			var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
			_expect_eq(retained, original[index], "%s failed commit preserves available generation %d byte-for-byte" % [label, index])
		_expect_true(not FileAccess.file_exists(service.backup_2_path + ".rotate"), "%s failed commit has no staged committed backup" % label)
		_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked)), OK, "%s unblocks replacement without touching progress" % label)
		_expect_eq(service.save_game(next), OK, "%s next generation commits after retry" % label)
		var expected: Array[PackedByteArray] = [original[0] if mask & 1 else original[1], original[1] if mask & 3 == 3 else original[2]]
		for index: int in range(1, 3):
			var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
			_expect_eq(retained, expected[index - 1], "%s successful commit retains available backup %d byte-for-byte" % [label, index])
		var loaded: Dictionary = service.load_game()
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)), "%s fully committed main reloads without recovery" % label)
		_expect_eq(str((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("name", "")), "v4", "%s reload retains the new identity" % label)
		_expect_eq(int((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), 444, "%s reload retains the new balance" % label)
		var committed: Array[PackedByteArray] = []
		for path: String in paths:
			committed.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_eq(service.save_game(next), OK, "%s duplicate commit remains idempotent" % label)
		for index: int in paths.size():
			var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
			_expect_eq(retained, committed[index], "%s duplicate commit cannot rotate generation %d" % [label, index])
		if not expected[1].is_empty():
			var recovery_base: String = base + "_recovery"
			_remove_tree(ProjectSettings.globalize_path(recovery_base))
			var recovery := SaveService.new(recovery_base)
			_write_rotation_fixture(recovery.save_path, "{damaged-main")
			_write_rotation_fixture(recovery.backup_1_path, "{damaged-newest-backup")
			_write_rotation_fixture(recovery.backup_2_path, (FileAccess.get_file_as_bytes(service.backup_2_path) if FileAccess.file_exists(service.backup_2_path) else PackedByteArray()).get_string_from_utf8())
			var recovered: Dictionary = recovery.load_game()
			_expect_true(bool(recovered.get("ok", false)) and bool(recovered.get("recovered", false)), "%s retained older backup still recovers when newer generations are damaged" % label)
			_expect_eq(str(recovered.get("source", "")), recovery.backup_2_path, "%s actual recovery source is its retained backup2" % label)
			var expected_data: Dictionary = JSON.parse_string(expected[1].get_string_from_utf8()) as Dictionary
			_expect_eq(int((recovered.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), int(expected_data.pig_state.daily_points), "%s oldest recovery preserves the original balance" % label)
			_expect_eq(FileAccess.get_file_as_bytes(recovery.backup_2_path), expected[1], "%s recovery preserves original backup2 bytes" % label)
			_remove_tree(ProjectSettings.globalize_path(recovery_base))
		_expect_eq(service.save_game({"last_saved_unix":5,"pig_state":{"name":"v5","daily_points":555}}), OK, "%s following commit rotates normally" % label)
		_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), committed[0], "%s following commit retains v4 as newest backup" % label)
		_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path) if FileAccess.file_exists(service.backup_2_path) else PackedByteArray(), expected[0] if not expected[0].is_empty() else expected[1], "%s following commit preserves the available older generation" % label)
		var fifth: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
		_expect_eq(service.save_game({"last_saved_unix":6,"pig_state":{"name":"v6","daily_points":666}}), OK, "%s second following commit fills both rotating backups" % label)
		_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), fifth, "%s normal rotation retains v5" % label)
		_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path), committed[0], "%s normal rotation retains v4" % label)
		_expect_true(not FileAccess.file_exists(service.temp_path) and not FileAccess.file_exists(service.backup_2_path + ".rotate"), "%s completed commits leave no transient files" % label)
		_expect_eq(recoveries, [], "%s saving and normal reload do not announce recovery" % label)
		_expect_eq(failures.size(), 1, "%s successful retries emit no additional failure" % label)
		_remove_tree(ProjectSettings.globalize_path(base))


func _test_save_rotation_damaged_generations() -> void:
	var catalog := ContentCatalog.new()
	_expect_eq(catalog.load_all(), [], "damaged rotation fixture loads permanent content IDs")
	for layout: int in range(27):
		for damage: String in ["syntax", "fraction", "reference"]:
			var label: String = "damaged rotation layout %d %s" % [layout, damage]
			var base: String = "user://piggy_damaged_rotation_%d_%s" % [layout, damage]
			_remove_tree(ProjectSettings.globalize_path(base))
			var service := LostTemporarySaveService.new(base)
			service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
			var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
			var states: Array[int] = [layout % 3, (layout / 3) % 3, (layout / 9) % 3]
			var original: Array[PackedByteArray] = []
			for index: int in paths.size():
				var pig := {"name":"v%d" % (3 - index),"daily_points":(3 - index) * 111}
				var payload := {"schema_version":0 if layout % 2 == 0 else 4,"last_saved_unix":3 - index}
				payload["pig" if layout % 2 == 0 else "pig_state"] = pig
				if states[index] == 1:
					if damage == "fraction":
						pig.daily_points = float(pig.daily_points) + 0.25
					elif damage == "reference":
						pig["current_outfit"] = "outfit_unknown_damaged_generation"
				if states[index] != 0:
					_write_rotation_fixture(paths[index], "{damaged-existing-generation" if states[index] == 1 and damage == "syntax" else JSON.stringify(payload))
				_expect_eq(bool(service.call("_is_valid_game_payload", service.migrate(service.call("_read_valid", paths[index]) as Dictionary))), states[index] == 2, "%s verifies fixture generation %d availability" % [label, index])
				original.append(FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray())
			var failures: Array[String] = []
			var recoveries: Array[String] = []
			service.save_failed.connect(func(message: String) -> void: failures.append(message))
			service.recovery_used.connect(func(source: String) -> void: recoveries.append(source))
			var next := {"last_saved_unix":4,"pig_state":{"name":"v4","daily_points":444}}
			service.discard_temporary_before_rotation = true
			_expect_true(service.save_game(next) != OK, "%s verified temporary disappearance reports commit failure" % label)
			_expect_eq(failures.size(), 1, "%s failed commit emits one storage error" % label)
			for index: int in paths.size():
				var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
				_expect_eq(retained, original[index], "%s failed replacement restores raw generation %d including damage" % [label, index])
			_expect_true(not FileAccess.file_exists(service.backup_2_path + ".rotate"), "%s failed commit rolls back the staged generation" % label)
			service.discard_temporary_before_rotation = false
			_expect_eq(service.save_game(next), OK, "%s valid next generation commits after retry" % label)
			var expected: Array[PackedByteArray] = [original[0] if states[0] == 2 else original[1], original[1] if states[0] == 2 and states[1] == 2 else original[2]]
			for index: int in range(1, 3):
				var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
				_expect_eq(retained, expected[index - 1], "%s committed backup %d cannot be displaced by a damaged generation" % [label, index])
			var loaded: Dictionary = service.load_game()
			_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)), "%s new main reloads without recovery" % label)
			_expect_eq(int((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), 444, "%s new main retains its exact balance" % label)
			var committed: Array[PackedByteArray] = []
			for path: String in paths:
				committed.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
			_expect_eq(service.save_game(next), OK, "%s duplicate commit remains idempotent" % label)
			for index: int in paths.size():
				var retained: PackedByteArray = FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray()
				_expect_eq(retained, committed[index], "%s duplicate preserves raw generation %d" % [label, index])
			_expect_eq(service.save_game({"last_saved_unix":5,"pig_state":{"name":"v5","daily_points":555}}), OK, "%s subsequent normal saving remains usable" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), committed[0], "%s following commit retains v4" % label)
			var had_valid_newest: bool = states[0] == 2 or states[1] == 2
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path) if FileAccess.file_exists(service.backup_2_path) else PackedByteArray(), expected[0] if had_valid_newest else expected[1], "%s following commit retains the newest available older backup" % label)
			_expect_true(not FileAccess.file_exists(service.temp_path) and not FileAccess.file_exists(service.backup_2_path + ".rotate"), "%s successful commits consume transient files" % label)
			_expect_eq(recoveries, [], "%s normal saves and reload do not emit recovery" % label)
			_expect_eq(failures.size(), 1, "%s successful retries emit no extra error" % label)
			_remove_tree(ProjectSettings.globalize_path(base))
	for mask: int in range(1, 8):
		for damage: String in ["syntax", "fraction", "future"]:
			var label: String = "invalid staging canonical mask %d %s" % [mask, damage]
			var base: String = "user://piggy_invalid_rotation_cleanup_%d_%s" % [mask, damage]
			_remove_tree(ProjectSettings.globalize_path(base))
			var service := SaveService.new(base)
			service.configure_content_ids(catalog, GameSessionScript.ROOM_SLOTS)
			var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
			var original: Array[PackedByteArray] = []
			var first_index: int = -1
			for index: int in paths.size():
				if mask & (1 << index):
					_write_rotation_fixture(paths[index], JSON.stringify({"schema_version":4,"pig_state":{"name":"v%d" % (3 - index),"daily_points":(3 - index) * 111}}))
					if first_index < 0:
						first_index = index
				original.append(FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray())
			var staged := {"schema_version":5 if damage == "future" else 4,"pig_state":{"name":"damaged","daily_points":0.25}}
			_write_rotation_fixture(service.backup_2_path + ".rotate", "{damaged-staging" if damage == "syntax" else JSON.stringify(staged))
			var failures: Array[String] = []
			var recoveries: Array[String] = []
			service.save_failed.connect(func(message: String) -> void: failures.append(message))
			service.recovery_used.connect(func(source: String) -> void: recoveries.append(source))
			var loaded: Dictionary = service.load_game()
			_expect_true(bool(loaded.get("ok", false)), "%s usable canonical generation remains loadable" % label)
			_expect_eq(str(loaded.get("source", "")), paths[first_index], "%s cleanup cannot reshuffle canonical recovery priority" % label)
			_expect_eq(int((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), (3 - first_index) * 111, "%s canonical recovery keeps its exact balance" % label)
			for index: int in range(1, 3):
				_expect_eq(FileAccess.get_file_as_bytes(paths[index]) if FileAccess.file_exists(paths[index]) else PackedByteArray(), original[index], "%s invalid staging cannot replace raw backup %d" % [label, index])
			_expect_true(not FileAccess.file_exists(service.backup_2_path + ".rotate"), "%s unusable staging is consumed only with a verified canonical generation" % label)
			_expect_eq(failures, [], "%s invalid staging cannot permanently block valid progression" % label)
			_expect_eq(recoveries, [paths[first_index]] if first_index > 0 else [], "%s actual backup recovery is announced once" % label)
			_expect_eq(service.save_game({"last_saved_unix":4,"pig_state":{"name":"v4","daily_points":444}}), OK, "%s cleanup permits subsequent saving" % label)
			_remove_tree(ProjectSettings.globalize_path(base))


func _test_interrupted_save_rotation_recovery() -> void:
	for interruption_phase: int in [1, 2, 3, 4]:
		var phase_label: String = "phase %d" % interruption_phase
		var base := "user://piggy_interrupted_rotation_%d_tests" % interruption_phase
		_remove_tree(ProjectSettings.globalize_path(base))
		var service := SaveService.new(base)
		var recovery_sources: Array[String] = []
		service.recovery_used.connect(func(source: String) -> void: recovery_sources.append(source))
		for version: int in [1, 2, 3]:
			_expect_eq(
				service.save_game({"last_saved_unix":version,"pig_state":{"name":"v%d" % version}}),
				OK,
				"%s interrupted rotation fixture writes generation %d" % [phase_label, version]
			)
		var rotation_path: String = service.backup_2_path + ".rotate"
		_expect_eq(
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(service.backup_2_path),
				ProjectSettings.globalize_path(rotation_path)
			),
			OK,
			"%s fixture stages the oldest backup" % phase_label
		)
		if interruption_phase >= 2:
			_expect_eq(
				DirAccess.rename_absolute(
					ProjectSettings.globalize_path(service.backup_1_path),
					ProjectSettings.globalize_path(service.backup_2_path)
				),
				OK,
				"%s fixture interrupts after rotating the newest backup" % phase_label
			)
		if interruption_phase >= 3:
			_expect_eq(
				DirAccess.rename_absolute(
					ProjectSettings.globalize_path(service.save_path),
					ProjectSettings.globalize_path(service.backup_1_path)
				),
				OK,
				"%s fixture interrupts after rotating the main save" % phase_label
			)
		if interruption_phase >= 4:
			var committed_payload := {
				"schema_version": SaveService.CURRENT_SCHEMA,
				"last_saved_unix": 4,
				"pig_state": {"name":"v4"},
			}
			_expect_eq(
				service.call("_write_atomic", service.temp_path, committed_payload),
				OK,
				"%s fixture writes the verified replacement generation" % phase_label
			)
			_expect_eq(
				DirAccess.rename_absolute(
					ProjectSettings.globalize_path(service.temp_path),
					ProjectSettings.globalize_path(service.save_path)
				),
				OK,
				"%s fixture interrupts after committing the replacement main save" % phase_label
			)
		var committed_version: int = 4 if interruption_phase >= 4 else 3
		var loaded: Dictionary = service.load_game()
		_expect_true(
			bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)),
			"%s load repairs the interrupted transaction before selecting a recovery source" % phase_label
		)
		_expect_eq(
			str(loaded.data.pig_state.name),
			"v%d" % committed_version,
			"%s load retains the latest committed generation" % phase_label
		)
		var recovered_backup_1: Dictionary = service.call("_read_valid", service.backup_1_path) as Dictionary
		var recovered_backup_2: Dictionary = service.call("_read_valid", service.backup_2_path) as Dictionary
		_expect_eq(
			str(recovered_backup_1.pig_state.name),
			"v%d" % (committed_version - 1),
			"%s load restores backup1 to its committed generation" % phase_label
		)
		_expect_eq(
			str(recovered_backup_2.pig_state.name),
			"v%d" % (committed_version - 2),
			"%s load restores backup2 to its committed generation" % phase_label
		)
		_expect_true(
			not FileAccess.file_exists(rotation_path)
				and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(rotation_path)),
			"%s load consumes the rotation staging file" % phase_label
		)
		_expect_eq(
			service.save_game({
				"last_saved_unix":committed_version + 1,
				"pig_state":{"name":"v%d" % (committed_version + 1)},
			}),
			OK,
			"%s recovered transaction accepts the next save" % phase_label
		)
		var current: Dictionary = service.call("_read_valid", service.save_path) as Dictionary
		var next_backup_1: Dictionary = service.call("_read_valid", service.backup_1_path) as Dictionary
		var next_backup_2: Dictionary = service.call("_read_valid", service.backup_2_path) as Dictionary
		_expect_eq(
			str(current.pig_state.name),
			"v%d" % (committed_version + 1),
			"%s next save becomes the main generation" % phase_label
		)
		_expect_eq(
			str(next_backup_1.pig_state.name),
			"v%d" % committed_version,
			"%s next save retains the previous main in backup1" % phase_label
		)
		_expect_eq(
			str(next_backup_2.pig_state.name),
			"v%d" % (committed_version - 1),
			"%s next save retains the previous backup1 in backup2" % phase_label
		)
		_expect_eq(recovery_sources, [], "%s transaction repair does not report valid data as corruption recovery" % phase_label)
		_remove_tree(ProjectSettings.globalize_path(base))


func _test_rotation_staging_salvage() -> void:
	var pig := PigState.new()
	pig.name = "Staged Pig"
	pig.daily_points = 111
	pig.tutorial_skipped = true
	var payload := {"schema_version":SaveService.CURRENT_SCHEMA,"last_saved_unix":1000,"pig_state":pig.to_dict()}
	for mask: int in range(8):
		for schema: int in [0, SaveService.CURRENT_SCHEMA]:
			var label: String = "rotation mask %d schema %d" % [mask, schema]
			var base: String = "user://piggy_rotation_salvage_%d_%d" % [mask, schema]
			_remove_tree(ProjectSettings.globalize_path(base))
			var service := SaveService.new(base)
			var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
			for index: int in paths.size():
				if mask & (1 << index):
					_write_rotation_fixture(paths[index], "{damaged-canonical")
			var rotation_path: String = service.backup_2_path + ".rotate"
			var staged: Dictionary = payload.duplicate(true)
			staged.schema_version = schema
			_write_rotation_fixture(rotation_path, JSON.stringify(staged))
			var original: PackedByteArray = FileAccess.get_file_as_bytes(rotation_path)
			var sources: Array[String] = []
			service.recovery_used.connect(func(source: String) -> void: sources.append(source))
			var loaded: Dictionary = service.load_game()
			var data: Dictionary = loaded.get("data", {}) as Dictionary
			var state: Dictionary = data.get("pig_state", {}) as Dictionary
			_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)), "%s can salvage its only valid staged generation" % label)
			_expect_eq(str(state.get("name", "")), "Staged Pig", "%s preserves the staged identity" % label)
			_expect_eq(int(state.get("daily_points", -1)), 111, "%s preserves the staged balance" % label)
			_expect_eq(str(loaded.get("source", "")), service.backup_2_path, "%s restores staging to the normal oldest backup slot" % label)
			_expect_true(bool(loaded.get("had_files", false)), "%s is never a fresh installation" % label)
			_expect_eq(loaded.get("recovery_write_error", FAILED), OK, "%s commits the recovered main atomically" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path) if FileAccess.file_exists(service.backup_2_path) else PackedByteArray(), original, "%s preserves the original staged backup bytes" % label)
			_expect_true(not FileAccess.file_exists(rotation_path), "%s consumes staging only after a verified generation is retained" % label)
			var reloaded: Dictionary = service.load_game()
			_expect_true(bool(reloaded.get("ok", false)) and not bool(reloaded.get("recovered", true)) and str(reloaded.get("source", "")) == service.save_path, "%s reloads the repaired main without another recovery" % label)
			_expect_eq(int((reloaded.get("data", {}) as Dictionary).get("schema_version", -1)), SaveService.CURRENT_SCHEMA, "%s main is migrated to the current schema" % label)
			_expect_eq(sources, [service.backup_2_path], "%s announces exactly one real backup recovery" % label)
			var next: Dictionary = payload.duplicate(true)
			next.pig_state.daily_points = 112
			next.last_saved_unix = 1001
			_expect_eq(service.save_game(next), OK, "%s recovered layout can commit the next normal save" % label)
			var next_load: Dictionary = service.load_game()
			_expect_eq(int(((next_load.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary).get("daily_points", -1)), 112, "%s next normal save retains the intended balance" % label)
			_remove_tree(ProjectSettings.globalize_path(base))
	for mask: int in [0, 7]:
		for invalid_kind: String in ["syntax", "future", "fraction"]:
			var label: String = "invalid rotation mask %d %s" % [mask, invalid_kind]
			var base: String = "user://piggy_rotation_invalid_%d_%s" % [mask, invalid_kind]
			_remove_tree(ProjectSettings.globalize_path(base))
			var service := SaveService.new(base)
			var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path, service.backup_2_path + ".rotate"]
			for index: int in range(3):
				if mask & (1 << index):
					_write_rotation_fixture(paths[index], "{damaged-canonical")
			var invalid: Dictionary = payload.duplicate(true)
			if invalid_kind == "future":
				invalid.schema_version = SaveService.CURRENT_SCHEMA + 1
			elif invalid_kind == "fraction":
				invalid.pig_state.daily_points = 17.000001
			_write_rotation_fixture(paths[3], "{damaged-staging" if invalid_kind == "syntax" else JSON.stringify(invalid))
			var before: Array[PackedByteArray] = []
			for path: String in paths:
				before.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
			var result: Dictionary = service.load_game()
			_expect_true(not bool(result.get("ok", true)), "%s never becomes accepted progression" % label)
			_expect_true(bool(result.get("had_files", false)), "%s remains existing progression requiring recovery" % label)
			var after: Array[PackedByteArray] = []
			for path: String in paths:
				after.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
			_expect_eq(after, before, "%s preserves all damaged and future-version originals for manual recovery" % label)
			_expect_true(FileAccess.file_exists(paths[3]), "%s retains the rotation artifact rather than discarding it" % label)
			_remove_tree(ProjectSettings.globalize_path(base))
	for mask: int in range(1, 8):
		var base: String = "user://piggy_rotation_priority_%d" % mask
		_remove_tree(ProjectSettings.globalize_path(base))
		var service := SaveService.new(base)
		var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
		for index: int in paths.size():
			if mask & (1 << index):
				var canonical: Dictionary = payload.duplicate(true)
				canonical.pig_state.daily_points = 555 - index * 111
				_write_rotation_fixture(paths[index], JSON.stringify(canonical))
		_write_rotation_fixture(service.backup_2_path + ".rotate", JSON.stringify(payload))
		var loaded: Dictionary = service.load_game()
		var first_index: int = 0 if mask & 1 else (1 if mask & 2 else 2)
		_expect_true(bool(loaded.get("ok", false)), "rotation mask %d keeps its existing valid canonical generation usable" % mask)
		_expect_eq(int(((loaded.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary).get("daily_points", -1)), 555 - first_index * 111, "rotation mask %d cannot replace newer canonical progress with older staging" % mask)
		_expect_true(not FileAccess.file_exists(service.backup_2_path + ".rotate"), "rotation mask %d normalizes the residual valid staging layout" % mask)
		var next: Dictionary = payload.duplicate(true)
		next.pig_state.daily_points = 777
		_expect_eq(service.save_game(next), OK, "rotation mask %d accepts subsequent normal saving" % mask)
		_remove_tree(ProjectSettings.globalize_path(base))
	var blocked_base := "user://piggy_rotation_blocked_salvage"
	_remove_tree(ProjectSettings.globalize_path(blocked_base))
	var blocked := SaveService.new(blocked_base)
	var blocked_rotation: String = blocked.backup_2_path + ".rotate"
	_write_rotation_fixture(blocked_rotation, JSON.stringify(payload))
	var blocked_bytes: PackedByteArray = FileAccess.get_file_as_bytes(blocked_rotation)
	var failures: Array[String] = []
	blocked.save_failed.connect(func(message: String) -> void: failures.append(message))
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked.backup_2_path)), OK, "blocked salvage fixture obstructs only the normalization destination")
	var loaded: Dictionary = blocked.load_game()
	_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("recovered", false)), "failed metadata normalization still returns usable staged progression")
	_expect_eq(str(loaded.get("source", "")), blocked_rotation, "failed normalization identifies the real staging recovery source")
	_expect_eq(int(((loaded.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary).get("daily_points", -1)), 111, "failed normalization returns the exact retained balance")
	_expect_true(bool(loaded.get("had_files", false)), "failed normalization cannot classify the directory as new")
	_expect_eq(FileAccess.get_file_as_bytes(blocked_rotation), blocked_bytes, "failed normalization preserves the only valid original staging bytes")
	_expect_eq(failures.size(), 1, "failed metadata normalization emits exactly one real storage error")
	_expect_eq(loaded.get("recovery_write_error", FAILED), OK, "usable staging can still repair an independently writable main")
	_expect_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(blocked.backup_2_path)), "failed normalization cannot delete the blocked destination")
	_remove_tree(ProjectSettings.globalize_path(blocked_base))
	var profile_base := "user://piggy_rotation_profile_boundary"
	_remove_tree(ProjectSettings.globalize_path(profile_base))
	var profile_session: Node = GameSessionScript.new()
	profile_session.catalog.load_all()
	profile_session.save_service = SaveService.new(profile_base + "/full")
	profile_session.save_service.configure_content_ids(profile_session.catalog, profile_session.ROOM_SLOTS)
	var demo := SaveService.new(profile_base + "/demo")
	var demo_payload: Dictionary = payload.duplicate(true)
	demo_payload["release_profile"] = "demo"
	demo_payload.pig_state.name = "Unrelated Demo"
	demo_payload.pig_state.daily_points = 17
	_expect_eq(demo.save_game(demo_payload), OK, "orphan rotation profile fixture creates a real unrelated Demo")
	var demo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(demo.save_path)
	var target: SaveService = profile_session.save_service
	var target_rotation: String = target.backup_2_path + ".rotate"
	_write_rotation_fixture(target_rotation, "{damaged-existing-full-staging")
	var target_bytes: PackedByteArray = FileAccess.get_file_as_bytes(target_rotation)
	var profile_result: Dictionary = profile_session.call("_load_game_with_profile_import", "full", demo) as Dictionary
	_expect_true(not bool(profile_result.get("ok", true)), "invalid Full rotation cannot be replaced by another profile")
	_expect_true(bool(profile_result.get("had_files", false)), "invalid Full rotation remains an existing target before profile import")
	_expect_eq(FileAccess.get_file_as_bytes(demo.save_path), demo_bytes, "orphan recovery leaves the unrelated Demo source unchanged")
	_expect_eq(FileAccess.get_file_as_bytes(target_rotation), target_bytes, "orphan profile boundary leaves the damaged Full staging unchanged")
	_expect_true(not FileAccess.file_exists(target.save_path) and not FileAccess.file_exists(target.backup_1_path) and not FileAccess.file_exists(target.backup_2_path) and not FileAccess.file_exists(target.temp_path), "orphan recovery cannot write replacement Demo progression into any target generation")
	_expect_true(not profile_session.demo_save_imported, "orphan recovery cannot report an unrelated Demo import as success")
	profile_session.free()
	_remove_tree(ProjectSettings.globalize_path(profile_base))


func _test_mixed_rotation_backup_repair() -> void:
	for schema: int in [0, 4]:
		for mask: int in range(8):
			for damage: String in ["syntax", "fraction"]:
				var label: String = "mixed rotation schema %d mask %d %s" % [schema, mask, damage]
				var base: String = "user://piggy_mixed_rotation_%d_%d_%s" % [schema, mask, damage]
				_remove_tree(ProjectSettings.globalize_path(base))
				var service := SaveService.new(base)
				var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
				var originals: Array[PackedByteArray] = []
				for index: int in paths.size():
					var pig := {"name":"v%d" % (4 - index),"daily_points":(4 - index) * 111}
					if mask & (1 << index) == 0:
						pig.daily_points = float(pig.daily_points) + 0.25
					var payload := {"schema_version":schema,"last_saved_unix":4 - index,"note":"原始 café 🐷","extension":{"number":1.5,"enabled":true}}
					payload["pig" if schema == 0 else "pig_state"] = pig
					_write_rotation_fixture(paths[index], "{damaged-mixed-canonical" if mask & (1 << index) == 0 and damage == "syntax" else JSON.stringify(payload, "  ", false) + "\n ")
					_expect_eq(bool(service.call("_is_valid_game_payload", service.migrate(service.call("_read_valid", paths[index]) as Dictionary))), bool(mask & (1 << index)), "%s verifies canonical generation %d usability" % [label, index])
					originals.append(FileAccess.get_file_as_bytes(paths[index]))
				var staged := {"schema_version":schema,"last_saved_unix":1,"note":"旧代 café 🐷"}
				staged["pig" if schema == 0 else "pig_state"] = {"name":"v1","daily_points":111}
				var rotation: String = service.backup_2_path + ".rotate"
				_write_rotation_fixture(rotation, JSON.stringify(staged, "  ", false) + "\n\t")
				var staged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(rotation)
				var failures: Array[String] = []
				var recoveries: Array[String] = []
				service.save_failed.connect(func(message: String) -> void: failures.append(message))
				service.recovery_used.connect(func(source: String) -> void: recoveries.append(source))
				var loaded: Dictionary = service.load_game()
				var expected_first: PackedByteArray = originals[1] if mask & 2 else (originals[2] if mask & 4 else originals[1])
				var expected_second: PackedByteArray = originals[2] if mask & 6 == 6 else staged_bytes
				var expected_index: int = 0 if mask & 1 else (1 if mask & 6 else 2)
				var expected_points: int = 444 if mask & 1 else (333 if mask & 2 else (222 if mask & 4 else 111))
				_expect_true(bool(loaded.get("ok", false)) and bool(loaded.get("had_files", false)), "%s retains usable existing progression" % label)
				_expect_eq(str(loaded.get("source", "")), paths[expected_index], "%s returns the real newest usable source" % label)
				_expect_eq(int((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), expected_points, "%s load preserves the newest available balance" % label)
				_expect_eq(FileAccess.get_file_as_bytes(paths[1]), expected_first, "%s newest available backup retains original Unicode, whitespace and extension bytes" % label)
				_expect_eq(FileAccess.get_file_as_bytes(paths[2]), expected_second, "%s older available backup survives mixed canonical damage" % label)
				_expect_true(not FileAccess.file_exists(rotation) and not FileAccess.file_exists(paths[1] + ".tmp"), "%s successful repair consumes only transient files" % label)
				_expect_eq(failures, [], "%s successful repair emits no storage failure" % label)
				_expect_eq(recoveries, [paths[expected_index]] if expected_index > 0 else [], "%s actual backup recovery is announced exactly once" % label)
				_expect_true(not bool(service.load_game().get("recovered", true)), "%s repaired main reloads normally" % label)
				for index: int in range(1, 3):
					_expect_eq(FileAccess.get_file_as_bytes(paths[index]), expected_first if index == 1 else expected_second, "%s normal reload preserves backup %d bytes" % [label, index])
				_write_rotation_fixture(paths[0], "{damaged-new-main")
				_write_rotation_fixture(paths[1], "{damaged-newest-backup")
				var fallback: Dictionary = service.load_game()
				var second_data: Dictionary = service.migrate(JSON.parse_string(expected_second.get_string_from_utf8()) as Dictionary)
				_expect_true(bool(fallback.get("ok", false)) and str(fallback.get("source", "")) == paths[2], "%s retained backup2 can still recover after newer damage" % label)
				_expect_eq(int((fallback.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)), int(second_data.pig_state.daily_points), "%s final fallback preserves its exact original balance" % label)
				_expect_eq(FileAccess.get_file_as_bytes(paths[2]), expected_second, "%s final fallback preserves backup2 original bytes" % label)
				_remove_tree(ProjectSettings.globalize_path(base))
		for phase: String in ["copy-blocked", "copied", "replace-blocked"]:
			var label: String = "mixed rotation retry schema %d %s" % [schema, phase]
			var base: String = "user://piggy_mixed_retry_%d_%s" % [schema, phase]
			_remove_tree(ProjectSettings.globalize_path(base))
			var service := SaveService.new(base)
			var main := {"schema_version":4,"pig_state":{"name":"v4","daily_points":444}}
			var older := {"schema_version":schema,"last_saved_unix":2,"note":"原始 café 🐷"}
			older["pig" if schema == 0 else "pig_state"] = {"name":"v2","daily_points":222}
			var staged := {"schema_version":schema,"last_saved_unix":1}
			staged["pig" if schema == 0 else "pig_state"] = {"name":"v1","daily_points":111}
			_write_rotation_fixture(service.save_path, JSON.stringify(main))
			_write_rotation_fixture(service.backup_1_path, "{damaged-backup1")
			_write_rotation_fixture(service.backup_2_path, JSON.stringify(older, "  ", false) + "\n ")
			var rotation: String = service.backup_2_path + ".rotate"
			_write_rotation_fixture(rotation, JSON.stringify(staged, "  ", false) + "\n\t")
			var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
			var staged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(rotation)
			var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
			var damaged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
			var blocker: String = service.backup_1_path + ".tmp" if phase == "copy-blocked" else service.backup_2_path
			if phase != "copy-blocked":
				_write_rotation_fixture(service.backup_1_path, old_bytes.get_string_from_utf8())
			if phase == "replace-blocked":
				_expect_eq(DirAccess.rename_absolute(ProjectSettings.globalize_path(service.backup_2_path), ProjectSettings.globalize_path(service.backup_2_path + ".held")), OK, "%s blocks only the final replacement after a complete source copy" % label)
			if phase != "copied":
				_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocker)), OK, "%s creates a real repair destination blocker" % label)
			var failures: Array[String] = []
			service.save_failed.connect(func(message: String) -> void: failures.append(message))
			var loaded: Dictionary = service.load_game()
			_expect_true(bool(loaded.get("ok", false)) and str(loaded.get("source", "")) == service.save_path, "%s repair failure cannot replace the valid main source" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.save_path), main_bytes, "%s canonical main remains byte-identical" % label)
			if phase != "copied":
				_expect_eq(failures.size(), 1, "%s incomplete repair reports one real storage error" % label)
				_expect_eq(FileAccess.get_file_as_bytes(rotation) if FileAccess.file_exists(rotation) else PackedByteArray(), staged_bytes, "%s incomplete repair preserves staged old bytes" % label)
				_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), damaged_bytes if phase == "copy-blocked" else old_bytes, "%s failure preserves either original damaged target or already verified source copy" % label)
				_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker)), OK, "%s unblocks only the repair destination" % label)
				if phase == "replace-blocked":
					_expect_eq(DirAccess.rename_absolute(ProjectSettings.globalize_path(service.backup_2_path + ".held"), ProjectSettings.globalize_path(service.backup_2_path)), OK, "%s restores the held verified source" % label)
				loaded = service.load_game()
				_expect_true(bool(loaded.get("ok", false)), "%s repair resumes after the destination becomes available" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), old_bytes, "%s completed copy preserves exact newest backup bytes" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path), staged_bytes, "%s copied duplicate is not mistaken for two independent retained generations" % label)
			_expect_true(not FileAccess.file_exists(rotation) and not FileAccess.file_exists(service.backup_1_path + ".tmp"), "%s completed retry consumes repair staging" % label)
			_expect_eq(failures.size(), 0 if phase == "copied" else 1, "%s successful completion emits no extra errors" % label)
			_remove_tree(ProjectSettings.globalize_path(base))


func _write_rotation_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _test_atomic_rewrites() -> void:
	var base := "user://piggy_atomic_rewrite_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var service := SaveService.new(base)
	var failures: Array[String] = []
	var recoveries: Array[String] = []
	service.save_failed.connect(func(message: String) -> void: failures.append(message))
	service.recovery_used.connect(func(source: String) -> void: recoveries.append(source))
	for generation: int in range(1, 4):
		_expect_eq(service.save_game({"last_saved_unix":generation,"pig_state":{"name":"v%d" % generation}}), OK, "atomic rewrite fixture commits generation %d" % generation)
	var progression_paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
	var progression_before: Array[PackedByteArray] = []
	for path: String in progression_paths:
		progression_before.append(FileAccess.get_file_as_bytes(path))
	var settings: Dictionary = {"ui_scale":1.5,"locale":"zh_CN","position":{"x":-240.0,"y":100.0}}
	_expect_eq(service.save_settings(settings), OK, "atomic settings fixture writes an existing machine-local file")
	_expect_eq(service.load_settings(), settings, "machine settings preserve nested numbers and strings")
	var settings_before: PackedByteArray = FileAccess.get_file_as_bytes(service.settings_path)
	var settings_stage: String = service.settings_path + ".tmp"
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(settings_stage)), OK, "atomic settings fixture blocks only the staging path")
	_expect_true(service.save_settings({"ui_scale":0.8,"locale":"en"}) != OK, "failed staging cannot report a committed settings change")
	_expect_eq(FileAccess.get_file_as_bytes(service.settings_path), settings_before, "failed settings staging preserves the complete previous file")
	_expect_eq(service.load_settings(), settings, "failed settings staging retains the previous readable configuration")
	_expect_eq(failures.size(), 1, "failed settings staging emits exactly one storage error")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_stage)), OK, "atomic settings fixture unblocks staging")
	_expect_eq(service.save_settings({"ui_scale":0.8,"locale":"en"}), OK, "settings retry commits after staging becomes writable")
	_expect_eq(service.load_settings(), {"ui_scale":0.8,"locale":"en"}, "settings retry reloads the new complete configuration")
	_expect_true(not FileAccess.file_exists(settings_stage), "successful settings replacement consumes its temporary file")
	var stale := FileAccess.open(settings_stage, FileAccess.WRITE)
	stale.store_string("interrupted partial JSON")
	stale.close()
	_expect_eq(service.save_settings({}), OK, "interrupted settings temporary data cannot prevent a clean retry")
	var empty_settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.settings_path))
	_expect_true(empty_settings is Dictionary and (empty_settings as Dictionary).is_empty(), "empty machine settings remain a valid complete JSON dictionary")
	_expect_true(not FileAccess.file_exists(settings_stage), "retry consumes stale settings staging data")
	var progression_after: Array[PackedByteArray] = []
	for path: String in progression_paths:
		progression_after.append(FileAccess.get_file_as_bytes(path))
	_expect_eq(progression_after, progression_before, "machine settings writes cannot alter the main progression or either backup")
	_expect_eq(recoveries.size(), 0, "machine settings writes cannot report progression recovery")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(service.settings_path)), OK, "settings rename-failure fixture removes only its machine-local file")
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(service.settings_path)), OK, "settings rename-failure fixture blocks only the destination")
	_expect_true(service.save_settings(settings) != OK, "settings replacement errors are propagated")
	_expect_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(service.settings_path)), "failed settings replacement preserves the blocked destination")
	_expect_true(not FileAccess.file_exists(settings_stage), "failed settings replacement cleans up uncommitted staging data")
	_expect_eq(failures.size(), 2, "settings replacement failure emits one additional storage error")
	var broken_main := FileAccess.open(service.save_path, FileAccess.WRITE)
	broken_main.store_string("{damaged-main")
	broken_main.close()
	var damaged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
	var restore_stage: String = service.save_path + ".tmp"
	_expect_true(restore_stage != settings_stage and restore_stage != service.temp_path, "recovery, settings and rotating save stages are distinct")
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(restore_stage)), OK, "backup restoration fixture blocks only the staging file")
	var failed_restore: Dictionary = service.load_game()
	_expect_true(bool(failed_restore.get("ok", false)) and bool(failed_restore.get("recovered", false)), "failed atomic restoration still returns usable backup progression")
	_expect_eq(str(failed_restore.data.pig_state.name), "v2", "failed atomic restoration returns the newest verified backup")
	_expect_eq(str(failed_restore.source), service.backup_1_path, "failed atomic restoration identifies its actual backup source")
	_expect_true(failed_restore.get("recovery_write_error", OK) != OK, "failed restoration staging is reported explicitly")
	_expect_eq(FileAccess.get_file_as_bytes(service.save_path), damaged_bytes, "failed restoration staging cannot truncate or rewrite the damaged main")
	_expect_eq(failures.size(), 3, "failed restoration staging emits exactly one additional storage error")
	_expect_eq(recoveries, [service.backup_1_path], "failed restoration announces the usable backup exactly once")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(restore_stage)), OK, "backup restoration fixture unblocks its staging path")
	stale = FileAccess.open(restore_stage, FileAccess.WRITE)
	stale.store_string("{partial-restore")
	stale.close()
	var restored: Dictionary = service.load_game()
	_expect_true(bool(restored.get("ok", false)) and bool(restored.get("recovered", false)), "backup restoration retries successfully despite stale partial staging")
	_expect_eq(restored.get("recovery_write_error", FAILED), OK, "successful atomic restoration reports a committed main")
	_expect_eq(str(restored.data.pig_state.name), "v2", "successful restoration preserves the recovered generation")
	_expect_true(not FileAccess.file_exists(restore_stage), "successful restoration consumes its temporary file")
	var reload: Dictionary = service.load_game()
	_expect_true(bool(reload.get("ok", false)) and not bool(reload.get("recovered", true)), "the next load uses the completely restored main")
	_expect_eq(str(reload.source), service.save_path, "restored main is used without another backup recovery")
	_expect_eq(recoveries, [service.backup_1_path, service.backup_1_path], "a successful main reload does not repeat the recovery notification")
	_expect_eq(failures.size(), 3, "successful restoration retry does not emit another storage error")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path)), OK, "restore rename-failure fixture removes only the main")
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(service.save_path)), OK, "restore rename-failure fixture blocks only the main destination")
	var blocked_restore: Dictionary = service.load_game()
	_expect_true(bool(blocked_restore.get("ok", false)) and bool(blocked_restore.get("recovered", false)), "failed restore replacement keeps backup progression usable")
	_expect_true(blocked_restore.get("recovery_write_error", OK) != OK, "failed restore replacement reports its storage error")
	_expect_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(service.save_path)), "failed restore replacement preserves the blocked destination")
	_expect_true(not FileAccess.file_exists(restore_stage), "failed restore replacement removes uncommitted staging")
	_expect_eq(failures.size(), 4, "failed restore replacement emits exactly one additional storage error")
	for index: int in range(1, progression_paths.size()):
		_expect_eq(FileAccess.get_file_as_bytes(progression_paths[index]), progression_before[index], "atomic restoration keeps backup%d byte-identical through failures and retries" % index)
	_expect_true(not FileAccess.file_exists(service.temp_path) and not FileAccess.file_exists(service.backup_2_path + ".rotate"), "direct atomic rewrites cannot enter progression backup rotation")
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_save_write_failures() -> void:
	var base := "user://piggy_save_failure_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var rotation_base := base + "_rotation"
	_remove_tree(ProjectSettings.globalize_path(rotation_base))
	var rotation_service := SaveService.new(rotation_base)
	var rotation_failures: Array[String] = []
	rotation_service.save_failed.connect(func(message: String) -> void: rotation_failures.append(message))
	_expect_eq(rotation_service.save_game({"last_saved_unix":1,"pig_state":{"name":"v1"}}), OK, "rotation rollback fixture writes its first generation")
	_expect_eq(rotation_service.save_game({"last_saved_unix":2,"pig_state":{"name":"v2"}}), OK, "rotation rollback fixture writes its second generation")
	_expect_eq(rotation_service.save_game({"last_saved_unix":3,"pig_state":{"name":"v3"}}), OK, "rotation rollback fixture writes its third generation")
	var blocked_backup_1_abs: String = ProjectSettings.globalize_path(rotation_service.backup_1_path)
	DirAccess.remove_absolute(blocked_backup_1_abs)
	DirAccess.make_dir_recursive_absolute(blocked_backup_1_abs)
	_expect_true(rotation_service.save_game({"last_saved_unix":4,"pig_state":{"name":"v4"}}) != OK, "failed main-to-backup rotation reports a save failure")
	_expect_true(FileAccess.file_exists(rotation_service.save_path), "failed rotation keeps the previous main save")
	var preserved_main: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rotation_service.save_path)) as Dictionary
	_expect_eq(str(preserved_main.pig_state.name), "v3", "failed rotation preserves the previous main generation")
	_expect_true(FileAccess.file_exists(rotation_service.backup_2_path), "failed rotation keeps the oldest recovery backup")
	var preserved_backup_2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rotation_service.backup_2_path)) as Dictionary
	_expect_eq(str(preserved_backup_2.pig_state.name), "v1", "failed rotation restores the oldest recovery generation")
	var rotation_staging_path: String = rotation_service.backup_2_path + ".rotate"
	_expect_true(
		not FileAccess.file_exists(rotation_staging_path)
			and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(rotation_staging_path)),
		"failed rotation leaves no staging artifact"
	)
	_expect_eq(rotation_failures.size(), 1, "transactional rotation failure emits one player-reportable error")
	var service := SaveService.new(base)
	_expect_eq(service.save_game({"last_saved_unix":1,"pig_state":{"name":"stable"}}), OK, "failure test starts from a valid main save")
	var blocker_path := base + "/not_a_directory"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("block child paths")
	blocker.close()
	var failures: Array[String] = []
	service.save_failed.connect(func(message: String) -> void: failures.append(message))
	var normal_temp: String = service.temp_path
	_expect_true(service.save_game({"last_saved_unix":2,"pig_state":[]}) != OK, "structurally invalid temporary data is rejected")
	_expect_eq(str(service.load_game().data.pig_state.name), "stable", "semantic temporary validation preserves the valid main save")
	service.temp_path = blocker_path + "/savegame.tmp.json"
	_expect_true(service.save_game({"last_saved_unix":2,"pig_state":{"name":"unsafe"}}) != OK, "unwritable temporary path reports a save failure")
	_expect_eq(str(service.load_game().data.pig_state.name), "stable", "temporary write failure preserves the valid main save")
	service.temp_path = normal_temp
	service.backup_1_path = blocker_path + "/savegame.backup1.json"
	_expect_true(service.save_game({"last_saved_unix":3,"pig_state":{"name":"unsafe"}}) != OK, "unwritable rotation path reports a save failure")
	_expect_eq(str(service.load_game().data.pig_state.name), "stable", "rotation failure preserves the valid main save")
	service.settings_path = blocker_path + "/machine_settings.json"
	_expect_true(service.save_settings({"ui_scale":1.0}) != OK, "unwritable machine settings path reports a save failure")
	_expect_eq(failures.size(), 4, "all save failure paths emit a player-reportable error")
	var recovery_base := "user://piggy_recovery_rewrite_failure_tests"
	_remove_tree(ProjectSettings.globalize_path(recovery_base))
	var recovery_service := SaveService.new(recovery_base)
	_expect_eq(recovery_service.save_game({"last_saved_unix":1,"pig_state":{"name":"backup-stable"}}), OK, "recovery rewrite fixture writes a valid generation")
	_expect_eq(
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(recovery_service.save_path),
			ProjectSettings.globalize_path(recovery_service.backup_1_path)
		),
		OK,
		"recovery rewrite fixture stages the valid generation as backup1"
	)
	var recovery_blocker_path := recovery_base + "/not_a_directory"
	var recovery_blocker := FileAccess.open(recovery_blocker_path, FileAccess.WRITE)
	recovery_blocker.store_string("block repaired main path")
	recovery_blocker.close()
	recovery_service.save_path = recovery_blocker_path + "/savegame.json"
	var recovery_failures: Array[String] = []
	var recovery_sources: Array[String] = []
	recovery_service.save_failed.connect(func(message: String) -> void: recovery_failures.append(message))
	recovery_service.recovery_used.connect(func(source: String) -> void: recovery_sources.append(source))
	var rewrite_failure: Dictionary = recovery_service.load_game()
	_expect_true(bool(rewrite_failure.get("ok", false)) and bool(rewrite_failure.get("recovered", false)), "backup data remains usable when the repaired main cannot be written")
	_expect_eq(str(rewrite_failure.data.pig_state.name), "backup-stable", "failed main rewrite returns the verified backup progression")
	_expect_true(rewrite_failure.get("recovery_write_error", OK) != OK, "backup load reports that the main save was not repaired")
	_expect_eq(recovery_sources, [recovery_service.backup_1_path], "failed main rewrite still identifies the backup recovery source")
	_expect_eq(recovery_failures.size(), 1, "failed main rewrite emits one player-visible storage error")
	_expect_true(FileAccess.file_exists(recovery_service.backup_1_path), "failed main rewrite preserves the verified recovery backup")
	var retry_session: Node = GameSessionScript.new()
	retry_session.catalog.load_all()
	retry_session.loaded_successfully = true
	retry_session.save_service = SaveService.new(base + "_autosave")
	_expect_eq(retry_session.call("_save_game_at", 1000), OK, "failed autosave fixture starts from a committed time anchor")
	var retry_temp_path: String = retry_session.save_service.temp_path
	retry_session.save_service.temp_path = blocker_path + "/autosave.tmp.json"
	retry_session.set("_autosave_elapsed", GameSessionScript.AUTOSAVE_SECONDS)
	_expect_true(retry_session.call("_save_game_at", 2000) != OK, "failed autosave fixture reports its write error")
	_expect_eq(retry_session.get("_autosave_elapsed"), 0.0, "failed autosave restarts the 60-second interval instead of retrying every frame")
	_expect_eq(retry_session.get("_last_saved_unix"), 1000, "failed autosave preserves the last committed in-memory time anchor")
	_expect_eq(int(retry_session.save_service.load_game().data.last_saved_unix), 1000, "failed autosave preserves the last committed on-disk time anchor")
	retry_session.save_service.temp_path = retry_temp_path
	_expect_eq(retry_session.call("_save_game_at", 3000), OK, "autosave retry commits after storage recovers")
	_expect_eq(retry_session.get("_last_saved_unix"), 3000, "successful autosave retry advances the in-memory time anchor")
	_expect_eq(int(retry_session.save_service.load_game().data.last_saved_unix), 3000, "successful autosave retry advances the on-disk time anchor")
	retry_session.free()
	var surfaced_session: Node = GameSessionScript.new()
	surfaced_session.call("_on_save_recovered", "backup1")
	surfaced_session.call("_on_save_failed", "permission denied")
	_expect_eq(surfaced_session.last_recovery_source, "backup1", "save recovery remains visible to UI created after startup")
	_expect_eq(surfaced_session.last_save_error, "permission denied", "save failure remains visible to the current session")
	surfaced_session.free()
	_remove_tree(ProjectSettings.globalize_path(base))
	_remove_tree(ProjectSettings.globalize_path(rotation_base))
	_remove_tree(ProjectSettings.globalize_path(recovery_base))


func _test_player_command_save_failure_transactions() -> void:
	var base := "user://piggy_shop_save_failure_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	var catalog_errors: Array[String] = session.catalog.load_all()
	session.loaded_successfully = catalog_errors.is_empty()
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, GameSession.ROOM_SLOTS)
	session.call("_connect_modules")
	session.pig_state.name = "Transaction Pig"
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[9]
	session.pig_state.familiarity_level = 10
	session.pig_state.daily_points = 1000
	session.pig_state.satiety = 40.0
	session.pig_state.interest = 40.0
	session.pig_state.tutorial_step = 0
	session.pig_state.tutorial_skipped = false
	for expression: Dictionary in session.catalog.expressions:
		session.pig_state.unlocked_expressions.append(str(expression.id))
	for event: Dictionary in session.catalog.events:
		session.pig_state.discovered_events.append(str(event.id))
		session.pig_state.seen_events.append(str(event.id))
	session.pig_state.ending_unlocked = true
	session.pig_state.ending_seen = false
	session.pig_state.demo_completion_seen = false
	if "furn_pillow_cloud" not in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.append("furn_pillow_cloud")
	session.pig_state.owned_furniture.erase("furn_nightlight_moon")
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	session.pig_state.owned_outfits.clear()
	session.pig_state.owned_outfits.append("outfit_round_glasses")
	session.pig_state.current_outfit = ""
	_expect_eq(session.save_game(), OK, "shop failure fixture commits its stable progression baseline")
	var baseline: Dictionary = session.pig_state.to_dict().duplicate(true)
	var disk_generation_before: Dictionary = {}
	for path: String in [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]:
		disk_generation_before[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var blocker_path := base + "/not_a_directory"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("block child paths")
	blocker.close()
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = blocker_path + "/savegame.tmp.json"
	var failures: Array[String] = []
	var success_toasts: Array[String] = []
	var behavior_changes: Array[Dictionary] = []
	var mode_changes: Array[bool] = []
	session.save_failed.connect(func(message: String) -> void: failures.append(message))
	session.toast_requested.connect(func(key: String, _values: Dictionary) -> void: success_toasts.append(key))
	session.behavior_changed.connect(func(behavior: Dictionary) -> void: behavior_changes.append(behavior.duplicate(true)))
	session.mode_changed.connect(func(enabled: bool) -> void: mode_changes.append(enabled))
	_expect_true(session.pet_pig().is_empty(), "failed pet save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed pet save rolls back points, familiarity, daily decay, achievements, and tutorial")
	session.pig_state.load_dict(baseline)
	_expect_true(session.poke_pig().is_empty(), "failed poke save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed poke save rolls back points, familiarity, daily decay, achievements, and tutorial")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.feed("snack_apple"), "failed feed save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed feed save rolls back points, needs, daily counters, expressions, achievements, and tutorial")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.purchase("furniture", "furn_nightlight_moon"), "failed furniture purchase save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed furniture purchase save rolls back points, ownership, achievements, and tutorial")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.place_furniture("sleep_2", "furn_pillow_cloud"), "failed furniture placement save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed furniture placement save restores the previous fixed-slot layout")
	session.pig_state.load_dict(baseline)
	var simulation_baseline: Dictionary = session.simulation.to_dict().duplicate(true)
	_expect_true(not session.invite_to_furniture("furn_bed_basic"), "failed furniture invitation save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed furniture invitation save restores the previous interest state")
	_expect_eq(session.simulation.to_dict(), simulation_baseline, "failed furniture invitation save restores the previous behavior timer")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.equip_outfit("outfit_round_glasses"), "failed outfit equip save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed outfit equip save restores the previous attachment")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.set_room_palette("mint"), "failed room palette save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed room palette save restores the previous room appearance")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.set_photo_frame("star"), "failed photo frame save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed photo frame save restores the previous album appearance")
	session.pig_state.load_dict(baseline)
	var favorite_expression_id: String = str(session.catalog.expressions[0].id)
	_expect_true(not session.set_favorite_desktop_expression(favorite_expression_id), "failed desktop expression save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed desktop expression save restores the previous idle preference")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.set_tendency("rest"), "failed tendency save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed tendency save restores both the previous preference and tutorial step")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.complete_tutorial_step(4), "failed album tutorial save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed album tutorial save restores the previous onboarding step")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.set_desktop_mode(true), "failed desktop-entry checkpoint refuses the window mode transition")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed desktop-entry checkpoint restores the previous onboarding step")
	_expect_true(not session.desktop_mode, "failed desktop-entry checkpoint leaves the room mode active")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.set_pig_name("Renamed Pig"), "failed naming save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed naming save restores both the previous name and tutorial step")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.skip_tutorial(), "failed tutorial skip save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed tutorial skip save restores the active onboarding state")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.restart_tutorial(), "failed tutorial replay save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed tutorial replay save restores the previous onboarding state")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.mark_ending_seen(), "failed ending acknowledgement save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed ending acknowledgement save keeps the ending retryable")
	session.pig_state.load_dict(baseline)
	_expect_true(not session.mark_demo_completion_seen("demo"), "failed Demo acknowledgement save reports failure to its caller")
	_expect_eq(session.pig_state.to_dict(), baseline, "failed Demo acknowledgement save keeps the completion page retryable")
	var disk_generation_after: Dictionary = {}
	for path: String in disk_generation_before:
		disk_generation_after[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	_expect_eq(disk_generation_after, disk_generation_before, "all failed player commands preserve the exact committed disk generation")
	_expect_eq(failures.size(), 18, "each failed player command emits exactly one player-visible save failure")
	_expect_eq(success_toasts, [], "failed player commands emit no feed or purchase success feedback")
	_expect_eq(behavior_changes, [], "failed furniture invitation emits no uncommitted behavior change")
	_expect_eq(mode_changes, [], "failed desktop entry emits no uncommitted mode change")
	_expect_true(not bool(session.get("_important_save_pending")), "failed player commands restore the important-save scheduler state")
	session.save_service.temp_path = normal_temp_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_first_launch_and_reinstall() -> void:
	var base := "user://piggy_reinstall_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var first: Node = GameSessionScript.new()
	first.catalog.load_all()
	first.save_service = SaveService.new(base)
	first.call("_load_or_create_game")
	_expect_eq(first.pig_state.name, "", "first launch keeps the persisted name empty until the player chooses one")
	_expect_eq(first.last_save_error, "", "true first launch does not report a false corruption warning")
	first.loaded_successfully = true
	var previous_locale: String = TranslationServer.get_locale()
	var localized_names: Array[Array] = [["zh_CN", "猪咪"], ["zh_TW", "豬咪"], ["en", "Piggy"]]
	for locale_and_name: Array in localized_names:
		TranslationServer.set_locale(locale_and_name[0])
		_expect_eq(first.pig_display_name(), locale_and_name[1], "unnamed pig uses the localized display name in %s" % locale_and_name[0])
	TranslationServer.set_locale(previous_locale)
	_expect_eq(first.save_game(), OK, "autosave can safely checkpoint the unnamed first-launch state")
	first.pig_state.name = "还在这里"
	first.pig_state.daily_points = 432
	_expect_eq(first.save_game(), OK, "first launch progression can be saved")
	first.free()
	var reinstalled: Node = GameSessionScript.new()
	reinstalled.catalog.load_all()
	reinstalled.save_service = SaveService.new(base)
	reinstalled.call("_load_or_create_game")
	_expect_eq(reinstalled.pig_state.name, "还在这里", "reinstall simulation reloads progression from the user directory")
	_expect_eq(reinstalled.pig_state.daily_points, 432, "reinstall simulation preserves the progression balance")
	_expect_true(not FileAccess.file_exists(reinstalled.save_service.settings_path), "progression does not depend on machine settings")
	reinstalled.free()
	var damage_service := SaveService.new(base)
	for path: String in [damage_service.save_path, damage_service.backup_1_path, damage_service.backup_2_path]:
		var invalid := FileAccess.open(path, FileAccess.WRITE)
		invalid.store_string("{broken")
		invalid.close()
	var damaged: Node = GameSessionScript.new()
	damaged.catalog.load_all()
	damaged.save_service = SaveService.new(base)
	damaged.call("_load_or_create_game")
	_expect_true(not damaged.last_save_error.is_empty(), "startup retains an exhausted-recovery error for UI created afterward")
	damaged.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_desktop_companion_policy() -> void:
	var policy := DesktopCompanionPolicy.new()
	_expect_true(not policy.application_focused and not policy.proactive_allowed(), "companion starts protected before native focus is known")
	for focused: bool in [false, true]:
		for quiet: bool in [false, true]:
			for no_disturb: bool in [false, true]:
				for frequency: String in DesktopCompanionPolicy.FREQUENCIES:
					policy.load_settings({"desktop_quiet":quiet, "desktop_do_not_disturb":no_disturb, "desktop_behavior_frequency":frequency})
					policy.set_application_focused(focused)
					var label: String = "companion focused=%s quiet=%s dnd=%s frequency=%s" % [focused, quiet, no_disturb, frequency]
					var proactive: bool = focused and not quiet and not no_disturb and frequency != "off"
					_expect_eq(policy.proactive_allowed(), proactive, "%s gates all proactive messages" % label)
					_expect_eq(policy.autonomous_motion_allowed(), proactive, "%s gates all autonomous motion" % label)
					_expect_eq(policy.effective_always_on_top(true), focused and not no_disturb, "%s protects other games regardless of stored top preference" % label)
					_expect_true(not policy.effective_always_on_top(false), "%s never enables an unwanted top preference" % label)
					policy.note_explicit_interaction()
					_expect_true(policy.message_allowed() and policy.explicit_feedback_allowed(), "%s permits deliberately requested feedback" % label)
					_expect_eq(policy.proactive_allowed(), proactive, "%s deliberate feedback never reactivates autonomous work" % label)
					policy.set_application_focused(false)
					_expect_true(not policy.message_allowed(), "%s focus loss clears even an already-background feedback lease" % label)
	policy.load_settings({"desktop_quiet":"true", "desktop_do_not_disturb":1, "desktop_behavior_frequency":[]})
	_expect_eq(policy.settings(), {"desktop_quiet":false, "desktop_do_not_disturb":false, "desktop_behavior_frequency":"normal"}, "malformed companion preferences use strict safe defaults")
	var expected_holds: Array[float] = [0.0, 45.0, 120.0, INF]
	for index: int in DesktopCompanionPolicy.FREQUENCIES.size():
		policy.load_settings({"desktop_behavior_frequency":DesktopCompanionPolicy.FREQUENCIES[index]})
		_expect_eq(policy.presentation_hold_seconds(false), expected_holds[index], "data-driven frequency has the intended minimum hold")
		_expect_true(policy.presentation_hold_seconds(true) >= 45.0, "legacy reduced action preference remains a minimum rather than bypassing the new frequency")
	var changes: Array[int] = [0]
	policy.changed.connect(func() -> void: changes[0] += 1)
	for interaction: int in 10:
		policy.note_explicit_interaction()
	_expect_eq(changes[0], 0, "local input does not emit policy changes or reset the behavior hold")
	policy.set("_explicit_feedback_until", Time.get_ticks_msec() - 1)
	_expect_true(not policy.message_allowed(), "explicit feedback lease expires without wall-clock history")


func _test_focus_companion_timer() -> void:
	var policy := DesktopCompanionPolicy.new()
	var reminders: Array[int] = [0]
	var ticks: Array[int] = [0]
	policy.break_ready.connect(func() -> void: reminders[0] += 1)
	policy.timer_changed.connect(func() -> void: ticks[0] += 1)
	policy.set_application_focused(true)
	_expect_true(not policy.start_rest(), "a rest cannot start before a work interval")
	policy.start_work()
	_expect_eq(policy.timer_snapshot(), {"phase":"work", "remaining":1500, "paused":false}, "focus starts the configured 25 minutes")
	_expect_eq(policy.timer_animation(), "read", "focused work uses the existing reading art")
	policy.advance(0.25)
	_expect_eq(ticks[0], 1, "timer labels do not refresh for every sub-second frame")
	policy.advance(0.75)
	_expect_eq(ticks[0], 2, "timer labels refresh only when the displayed second changes")
	policy.toggle_timer_pause()
	var paused: Dictionary = policy.timer_snapshot()
	policy.advance(5000.0)
	_expect_eq(policy.timer_snapshot(), paused, "paused timer ignores elapsed time")
	_expect_eq(policy.timer_animation(), "", "timer pause stops the companion reading override")
	policy.toggle_timer_pause()
	for invalid: float in [0.0, -1.0, INF, NAN]:
		var before: Dictionary = policy.timer_snapshot()
		policy.advance(invalid)
		_expect_eq(policy.timer_snapshot(), before, "invalid timer delta cannot corrupt timer state")
	policy.advance(2000.0)
	_expect_eq(policy.timer_phase, "rest_ready", "work completion waits for a deliberate rest start")
	_expect_eq(reminders[0], 1, "foreground completion emits one gentle reminder")
	policy.advance(100.0)
	_expect_eq(reminders[0], 1, "completed work never repeats reminders or counts into a break")
	_expect_true(policy.start_rest(), "rest can start deliberately after work")
	_expect_eq(policy.timer_snapshot(), {"phase":"rest", "remaining":300, "paused":false}, "rest starts the configured five minutes")
	_expect_eq(policy.timer_animation(), "yoga", "rest uses the existing stretching art")
	policy.advance(300.0)
	_expect_eq(policy.timer_phase, "finished", "rest completion has no automatic restart")
	_expect_eq(reminders[0], 1, "rest completion adds no extra interruption")
	policy.stop_timer()
	_expect_eq(policy.timer_snapshot(), {"phase":"idle", "remaining":0, "paused":false}, "timer stop erases the in-memory interval")
	for mode: String in ["background", "quiet", "dnd", "off"]:
		policy.load_settings({"desktop_quiet":mode == "quiet", "desktop_do_not_disturb":mode == "dnd", "desktop_behavior_frequency":"off" if mode == "off" else "normal"})
		policy.set_application_focused(mode != "background")
		policy.start_work()
		policy.note_explicit_interaction()
		_expect_eq(policy.timer_animation(), "", "%s suppresses timer animation even during a feedback lease" % mode)
		policy.advance(1500.0)
		_expect_eq(policy.timer_phase, "rest_ready", "%s keeps timer progress without auto-starting rest" % mode)
		_expect_eq(reminders[0], 1, "%s completion is silent even after explicit input" % mode)
		policy.load_settings({})
		policy.set_application_focused(true)
		policy.advance(1.0)
		_expect_eq(reminders[0], 1, "%s never replays an expired reminder on return" % mode)
	_expect_true(not policy.settings().has("timer_phase") and not policy.settings().has("application_focused"), "transient focus, timer and input history are not persisted")


func _test_desktop_companion_session() -> void:
	var base: String = "user://companion_protection_tests"
	_remove_tree(ProjectSettings.globalize_path(base))
	var session: Node = GameSessionScript.new()
	session.catalog.load_all()
	session.loaded_successfully = true
	session.save_service = SaveService.new(base)
	session.save_service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	session.pig_state.name = "Quiet Pig"
	_expect_eq(session.save_game(), OK, "companion preferences fixture stores legitimate progress")
	var pig_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	var simulation_before: Dictionary = session.simulation.to_dict().duplicate(true)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
	_expect_true(session.set_desktop_companion_settings(true, true, "rare"), "companion preferences change through the session facade")
	var settings: Dictionary = session.save_service.load_settings()
	_expect_true(settings.desktop_quiet and settings.desktop_do_not_disturb and settings.desktop_behavior_frequency == "rare", "companion preferences persist only in machine settings")
	_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), save_bytes, "companion preferences leave progression bytes unchanged")
	session.desktop_companion.load_settings({})
	session.call("_load_machine_settings")
	_expect_eq(session.desktop_companion.settings(), {"desktop_quiet":true, "desktop_do_not_disturb":true, "desktop_behavior_frequency":"rare"}, "companion settings restore independently of progress")
	_expect_true(not session.set_desktop_companion_settings(false, false, "unknown"), "invalid frequency is rejected by the facade")
	var settings_before: Dictionary = session.desktop_companion.settings()
	var blocked_path: String = session.save_service.settings_path + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	_expect_true(not session.set_desktop_companion_settings(false, false, "frequent"), "failed machine save reports failure")
	_expect_eq(session.desktop_companion.settings(), settings_before, "failed companion preference save rolls back every setting")
	session.start_focus_timer()
	session.toggle_focus_timer_pause()
	session.toggle_focus_timer_pause()
	_expect_eq(session.pig_state.to_dict(), pig_before, "focus timer commands award nothing and do not mutate residents")
	_expect_eq(session.simulation.to_dict(), simulation_before, "focus timer commands do not reset the simulation")
	var now: int = session.clock.current_unix()
	session.set("_last_process_unix", now)
	session.call("_advance_runtime_frame", 1.0, now + 1)
	_expect_eq(int(session.desktop_companion.timer_remaining), 1499, "accepted runtime delta advances focus exactly once")
	session.call("_advance_runtime_frame", 3600.0, now + 3601)
	_expect_eq(int(session.desktop_companion.timer_remaining), 1499, "sleep/wake settlement never mistakes suspension for focused work")
	session.stop_focus_timer()
	_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path) == save_bytes, false, "normal resume settlement still persists legitimate offline progress")
	var restored := DesktopCompanionPolicy.new()
	restored.load_settings(session.save_service.load_settings())
	_expect_eq(restored.timer_phase, "idle", "restarting the game does not restore timer or work history")
	session.free()
	_remove_tree(ProjectSettings.globalize_path(base))


func _test_release_configuration() -> void:
	_expect_true(FileAccess.file_exists("res://export_presets.cfg"), "Windows export preset exists")
	var preset: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect_true('platform="Windows Desktop"' in preset, "Windows Desktop export platform is configured")
	_expect_true('binary_format/architecture="x86_64"' in preset, "Windows export is x86_64")
	_expect_true('name="Windows x64 Demo"' in preset and 'custom_features="demo"' in preset, "Windows demo export preset enables the demo profile")
	_expect_true('PiggyDidNothingTodayDemo.exe' in preset, "Windows demo has a distinct export artifact")
	var product_icon: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	_expect_true(not product_icon.is_empty() and preset.count('application/icon="%s"' % product_icon) == 2, "both Windows exports use the currently active product icon")
	_expect_true("assest/**" in preset and "start.tscn" in preset, "legacy assets and scenes are excluded from release")
	_expect_true("build/**" in preset, "validation captures and previous builds are excluded from release")
	var internal_release_docs_excluded: bool = true
	for path: String in ["docs/release/build-and-release.md", "docs/release/candidate-manifest.json", "docs/release/steam-store-copy.md", "docs/release/support-and-known-issues.md", "docs/release/windows-test-matrix.md"]:
		internal_release_docs_excluded = internal_release_docs_excluded and path in preset
	_expect_true(internal_release_docs_excluded, "internal release identity, build, support, store, and Windows documents are excluded")
	var project_config: String = FileAccess.get_file_as_string("res://project.godot")
	_expect_true('file_logging/enable_file_logging=true' in project_config, "local rolling runtime logging is enabled")
	_expect_true('file_logging/max_log_files=5' in project_config, "local runtime log retention is capped")
	_expect_true(FileAccess.file_exists("res://game/data/catalog/final_asset_manifest.json"), "dedicated creative asset manifest exists")
	var asset_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/catalog/final_asset_manifest.json")) as Dictionary
	_expect_true(asset_manifest.has("ready") and asset_manifest.has("provided_by_user") and asset_manifest.has("entries"), "creative asset readiness is explicit and machine-checkable")


func _expect_true(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		var child: String = path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
