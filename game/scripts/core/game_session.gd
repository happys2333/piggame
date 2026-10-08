extends Node

signal ready_for_ui
signal state_changed
signal behavior_changed(behavior: Dictionary)
signal toast_requested(text_key: String, values: Dictionary)
signal offline_summary_ready(summary: Dictionary)
signal event_queued(event_id: String)
signal memory_queue_changed
signal event_photo_recorded(event_id: String)
signal ending_ready
signal demo_complete_ready
signal mode_changed(desktop_mode: bool)
signal save_recovered(source: String)
signal save_failed(message: String)
signal demo_progress_imported
signal life_plan_changed
signal companions_changed
signal exit_checkpoint_failed(result: Dictionary)
signal desktop_companion_changed
signal focus_timer_changed
signal focus_break_ready
signal pig_performance_changed

const EVENT_CHECK_SECONDS: float = 75.0
const AUTOSAVE_SECONDS: float = 60.0
const EXPRESSION_UNLOCK_POINTS: int = 10
const ROOM_SLOTS := {
	"sleep_1": "large", "sleep_2": "small", "sleep_3": "small", "sleep_4": "wall",
	"snack_1": "large", "snack_2": "large", "snack_3": "small", "snack_4": "small",
	"activity_1": "large", "activity_2": "large", "activity_3": "small", "activity_4": "small",
	"window_1": "large", "window_2": "small", "window_3": "small", "window_4": "wall",
}
const ROOM_PALETTES: Array[String] = ["rose", "mint", "night"]
const PHOTO_FRAMES: Array[String] = ["plain", "berry", "star"]
const SUPPORTED_LOCALES: Array[String] = ["zh_CN", "zh_TW", "en"]
const MAIN_WINDOW_MIN_SIZE := Vector2i(960, 540)
const MAIN_WINDOW_TITLE_REGION_HEIGHT: int = 48
const MAIN_WINDOW_ACCESSIBLE_TITLE_SIZE := Vector2i(160, 32)

var catalog := ContentCatalog.new()
var final_assets := FinalAssetCatalog.new()
var pig_state := PigState.new()
var clock := GameClock.new()
var behavior_director := BehaviorDirector.new()
var event_director := EventDirector.new()
var simulation := Simulation.new()
var save_service := SaveService.new(ReleaseProfile.save_base_dir())
var desktop_companion := DesktopCompanionPolicy.new()
var pig_performance := PigPerformance.new()
var desktop_mode: bool = false
var focus_mode: bool = false
var ui_scale: float = 1.0
var reduce_motion: bool = false
var camera_shake_enabled: bool = true
var reduce_desktop_roaming: bool = false
var reduce_desktop_action_frequency: bool = false
var bubble_duration_scale: float = 1.0
var locale: String = "zh_CN"
var main_window_fullscreen: bool = false
var main_window_size: Vector2i = Vector2i(1280, 720)
var main_window_position: Vector2i = Vector2i(-1, -1)
var last_offline_summary: Dictionary = {}
var last_recovery_source: String = ""
var last_save_error: String = ""
var demo_save_imported: bool = false
var loaded_successfully: bool = false
var save_recovery_required: bool = false
var _autosave_elapsed: float = 0.0
var _event_elapsed: float = 0.0
var _last_saved_unix: int = 0
var _last_process_unix: int = 0
var _important_save_pending: bool = false
var _important_save_scheduled: bool = false
var _progression_commit_in_progress: bool = false
var _life_plan_ui_elapsed: float = 0.0
var _life_plan_checkpoint_retry: float = 0.0
var active_companion_id: String = CompanionRules.IDS[0]
var _companions: Dictionary = {}
var _personality_rng := RandomNumberGenerator.new()
var _performance_rng := RandomNumberGenerator.new()


func _init() -> void:
	_personality_rng.randomize()
	_performance_rng.randomize()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var errors: Array[String] = catalog.load_all()
	errors.append_array(final_assets.load_manifest())
	for error: String in errors:
		push_error("Content validation: %s" % error)
	if ReleaseProfile.is_demo():
		catalog.apply_demo_profile()
	save_service.configure_content_ids(catalog, ROOM_SLOTS)
	loaded_successfully = errors.is_empty()
	_connect_modules()
	_load_machine_settings()
	desktop_companion.changed.connect(func() -> void: desktop_companion_changed.emit())
	desktop_companion.timer_changed.connect(func() -> void: focus_timer_changed.emit())
	desktop_companion.break_ready.connect(func() -> void: focus_break_ready.emit())
	pig_performance.changed.connect(func() -> void: pig_performance_changed.emit())
	get_window().focus_entered.connect(_on_application_focus_entered)
	get_window().focus_exited.connect(_on_application_focus_exited)
	desktop_companion.set_application_focused(get_window().has_focus())
	_load_or_create_game()
	_last_process_unix = clock.current_unix()
	call_deferred("_sync_steam_state")
	ready_for_ui.emit()


func _process(delta: float) -> void:
	if not loaded_successfully or save_recovery_required or get_tree().paused:
		return
	_advance_runtime_frame(delta, clock.current_unix())


func _advance_runtime_frame(delta: float, now: int) -> void:
	var frame_delta: float = maxf(delta, 0.0)
	if runtime_gap_requires_settlement(_last_process_unix, now):
		handle_runtime_resume(_last_process_unix, now)
		pig_performance.stop(true)
		frame_delta = 0.0
	_last_process_unix = now
	_life_plan_checkpoint_retry = maxf(_life_plan_checkpoint_retry - frame_delta, 0.0)
	if frame_delta > 0.0:
		desktop_companion.advance(frame_delta)
		pig_performance.advance(frame_delta, catalog.performances, pig_state.current_outfit, desktop_companion.proactive_allowed() and not focus_mode and desktop_companion.timer_phase == "idle", performance_frequency(), _performance_rng, performance_motion_allowed())
		_advance_life_plan(frame_delta)
		simulation.advance(frame_delta, pig_state, catalog.behaviors, behavior_director, now, desktop_mode, focus_mode)
	_autosave_elapsed += frame_delta
	_event_elapsed += frame_delta
	if _event_elapsed >= EVENT_CHECK_SECONDS:
		_event_elapsed = 0.0
		_try_discover_event(now)
	if _autosave_elapsed >= AUTOSAVE_SECONDS:
		save_game()


static func runtime_gap_requires_settlement(previous_unix: int, current_unix: int) -> bool:
	if previous_unix <= 0:
		return false
	var elapsed: int = current_unix - previous_unix
	return elapsed < 0 or elapsed >= 15


static func main_window_has_accessible_title_region(window_rect: Rect2i, usable_rects: Array[Rect2i]) -> bool:
	if window_rect.size.x <= 0 or window_rect.size.y <= 0:
		return false
	var title_region := Rect2i(
		window_rect.position,
		Vector2i(window_rect.size.x, mini(window_rect.size.y, MAIN_WINDOW_TITLE_REGION_HEIGHT))
	)
	var required_size := Vector2i(
		mini(title_region.size.x, MAIN_WINDOW_ACCESSIBLE_TITLE_SIZE.x),
		mini(title_region.size.y, MAIN_WINDOW_ACCESSIBLE_TITLE_SIZE.y)
	)
	for usable: Rect2i in usable_rects:
		var overlap: Rect2i = usable.intersection(title_region)
		if overlap.size.x >= required_size.x and overlap.size.y >= required_size.y:
			return true
	return false


func _current_local_date() -> String:
	return GameClock.local_date_string(clock.current_unix())


func pet_pig() -> Dictionary:
	return interact_with_pig("pet")


func poke_pig() -> Dictionary:
	return interact_with_pig("poke")


func interact_with_pig(kind: String) -> Dictionary:
	note_explicit_companion_interaction()
	pig_performance.stop()
	var interaction_kind: String = kind if kind in ["pet", "poke"] else "pet"
	var reaction: Dictionary = {
		"kind": interaction_kind,
		"category": "wronged" if interaction_kind == "poke" else "happy",
		"expression_id": "expr_wronged_poke" if interaction_kind == "poke" else "expr_happy_soft",
		"toast_key": "TOAST_POKE" if interaction_kind == "poke" else "TOAST_PET",
	}
	var personality: Dictionary = catalog.get_item("personalities", pig_state.personality_id)
	if not personality.is_empty():
		reaction.merge(personality[interaction_kind] as Dictionary, true)
	var mutation := func() -> void:
		var count: int = pig_state.record_daily_interaction("pet", _current_local_date())
		pig_state.interest = minf(pig_state.interest + 3.0, 100.0)
		if count == 1:
			pig_state.add_points(2)
			pig_state.add_familiarity(2)
		_unlock_interaction_expressions(interaction_kind)
		_advance_tutorial(1)
	if not _commit_pig_state_transaction(
		mutation,
		true,
		"pet",
		str(reaction.toast_key),
		{"name": pig_display_name()}
	):
		return {}
	return reaction


func feed(snack_id: String) -> bool:
	var snack: Dictionary = catalog.get_item("snacks", snack_id)
	if snack.is_empty() or pig_state.familiarity_level < int(snack.get("min_level", 1)):
		return false
	var price: int = int(snack.get("price", 0))
	if price < 0 or pig_state.daily_points < price:
		return false
	var mutation := func() -> void:
		pig_state.spend_points(price)
		if not snack_id in pig_state.owned_snacks:
			pig_state.owned_snacks.append(snack_id)
		pig_state.satiety = minf(pig_state.satiety + float(snack.get("satiety", 12)), 100.0)
		pig_state.interest = minf(pig_state.interest + float(snack.get("interest", 4)), 100.0)
		var count: int = pig_state.record_daily_interaction("feed", _current_local_date())
		if count == 1:
			pig_state.add_points(3)
			pig_state.add_familiarity(3)
		_unlock_interaction_expressions("feed")
		_advance_tutorial(2)
	return _commit_pig_state_transaction(
		mutation,
		true,
		"feed",
		str(snack.get("reaction_key", "TOAST_FEED")),
		{"name": pig_display_name()}
	)


func purchase(type: String, id: String) -> bool:
	var catalog_type: String = type
	var unlock_type: String = type.trim_suffix("s")
	if type == "snacks": unlock_type = "snack"
	if type == "outfits": unlock_type = "outfit"
	var item: Dictionary = catalog.get_item(catalog_type, id)
	if (
		item.is_empty()
		or unlock_type not in ["furniture", "snack", "outfit"]
		or pig_state.familiarity_level < int(item.get("min_level", 1))
	):
		return false
	if type == "furniture" and not is_room_area_unlocked(str(item.get("area", ""))):
		return false
	var already_owned: bool = (
		(unlock_type == "furniture" and id in pig_state.owned_furniture)
		or (unlock_type == "snack" and id in pig_state.owned_snacks)
		or (unlock_type == "outfit" and id in pig_state.owned_outfits)
	)
	var price: int = int(item.get("price", 0))
	if already_owned or price < 0 or pig_state.daily_points < price:
		return false
	var mutation := func() -> void:
		pig_state.spend_points(price)
		pig_state.unlock(unlock_type, id, clock.current_unix())
		_advance_tutorial(3)
	return _commit_pig_state_transaction(
		mutation,
		true,
		"purchase",
		"TOAST_PURCHASED",
		{"item": tr(str(item.get("name_key", "")))}
	)


func place_furniture(slot_id: String, furniture_id: String) -> bool:
	var item: Dictionary = catalog.get_item("furniture", furniture_id)
	if item.is_empty() or not furniture_id in pig_state.owned_furniture:
		return false
	if not is_room_area_unlocked(str(item.get("area", ""))):
		return false
	if not ROOM_SLOTS.has(slot_id) or not slot_id.begins_with(str(item.get("area", ""))):
		return false
	if str(ROOM_SLOTS[slot_id]) != str(item.get("slot", "")):
		return false
	var mutation := func() -> void:
		for occupied_slot: String in pig_state.placed_furniture.keys():
			if occupied_slot != slot_id and str(pig_state.placed_furniture[occupied_slot]) == furniture_id:
				pig_state.placed_furniture.erase(occupied_slot)
		pig_state.placed_furniture[slot_id] = furniture_id
	return _commit_pig_state_transaction(mutation, false)


func can_invite_to_furniture(furniture_id: String) -> bool:
	if not furniture_id in pig_state.placed_furniture.values():
		return false
	var furniture: Dictionary = catalog.get_item("furniture", furniture_id)
	var behavior_id: String = str(furniture.get("behavior_id", ""))
	var behavior: Dictionary = catalog.get_item("behaviors", behavior_id)
	if behavior.is_empty() or str(simulation.current_behavior.get("id", "")) == behavior_id:
		return false
	return clock.current_unix() >= int(behavior_director.cooldown_until.get(behavior_id, 0))


func invite_to_furniture(furniture_id: String) -> bool:
	note_explicit_companion_interaction()
	if not can_invite_to_furniture(furniture_id):
		return false
	var furniture: Dictionary = catalog.get_item("furniture", furniture_id)
	var behavior: Dictionary = catalog.get_item("behaviors", str(furniture.get("behavior_id", "")))
	var state_before: Dictionary = pig_state.to_dict().duplicate(true)
	var simulation_before: Dictionary = simulation.to_dict().duplicate(true)
	var saved_unix_before: int = _last_saved_unix
	var important_save_before: bool = _important_save_pending
	_progression_commit_in_progress = true
	if not simulation.invite_behavior(behavior, false):
		_progression_commit_in_progress = false
		return false
	pig_state.interest = minf(pig_state.interest + 1.0, 100.0)
	pig_state.normalize()
	if save_game() != OK:
		pig_state.load_dict(state_before)
		simulation.load_dict(simulation_before, catalog)
		_last_saved_unix = saved_unix_before
		_important_save_pending = important_save_before
		_progression_commit_in_progress = false
		state_changed.emit()
		return false
	_progression_commit_in_progress = false
	simulation.announce_current_behavior()
	toast_requested.emit("TOAST_FURNITURE_INVITED", {"item": tr(str(furniture.get("name_key", "")))})
	state_changed.emit()
	return true


func react_to_furniture(furniture_id: String) -> bool:
	note_explicit_companion_interaction()
	if not furniture_id in pig_state.placed_furniture.values():
		return false
	var furniture: Dictionary = catalog.get_item("furniture", furniture_id)
	var reaction_key: String = str(furniture.get("reaction_key", ""))
	if furniture.is_empty() or reaction_key.is_empty():
		return false
	toast_requested.emit(reaction_key, {
		"name": pig_display_name(),
		"item": tr(str(furniture.get("name_key", ""))),
	})
	return true


func compatible_furniture_slots(furniture_id: String) -> Array[String]:
	var item: Dictionary = catalog.get_item("furniture", furniture_id)
	var result: Array[String] = []
	if item.is_empty() or not is_room_area_unlocked(str(item.get("area", ""))):
		return result
	for slot_id: String in ROOM_SLOTS:
		if slot_id.begins_with(str(item.get("area", ""))) and str(ROOM_SLOTS[slot_id]) == str(item.get("slot", "")):
			result.append(slot_id)
	return result


func is_room_area_unlocked(area_id: String) -> bool:
	var unlock_level: int = ReleaseProfile.area_unlock_level(area_id)
	return (
		unlock_level > 0
		and ReleaseProfile.area_available(area_id)
		and pig_state.familiarity_level >= unlock_level
	)


func unlocked_room_palettes() -> Array[String]:
	var result: Array[String] = ["rose"]
	if pig_state.familiarity_level >= 7:
		result.append("mint")
	if pig_state.unlocked_expressions.size() >= 36:
		result.append("night")
	return result


func set_room_palette(palette_id: String) -> bool:
	if not palette_id in ROOM_PALETTES or not palette_id in unlocked_room_palettes():
		return false
	var mutation := func() -> void:
		pig_state.current_room_palette = palette_id
	return _commit_pig_state_transaction(mutation, false)


func unlocked_photo_frames() -> Array[String]:
	var result: Array[String] = ["plain"]
	if pig_state.unlocked_expressions.size() >= 16:
		result.append("berry")
	if pig_state.unlocked_expressions.size() >= 48:
		result.append("star")
	return result


func set_photo_frame(frame_id: String) -> bool:
	if frame_id not in PHOTO_FRAMES or frame_id not in unlocked_photo_frames():
		return false
	var mutation := func() -> void:
		pig_state.current_photo_frame = frame_id
	return _commit_pig_state_transaction(mutation, false)


func equip_outfit(outfit_id: String) -> bool:
	if not outfit_id.is_empty() and not outfit_id in pig_state.owned_outfits:
		return false
	var mutation := func() -> void:
		pig_state.current_outfit = outfit_id
	var success: bool = _commit_pig_state_transaction(mutation, true)
	if success:
		pig_performance.stop()
	return success


func perform_pig(id: String) -> bool:
	if save_recovery_required or _progression_commit_in_progress:
		return false
	var entry: Dictionary = catalog.performances.item(id)
	if entry.is_empty() or catalog.performances.kind_for(id) == "clips":
		return false
	if catalog.performances.kind_for(id) == "outfit_actions" and str(entry.outfit_id) != pig_state.current_outfit:
		return false
	note_explicit_companion_interaction()
	if not pig_performance.start(id, catalog.performances, pig_state.current_outfit):
		return false
	if entry.has("line_key"):
		toast_requested.emit(str(entry.line_key), {"name":pig_state.name if not pig_state.name.is_empty() else tr("NAME_DEFAULT")})
	return true


func stop_pig_performance() -> void:
	note_explicit_companion_interaction()
	pig_performance.stop(true)


func performance_motion_allowed() -> bool:
	return desktop_companion.proactive_allowed() or (pig_performance.manual and desktop_companion.message_allowed())


func performance_frequency() -> String:
	return "rare" if reduce_desktop_action_frequency and desktop_companion.frequency != "off" else desktop_companion.frequency


func _commit_pig_state_transaction(
	mutation: Callable,
	evaluate_achievements: bool,
	sfx_id: String = "",
	toast_key: String = "",
	toast_values: Dictionary = {},
	notify_state: bool = true
) -> bool:
	var state_before: Dictionary = pig_state.to_dict().duplicate(true)
	var saved_unix_before: int = _last_saved_unix
	var important_save_before: bool = _important_save_pending
	var level_before: int = pig_state.familiarity_level
	_progression_commit_in_progress = true
	mutation.call()
	var evaluated_achievements: Array[String] = []
	if evaluate_achievements:
		evaluated_achievements = _evaluate_achievements(false)
	if save_game() != OK:
		pig_state.load_dict(state_before)
		_last_saved_unix = saved_unix_before
		_important_save_pending = important_save_before
		_progression_commit_in_progress = false
		if notify_state:
			state_changed.emit()
		return false
	_progression_commit_in_progress = false
	if not sfx_id.is_empty():
		_play_sfx(sfx_id)
	if pig_state.familiarity_level > level_before:
		_play_sfx("level_up")
		toast_requested.emit("TOAST_LEVEL_UP", {"level": pig_state.familiarity_level})
	if evaluate_achievements:
		_sync_committed_achievements(evaluated_achievements)
	if not toast_key.is_empty():
		toast_requested.emit(toast_key, toast_values)
	if notify_state:
		state_changed.emit()
	return true


func set_favorite_desktop_expression(expression_id: String) -> bool:
	if not expression_id in pig_state.unlocked_expressions or not catalog.has_item("expressions", expression_id):
		return false
	var mutation := func() -> void:
		pig_state.favorite_desktop_expression = expression_id
	return _commit_pig_state_transaction(mutation, false)


func set_tendency(value: String) -> bool:
	if pig_state.familiarity_level < 5 or not value in ["rest", "food", "active", "explore"]:
		return false
	var mutation := func() -> void:
		pig_state.tendency = value
		_advance_tutorial(6)
	return _commit_pig_state_transaction(mutation, false)


func select_life_plan(plan_id: String) -> bool:
	var plan: Dictionary = catalog.get_item("life_plans", plan_id)
	if plan.is_empty() or save_recovery_required or pig_state.familiarity_level < int(plan.min_level) or LifePlanRules.is_complete(plan, pig_state) or pig_state.active_life_plan == plan_id:
		return false
	var mutation := func() -> void:
		pig_state.active_life_plan = plan_id
	if not _commit_pig_state_transaction(mutation, false):
		return false
	life_plan_changed.emit()
	return true


func pause_life_plan() -> bool:
	if pig_state.active_life_plan.is_empty() or save_recovery_required:
		return false
	var mutation := func() -> void:
		pig_state.active_life_plan = ""
	if not _commit_pig_state_transaction(mutation, false):
		return false
	life_plan_changed.emit()
	return true


func life_plan_snapshot(plan_id: String) -> Dictionary:
	var plan: Dictionary = catalog.get_item("life_plans", plan_id)
	if plan.is_empty():
		return {}
	return {
		"id":plan_id,
		"active":pig_state.active_life_plan == plan_id,
		"unlocked":pig_state.familiarity_level >= int(plan.min_level),
		"progress":float(pig_state.life_plan_progress.get(plan_id, 0.0)),
		"maximum":LifePlanRules.maximum_seconds(plan),
		"earned":LifePlanRules.earned_entries(plan, pig_state),
		"complete":LifePlanRules.is_complete(plan, pig_state),
		"room_rate":LifePlanRules.room_rate(plan, pig_state),
		"entries":pig_state.life_plan_entries.duplicate(),
	}


func _advance_life_plan(seconds: float, checkpoint_entries: bool = true, use_room_rate: bool = true) -> Dictionary:
	if save_recovery_required or pig_state.active_life_plan.is_empty():
		return {}
	var plan: Dictionary = catalog.get_item("life_plans", pig_state.active_life_plan)
	var update: Dictionary = LifePlanRules.preview_advance(plan, pig_state, seconds, use_room_rate)
	if update.is_empty():
		return {}
	var has_entries: bool = not (update.new_entries as Array).is_empty()
	var mutation := func() -> void:
		LifePlanRules.apply_advance(update, pig_state)
	if has_entries and checkpoint_entries:
		if _life_plan_checkpoint_retry > 0.0:
			pig_state.life_plan_progress[str(update.id)] = float(update.progress)
			update["new_entries"] = []
		elif not _commit_pig_state_transaction(mutation, false, "", "", {}, false):
			_life_plan_checkpoint_retry = 5.0
			return {}
	else:
		mutation.call()
	_life_plan_ui_elapsed += seconds
	if has_entries or _life_plan_ui_elapsed >= 1.0:
		_life_plan_ui_elapsed = 0.0
		life_plan_changed.emit()
	return update


func prepare_event(event_id: String) -> Dictionary:
	var event: Dictionary = catalog.get_item("events", event_id)
	if event.is_empty():
		return {}
	var prepared: Dictionary = event.duplicate(true)
	var branch: Dictionary = event_director.resolve_branch(event, pig_state)
	prepared["variants"] = (branch.get("variant_keys", event.get("variants", [])) as Array).duplicate()
	prepared["resolved_branch_id"] = str(branch.get("id", "default"))
	return prepared


func complete_event_with_photo(event_id: String, image: Image, branch_id: String = "") -> Dictionary:
	var event: Dictionary = catalog.get_item("events", event_id)
	if (
		image == null
		or image.is_empty()
		or event.is_empty()
		or not event_id in pig_state.discovered_events
		or (not event_id in pig_state.pending_events and not event_id in pig_state.summarized_events)
	):
		return {}
	var photo_path: String = _event_photo_path(event)
	var previous_photo: Dictionary = _snapshot_file(photo_path)
	var photo_result: Dictionary = _write_event_photo(event, image)
	if photo_result.get("error", FAILED) != OK:
		return {}
	return _commit_watched_event(event, branch_id, str(photo_result.get("path", "")), previous_photo)


func _commit_watched_event(
	event: Dictionary,
	branch_id: String,
	photo_path: String = "",
	previous_photo: Dictionary = {}
) -> Dictionary:
	var state_before: Dictionary = pig_state.to_dict().duplicate(true)
	var director_before: Dictionary = event_director.to_dict().duplicate(true)
	var saved_unix_before: int = _last_saved_unix
	var important_save_before: bool = _important_save_pending
	var level_before: int = pig_state.familiarity_level
	var ending_before: bool = pig_state.ending_unlocked
	_progression_commit_in_progress = true
	if not photo_path.is_empty():
		_record_event_photo(str(event.get("id", "")), event, photo_path, false)
	var result: Dictionary = event_director.mark_watched(event, pig_state, clock.current_unix(), branch_id)
	_sync_ending_state(false)
	var evaluated_achievements: Array[String] = _evaluate_achievements(false)
	var save_error: Error = save_game()
	result["save_error"] = save_error
	if save_error != OK:
		pig_state.load_dict(state_before)
		event_director.load_dict(director_before)
		_last_saved_unix = saved_unix_before
		_important_save_pending = important_save_before
		if not photo_path.is_empty():
			result["photo_rollback_error"] = _restore_file(photo_path, previous_photo)
		_progression_commit_in_progress = false
		memory_queue_changed.emit()
		state_changed.emit()
		return result
	_progression_commit_in_progress = false
	if not photo_path.is_empty():
		_announce_event_photo(str(event.get("id", "")))
	_play_sfx("event")
	if pig_state.familiarity_level > level_before:
		_play_sfx("level_up")
		toast_requested.emit("TOAST_LEVEL_UP", {"level": pig_state.familiarity_level})
	_sync_committed_event_achievements(result.get("achievements", []), evaluated_achievements)
	if not ending_before and pig_state.ending_unlocked:
		ending_ready.emit()
	_sync_demo_state(true)
	memory_queue_changed.emit()
	state_changed.emit()
	return result


func record_event_photo(event_id: String, path: String) -> bool:
	var event: Dictionary = catalog.get_item("events", event_id)
	if event.is_empty() or not event_id in pig_state.discovered_events:
		return false
	var expected_path: String = _event_photo_path(event)
	if path != expected_path or not FileAccess.file_exists(expected_path):
		return false
	var state_before: Dictionary = pig_state.to_dict().duplicate(true)
	_record_event_photo(event_id, event, path, false)
	if save_game() != OK:
		pig_state.load_dict(state_before)
		state_changed.emit()
		return false
	_announce_event_photo(event_id)
	state_changed.emit()
	return true


func _record_event_photo(event_id: String, event: Dictionary, path: String, announce: bool = true) -> void:
	pig_state.life_photos[event_id] = {
		"photo_id": str(event.get("photo_id", event_id)),
		"path": path,
		"captured_unix": clock.current_unix(),
	}
	if announce:
		_announce_event_photo(event_id)


func _announce_event_photo(event_id: String) -> void:
	_play_sfx("camera")
	event_photo_recorded.emit(event_id)


func store_event_photo(event_id: String, image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var event: Dictionary = catalog.get_item("events", event_id)
	if event.is_empty():
		return false
	var photo_path: String = _event_photo_path(event)
	var previous_photo: Dictionary = _snapshot_file(photo_path)
	var result: Dictionary = _write_event_photo(event, image)
	if result.get("error", FAILED) != OK:
		return false
	if record_event_photo(event_id, str(result.get("path", ""))):
		return true
	_restore_file(photo_path, previous_photo)
	return false


func _write_event_photo(event: Dictionary, image: Image) -> Dictionary:
	var directory: String = CompanionRules.photo_base_dir(save_service.base_dir, active_companion_id) + "/photos"
	if FileAccess.file_exists(save_service.base_dir):
		return {"error": ERR_CANT_CREATE, "path": ""}
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK:
		return {"error": directory_error, "path": ""}
	var path: String = _event_photo_path(event)
	var error: Error = image.save_png(path)
	return {"error": error, "path": path if error == OK else ""}


func _event_photo_path(event: Dictionary) -> String:
	return "%s/photos/%s.png" % [CompanionRules.photo_base_dir(save_service.base_dir, active_companion_id), str(event.get("photo_id", event.get("id", "event")))]


func event_photo_path(event_id: String) -> String:
	var event: Dictionary = catalog.get_item("events", event_id)
	var record_value: Variant = pig_state.life_photos.get(event_id, null)
	if event.is_empty() or not record_value is Dictionary:
		return ""
	var record: Dictionary = record_value as Dictionary
	var expected_photo_id: String = str(event.get("photo_id", event_id))
	var expected_path: String = _event_photo_path(event)
	if str(record.get("photo_id", "")) != expected_photo_id or str(record.get("path", "")) != expected_path:
		return ""
	return expected_path if FileAccess.file_exists(expected_path) else ""


static func _snapshot_file(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	return {
		"exists": exists,
		"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
	}


static func _restore_file(path: String, snapshot: Dictionary) -> Error:
	if not bool(snapshot.get("exists", false)):
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else OK
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(snapshot.get("bytes", PackedByteArray()) as PackedByteArray)
	file.close()
	return OK


func export_event_photo(event_id: String) -> String:
	var event: Dictionary = catalog.get_item("events", event_id)
	var source: String = event_photo_path(event_id)
	if event.is_empty() or source.is_empty():
		return ""
	var directory: String = save_service.base_dir + "/exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var destination: String = "%s/%s.png" % [directory, str(event.get("photo_id", event_id))]
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
	return ProjectSettings.globalize_path(destination) if error == OK else ""


func mark_ending_seen() -> bool:
	if not pig_state.ending_unlocked:
		return false
	var mutation := func() -> void:
		pig_state.ending_seen = true
	return _commit_pig_state_transaction(mutation, false)


func mark_demo_completion_seen(for_profile: String = "") -> bool:
	if not should_show_demo_complete(for_profile):
		return false
	var mutation := func() -> void:
		pig_state.demo_completion_seen = true
	return _commit_pig_state_transaction(mutation, false)


func set_pig_name(value: String) -> bool:
	var cleaned: String = CompanionRules.clean_name(value)
	if cleaned.is_empty():
		return false
	var mutation := func() -> void:
		pig_state.name = cleaned
		_advance_tutorial(0)
	return _commit_pig_state_transaction(mutation, false)


func initialize_current_companion(value: String, personality_choice: String = PersonalityRules.RANDOM_CHOICE, skip_intro: bool = false) -> bool:
	if not pig_state.personality_id.is_empty() or save_recovery_required or _progression_commit_in_progress:
		return false
	var cleaned: String = CompanionRules.clean_name(value)
	if cleaned.is_empty() and (not skip_intro or not value.strip_edges().is_empty()):
		return false
	var selected: String = PersonalityRules.resolve_choice(personality_choice, catalog.personalities, _personality_rng)
	if selected.is_empty():
		return false
	note_explicit_companion_interaction()
	var mutation := func() -> void:
		pig_state.personality_id = selected
		pig_state.name = cleaned
		if skip_intro:
			pig_state.tutorial_skipped = true
		elif not cleaned.is_empty():
			_advance_tutorial(0)
	return _commit_pig_state_transaction(mutation, false)


func choose_initial_personality(choice: String) -> bool:
	if not pig_state.personality_id.is_empty() or save_recovery_required or _progression_commit_in_progress:
		return false
	var selected: String = PersonalityRules.resolve_choice(choice, catalog.personalities, _personality_rng)
	if selected.is_empty():
		return false
	note_explicit_companion_interaction()
	var mutation := func() -> void: pig_state.personality_id = selected
	return _commit_pig_state_transaction(mutation, false)


func personality_choices() -> Array[Dictionary]:
	return catalog.personalities.duplicate(true)


func companion_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in CompanionRules.IDS:
		if id != active_companion_id and not _companions.has(id):
			continue
		var pig: Dictionary = pig_state.to_dict() if id == active_companion_id else (_companions[id] as Dictionary).pig_state as Dictionary
		result.append({"id":id, "name":str(pig.get("name", "")), "personality_id":str(pig.get("personality_id", "")), "active":id == active_companion_id, "level":int(pig.get("familiarity_level", 1)), "points":int(pig.get("daily_points", 0)), "notes":(pig.get("life_plan_entries", []) as Array).size()})
	return result


func add_companion(value: String, personality_choice: String = PersonalityRules.RANDOM_CHOICE) -> bool:
	var cleaned: String = CompanionRules.clean_name(value)
	if cleaned.is_empty() or save_recovery_required or desktop_mode or _progression_commit_in_progress:
		return false
	var id: String = ""
	for candidate: String in CompanionRules.IDS:
		if candidate != active_companion_id and not _companions.has(candidate):
			id = candidate
			break
	if id.is_empty():
		return false
	var selected: String = PersonalityRules.resolve_choice(personality_choice, catalog.personalities, _personality_rng)
	if selected.is_empty():
		return false
	var previous: Dictionary = _companions.duplicate(true)
	var newcomer := PigState.new()
	newcomer.name = cleaned
	newcomer.personality_id = selected
	newcomer.tutorial_skipped = true
	_companions[id] = {"pig_state":newcomer.to_dict(), "behavior_director":BehaviorDirector.new().to_dict(), "event_director":EventDirector.new().to_dict(), "simulation":Simulation.new().to_dict(), "last_saved_unix":clock.current_unix()}
	if save_game() != OK:
		_companions = previous
		return false
	companions_changed.emit()
	return true


func switch_companion(id: String) -> bool:
	if id == active_companion_id or not _companions.has(id) or save_recovery_required or desktop_mode or _progression_commit_in_progress:
		return false
	note_explicit_companion_interaction()
	var now: int = clock.current_unix()
	var previous_state: Dictionary = _companion_snapshot(_last_saved_unix)
	var previous_roster: Dictionary = _companions.duplicate(true)
	var previous_id: String = active_companion_id
	_progression_commit_in_progress = true
	if runtime_gap_requires_settlement(_last_process_unix, now):
		_settle_companion_until(_last_process_unix, now)
	_companions[active_companion_id] = _companion_snapshot(now)
	var target: Dictionary = (_companions[id] as Dictionary).duplicate(true)
	active_companion_id = id
	_apply_companion_snapshot(target)
	var settlement: Dictionary = _settle_companion_until(int(target.last_saved_unix), now)
	if save_game() != OK:
		active_companion_id = previous_id
		_companions = previous_roster
		_apply_companion_snapshot(previous_state)
		_progression_commit_in_progress = false
		return false
	_progression_commit_in_progress = false
	_last_process_unix = now
	_event_elapsed = 0.0
	_life_plan_ui_elapsed = 0.0
	_life_plan_checkpoint_retry = 0.0
	last_offline_summary = settlement if int(settlement.elapsed_seconds) >= 60 else {}
	pig_performance.stop(true)
	simulation.announce_current_behavior()
	state_changed.emit()
	life_plan_changed.emit()
	memory_queue_changed.emit()
	companions_changed.emit()
	_sync_steam_state()
	return true


func _settle_companion_until(previous_unix: int, now: int) -> Dictionary:
	var settlement: Dictionary = clock.settle(previous_unix, now)
	if bool(settlement.clock_went_backwards):
		behavior_director.discard_future_timestamps(now)
		event_director.discard_future_timestamps(now)
	simulation.apply_offline(pig_state, settlement)
	var plan: Dictionary = catalog.get_item("life_plans", pig_state.active_life_plan)
	var update: Dictionary = LifePlanRules.preview_advance(plan, pig_state, float(settlement.elapsed_seconds))
	LifePlanRules.apply_advance(update, pig_state)
	if not update.is_empty() and not (update.new_entries as Array).is_empty():
		settlement["life_plan_entries"] = (update.new_entries as Array).duplicate()
	for sample_unix: int in offline_event_sample_times(settlement, now):
		event_director.discover_one(catalog.events, pig_state, sample_unix, false, false)
	_sync_ending_state(false)
	return settlement


func _companion_snapshot(unix_time: int) -> Dictionary:
	return {"pig_state":pig_state.to_dict(), "behavior_director":behavior_director.to_dict(), "event_director":event_director.to_dict(), "simulation":simulation.to_dict(), "last_saved_unix":maxi(unix_time, 0)}.duplicate(true)


func _apply_companion_snapshot(snapshot: Dictionary) -> void:
	pig_state.load_dict(snapshot.pig_state as Dictionary)
	behavior_director.load_dict(snapshot.behavior_director as Dictionary)
	event_director.load_dict(snapshot.event_director as Dictionary)
	simulation.load_dict(snapshot.simulation as Dictionary, catalog)


func pig_display_name() -> String:
	return pig_state.name if not pig_state.name.strip_edges().is_empty() else tr("NAME_DEFAULT")


func complete_tutorial_step(completed_step: int) -> bool:
	if completed_step < 0 or completed_step > 6:
		return false
	if pig_state.tutorial_skipped or pig_state.tutorial_step > completed_step:
		return true
	var mutation := func() -> void:
		_advance_tutorial(completed_step)
	return _commit_pig_state_transaction(mutation, false)


func _advance_tutorial(completed_step: int) -> void:
	if pig_state.tutorial_skipped:
		return
	if pig_state.tutorial_step <= completed_step:
		pig_state.tutorial_step = completed_step + 1


func skip_tutorial() -> bool:
	var mutation := func() -> void:
		pig_state.tutorial_skipped = true
	return _commit_pig_state_transaction(mutation, false)


func restart_tutorial() -> bool:
	var mutation := func() -> void:
		pig_state.tutorial_skipped = false
		pig_state.tutorial_step = 1 if not pig_state.name.is_empty() else 0
	return _commit_pig_state_transaction(mutation, false)


func set_desktop_mode(enabled: bool) -> bool:
	if enabled and pig_state.familiarity_level < 2:
		return false
	if enabled == desktop_mode:
		return true
	if enabled and not desktop_mode:
		capture_main_window_settings()
	var mutation := func() -> void:
		if enabled:
			_advance_tutorial(5)
	var progression_saved: bool = _commit_pig_state_transaction(mutation, false, "", "", {}, false)
	if enabled and not progression_saved:
		return false
	desktop_mode = enabled
	var audio: Node = get_node_or_null("/root/AudioService") if is_inside_tree() else null
	if audio != null:
		audio.call("set_desktop_mode", enabled)
	var steam: Node = get_node_or_null("/root/SteamService") if is_inside_tree() else null
	if steam != null:
		steam.call("set_rich_presence", "RICH_DESKTOP" if enabled else "RICH_ROOM")
	save_machine_settings({}, false)
	mode_changed.emit(enabled)
	state_changed.emit()
	return true


func set_focus_mode(enabled: bool) -> void:
	if focus_mode == enabled:
		return
	focus_mode = enabled
	save_machine_settings({}, false)
	state_changed.emit()


func current_behavior_snapshot() -> Dictionary:
	return simulation.current_behavior.duplicate(true)


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.8, 1.5)


func set_bubble_duration_scale(value: float) -> void:
	bubble_duration_scale = clampf(value, 0.75, 2.0)


func set_locale(value: String) -> bool:
	if value not in SUPPORTED_LOCALES:
		return false
	locale = value
	TranslationServer.set_locale(locale)
	save_machine_settings()
	return true


func notify_pig_placed() -> void:
	note_explicit_companion_interaction()
	toast_requested.emit("TOAST_PIG_PLACED", {"name": pig_display_name()})


func desktop_window_settings() -> Dictionary:
	var data: Dictionary = save_service.load_settings()
	var saved_dock: String = str(data.get("desktop_dock", "bottom"))
	var saved_screen_value: Variant = data.get("desktop_screen", -1)
	var saved_screen: int = _bounded_int(saved_screen_value, -1, -1, 1024)
	return {
		"desktop_scale": _bounded_float(data.get("desktop_scale", 1.0), 1.0, 0.5, 1.5),
		"desktop_dock": saved_dock if saved_dock in ReleaseProfile.desktop_docks() else "bottom",
		"desktop_screen": saved_screen,
		"desktop_always_on_top": _safe_bool(data.get("desktop_always_on_top", true), true),
		"desktop_transparent_mode": _safe_bool(data.get("desktop_transparent_mode", true), true),
		"desktop_pig_only": _safe_bool(data.get("desktop_pig_only", false), false),
	}


func progression_save_directory() -> String:
	return ProjectSettings.globalize_path(save_service.base_dir)


func manual_screenshot_directory() -> String:
	return CompanionRules.photo_base_dir(save_service.base_dir, active_companion_id) + "/screenshots"


func save_manual_screenshot(image: Image) -> Dictionary:
	var directory: String = manual_screenshot_directory()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if image == null or image.is_empty() or directory_error != OK:
		toast_requested.emit("TOAST_SCREENSHOT_FAILED", {"path": ProjectSettings.globalize_path(directory)})
		return {"error": ERR_CANT_CREATE if directory_error != OK else ERR_INVALID_DATA, "path": ""}
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var stem: String = "piggy-%s" % stamp
	var path: String = "%s/%s.png" % [directory, stem]
	var suffix: int = 2
	while FileAccess.file_exists(path):
		path = "%s/%s-%d.png" % [directory, stem, suffix]
		suffix += 1
	var error: Error = image.save_png(path)
	var global_path: String = ProjectSettings.globalize_path(path)
	toast_requested.emit("TOAST_SCREENSHOT_SAVED" if error == OK else "TOAST_SCREENSHOT_FAILED", {"path": global_path})
	return {"error": error, "path": path if error == OK else ""}


func save_game() -> Error:
	return _save_game_at(clock.current_unix())


func _save_game_at(unix_time: int) -> Error:
	if save_recovery_required:
		_on_save_failed("Existing progression must be recovered before writing")
		return ERR_FILE_CORRUPT
	if not loaded_successfully and not catalog.events:
		return ERR_UNCONFIGURED
	_autosave_elapsed = 0.0
	var saved_unix: int = maxi(unix_time, 0)
	var data := {
		"schema_version": SaveService.CURRENT_SCHEMA,
		"release_profile": ReleaseProfile.profile_id(),
		"last_saved_unix": saved_unix,
		"pig_state": pig_state.to_dict(),
		"behavior_director": behavior_director.to_dict(),
		"event_director": event_director.to_dict(),
		"simulation": simulation.to_dict(),
	}
	var roster: Dictionary = _companions.duplicate(true)
	if not roster.is_empty():
		roster[active_companion_id] = CompanionRules.snapshot(data)
		data["active_companion_id"] = active_companion_id
		data["companions"] = roster
	var error: Error = save_service.save_game(data)
	if error == OK:
		_companions = roster
		_last_saved_unix = saved_unix
		_important_save_pending = false
		last_save_error = ""
	return error


func _schedule_important_save() -> void:
	_important_save_pending = true
	if _important_save_scheduled:
		return
	_important_save_scheduled = true
	call_deferred("_flush_important_save")


func _flush_important_save() -> void:
	_important_save_scheduled = false
	if _important_save_pending:
		save_game()


func save_machine_settings(extra: Dictionary = {}, capture_window: bool = true) -> Error:
	if capture_window:
		capture_main_window_settings()
	var audio: Node = get_node_or_null("/root/AudioService") if is_inside_tree() else null
	var data: Dictionary = save_service.load_settings()
	data.merge({
		"ui_scale": ui_scale,
		"reduce_motion": reduce_motion,
		"camera_shake_enabled": camera_shake_enabled,
		"reduce_desktop_roaming": reduce_desktop_roaming,
		"reduce_desktop_action_frequency": reduce_desktop_action_frequency,
		"bubble_duration_scale": bubble_duration_scale,
		"locale": locale,
		"desktop_mode": desktop_mode,
		"focus_mode": focus_mode,
		"main_window_fullscreen": main_window_fullscreen,
		"main_window_size": {"x": main_window_size.x, "y": main_window_size.y},
		"main_window_position": {"x": main_window_position.x, "y": main_window_position.y},
		"audio": audio.call("to_dict") if audio != null else {},
	}, true)
	data.merge(extra, true)
	data.merge(desktop_companion.settings(), true)
	return save_service.save_settings(data)


func capture_main_window_settings() -> void:
	if not is_inside_tree() or desktop_mode or DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	main_window_fullscreen = mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if not main_window_fullscreen:
		main_window_size = DisplayServer.window_get_size()
		main_window_position = DisplayServer.window_get_position()


func set_main_window_fullscreen(enabled: bool) -> void:
	if enabled == main_window_fullscreen:
		return
	if enabled:
		capture_main_window_settings()
	main_window_fullscreen = enabled
	apply_main_window_settings()
	save_machine_settings({}, false)


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	save_machine_settings()


func set_camera_shake_enabled(enabled: bool) -> void:
	camera_shake_enabled = enabled
	save_machine_settings()


func set_reduce_desktop_roaming(enabled: bool) -> void:
	reduce_desktop_roaming = enabled
	save_machine_settings()


func set_reduce_desktop_action_frequency(enabled: bool) -> void:
	reduce_desktop_action_frequency = enabled
	save_machine_settings()


func desktop_roaming_reduced() -> bool:
	return reduce_motion or reduce_desktop_roaming


func set_desktop_companion_settings(quiet: bool, do_not_disturb: bool, frequency: String) -> bool:
	if frequency not in DesktopCompanionPolicy.FREQUENCIES:
		return false
	note_explicit_companion_interaction()
	var previous: Dictionary = desktop_companion.settings()
	desktop_companion.load_settings({"desktop_quiet":quiet, "desktop_do_not_disturb":do_not_disturb, "desktop_behavior_frequency":frequency})
	if save_machine_settings({}, false) != OK:
		desktop_companion.load_settings(previous)
		return false
	return true


func start_focus_timer() -> void:
	note_explicit_companion_interaction()
	desktop_companion.start_work()


func start_focus_rest() -> bool:
	note_explicit_companion_interaction()
	return desktop_companion.start_rest()


func toggle_focus_timer_pause() -> void:
	desktop_companion.toggle_timer_pause()


func stop_focus_timer() -> void:
	desktop_companion.stop_timer()


func note_explicit_companion_interaction() -> void:
	desktop_companion.note_explicit_interaction()


func _on_application_focus_entered() -> void:
	if is_inside_tree():
		desktop_companion.set_application_focused(get_window().has_focus())


func _on_application_focus_exited() -> void:
	desktop_companion.set_application_focused(false)


func apply_main_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_inside_tree():
		get_window().min_size = MAIN_WINDOW_MIN_SIZE
	DisplayServer.window_set_min_size(MAIN_WINDOW_MIN_SIZE)
	if main_window_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var primary: int = DisplayServer.get_primary_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(primary)
	var restored_size := Vector2i(
		clampi(main_window_size.x, MAIN_WINDOW_MIN_SIZE.x, maxi(usable.size.x, MAIN_WINDOW_MIN_SIZE.x)),
		clampi(main_window_size.y, MAIN_WINDOW_MIN_SIZE.y, maxi(usable.size.y, MAIN_WINDOW_MIN_SIZE.y))
	)
	DisplayServer.window_set_size(restored_size)
	if not DesktopPlatformPolicy.supports_global_positioning(DisplayServer.get_name()):
		return
	var restored_rect := Rect2i(main_window_position, restored_size)
	var usable_rects: Array[Rect2i] = []
	for screen: int in DisplayServer.get_screen_count():
		usable_rects.append(DisplayServer.screen_get_usable_rect(screen))
	if main_window_has_accessible_title_region(restored_rect, usable_rects):
		DisplayServer.window_set_position(main_window_position)
	else:
		main_window_position = usable.position + (usable.size - restored_size) / 2
		DisplayServer.window_set_position(main_window_position)


func handle_runtime_resume(previous_unix: int, current_unix: int) -> Dictionary:
	var settlement: Dictionary = clock.settle(previous_unix, current_unix)
	if bool(settlement.get("clock_went_backwards", false)):
		behavior_director.discard_future_timestamps(current_unix)
		event_director.discard_future_timestamps(current_unix)
		_save_game_at(current_unix)
		return settlement
	if int(settlement.get("elapsed_seconds", 0)) <= 0:
		return settlement
	simulation.apply_offline(pig_state, settlement)
	var plan_update: Dictionary = _advance_life_plan(float(settlement.get("elapsed_seconds", 0)), false)
	if not plan_update.is_empty() and not (plan_update.new_entries as Array).is_empty():
		settlement["life_plan_entries"] = (plan_update.new_entries as Array).duplicate()
	_discover_offline_events(settlement, current_unix)
	last_offline_summary = settlement
	offline_summary_ready.emit(settlement)
	_save_game_at(current_unix)
	state_changed.emit()
	return settlement


func checkpoint_for_exit() -> Dictionary:
	var progression_error: Error = save_game()
	var settings_error: Error = save_machine_settings()
	return {
		"progression_error": progression_error,
		"settings_error": settings_error,
	}


func request_exit() -> bool:
	var result: Dictionary = checkpoint_for_exit()
	if result.get("progression_error", FAILED) == OK and result.get("settings_error", FAILED) == OK:
		get_tree().quit()
		return true
	exit_checkpoint_failed.emit(result)
	return false


func force_exit_without_saving() -> void:
	get_tree().quit()


func retry_save_recovery() -> bool:
	if not save_recovery_required:
		return false
	last_save_error = ""
	last_recovery_source = ""
	_load_or_create_game(false)
	_last_process_unix = clock.current_unix()
	if not save_recovery_required:
		state_changed.emit()
	return not save_recovery_required


func _load_or_create_game(allow_new_game: bool = true) -> void:
	var result: Dictionary = _load_game_with_profile_import()
	save_recovery_required = not bool(result.get("ok", false)) and (bool(result.get("had_files", false)) or not allow_new_game)
	var now: int = clock.current_unix()
	if bool(result.get("ok", false)):
		var data: Dictionary = result.data
		active_companion_id = str(data.get("active_companion_id", CompanionRules.IDS[0]))
		_companions = (data.get("companions", {}) as Dictionary).duplicate(true)
		pig_state.load_dict(data.get("pig_state", {}) as Dictionary)
		var photo_records_repaired: bool = _discard_noncanonical_event_photo_records()
		if pig_state.current_photo_frame not in PHOTO_FRAMES:
			pig_state.current_photo_frame = "plain"
		behavior_director.load_dict(data.get("behavior_director", {}) as Dictionary)
		event_director.load_dict(data.get("event_director", {}) as Dictionary)
		simulation.load_dict(data.get("simulation", {}) as Dictionary, catalog)
		_last_saved_unix = int(data.get("last_saved_unix", now))
		var settlement: Dictionary = clock.settle(_last_saved_unix, now)
		if bool(settlement.get("clock_went_backwards", false)):
			behavior_director.discard_future_timestamps(now)
			event_director.discard_future_timestamps(now)
		simulation.apply_offline(pig_state, settlement)
		var plan_update: Dictionary = _advance_life_plan(float(settlement.get("elapsed_seconds", 0)), false)
		if not plan_update.is_empty() and not (plan_update.new_entries as Array).is_empty():
			settlement["life_plan_entries"] = (plan_update.new_entries as Array).duplicate()
		_discover_offline_events(settlement, now)
		_sync_ending_state(false)
		_sync_demo_state(false)
		if int(settlement.elapsed_seconds) >= 60:
			last_offline_summary = settlement
			offline_summary_ready.emit(settlement)
		# Commit the consumed time anchor immediately. Otherwise a crash before the
		# first autosave can award the same offline interval again. This also resets
		# a future anchor after the system clock moves backwards, without punishment.
		if loaded_successfully and (int(settlement.get("raw_seconds", 0)) != 0 or photo_records_repaired):
			var checkpoint_error: Error = save_game()
			if checkpoint_error != OK and last_save_error.is_empty():
				_on_save_failed("Could not checkpoint startup time settlement")
	else:
		_last_saved_unix = now
		if save_recovery_required:
			_on_save_failed("No valid progression save or backup could be loaded")


func _load_game_with_profile_import(for_profile: String = "", import_service: SaveService = null) -> Dictionary:
	demo_save_imported = false
	var target_profile: String = ReleaseProfile.profile_id() if for_profile.is_empty() else ("demo" if for_profile == "demo" else "full")
	var result: Dictionary = save_service.load_game()
	if bool(result.get("ok", false)):
		var existing_profile: String = str((result.get("data", {}) as Dictionary).get("release_profile", ""))
		if target_profile == "demo" and existing_profile == "full":
			return {"ok":false, "data":{}, "source":"", "recovered":false, "had_files":true}
		if target_profile == "full" and existing_profile == "demo":
			var legacy_data: Dictionary = (result.data as Dictionary).duplicate(true)
			legacy_data["release_profile"] = "full"
			_copy_imported_event_photos(legacy_data, save_service.base_dir)
			if save_service.save_game(legacy_data) == OK:
				demo_save_imported = true
				demo_progress_imported.emit()
				return save_service.load_game()
		return result
	if bool(result.get("had_files", false)) or save_recovery_required:
		return result
	var source: SaveService = import_service
	if source == null:
		var source_profile: String = "demo" if target_profile == "full" else "full"
		source = SaveService.new(ReleaseProfile.save_base_dir(source_profile))
	if not catalog.events.is_empty():
		source.configure_content_ids(catalog, ROOM_SLOTS)
	var source_result: Dictionary = source.load_game()
	if not bool(source_result.get("ok", false)):
		return result
	var source_data: Dictionary = (source_result.data as Dictionary).duplicate(true)
	if str(source_data.get("release_profile", "")) != "demo":
		return result
	source_data["release_profile"] = target_profile
	_copy_imported_event_photos(source_data, source.base_dir)
	var import_error: Error = save_service.save_game(source_data)
	if import_error != OK:
		if last_save_error.is_empty():
			_on_save_failed("Could not import demo progression")
		return result
	var imported: Dictionary = save_service.load_game()
	if target_profile == "full" and bool(imported.get("ok", false)):
		demo_save_imported = true
		demo_progress_imported.emit()
	return imported


func _copy_imported_event_photos(data: Dictionary, source_base_dir: String, companion_id: String = "pig_1") -> void:
	if data.get("companions", null) is Dictionary:
		var companions: Dictionary = data.companions as Dictionary
		for id: String in companions:
			_copy_imported_event_photos({"pig_state":(companions[id] as Dictionary).pig_state}, CompanionRules.photo_base_dir(source_base_dir, id), id)
		data["pig_state"] = ((companions[str(data.active_companion_id)] as Dictionary).pig_state as Dictionary).duplicate(true)
		return
	var pig_value: Variant = data.get("pig_state", null)
	if not pig_value is Dictionary:
		return
	var pig: Dictionary = pig_value as Dictionary
	var photos_value: Variant = pig.get("life_photos", null)
	if not photos_value is Dictionary or (photos_value as Dictionary).is_empty():
		return
	var photos: Dictionary = photos_value as Dictionary
	var target_directory: String = CompanionRules.photo_base_dir(save_service.base_dir, companion_id) + "/photos"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_directory)) != OK:
		photos.clear()
		return
	var omitted_event_ids: Array[Variant] = []
	for event_id_value: Variant in photos:
		var record_value: Variant = photos[event_id_value]
		if not record_value is Dictionary:
			omitted_event_ids.append(event_id_value)
			continue
		var record: Dictionary = record_value as Dictionary
		var source_path: String = str(record.get("path", ""))
		var photo_id: String = str(record.get("photo_id", event_id_value)).get_file().validate_filename()
		if photo_id.is_empty():
			photo_id = str(event_id_value).get_file().validate_filename()
		var expected_source: String = "%s/photos/%s.png" % [source_base_dir.trim_suffix("/"), photo_id]
		if source_path != expected_source or not FileAccess.file_exists(source_path):
			omitted_event_ids.append(event_id_value)
			continue
		var destination: String = "%s/%s.png" % [target_directory, photo_id]
		if source_path == destination or DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(destination)) == OK:
			record["path"] = destination
		else:
			omitted_event_ids.append(event_id_value)
	for event_id_value: Variant in omitted_event_ids:
		photos.erase(event_id_value)


func _discard_noncanonical_event_photo_records() -> bool:
	var removed_event_ids: Array[Variant] = []
	for event_id_value: Variant in pig_state.life_photos:
		var event_id: String = str(event_id_value)
		var event: Dictionary = catalog.get_item("events", event_id)
		var record_value: Variant = pig_state.life_photos[event_id_value]
		if event.is_empty() or not record_value is Dictionary:
			removed_event_ids.append(event_id_value)
			continue
		var record: Dictionary = record_value as Dictionary
		if (
			str(record.get("photo_id", "")) != str(event.get("photo_id", event_id))
			or str(record.get("path", "")) != _event_photo_path(event)
		):
			removed_event_ids.append(event_id_value)
	for event_id_value: Variant in removed_event_ids:
		pig_state.life_photos.erase(event_id_value)
	return not removed_event_ids.is_empty()


func _load_machine_settings() -> void:
	var data: Dictionary = save_service.load_settings()
	desktop_companion.load_settings(data)
	ui_scale = _bounded_float(data.get("ui_scale", ui_scale), ui_scale, 0.8, 1.5)
	reduce_motion = _safe_bool(data.get("reduce_motion", reduce_motion), reduce_motion)
	camera_shake_enabled = _safe_bool(data.get("camera_shake_enabled", camera_shake_enabled), camera_shake_enabled)
	reduce_desktop_roaming = _safe_bool(data.get("reduce_desktop_roaming", reduce_desktop_roaming), reduce_desktop_roaming)
	reduce_desktop_action_frequency = _safe_bool(data.get("reduce_desktop_action_frequency", reduce_desktop_action_frequency), reduce_desktop_action_frequency)
	bubble_duration_scale = _bounded_float(data.get("bubble_duration_scale", bubble_duration_scale), bubble_duration_scale, 0.75, 2.0)
	var locale_value: Variant = data.get("locale", locale)
	locale = str(locale_value) if locale_value is String else "zh_CN"
	if locale not in SUPPORTED_LOCALES:
		locale = "zh_CN"
	TranslationServer.set_locale(locale)
	desktop_mode = _safe_bool(data.get("desktop_mode", desktop_mode), desktop_mode)
	focus_mode = _safe_bool(data.get("focus_mode", focus_mode), focus_mode)
	main_window_fullscreen = _safe_bool(data.get("main_window_fullscreen", main_window_fullscreen), main_window_fullscreen)
	var saved_size_value: Variant = data.get("main_window_size", {})
	var saved_size: Dictionary = saved_size_value as Dictionary if saved_size_value is Dictionary else {}
	main_window_size = Vector2i(
		_bounded_int(saved_size.get("x", main_window_size.x), main_window_size.x, MAIN_WINDOW_MIN_SIZE.x, 16384),
		_bounded_int(saved_size.get("y", main_window_size.y), main_window_size.y, MAIN_WINDOW_MIN_SIZE.y, 16384)
	)
	var saved_position_value: Variant = data.get("main_window_position", {})
	var saved_position: Dictionary = saved_position_value as Dictionary if saved_position_value is Dictionary else {}
	main_window_position = Vector2i(
		_bounded_int(saved_position.get("x", main_window_position.x), main_window_position.x, -32768, 32768),
		_bounded_int(saved_position.get("y", main_window_position.y), main_window_position.y, -32768, 32768)
	)
	var audio_value: Variant = data.get("audio", {})
	call_deferred("_apply_audio_settings", audio_value as Dictionary if audio_value is Dictionary else {})


static func _bounded_float(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return clampf(float(value), minimum, maximum)


static func _bounded_int(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return clampi(int(value), minimum, maximum)


static func _safe_bool(value: Variant, fallback: bool) -> bool:
	return bool(value) if value is bool else fallback


func _apply_audio_settings(data: Dictionary) -> void:
	var audio: Node = get_node_or_null("/root/AudioService") if is_inside_tree() else null
	if audio != null:
		audio.call("configure", data)
		audio.call("set_desktop_mode", desktop_mode)


func _connect_modules() -> void:
	pig_state.changed.connect(_on_pig_state_changed)
	pig_state.familiarity_level_changed.connect(_on_familiarity_level_changed)
	pig_state.content_unlocked.connect(_on_content_unlocked)
	simulation.behavior_started.connect(func(behavior: Dictionary) -> void: behavior_changed.emit(behavior))
	simulation.behavior_completed.connect(_on_behavior_completed)
	event_director.event_discovered.connect(_on_event_discovered)
	save_service.recovery_used.connect(_on_save_recovered)
	save_service.save_failed.connect(_on_save_failed)


func _sync_steam_state() -> void:
	var steam: Node = get_node_or_null("/root/SteamService") if is_inside_tree() else null
	if steam == null:
		return
	if not ReleaseProfile.is_demo():
		var achievements: Array[String] = pig_state.unlocked_achievements.duplicate()
		for id: String in _companions:
			for achievement_id: String in ((_companions[id] as Dictionary).pig_state as Dictionary).get("unlocked_achievements", []) as Array:
				if achievement_id not in achievements:
					achievements.append(achievement_id)
		steam.call("sync_achievements", achievements)
		_sync_steam_stats(steam)
	steam.call("set_rich_presence", "RICH_DESKTOP" if desktop_mode else "RICH_ROOM")


func _try_discover_event(unix_time: int) -> Dictionary:
	var state_before: Dictionary = pig_state.to_dict().duplicate(true)
	var director_before: Dictionary = event_director.to_dict().duplicate(true)
	var important_save_before: bool = _important_save_pending
	_progression_commit_in_progress = true
	var result: Dictionary = event_director.discover_one(
		catalog.events,
		pig_state,
		unix_time,
		desktop_mode,
		false
	)
	if result.is_empty():
		_progression_commit_in_progress = false
		return {}
	if save_game() != OK:
		pig_state.load_dict(state_before)
		event_director.load_dict(director_before)
		_important_save_pending = important_save_before
		_progression_commit_in_progress = false
		return {}
	_progression_commit_in_progress = false
	event_director.announce_discovery(result)
	return result


func _discover_offline_events(settlement: Dictionary, unix_time: int) -> void:
	for sample_unix: int in offline_event_sample_times(settlement, unix_time):
		event_director.discover_one(catalog.events, pig_state, sample_unix, false)


static func offline_event_sample_times(settlement: Dictionary, current_unix: int) -> Array[int]:
	var elapsed: int = clampi(int(settlement.get("elapsed_seconds", 0)), 0, GameClock.MAX_OFFLINE_SECONDS)
	var attempts: int = clampi(elapsed / 7200, 0, 6)
	var result: Array[int] = []
	if attempts <= 0:
		return result
	var start_unix: int = current_unix - elapsed
	if elapsed >= GameClock.MAX_OFFLINE_SECONDS:
		var timezone: Dictionary = Time.get_time_zone_from_system()
		var bias_seconds: int = int(timezone.get("bias", 0)) * 60
		var current_local: int = current_unix + bias_seconds
		var local_day_start: int = floori(float(current_local) / 86400.0) * 86400
		for target_hour: int in [7, 12, 19, 23]:
			var target_local: int = local_day_start + target_hour * 3600
			if target_local > current_local:
				target_local -= 86400
			var target_unix: int = target_local - bias_seconds
			if target_unix >= start_unix and target_unix <= current_unix and not target_unix in result:
				result.append(target_unix)
	for index: int in attempts:
		var offset: int = roundi(float(index + 1) * float(elapsed) / float(attempts + 1))
		var sample_unix: int = start_unix + offset
		if not sample_unix in result and result.size() < attempts:
			result.append(sample_unix)
	result.sort()
	return result


func _on_behavior_completed(behavior: Dictionary, points: int) -> void:
	var plan: Dictionary = catalog.get_item("life_plans", pig_state.active_life_plan)
	_advance_life_plan(LifePlanRules.behavior_inspiration(plan, behavior), true, false)
	_play_sfx("points")
	toast_requested.emit("TOAST_BEHAVIOR_POINTS", {"behavior": tr(str(behavior.get("name_key", ""))), "points": points, "companion_proactive":true})
	_evaluate_achievements()
	state_changed.emit()


func _on_event_discovered(event_id: String, queued: bool) -> void:
	if queued:
		event_queued.emit(event_id)
		toast_requested.emit("TOAST_MEMORY_WAITING", {"companion_proactive":true})
	memory_queue_changed.emit()
	state_changed.emit()


func _on_save_recovered(source: String) -> void:
	last_recovery_source = source
	save_recovered.emit(source)


func _on_save_failed(message: String) -> void:
	last_save_error = message
	save_failed.emit(message)


func _on_pig_state_changed() -> void:
	if not _progression_commit_in_progress:
		state_changed.emit()


func _on_familiarity_level_changed(level: int) -> void:
	if _progression_commit_in_progress:
		return
	_play_sfx("level_up")
	toast_requested.emit("TOAST_LEVEL_UP", {"level": level, "companion_proactive":true})
	_evaluate_achievements()
	_schedule_important_save()


func _on_content_unlocked(_type: String, _id: String) -> void:
	if _progression_commit_in_progress:
		return
	_schedule_important_save()


func _evaluate_achievements(sync_steam: bool = true) -> Array[String]:
	var unlocked: Array[String] = []
	var steam: Node = get_node_or_null("/root/SteamService") if sync_steam and is_inside_tree() else null
	for achievement: Dictionary in catalog.achievements:
		var id: String = str(achievement.id)
		if id in pig_state.unlocked_achievements:
			continue
		var condition: Dictionary = achievement.get("condition", {}) as Dictionary
		var kind: String = str(condition.get("type", ""))
		var target: int = int(condition.get("count", 1))
		var met: bool = false
		match kind:
			"familiarity": met = pig_state.familiarity_level >= target
			"expressions": met = pig_state.unlocked_expressions.size() >= target
			"events": met = pig_state.seen_events.size() >= target
			"furniture": met = pig_state.owned_furniture.size() >= target
			"outfits": met = pig_state.owned_outfits.size() >= target
			"points": met = pig_state.daily_points >= target
			_:
				var content_id: String = str(condition.get("id", ""))
				met = (kind == "event_id" and content_id in pig_state.seen_events) or (kind == "expression_id" and content_id in pig_state.unlocked_expressions)
		if met and pig_state.unlock("achievement", id, clock.current_unix()):
			unlocked.append(id)
			if steam != null:
				steam.call("unlock_achievement", id)
	if steam != null and not ReleaseProfile.is_demo():
		_sync_steam_stats(steam)
	return unlocked


func _sync_committed_event_achievements(event_achievements: Array, evaluated_achievements: Array[String]) -> void:
	var achievement_ids: Array[String] = []
	for achievement_id: Variant in event_achievements:
		var id: String = str(achievement_id)
		if not id in achievement_ids:
			achievement_ids.append(id)
	for id: String in evaluated_achievements:
		if not id in achievement_ids:
			achievement_ids.append(id)
	_sync_committed_achievements(achievement_ids)


func _sync_committed_achievements(achievement_ids: Array[String]) -> void:
	var steam: Node = get_node_or_null("/root/SteamService") if is_inside_tree() else null
	if steam == null:
		return
	for id: String in achievement_ids:
		steam.call("unlock_achievement", id)
	if not ReleaseProfile.is_demo():
		_sync_steam_stats(steam)


func _sync_steam_stats(steam: Node) -> void:
	var stats: Dictionary = {
		"stat_familiarity_level": pig_state.familiarity_level,
		"stat_expressions": pig_state.unlocked_expressions.size(),
		"stat_events": pig_state.seen_events.size(),
		"stat_furniture": pig_state.owned_furniture.size(),
		"stat_outfits": pig_state.owned_outfits.size(),
	}
	for id: String in _companions:
		if id == active_companion_id:
			continue
		var pig: Dictionary = (_companions[id] as Dictionary).pig_state as Dictionary
		stats.stat_familiarity_level = maxi(int(stats.stat_familiarity_level), int(pig.get("familiarity_level", 1)))
		for collection: String in ["expressions", "events", "furniture", "outfits"]:
			var field: String = {"expressions":"unlocked_expressions", "events":"seen_events", "furniture":"owned_furniture", "outfits":"owned_outfits"}[collection]
			var key: String = "stat_" + collection
			stats[key] = maxi(int(stats[key]), (pig.get(field, []) as Array).size())
	steam.call("sync_stats", stats)


func _unlock_interaction_expressions(interaction_id: String) -> int:
	var unlocked_count: int = 0
	for expression: Dictionary in catalog.expressions:
		var condition: Dictionary = expression.get("condition", {}) as Dictionary
		if str(condition.get("type", "")) != "interaction" or str(condition.get("id", "")) != interaction_id:
			continue
		if pig_state.unlock("expression", str(expression.get("id", "")), clock.current_unix()):
			pig_state.add_points(EXPRESSION_UNLOCK_POINTS)
			unlocked_count += 1
	return unlocked_count


func _sync_ending_state(announce: bool) -> void:
	if ReleaseProfile.is_demo():
		return
	if pig_state.ending_unlocked:
		return
	if pig_state.familiarity_level < 10 or pig_state.seen_events.size() < catalog.events.size():
		return
	for event: Dictionary in catalog.events:
		if not str(event.get("id", "")) in pig_state.seen_events:
			return
	pig_state.ending_unlocked = true
	if announce:
		ending_ready.emit()


func is_demo_complete(for_profile: String = "") -> bool:
	var selected_profile: String = ReleaseProfile.profile_id() if for_profile.is_empty() else for_profile
	if selected_profile != "demo" or catalog.events.is_empty():
		return false
	for event: Dictionary in catalog.events:
		if not str(event.get("id", "")) in pig_state.seen_events:
			return false
	return true


func should_show_demo_complete(for_profile: String = "") -> bool:
	return not pig_state.demo_completion_seen and is_demo_complete(for_profile)


func _sync_demo_state(announce: bool, for_profile: String = "") -> void:
	if announce and should_show_demo_complete(for_profile):
		demo_complete_ready.emit()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_on_application_focus_exited()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_on_application_focus_entered()
	if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT) and is_inside_tree():
		if loaded_successfully:
			save_game()
			save_machine_settings()


func _play_sfx(id: String) -> void:
	var audio: Node = get_node_or_null("/root/AudioService") if is_inside_tree() else null
	if audio != null:
		audio.call("play_sfx", id)
