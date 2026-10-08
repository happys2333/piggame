extends Node

const MainScene = preload("res://game/scenes/main.tscn")
const EventViewerScript = preload("res://game/scripts/ui/event_viewer.gd")
const MACOS_FULLSCREEN_SETTLE_SECONDS: float = 1.0

var _failures: Array[String] = []
var _assertions: int = 0


func _process(_delta: float) -> void:
	RenderingServer.force_draw()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = main.get_node("UILayer/MainUI")
	var session: Node = get_tree().root.get_node("GameSession")
	var name_skip: Button = ui.find_child("NameSkipTutorialButton", true, false) as Button
	var initial_personality := ui.find_child("NamePersonalityChoice", true, false) as OptionButton
	_expect_true(initial_personality != null and initial_personality.get_item_metadata(0) == PersonalityRules.RANDOM_CHOICE, "first welcome offers random personality by default")
	if initial_personality != null:
		initial_personality.select(1)
	_expect_true(name_skip != null and name_skip.visible, "first-run naming visibly offers the localized tutorial skip action")
	if name_skip != null:
		name_skip.pressed.emit()
	await get_tree().process_frame
	_expect_true(session.pig_state.tutorial_skipped and session.pig_state.name.is_empty(), "first-run naming skip returns to a playable unnamed room")
	_expect_eq(session.pig_state.personality_id, "personality_lively", "first-run skip still commits the selected personality")
	_expect_true(not bool(ui.get("_overlay").visible), "first-run naming skip closes the blocking prompt")
	var settings_button: Button = ui.find_child("SettingsButton", true, false) as Button
	_expect_true(settings_button != null and settings_button.visible, "the playable unnamed room keeps settings reachable")
	if settings_button != null:
		settings_button.pressed.emit()
	await get_tree().process_frame
	var help_button: Button = ui.find_child("SettingsHelpButton", true, false) as Button
	_expect_true(help_button != null and help_button.visible, "the real settings panel keeps help reachable for an unnamed pig")
	if help_button != null:
		help_button.pressed.emit()
	await get_tree().process_frame
	var replay_button: Button = ui.find_child("HelpReplayTutorialButton", true, false) as Button
	_expect_true(
		replay_button != null and replay_button.text == tr("HELP_REPLAY_NAMING"),
		"the unnamed help page offers the localized naming replay action"
	)
	if replay_button != null:
		replay_button.pressed.emit()
	await get_tree().process_frame
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	var name_input: LineEdit = ui.find_child("NameInput", true, false) as LineEdit
	var name_confirm: Button = ui.find_child("NameConfirmButton", true, false) as Button
	_expect_true(
		not session.pig_state.tutorial_skipped and session.pig_state.tutorial_step == 0,
		"the real unnamed help replay resets onboarding to the naming step"
	)
	_expect_true(overlay != null and overlay.visible, "the unnamed help replay keeps naming modal")
	_expect_true(
		name_input != null and name_input.visible and name_confirm != null and name_confirm.visible,
		"the unnamed help replay renders the real naming input and confirmation"
	)
	if name_input != null and name_confirm != null:
		name_input.text = "Smoke Pig"
		name_confirm.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.name, "Smoke Pig", "the real naming confirmation persists the first-launch pig name")
	_expect_true(
		session.pig_state.tutorial_step == 1 and overlay != null and not overlay.visible,
		"the real naming confirmation closes the modal and continues at petting"
	)
	await _test_status_hud(session, ui)
	await _test_runtime_optimizations(main, session, ui)
	await _test_autonomous_life(main, session, ui)
	await _test_live_event_discovery(session, ui)
	await _test_live_event_overflow(session, ui)
	await _test_unread_indicator(session, ui)
	_test_pig_mouse_drag_classification()
	_test_pig_interruption_contract()
	await _test_pig_interruption_transaction(main, session, ui)
	_test_pig_mouse_drag_transaction(main, session, ui)
	await _test_pig_furniture_drag_transaction(main, session, ui)
	await _test_pig_touch_feedback(main, session, ui)
	await _test_first_feed_expression(session, ui)
	await _test_tutorial_highlights(session, ui, main.get_node("Pig") as PigVisual)
	await _test_help_replay_and_tendency(session, ui)
	print("UI phase: life plans")
	await _test_life_plan_album(session, ui)
	print("UI phase: companion residents")
	await _test_companion_residents(session, ui)
	print("UI phase: independent personalities")
	await _test_personality_forms(main, session, ui)
	print("UI phase: shared pig performance library")
	await _test_pig_performance_library(main, session, ui)
	print("UI phase: background companion protection")
	await _test_desktop_companion_protection(main, session, ui)
	print("UI phase: saves and offline summaries")
	print("UI phase: silent audio settings")
	await _test_silent_audio_settings(session, ui)
	print("UI phase: caption duration")
	await _test_event_caption_duration(session, ui)
	print("UI phase: save recovery")
	await _test_save_recovery_toast(session, ui)
	await _test_atomic_rewrite_failure_ui(session, ui)
	print("UI phase: rotation recovery")
	await _test_rotation_staging_recovery_ui(session, ui)
	await _test_damaged_generation_rotation_ui(session, ui)
	await _test_startup_save_recovery_ui(session, ui)
	await _test_legacy_boolean_recovery_ui(session, ui)
	await _test_unnamed_save_type_recovery_ui(session, ui)
	await _test_integer_save_recovery_ui(session, ui)
	print("UI phase: profile and offline summaries")
	await _test_demo_import_notice(session, ui)
	await _test_deferred_offline_summary(session, ui)
	await _test_offline_summary_event_playback(session, ui)
	await _test_exit_choice(main, session, ui)
	await _test_main_window_mode_switch(session, ui)
	await _test_window_minimum_mode_switch(main, session, ui)
	await _test_desktop_pig_scale_roundtrip(main, session, ui)
	await _test_desktop_unobstructed_companion(main, session, ui)
	await _test_desktop_animation_pause(main, session, ui)
	print("UI phase: pig-only companion")
	await _test_pig_only_companion(main, session, ui)
	print("UI phase: photos and main layouts")
	await _test_ending_flow(session, ui)
	await _test_manual_screenshot(main, session, ui)
	await _test_manual_screenshot_frame_contract(main, session, ui)
	await _test_event_photo_capture_isolation(main, session, ui)
	await _test_album_photo_actions(session, ui)
	await _test_event_branch_handoff(session, ui)
	var cases: Array[Array] = [
		[Vector2i(1280, 720), 1.0, "1280x720-100"],
		[Vector2i(960, 540), 1.0, "960x540-100"],
		[Vector2i(1280, 800), 0.8, "1280x800-80"],
		[Vector2i(2560, 1080), 1.0, "2560x1080-100"],
		[Vector2i(1280, 720), 1.5, "1280x720-150"],
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	for test_case: Array in cases:
		get_window().size = test_case[0]
		session.set("ui_scale", test_case[1])
		ui.call("_rebuild_ui")
		ui.call("_close_panel")
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var main_control := main as Control
		_expect_true(main_control != null and ui.size.is_equal_approx(main_control.size), "UI fills logical canvas at %s" % test_case[2])
		var viewport_rect := Rect2(Vector2.ZERO, ui.size)
		var status_icon: StatusIcon = ui.get("_status_icon") as StatusIcon
		var status_label: Label = ui.get("_status_label") as Label
		_expect_true(
			status_icon != null and _rect_inside(viewport_rect, status_icon.get_global_rect()),
			"current-status icon remains fully visible at %s" % test_case[2]
		)
		_expect_true(
			status_label != null and _rect_inside(viewport_rect, status_label.get_global_rect()),
			"current-status text remains fully visible at %s" % test_case[2]
		)
		for node: Node in ui.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.is_visible_in_tree():
				_expect_true(viewport_rect.intersects(button.get_global_rect()), "visible button remains on-screen at %s" % test_case[2])
		var image: Image = get_window().get_texture().get_image()
		_expect_true(not image.is_empty(), "rendered frame exists for %s" % test_case[2])
		image.save_png("res://build/validation/ui/%s.png" % test_case[2])
	await _test_minimum_window_overlays(session, ui)

	get_window().size = Vector2i(1280, 720)
	session.set("ui_scale", 1.0)
	var smoke_name: String = session.pig_state.name
	session.pig_state.name = ""
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		session.set("locale", locale)
		ui.call("_rebuild_ui")
		ui.call("_close_panel")
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var viewport_rect := Rect2(Vector2.ZERO, ui.size)
		var status_icon: StatusIcon = ui.get("_status_icon") as StatusIcon
		var status_label: Label = ui.get("_status_label") as Label
		var name_label: Label = ui.get("_name_label") as Label
		_expect_eq(
			name_label.text,
			tr("UI_PIG_NAME_LEVEL").format({"name":tr("NAME_DEFAULT"), "level":session.pig_state.familiarity_level}),
			"unnamed HUD uses the localized default pig name in %s" % locale
		)
		_expect_true(
			status_icon != null
				and status_label != null
				and _rect_inside(viewport_rect, status_icon.get_global_rect())
				and status_icon.tooltip_text == status_label.text,
			"localized current-status icon and text remain paired in %s" % locale
		)
		for node: Node in ui.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.is_visible_in_tree():
				_expect_true(viewport_rect.intersects(button.get_global_rect()), "localized button remains on-screen in %s" % locale)
		for node: Node in ui.find_children("*", "Label", true, false):
			var label := node as Label
			if label != null and label.is_visible_in_tree() and label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.size.x > 0:
				_expect_true(label.get_minimum_size().x <= label.size.x + 2.0, "single-line label fits in %s: %s" % [locale, label.text])
		var localized_image: Image = get_window().get_texture().get_image()
		_expect_true(not localized_image.is_empty(), "localized rendered frame exists for %s" % locale)
		ui.call("_show_toast", "TOAST_SAVE_FAILED", {})
		await get_tree().process_frame
		var toast_label: Label = ui.get("_toast_label") as Label
		_expect_true(toast_label != null and toast_label.text != "TOAST_SAVE_FAILED", "localized save failure is visible in %s" % locale)
		_expect_true(toast_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "save failure toast wraps safely in %s" % locale)
		localized_image.save_png("res://build/validation/ui/1280x720-%s.png" % locale)
		_press_visible_button_with_text(ui, tr("UI_SETTINGS"))
		await get_tree().process_frame
		var language_selector: OptionButton = ui.find_child("LanguageSelector", true, false) as OptionButton
		_expect_true(
			language_selector != null
				and language_selector.get_item_text(0) == tr("LANGUAGE_ZH_CN")
				and language_selector.get_item_text(1) == tr("LANGUAGE_ZH_TW")
				and language_selector.get_item_text(2) == tr("LANGUAGE_EN"),
			"language selector renders all choices through localization keys in %s" % locale
		)
		_press_visible_button_with_text(ui, tr("SETTINGS_LEGAL"))
		await get_tree().process_frame
		var privacy_markers: Dictionary = {
			"zh_CN": ["养成主档", "两份安全备份", "游戏自动生成的生活相册照片", "手动截图", "互相隔离的云路径"],
			"zh_TW": ["養成主檔", "兩份安全備份", "遊戲自動生成的生活相簿照片", "手動截圖", "互相隔離的雲路徑"],
			"en": ["main progression save", "two safety backups", "game-generated life-album photos", "manual screenshots", "isolated cloud paths"],
		}
		var privacy_text: String = tr("LEGAL_PRIVACY")
		_expect_true(
			(privacy_markers[locale] as Array).all(func(marker: Variant) -> bool: return str(marker) in privacy_text),
			"localized privacy copy discloses the exact Steam Cloud scope in %s" % locale
		)
		var privacy_rendered: bool = false
		for node: Node in ui.find_children("*", "Label", true, false):
			var label := node as Label
			privacy_rendered = privacy_rendered or (label != null and label.text == privacy_text)
		_expect_true(privacy_rendered, "the complete localized privacy disclosure renders in the legal panel for %s" % locale)
		ui.call("_close_panel")
	TranslationServer.set_locale("zh_CN")
	session.set("locale", "zh_CN")
	session.pig_state.name = smoke_name

	get_window().size = Vector2i(1280, 720)
	session.set("ui_scale", 1.0)
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	var viewer: Control = EventViewerScript.new()
	var event: Dictionary = session.get("catalog").get_item("events", "event_rainy_window")
	viewer.call("play", event, true)
	ui.add_child(viewer)
	await get_tree().process_frame
	var stages: Array[Node] = viewer.find_children("*", "EventStage", true, false)
	var event_skip: Button = viewer.find_child("EventSkipButton", true, false) as Button
	_expect_true(stages.size() == 1 and event_skip != null and event_skip.text == tr("EVENT_SKIP"), "event viewer builds a data-driven visual stage with its localized skip action")
	var stage_pixel_size := Vector2i.ZERO
	if not stages.is_empty():
		var stage := stages[0] as EventStage
		_expect_true(stage.event_anchor == "window", "event stage uses the event anchor for framing")
		_expect_true("rain" in stage.event_props and "warm_drink" in stage.event_props, "event stage retains all event-level props")
	await RenderingServer.frame_post_draw
	var event_viewer_image: Image = get_window().get_texture().get_image()
	event_viewer_image.save_png("res://build/validation/ui/event-viewer.png")
	if not stages.is_empty():
		stage_pixel_size = _event_stage_pixels(stages[0] as EventStage).get_size()
	if not "event_rainy_window" in session.pig_state.discovered_events:
		session.pig_state.discovered_events.append("event_rainy_window")
	var capture_result := {"image": null, "stored": false}
	viewer.connect("photo_captured", func(event_id: String, image: Image) -> void:
		capture_result.image = image
		capture_result.stored = session.store_event_photo(event_id, image)
	)
	_press_event_skip(viewer)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var captured_image: Image = capture_result.image as Image
	_expect_true(captured_image != null and not captured_image.is_empty(), "event climax produces an automatic album photo")
	if captured_image != null and not captured_image.is_empty():
		_expect_eq(captured_image.get_size(), stage_pixel_size, "automatic event photo matches the rendered EventStage pixel rectangle")
		_expect_true(captured_image.get_size() != event_viewer_image.get_size(), "automatic event photo excludes the full viewport and surrounding viewer UI")
		captured_image.save_png("res://build/validation/ui/captured-event-photo.png")
	_expect_true(bool(capture_result.stored), "automatic event photo is stored through the session facade")
	var exported_photo_path: String = session.export_event_photo("event_rainy_window")
	var exported_photo: Image = Image.load_from_file(exported_photo_path) if not exported_photo_path.is_empty() else null
	_expect_true(
		exported_photo != null and exported_photo.get_size() == stage_pixel_size,
		"stored automatic event photo exports as a real PNG with the EventStage dimensions"
	)
	var original_photo_record: Dictionary = session.pig_state.life_photos.get("event_rainy_window", {}).duplicate(true)
	var original_photo_path: String = str(original_photo_record.get("path", ""))
	var original_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(original_photo_path)
	var replay_seen_events: Array[String] = session.pig_state.seen_events.duplicate()
	var replay_pending_events: Array[String] = session.pig_state.pending_events.duplicate()
	var replay_summarized_events: Array[String] = session.pig_state.summarized_events.duplicate()
	if "event_rainy_window" not in session.pig_state.seen_events:
		session.pig_state.seen_events.append("event_rainy_window")
	session.pig_state.pending_events.erase("event_rainy_window")
	session.pig_state.summarized_events.erase("event_rainy_window")
	ui.call("_refresh")
	await _press_album_event_action(ui, event, tr("ALBUM_REPLAY"))
	await get_tree().process_frame
	var replay_nodes: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var replay_viewer: EventViewer = replay_nodes[0] as EventViewer if not replay_nodes.is_empty() else null
	var replay_photo_emitted := [false]
	if replay_viewer != null:
		replay_viewer.photo_captured.connect(func(_event_id: String, _image: Image) -> void: replay_photo_emitted[0] = true)
	_expect_true(
		replay_viewer != null and not bool(replay_viewer.get("_capture_photo")),
		"album replay disables automatic photo capture"
	)
	if replay_viewer != null:
		_press_event_skip(replay_viewer)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var replayed_photo_record: Dictionary = session.pig_state.life_photos.get("event_rainy_window", {}) as Dictionary
	_expect_true(
		not bool(replay_photo_emitted[0])
			and replayed_photo_record == original_photo_record
			and FileAccess.get_file_as_bytes(original_photo_path) == original_photo_bytes,
			"album replay preserves the original automatic photo bytes and capture date"
		)
	session.pig_state.seen_events = replay_seen_events
	session.pig_state.pending_events = replay_pending_events
	session.pig_state.summarized_events = replay_summarized_events
	ui.call("_refresh")
	await _test_event_camera_shake(session)
	await _test_event_stage_catalog(session)
	await _test_furniture_purchase_controls(main, session, ui)
	await _test_furniture_controls(main, session, ui)
	await _test_outfit_controls(main, session, ui)
	await _test_shop_save_failure_recovery(main, session, ui)
	await _test_outfit_visuals(session)
	await _test_behavior_visuals(session)
	await _test_furniture_visuals(session)
	await _test_atmosphere_visuals(session)
	await _test_expression_portraits(session)
	await _test_desktop_expression_preference(main, session, ui)
	await _test_hidden_expression_hint_gate(session, ui)
	await _test_collection_cosmetic_controls(main, session, ui)
	await _test_photo_frames(session, ui)
	await _test_final_asset_runtime_switch(session, ui)
	await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame
	get_tree().root.get_node("AudioService").call("stop_all")
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: %d UI smoke assertions" % _assertions)
		get_tree().quit(0)
	else:
		printerr("FAIL: %d of %d UI assertions failed" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("- %s" % failure)
		get_tree().quit(1)


func _test_personality_forms(main: Node, session: Node, ui: Control) -> void:
	var previous_native_focus: bool = get_window().has_focus()
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_roster: Dictionary = (session.get("_companions") as Dictionary).duplicate(true)
	var previous_id: String = session.active_companion_id
	var previous_clock: GameClock = session.clock
	var previous_locale: String = session.locale
	var previous_scale: float = session.ui_scale
	var previous_size: Vector2i = get_window().size
	var previous_main_size: Vector2i = session.main_window_size
	var previous_main_position: Vector2i = session.main_window_position
	var previous_fullscreen: bool = session.main_window_fullscreen
	var was_processing: bool = session.is_processing()
	var pig := main.get_node("Pig") as PigVisual
	var pig_was_processing: bool = pig.is_processing()
	var fixed_now: int = previous_clock.current_unix()
	session.clock = GameClock.new(func() -> int: return fixed_now)
	session.set_process(false)
	pig.set_process(false)
	ui.hide()
	session.active_companion_id = "pig_1"
	session.set("_companions", {})
	var hashes: Array[int] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	for index: int in session.personality_choices().size():
		var profile: Dictionary = session.personality_choices()[index]
		session.pig_state.load_dict(PigState.new().to_dict())
		var welcome := MainUI.new()
		ui.get_parent().add_child(welcome)
		await get_tree().process_frame
		await get_tree().process_frame
		var options := welcome.find_child("NamePersonalityChoice", true, false) as OptionButton
		_expect_true(options != null and options.item_count == 6 and options.selected == 0, "%s welcome defaults to random and offers all five choices" % profile.id)
		options.select(index + 1)
		options.item_selected.emit(index + 1)
		_expect_eq((welcome.find_child("NamePersonalityChoiceDescription", true, false) as Label).text, tr(str(profile.description_key)), "%s selection previews its localized personality description" % profile.id)
		(welcome.find_child("NameInput", true, false) as LineEdit).text = "造型猪"
		(welcome.find_child("NameConfirmButton", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		_expect_true(session.pig_state.personality_id == str(profile.id) and session.save_service.load_game().data.pig_state.personality_id == str(profile.id), "%s real welcome confirms and persists the chosen personality" % profile.id)
		_expect_true(session.pig_state.daily_points == 70 and session.pig_state.familiarity_xp == 0 and not (welcome.get("_overlay") as ColorRect).visible, "%s welcome closes without bonuses or penalties" % profile.id)
		_send_scaled_pig_input(pig)
		_expect_eq(pig.active_reaction_signature(), "%s:%s" % [profile.pet.category, profile.pet.expression_id], "%s real mouse/touch interaction renders its own reaction" % profile.id)
		await RenderingServer.frame_post_draw
		var frame: Image = get_window().get_texture().get_image()
		var region: Rect2i = Rect2i(pig.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
		_expect_true(region.has_area(), "%s pig reaction remains on-screen" % profile.id)
		var portrait: Image = frame.get_region(region)
		hashes.append(hash(portrait.get_data()))
		portrait.save_png("res://build/validation/ui/personality-reaction-%s.png" % str(profile.id).trim_prefix("personality_"))
		(welcome.find_child("SettingsButton", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		(welcome.find_child("ResidentsSettingsButton", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		var card := welcome.find_child("ResidentPersonality_pig_1", true, false) as Label
		_expect_true(card != null and card.text == tr("PERSONALITY_CARD").format({"personality":tr(str(profile.name_key))}) and welcome.find_child("ResidentInitialPersonality", true, false) == null, "%s resident card shows a permanent personality instead of a reroll command" % profile.id)
		var add_choice := welcome.find_child("ResidentAddPersonality", true, false) as OptionButton
		add_choice.select(2)
		(welcome.find_child("ResidentAddInput", true, false) as LineEdit).text = "同名伙伴"
		(welcome.find_child("ResidentAddInput", true, false) as LineEdit).text_changed.emit("同名伙伴")
		(welcome.find_child("ResidentAddSubmit", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		_expect_true(session.companion_summaries()[1].personality_id == "personality_tsundere" and session.pig_state.personality_id == str(profile.id), "%s newcomer selection is independent of the current pig" % profile.id)
		welcome.queue_free()
		await get_tree().process_frame
		session.set("_companions", {})
		pig.call("_process", 2.0)
	_expect_true(hashes.size() == 5 and hashes.all(func(value: int) -> bool: return hashes.count(value) == 1), "all five personality reactions have distinct real pig pixels")
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		for scale_value: float in [0.8, 1.5]:
			session.set_locale(locale)
			session.set_ui_scale(scale_value)
			get_window().size = Vector2i(960, 540)
			session.pig_state.load_dict(PigState.new().to_dict())
			var welcome := MainUI.new()
			ui.get_parent().add_child(welcome)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var viewport_rect := Rect2(Vector2.ZERO, welcome.size)
			var scroll := welcome.get("_panel_scroll") as ScrollContainer
			for control_name: String in ["NameInput", "NamePersonalityChoice", "NameConfirmButton", "NameSkipTutorialButton"]:
				var control := welcome.find_child(control_name, true, false) as Control
				scroll.ensure_control_visible(control)
				await get_tree().process_frame
				_expect_true(control != null and viewport_rect.intersects(control.get_global_rect()), "%s %s welcome keeps %s reachable" % [locale, scale_value, control_name])
			scroll.scroll_vertical = 0
			await RenderingServer.frame_post_draw
			get_window().get_texture().get_image().save_png("res://build/validation/ui/personality-setup-%s-%s.png" % [locale, "80" if scale_value < 1.0 else "150"])
			(welcome.find_child("NameSkipTutorialButton", true, false) as Button).pressed.emit()
			_expect_true(session.pig_state.personality_id in PersonalityRules.IDS and session.pig_state.name.is_empty(), "%s %s unnamed skip commits a random personality" % [locale, scale_value])
			(welcome.find_child("SettingsButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			(welcome.find_child("ResidentsSettingsButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			scroll = welcome.get("_panel_scroll") as ScrollContainer
			var add_choice := welcome.find_child("ResidentAddPersonality", true, false) as OptionButton
			scroll.ensure_control_visible(add_choice)
			await get_tree().process_frame
			_expect_true(_rect_inside(viewport_rect, scroll.get_global_rect()) and viewport_rect.intersects(add_choice.get_global_rect()), "%s %s resident personality picker stays within a scrollable minimum window" % [locale, scale_value])
			await RenderingServer.frame_post_draw
			get_window().get_texture().get_image().save_png("res://build/validation/ui/personality-residents-%s-%s.png" % [locale, "80" if scale_value < 1.0 else "150"])
			welcome.queue_free()
			await get_tree().process_frame
	session.pig_state.load_dict(previous_state)
	session.set("_companions", previous_roster)
	session.active_companion_id = previous_id
	session.clock = previous_clock
	session.set_locale(previous_locale)
	session.set_ui_scale(previous_scale)
	get_window().size = previous_size
	session.main_window_size = previous_main_size
	session.main_window_position = previous_main_position
	session.main_window_fullscreen = previous_fullscreen
	session.save_machine_settings({}, false)
	session.save_game()
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	pig.set_process(pig_was_processing)
	ui.show()
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	if previous_native_focus:
		get_window().grab_focus()
	_expect_true(not previous_native_focus or await _wait_for_foreground_focus(session), "explicit welcome/window-size fixture restores its prior native foreground context")
	await get_tree().process_frame


func _test_pig_performance_library(main: Node, session: Node, ui: Control) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "performance fixture uses settled native focus")
	var was_processing: bool = session.is_processing()
	var previous_size: Vector2i = get_window().size
	var previous_locale: String = TranslationServer.get_locale()
	var previous_scale: float = session.ui_scale
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_policy: Dictionary = session.desktop_companion.settings()
	session.set_process(false)
	session.set_desktop_companion_settings(false, false, "frequent")
	var directory: String = "res://build/validation/ui/performances"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		for scale: float in [0.8, 1.5]:
			TranslationServer.set_locale(locale)
			session.locale = locale
			session.ui_scale = scale
			get_window().size = Vector2i(960, 540)
			ui.call("_rebuild_ui")
			ui.call("_close_panel")
			await get_tree().process_frame
			(ui.find_child("SettingsButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			var entry_button := ui.find_child("PigPerformanceLibraryButton", true, false) as Button
			_expect_true(entry_button != null and not entry_button.disabled, "%s/%s opens the performance library from real settings" % [locale, scale])
			if entry_button != null:
				entry_button.pressed.emit()
			await get_tree().process_frame
			for category: int in 5:
				var selector := ui.find_child("PerformanceCategory", true, false) as OptionButton
				_expect_true(selector != null and selector.item_count == 5, "performance library preserves all five classified sections")
				if selector == null:
					continue
				selector.select(category)
				selector.item_selected.emit(category)
				await get_tree().process_frame
				await get_tree().process_frame
				var scroll := ui.get("_panel_scroll") as ScrollContainer
				var stop_button := ui.find_child("PerformanceStopButton", true, false) as Button
				var panel := ui.get("_panel") as PanelContainer
				_expect_true(stop_button != null and _rect_inside(panel.get_global_rect(), stop_button.get_global_rect()) and not scroll.get_global_rect().intersects(stop_button.get_global_rect()), "localized performance return remains pinned outside scrolling content in %s/%s/category%d" % [locale, scale, category])
				var buttons: Array[Node] = ui.find_children("Performance_*", "Button", true, false)
				var counts: Array[int] = [9, 9, 12, 6, 2]
				_expect_eq(buttons.size(), counts[category], "performance section lists its complete permanent catalog")
				var last := buttons.back() as Button if not buttons.is_empty() else null
				if last != null:
					scroll.ensure_control_visible(last)
					await get_tree().process_frame
					await get_tree().process_frame
					_expect_true(_rect_inside(scroll.get_global_rect(), last.get_global_rect()), "last localized performance action is reachable by scrolling at minimum size")
				if category == 0:
					await RenderingServer.frame_post_draw
					get_window().get_texture().get_image().save_png("%s/panel-%s-%d.png" % [directory, locale, roundi(scale * 100)])
			ui.call("_close_panel")
	ui.call("_rebuild_ui")
	var pig := main.get_node("Pig") as PigVisual
	_expect_true(await _press_performance_entry(ui, "face_tears", 0), "real performance face button selects independent facial glyphs")
	_expect_true("face_tears" in pig.active_performance_signature(), "production signal presents the selected face")
	_expect_true(await _press_performance_entry(ui, "pose_flat", 1), "real performance pose button selects a four-frame pose")
	_expect_true("body_flat:face_tears" in pig.active_performance_signature(), "pose combines with the previously selected face, not a full-character replacement")
	_expect_true(session.perform_pig("meme_worker"), "manual meme request selects the work form")
	session.pig_performance.advance(8.1, session.catalog.performances, "", true, "normal", RandomNumberGenerator.new())
	_expect_true("body_worker:face_glare" in pig.active_performance_signature(), "meme state advances its face phase while retaining a shared animated form")
	session.set_desktop_companion_settings(true, true, "off")
	session.desktop_companion.set_application_focused(false)
	var signature: String = pig.active_performance_signature()
	var phase: float = float(pig.get("_phase"))
	pig.call("_process", 2.0)
	_expect_eq(pig.get("_phase"), phase, "quiet/background freezes the new performance's real animation phase")
	session.pig_performance.advance(100.0, session.catalog.performances, "outfit_sleepy_cap", false, "off", RandomNumberGenerator.new())
	_expect_eq(pig.active_performance_signature(), signature, "hidden expiry never changes the frozen pig behind another game")
	_expect_true(session.perform_pig("pose_arms"), "explicit interaction remains available in quiet/background protection")
	_expect_true("body_arms" in pig.active_performance_signature(), "explicit request is the only source of a background visual change")
	session.stop_pig_performance()
	_expect_eq(pig.active_performance_signature(), "", "manual ordinary-pig return clears the presentation")
	session.set_desktop_companion_settings(false, false, "frequent")
	session.desktop_companion.set_application_focused(get_window().has_focus())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 230)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var specimen := PigVisual.new()
	specimen.size = Vector2(280, 230)
	viewport.add_child(specimen)
	specimen.set_process(false)
	var faces: Array[Dictionary] = session.catalog.performances.entries("faces")
	for clip: Dictionary in session.catalog.performances.entries("clips"):
		for face: Dictionary in faces:
			var first_pixels := PackedByteArray()
			for frame: int in 4:
				specimen.set_performance({"id":"test", "body_id":str(clip.id), "face_id":str(face.id), "manual":true})
				specimen.set("_phase", float(frame) * PigVisual.FRAME_STEP)
				specimen.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image: Image = viewport.get_texture().get_image()
				var snout_anchor: Array = (clip.snouts as Array)[frame] as Array
				var snout_point := Vector2(float(snout_anchor[0]), float(snout_anchor[1])) * specimen.size / Vector2(256, 256)
				_expect_eq(specimen.interaction_kind_at(snout_point), "poke", "%s/%s/frame%d recognizes the visible animated snout rather than a fixed old hotspot" % [clip.id, face.id, frame])
				_expect_true(not image.is_empty() and image.get_used_rect().has_area(), "%s/%s/frame%d renders actual layered pig pixels" % [clip.id, face.id, frame])
				_expect_true((session.final_assets.get("_atlas_cache") as Dictionary).size() <= 8, "combinable faces and poses keep the eight-atlas LRU budget")
				if frame == 0:
					first_pixels = image.get_data()
					if str(face.id) == "face_dot":
						image.save_png("%s/%s.png" % [directory, str(clip.id)])
				elif frame == 1:
					_expect_true(image.get_data() != first_pixels, "%s/%s has real animated keyframes rather than a static sticker" % [clip.id, face.id])
	viewport.queue_free()
	await get_tree().process_frame
	var face_viewport := SubViewport.new()
	face_viewport.size = Vector2i(840, 690)
	face_viewport.transparent_bg = true
	face_viewport.disable_3d = true
	face_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(face_viewport)
	for face_index: int in faces.size():
		var portrait := PigVisual.new()
		portrait.size = Vector2(280, 230)
		portrait.position = Vector2((face_index % 3) * 280, floori(float(face_index) / 3.0) * 230)
		face_viewport.add_child(portrait)
		portrait.set_process(false)
		portrait.set_performance({"id":"test", "body_id":"body_base", "face_id":str(faces[face_index].id), "manual":true})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	face_viewport.get_texture().get_image().save_png("%s/faces.png" % directory)
	face_viewport.queue_free()
	await get_tree().process_frame
	_expect_eq(session.pig_state.to_dict(), previous_state, "all performances leave the resident's actual progression unchanged")
	_expect_eq(session.simulation.to_dict(), previous_simulation, "all performances preserve the reward-bearing simulation state")
	session.stop_pig_performance()
	session.desktop_companion.load_settings(previous_policy)
	session.save_service.save_settings(previous_settings)
	TranslationServer.set_locale(previous_locale)
	session.locale = previous_locale
	session.ui_scale = previous_scale
	get_window().size = previous_size
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	_expect_true(await _wait_for_foreground_focus(session), "performance fixture restores settled foreground focus for subsequent protection regressions")


func _press_performance_entry(ui: Control, id: String, category: int) -> bool:
	(ui.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	(ui.find_child("PigPerformanceLibraryButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var selector := ui.find_child("PerformanceCategory", true, false) as OptionButton
	selector.select(category)
	selector.item_selected.emit(category)
	await get_tree().process_frame
	var action := ui.find_child("Performance_%s" % id, true, false) as Button
	if action == null or action.disabled:
		return false
	action.pressed.emit()
	await get_tree().process_frame
	return true


func _test_companion_residents(session: Node, ui: Control) -> void:
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_roster: Dictionary = (session.get("_companions") as Dictionary).duplicate(true)
	var previous_id: String = session.active_companion_id
	var previous_locale: String = session.locale
	var previous_scale: float = session.ui_scale
	var previous_size: Vector2i = get_window().size
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	var fixed_now: int = previous_clock.current_unix()
	session.clock = GameClock.new(func() -> int: return fixed_now)
	ui.call("_close_panel")
	var settings: Button = ui.find_child("SettingsButton", true, false) as Button
	settings.pressed.emit()
	await get_tree().process_frame
	var entry: Button = ui.find_child("ResidentsSettingsButton", true, false) as Button
	_expect_true(entry != null and entry.text == tr("RESIDENTS_TITLE"), "settings exposes the localized resident and naming entry")
	entry.pressed.emit()
	await get_tree().process_frame
	var rename_input: LineEdit = ui.find_child("ResidentRenameInput", true, false) as LineEdit
	var rename: Button = ui.find_child("ResidentRenameSubmit", true, false) as Button
	_expect_true(rename_input != null and rename != null and rename_input.max_length == 16, "the real resident page provides a sixteen-character rename form")
	rename_input.text = "  云朵🐷  "
	rename_input.text_changed.emit(rename_input.text)
	rename.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.name, "云朵🐷", "the real rename button saves a trimmed Unicode name")
	var renamed: Dictionary = previous_state.duplicate(true)
	renamed.name = "云朵🐷"
	_expect_eq(session.pig_state.to_dict(), renamed, "renaming preserves the entire original progression")
	_expect_eq(session.save_service.load_game().data.pig_state.name, "云朵🐷", "the displayed renamed pig is already durable")
	var add_input: LineEdit = ui.find_child("ResidentAddInput", true, false) as LineEdit
	var add_button: Button = ui.find_child("ResidentAddSubmit", true, false) as Button
	_expect_true(add_button.disabled, "a newcomer cannot be admitted with an empty name")
	add_input.text = "馒头"
	add_input.text_changed.emit(add_input.text)
	add_button.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.companion_summaries().size(), 2, "the real admission button adds a second independent resident")
	var switch_button: Button = ui.find_child("ResidentSwitch_pig_2", true, false) as Button
	_expect_true(switch_button != null and not switch_button.disabled, "a real button can select the admitted second pig")
	switch_button.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.active_companion_id, "pig_2", "resident switching changes the persistent active ID")
	_expect_eq(session.pig_state.name, "馒头", "the room HUD follows the second pig's chosen name")
	_expect_eq(session.pig_state.daily_points, 70, "switching cannot transfer the first pig's currency")
	_expect_eq(session.pig_state.familiarity_level, 1, "newcomer familiarity stays independent")
	_expect_true("馒头" in (ui.get("_name_label") as Label).text, "the rebuilt live HUD identifies the active resident")
	(ui.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	(ui.find_child("ResidentsSettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	(ui.find_child("ResidentSwitch_pig_1", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.to_dict(), renamed, "returning restores the first pig's own collections and progress")
	session.set_pig_name("WWWWWWWWWWWWWWWW")
	get_window().size = Vector2i(960, 540)
	await get_tree().process_frame
	var hud_name: Label = ui.get("_name_label") as Label
	_expect_true(hud_name.clip_text and hud_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and hud_name.tooltip_text == "WWWWWWWWWWWWWWWW", "maximum-width names retain full tooltips and a compact ellipsis HUD")
	_expect_true(_rect_inside(Rect2(Vector2.ZERO, ui.size), hud_name.get_global_rect()), "a sixteen-character wide name cannot push its HUD outside the minimum window")
	session.set_pig_name("云朵🐷")
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		for scale_value: float in [0.8, 1.5]:
			session.set_locale(locale)
			session.set_ui_scale(scale_value)
			get_window().size = Vector2i(960, 540)
			ui.call("_rebuild_ui")
			(ui.find_child("SettingsButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			(ui.find_child("ResidentsSettingsButton", true, false) as Button).pressed.emit()
			await get_tree().process_frame
			RenderingServer.force_draw()
			var panel_scroll: ScrollContainer = ui.get("_panel_scroll") as ScrollContainer
			_expect_true(_rect_inside(Rect2(Vector2.ZERO, ui.size), panel_scroll.get_global_rect()), "resident forms stay scrollable inside the minimum viewport in %s at %s" % [locale, scale_value])
			rename_input = ui.find_child("ResidentRenameInput", true, false) as LineEdit
			_expect_true(rename_input.text == "云朵🐷" and rename_input.size.x <= panel_scroll.size.x, "Unicode naming input fits and persists in %s at %s" % [locale, scale_value])
			if locale == "zh_CN":
				get_window().get_texture().get_image().save_png("res://build/validation/ui/residents-%s.png" % ("80" if scale_value < 1.0 else "150"))
	session.pig_state.load_dict(previous_state)
	session.set("_companions", previous_roster)
	session.active_companion_id = previous_id
	session.set_locale(previous_locale)
	session.set_ui_scale(previous_scale)
	get_window().size = previous_size
	session.clock = previous_clock
	session.save_game()
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.set("_displayed_companion_id", previous_id)
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame


func _test_life_plan_album(session: Node, ui: Control) -> void:
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var previous_scale: float = session.ui_scale
	var previous_locale: String = session.locale
	var previous_window_size: Vector2i = get_window().size
	session.set_process(false)
	var fixture := PigState.new()
	fixture.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[7]
	fixture.familiarity_level = 8
	fixture.tutorial_skipped = true
	fixture.owned_furniture.append_array(["furn_pillow_cloud", "furn_nightlight_moon"])
	fixture.placed_furniture["sleep_2"] = "furn_pillow_cloud"
	fixture.placed_furniture["sleep_3"] = "furn_nightlight_moon"
	session.pig_state.load_dict(fixture.to_dict())
	_expect_eq(session.save_game(), OK, "plan UI starts from a legal durable room fixture")
	ui.call("_close_panel")
	var album: Button = ui.get("_album_button") as Button
	album.pressed.emit()
	await get_tree().process_frame
	var tabs: TabContainer = ui.find_child("AlbumTabs", true, false) as TabContainer
	_expect_true(tabs != null and tabs.get_tab_count() == 4, "the real album contains the optional little-plans page")
	if tabs == null:
		return
	tabs.current_tab = 3
	await get_tree().process_frame
	var choose: Button = ui.find_child("LifePlanChoose_plan_pillow_notes", true, false) as Button
	_expect_true(choose != null and choose.is_visible_in_tree() and not choose.disabled, "the unlocked pillow plan is reachable through its real button")
	var economy_before: Array = [session.pig_state.daily_points, session.pig_state.familiarity_xp]
	choose.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.active_life_plan, "plan_pillow_notes", "choosing a plan goes through the real session facade")
	_expect_true(choose.disabled and choose.text == tr("LIFE_PLAN_ACTIVE"), "the selected plan becomes the only active choice")
	_expect_eq(session.save_service.load_game().data.pig_state.active_life_plan, "plan_pillow_notes", "the UI choice is already saved")
	_expect_true(is_equal_approx(float(session.life_plan_snapshot("plan_pillow_notes").room_rate), 1.4), "the UI plan uses both actually placed inspiration items")
	session.call("_advance_life_plan", 430.0)
	await get_tree().process_frame
	_expect_eq(session.pig_state.life_plan_entries, ["note_pillow_1"], "room inspiration advances to the first real journal entry")
	var note: Label = ui.find_child("LifePlanEntry_note_pillow_1", true, false) as Label
	_expect_true(note != null and tr("NOTE_PILLOW_1_TEXT") in note.text, "the earned note reveals its localized story without a popup")
	_expect_eq([session.pig_state.daily_points, session.pig_state.familiarity_xp], economy_before, "journal notes grant no points or familiarity")
	var pause: Button = ui.find_child("LifePlanPauseButton", true, false) as Button
	_expect_true(pause != null and not pause.disabled, "the optional plan can be paused through a visible button")
	pause.pressed.emit()
	await get_tree().process_frame
	var kept_progress: float = float(session.pig_state.life_plan_progress["plan_pillow_notes"])
	_expect_true(session.pig_state.active_life_plan.is_empty() and pause.disabled, "pausing changes only the chosen plan")
	_expect_true(not choose.disabled and choose.text == tr("LIFE_PLAN_CONTINUE"), "the same plan offers continuation without resetting it")
	choose.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.life_plan_progress["plan_pillow_notes"], kept_progress, "continuation preserves the accumulated room inspiration")
	var snack: Button = ui.find_child("LifePlanChoose_plan_snack_reviews", true, false) as Button
	snack.pressed.emit()
	await get_tree().process_frame
	_expect_eq(session.pig_state.active_life_plan, "plan_snack_reviews", "the player can switch to a different unlocked plan")
	_expect_eq(session.pig_state.life_plan_progress["plan_pillow_notes"], kept_progress, "switching keeps the first plan and its permanent note")
	_expect_eq(session.pig_state.life_plan_entries, ["note_pillow_1"], "a different plan cannot erase existing notes")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		for scale_value: float in [0.8, 1.5]:
			session.set_locale(locale)
			session.set_ui_scale(scale_value)
			get_window().size = Vector2i(960, 540)
			ui.call("_rebuild_ui")
			(ui.get("_album_button") as Button).pressed.emit()
			await get_tree().process_frame
			tabs = ui.find_child("AlbumTabs", true, false) as TabContainer
			tabs.current_tab = 3
			await get_tree().process_frame
			RenderingServer.force_draw()
			var page: ScrollContainer = tabs.get_child(3) as ScrollContainer
			_expect_true(page != null and page.is_visible_in_tree() and _rect_inside(Rect2(Vector2.ZERO, ui.size), page.get_global_rect()), "plan page is scrollable and inside the minimum viewport in %s at %s" % [locale, scale_value])
			var summary: Label = ui.find_child("LifePlanSummary", true, false) as Label
			_expect_true(summary != null and summary.text == tr("LIFE_PLAN_COLLECTION").format({"count":1, "total":18}), "plan collection is localized and persistent in %s at %s" % [locale, scale_value])
			pause = ui.find_child("LifePlanPauseButton", true, false) as Button
			_expect_true(pause != null and pause.get_minimum_size().x <= page.size.x, "the pause affordance fits in %s at %s" % [locale, scale_value])
			var image: Image = get_window().get_texture().get_image()
			if locale == "zh_CN":
				image.save_png("res://build/validation/ui/life-plans-%s.png" % ("80" if scale_value < 1.0 else "150"))
	session.set_locale(previous_locale)
	session.set_ui_scale(previous_scale)
	get_window().size = previous_window_size
	session.pig_state.load_dict(previous_state)
	session.save_game()
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame


func _test_runtime_optimizations(main: Node, session: Node, ui: Control) -> void:
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	var points: Label = ui.get("_points_label") as Label
	var previous_text: String = points.text
	ui.hide()
	session.pig_state.add_points(17)
	session.state_changed.emit()
	_expect_eq(points.text, previous_text, "hidden HUD state signals do not shape or redraw invisible text")
	ui.show()
	_expect_eq(points.text, tr("UI_POINTS").format({"points":session.pig_state.daily_points}), "returning from desktop or screenshot visibility restores the latest HUD state")
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var draw_count: Array[int] = [0]
	var record_draw := func() -> void: draw_count[0] += 1
	room.draw.connect(record_draw)
	for frame_index: int in 8:
		session.state_changed.emit()
		await RenderingServer.frame_post_draw
	_expect_eq(draw_count[0], 0, "unchanged state notifications never rebuild the static room canvas")
	var scene_textures: Array = room.get("_drawn_textures") as Array
	_expect_true(not scene_textures.is_empty(), "custom room canvas explicitly owns the textures used by its retained draw commands")
	var room_path: String = session.final_assets.path_for("room:%s" % session.pig_state.current_room_palette)
	var manifest: Dictionary = JsonStore.read_object(FinalAssetCatalog.MANIFEST_PATH)
	for entry: Dictionary in manifest.entries as Array:
		if str(entry.path) != room_path:
			session.final_assets.texture_for(str(entry.covers[0]))
	_expect_true(not (session.final_assets.get("_atlas_cache") as Dictionary).has(room_path), "browsing other art really evicts the static room source from the shared catalogue")
	_expect_true(not scene_textures.is_empty() and (scene_textures[0] as Texture2D).get_rid().is_valid(), "scene-owned textures remain valid after shared LRU eviction without forcing a room redraw")
	await RenderingServer.frame_post_draw
	_expect_eq(draw_count[0], 0, "catalogue eviction does not add recurring invalidations to the static room")
	room.hide()
	session.pig_state.current_room_palette = "mint"
	session.state_changed.emit()
	await RenderingServer.frame_post_draw
	_expect_eq(draw_count[0], 0, "hidden room appearance updates defer work rather than drawing in desktop mode")
	room.show()
	await RenderingServer.frame_post_draw
	_expect_true(draw_count[0] > 0, "revealing the room redraws the changed palette")
	room.draw.disconnect(record_draw)
	var probe := PigVisual.new()
	main.add_child(probe)
	probe.set_process(false)
	var previous_reduce_motion: bool = session.reduce_motion
	session.reduce_motion = true
	var phase: float = float(probe.get("_phase"))
	probe.call("_process", 1.0)
	_expect_eq(float(probe.get("_phase")), phase, "reduced motion does not advance a static pig's visual clock")
	session.reduce_motion = previous_reduce_motion
	probe.hide()
	probe.call("_process", 1.0)
	_expect_eq(float(probe.get("_phase")), phase, "hidden pig canvases do not advance or invalidate their animations")
	probe.queue_free()
	session.pig_state.load_dict(previous_state)
	session.state_changed.emit()
	session.set_process(was_processing)


func _test_pig_only_companion(main: Node, session: Node, ui: Control) -> void:
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var was_processing: bool = session.is_processing()
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var pig_was_processing: bool = pig.is_processing()
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var controller_was_processing: bool = controller.is_processing()
	session.set_process(false)
	session.pig_state.familiarity_xp = maxi(session.pig_state.familiarity_xp, PigState.FAMILIARITY_THRESHOLDS[1])
	session.pig_state.familiarity_level = maxi(session.pig_state.familiarity_level, 2)
	session.pig_state.tutorial_skipped = true
	session.save_game()
	session.save_machine_settings({"desktop_pig_only":false, "desktop_transparent_mode":true, "desktop_scale":1.0})
	ui.call("_close_panel")
	ui.call("_refresh")
	(ui.get("_desktop_button") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	controller.set_process(false)
	pig.set_process(false)
	var menus: Array[Node] = controller.find_children("*", "MenuButton", true, false)
	var popup: PopupMenu = (menus[0] as MenuButton).get_popup() if not menus.is_empty() else null
	_expect_true(popup != null and controller.active, "standalone pig enters through the real desktop affordance")
	if popup == null:
		return
	var full_width: int = DisplayServer.window_get_size().x
	var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
	popup.id_pressed.emit(6)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(controller.pig_only_mode and session.desktop_mode and not ui.visible, "pig-only mode leaves the main interface hidden")
	var controls: CanvasLayer = controller.get("_controls_layer") as CanvasLayer
	var bubble: PanelContainer = controller.get("_event_bubble") as PanelContainer
	_expect_true(controls != null and not controls.visible and bubble != null and not bubble.visible, "pig-only mode renders neither control rail nor memory bubble")
	_expect_true(DisplayServer.window_get_size().x < full_width, "the standalone pet actually uses a compact native window")
	var native_transparency: bool = DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY)
	_expect_eq(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), controller.transparent_mode and native_transparency, "native borderless state follows transparent mode with a normal-window fallback")
	_expect_eq(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT), controller.transparent_mode and native_transparency, "the standalone pet enables native transparency, not just an alpha viewport")
	_expect_true(bool(session.desktop_window_settings().desktop_pig_only), "pig-only preference is saved as a machine-local setting")
	_expect_eq(session.pig_state.to_dict(), state_before, "changing desktop presentation does not change progression or plan state")
	popup.id_pressed.emit(4)
	await get_tree().process_frame
	_expect_true(not controller.pig_only_mode and controls.visible, "turning transparency off always restores reachable controls and a normal native window")
	_expect_true(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT), "normal-window fallback clears both transparent and borderless flags")
	_expect_true(bool(session.desktop_window_settings().desktop_pig_only), "fallback preserves the requested pig-only preference without hiding controls")
	popup.about_to_popup.emit()
	_expect_true(popup.is_item_disabled(popup.get_item_index(6)), "normal-window mode disables the unsafe control-hiding action")
	popup.id_pressed.emit(4)
	await get_tree().process_frame
	_expect_true(controller.pig_only_mode and not controls.visible, "restoring supported transparency reapplies the saved standalone preference")
	var window_size: Vector2i = DisplayServer.window_get_size()
	var polygon: PackedVector2Array = controller.call("_update_passthrough", window_size)
	_expect_eq(polygon.size(), 4, "actual native passthrough captures only the pig rectangle without hidden UI corridors")
	controller.set_screenshot_controls_visible(true)
	_expect_true(not controls.visible, "screenshot restoration cannot reveal hidden pig-only controls")
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
	await RenderingServer.frame_post_draw
	var image: Image = get_window().get_texture().get_image()
	_expect_true(not image.is_empty(), "the standalone pet renders a real frame")
	if native_transparency and controller.transparent_mode:
		_expect_true(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, 0).a == 0.0, "the standalone pet has truly transparent empty corners")
	image.save_png("res://build/validation/ui/desktop-pig-only.png")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = pig.size * 0.5
	pig.call("_gui_input", right)
	await get_tree().process_frame
	var context: PopupMenu = controller.get("_context_popup") as PopupMenu
	_expect_true(context != null and context.visible and context.get_item_index(22) >= 0, "right-click opens the real standalone context menu with a return-to-room action")
	if context != null:
		context.hide()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(not controller.pig_only_mode and controls.visible, "the real Escape input restores reachable desktop controls")
	popup.id_pressed.emit(6)
	await get_tree().process_frame
	controller.leave()
	await get_tree().process_frame
	(ui.get("_desktop_button") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(controller.pig_only_mode and not (controller.get("_controls_layer") as CanvasLayer).visible, "re-entering desktop mode restores the saved pig-only preference")
	context = controller.get("_context_popup") as PopupMenu
	context.id_pressed.emit(22)
	await get_tree().process_frame
	_expect_true(not controller.active and not session.desktop_mode and ui.visible, "the context action returns to the ordinary playable room")
	_expect_true(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT) and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "returning to the room restores an opaque decorated native window")
	session.pig_state.load_dict(previous_state)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	pig.set_process(pig_was_processing)
	controller.set_process(controller_was_processing)
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame


func _test_status_hud(session: Node, ui: Control) -> void:
	var previous_satiety: float = session.pig_state.satiety
	var previous_energy: float = session.pig_state.energy
	var previous_interest: float = session.pig_state.interest
	var fixtures: Array[Array] = [
		["STATUS_SLEEPY", 60.0, 10.0, 60.0, "ui:status_sleepy"],
		["STATUS_HUNGRY", 10.0, 60.0, 60.0, "ui:status_hungry"],
		["STATUS_BORED", 60.0, 60.0, 10.0, "ui:status_bored"],
		["STATUS_ENERGETIC", 60.0, 90.0, 80.0, "ui:status_energetic"],
		["STATUS_CONTENT", 60.0, 60.0, 60.0, "ui:status_content"],
	]
	var fallback_hashes: Dictionary = {}
	for fixture: Array in fixtures:
		session.pig_state.satiety = fixture[1]
		session.pig_state.energy = fixture[2]
		session.pig_state.interest = fixture[3]
		ui.call("_refresh")
		await get_tree().process_frame
		var status_icon: StatusIcon = ui.get("_status_icon") as StatusIcon
		var status_label: Label = ui.get("_status_label") as Label
		_expect_true(status_icon != null and status_label != null, "HUD exposes one current-status icon and one text label")
		if status_icon == null or status_label == null:
			continue
		_expect_eq(status_label.text, tr(str(fixture[0])), "current status uses its localized qualitative text")
		_expect_eq(status_icon.status_key, str(fixture[0]), "current-status icon follows the qualitative state")
		_expect_eq(status_icon.asset_token(), str(fixture[4]), "current-status icon has a permanent replacement token")
		_expect_eq(status_icon.tooltip_text, status_label.text, "current-status icon exposes the same accessible description")
		_expect_true(not _contains_ascii_digit(status_label.text), "current status never exposes its 0-100 simulation values")
		var rendered: Image = await _render_status_icon(str(fixture[0]))
		_expect_true(rendered != null and not rendered.is_empty(), "current-status fallback icon renders for %s" % fixture[0])
		if rendered != null and not rendered.is_empty():
			fallback_hashes[hash(rendered.get_data())] = true
	_expect_eq(fallback_hashes.size(), fixtures.size(), "all qualitative states have visibly distinct non-color-only fallback icons")

	var manifest_path := "user://status-icon-runtime-smoke.json"
	var status_token := "ui:status_content"
	var status_tokens: Array[String] = [status_token]
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[{"path":"res://game/assets/ui/app_icon.svg", "covers":[status_token]}],
	}))
	manifest.close()
	_expect_eq(
		session.final_assets.load_manifest(manifest_path, status_tokens),
		[],
		"current-status fixture enables its dedicated visual resolver"
	)
	var dedicated: Image = await _render_status_icon("STATUS_CONTENT")
	_expect_eq(session.final_assets.load_manifest(), [], "current-status fixture restores the pending project manifest")
	var fallback: Image = await _render_status_icon("STATUS_CONTENT")
	_expect_true(
		dedicated != null
			and fallback != null
			and hash(dedicated.get_data()) != hash(fallback.get_data()),
		"dedicated current-status texture replaces the procedural icon through its permanent token"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manifest_path))
	session.pig_state.satiety = previous_satiety
	session.pig_state.energy = previous_energy
	session.pig_state.interest = previous_interest
	ui.call("_refresh")


func _render_status_icon(status_key: String) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(40, 40)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#fffdf9")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var icon := StatusIcon.new()
	icon.position = Vector2(4, 4)
	icon.size = Vector2(32, 32)
	viewport.add_child(icon)
	icon.set_status(status_key)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image


func _wait_for_foreground_focus(session: Node) -> bool:
	get_window().grab_focus()
	var stable_samples: int = 0
	for attempt: int in 20:
		await get_tree().create_timer(0.1).timeout
		stable_samples = stable_samples + 1 if get_window().has_focus() and session.desktop_companion.application_focused else 0
		if stable_samples >= 3:
			return true
	return false


func _test_autonomous_life(main: Node, session: Node, ui: Control) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "foreground reward fixture waits for real startup focus to settle without overriding protection")
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_desktop_mode: bool = session.desktop_mode
	var previous_focus_mode: bool = session.focus_mode
	var previous_autosave_elapsed: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_last_process_unix: int = int(session.get("_last_process_unix"))
	var scene_pig: PigVisual = main.get_node("Pig") as PigVisual
	session.desktop_mode = false
	session.focus_mode = false
	session.simulation.current_behavior = {}
	session.simulation.remaining_seconds = 0.0
	session.behavior_director.recent_ids.clear()
	session.behavior_director.cooldown_until.clear()
	scene_pig.set_behavior({"animation":"idle"})
	await get_tree().process_frame
	await get_tree().process_frame
	var completed_behavior: Dictionary = session.current_behavior_snapshot()
	_expect_true(
		not completed_behavior.is_empty()
			and scene_pig.behavior_animation == str(completed_behavior.get("animation", "idle")),
		"the real main scene starts and presents an autonomous behavior without player input"
	)
	var completed_id: String = str(completed_behavior.get("id", ""))
	var points_before: int = session.pig_state.daily_points
	var familiarity_before: int = session.pig_state.familiarity_xp
	var interactions_before: Dictionary = session.pig_state.interaction_counts.duplicate(true)
	session.simulation.remaining_seconds = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var points_delta: int = session.pig_state.daily_points - points_before
	var next_behavior: Dictionary = session.current_behavior_snapshot()
	_expect_true(completed_id in session.behavior_director.recent_ids, "autonomous completion records its cooldown and recent-history entry")
	_expect_true(
		points_delta >= int(completed_behavior.get("points_min", 2))
			and points_delta <= int(completed_behavior.get("points_max", 5)),
		"autonomous completion grants the configured ordinary daily-points reward"
	)
	_expect_eq(session.pig_state.familiarity_xp, familiarity_before + 1, "autonomous completion advances familiarity without a player command")
	_expect_eq(session.pig_state.interaction_counts, interactions_before, "autonomous life does not fabricate petting or feeding interactions")
	_expect_true(
		not next_behavior.is_empty() and str(next_behavior.get("id", "")) != completed_id,
		"the autonomous scheduler continues into a non-repeating next behavior"
	)
	_expect_eq(
		scene_pig.behavior_animation,
		str(next_behavior.get("animation", "idle")),
		"the production behavior signal updates the live room pig"
	)
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	var toast_label: Label = ui.get("_toast_label") as Label
	var expected_toast: String = tr("TOAST_BEHAVIOR_POINTS").format({
		"behavior":tr(str(completed_behavior.get("name_key", ""))),
		"points":points_delta,
	})
	_expect_true(
		toast_panel != null
			and toast_label != null
			and toast_panel.modulate.a > 0.0
			and toast_label.text == expected_toast,
		"autonomous completion shows its localized ordinary-reward feedback in the real UI"
	)
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_director)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.desktop_mode = previous_desktop_mode
	session.focus_mode = previous_focus_mode
	session.set("_autosave_elapsed", previous_autosave_elapsed)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set("_last_process_unix", previous_last_process_unix)
	if previous_simulation.get("current_behavior_id", "") == "":
		scene_pig.set_behavior({"animation":"idle"})
	else:
		session.simulation.announce_current_behavior()
	ui.call("_refresh")


func _test_live_event_discovery(session: Node, ui: Control) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "foreground memory fixture uses settled native focus")
	var previous_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_behavior_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_event_director: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_autosave_elapsed: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_last_process_unix: int = int(session.get("_last_process_unix"))
	var queued_ids: Array[String] = []
	var memory_notifications: Array[bool] = []
	var success_toasts: Array[String] = []
	var queue_checkpoints: Array[Dictionary] = []
	var memory_checkpoints: Array[Dictionary] = []
	var toast_checkpoints: Array[Dictionary] = []
	var save_path: String = session.save_service.save_path
	var event_id := "event_move_in"
	session.pig_state.familiarity_xp = 0
	session.pig_state.familiarity_level = 1
	session.pig_state.discovered_events.clear()
	session.pig_state.seen_events.clear()
	session.pig_state.pending_events.clear()
	session.pig_state.summarized_events.clear()
	session.event_director.last_triggered_unix.clear()
	session.event_director.recent_event_ids.clear()
	_expect_eq(session.save_game(), OK, "runtime discovery fixture commits a baseline without the event")
	_expect_eq(
		_read_event_discovery_checkpoint(save_path),
		{"discovered_events":[], "pending_events":[], "summarized_events":[], "event_director":{"last_triggered_unix":{}, "recent_event_ids":[]}},
		"runtime discovery starts from a real disk generation with no discovered or queued event"
	)
	var queue_listener: Callable = func(queued_id: String) -> void:
		queued_ids.append(queued_id)
		queue_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	var memory_listener: Callable = func() -> void:
		memory_notifications.append(true)
		memory_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	var toast_listener: Callable = func(key: String, _values: Dictionary) -> void:
		if key == "TOAST_MEMORY_WAITING":
			success_toasts.append(key)
			toast_checkpoints.append(_read_event_discovery_checkpoint(save_path))
	session.event_queued.connect(queue_listener)
	session.memory_queue_changed.connect(memory_listener)
	session.toast_requested.connect(toast_listener)
	session.set("_event_elapsed", GameSession.EVENT_CHECK_SECONDS)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_expect_true(
		event_id in session.pig_state.discovered_events
			and event_id in session.pig_state.pending_events
			and event_id not in session.pig_state.seen_events,
		"the real runtime discovers the eligible unseen event into the pending queue without a player command"
	)
	_expect_eq(queued_ids, [event_id], "durable runtime discovery emits the player-facing queue signal exactly once")
	_expect_eq(memory_notifications.size(), 1, "durable runtime discovery refreshes the visible memory count exactly once")
	_expect_eq(success_toasts, ["TOAST_MEMORY_WAITING"], "durable runtime discovery emits its localized success toast exactly once")
	var expected_checkpoint: Dictionary = JSON.parse_string(JSON.stringify({
		"discovered_events":[event_id],
		"pending_events":[event_id],
		"summarized_events":[],
		"event_director":session.event_director.to_dict().duplicate(true),
	})) as Dictionary
	_expect_eq(queue_checkpoints, [expected_checkpoint], "the real queue signal observes discovery and cooldown already committed in the main file")
	_expect_eq(memory_checkpoints, [expected_checkpoint], "the real memory-count signal observes discovery and cooldown already committed in the main file")
	_expect_eq(toast_checkpoints, [expected_checkpoint], "the real success-toast signal observes discovery and cooldown already committed in the main file")
	var album_button: Button = ui.get("_album_button") as Button
	var unread_dot: Panel = ui.get("_album_unread_dot") as Panel
	_expect_true(
		album_button != null
			and unread_dot != null
			and unread_dot.visible
			and album_button.text == tr("UI_ALBUM"),
		"automatic discovery lights the real album unread mark without changing its localized label"
	)
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		toast_panel != null
			and toast_label != null
			and toast_panel.modulate.a > 0.0
			and toast_label.text == tr("TOAST_MEMORY_WAITING"),
		"automatic discovery shows the localized waiting-memory feedback"
	)
	_expect_true(
		ui.find_children("*", "EventViewer", true, false).is_empty(),
		"automatic discovery never interrupts the player by opening the event viewer"
	)
	var persisted: Dictionary = session.save_service.load_game()
	var persisted_state: Dictionary = (persisted.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary
	_expect_true(
		bool(persisted.get("ok", false))
			and event_id in persisted_state.get("discovered_events", [])
			and event_id in persisted_state.get("pending_events", []),
		"automatic discovery remains readable through the production save loader"
	)

	session.set_process(false)
	session.event_queued.disconnect(queue_listener)
	session.memory_queue_changed.disconnect(memory_listener)
	session.toast_requested.disconnect(toast_listener)
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior_director)
	session.event_director.load_dict(previous_event_director)
	session.simulation.load_dict(previous_simulation, session.catalog)
	_expect_eq(session.save_game(), OK, "runtime discovery fixture restores its original committed state")
	session.set("_autosave_elapsed", previous_autosave_elapsed)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set("_last_process_unix", previous_last_process_unix)
	session.simulation.announce_current_behavior()
	ui.call("_refresh")
	session.set_process(previous_processing)


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


func _test_live_event_overflow(session: Node, ui: Control) -> void:
	var previous_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_behavior_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_event_director: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_autosave_elapsed: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_last_process_unix: int = int(session.get("_last_process_unix"))
	var event_id := "event_fridge_meeting"
	var event: Dictionary = session.catalog.get_item("events", event_id)
	var photo_path: String = "%s/photos/%s.png" % [session.save_service.base_dir, str(event.get("photo_id", event_id))]
	var previous_photo_exists: bool = FileAccess.file_exists(photo_path)
	var previous_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if previous_photo_exists else PackedByteArray()
	var pending_ids: Array[String] = [
		"event_pillow_migration", "event_dream_meeting", "event_alarm_victory",
		"event_balanced_treat", "event_cookie_detective",
	]
	var discovered_ids: Array[String] = ["event_move_in"]
	discovered_ids.append_array(pending_ids)
	var seen_ids: Array[String] = ["event_move_in"]
	var owned_furniture: Array[String] = [
		"furn_bed_basic", "furn_fridge_pink", "furn_pillow_cloud",
		"furn_clock_sleepy", "furn_treadmill", "furn_cookie_jar",
	]
	session.pig_state.familiarity_xp = 95
	session.pig_state.familiarity_level = 5
	session.pig_state.daily_points = 2000
	session.pig_state.satiety = 60.0
	session.pig_state.energy = 65.0
	session.pig_state.interest = 60.0
	session.pig_state.owned_furniture = owned_furniture
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic", "snack_1":"furn_fridge_pink"}
	session.pig_state.discovered_events = discovered_ids.duplicate()
	session.pig_state.seen_events = seen_ids
	session.pig_state.pending_events = pending_ids.duplicate()
	session.pig_state.summarized_events.clear()
	session.pig_state.unlocked_expressions.clear()
	session.pig_state.expression_unlock_dates.clear()
	session.pig_state.favorite_desktop_expression = ""
	session.pig_state.life_photos.clear()
	session.event_director.last_triggered_unix = {"event_move_in":session.clock.current_unix()}
	session.event_director.recent_event_ids.clear()
	var eligible: Array[Dictionary] = session.event_director.get_eligible(session.catalog.events, session.pig_state, session.clock.current_unix())
	_expect_true(
		eligible.size() == 1 and str(eligible[0].get("id", "")) == event_id,
		"the full-queue fixture uses unchanged production content with one eligible first-time event"
	)
	_expect_eq(session.save_game(), OK, "the overflow fixture commits five real pending memories before discovery")
	var queued_ids: Array[String] = []
	var waiting_toasts: Array[String] = []
	var memory_checkpoints: Array[Dictionary] = []
	var save_path: String = session.save_service.save_path
	var queue_listener: Callable = func(queued_id: String) -> void: queued_ids.append(queued_id)
	var toast_listener: Callable = func(key: String, _values: Dictionary) -> void:
		if key == "TOAST_MEMORY_WAITING":
			waiting_toasts.append(key)
	var memory_listener: Callable = func() -> void:
		memory_checkpoints.append(_read_event_discovery_checkpoint(save_path))
		session.set_process(false)
	session.event_queued.connect(queue_listener)
	session.toast_requested.connect(toast_listener)
	session.memory_queue_changed.connect(memory_listener)
	session.set("_event_elapsed", GameSession.EVENT_CHECK_SECONDS)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	session.set_process(false)
	discovered_ids.append(event_id)
	_expect_eq(session.pig_state.pending_events, pending_ids, "live overflow preserves all five pending memories in their original order")
	_expect_eq(session.pig_state.summarized_events, [event_id], "the sixth live memory becomes an unread summary instead of being discarded")
	_expect_eq(session.pig_state.discovered_events, discovered_ids, "live overflow retains every first-time permanent event ID")
	_expect_eq(queued_ids, [], "overflow never emits a misleading sixth ordinary-queue signal")
	_expect_eq(waiting_toasts, [], "overflow does not repeatedly interrupt the player with a queue toast")
	var expected_checkpoint: Dictionary = JSON.parse_string(JSON.stringify({
		"discovered_events":discovered_ids,
		"pending_events":pending_ids,
		"summarized_events":[event_id],
		"event_director":session.event_director.to_dict(),
	})) as Dictionary
	_expect_eq(memory_checkpoints, [expected_checkpoint], "the overflow count signal observes the complete summary already committed in the main file exactly once")
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and (persisted.data.pig_state.pending_events as Array) == pending_ids
			and (persisted.data.pig_state.summarized_events as Array) == [event_id]
			and (persisted.data.pig_state.discovered_events as Array) == discovered_ids,
		"the real save loader retains the capped queue and its overflow without losing first discoveries"
	)
	var unread_dot: Panel = ui.get("_album_unread_dot") as Panel
	_expect_true(unread_dot != null and unread_dot.visible, "the production overflow signal keeps the real album visibly unread")
	_expect_true(ui.find_children("*", "EventViewer", true, false).is_empty(), "live overflow never opens an unsolicited event viewer")
	session.event_queued.disconnect(queue_listener)
	session.toast_requested.disconnect(toast_listener)
	session.memory_queue_changed.disconnect(memory_listener)
	var points_before: int = session.pig_state.daily_points
	var familiarity_before: int = session.pig_state.familiarity_xp
	var branch: Dictionary = session.event_director.resolve_branch(event, session.pig_state)
	var rewards: Dictionary = event.get("rewards", {}) as Dictionary
	var bonus: Dictionary = branch.get("reward_bonus", {}) as Dictionary
	var expected_points: int = int(rewards.get("points", 0)) + int(bonus.get("points", 0)) + (rewards.get("expressions", []) as Array).size() * 10
	var expected_familiarity: int = int(rewards.get("familiarity", 0)) + int(bonus.get("familiarity", 0))
	_expect_true(await _press_album_event_action(ui, event, tr("ALBUM_WATCH")), "the real album offers a watch action for the unread overflow memory")
	var viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var viewer: EventViewer = viewers[0] as EventViewer if not viewers.is_empty() else null
	_expect_true(
		viewer != null and str((viewer.get("_event") as Dictionary).get("id", "")) == event_id and bool(viewer.get("_capture_photo")),
		"the overflow album action starts the correct production event with first-watch photo capture"
	)
	if viewer != null:
		_press_event_skip(viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_eq(session.pig_state.pending_events, pending_ids, "watching an overflow memory does not consume any of the five pending memories")
	_expect_true(session.pig_state.summarized_events.is_empty() and event_id in session.pig_state.seen_events, "watching the overflow memory consumes only its summary and records first viewing")
	_expect_eq(session.pig_state.daily_points, points_before + expected_points, "first overflow viewing grants its configured event and expression rewards once")
	_expect_eq(session.pig_state.familiarity_xp, familiarity_before + expected_familiarity, "first overflow viewing grants its configured familiarity once")
	var recorded_photo: Dictionary = session.pig_state.life_photos.get(event_id, {}) as Dictionary
	var committed_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if FileAccess.file_exists(photo_path) else PackedByteArray()
	_expect_true(
		str(recorded_photo.get("photo_id", "")) == str(event.get("photo_id", ""))
			and str(recorded_photo.get("path", "")) == photo_path
			and not committed_photo_bytes.is_empty(),
		"the first overflow viewing records a real PNG under its permanent life-photo ID"
	)
	persisted = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and event_id in persisted.data.pig_state.seen_events
			and (persisted.data.pig_state.summarized_events as Array).is_empty()
			and (persisted.data.pig_state.pending_events as Array) == pending_ids,
		"the consumed overflow summary and unchanged pending queue survive a production reload"
	)
	var committed_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var committed_director: Dictionary = session.event_director.to_dict().duplicate(true)
	_expect_true(await _press_album_event_action(ui, event, tr("ALBUM_REPLAY")), "the consumed overflow memory becomes a real no-reward album replay")
	viewers = ui.find_children("*", "EventViewer", true, false)
	viewer = viewers[0] as EventViewer if not viewers.is_empty() else null
	_expect_true(viewer != null and not bool(viewer.get("_capture_photo")), "overflow replay disables automatic photo capture through the production viewer")
	if viewer != null:
		_press_event_skip(viewer)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_eq(session.pig_state.to_dict(), committed_state, "replaying a consumed overflow memory cannot change rewards, collections or unread queues")
	_expect_eq(session.event_director.to_dict(), committed_director, "overflow replay preserves committed event cooldown and recent-history state")
	_expect_eq(FileAccess.get_file_as_bytes(photo_path) if FileAccess.file_exists(photo_path) else PackedByteArray(), committed_photo_bytes, "overflow replay preserves the original captured photo bytes")
	if previous_photo_exists:
		var restored_photo := FileAccess.open(photo_path, FileAccess.WRITE)
		restored_photo.store_buffer(previous_photo_bytes)
		restored_photo.close()
	elif FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior_director)
	session.event_director.load_dict(previous_event_director)
	session.simulation.load_dict(previous_simulation, session.catalog)
	_expect_eq(session.save_game(), OK, "the live overflow fixture restores its original committed progression")
	session.set("_autosave_elapsed", previous_autosave_elapsed)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set("_last_process_unix", previous_last_process_unix)
	session.simulation.announce_current_behavior()
	ui.call("_refresh")
	ui.call("_close_panel")
	session.set_process(previous_processing)


static func _contains_ascii_digit(value: String) -> bool:
	for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		if digit in value:
			return true
	return false


func _test_unread_indicator(session: Node, ui: Control) -> void:
	var previous_pending: Array[String] = session.pig_state.pending_events.duplicate()
	var previous_summarized: Array[String] = session.pig_state.summarized_events.duplicate()
	var previous_size: Vector2i = get_window().size
	var previous_scale: float = session.ui_scale
	var no_events: Array[String] = []
	session.pig_state.pending_events = no_events
	session.pig_state.summarized_events = no_events.duplicate()
	ui.call("_refresh")
	var album_button: Button = ui.get("_album_button") as Button
	var unread_dot: Panel = ui.get("_album_unread_dot") as Panel
	_expect_true(
		album_button != null
			and unread_dot != null
			and not unread_dot.visible
			and album_button.text == tr("UI_ALBUM"),
		"album keeps its localized label clean and hides the unread mark when no new memory exists"
	)
	var summarized_only: Array[String] = ["event_pillow_migration"]
	session.pig_state.summarized_events = summarized_only
	ui.call("_refresh")
	_expect_true(unread_dot.visible, "album unread dot remains visible when only an overflow summary is waiting")
	session.pig_state.summarized_events = no_events.duplicate()
	var one_event: Array[String] = ["event_move_in"]
	session.pig_state.pending_events = one_event
	ui.call("_refresh")
	var unread_style: StyleBoxFlat = unread_dot.get_theme_stylebox("panel") as StyleBoxFlat
	_expect_true(
		unread_style != null
			and unread_style.bg_color.a < 1.0
			and unread_style.bg_color.r > unread_style.bg_color.g,
		"new-content indicator uses a soft translucent rose treatment instead of button-text glyphs"
	)
	for layout: Array in [
		[Vector2i(960, 540), 1.0, "960x540"],
		[Vector2i(1280, 800), 0.8, "80%"],
		[Vector2i(1280, 720), 1.5, "150%"],
	]:
		get_window().size = layout[0]
		session.ui_scale = layout[1]
		ui.call("_rebuild_ui")
		await get_tree().process_frame
		await get_tree().process_frame
		album_button = ui.get("_album_button") as Button
		unread_dot = ui.get("_album_unread_dot") as Panel
		_expect_true(
			unread_dot != null
				and unread_dot.is_visible_in_tree()
				and album_button != null
				and album_button.text == tr("UI_ALBUM")
				and _rect_inside(album_button.get_global_rect(), unread_dot.get_global_rect()),
			"soft album unread dot remains distinct from its localized label at %s" % layout[2]
		)
	session.pig_state.pending_events = previous_pending
	session.pig_state.summarized_events = previous_summarized
	get_window().size = previous_size
	session.ui_scale = previous_scale
	ui.call("_rebuild_ui")
	await get_tree().process_frame


func _test_pig_mouse_drag_classification() -> void:
	var surface := Control.new()
	surface.size = Vector2(1280, 720)
	get_tree().root.add_child(surface)
	var pig := PigVisual.new()
	pig.size = Vector2(280, 230)
	pig.position = Vector2(450, 300)
	surface.add_child(pig)
	pig.set_process(false)
	var pressed_kinds: Array[String] = []
	var drag_origins: Array[Vector2] = []
	pig.pressed.connect(func(kind: String) -> void: pressed_kinds.append(kind))
	pig.drag_finished.connect(func(_final_position: Vector2, origin: Vector2) -> void: drag_origins.append(origin))
	var origin: Vector2 = pig.position
	var press_position: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
	_send_pig_mouse_button(pig, press_position, true)
	_send_pig_mouse_motion(pig, press_position + Vector2(80, 0), Vector2(80, 0))
	_send_pig_mouse_motion(pig, press_position, Vector2(-80, 0))
	_send_pig_mouse_button(pig, press_position, false)
	_expect_eq(pressed_kinds, [], "an out-and-back mouse drag cannot become a pet or poke at release")
	_expect_eq(drag_origins, [origin], "an out-and-back mouse drag emits one placement with its original position")
	_expect_eq(pig.position, origin, "returning the mouse to its press point restores the drag position")
	pressed_kinds.clear()
	drag_origins.clear()
	_send_pig_mouse_button(pig, press_position, true)
	_send_pig_mouse_motion(pig, press_position + Vector2(80, 0), Vector2(80, 0))
	_send_pig_mouse_button(pig, press_position + Vector2(80, 0), false)
	_expect_eq(pressed_kinds, [], "an identical outward path with an outward release remains a drag")
	_expect_eq(drag_origins, [origin], "an outward release emits placement without touching the 180 px clamp")
	_expect_eq(pig.position, origin + Vector2(80, 0), "the unclamped outward path moves the rendered pig by 80 px")
	pig.position = origin
	pressed_kinds.clear()
	drag_origins.clear()
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 7
	touch_down.position = pig.size * _normalized_snout_point(pig)
	touch_down.pressed = true
	pig.call("_gui_input", touch_down)
	_send_pig_mouse_motion(pig, press_position + Vector2(80, 0), Vector2(80, 0))
	_expect_eq(pig.position, origin, "real mouse motion cannot move an active screen-touch gesture")
	_send_pig_mouse_button(pig, press_position, false)
	_expect_true(pressed_kinds.is_empty() and drag_origins.is_empty(), "real mouse release cannot finish an active screen-touch gesture")
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 7
	touch_up.position = touch_down.position
	touch_up.pressed = false
	pig.call("_gui_input", touch_up)
	_expect_eq(pressed_kinds, ["poke"], "the owning touch still finishes once after unrelated real mouse input")
	var cases: Array[Dictionary] = [
		{"label":"ordinary body click", "pressed":["pet"]},
		{"label":"ordinary snout click", "point":_normalized_snout_point(pig), "pressed":["poke"]},
		{"label":"small repeated jitter", "offsets":[Vector2(3, 0), Vector2(-3, 0), Vector2(3, 0), Vector2.ZERO], "pressed":["pet"]},
		{"label":"below-threshold round trip", "offsets":[Vector2(7.99, 0), Vector2.ZERO], "pressed":["pet"]},
		{"label":"exact-threshold round trip", "offsets":[Vector2(8, 0), Vector2.ZERO], "drags":1},
		{"label":"disabled dragging click", "enabled":false, "pressed":["pet"]},
		{"label":"disabled dragging round trip", "enabled":false, "offsets":[Vector2(80, 0), Vector2.ZERO]},
		{"label":"long mouse drag", "offsets":[Vector2(400, 0)], "release":Vector2(400, 0), "drags":1, "final":Vector2(180, 0)},
		{"label":"release displacement without motion", "release":Vector2(80, 0), "drags":1},
	]
	for test_case: Dictionary in cases:
		pig.position = origin
		pig.dragging_enabled = bool(test_case.get("enabled", true))
		pressed_kinds.clear()
		drag_origins.clear()
		var point: Vector2 = test_case.get("point", Vector2(0.72, 0.50)) as Vector2
		press_position = pig.global_position + pig.size * point
		_send_pig_mouse_button(pig, press_position, true)
		var previous_offset := Vector2.ZERO
		for offset: Vector2 in test_case.get("offsets", []) as Array:
			_send_pig_mouse_motion(pig, press_position + offset, offset - previous_offset)
			previous_offset = offset
		_send_pig_mouse_button(pig, press_position + (test_case.get("release", Vector2.ZERO) as Vector2), false)
		var label: String = str(test_case.label)
		_expect_eq(pressed_kinds, test_case.get("pressed", []), "%s preserves click classification" % label)
		_expect_eq(drag_origins, [origin] if int(test_case.get("drags", 0)) == 1 else [], "%s preserves placement count and origin" % label)
		_expect_eq(pig.position, origin + (test_case.get("final", Vector2.ZERO) as Vector2), "%s preserves movement policy" % label)
	pig.position = origin
	pig.dragging_enabled = true
	pressed_kinds.clear()
	drag_origins.clear()
	press_position = pig.global_position + pig.size * Vector2(0.72, 0.50)
	_send_pig_mouse_button(pig, press_position, true)
	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = InputEvent.DEVICE_ID_EMULATION
	emulated_motion.global_position = press_position + Vector2(400, 0)
	emulated_motion.relative = Vector2(400, 0)
	pig.call("_gui_input", emulated_motion)
	var emulated_release := InputEventMouseButton.new()
	emulated_release.device = InputEvent.DEVICE_ID_EMULATION
	emulated_release.button_index = MOUSE_BUTTON_LEFT
	emulated_release.global_position = press_position
	pig.call("_gui_input", emulated_release)
	_send_pig_mouse_button(pig, press_position, false)
	_expect_eq(pressed_kinds, ["pet"], "emulated motion and release cannot spoil an owning real mouse click")
	_expect_eq(drag_origins, [], "emulated motion cannot add a mouse placement")
	_expect_eq(pig.position, origin, "emulated motion cannot move an owning real mouse gesture")
	pressed_kinds.clear()
	_send_pig_mouse_button(pig, press_position, true)
	touch_down.index = 8
	pig.call("_gui_input", touch_down)
	var screen_drag := InputEventScreenDrag.new()
	screen_drag.index = 8
	screen_drag.relative = Vector2(80, 0)
	pig.call("_gui_input", screen_drag)
	touch_up.index = 8
	pig.call("_gui_input", touch_up)
	_expect_true(pressed_kinds.is_empty() and drag_origins.is_empty() and pig.position == origin, "unrelated screen-touch events cannot move or finish an owning mouse gesture")
	_send_pig_mouse_button(pig, press_position, false)
	_expect_eq(pressed_kinds, ["pet"], "the owning mouse still finishes once after unrelated screen-touch input")
	_expect_eq(drag_origins, [], "unrelated screen-touch input cannot turn a mouse click into placement")
	pressed_kinds.clear()
	touch_down.index = 9
	pig.call("_gui_input", touch_down)
	screen_drag.index = 9
	pig.call("_gui_input", screen_drag)
	touch_up.index = 9
	touch_up.canceled = true
	pig.call("_gui_input", touch_up)
	_expect_eq(pig.position, origin, "a canceled touch drag restores its origin")
	_expect_eq(pressed_kinds, [], "a canceled touch cannot turn into an interaction")
	_expect_eq(drag_origins, [], "a canceled touch cannot commit placement")
	touch_down.index = 10
	pig.call("_gui_input", touch_down)
	touch_up.index = 11
	touch_up.canceled = false
	pig.call("_gui_input", touch_up)
	_expect_true(pressed_kinds.is_empty() and drag_origins.is_empty(), "a different touch index cannot finish the owning touch")
	screen_drag.index = 11
	pig.call("_gui_input", screen_drag)
	_expect_eq(pig.position, origin, "a different touch index cannot move the owning touch")
	touch_up.index = 10
	pig.call("_gui_input", touch_up)
	_expect_eq(pressed_kinds, ["poke"], "the matching touch index still resolves its snout tap")
	pressed_kinds.clear()
	touch_down.index = 12
	pig.call("_gui_input", touch_down)
	screen_drag.index = 12
	pig.call("_gui_input", screen_drag)
	screen_drag.relative = Vector2(-80, 0)
	pig.call("_gui_input", screen_drag)
	touch_up.index = 12
	pig.call("_gui_input", touch_up)
	_expect_eq(pressed_kinds, [], "an out-and-back screen drag still cannot become an interaction")
	_expect_eq(drag_origins, [origin], "an out-and-back screen drag keeps one placement")
	_expect_eq(pig.position, origin, "an out-and-back screen drag restores the visible position")
	touch_down.index = 13
	pig.call("_gui_input", touch_down)
	touch_up.index = 13
	pig.call("_gui_input", touch_up)
	_expect_eq(pressed_kinds, ["poke"], "a new touch tap resets travel history after a drag")
	surface.free()


func _test_pig_interruption_contract() -> void:
	var session: Node = get_tree().root.get_node("GameSession")
	var previous_application_focus: bool = session.desktop_companion.application_focused
	for source: String in ["mouse", "touch"]:
		for interruption: String in ["window_notice", "app_notice", "window_signal", "control_hide", "parent_hide", "disable_drag", "enable_drag", "pointer_cancel"]:
			var surface := Control.new()
			surface.size = Vector2(1280, 720)
			get_tree().root.add_child(surface)
			var pig := PigVisual.new()
			pig.size = Vector2(280, 230)
			pig.position = Vector2(450, 300)
			surface.add_child(pig)
			pig.set_process(false)
			pig.dragging_enabled = interruption != "enable_drag"
			var pressed_kinds: Array[String] = []
			var drag_origins: Array[Vector2] = []
			pig.pressed.connect(func(kind: String) -> void: pressed_kinds.append(kind))
			pig.drag_finished.connect(func(_final_position: Vector2, origin: Vector2) -> void: drag_origins.append(origin))
			var origin: Vector2 = pig.position
			var press_position: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
			if source == "mouse":
				_send_pig_mouse_button(pig, press_position, true)
				_send_pig_mouse_motion(pig, press_position + Vector2(80, 0), Vector2(80, 0))
			else:
				_send_pig_screen_touch(pig, 14, true)
				_send_pig_screen_drag(pig, 14, Vector2(80, 0))
			var expected_position: Vector2 = origin
			if interruption == "enable_drag":
				pig.position += Vector2(15, 0)
				expected_position = pig.position
			match interruption:
				"window_notice": pig.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
				"app_notice": pig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
				"window_signal":
					get_window().focus_exited.emit()
					_expect_true(not session.desktop_companion.proactive_allowed(), "synthetic window focus loss really enables background protection")
				"control_hide":
					pig.hide()
					pig.show()
				"parent_hide":
					surface.hide()
					surface.show()
				"disable_drag": pig.dragging_enabled = false
				"enable_drag": pig.dragging_enabled = true
				"pointer_cancel":
					if source == "mouse":
						_send_pig_mouse_button(pig, press_position + Vector2(80, 0), false, true)
					else:
						_send_pig_screen_touch(pig, 14, false, true)
			var label: String = "%s/%s" % [source, interruption]
			_expect_eq(pig.position, expected_position, "%s cancels the temporary drag without rewinding disabled-drag roaming" % label)
			if source == "mouse":
				var late_motion := InputEventMouseMotion.new()
				late_motion.global_position = press_position + Vector2(100, 0)
				late_motion.position = late_motion.global_position - pig.global_position
				late_motion.relative = Vector2(20, 0)
				pig.call("_gui_input", late_motion)
				_send_pig_mouse_button(pig, press_position + Vector2(100, 0), false)
			else:
				_send_pig_screen_drag(pig, 14, Vector2(20, 0))
				_send_pig_screen_touch(pig, 14, false)
			_expect_eq(pig.position, expected_position, "%s ignores late motion and release from the canceled gesture" % label)
			_expect_eq(pressed_kinds, [], "%s cannot commit an interrupted pet or poke" % label)
			_expect_eq(drag_origins, [], "%s cannot commit an interrupted placement" % label)
			pressed_kinds.clear()
			var next_press: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
			_send_pig_mouse_button(pig, next_press, true)
			_send_pig_mouse_button(pig, next_press, false)
			_expect_eq(pressed_kinds, ["pet"], "%s allows the next independent click" % label)
			pig.position += Vector2(15, 0)
			var idle_position: Vector2 = pig.position
			get_window().focus_exited.emit()
			_expect_eq(pig.position, idle_position, "%s idle cancellation cannot rewind autonomous positioning" % label)
			surface.free()
		for dragging: bool in [true, false]:
			var surface := Control.new()
			surface.size = Vector2(1280, 720)
			get_tree().root.add_child(surface)
			var pig := PigVisual.new()
			pig.size = Vector2(280, 230)
			pig.position = Vector2(450, 300)
			surface.add_child(pig)
			pig.set_process(false)
			pig.dragging_enabled = dragging
			var pressed_kinds: Array[String] = []
			var drag_origins: Array[Vector2] = []
			pig.pressed.connect(func(kind: String) -> void: pressed_kinds.append(kind))
			pig.drag_finished.connect(func(_final_position: Vector2, origin: Vector2) -> void: drag_origins.append(origin))
			var press_position: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
			if source == "mouse":
				_send_pig_mouse_button(pig, press_position, true)
			else:
				_send_pig_screen_touch(pig, 15, true)
			if not dragging:
				pig.position += Vector2(15, 0)
			var expected_position: Vector2 = pig.position
			if source == "mouse":
				_send_pig_mouse_button(pig, press_position, false, true)
			else:
				_send_pig_screen_touch(pig, 15, false, true)
			_expect_eq(pressed_kinds, [], "canceled %s presses do not become a tap with dragging=%s" % [source, dragging])
			_expect_eq(drag_origins, [], "canceled %s presses do not become placement with dragging=%s" % [source, dragging])
			_expect_eq(pig.position, expected_position, "canceled %s presses preserve autonomous positioning with dragging=%s" % [source, dragging])
			surface.free()
	session.desktop_companion.set_application_focused(previous_application_focus and get_window().has_focus())
	_expect_eq(session.desktop_companion.application_focused, previous_application_focus and get_window().has_focus(), "gesture contract restores its prior focus model rather than forcing foreground")


func _test_pig_interruption_transaction(main: Node, session: Node, ui: Control) -> void:
	var previous_application_focus: bool = session.desktop_companion.application_focused
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_cooldowns: Dictionary = session.behavior_director.cooldown_until.duplicate(true)
	var previous_position: Vector2 = pig.position
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	_expect_true(
		pig.pressed.is_connected(Callable(main, "_on_pig_pressed"))
			and pig.drag_finished.is_connected(Callable(main, "_on_pig_drag_finished")),
		"interrupted gestures exercise both connected production scene handlers"
	)
	if not "furn_bed_basic" in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.append("furn_bed_basic")
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	session.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":60.0}, session.catalog)
	session.behavior_director.cooldown_until.erase("behavior_bed_nap")
	_expect_eq(session.save_game(), OK, "interruption fixture commits real furniture before checking save generations")
	room.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary
	var hitbox: Dictionary = hitboxes.get("sleep_1", {}) as Dictionary
	_expect_true(hitbox.has("rect") and session.can_invite_to_furniture("furn_bed_basic"), "interruption fixture targets an available rendered functional bed")
	var save_paths: Array[String] = [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]
	var files_before: Array[PackedByteArray] = []
	for path: String in save_paths:
		files_before.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	_expect_true(files_before.all(func(bytes: PackedByteArray) -> bool: return not bytes.is_empty()), "interruption regression protects three existing save generations")
	var pressed_kinds: Array[String] = []
	var drag_origins: Array[Vector2] = []
	var toast_keys: Array[String] = []
	var pressed_handler := func(kind: String) -> void: pressed_kinds.append(kind)
	var drag_handler := func(_final_position: Vector2, origin: Vector2) -> void: drag_origins.append(origin)
	var toast_handler := func(key: String, _values: Dictionary) -> void: toast_keys.append(key)
	pig.pressed.connect(pressed_handler)
	pig.drag_finished.connect(drag_handler)
	session.toast_requested.connect(toast_handler)
	if hitbox.has("rect"):
		var target_global: Vector2 = room.get_global_transform() * (hitbox.rect as Rect2).get_center()
		var origin: Vector2 = (main as Control).get_global_transform().affine_inverse() * target_global - pig.size * 0.5 + Vector2(80, 0)
		for source: String in ["mouse", "touch"]:
			for interruption: String in ["window_signal", "pointer_cancel"]:
				pig.position = origin
				pressed_kinds.clear()
				drag_origins.clear()
				toast_keys.clear()
				var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
				var simulation_before: Dictionary = session.simulation.to_dict().duplicate(true)
				var cooldowns_before: Dictionary = session.behavior_director.cooldown_until.duplicate(true)
				var toast_label: Label = ui.get("_toast_label") as Label
				var toast_before: String = toast_label.text
				var reaction_before: String = pig.active_reaction_signature()
				var press_position: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
				if source == "mouse":
					_send_pig_mouse_button(pig, press_position, true)
					_send_pig_mouse_motion(pig, press_position - Vector2(80, 0), Vector2(-80, 0))
				else:
					_send_pig_screen_touch(pig, 16, true)
					_send_pig_screen_drag(pig, 16, Vector2(-80, 0))
				if interruption == "window_signal":
					get_window().focus_exited.emit()
					_expect_true(not session.desktop_companion.proactive_allowed(), "production canceled drag keeps real background protection enabled")
				elif source == "mouse":
					_send_pig_mouse_button(pig, press_position - Vector2(80, 0), false, true)
				else:
					_send_pig_screen_touch(pig, 16, false, true)
				var label: String = "production %s/%s" % [source, interruption]
				_expect_eq(pig.position, origin, "%s restores the temporary furniture drag" % label)
				if source == "mouse":
					_send_pig_mouse_motion(pig, press_position - Vector2(80, 0), Vector2.ZERO)
					_send_pig_mouse_button(pig, press_position - Vector2(80, 0), false)
				else:
					_send_pig_screen_drag(pig, 16, Vector2.ZERO)
					_send_pig_screen_touch(pig, 16, false)
				var files_after: Array[PackedByteArray] = []
				for path: String in save_paths:
					files_after.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
				_expect_eq(pig.position, origin, "%s ignores late furniture-drop input" % label)
				_expect_true(pressed_kinds.is_empty() and drag_origins.is_empty(), "%s emits no successful interaction or placement" % label)
				_expect_eq(session.pig_state.to_dict(), state_before, "%s preserves points, familiarity, interest, interaction counts and onboarding" % label)
				_expect_eq(session.simulation.to_dict(), simulation_before, "%s cannot start the bed invitation behavior" % label)
				_expect_eq(session.behavior_director.cooldown_until, cooldowns_before, "%s cannot start an invitation cooldown" % label)
				_expect_eq(files_after, files_before, "%s cannot rewrite or rotate any of three save generations" % label)
				_expect_true(toast_keys.is_empty() and toast_label.text == toast_before and pig.active_reaction_signature() == reaction_before, "%s cannot show successful placement, invitation or touch feedback" % label)
	pig.pressed.disconnect(pressed_handler)
	pig.drag_finished.disconnect(drag_handler)
	session.toast_requested.disconnect(toast_handler)
	pig.position = previous_position
	session.pig_state.load_dict(previous_state)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.behavior_director.cooldown_until = previous_cooldowns
	session.save_game()
	main.call("_refresh_pig")
	pig.set_behavior(session.simulation.current_behavior)
	room.queue_redraw()
	session.desktop_companion.set_application_focused(previous_application_focus and get_window().has_focus())
	_expect_eq(session.desktop_companion.application_focused, previous_application_focus and get_window().has_focus(), "canceled-drag fixture restores only its original focus state")
	session.set_process(was_processing)
	await get_tree().process_frame


func _send_pig_screen_touch(pig: PigVisual, index: int, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pig.size * Vector2(0.72, 0.50)
	event.pressed = down
	event.canceled = canceled
	pig.call("_gui_input", event)


func _send_pig_screen_drag(pig: PigVisual, index: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pig.size * Vector2(0.72, 0.50) + relative
	event.relative = relative
	pig.call("_gui_input", event)


func _test_pig_mouse_drag_transaction(main: Node, session: Node, ui: Control) -> void:
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var origin: Vector2 = pig.position
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	_expect_true(
		pig.pressed.is_connected(Callable(main, "_on_pig_pressed"))
			and pig.drag_finished.is_connected(Callable(main, "_on_pig_drag_finished")),
		"mouse regression uses both connected production scene handlers"
	)
	_expect_eq(room.furniture_at_position(room.get_global_transform().affine_inverse() * (pig.global_position + pig.size * 0.5)), "", "round-trip placement fixture ends on empty room space")
	var pressed_kinds: Array[String] = []
	var drag_origins: Array[Vector2] = []
	var toast_keys: Array[String] = []
	var pressed_handler := func(kind: String) -> void: pressed_kinds.append(kind)
	var drag_handler := func(_final_position: Vector2, drag_origin: Vector2) -> void: drag_origins.append(drag_origin)
	var toast_handler := func(key: String, _values: Dictionary) -> void: toast_keys.append(key)
	pig.pressed.connect(pressed_handler)
	pig.drag_finished.connect(drag_handler)
	session.toast_requested.connect(toast_handler)
	var save_paths: Array[String] = [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]
	for point: Vector2 in [_normalized_snout_point(pig), Vector2(0.72, 0.50)]:
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		var files_before: Array[PackedByteArray] = []
		for path: String in save_paths:
			files_before.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		pressed_kinds.clear()
		drag_origins.clear()
		toast_keys.clear()
		var press_position: Vector2 = pig.global_position + pig.size * point
		_send_pig_mouse_button(pig, press_position, true)
		_send_pig_mouse_motion(pig, press_position + Vector2(80, 0), Vector2(80, 0))
		_send_pig_mouse_motion(pig, press_position, Vector2(-80, 0))
		_send_pig_mouse_button(pig, press_position, false)
		var files_after: Array[PackedByteArray] = []
		for path: String in save_paths:
			files_after.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_eq(pressed_kinds, [], "production round-trip mouse drag cannot issue pet or poke")
		_expect_eq(drag_origins, [origin], "production round-trip mouse drag issues exactly one placement")
		_expect_eq(pig.position, origin, "production empty-space placement restores the rendered pig position")
		_expect_eq(session.pig_state.to_dict(), state_before, "round-trip dragging cannot change points, familiarity, interest, interactions or onboarding")
		_expect_eq(files_after, files_before, "round-trip dragging cannot rewrite or rotate any of the three save generations")
		_expect_eq(toast_keys, ["TOAST_PIG_PLACED"], "production round-trip drag emits placement feedback instead of pet or poke feedback")
		var toast_label: Label = ui.get("_toast_label") as Label
		_expect_eq(toast_label.text, tr("TOAST_PIG_PLACED").format({"name": session.pig_display_name()}), "production round-trip drag displays its localized placement phrase")
	pig.pressed.disconnect(pressed_handler)
	pig.drag_finished.disconnect(drag_handler)
	session.toast_requested.disconnect(toast_handler)
	session.set_process(was_processing)


func _test_pig_furniture_drag_transaction(main: Node, session: Node, ui: Control) -> void:
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_cooldowns: Dictionary = session.behavior_director.cooldown_until.duplicate(true)
	var previous_position: Vector2 = pig.position
	var previous_room_scale: Vector2 = room.scale
	var previous_room_position: Vector2 = room.position
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	if not "furn_bed_basic" in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.append("furn_bed_basic")
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	session.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":60.0}, session.catalog)
	session.behavior_director.cooldown_until.erase("behavior_bed_nap")
	room.scale = Vector2(0.9, 0.85)
	room.position += Vector2(140, 0)
	room.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary
	var hitbox: Dictionary = hitboxes.get("sleep_1", {}) as Dictionary
	_expect_true(hitbox.has("rect") and str(hitbox.get("furniture_id", "")) == "furn_bed_basic" and session.can_invite_to_furniture("furn_bed_basic"), "mouse placement uses the rendered bed's real hitbox while invitation is available")
	if hitbox.has("rect"):
		var target_in_room: Vector2 = (hitbox.rect as Rect2).get_center()
		_expect_eq(room.furniture_at_position(target_in_room), "furn_bed_basic", "scaled-room drag fixture targets an actual placed functional furniture")
		var target_global: Vector2 = room.get_global_transform() * target_in_room
		var final_position: Vector2 = (main as Control).get_global_transform().affine_inverse() * target_global - pig.size * 0.5
		var origin: Vector2 = final_position + Vector2(80, 0)
		pig.position = origin
		var pressed_kinds: Array[String] = []
		var drag_origins: Array[Vector2] = []
		var toast_keys: Array[String] = []
		var pressed_handler := func(kind: String) -> void: pressed_kinds.append(kind)
		var drag_handler := func(_final_position: Vector2, drag_origin: Vector2) -> void: drag_origins.append(drag_origin)
		var toast_handler := func(key: String, _values: Dictionary) -> void: toast_keys.append(key)
		pig.pressed.connect(pressed_handler)
		pig.drag_finished.connect(drag_handler)
		session.toast_requested.connect(toast_handler)
		var points_before: int = session.pig_state.daily_points
		var interactions_before: Dictionary = session.pig_state.interaction_counts.duplicate(true)
		var interest_before: float = session.pig_state.interest
		var press_position: Vector2 = pig.global_position + pig.size * Vector2(0.72, 0.50)
		_send_pig_mouse_button(pig, press_position, true)
		_send_pig_mouse_motion(pig, press_position - Vector2(80, 0), Vector2(-80, 0))
		_send_pig_mouse_button(pig, press_position - Vector2(80, 0), false)
		_expect_eq(pressed_kinds, [], "dragging onto functional furniture cannot also pet the pig")
		_expect_eq(drag_origins, [origin], "dragging onto functional furniture commits exactly one placement")
		_expect_true(pig.position.is_equal_approx(final_position), "successful furniture placement keeps the short-distance drop in the scaled room")
		var persisted: Dictionary = session.save_service.load_game().get("data", {}) as Dictionary
		var persisted_simulation: Dictionary = persisted.get("simulation", {}) as Dictionary
		_expect_true(
			str(session.simulation.to_dict().get("current_behavior_id", "")) == "behavior_bed_nap"
				and str(persisted_simulation.get("current_behavior_id", "")) == "behavior_bed_nap",
			"real scaled-room furniture drop starts and persists the bed behavior through GameSession"
		)
		_expect_true(
			session.pig_state.daily_points == points_before
				and session.pig_state.interaction_counts == interactions_before
				and is_equal_approx(session.pig_state.interest, minf(interest_before + 1.0, 100.0)),
			"functional drag uses invitation state changes instead of pet rewards or interaction counts"
		)
		var toast_label: Label = ui.get("_toast_label") as Label
		_expect_true(
			toast_keys == ["TOAST_FURNITURE_INVITED"]
				and toast_label.text == tr("TOAST_FURNITURE_INVITED").format({"item":tr("FURN_BED_BASIC_NAME")}),
			"functional furniture drop shows only its localized invitation feedback"
		)
		pig.pressed.disconnect(pressed_handler)
		pig.drag_finished.disconnect(drag_handler)
		session.toast_requested.disconnect(toast_handler)
	pig.position = previous_position
	room.scale = previous_room_scale
	room.position = previous_room_position
	session.pig_state.load_dict(previous_state)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.behavior_director.cooldown_until = previous_cooldowns
	session.save_game()
	main.call("_refresh_pig")
	pig.set_behavior(session.simulation.current_behavior)
	room.queue_redraw()
	session.set_process(was_processing)
	await get_tree().process_frame


func _send_pig_mouse_button(pig: PigVisual, global_position: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.canceled = canceled
	event.global_position = global_position
	event.position = global_position - pig.global_position
	pig.call("_gui_input", event)


func _send_pig_mouse_motion(pig: PigVisual, global_position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.global_position = global_position
	event.position = global_position - pig.global_position
	event.relative = relative
	pig.call("_gui_input", event)


func _test_pig_touch_feedback(main: Node, session: Node, ui: Control) -> void:
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var pressed_kinds: Array[String] = []
	var drag_records: Array[Dictionary] = []
	pig.pressed.connect(func(kind: String) -> void: pressed_kinds.append(kind))
	pig.drag_finished.connect(func(final_position: Vector2, origin: Vector2) -> void:
		drag_records.append({"position":final_position, "origin":origin})
	)
	var previous_points: int = session.pig_state.daily_points
	var previous_interest: float = session.pig_state.interest
	var previous_xp: int = session.pig_state.familiarity_xp
	var previous_level: int = session.pig_state.familiarity_level
	var previous_expressions: Array[String] = session.pig_state.unlocked_expressions.duplicate()
	var previous_expression_dates: Dictionary = session.pig_state.expression_unlock_dates.duplicate(true)
	var previous_achievements: Array[String] = session.pig_state.unlocked_achievements.duplicate()
	var previous_interactions: Dictionary = session.pig_state.interaction_counts.duplicate(true)
	var previous_tutorial_step: int = session.pig_state.tutorial_step
	var previous_tutorial_skipped: bool = session.pig_state.tutorial_skipped
	var previous_behavior_animation: String = pig.behavior_animation
	var previous_expression_category: String = pig.expression_category
	session.pig_state.tutorial_skipped = true
	pig.set_behavior({"animation":"idle"})
	_expect_eq(
		pig.interaction_kind_at(PigVisualRig.snout_for("body_base", 0) * pig.size / Vector2(256, 256)),
		"poke",
		"clicking the rendered snout resolves to a poke"
	)
	_expect_eq(
		pig.interaction_kind_at(pig.size * Vector2(0.72, 0.50)),
		"pet",
		"clicking the rendered body resolves to a pet"
	)
	await RenderingServer.frame_post_draw
	var before_image: Image = get_window().get_texture().get_image()
	var pig_rect: Rect2 = pig.get_global_rect()
	var capture_rect := Rect2i(
		floori(pig_rect.position.x),
		floori(pig_rect.position.y),
		ceili(pig_rect.size.x),
		ceili(pig_rect.size.y)
	)
	var poke_touch_down := InputEventScreenTouch.new()
	poke_touch_down.index = 4
	poke_touch_down.position = pig.size * _normalized_snout_point(pig)
	poke_touch_down.pressed = true
	pig.call("_gui_input", poke_touch_down)
	var poke_touch_up := InputEventScreenTouch.new()
	poke_touch_up.index = 4
	poke_touch_up.position = poke_touch_down.position
	poke_touch_up.pressed = false
	pig.call("_gui_input", poke_touch_up)
	_expect_eq(pressed_kinds, ["poke"], "a real screen-touch tap reaches the snout interaction")
	var emulated_down := InputEventMouseButton.new()
	emulated_down.device = InputEvent.DEVICE_ID_EMULATION
	emulated_down.button_index = MOUSE_BUTTON_LEFT
	emulated_down.position = poke_touch_down.position
	emulated_down.global_position = poke_touch_down.position
	emulated_down.pressed = true
	pig.call("_gui_input", emulated_down)
	var emulated_up := InputEventMouseButton.new()
	emulated_up.device = InputEvent.DEVICE_ID_EMULATION
	emulated_up.button_index = MOUSE_BUTTON_LEFT
	emulated_up.position = poke_touch_down.position
	emulated_up.global_position = poke_touch_down.position
	emulated_up.pressed = false
	pig.call("_gui_input", emulated_up)
	_expect_eq(pressed_kinds, ["poke"], "touch-generated mouse events cannot duplicate a pig interaction")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var poke_image: Image = get_window().get_texture().get_image()
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_eq(pig.active_reaction_signature(), "wronged:expr_wronged_poke", "poke displays an immediate wronged expression with a permanent content ID")
	_expect_eq(
		toast_label.text,
		tr("TOAST_POKE").format({"name": session.pig_state.name}),
		"poke displays its localized short phrase"
	)
	_expect_true(
		not before_image.is_empty()
			and not poke_image.is_empty()
			and hash(before_image.get_region(capture_rect).get_data()) != hash(poke_image.get_region(capture_rect).get_data()),
		"poke changes the rendered pig face immediately"
	)
	var pet_touch_down := InputEventScreenTouch.new()
	pet_touch_down.index = 5
	pet_touch_down.position = pig.size * Vector2(0.72, 0.50)
	pet_touch_down.pressed = true
	pig.call("_gui_input", pet_touch_down)
	var pet_touch_up := InputEventScreenTouch.new()
	pet_touch_up.index = 5
	pet_touch_up.position = pet_touch_down.position
	pet_touch_up.pressed = false
	pig.call("_gui_input", pet_touch_up)
	_expect_eq(pressed_kinds, ["poke", "pet"], "real screen touches preserve distinct snout and body interactions")
	_expect_eq(pig.active_reaction_signature(), "happy:expr_happy_soft", "body touch replaces poke feedback with an immediate pet expression")
	_expect_eq(
		toast_label.text,
		tr("TOAST_PET").format({"name": session.pig_state.name}),
		"pet retains its localized short phrase"
	)
	pig.call("_process", 1.0)
	_expect_true(pig.active_reaction_signature().is_empty(), "touch expression returns to autonomous behavior after a short non-blocking reaction")
	var main_drag_handler := Callable(main, "_on_pig_drag_finished")
	var main_drag_was_connected: bool = pig.drag_finished.is_connected(main_drag_handler)
	if main_drag_was_connected:
		pig.drag_finished.disconnect(main_drag_handler)
	var drag_origin: Vector2 = pig.position
	var drag_down := InputEventScreenTouch.new()
	drag_down.index = 6
	drag_down.position = pig.size * Vector2(0.72, 0.50)
	drag_down.pressed = true
	pig.call("_gui_input", drag_down)
	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = InputEvent.DEVICE_ID_EMULATION
	emulated_motion.position = drag_down.position + Vector2(40, 0)
	emulated_motion.global_position = emulated_motion.position
	pig.call("_gui_input", emulated_motion)
	_expect_eq(pig.position, drag_origin, "touch-generated mouse motion cannot duplicate a screen drag")
	var screen_drag := InputEventScreenDrag.new()
	screen_drag.index = 6
	screen_drag.position = drag_down.position + Vector2(400, 0)
	screen_drag.relative = Vector2(400, 0)
	pig.call("_gui_input", screen_drag)
	var drag_up := InputEventScreenTouch.new()
	drag_up.index = 6
	drag_up.position = screen_drag.position
	drag_up.pressed = false
	pig.call("_gui_input", drag_up)
	_expect_eq(drag_records.size(), 1, "a real screen drag emits one placement transaction")
	var drag_position: Vector2 = drag_records[0].get("position", drag_origin) as Vector2 if not drag_records.is_empty() else drag_origin
	_expect_true(
		drag_position.distance_to(drag_origin) > 179.0
			and drag_position.distance_to(drag_origin) <= PigVisual.MAX_DRAG_DISTANCE + 0.01,
		"screen dragging obeys the same short-distance limit as mouse dragging"
	)
	_expect_eq(pressed_kinds, ["poke", "pet"], "a screen drag never also resolves as a tap")
	pig.position = drag_origin
	if main_drag_was_connected:
		pig.drag_finished.connect(main_drag_handler)
	session.pig_state.daily_points = previous_points
	session.pig_state.interest = previous_interest
	session.pig_state.familiarity_xp = previous_xp
	session.pig_state.familiarity_level = previous_level
	session.pig_state.unlocked_expressions = previous_expressions
	session.pig_state.expression_unlock_dates = previous_expression_dates
	session.pig_state.unlocked_achievements = previous_achievements
	session.pig_state.interaction_counts = previous_interactions
	session.pig_state.tutorial_step = previous_tutorial_step
	session.pig_state.tutorial_skipped = previous_tutorial_skipped
	pig.behavior_animation = previous_behavior_animation
	pig.expression_category = previous_expression_category
	pig.queue_redraw()
	ui.call("_refresh")
	main.call("_refresh_pig")


func _test_first_feed_expression(session: Node, ui: Control) -> void:
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var target: Dictionary = session.catalog.get_item("snacks", "snack_apple")
	var target_id: String = str(target.get("id", ""))
	var target_price: int = int(target.get("price", 0))
	var satiety_gain: float = float(target.get("satiety", 0.0))
	var interest_gain: float = float(target.get("interest", 0.0))
	var starting_points: int = 70
	var starting_satiety: float = 40.0
	var starting_interest: float = 40.0
	var interaction_key: String = "feed:%s" % GameClock.local_date_string(session.clock.current_unix())
	session.set_process(false)
	session.pig_state.daily_points = starting_points
	session.pig_state.satiety = starting_satiety
	session.pig_state.interest = starting_interest
	session.pig_state.familiarity_xp = 0
	session.pig_state.familiarity_level = 1
	session.pig_state.owned_snacks.erase(target_id)
	session.pig_state.unlocked_expressions.erase("expr_happy_soft")
	session.pig_state.expression_unlock_dates.erase("expr_happy_soft")
	session.pig_state.unlocked_achievements.erase("ach_first_expression")
	session.pig_state.interaction_counts.erase(interaction_key)
	session.pig_state.tutorial_step = 2
	session.pig_state.tutorial_skipped = false
	ui.call("_close_panel")
	ui.call("_refresh")
	var tutorial_label: Label = ui.get("_tutorial_label") as Label
	var snacks_entry: Button = ui.get("_snacks_button") as Button
	if snacks_entry != null:
		snacks_entry.pressed.emit()
	await get_tree().process_frame
	var first_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	_expect_true(
		tutorial_label != null
			and tutorial_label.text == tr("TUTORIAL_FEED")
			and snacks_entry != null
			and first_action != null
			and not first_action.disabled
			and first_action.text == tr("UI_FEED").format({"price":target_price}),
		"the real snack entry opens the first unlocked item with an integer repeatable feed price"
	)
	if first_action != null:
		first_action.pressed.emit()
	await get_tree().process_frame
	var rebuilt_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var first_save: Dictionary = session.save_service.load_game()
	var first_save_data: Dictionary = first_save.get("data", {}) as Dictionary
	var first_save_state: Dictionary = first_save_data.get("pig_state", {}) as Dictionary
	var expected_first_points: int = starting_points - target_price + 13
	var first_transaction_ok: bool = (
		session.pig_state.daily_points == expected_first_points
		and session.pig_state.familiarity_xp == 3
		and is_equal_approx(session.pig_state.satiety, starting_satiety + satiety_gain)
		and is_equal_approx(session.pig_state.interest, starting_interest + interest_gain)
		and session.pig_state.owned_snacks.count(target_id) == 1
		and "expr_happy_soft" in session.pig_state.unlocked_expressions
		and "ach_first_expression" in session.pig_state.unlocked_achievements
		and int(session.pig_state.interaction_counts.get(interaction_key, 0)) == 1
		and session.pig_state.tutorial_step == 3
		and tutorial_label.text == tr("TUTORIAL_FURNITURE")
		and rebuilt_action != null
		and not rebuilt_action.disabled
		and rebuilt_action.text == tr("UI_FEED").format({"price":target_price})
		and bool(first_save.get("ok", false))
		and int(first_save_state.get("daily_points", -1)) == expected_first_points
		and int(first_save_state.get("familiarity_xp", -1)) == 3
		and target_id in (first_save_state.get("owned_snacks", []) as Array)
		and "expr_happy_soft" in (first_save_state.get("unlocked_expressions", []) as Array)
		and int((first_save_state.get("interaction_counts", {}) as Dictionary).get(interaction_key, 0)) == 1
		and int(first_save_state.get("tutorial_step", -1)) == 3
	)
	_expect_true(
		first_transaction_ok,
		"the first real feed purchases one snack, grants first-feed collection rewards, advances the tutorial, rebuilds, and saves"
	)
	if rebuilt_action != null:
		rebuilt_action.pressed.emit()
	await get_tree().process_frame
	var repeated_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var repeated_save: Dictionary = session.save_service.load_game()
	var repeated_save_data: Dictionary = repeated_save.get("data", {}) as Dictionary
	var repeated_save_state: Dictionary = repeated_save_data.get("pig_state", {}) as Dictionary
	_expect_true(
		session.pig_state.daily_points == expected_first_points - target_price
			and session.pig_state.familiarity_xp == 3
			and is_equal_approx(session.pig_state.satiety, starting_satiety + satiety_gain * 2.0)
			and is_equal_approx(session.pig_state.interest, starting_interest + interest_gain * 2.0)
			and session.pig_state.owned_snacks.count(target_id) == 1
			and session.pig_state.unlocked_expressions.count("expr_happy_soft") == 1
			and session.pig_state.unlocked_achievements.count("ach_first_expression") == 1
			and int(session.pig_state.interaction_counts.get(interaction_key, 0)) == 2
			and repeated_action != null
			and not repeated_action.disabled
			and repeated_action.text == tr("UI_FEED").format({"price":target_price})
			and bool(repeated_save.get("ok", false))
			and int(repeated_save_state.get("daily_points", -1)) == expected_first_points - target_price
			and int(repeated_save_state.get("familiarity_xp", -1)) == 3
			and int((repeated_save_state.get("interaction_counts", {}) as Dictionary).get(interaction_key, 0)) == 2,
		"repeating the real feed charges only the snack price, keeps one ownership record and first rewards, rebuilds, and saves"
	)
	ui.call("_close_panel")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")


func _test_tutorial_highlights(session: Node, ui: Control, pig: PigVisual) -> void:
	var previous_step: int = session.pig_state.tutorial_step
	var previous_skipped: bool = session.pig_state.tutorial_skipped
	session.pig_state.tutorial_skipped = false
	session.pig_state.tutorial_step = 1
	ui.call("_refresh")
	_expect_true(bool(pig.call("_tutorial_highlight_active")), "petting tutorial highlights the pig without a modal popup")
	var targets: Array[Array] = [
		[2, "_snacks_button"], [3, "_furniture_button"], [4, "_album_button"],
		[5, "_desktop_button"], [6, "_tendency_button"],
	]
	for target: Array in targets:
		session.pig_state.tutorial_step = int(target[0])
		ui.call("_refresh")
		var button: Button = ui.get(str(target[1])) as Button
		_expect_true(button != null and button.has_theme_stylebox_override("normal"), "tutorial step %d visibly highlights its environment target" % target[0])
	session.pig_state.tutorial_step = 7
	ui.call("_refresh")
	var any_highlighted: bool = false
	for target: Array in targets:
		var button: Button = ui.get(str(target[1])) as Button
		any_highlighted = any_highlighted or (button != null and button.has_theme_stylebox_override("normal"))
	_expect_true(not any_highlighted, "completed tutorial clears every environment highlight")
	session.pig_state.tutorial_step = previous_step
	session.pig_state.tutorial_skipped = previous_skipped
	ui.call("_refresh")


func _test_help_replay_and_tendency(session: Node, ui: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var existing_toast_tween: Tween = ui.get("_toast_tween") as Tween
	if existing_toast_tween != null and existing_toast_tween.is_valid():
		existing_toast_tween.kill()
	var existing_toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	if existing_toast_panel != null:
		existing_toast_panel.modulate.a = 0.0
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	session.pig_state.tutorial_skipped = false
	session.pig_state.tutorial_step = 4
	ui.call("_refresh")
	_press_visible_button_with_text(ui, tr("UI_SETTINGS"))
	await get_tree().process_frame
	var skip_button: Button
	var help_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == tr("SETTINGS_SKIP_TUTORIAL"):
			skip_button = button
		elif button.text == tr("SETTINGS_HELP"):
			help_button = button
	_expect_true(
		skip_button != null and not skip_button.disabled and help_button != null,
		"settings exposes enabled skip and help actions while onboarding is active"
	)
	if skip_button != null:
		skip_button.pressed.emit()
	await get_tree().process_frame
	var tutorial_panel: PanelContainer = ui.get("_tutorial_panel") as PanelContainer
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	_expect_true(
		session.pig_state.tutorial_skipped
			and tutorial_panel != null
			and not tutorial_panel.visible
			and overlay != null
			and not overlay.visible,
		"the real settings action skips onboarding and returns to the playable room"
	)
	_press_visible_button_with_text(ui, tr("UI_SETTINGS"))
	await get_tree().process_frame
	skip_button = null
	help_button = null
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == tr("SETTINGS_SKIP_TUTORIAL"):
			skip_button = button
		elif button.text == tr("SETTINGS_HELP"):
			help_button = button
	_expect_true(skip_button != null and skip_button.disabled and help_button != null, "settings disables duplicate skipping but keeps help reachable")
	if help_button != null:
		help_button.pressed.emit()
	await get_tree().process_frame
	var replay_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("HELP_REPLAY_TUTORIAL"):
			replay_button = button
			break
	_expect_true(
		replay_button != null
			and _count_labels_with_text(ui, tr("HELP_CORE")) == 1
			and _count_labels_with_text(ui, tr("HELP_DESKTOP")) == 1
			and _count_labels_with_text(ui, tr("HELP_ALBUM")) == 1
			and _count_labels_with_text(ui, tr("HELP_SAVING")) == 1,
		"the real help page renders all guidance and the tutorial replay action"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/help-tutorial-replay.png")
	if replay_button != null:
		replay_button.pressed.emit()
	await get_tree().process_frame
	var tutorial_label: Label = ui.get("_tutorial_label") as Label
	_expect_true(
		not session.pig_state.tutorial_skipped
			and session.pig_state.tutorial_step == 1
			and tutorial_panel.visible
			and tutorial_label != null
			and tutorial_label.text == tr("TUTORIAL_PET")
			and not overlay.visible,
		"help replay restarts the visible one-step tutorial at petting without a modal"
	)
	session.pig_state.familiarity_level = 5
	session.pig_state.tutorial_step = 6
	session.pig_state.tendency = "rest"
	ui.call("_refresh")
	var tendency_button: Button = ui.get("_tendency_button") as Button
	if tendency_button != null:
		tendency_button.pressed.emit()
	await get_tree().process_frame
	var active_choose: Button
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text != tr("TENDENCY_ACTIVE_NAME"):
			continue
		var card: Node = label.get_parent().get_parent().get_parent()
		for candidate: Node in card.find_children("*", "Button", true, false):
			active_choose = candidate as Button
			break
		break
	_expect_true(
		active_choose != null
			and not active_choose.disabled
			and active_choose.text == tr("UI_CHOOSE")
			and _count_labels_with_text(ui, tr("TENDENCY_INTRO")) == 1,
		"the unlocked tendency panel explains the soft choice and enables an unselected option"
	)
	if active_choose != null:
		active_choose.pressed.emit()
	await get_tree().process_frame
	var active_selected: Button
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text != tr("TENDENCY_ACTIVE_NAME"):
			continue
		var card: Node = label.get_parent().get_parent().get_parent()
		for candidate: Node in card.find_children("*", "Button", true, false):
			active_selected = candidate as Button
			break
		break
	_expect_true(
		session.pig_state.tendency == "active"
			and session.pig_state.tutorial_step == 7
			and active_selected != null
			and active_selected.disabled
			and active_selected.text == tr("UI_SELECTED")
			and not tutorial_panel.visible,
		"choosing a real tendency card persists the choice and completes onboarding visibly"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/tendency-selected.png")
	ui.call("_close_panel")
	session.pig_state.load_dict(previous_pig_state)
	session.save_game()
	ui.call("_refresh")


func _test_silent_audio_settings(session: Node, ui: Control) -> void:
	_press_visible_button_with_text(ui, tr("UI_SETTINGS"))
	await get_tree().process_frame
	var has_notice: bool = false
	var has_reduce_motion: bool = false
	var has_reduce_roaming: bool = false
	var reduce_desktop_actions_checkbox: CheckBox
	var camera_shake_checkbox: CheckBox
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		has_notice = has_notice or (label != null and label.text == tr("SETTINGS_AUDIO_SILENT"))
	var disabled_audio_sliders: int = 0
	var bubble_slider: HSlider
	for node: Node in ui.find_children("*", "HSlider", true, false):
		var slider := node as HSlider
		if slider != null and not slider.editable:
			disabled_audio_sliders += 1
		if slider != null:
			var row := slider.get_parent() as HBoxContainer
			var label := row.get_child(0) as Label if row != null and row.get_child_count() > 0 else null
			if label != null and label.text == tr("SETTINGS_BUBBLE_TIME"):
				bubble_slider = slider
	var desktop_music_disabled: bool = false
	for node: Node in ui.find_children("*", "CheckBox", true, false):
		var checkbox := node as CheckBox
		if checkbox != null:
			if checkbox.text == tr("SETTINGS_DESKTOP_MUSIC"):
				desktop_music_disabled = checkbox.disabled
			has_reduce_motion = has_reduce_motion or checkbox.text == tr("SETTINGS_REDUCE_MOTION")
			has_reduce_roaming = has_reduce_roaming or checkbox.text == tr("SETTINGS_REDUCE_DESKTOP_ROAMING")
			if checkbox.text == tr("SETTINGS_REDUCE_DESKTOP_ACTION_FREQUENCY"):
				reduce_desktop_actions_checkbox = checkbox
			if checkbox.text == tr("SETTINGS_CAMERA_SHAKE"):
				camera_shake_checkbox = checkbox
	_expect_true(has_notice, "settings explain that the current development build is intentionally silent")
	_expect_true(disabled_audio_sliders == 3, "music, ambient and interaction sliders are disabled in the silent build")
	_expect_true(desktop_music_disabled, "desktop music toggle is disabled in the silent build")
	_expect_true(has_reduce_motion, "settings expose the general reduced-motion preference")
	_expect_true(camera_shake_checkbox != null and camera_shake_checkbox.button_pressed == session.camera_shake_enabled, "settings expose an independent camera-shake preference")
	_expect_true(has_reduce_roaming, "settings expose an independent reduced desktop roaming preference")
	_expect_true(reduce_desktop_actions_checkbox != null and reduce_desktop_actions_checkbox.button_pressed == session.reduce_desktop_action_frequency, "settings expose the independent desktop action-frequency preference")
	_expect_true(bubble_slider != null and bubble_slider.editable and bubble_slider.min_value == 0.75 and bubble_slider.max_value == 2.0, "settings expose the full accessible bubble-duration range")
	var languages: OptionButton = ui.find_child("LanguageSelector", true, false) as OptionButton
	_expect_true(
		languages != null
			and languages.item_count == 3
			and languages.get_item_text(0) == tr("LANGUAGE_ZH_CN")
			and languages.get_item_text(1) == tr("LANGUAGE_ZH_TW")
			and languages.get_item_text(2) == tr("LANGUAGE_EN")
			and str(languages.get_item_metadata(0)) == "zh_CN"
			and str(languages.get_item_metadata(1)) == "zh_TW"
			and str(languages.get_item_metadata(2)) == "en",
		"settings language choices use localized copy while preserving stable locale metadata"
	)
	if bubble_slider != null:
		var previous_duration: float = float(session.bubble_duration_scale)
		bubble_slider.value = 1.65
		_expect_true(is_equal_approx(float(session.bubble_duration_scale), 1.65), "bubble-duration control updates the runtime hold-time scale")
		bubble_slider.value = previous_duration
	if camera_shake_checkbox != null:
		var previous_camera_shake: bool = session.camera_shake_enabled
		camera_shake_checkbox.button_pressed = not previous_camera_shake
		_expect_eq(session.camera_shake_enabled, not previous_camera_shake, "camera-shake control updates the runtime accessibility setting")
		camera_shake_checkbox.button_pressed = previous_camera_shake
	if reduce_desktop_actions_checkbox != null:
		var previous_action_frequency: bool = session.reduce_desktop_action_frequency
		reduce_desktop_actions_checkbox.button_pressed = not previous_action_frequency
		_expect_eq(session.reduce_desktop_action_frequency, not previous_action_frequency, "desktop action-frequency control updates the machine-local presentation setting")
		reduce_desktop_actions_checkbox.button_pressed = previous_action_frequency
	ui.call("_close_panel")
	await get_tree().process_frame


func _test_event_caption_duration(session: Node, ui: Control) -> void:
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var previous_duration: float = session.bubble_duration_scale
	var session_was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.call("_close_panel")
	var event: Dictionary = session.catalog.get_item("events", "event_move_in")
	var event_id: String = str(event.id)
	session.pig_state.tutorial_skipped = true
	if not event_id in session.pig_state.discovered_events:
		session.pig_state.discovered_events.append(event_id)
	if not event_id in session.pig_state.seen_events:
		session.pig_state.seen_events.append(event_id)
	session.pig_state.pending_events.erase(event_id)
	session.pig_state.summarized_events.erase(event_id)
	_expect_eq(session.save_game(), OK, "caption-duration fixture commits a valid watched event for reward-free replays")
	ui.call("_refresh")
	var native_duration: float = 0.0
	for step: Dictionary in event.get("steps", []):
		native_duration += float(step.duration)
	for scale_value: float in [0.75, 1.0, 2.0]:
		var label: String = "event caption duration scale=%s" % scale_value
		_expect_true(_press_visible_button_with_text(ui, tr("UI_SETTINGS")), "%s opens the production settings panel" % label)
		await get_tree().process_frame
		var slider: HSlider
		for node: Node in ui.find_children("*", "HSlider", true, false):
			var candidate := node as HSlider
			var row := candidate.get_parent() as HBoxContainer
			var row_label := row.get_child(0) as Label if row != null and row.get_child_count() > 0 else null
			if row_label != null and row_label.text == tr("SETTINGS_BUBBLE_TIME"):
				slider = candidate
				break
		_expect_true(slider != null and slider.editable, "%s exposes the real accessible text-duration slider" % label)
		if slider != null:
			slider.value = scale_value
			slider.drag_ended.emit(true)
		_expect_true(is_equal_approx(session.bubble_duration_scale, scale_value), "%s slider updates the production session" % label)
		_expect_true(is_equal_approx(float(session.save_service.load_settings().get("bubble_duration_scale", 0.0)), scale_value), "%s preference persists in machine settings" % label)
		ui.call("_close_panel")
		await get_tree().process_frame
		var before_state: Dictionary = session.pig_state.to_dict().duplicate(true)
		var before_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
		var before_director: Dictionary = session.event_director.to_dict().duplicate(true)
		_expect_true(await _press_album_event_action(ui, event, tr("ALBUM_REPLAY")), "%s starts through the real album replay button" % label)
		var viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
		var viewer: EventViewer = viewers[0] as EventViewer if not viewers.is_empty() else null
		_expect_true(viewer != null and not bool(viewer.get("_capture_photo")), "%s creates the live production reward-free viewer" % label)
		if viewer == null:
			continue
		viewer.set_process(false)
		var finish_count: Array[int] = [0]
		var photo_count: Array[int] = [0]
		viewer.finished.connect(func() -> void: finish_count[0] += 1)
		viewer.photo_captured.connect(func(_id: String, _image: Image) -> void: photo_count[0] += 1)
		var prepared: Dictionary = viewer.get("_event") as Dictionary
		var caption: Label
		for node: Node in viewer.find_children("*", "Label", true, false):
			var candidate := node as Label
			for key: String in prepared.get("variants", []):
				if candidate.text == tr(key):
					caption = candidate
		_expect_true(caption != null and caption.is_visible_in_tree() and not caption.text.is_empty(), "%s keeps the localized event subtitle visible" % label)
		_expect_true(prepared.get("steps", []) == event.get("steps", []) and native_duration >= 10.0 and native_duration <= 25.0, "%s retains the original content timeline and default event-duration budget" % label)
		var supplied_seconds: float = VisualFramePolicy.FRAME_STEP * 0.5
		viewer.call("_process", supplied_seconds)
		viewer.call("_process", supplied_seconds)
		supplied_seconds *= 2.0
		_expect_true(float(viewer.get("_last_visual_progress")) > 0.0, "%s preserves a real-time 10 FPS visual update rather than halving frame cadence for longer reading" % label)
		viewer.call("_process", native_duration * 0.25 - supplied_seconds)
		supplied_seconds = native_duration * 0.25
		var progress: ProgressBar = viewer.get("_progress") as ProgressBar
		_expect_true(progress != null and absf(progress.value - supplied_seconds / (native_duration * scale_value) * 100.0) <= 0.02, "%s advances the caption timeline according to the actual selected reading duration" % label)
		while supplied_seconds < native_duration * 0.5:
			viewer.call("_process", 0.25)
			supplied_seconds += 0.25
		var logical_remaining: float = supplied_seconds / scale_value
		var expected_step: int = 0
		var steps: Array = event.get("steps", []) as Array
		for step_index: int in steps.size() - 1:
			var step_duration: float = float((steps[step_index] as Dictionary).duration)
			if logical_remaining < step_duration:
				break
			logical_remaining -= step_duration
			expected_step += 1
		_expect_eq(int(viewer.get("_step_index")), expected_step, "%s keeps the event choreography synchronized with its subtitle timeline" % label)
		var finish_seconds: float = native_duration * scale_value
		while supplied_seconds + 0.25 < finish_seconds and not bool(viewer.get("_finished")):
			viewer.call("_process", 0.25)
			supplied_seconds += 0.25
		_expect_true(not bool(viewer.get("_finished")) and finish_count[0] == 0 and caption != null and caption.is_visible_in_tree(), "%s cannot remove the subtitle before its selected reading deadline" % label)
		if not bool(viewer.get("_finished")):
			viewer.call("_process", finish_seconds - supplied_seconds + 0.001)
		_expect_true(bool(viewer.get("_finished")), "%s finishes at the selected reading deadline rather than a fixed native deadline" % label)
		_expect_eq(finish_count[0], 1, "%s completes exactly once at the chosen text duration" % label)
		_expect_eq(photo_count[0], 0, "%s reward-free replay never captures a new photo" % label)
		_expect_true(session.pig_state.to_dict() == before_state and session.simulation.to_dict() == before_simulation and session.event_director.to_dict() == before_director, "%s presentation timing does not mutate progression, current behavior, or event cooldowns" % label)
		if not bool(viewer.get("_finished")):
			_press_event_skip(viewer)
		viewer.call("_process", 0.5)
		_expect_eq(finish_count[0], 1, "%s remains idempotent after automatic completion or explicit skip" % label)
		await get_tree().process_frame
		await get_tree().process_frame
	session.pig_state.load_dict(previous_state)
	session.set_bubble_duration_scale(previous_duration)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(session_was_processing)
	ui.call("_refresh")


func _test_deferred_offline_summary(session: Node, ui: Control) -> void:
	var previous_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_behavior_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_event_director: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_clock: GameClock = session.clock
	var previous_autosave_elapsed: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_last_process_unix: int = int(session.get("_last_process_unix"))
	var frame_time: Array[int] = [GameClock.now_unix() - 3600]
	session.clock = GameClock.new(func() -> int: return frame_time[0])
	session.pig_state.familiarity_xp = 0
	session.pig_state.familiarity_level = 1
	session.simulation.invite_behavior(session.catalog.get_item("behaviors", "behavior_idle_stand"), false)
	session.simulation.remaining_seconds = 0.5
	session.set("_event_elapsed", 0.0)
	session.set("_last_process_unix", frame_time[0])
	_expect_eq(session.save_game(), OK, "offline-summary fixture commits its pre-resume time anchor")
	var points_before: int = session.pig_state.daily_points
	var summary_notifications: Array[Dictionary] = []
	var summary_listener: Callable = func(summary: Dictionary) -> void:
		summary_notifications.append(summary.duplicate(true))
		session.set_process(false)
	session.offline_summary_ready.connect(summary_listener)
	_expect_true(_press_visible_button_with_text(ui, tr("UI_SETTINGS")), "the real settings entry opens before runtime recovery")
	frame_time[0] += 3600
	session.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	session.set_process(false)
	_expect_eq(summary_notifications.size(), 1, "a real runtime recovery frame emits exactly one offline summary")
	_expect_eq(session.pig_state.daily_points, points_before + 13, "the real runtime recovery frame grants the one-hour point reward")
	_expect_eq(session.pig_state.familiarity_xp, 2, "the real runtime recovery frame grants one-hour familiarity without interaction")
	_expect_eq(session.simulation.remaining_seconds, 0.5, "the real runtime recovery frame preserves a nearly finished foreground behavior")
	_expect_eq(int(session.get("_last_process_unix")), frame_time[0], "the real runtime recovery frame advances its clock anchor")
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.save_service.save_path)) as Dictionary
	_expect_true(
		int(persisted.get("last_saved_unix", 0)) == frame_time[0]
			and int((persisted.get("pig_state", {}) as Dictionary).get("daily_points", 0)) == points_before + 13
			and int((persisted.get("pig_state", {}) as Dictionary).get("familiarity_xp", 0)) == 2,
		"the completed runtime recovery frame commits both rewards with the consumed time anchor"
	)
	var panel_title: Label = ui.get("_panel_title") as Label
	_expect_true(
		panel_title != null
			and panel_title.text == tr("UI_SETTINGS")
			and not (ui.get("_pending_offline_summary") as Dictionary).is_empty(),
		"runtime resume queues its offline summary without replacing an open panel"
	)
	_expect_true(_press_visible_button_with_text(ui, tr("UI_CLOSE")), "the real settings close button releases the queued summary")
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	_expect_true(overlay != null and overlay.visible and panel_title.text == tr("OFFLINE_TITLE"), "queued offline summary appears after the active panel closes")
	var expected_message: String = tr("OFFLINE_SHORT").format({"hours":1.0, "points":13})
	var message_rendered: bool = false
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		message_rendered = message_rendered or (label != null and label.text == expected_message)
	_expect_true(message_rendered, "deferred offline summary renders the settled time and reward")
	_expect_true(_press_visible_button_with_text(ui, tr("UI_CLOSE")), "the real summary close button consumes the first recovery notice")
	await get_tree().process_frame
	_expect_true(overlay != null and not overlay.visible, "deferred offline summary is consumed exactly once")

	_expect_true(_press_visible_button_with_text(ui, tr("UI_SETTINGS")), "the real settings entry opens before a second runtime recovery")
	frame_time[0] += 3600
	session.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	session.set_process(false)
	_expect_eq(summary_notifications.size(), 2, "a second real runtime recovery produces one new summary rather than replaying the first")
	_expect_eq(session.pig_state.daily_points, points_before + 26, "two real one-hour recoveries settle each interval exactly once")
	_expect_eq(session.pig_state.familiarity_xp, 4, "two real one-hour recoveries do not duplicate familiarity")
	_expect_eq(session.simulation.remaining_seconds, 0.5, "repeated runtime recovery still preserves the active behavior timer")
	_expect_eq(int(session.get("_last_process_unix")), frame_time[0], "the second runtime recovery advances the same production clock anchor")
	persisted = JSON.parse_string(FileAccess.get_file_as_string(session.save_service.save_path)) as Dictionary
	_expect_true(
		int(persisted.get("last_saved_unix", 0)) == frame_time[0]
			and int((persisted.get("pig_state", {}) as Dictionary).get("daily_points", 0)) == points_before + 26
			and int((persisted.get("pig_state", {}) as Dictionary).get("familiarity_xp", 0)) == 4,
		"the second runtime recovery commits only its additional interval"
	)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame
	overlay = ui.get("_overlay") as ColorRect
	panel_title = ui.get("_panel_title") as Label
	_expect_true(
		overlay != null and overlay.visible and panel_title != null and panel_title.text == tr("OFFLINE_TITLE"),
		"UI rebuild displays a queued offline summary instead of stranding it"
	)
	_expect_true(_press_visible_button_with_text(ui, tr("UI_CLOSE")), "the rebuilt real UI keeps its summary close action reachable")
	await get_tree().process_frame
	_expect_true(
		overlay != null and not overlay.visible and (ui.get("_pending_offline_summary") as Dictionary).is_empty(),
		"offline summary queued across UI rebuild is consumed exactly once"
	)
	session.offline_summary_ready.disconnect(summary_listener)
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior_director)
	session.event_director.load_dict(previous_event_director)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.clock = previous_clock
	_expect_eq(session.save_game(), OK, "offline-summary fixture restores its original progression and real time anchor")
	session.set("_autosave_elapsed", previous_autosave_elapsed)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set("_last_process_unix", previous_last_process_unix)
	session.simulation.announce_current_behavior()
	ui.call("_refresh")
	session.set_process(previous_processing)


func _test_offline_summary_event_playback(session: Node, ui: Control) -> void:
	var previous_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_behavior_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_event_director: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_clock: GameClock = session.clock
	var previous_autosave_elapsed: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_last_process_unix: int = int(session.get("_last_process_unix"))
	var event: Dictionary = session.catalog.get_item("events", "event_move_in")
	var photo_path: String = "%s/photos/%s.png" % [session.save_service.base_dir, str(event.get("photo_id", ""))]
	var previous_photo_exists: bool = FileAccess.file_exists(photo_path)
	var previous_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if previous_photo_exists else PackedByteArray()
	var frame_time: Array[int] = [GameClock.now_unix() - 7200]
	session.clock = GameClock.new(func() -> int: return frame_time[0])
	var fixture := PigState.new()
	fixture.tutorial_skipped = true
	fixture.discovered_events = ["event_move_in"]
	fixture.pending_events = ["event_move_in"]
	session.pig_state.load_dict(fixture.to_dict())
	session.behavior_director.load_dict({})
	session.event_director.load_dict({})
	session.simulation.invite_behavior(session.catalog.get_item("behaviors", "behavior_idle_stand"), false)
	session.simulation.remaining_seconds = 0.5
	ui.set("_pending_offline_summary", {})
	ui.call("_close_panel")
	var summaries: Array[Dictionary] = []
	var summary_listener: Callable = func(summary: Dictionary) -> void:
		summaries.append(summary.duplicate(true))
		session.set_process(false)
	session.offline_summary_ready.connect(summary_listener)
	for grant_rewards: bool in [true, false]:
		var label: String = "first viewing" if grant_rewards else "album replay"
		session.set("_last_process_unix", frame_time[0])
		session.set("_event_elapsed", 0.0)
		_expect_eq(session.save_game(), OK, "%s event-resume fixture saves a real time anchor" % label)
		var original_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if FileAccess.file_exists(photo_path) else PackedByteArray()
		var original_photo_record: Dictionary = (session.pig_state.life_photos.get("event_move_in", {}) as Dictionary).duplicate(true)
		var action_text: String = tr("ALBUM_WATCH" if grant_rewards else "ALBUM_REPLAY")
		_expect_true(await _press_album_event_action(ui, event, action_text), "%s starts through the actual album action" % label)
		var viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
		var viewer: EventViewer = viewers[0] as EventViewer if viewers.size() == 1 else null
		_expect_true(viewer != null and bool(viewer.get("_capture_photo")) == grant_rewards, "%s owns one correctly configured production viewer" % label)
		if viewer == null:
			continue
		viewer.set_process(false)
		var stage: EventStage = viewer.get("_stage") as EventStage
		stage.set_process(false)
		viewer.call("_apply_step", (viewer.get("_steps") as Array).size() - 1)
		stage.set_step_progress(0.72)
		stage.set("_phase", 0.0)
		var captured_images: Array[Image] = []
		var completions: Array[bool] = []
		viewer.photo_captured.connect(func(_event_id: String, image: Image) -> void: captured_images.append(image.duplicate()))
		viewer.finished.connect(func() -> void: completions.append(true))
		await RenderingServer.frame_post_draw
		var reference: Image = _event_stage_pixels(stage)
		reference.convert(Image.FORMAT_RGBA8)
		if grant_rewards:
			reference.save_png("user://event-summary-reference.png")
		var points_before: int = session.pig_state.daily_points
		var familiarity_before: int = session.pig_state.familiarity_xp
		frame_time[0] += 3600
		session.set_process(true)
		await get_tree().process_frame
		await get_tree().process_frame
		session.set_process(false)
		_expect_eq(summaries.size(), 1 if grant_rewards else 2, "%s recovery emits one summary rather than repeated notifications" % label)
		_expect_eq(session.pig_state.daily_points, points_before + 13, "%s recovery retains the normal one-hour offline reward" % label)
		_expect_eq(session.pig_state.familiarity_xp, familiarity_before + 2, "%s recovery retains the normal one-hour familiarity" % label)
		_expect_eq(session.simulation.remaining_seconds, 0.5, "%s recovery does not advance the foreground behavior twice" % label)
		var overlay: ColorRect = ui.get("_overlay") as ColorRect
		_expect_true(not overlay.visible, "%s recovery cannot cover the active event with a summary panel" % label)
		_expect_true(not (ui.get("_pending_offline_summary") as Dictionary).is_empty(), "%s recovery keeps its summary queued until the event closes" % label)
		ui.call_deferred("_show_pending_offline_summary")
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not overlay.visible and not (ui.get("_pending_offline_summary") as Dictionary).is_empty(), "%s deferred summary callback cannot bypass active playback" % label)
		await RenderingServer.frame_post_draw
		var resumed_pixels: Image = _event_stage_pixels(stage)
		resumed_pixels.convert(Image.FORMAT_RGBA8)
		_expect_true(resumed_pixels.get_data() == reference.get_data(), "%s recovery preserves every visible stage pixel" % label)
		if grant_rewards:
			resumed_pixels.save_png("user://event-summary-resumed.png")
		var recovered_state: Dictionary = session.pig_state.to_dict().duplicate(true)
		var recovered_director: Dictionary = session.event_director.to_dict().duplicate(true)
		var skip: Button = viewer.find_child("EventSkipButton", true, false) as Button
		_expect_true(skip != null and skip.text == tr("EVENT_SKIP"), "%s closes through the actual localized event skip action" % label)
		_press_event_skip(viewer)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_eq(completions.size(), 1, "%s finishes once before releasing the queued summary" % label)
		_expect_true(ui.find_children("*", "EventViewer", true, false).is_empty(), "%s releases the finished viewer before showing the summary" % label)
		var title: Label = ui.get("_panel_title") as Label
		_expect_true(overlay.visible and title.text == tr("OFFLINE_TITLE"), "%s queued summary becomes reachable immediately after event completion" % label)
		_expect_true((ui.get("_pending_offline_summary") as Dictionary).is_empty(), "%s consumes the queued summary once" % label)
		if grant_rewards:
			_expect_eq(captured_images.size(), 1, "first viewing still captures exactly one automatic photo")
			if not captured_images.is_empty():
				captured_images[0].convert(Image.FORMAT_RGBA8)
				_expect_true(captured_images[0].get_data() == reference.get_data(), "automatic event photo excludes the deferred recovery interface")
			var stored: Image = Image.load_from_file(ProjectSettings.globalize_path(photo_path))
			_expect_true(stored != null and not stored.is_empty(), "first viewing commits its real automatic PNG after recovery")
			if stored != null and not stored.is_empty():
				stored.convert(Image.FORMAT_RGBA8)
				_expect_true(stored.get_data() == reference.get_data(), "committed life-photo pixels exclude the deferred recovery interface")
			_expect_true("event_move_in" in session.pig_state.seen_events and not "event_move_in" in session.pig_state.pending_events, "first viewing consumes only its completed pending memory")
			var rewards: Dictionary = event.get("rewards", {}) as Dictionary
			_expect_eq(session.pig_state.daily_points, int(recovered_state.get("daily_points", 0)) + int(rewards.get("points", 0)) + (rewards.get("expressions", []) as Array).size() * 10, "first viewing grants event and first-expression points once")
			_expect_eq(session.pig_state.familiarity_xp, int(recovered_state.get("familiarity_xp", 0)) + int(rewards.get("familiarity", 0)), "first viewing grants event familiarity once")
		else:
			_expect_eq(captured_images.size(), 0, "album replay still does not capture an automatic photo after recovery")
			_expect_eq(session.pig_state.to_dict(), recovered_state, "album replay preserves all already settled progress and collections")
			_expect_eq(session.event_director.to_dict(), recovered_director, "album replay preserves the already settled event history and cooldowns")
			_expect_eq(FileAccess.get_file_as_bytes(photo_path), original_photo_bytes, "album replay preserves the original photo bytes after recovery")
			_expect_eq(session.pig_state.life_photos.get("event_move_in", {}), original_photo_record, "album replay preserves the original photo record after recovery")
		var committed_state: Dictionary = session.pig_state.to_dict().duplicate(true)
		var committed_director: Dictionary = session.event_director.to_dict().duplicate(true)
		var committed_save: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
		_expect_true(_press_visible_button_with_text(ui, tr("UI_CLOSE")), "%s deferred summary closes through its actual button" % label)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not overlay.visible and (ui.get("_pending_offline_summary") as Dictionary).is_empty(), "%s closed summary does not reappear" % label)
		_expect_eq(session.pig_state.to_dict(), committed_state, "%s reading the summary cannot repeat settled progression" % label)
		_expect_eq(session.event_director.to_dict(), committed_director, "%s reading the summary cannot repeat event discovery" % label)
		_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), committed_save, "%s reading the summary cannot rotate the committed save" % label)
	session.offline_summary_ready.disconnect(summary_listener)
	if previous_photo_exists:
		var restored_photo := FileAccess.open(photo_path, FileAccess.WRITE)
		restored_photo.store_buffer(previous_photo_bytes)
		restored_photo.close()
	elif FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior_director)
	session.event_director.load_dict(previous_event_director)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.clock = previous_clock
	ui.set("_pending_offline_summary", {})
	ui.call("_close_panel")
	_expect_eq(session.save_game(), OK, "event-resume fixture restores its original progression and time anchor")
	session.set("_autosave_elapsed", previous_autosave_elapsed)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set("_last_process_unix", previous_last_process_unix)
	session.simulation.announce_current_behavior()
	ui.call("_refresh")
	session.set_process(previous_processing)


func _event_stage_pixels(stage: EventStage) -> Image:
	var viewport_image: Image = stage.get_viewport().get_texture().get_image()
	var viewport_size: Vector2 = stage.get_viewport_rect().size
	var scale := Vector2(float(viewport_image.get_width()) / viewport_size.x, float(viewport_image.get_height()) / viewport_size.y)
	var frame_rect: Rect2 = (stage.get_parent() as Control).get_global_rect()
	var clip_start: Vector2 = frame_rect.position.ceil()
	var clip_end: Vector2 = frame_rect.end.floor()
	var stage_rect: Rect2 = stage.get_global_rect().intersection(Rect2(clip_start, clip_end - clip_start))
	var first_pixel := Vector2i((stage_rect.position * scale).ceil())
	var last_pixel := Vector2i((stage_rect.end * scale).floor())
	var pixels := Rect2i(first_pixel, last_pixel - first_pixel)
	return viewport_image.get_region(pixels)


func _test_exit_choice(main: Node, session: Node, ui: Control) -> void:
	var previous_level: int = session.pig_state.familiarity_level
	session.pig_state.familiarity_level = 1
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame
	var keep_desktop: Button = ui.find_child("ExitKeepDesktopButton", true, false) as Button
	var exit_all: Button = ui.find_child("ExitAllButton", true, false) as Button
	var cancel: Button = ui.find_child("ExitCancelButton", true, false) as Button
	_expect_true(keep_desktop != null and keep_desktop.disabled, "close-window choice keeps desktop mode locked before familiarity two")
	_expect_true(exit_all != null and cancel != null, "close-window choice exposes full exit and cancellation without quitting immediately")
	session.pig_state.familiarity_level = 2
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame
	keep_desktop = ui.find_child("ExitKeepDesktopButton", true, false) as Button
	var keep_desktop_available: bool = keep_desktop != null and not keep_desktop.disabled
	if keep_desktop != null:
		keep_desktop.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var controller_nodes: Array[Node] = main.find_children("*", "DesktopWindowController", true, false)
	var controller: DesktopWindowController = controller_nodes[0] as DesktopWindowController if not controller_nodes.is_empty() else null
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	var room_button: Button
	if controller != null:
		for node: Node in controller.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == tr("DESKTOP_ROOM"):
				room_button = button
				break
	_expect_true(
		keep_desktop_available
			and controller != null
			and controller.active
			and overlay != null
			and not overlay.visible
			and room_button != null,
		"the real close-window choice leaves the unlocked pig on the desktop with a room-return action"
	)
	if room_button != null:
		room_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame
	cancel = ui.find_child("ExitCancelButton", true, false) as Button
	if cancel != null:
		cancel.pressed.emit()
		await get_tree().process_frame
		_expect_true(controller != null and not controller.active and overlay != null and not overlay.visible, "close-window choice can return from desktop and be cancelled safely")
	var normal_temp_path: String = session.save_service.temp_path
	var blocker_path: String = session.save_service.base_dir + "/exit_checkpoint_blocker"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	_expect_true(blocker != null, "exit failure UI fixture creates a file that blocks the progression temp path")
	if blocker != null:
		blocker.store_string("block child paths")
		blocker.close()
	session.save_service.temp_path = blocker_path + "/savegame.tmp.json"
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame
	exit_all = ui.find_child("ExitAllButton", true, false) as Button
	var exit_action_available: bool = exit_all != null and exit_all.is_inside_tree()
	if exit_all != null:
		exit_all.pressed.emit()
	await get_tree().process_frame
	_expect_true(exit_action_available and main.is_inside_tree(), "the real window-close exit action keeps the rendered game running when its checkpoint fails")
	await get_tree().process_frame
	var failure_overlay: ColorRect = ui.get("_overlay") as ColorRect
	var failure_title: Label = ui.get("_panel_title") as Label
	_expect_true(
		failure_overlay != null
			and failure_overlay.visible
			and failure_title != null
			and failure_title.text == tr("EXIT_SAVE_FAILED_TITLE")
			and _count_labels_with_text(ui, tr("EXIT_SAVE_FAILED_MESSAGE")) == 1,
		"main exit-failure handling shows the localized title and storage guidance"
	)
	var retry: Button = ui.find_child("ExitRetryButton", true, false) as Button
	var exit_without_saving: Button = ui.find_child("ExitWithoutSavingButton", true, false) as Button
	var failure_cancel: Button = ui.find_child("ExitFailureCancelButton", true, false) as Button
	_expect_true(retry != null and retry.text == tr("EXIT_RETRY"), "exit failure panel exposes a localized retry action")
	_expect_true(
		exit_without_saving != null and exit_without_saving.text == tr("EXIT_WITHOUT_SAVING"),
		"exit failure panel exposes an explicit localized exit-without-saving action"
	)
	_expect_true(failure_cancel != null and failure_cancel.text == tr("EXIT_CANCEL"), "exit failure panel exposes a localized cancellation action")
	session.save_service.temp_path = normal_temp_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	if failure_cancel != null:
		failure_cancel.pressed.emit()
	await get_tree().process_frame
	_expect_true(failure_overlay != null and not failure_overlay.visible, "exit save failure can be cancelled without retrying or quitting")
	session.pig_state.familiarity_level = previous_level
	ui.call("_refresh")


func _test_main_window_mode_switch(session: Node, ui: Control) -> void:
	var original_size: Vector2i = DisplayServer.window_get_size()
	var original_position: Vector2i = DisplayServer.window_get_position()
	_press_visible_button_with_text(ui, tr("UI_SETTINGS"))
	await get_tree().process_frame
	var fullscreen_checkbox: CheckBox
	for node: Node in ui.find_children("*", "CheckBox", true, false):
		var checkbox := node as CheckBox
		if checkbox != null and checkbox.text == tr("SETTINGS_FULLSCREEN"):
			fullscreen_checkbox = checkbox
			break
	_expect_true(
		fullscreen_checkbox != null
			and not fullscreen_checkbox.button_pressed
			and not session.main_window_fullscreen
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
		"settings expose the real main window in its initial windowed state"
	)
	if fullscreen_checkbox == null:
		ui.call("_close_panel")
		return

	fullscreen_checkbox.button_pressed = true
	for _enter_frame: int in 10:
		await get_tree().process_frame
		if DisplayServer.window_get_mode() in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]:
			break
	var fullscreen_settings: Dictionary = session.save_service.load_settings()
	if OS.has_feature("macos"):
		await get_tree().create_timer(MACOS_FULLSCREEN_SETTLE_SECONDS).timeout
	_expect_true(
		fullscreen_checkbox.button_pressed
			and session.main_window_fullscreen
			and DisplayServer.window_get_mode() in [
				DisplayServer.WINDOW_MODE_FULLSCREEN,
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
			]
			and bool(fullscreen_settings.get("main_window_fullscreen", false)),
		"fullscreen settings control switches the production window and persists the enabled state"
	)
	var fullscreen_size_value: Variant = fullscreen_settings.get("main_window_size", {})
	var fullscreen_position_value: Variant = fullscreen_settings.get("main_window_position", {})
	var fullscreen_size: Dictionary = fullscreen_size_value as Dictionary if fullscreen_size_value is Dictionary else {}
	var fullscreen_position: Dictionary = fullscreen_position_value as Dictionary if fullscreen_position_value is Dictionary else {}
	_expect_true(
		int(fullscreen_size.get("x", -1)) == original_size.x
			and int(fullscreen_size.get("y", -1)) == original_size.y
			and int(fullscreen_position.get("x", -32769)) == original_position.x
			and int(fullscreen_position.get("y", -32769)) == original_position.y,
		"entering fullscreen preserves the previous windowed size and position in machine settings"
	)

	fullscreen_checkbox.button_pressed = false
	for _leave_frame: int in 12:
		await get_tree().process_frame
		var current_size: Vector2i = DisplayServer.window_get_size()
		var current_position: Vector2i = DisplayServer.window_get_position()
		if (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
				and absi(current_size.x - original_size.x) <= 2
				and absi(current_size.y - original_size.y) <= 2
				and absi(current_position.x - original_position.x) <= 2
				and absi(current_position.y - original_position.y) <= 2
		):
			break
	var restored_settings: Dictionary = session.save_service.load_settings()
	if OS.has_feature("macos"):
		await get_tree().create_timer(MACOS_FULLSCREEN_SETTLE_SECONDS).timeout
	_expect_true(
		not fullscreen_checkbox.button_pressed
			and not session.main_window_fullscreen
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
			and not bool(restored_settings.get("main_window_fullscreen", true)),
		"fullscreen settings control returns the production window to windowed mode and persists the cleared state"
	)
	var restored_size: Vector2i = DisplayServer.window_get_size()
	var restored_position: Vector2i = DisplayServer.window_get_position()
	_expect_true(
		absi(restored_size.x - original_size.x) <= 2
			and absi(restored_size.y - original_size.y) <= 2
			and absi(restored_position.x - original_position.x) <= 2
			and absi(restored_position.y - original_position.y) <= 2,
		"returning to windowed mode restores the previous native size and position"
	)
	ui.call("_close_panel")
	await get_tree().process_frame


func _test_minimum_window_overlays(session: Node, ui: Control) -> void:
	get_window().size = GameSession.MAIN_WINDOW_MIN_SIZE
	session.set("ui_scale", 1.0)
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_rect := Rect2(Vector2.ZERO, ui.size)
	_expect_eq(DisplayServer.window_get_min_size(), GameSession.MAIN_WINDOW_MIN_SIZE, "main window publishes the real 960x540 resize floor")
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree():
			_expect_true(_rect_inside(viewport_rect, button.get_global_rect()), "main HUD button is fully visible at 960x540: %s" % button.text)

	var settings_button: Button = ui.find_child("SettingsButton", true, false) as Button
	_expect_true(settings_button != null and settings_button.is_visible_in_tree(), "the real settings HUD action remains reachable at 960x540")
	if settings_button != null:
		settings_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: PanelContainer = ui.get("_panel") as PanelContainer
	var panel_scroll: ScrollContainer = ui.get("_panel_scroll") as ScrollContainer
	_expect_true(panel != null and _rect_inside(viewport_rect, panel.get_global_rect()), "settings panel fits entirely inside 960x540")
	var legal_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("SETTINGS_LEGAL"):
			legal_button = button
			break
	_expect_true(panel_scroll != null and legal_button != null, "settings retain their scroll viewport and final legal action at 960x540")
	if panel_scroll != null and legal_button != null:
		panel_scroll.ensure_control_visible(legal_button)
		await get_tree().process_frame
		_expect_true(panel_scroll.get_global_rect().intersects(legal_button.get_global_rect()), "the final settings action remains reachable by scrolling at 960x540")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-settings.png")

	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	session.pig_state.name = ""
	session.pig_state.tutorial_step = 7
	session.pig_state.tutorial_skipped = true
	var help_button: Button = ui.find_child("SettingsHelpButton", true, false) as Button
	if panel_scroll != null and help_button != null:
		panel_scroll.ensure_control_visible(help_button)
		await get_tree().process_frame
	_expect_true(
		panel_scroll != null
			and help_button != null
			and panel_scroll.get_global_rect().intersects(help_button.get_global_rect()),
		"the settings help action remains reachable by scrolling at 960x540"
	)
	if help_button != null:
		help_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	panel_scroll = ui.get("_panel_scroll") as ScrollContainer
	var replay_button: Button = ui.find_child("HelpReplayTutorialButton", true, false) as Button
	if panel_scroll != null and replay_button != null:
		panel_scroll.ensure_control_visible(replay_button)
		await get_tree().process_frame
	_expect_true(
		panel_scroll != null
			and replay_button != null
			and replay_button.text == tr("HELP_REPLAY_NAMING")
			and panel_scroll.get_global_rect().intersects(replay_button.get_global_rect()),
		"the unnamed help replay action remains reachable by scrolling at 960x540"
	)
	if replay_button != null:
		replay_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	panel = ui.get("_panel") as PanelContainer
	panel_scroll = ui.get("_panel_scroll") as ScrollContainer
	var name_input: LineEdit = ui.find_child("NameInput", true, false) as LineEdit
	var name_confirm: Button = ui.find_child("NameConfirmButton", true, false) as Button
	var name_skip: Button = ui.find_child("NameSkipTutorialButton", true, false) as Button
	if panel_scroll != null and name_skip != null:
		panel_scroll.ensure_control_visible(name_skip)
		await get_tree().process_frame
	_expect_true(
		panel != null
			and _rect_inside(viewport_rect, panel.get_global_rect())
			and name_input != null
			and name_confirm != null
			and name_skip != null
			and panel_scroll != null
			and panel_scroll.get_global_rect().intersects(name_skip.get_global_rect()),
		"unnamed help replay keeps every naming control scroll-reachable inside 960x540"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-help-naming-replay.png")
	if name_skip != null:
		name_skip.pressed.emit()
	await get_tree().process_frame
	session.pig_state.load_dict(previous_pig_state)
	session.save_game()
	ui.call("_refresh")
	ui.call("_close_panel")

	ui.show_exit_save_failure()
	await get_tree().process_frame
	await get_tree().process_frame
	panel = ui.get("_panel") as PanelContainer
	var exit_failure_fits: bool = panel != null and _rect_inside(viewport_rect, panel.get_global_rect())
	for button_name: String in ["ExitRetryButton", "ExitWithoutSavingButton", "ExitFailureCancelButton"]:
		var exit_button: Button = ui.find_child(button_name, true, false) as Button
		exit_failure_fits = exit_failure_fits and exit_button != null and _rect_inside(viewport_rect, exit_button.get_global_rect())
	_expect_true(exit_failure_fits, "exit save failure panel and all recovery actions fit entirely inside 960x540")
	ui.call("_close_panel")

	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	panel = ui.get("_panel") as PanelContainer
	_expect_true(panel != null and _rect_inside(viewport_rect, panel.get_global_rect()), "album panel fits entirely inside 960x540")
	var tab_nodes: Array[Node] = ui.find_children("*", "TabContainer", true, false)
	var tabs: TabContainer = tab_nodes[0] as TabContainer if not tab_nodes.is_empty() else null
	var album_scrolls: Array[Node] = tabs.find_children("*", "ScrollContainer", true, false) if tabs != null else []
	_expect_true(
		tabs != null and panel_scroll != null and tabs.size.y <= 480.0 and panel_scroll.get_global_rect().intersects(tabs.get_global_rect()),
		"album tabs remain inside the panel's scrollable body at the minimum window"
	)
	_expect_true(not album_scrolls.is_empty(), "album pages retain nested scrolling at the minimum window")
	if not album_scrolls.is_empty():
		var album_scroll := album_scrolls[0] as ScrollContainer
		_expect_true(album_scroll.get_v_scroll_bar().max_value > album_scroll.get_v_scroll_bar().page, "the expression collection can scroll through all cards at 960x540")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-album.png")
	ui.call("_close_panel")

	var sample := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	sample.fill(Color("#d9879b"))
	ui.call("_show_photo_lightbox", sample)
	await get_tree().process_frame
	await get_tree().process_frame
	var lightbox: ColorRect = ui.get("_photo_lightbox") as ColorRect
	var framed_nodes: Array[Node] = lightbox.find_children("*", "PanelContainer", true, false) if lightbox != null else []
	var framed: PanelContainer = framed_nodes[0] as PanelContainer if not framed_nodes.is_empty() else null
	_expect_true(framed != null and _rect_inside(viewport_rect, framed.get_global_rect()), "album photo lightbox fits entirely inside 960x540")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-photo.png")
	ui.call("_close_photo_lightbox")

	var viewer: Control = EventViewerScript.new()
	var event: Dictionary = session.get("catalog").get_item("events", "event_rainy_window")
	viewer.call("play", event, false)
	ui.add_child(viewer)
	await get_tree().process_frame
	await get_tree().process_frame
	var event_panel: PanelContainer = viewer.find_child("EventPanel", true, false) as PanelContainer
	var skip: Button = viewer.find_child("EventSkipButton", true, false) as Button
	var stage_nodes: Array[Node] = viewer.find_children("*", "EventStage", true, false)
	var stage: Control = stage_nodes[0] as Control if not stage_nodes.is_empty() else null
	_expect_true(event_panel != null and _rect_inside(viewport_rect, event_panel.get_global_rect()), "event viewer panel fits entirely inside 960x540")
	_expect_true(skip != null and _rect_inside(viewport_rect, skip.get_global_rect()), "event skip control remains fully reachable at 960x540")
	_expect_true(stage != null and _rect_inside(viewport_rect, stage.get_global_rect()), "event staging remains visible at 960x540")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-event-viewer.png")
	viewer.queue_free()
	await get_tree().process_frame

	var previous_demo_discovered_events: Array[String] = session.pig_state.discovered_events.duplicate()
	var previous_demo_seen_events: Array[String] = session.pig_state.seen_events.duplicate()
	var previous_demo_completion_seen: bool = session.pig_state.demo_completion_seen
	var completed_demo_event_ids: Array[String] = []
	for demo_event: Dictionary in session.catalog.events:
		completed_demo_event_ids.append(str(demo_event.get("id", "")))
	session.pig_state.discovered_events = completed_demo_event_ids.duplicate()
	session.pig_state.seen_events = completed_demo_event_ids.duplicate()
	session.pig_state.demo_completion_seen = false
	ui.call("_show_demo_complete_for_profile", "demo")
	await get_tree().process_frame
	await get_tree().process_frame
	panel = ui.get("_panel") as PanelContainer
	var demo_grid: GridContainer = ui.find_child("DemoLockedExpressionSilhouettes", true, false) as GridContainer
	var demo_portraits: Array[Node] = demo_grid.find_children("*", "ExpressionPortrait", true, false) if demo_grid != null else []
	_expect_true(panel != null and _rect_inside(viewport_rect, panel.get_global_rect()), "Demo completion panel fits entirely inside 960x540")
	_expect_true(
		demo_grid != null
			and demo_grid.columns == MainUI.DEMO_LOCKED_EXPRESSION_PREVIEW_COUNT
			and demo_portraits.size() == MainUI.DEMO_LOCKED_EXPRESSION_PREVIEW_COUNT,
		"Demo completion presents a real grid of locked album silhouettes"
	)
	var all_locked: bool = not demo_portraits.is_empty()
	for node: Node in demo_portraits:
		var portrait := node as ExpressionPortrait
		all_locked = all_locked and portrait != null and not portrait.unlocked
	_expect_true(all_locked, "Demo album preview keeps every teased expression visibly locked")
	var demo_buttons: Array[Node] = panel.find_children("*", "Button", true, false) if panel != null else []
	var continue_buttons: int = 0
	var continue_button: Button
	for node: Node in demo_buttons:
		var button := node as Button
		if button != null and button.text == tr("DEMO_CONTINUE"):
			continue_buttons += 1
			continue_button = button
	_expect_true(continue_buttons == 1 and demo_buttons.size() == 2, "Demo completion offers continue and close without a duplicate purchase prompt")
	_expect_true(continue_button != null and not continue_button.disabled, "Demo completion keeps the continue action enabled")
	if continue_button != null:
		continue_button.grab_focus()
		await get_tree().process_frame
		_expect_eq(continue_button.get_theme_color("font_focus_color"), ThemeFactory.INK, "focused Demo action retains readable dark text")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/960x540-demo-complete.png")
	if continue_button != null:
		continue_button.pressed.emit()
		await get_tree().process_frame
	_expect_true(
		(demo_grid == null or not demo_grid.is_inside_tree()) and session.pig_state.demo_completion_seen,
		"Demo continue action commits the acknowledgement and leaves the completion page"
	)
	ui.call("_close_panel")
	session.pig_state.discovered_events = previous_demo_discovered_events
	session.pig_state.seen_events = previous_demo_seen_events
	session.pig_state.demo_completion_seen = previous_demo_completion_seen
	session.save_game()
	await get_tree().process_frame


func _test_desktop_control_visibility_recovery(controller: DesktopWindowController, session: Node, room_button: Button, menu_button: MenuButton) -> void:
	var usable_rects: Array[Rect2i] = []
	var rightmost := Rect2i()
	for screen: int in DisplayServer.get_screen_count():
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
		usable_rects.append(usable)
		if usable_rects.size() == 1 or usable.end.x > rightmost.end.x:
			rightmost = usable
	var window_size: Vector2i = DisplayServer.window_get_size()
	var original_scale: float = controller.scale_factor
	var original_dock: String = controller.dock
	var was_processing: bool = controller.is_processing()
	controller.set_process(false)
	DisplayServer.window_set_position(Vector2i(rightmost.end.x - 120, rightmost.position.y + maxi((rightmost.size.y - window_size.y) / 2, 0)))
	await get_tree().process_frame
	await get_tree().process_frame
	var clipped_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var body_overlap: Rect2i = clipped_rect.intersection(rightmost)
	_expect_true(body_overlap.size.x >= 96 and body_overlap.size.y >= 64, "native desktop recovery fixture leaves a substantial visible pig/window region")
	_expect_true(not DesktopFramePolicy.window_has_accessible_region(clipped_rect, usable_rects), "native desktop recovery detects off-screen return/menu controls despite visible window pixels")
	controller.call("_ensure_visible")
	await get_tree().process_frame
	await get_tree().process_frame
	var recovered_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	_expect_true(recovered_rect.position != clipped_rect.position and DesktopFramePolicy.window_has_accessible_region(recovered_rect, usable_rects), "production desktop visibility recovery relocates the real native window to accessible controls")
	var buttons_visible: bool = room_button != null and menu_button != null
	for button: Button in [room_button, menu_button]:
		var on_screen: bool = false
		if button != null:
			var button_rect := Rect2(Vector2(recovered_rect.position) + button.get_global_rect().position, button.get_global_rect().size)
			for usable: Rect2i in usable_rects:
				on_screen = on_screen or Rect2(usable).grow(1.0).encloses(button_rect)
		buttons_visible = buttons_visible and on_screen
	_expect_true(buttons_visible, "native recovery leaves both real return and menu buttons fully on-screen")
	_expect_true(controller.active and session.desktop_mode and controller.scale_factor == original_scale and controller.dock == original_dock, "native visibility recovery preserves companion mode and the player's scale/dock choices")
	controller.call("_ensure_visible")
	await get_tree().process_frame
	_expect_eq(DisplayServer.window_get_position(), recovered_rect.position, "native desktop visibility recovery is idempotent once its controls are reachable")
	controller.set_process(was_processing)


func _test_desktop_companion_protection(main: Node, session: Node, ui: Control) -> void:
	var previous_native_focus: bool = get_window().has_focus()
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.desktop_companion.settings()
	var previous_focus: bool = session.desktop_companion.application_focused
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_size: Vector2i = get_window().size
	var previous_main_size: Vector2i = session.main_window_size
	var previous_main_position: Vector2i = session.main_window_position
	var previous_fullscreen: bool = session.main_window_fullscreen
	var previous_scale: float = session.ui_scale
	var previous_locale: String = session.locale
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.call("_close_panel")
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
	session.pig_state.familiarity_level = 2
	session.pig_state.tutorial_skipped = true
	session.pig_state.pending_events.assign(["event_move_in"])
	if not "event_move_in" in session.pig_state.discovered_events:
		session.pig_state.discovered_events.append("event_move_in")
	session.set_desktop_companion_settings(false, false, "normal")
	session.desktop_companion.set_application_focused(true)
	ui.call("_refresh")
	var desktop_button := ui.get("_desktop_button") as Button
	desktop_button.pressed.emit()
	await get_tree().process_frame
	var controller := main.get("_desktop_controller") as DesktopWindowController
	var pig := main.get_node("Pig") as PigVisual
	controller.set_process(false)
	var menus: Array[Node] = controller.find_children("*", "MenuButton", true, false)
	var menu: PopupMenu = (menus[0] as MenuButton).get_popup() if not menus.is_empty() else null
	_expect_true(controller.active and menu != null, "protection fixture enters through the real desktop HUD")
	if menu == null:
		return
	var saved_pig: Dictionary = session.pig_state.to_dict().duplicate(true)
	var saved_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	for mode: String in ["background", "quiet", "dnd", "off"]:
		session.set_desktop_companion_settings(false, false, "normal")
		session.desktop_companion.set_application_focused(true)
		controller.call("_update_behavior_presentation", 45.0)
		controller.present_behavior({"animation":"walk"})
		if mode == "background":
			session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			session.set_desktop_companion_settings(mode == "quiet", mode == "dnd", "off" if mode == "off" else "normal")
		var phase: float = float(pig.get("_phase"))
		var position_before: Vector2 = pig.position
		var animation_before: String = pig.behavior_animation
		var bubble := controller.get("_event_bubble") as PanelContainer
		_expect_true(not session.desktop_companion.proactive_allowed() and not session.desktop_companion.autonomous_motion_allowed(), "%s policy is protected" % mode)
		_expect_true(not bubble.visible, "%s hides the deferred-memory bubble" % mode)
		_expect_eq(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), controller.effective_always_on_top(), "%s applies the effective native top flag" % mode)
		if mode in ["background", "dnd"]:
			_expect_true(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), "%s withdraws native always-on-top" % mode)
		var pig_rect := Rect2i(pig.get_global_rect())
		var frame_before: Image = await _settled_desktop_frame()
		controller.present_behavior({"animation":"sleep"})
		controller.present_behavior({"animation":"walk"})
		controller.call("_update_behavior_presentation", 200.0)
		controller.call("_update_desktop_roaming", 10.0)
		pig.call("_process", 1.0)
		var frame_after: Image = await _settled_desktop_frame()
		_expect_true(pig.behavior_animation == animation_before and float(pig.get("_phase")) == phase and pig.position == position_before, "%s freezes behavior, frame phase and roaming" % mode)
		var region: Rect2i = pig_rect.intersection(Rect2i(Vector2i.ZERO, frame_before.get_size()))
		_expect_true(region.has_area() and frame_before.get_region(region).get_data() == frame_after.get_region(region).get_data(), "%s keeps real rendered pig pixels unchanged" % mode)
		_expect_eq(Engine.max_fps, DesktopFramePolicy.DESKTOP_IDLE_FPS, "%s uses the idle rendering budget" % mode)
		session.note_explicit_companion_interaction()
		session.toast_requested.emit("TOAST_MEMORY_WAITING", {"companion_proactive":true})
		session.ending_ready.emit()
		session.demo_complete_ready.emit()
		await get_tree().process_frame
		_expect_true((ui.get("_toast_panel") as PanelContainer).modulate.a == 0.0 and not (ui.get("_overlay") as ColorRect).visible, "%s explicit lease cannot unlock automatic notices or completion panels" % mode)
		var hold_before: float = float(controller.get("_behavior_hold_elapsed"))
		_send_scaled_pig_input(pig)
		_expect_eq(pig.active_reaction_signature(), "happy:expr_happy_soft", "%s deliberate local mouse/touch feedback still responds" % mode)
		_expect_true(float(pig.get("_phase")) == phase and pig.position == position_before and float(controller.get("_behavior_hold_elapsed")) == hold_before, "%s deliberate input does not resume autonomous motion or reset its frequency" % mode)
		_expect_true(not bubble.visible and not session.desktop_companion.proactive_allowed(), "%s deliberate input does not re-enable proactive memory prompts" % mode)
		pig.call("_process", 2.0)
		var reminders: Array[int] = [0]
		var record_reminder := func() -> void: reminders[0] += 1
		session.focus_break_ready.connect(record_reminder)
		session.start_focus_timer()
		session.desktop_companion.advance(1500.0)
		_expect_true(session.desktop_companion.timer_phase == "rest_ready" and reminders[0] == 0, "%s 25-minute completion remains silent" % mode)
		session.set_desktop_companion_settings(false, false, "normal")
		session.desktop_companion.set_application_focused(true)
		session.desktop_companion.advance(1.0)
		_expect_eq(reminders[0], 0, "%s return never replays expired break reminders" % mode)
		session.focus_break_ready.disconnect(record_reminder)
		session.stop_focus_timer()
		_expect_eq(session.simulation.to_dict(), saved_simulation, "%s presentation and deliberate input never reset the simulation" % mode)
	_expect_true(session.pig_state.daily_points >= int(saved_pig.daily_points) and session.pig_state.familiarity_xp >= int(saved_pig.familiarity_xp), "background protection never removes points or familiarity")
	session.desktop_companion.set_application_focused(false)
	var motion := InputEventMouseMotion.new()
	ui.call("_input", motion)
	_expect_true(not session.desktop_companion.message_allowed(), "local mouse hover is not deliberate interaction")
	var key := InputEventKey.new()
	key.pressed = true
	key.echo = true
	ui.call("_input", key)
	_expect_true(not session.desktop_companion.message_allowed(), "keyboard repeat cannot create a feedback lease")
	key.echo = false
	ui.call("_input", key)
	_expect_true(session.desktop_companion.message_allowed() and not session.desktop_companion.proactive_allowed(), "deliberate local key allows feedback, not proactive work")
	session.desktop_companion.set_application_focused(false)
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.canceled = true
	ui.call("_input", mouse)
	_expect_true(not session.desktop_companion.message_allowed(), "canceled input is not an interaction")
	mouse.canceled = false
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	ui.call("_input", mouse)
	_expect_true(not session.desktop_companion.message_allowed(), "emulated mouse input cannot duplicate a touch lease")
	menu.id_pressed.emit(31)
	_expect_true(session.desktop_companion.do_not_disturb and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), "real desktop menu enables do not disturb without stealing focus")
	menu.id_pressed.emit(30)
	_expect_true(session.desktop_companion.quiet, "real desktop menu enables quiet mode")
	menu.id_pressed.emit(32)
	_expect_eq(session.desktop_companion.timer_phase, "work", "real desktop menu starts focus timer")
	menu.id_pressed.emit(33)
	_expect_eq(session.desktop_companion.timer_phase, "idle", "real desktop menu stops focus timer")
	menu.id_pressed.emit(34)
	await get_tree().process_frame
	_expect_true(not controller.active and ui.visible and ui.find_child("DesktopQuietToggle", true, false) != null, "real desktop menu returns to the companion settings page")
	var quiet_toggle := ui.find_child("DesktopQuietToggle", true, false) as CheckBox
	var dnd_toggle := ui.find_child("DesktopDoNotDisturbToggle", true, false) as CheckBox
	quiet_toggle.button_pressed = false
	dnd_toggle.button_pressed = false
	var frequencies := ui.find_child("DesktopBehaviorFrequency", true, false) as OptionButton
	frequencies.select(2)
	frequencies.item_selected.emit(2)
	_expect_eq(session.desktop_companion.frequency, "rare", "real settings selector stores a permanent frequency ID")
	var start := ui.find_child("FocusTimerStart", true, false) as Button
	var pause := ui.find_child("FocusTimerPause", true, false) as Button
	var rest := ui.find_child("FocusTimerRest", true, false) as Button
	var stop := ui.find_child("FocusTimerStop", true, false) as Button
	_expect_true(pause.disabled and rest.disabled and stop.disabled, "idle timer disables unavailable commands")
	start.pressed.emit()
	_expect_true(not pause.disabled and not stop.disabled and rest.disabled, "working timer exposes pause and stop only")
	pause.pressed.emit()
	_expect_true(session.desktop_companion.timer_paused and pause.text == tr("FOCUS_TIMER_RESUME"), "real timer pause offers the localized resume action")
	pause.pressed.emit()
	session.desktop_companion.advance(1500.0)
	_expect_true(not rest.disabled and pause.disabled, "finished work enables deliberately starting a rest")
	rest.pressed.emit()
	_expect_true(session.desktop_companion.timer_phase == "rest" and not pause.disabled and rest.disabled, "real rest button starts the five-minute interval")
	stop.pressed.emit()
	_expect_eq(session.desktop_companion.timer_phase, "idle", "real stop button ends the in-memory interval")
	var cases: Array[Array] = [
		[Vector2i(1280, 720), 1.0, "standard"],
		[Vector2i(1280, 800), 0.8, "16-10-80"],
		[Vector2i(2560, 1080), 1.0, "ultrawide"],
		[Vector2i(1280, 720), 1.5, "standard-150"],
		[Vector2i(960, 540), 1.5, "minimum-150"],
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		session.set_locale(locale)
		for test_case: Array in cases:
			get_window().size = test_case[0]
			session.set_ui_scale(float(test_case[1]))
			ui.call("_rebuild_ui")
			ui.open_desktop_companion_settings()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var panel := ui.get("_panel") as PanelContainer
			var viewport_rect := Rect2(Vector2.ZERO, ui.size)
			var label: String = "%s %s companion settings" % [locale, test_case[2]]
			_expect_true(_rect_inside(viewport_rect, panel.get_global_rect()), "%s fits the logical viewport" % label)
			for key_name: String in ["DesktopQuietToggle", "DesktopDoNotDisturbToggle", "DesktopBehaviorFrequency", "FocusTimerStart", "FocusTimerPause", "FocusTimerRest", "FocusTimerStop"]:
				var control := ui.find_child(key_name, true, false) as Control
				var scroll := ui.get("_panel_scroll") as ScrollContainer
				scroll.ensure_control_visible(control)
				await get_tree().process_frame
				_expect_true(control != null and viewport_rect.intersects(control.get_global_rect()), "%s keeps %s reachable through scrolling" % [label, key_name])
			(ui.get("_panel_scroll") as ScrollContainer).scroll_vertical = 0
			await RenderingServer.frame_post_draw
			get_window().get_texture().get_image().save_png("res://build/validation/ui/companion-%s-%s.png" % [locale, test_case[2]])
	ui.call("_close_panel")
	session.stop_focus_timer()
	session.desktop_companion.load_settings(previous_settings)
	session.desktop_companion.set_application_focused(previous_focus)
	session.pig_state.load_dict(previous_state)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.set_ui_scale(previous_scale)
	session.set_locale(previous_locale)
	get_window().size = previous_size
	session.main_window_size = previous_main_size
	session.main_window_position = previous_main_position
	session.main_window_fullscreen = previous_fullscreen
	session.save_machine_settings({}, false)
	session.save_game()
	ui.call("_rebuild_ui")
	session.set_process(was_processing)
	if previous_native_focus:
		get_window().grab_focus()
	_expect_true(not previous_native_focus or await _wait_for_foreground_focus(session), "explicit desktop return restores only a previously foreground test window")
	await get_tree().process_frame


func _test_window_minimum_mode_switch(main: Node, session: Node, ui: Control) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "foreground desktop-control fixture acquires settled native focus")
	var controller_nodes: Array[Node] = main.find_children("*", "DesktopWindowController", true, false)
	var controller: DesktopWindowController = controller_nodes[0] as DesktopWindowController if not controller_nodes.is_empty() else null
	_expect_true(controller != null, "main scene owns the desktop window controller")
	if controller == null:
		return
	var previous_companion_settings: Dictionary = session.desktop_companion.settings()
	session.set_desktop_companion_settings(false, false, "frequent")
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var event_director: EventDirector = session.get("event_director") as EventDirector
	var previous_event_director: Dictionary = event_director.to_dict().duplicate(true)
	var previous_focus_mode: bool = session.focus_mode
	if previous_focus_mode:
		session.set_focus_mode(false)
	var move_in_event: Dictionary = session.catalog.get_item("events", "event_move_in")
	var move_in_photo_path: String = "%s/photos/%s.png" % [
		session.save_service.base_dir,
		str(move_in_event.get("photo_id", "event_move_in")),
	]
	var previous_move_in_photo_exists: bool = FileAccess.file_exists(move_in_photo_path)
	var previous_move_in_photo_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(move_in_photo_path)
		if previous_move_in_photo_exists
		else PackedByteArray()
	)
	session.pig_state.daily_points = 100
	session.pig_state.familiarity_xp = 70
	session.pig_state.familiarity_level = 2
	session.pig_state.seen_events.erase("event_move_in")
	session.pig_state.life_photos.erase("event_move_in")
	for event_id: String in ["event_move_in", "event_pillow_migration"]:
		if not event_id in session.pig_state.discovered_events:
			session.pig_state.discovered_events.append(event_id)
	for expression_id: String in ["expr_happy_soft", "expr_shocked_new_home"]:
		session.pig_state.unlocked_expressions.erase(expression_id)
		session.pig_state.expression_unlock_dates.erase(expression_id)
		if session.pig_state.favorite_desktop_expression == expression_id:
			session.pig_state.favorite_desktop_expression = ""
	session.pig_state.unlocked_achievements.erase("ach_welcome_home")
	ui.call("_refresh")
	var desktop_button: Button = ui.get("_desktop_button") as Button
	_expect_true(
		desktop_button != null and desktop_button.is_visible_in_tree() and not desktop_button.disabled,
		"the unlocked desktop HUD action is available for the real-window smoke test"
	)
	if desktop_button != null:
		desktop_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(controller.active, "the real desktop HUD action enters companion mode through the production signal chain")
	_expect_eq(DisplayServer.window_get_min_size(), DesktopFramePolicy.minimum_companion_window_size(controller.scale_factor), "desktop companion mode applies the resize floor for the selected character scale and control rail")
	var active_desktop_screen: int = DisplayServer.window_get_current_screen()
	_expect_eq(controller.desktop_screen, active_desktop_screen, "desktop companion resolves and tracks the real target display")
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	_expect_true(not pig.dragging_enabled, "desktop companion disables room-style drag placement")
	var menu_buttons: Array[Node] = controller.find_children("*", "MenuButton", true, false)
	var desktop_menu: PopupMenu = (menu_buttons[0] as MenuButton).get_popup() if not menu_buttons.is_empty() else null
	var room_button: Button
	for node: Node in controller.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("DESKTOP_ROOM"):
			room_button = button
			break
	var focus_item: int = desktop_menu.get_item_index(1) if desktop_menu != null else -1
	var top_item: int = desktop_menu.get_item_index(2) if desktop_menu != null else -1
	var frequency_item: int = desktop_menu.get_item_index(5) if desktop_menu != null else -1
	_expect_true(room_button != null and focus_item >= 0 and top_item >= 0 and frequency_item >= 0, "desktop controls expose room return, focus, always-on-top, and adjustable action frequency")
	await _test_desktop_control_visibility_recovery(controller, session, room_button, menu_buttons[0] as MenuButton if not menu_buttons.is_empty() else null)
	var original_action_frequency: bool = session.reduce_desktop_action_frequency
	if desktop_menu != null and focus_item >= 0:
		desktop_menu.id_pressed.emit(1)
	var focused_settings: Dictionary = session.save_service.load_settings()
	_expect_true(
		session.focus_mode
			and desktop_menu != null
			and focus_item >= 0
			and desktop_menu.is_item_checked(focus_item)
			and bool(focused_settings.get("focus_mode", false)),
		"desktop focus command updates the production session, menu check, and machine setting"
	)
	if desktop_menu != null and focus_item >= 0:
		desktop_menu.id_pressed.emit(1)
	_expect_true(
		not session.focus_mode
			and desktop_menu != null
			and focus_item >= 0
			and not desktop_menu.is_item_checked(focus_item)
			and not bool(session.save_service.load_settings().get("focus_mode", true)),
		"desktop focus command restores ordinary behavior mode and persists the cleared check"
	)
	_expect_true(
		controller.always_on_top
			and desktop_menu != null
			and top_item >= 0
			and desktop_menu.is_item_checked(top_item)
			and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP) == controller.effective_always_on_top(),
		"desktop companion applies the effective foreground top preference, not an unsafe background top flag"
	)
	if desktop_menu != null and top_item >= 0:
		desktop_menu.id_pressed.emit(2)
	var top_settings: Dictionary = session.save_service.load_settings()
	_expect_true(
		not controller.always_on_top
			and desktop_menu != null
			and top_item >= 0
			and not desktop_menu.is_item_checked(top_item)
			and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
			and not bool(top_settings.get("desktop_always_on_top", true))
			and session.reduce_desktop_action_frequency == original_action_frequency,
		"always-on-top toggles the controller, real window and machine setting without changing action frequency"
	)
	if room_button != null:
		room_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if desktop_button != null:
		desktop_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	menu_buttons = controller.find_children("*", "MenuButton", true, false)
	desktop_menu = (menu_buttons[0] as MenuButton).get_popup() if not menu_buttons.is_empty() else null
	top_item = desktop_menu.get_item_index(2) if desktop_menu != null else -1
	frequency_item = desktop_menu.get_item_index(5) if desktop_menu != null else -1
	_expect_true(
		controller.active
			and desktop_menu != null
			and top_item >= 0
			and frequency_item >= 0
			and not controller.always_on_top
			and not desktop_menu.is_item_checked(top_item)
			and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
			and session.reduce_desktop_action_frequency == original_action_frequency,
		"leaving and re-entering desktop companion restores the remembered always-on-top choice"
	)
	if desktop_menu != null:
		controller.present_behavior({"animation":"idle"})
		desktop_menu.id_pressed.emit(5)
		controller.present_behavior({"animation":"walk"})
		_expect_true(
			session.reduce_desktop_action_frequency
				and desktop_menu.is_item_checked(frequency_item)
				and pig.behavior_animation == "idle",
			"reduced desktop action frequency holds a simulated visual transition without pausing simulation"
		)
		controller.call("_update_behavior_presentation", DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS)
		_expect_eq(pig.behavior_animation, "walk", "reduced desktop action frequency releases the newest pending behavior after 45 seconds")
		controller.present_behavior({"animation":"sleep"})
		desktop_menu.id_pressed.emit(5)
		_expect_true(
			not session.reduce_desktop_action_frequency
				and not desktop_menu.is_item_checked(frequency_item)
				and pig.behavior_animation == "sleep"
				and not bool(session.save_service.load_settings().get("reduce_desktop_action_frequency", true)),
			"returning to normal frequency immediately presents pending behavior and persists the choice"
		)
		_expect_true(
			not controller.always_on_top
				and not desktop_menu.is_item_checked(top_item)
				and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
				and not bool(session.save_service.load_settings().get("desktop_always_on_top", true)),
			"desktop action-frequency changes preserve the independent always-on-top choice"
		)
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(3)
	_expect_true(not pig.is_processing() and Engine.max_fps == DesktopFramePolicy.DESKTOP_IDLE_FPS, "desktop pause action stops visual animation and applies the idle frame budget")
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(3)
	_expect_true(pig.is_processing(), "desktop pause action resumes visual animation")
	var hide_dispatched := [false]
	controller.hide_requested.connect(func() -> void: hide_dispatched[0] = true, CONNECT_ONE_SHOT)
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(20)
	await get_tree().process_frame
	_expect_true(bool(hide_dispatched[0]) and controller.active, "desktop hide action dispatches the taskbar request without exiting the companion")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	var pending_fixture: Array[String] = ["event_move_in"]
	var summarized_fixture: Array[String] = []
	session.pig_state.pending_events = pending_fixture
	session.pig_state.summarized_events = summarized_fixture
	controller.call("_update_event_bubble")
	var memory_bubble: Button = controller.get("_event_bubble_button") as Button
	_expect_true(memory_bubble != null and memory_bubble.is_visible_in_tree() and "1" in memory_bubble.text, "desktop memory bubble exposes the queued-event count")
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(50)
	await get_tree().process_frame
	await get_tree().process_frame
	var compact_window_size: Vector2i = DisplayServer.window_get_size()
	var bubble_panel: PanelContainer = controller.get("_event_bubble") as PanelContainer
	var compact_viewport := Rect2(Vector2.ZERO, Vector2(compact_window_size))
	_expect_true(
		absi(compact_window_size.x - DesktopWindowController.MIN_SIZE.x) <= 1
			and absi(compact_window_size.y - DesktopWindowController.MIN_SIZE.y) <= 1,
		"50-percent desktop scale reaches the supported compact window size within native one-pixel rounding"
	)
	_expect_true(
		bubble_panel != null and _rect_inside(compact_viewport, bubble_panel.get_global_rect()),
		"50-percent desktop memory bubble remains fully inside the real window"
	)
	_expect_true(
		memory_bubble != null and memory_bubble.get_minimum_size().x <= memory_bubble.size.x + 2.0,
		"50-percent desktop memory text fits inside its button"
	)
	_expect_eq(float(session.save_service.load_settings().get("desktop_scale", 0.0)), 0.5, "50-percent desktop scale persists outside progression data")
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(4)
	await get_tree().process_frame
	_expect_true(
		not controller.transparent_mode
			and not get_window().transparent_bg
			and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"compact desktop mode provides an opaque bordered normal-window fallback"
	)
	var compact_desktop_image := Image.new()
	var fallback_window_size: Vector2i = DisplayServer.window_get_size()
	for _attempt: int in 12:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		fallback_window_size = DisplayServer.window_get_size()
		compact_desktop_image = get_window().get_texture().get_image()
		if compact_desktop_image.get_size() == fallback_window_size:
			break
	_expect_true(
		not compact_desktop_image.is_empty() and compact_desktop_image.get_size() == fallback_window_size,
		"50-percent normal desktop fallback renders at the actual compact pixel size (expected %s, current %s, canvas %s, got %s)" % [
			fallback_window_size,
			DisplayServer.window_get_size(),
			get_window().content_scale_size,
			compact_desktop_image.get_size(),
		]
	)
	compact_desktop_image.save_png("res://build/validation/ui/desktop-50-memory-normal-window.png")
	summarized_fixture.append("event_pillow_migration")
	session.call("_on_event_discovered", "event_pillow_migration", false)
	await get_tree().process_frame
	_expect_true(memory_bubble != null and "2" in memory_bubble.text, "desktop memory bubble refreshes when overflow becomes an unread summary")
	if desktop_menu != null:
		desktop_menu.id_pressed.emit(3)
	_expect_true(not pig.is_processing(), "desktop animation can remain paused until the player leaves companion mode")
	if memory_bubble != null:
		memory_bubble.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	var event_viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var pending_viewer: EventViewer = event_viewers[0] as EventViewer if not event_viewers.is_empty() else null
	var playing_event: Dictionary = pending_viewer.get("_event") as Dictionary if pending_viewer != null else {}
	_expect_true(
		not controller.active and ui.visible and overlay != null and not overlay.visible,
		"desktop memory bubble returns to the unobstructed main room"
	)
	_expect_true(
		pending_viewer != null
			and str(playing_event.get("id", "")) == "event_move_in"
			and bool(pending_viewer.get("_capture_photo")),
		"desktop memory bubble immediately plays the oldest queued event"
	)
	_expect_true(pig.is_processing() and not bool(controller.get("_paused_animation")), "returning to the room clears desktop-only animation pause state")
	_expect_eq(int(session.save_service.load_settings().get("desktop_screen", -1)), active_desktop_screen, "leaving desktop mode persists its display outside the game save")
	_expect_true(not controller.active and ui.visible, "leaving desktop mode restores the normal room UI")
	_expect_eq(DisplayServer.window_get_min_size(), GameSession.MAIN_WINDOW_MIN_SIZE, "returning to the room restores the 960x540 resize floor")
	_expect_true(pig.dragging_enabled, "returning to the room restores short-distance drag placement")
	var reward_baseline_points: int = session.pig_state.daily_points
	var reward_baseline_xp: int = session.pig_state.familiarity_xp
	var normal_photo_base: String = session.save_service.base_dir
	var photo_blocker_path: String = normal_photo_base + "/event_photo_blocker"
	var photo_blocker := FileAccess.open(photo_blocker_path, FileAccess.WRITE)
	photo_blocker.store_string("block automatic photo child paths")
	photo_blocker.close()
	session.save_service.base_dir = photo_blocker_path
	if pending_viewer != null:
		_press_event_skip(pending_viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	var failed_photo_toast: Label = ui.get("_toast_label") as Label
	var unread_dot: Panel = ui.get("_album_unread_dot") as Panel
	_expect_true(
		"event_move_in" in session.pig_state.pending_events
			and "event_move_in" not in session.pig_state.seen_events
			and session.pig_state.daily_points == reward_baseline_points
			and session.pig_state.familiarity_xp == reward_baseline_xp
			and not session.pig_state.life_photos.has("event_move_in"),
		"automatic-photo failure preserves the pending event and withholds every first-watch reward"
	)
	_expect_true(
		failed_photo_toast != null
			and failed_photo_toast.text == tr("TOAST_SCREENSHOT_FAILED")
			and unread_dot != null
			and unread_dot.visible,
		"automatic-photo failure stays visible while the memory remains unread"
	)
	session.save_service.base_dir = normal_photo_base
	await _press_album_event_action(ui, move_in_event, tr("ALBUM_WATCH"))
	await get_tree().process_frame
	await get_tree().process_frame
	var retry_viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	pending_viewer = retry_viewers[0] as EventViewer if not retry_viewers.is_empty() else null
	_expect_true(
		pending_viewer != null and bool(pending_viewer.get("_capture_photo")),
		"pending memory can retry its required automatic photo after storage recovers"
	)
	var save_blocker_path: String = normal_photo_base + "/event_save_blocker"
	var save_blocker := FileAccess.open(save_blocker_path, FileAccess.WRITE)
	save_blocker.store_string("block progression temp paths after the automatic photo write")
	save_blocker.close()
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = save_blocker_path + "/savegame.tmp.json"
	if pending_viewer != null:
		_press_event_skip(pending_viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	var failed_save_toast: Label = ui.get("_toast_label") as Label
	var previous_photo_restored: bool = (
		FileAccess.file_exists(move_in_photo_path)
			and FileAccess.get_file_as_bytes(move_in_photo_path) == previous_move_in_photo_bytes
		if previous_move_in_photo_exists
		else not FileAccess.file_exists(move_in_photo_path)
	)
	_expect_true(
		"event_move_in" in session.pig_state.pending_events
			and "event_move_in" not in session.pig_state.seen_events
			and session.pig_state.daily_points == reward_baseline_points
			and session.pig_state.familiarity_xp == reward_baseline_xp
			and not session.pig_state.life_photos.has("event_move_in")
			and previous_photo_restored,
		"progression-save failure rolls back the watched event and restores the previous photo bytes"
	)
	_expect_true(
		failed_save_toast != null
			and failed_save_toast.text == tr("TOAST_SAVE_FAILED")
			and unread_dot != null
			and unread_dot.visible,
		"progression-save failure remains visible while the memory stays retryable"
	)
	session.save_service.temp_path = normal_temp_path
	await _press_album_event_action(ui, move_in_event, tr("ALBUM_WATCH"))
	await get_tree().process_frame
	await get_tree().process_frame
	retry_viewers = ui.find_children("*", "EventViewer", true, false)
	pending_viewer = retry_viewers[0] as EventViewer if not retry_viewers.is_empty() else null
	_expect_true(
		pending_viewer != null and bool(pending_viewer.get("_capture_photo")),
		"pending memory can retry after progression storage recovers"
	)
	if pending_viewer != null:
		_press_event_skip(pending_viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(
		"event_move_in" in session.pig_state.seen_events
			and not "event_move_in" in session.pig_state.pending_events
			and session.pig_state.summarized_events == ["event_pillow_migration"],
		"completing the desktop memory consumes only its queued event and preserves unread summaries"
	)
	var first_photo_record: Dictionary = session.pig_state.life_photos.get("event_move_in", {}).duplicate(true)
	var first_photo_path: String = str(first_photo_record.get("path", ""))
	var first_photo_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(first_photo_path)
		if not first_photo_path.is_empty() and FileAccess.file_exists(first_photo_path)
		else PackedByteArray()
	)
	_expect_true(
		str(first_photo_record.get("photo_id", "")) == "photo_move_in"
			and int(first_photo_record.get("captured_unix", 0)) > 0
			and not first_photo_bytes.is_empty(),
		"completing the desktop memory stores its automatic life-album photo"
	)
	_expect_eq(session.pig_state.daily_points, reward_baseline_points + 50, "first desktop-memory watch grants event and two expression rewards once")
	_expect_eq(session.pig_state.familiarity_xp, reward_baseline_xp + 12, "first desktop-memory watch grants its familiarity reward")
	_expect_eq(session.pig_state.familiarity_level, 3, "desktop-memory familiarity reward uses the normal level thresholds")
	_expect_true(
		"expr_happy_soft" in session.pig_state.unlocked_expressions
			and "expr_shocked_new_home" in session.pig_state.unlocked_expressions
			and int(session.pig_state.expression_unlock_dates.get("expr_happy_soft", 0)) > 0
			and int(session.pig_state.expression_unlock_dates.get("expr_shocked_new_home", 0)) > 0,
		"first desktop-memory watch records both permanent expression unlocks and dates"
	)
	_expect_true("ach_welcome_home" in session.pig_state.unlocked_achievements, "first desktop-memory watch unlocks its permanent achievement")
	var first_watch_state := {
		"daily_points": session.pig_state.daily_points,
		"familiarity_xp": session.pig_state.familiarity_xp,
		"familiarity_level": session.pig_state.familiarity_level,
		"discovered_events": session.pig_state.discovered_events.duplicate(),
		"seen_events": session.pig_state.seen_events.duplicate(),
		"pending_events": session.pig_state.pending_events.duplicate(),
		"summarized_events": session.pig_state.summarized_events.duplicate(),
		"unlocked_expressions": session.pig_state.unlocked_expressions.duplicate(),
		"expression_unlock_dates": session.pig_state.expression_unlock_dates.duplicate(true),
		"unlocked_achievements": session.pig_state.unlocked_achievements.duplicate(),
		"life_photos": session.pig_state.life_photos.duplicate(true),
		"ending_unlocked": session.pig_state.ending_unlocked,
		"ending_seen": session.pig_state.ending_seen,
	}
	var first_watch_event_director: Dictionary = event_director.to_dict().duplicate(true)
	await _press_album_event_action(ui, move_in_event, tr("ALBUM_REPLAY"))
	await get_tree().process_frame
	await get_tree().process_frame
	var replay_viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var replay_viewer: EventViewer = replay_viewers[0] as EventViewer if not replay_viewers.is_empty() else null
	var replay_photo_emitted := [false]
	if replay_viewer != null:
		replay_viewer.photo_captured.connect(func(_event_id: String, _image: Image) -> void: replay_photo_emitted[0] = true)
	_expect_true(replay_viewer != null and not bool(replay_viewer.get("_capture_photo")), "desktop-memory album replay disables automatic photo capture")
	if replay_viewer != null:
		_press_event_skip(replay_viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(
		not bool(replay_photo_emitted[0])
			and session.pig_state.life_photos.get("event_move_in", {}) == first_photo_record
			and FileAccess.get_file_as_bytes(first_photo_path) == first_photo_bytes,
		"desktop-memory album replay preserves the original automatic photo bytes and capture date"
	)
	_expect_true(
		{
			"daily_points": session.pig_state.daily_points,
			"familiarity_xp": session.pig_state.familiarity_xp,
			"familiarity_level": session.pig_state.familiarity_level,
			"discovered_events": session.pig_state.discovered_events,
			"seen_events": session.pig_state.seen_events,
			"pending_events": session.pig_state.pending_events,
			"summarized_events": session.pig_state.summarized_events,
			"unlocked_expressions": session.pig_state.unlocked_expressions,
			"expression_unlock_dates": session.pig_state.expression_unlock_dates,
			"unlocked_achievements": session.pig_state.unlocked_achievements,
			"life_photos": session.pig_state.life_photos,
			"ending_unlocked": session.pig_state.ending_unlocked,
			"ending_seen": session.pig_state.ending_seen,
		} == first_watch_state
			and event_director.to_dict() == first_watch_event_director,
		"desktop-memory album replay cannot duplicate rewards or mutate event queues"
	)
	if previous_move_in_photo_exists:
		var restored_photo := FileAccess.open(move_in_photo_path, FileAccess.WRITE)
		if restored_photo != null:
			restored_photo.store_buffer(previous_move_in_photo_bytes)
			restored_photo.close()
	elif FileAccess.file_exists(move_in_photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(move_in_photo_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_blocker_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_blocker_path))
	session.pig_state.load_dict(previous_pig_state)
	event_director.load_dict(previous_event_director)
	session.set_focus_mode(previous_focus_mode)
	session.desktop_companion.load_settings(previous_companion_settings)
	session.save_machine_settings({}, false)
	session.save_game()
	await get_tree().process_frame
	ui.call("_refresh")


func _test_save_recovery_toast(session: Node, ui: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var service: SaveService = session.get("save_service") as SaveService
	var previous_recovery_source: String = str(session.get("last_recovery_source"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	_expect_true(
		service != null and session.save_game() == OK and session.save_game() == OK,
		"save recovery UI fixture creates a valid rotating backup through the active session"
	)
	if service == null:
		session.set_process(was_processing)
		return
	var broken_main: FileAccess = FileAccess.open(service.save_path, FileAccess.WRITE)
	_expect_true(broken_main != null, "save recovery UI fixture can replace the isolated main save")
	if broken_main == null:
		session.set_process(was_processing)
		return
	broken_main.store_string("{not-json")
	broken_main.close()
	var recovered: Dictionary = service.load_game()
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		bool(recovered.get("ok", false))
			and bool(recovered.get("recovered", false))
			and str(recovered.get("source", "")) == service.backup_1_path,
		"a damaged main save really falls back to the newest rotating backup"
	)
	_expect_eq(
		str(session.get("last_recovery_source")),
		service.backup_1_path,
		"the active session retains the real backup recovery source for UI startup"
	)
	_expect_true(
		toast_panel != null
			and toast_label != null
			and toast_panel.modulate.a > 0.9
			and toast_label.text == tr("TOAST_SAVE_RECOVERED")
			and toast_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"the save_recovered signal renders the localized player-visible recovery toast"
	)
	var backup_paths: Array[String] = [service.backup_1_path, service.backup_2_path]
	var backups_before: Array[PackedByteArray] = []
	for path: String in backup_paths:
		backups_before.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.backup_1_path)) as Dictionary
	var invalid_placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(service.save_path)) as Dictionary
	if "furn_bed_basic" not in invalid_placement.pig_state.owned_furniture:
		invalid_placement.pig_state.owned_furniture.append("furn_bed_basic")
	invalid_placement.pig_state.placed_furniture = {"sleep_3":"furn_bed_basic"}
	broken_main = FileAccess.open(service.save_path, FileAccess.WRITE)
	_expect_true(broken_main != null, "semantic-placement UI fixture can corrupt only the isolated main file")
	if broken_main != null:
		broken_main.store_string(JSON.stringify(invalid_placement))
		broken_main.close()
		var placement_recovery: Dictionary = service.load_game()
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		_expect_true(
			bool(placement_recovery.get("ok", false))
				and bool(placement_recovery.get("recovered", false))
				and str(placement_recovery.get("source", "")) == service.backup_1_path
				and (placement_recovery.get("data", {}) as Dictionary).get("pig_state", {}) == backup.get("pig_state", {}),
			"a syntactically valid incompatible placement restores the newest legal backup state"
		)
		_expect_true(
			str(session.get("last_recovery_source")) == service.backup_1_path
				and toast_panel != null
				and toast_label != null
				and toast_panel.modulate.a > 0.9
				and toast_label.text == tr("TOAST_SAVE_RECOVERED"),
			"semantic-placement recovery reaches the real session and localized visible recovery toast"
		)
		var backups_after: Array[PackedByteArray] = []
		for path: String in backup_paths:
			backups_after.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_eq(backups_after, backups_before, "semantic-placement UI recovery cannot rotate either valid backup")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/save-recovery-toast.png")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.set("last_recovery_source", previous_recovery_source)
	session.set_process(was_processing)


func _test_atomic_rewrite_failure_ui(session: Node, ui: Control) -> void:
	var service: SaveService = session.save_service
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	session.set_process(false)
	_expect_eq(session.save_game(), OK, "atomic rewrite UI fixture commits a main generation")
	session.pig_state.daily_points += 1
	_expect_eq(session.save_game(), OK, "atomic rewrite UI fixture commits a recovery backup")
	_expect_true(FileAccess.file_exists(service.backup_1_path), "atomic rewrite UI fixture contains a real nonidentical backup generation")
	_expect_eq(session.save_machine_settings({}, false), OK, "atomic rewrite UI fixture commits machine settings through the real facade")
	var paths: Array[String] = [service.settings_path, service.save_path, service.backup_1_path, service.backup_2_path]
	var original: Array[PackedByteArray] = []
	for path: String in paths:
		original.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	var errors: Array[String] = []
	var error_listener: Callable = func(message: String) -> void: errors.append(message)
	session.save_failed.connect(error_listener)
	var settings_stage: String = service.settings_path + ".tmp"
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(settings_stage)), OK, "atomic rewrite UI fixture blocks only machine settings staging")
	_expect_true(session.save_machine_settings({"atomic_probe":true}, false) != OK, "the real settings facade reports a failed atomic checkpoint")
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(toast_panel != null and toast_label != null and toast_panel.modulate.a > 0.9 and toast_label.text == tr("TOAST_SAVE_FAILED"), "failed settings staging reaches the localized player-visible storage toast")
	_expect_eq(FileAccess.get_file_as_bytes(service.settings_path), original[0], "failed facade checkpoint preserves the previous complete machine settings")
	_expect_eq(errors.size(), 1, "failed facade settings checkpoint emits exactly one session error")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_stage)), OK, "atomic rewrite UI fixture unblocks machine settings staging")
	_expect_eq(session.save_machine_settings({"atomic_probe":true}, false), OK, "the real settings facade can retry after staging is repaired")
	_expect_true(bool(service.load_settings().get("atomic_probe", false)) and not FileAccess.file_exists(settings_stage), "successful facade retry commits complete settings and consumes staging")
	var broken_main := FileAccess.open(service.save_path, FileAccess.WRITE)
	broken_main.store_string("{atomic-ui-damaged-main")
	broken_main.close()
	var damaged_bytes: PackedByteArray = FileAccess.get_file_as_bytes(service.save_path)
	var restore_stage: String = service.save_path + ".tmp"
	_expect_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(restore_stage)), OK, "atomic recovery UI fixture blocks only main restoration staging")
	var recovered: Dictionary = service.load_game()
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	_expect_true(bool(recovered.get("ok", false)) and bool(recovered.get("recovered", false)) and str(recovered.get("source", "")) == service.backup_1_path, "failed atomic main rewrite still returns the actual usable backup")
	_expect_true(recovered.get("recovery_write_error", OK) != OK, "failed atomic recovery explicitly reports that the main is not repaired")
	_expect_true(toast_panel != null and toast_label != null and toast_panel.modulate.a > 0.9 and toast_label.text == tr("TOAST_SAVE_FAILED"), "failed recovery rewrite is not hidden by the earlier recovered toast")
	_expect_eq(FileAccess.get_file_as_bytes(service.save_path), damaged_bytes, "failed recovery staging preserves the original main bytes")
	_expect_eq(errors.size(), 2, "failed recovery rewrite adds exactly one real session error")
	_expect_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(restore_stage)), OK, "atomic recovery UI fixture unblocks restoration staging")
	var retried: Dictionary = service.load_game()
	_expect_eq(retried.get("recovery_write_error", FAILED), OK, "atomic recovery retry successfully replaces the main")
	_expect_eq((retried.get("data", {}) as Dictionary).get("pig_state", {}), (JSON.parse_string(original[2].get_string_from_utf8()) as Dictionary).get("pig_state", {}), "atomic recovery retry retains the exact verified pig progression")
	_expect_true(not FileAccess.file_exists(restore_stage), "atomic recovery retry consumes its staging file")
	for index: int in range(2, paths.size()):
		_expect_eq(FileAccess.get_file_as_bytes(paths[index]), original[index], "real facade atomic writes cannot rotate backup%d" % (index - 1))
	session.save_failed.disconnect(error_listener)
	for index: int in paths.size():
		if original[index].is_empty():
			if FileAccess.file_exists(paths[index]):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(paths[index]))
		else:
			var restored := FileAccess.open(paths[index], FileAccess.WRITE)
			restored.store_buffer(original[index])
			restored.close()
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)


func _test_rotation_staging_recovery_ui(session: Node, ui: Control) -> void:
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.hide()
	var service := SaveService.new("user://rotation_staging_recovery_ui_tests")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var restored := PigState.new()
	restored.name = "Staged Pig"
	restored.daily_points = 432
	restored.tutorial_skipped = true
	var payload := {"schema_version":SaveService.CURRENT_SCHEMA,"release_profile":ReleaseProfile.profile_id(),"last_saved_unix":3000,"pig_state":restored.to_dict()}
	var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path, service.backup_2_path + ".rotate"]
	for shape: String in ["orphan", "committed"]:
		for path: String in paths:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		for index: int in paths.size():
			if shape == "committed" or index == 3:
				var broken := FileAccess.open(paths[index], FileAccess.WRITE)
				broken.store_string("{damaged-rotation-ui")
				broken.close()
		var damaged: Array[PackedByteArray] = []
		for path: String in paths:
			damaged.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		session.save_recovery_required = false
		session.last_offline_summary = {}
		session.last_save_error = ""
		session.last_recovery_source = ""
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and session.pig_state.to_dict() == state_before, "%s damaged rotation is existing progression and cannot start a new pig" % shape)
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true((recovery_ui.get("_overlay") as ColorRect).visible and (recovery_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s damaged rotation renders the actual startup recovery page" % shape)
		_expect_true(session.save_game() != OK and not FileAccess.file_exists(service.temp_path), "%s blocked startup cannot write substitute temporary progression" % shape)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and (recovery_ui.get("_overlay") as ColorRect).visible, "%s retry stays blocked before a valid staged generation is restored" % shape)
		var after_failure: Array[PackedByteArray] = []
		for path: String in paths:
			after_failure.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_eq(after_failure, damaged, "%s failed startup and retry retain every damaged original" % shape)
		if FileAccess.file_exists(service.temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(service.temp_path))
		var valid := FileAccess.open(paths[3], FileAccess.WRITE)
		valid.store_string(JSON.stringify(payload))
		valid.close()
		var restored_bytes: PackedByteArray = FileAccess.get_file_as_bytes(paths[3])
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.pig_state.name == "Staged Pig" and session.pig_state.daily_points == 432, "%s actual retry salvages the exact staged identity and balance" % shape)
		_expect_eq(session.last_recovery_source, service.backup_2_path, "%s actual retry reports the normalized oldest backup source" % shape)
		_expect_true(not (recovery_ui.get("_overlay") as ColorRect).visible and recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s successful staged recovery returns to a usable room" % shape)
		_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path) if FileAccess.file_exists(service.backup_2_path) else PackedByteArray(), restored_bytes, "%s staged recovery retains an unchanged original backup" % shape)
		_expect_true(not FileAccess.file_exists(paths[3]), "%s successful normalization consumes only the retained staging artifact" % shape)
		var loaded: Dictionary = service.load_game()
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(((loaded.get("data", {}) as Dictionary).get("pig_state", {}) as Dictionary).get("daily_points", -1)) == 432, "%s normalized main reloads the exact recovered progression" % shape)
		recovery_ui.queue_free()
		await get_tree().process_frame
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.show()
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_damaged_generation_rotation_ui(session: Node, ui: Control) -> void:
	var previous_application_focus: bool = session.desktop_companion.application_focused
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	for damaged_index: int in [0, 1]:
		for damage: String in ["syntax", "semantic"]:
			session.desktop_companion.set_application_focused(damage == "syntax")
			var label: String = "live damaged generation %d %s" % [damaged_index, damage]
			var service := SaveService.new("user://damaged_generation_ui_%d_%s" % [damaged_index, damage])
			service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
			service.recovery_used.connect(session._on_save_recovered)
			service.save_failed.connect(session._on_save_failed)
			session.save_service = service
			session.clock = GameClock.new(func() -> int: return 3000)
			session.save_recovery_required = false
			session.last_save_error = ""
			session.last_recovery_source = ""
			session.last_offline_summary = {}
			var pig := PigState.new()
			pig.name = "Rotation Pig"
			pig.tutorial_skipped = true
			var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
			for generation: int in range(1, 4):
				pig.daily_points = generation * 111
				_expect_eq(service.save_game({"last_saved_unix":3000,"release_profile":ReleaseProfile.profile_id(),"pig_state":pig.to_dict()}), OK, "%s creates committed fixture generation %d" % [label, generation])
			var original: Array[PackedByteArray] = []
			for path: String in paths:
				original.append(FileAccess.get_file_as_bytes(path))
			var damaged := FileAccess.open(paths[damaged_index], FileAccess.WRITE)
			damaged.store_string("{damaged-live-generation" if damage == "syntax" else JSON.stringify({"schema_version":4,"pig_state":{"name":"Damaged Pig","daily_points":-1}}))
			damaged.close()
			pig.daily_points = 444
			session.pig_state.load_dict(pig.to_dict())
			_expect_eq(session.save_game(), OK, "%s real autoload save commits valid in-memory progression" % label)
			var loaded: Dictionary = service.load_game()
			_expect_true(bool(loaded.get("ok", false)) and int((loaded.get("data", {}) as Dictionary).get("pig_state", {}).get("daily_points", -1)) == 444, "%s active session persists its intended new balance" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_1_path), original[1 if damaged_index == 0 else 0], "%s actual save retains its newest valid backup" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path), original[2], "%s actual save preserves the remaining oldest valid bytes" % label)
			_expect_true(session.last_save_error.is_empty() and session.last_recovery_source.is_empty(), "%s successful saving cannot emit a spurious error or recovery" % label)
			for path: String in [service.save_path, service.backup_1_path]:
				var broken := FileAccess.open(path, FileAccess.WRITE)
				broken.store_string("{damaged-newer-generation")
				broken.close()
			ui.call("_rebuild_ui")
			session.call("_load_or_create_game")
			session.state_changed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_expect_true(not session.save_recovery_required and session.pig_state.name == "Rotation Pig" and session.pig_state.daily_points == 111, "%s active autoload recovers exact oldest progress after newer damage" % label)
			_expect_eq(session.last_recovery_source, service.backup_2_path, "%s active recovery retains its actual backup2 source" % label)
			var toast: Label = ui.get("_toast_label") as Label
			var toast_panel := ui.get("_toast_panel") as PanelContainer
			_expect_true(toast_panel.modulate.a > 0.0 and toast.text == tr("TOAST_SAVE_RECOVERED") if damage == "syntax" else toast_panel.modulate.a == 0.0, "%s usable backup notice respects foreground/background protection" % label)
			_expect_true(not (ui.get("_overlay") as ColorRect).visible and ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s recovered progress leaves the real room usable" % label)
			_expect_eq(FileAccess.get_file_as_bytes(service.backup_2_path), original[2], "%s actual recovery preserves original backup2 bytes" % label)
			service.recovery_used.disconnect(session._on_save_recovered)
			service.save_failed.disconnect(session._on_save_failed)
			for path: String in paths:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	session.desktop_companion.set_application_focused(previous_application_focus)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_demo_import_notice(session: Node, ui: Control) -> void:
	var previous_application_focus: bool = session.desktop_companion.application_focused
	var previous_imported: bool = session.demo_save_imported
	var previous_save_error: String = session.last_save_error
	var previous_recovery_source: String = session.last_recovery_source
	session.demo_save_imported = true
	session.last_save_error = ""
	session.last_recovery_source = ""
	for focused: bool in [true, false]:
		session.desktop_companion.set_application_focused(focused)
		var import_ui := MainUI.new()
		ui.get_parent().add_child(import_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		var toast_panel: PanelContainer = import_ui.get("_toast_panel") as PanelContainer
		var toast_label: Label = import_ui.get("_toast_label") as Label
		_expect_true(
			toast_panel.modulate.a > 0.0 and toast_label.text == tr("TOAST_DEMO_SAVE_IMPORTED") if focused else toast_panel.modulate.a == 0.0,
			"a successful Demo import notice respects foreground=%s on a freshly started production UI" % focused
		)
		import_ui.queue_free()
		await get_tree().process_frame
	session.desktop_companion.set_application_focused(previous_application_focus)
	session.demo_save_imported = previous_imported
	session.last_save_error = previous_save_error
	session.last_recovery_source = previous_recovery_source


func _test_album_photo_actions(session: Node, ui: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var event_id := "event_rainy_window"
	var event: Dictionary = session.catalog.get_item("events", event_id)
	var photo_id: String = str(event.get("photo_id", event_id))
	var photo_path: String = "%s/photos/%s.png" % [session.save_service.base_dir, photo_id]
	var export_path: String = "%s/exports/%s.png" % [session.save_service.base_dir, photo_id]
	var previous_photo_exists: bool = FileAccess.file_exists(photo_path)
	var previous_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if previous_photo_exists else PackedByteArray()
	var previous_export_exists: bool = FileAccess.file_exists(export_path)
	var previous_export_bytes: PackedByteArray = FileAccess.get_file_as_bytes(export_path) if previous_export_exists else PackedByteArray()
	var sample := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	sample.fill(Color("#d9879b"))
	sample.fill_rect(Rect2i(160, 0, 160, 90), Color("#f7d9df"))
	sample.fill_rect(Rect2i(0, 90, 160, 90), Color("#8ebfc6"))
	var discovered_events: Array[String] = [event_id]
	var seen_events: Array[String] = [event_id]
	var pending_events: Array[String] = []
	var summarized_events: Array[String] = []
	session.pig_state.discovered_events = discovered_events
	session.pig_state.seen_events = seen_events
	session.pig_state.pending_events = pending_events
	session.pig_state.summarized_events = summarized_events
	session.pig_state.life_photos.clear()
	_expect_true(session.store_event_photo(event_id, sample), "album action fixture stores a real event photo through the session facade")
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(export_path))
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_nodes: Array[Node] = ui.find_children("*", "TabContainer", true, false)
	var tabs: TabContainer = tab_nodes[0] as TabContainer if not tab_nodes.is_empty() else null
	if tabs != null:
		tabs.current_tab = 1
	await get_tree().process_frame
	var view_button: Button
	var export_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == tr("ALBUM_VIEW_PHOTO"):
			view_button = button
		elif button.text == tr("ALBUM_EXPORT"):
			export_button = button
	_expect_true(
		view_button != null and export_button != null,
		"the watched memory exposes real view-without-UI and export actions"
	)
	if view_button != null:
		view_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var lightbox: ColorRect = ui.get("_photo_lightbox") as ColorRect
	var lightbox_photos: Array[Node] = lightbox.find_children("*", "TextureRect", true, false) if lightbox != null else []
	var lightbox_photo: TextureRect = lightbox_photos[0] as TextureRect if not lightbox_photos.is_empty() else null
	var rendered_image: Image = lightbox_photo.texture.get_image() if lightbox_photo != null and lightbox_photo.texture != null else null
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	_expect_true(
		lightbox != null
			and lightbox.color.a == 1.0
			and overlay != null
			and not overlay.visible
			and rendered_image != null
			and rendered_image.get_size() == sample.get_size()
			and rendered_image.get_data() == sample.get_data(),
		"view without UI fully hides the HUD and renders the exact stored photo"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/album-photo-without-ui.png")
	var lightbox_touch := InputEventScreenTouch.new()
	lightbox_touch.index = 7
	lightbox_touch.position = Vector2(12, 12)
	lightbox_touch.pressed = true
	lightbox.gui_input.emit(lightbox_touch)
	await get_tree().process_frame
	_expect_true(ui.get("_photo_lightbox") == null, "a screen touch closes the photo lightbox")
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	export_button = null
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("ALBUM_EXPORT"):
			export_button = button
			break
	_expect_true(export_button != null, "the export action remains available after closing the photo viewer")
	if export_button != null:
		export_button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	var exported_absolute_path: String = ProjectSettings.globalize_path(export_path)
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		FileAccess.file_exists(export_path)
			and FileAccess.get_file_as_bytes(export_path) == sample.save_png_to_buffer()
			and toast_panel != null
			and toast_panel.modulate.a > 0.9
			and toast_label != null
			and toast_label.text == tr("TOAST_PHOTO_EXPORTED").format({"path":exported_absolute_path}),
		"the album export button copies identical PNG bytes and reports the localized destination"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/album-photo-export-toast.png")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	ui.call("_close_panel")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	_expect_eq(session.event_photo_path(event_id), "", "a missing album PNG is unavailable through the session boundary")
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	tab_nodes = ui.find_children("*", "TabContainer", true, false)
	tabs = tab_nodes[0] as TabContainer if not tab_nodes.is_empty() else null
	if tabs != null:
		tabs.current_tab = 1
	await get_tree().process_frame
	var stale_photo_action_visible: bool = false
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text in [tr("ALBUM_VIEW_PHOTO"), tr("ALBUM_EXPORT")]:
			stale_photo_action_visible = true
			break
	_expect_true(not stale_photo_action_visible, "the real album hides view and export actions for missing photo bytes")
	ui.call("_close_panel")
	session.pig_state.load_dict(previous_pig_state)
	if previous_photo_exists:
		var restored_photo: FileAccess = FileAccess.open(photo_path, FileAccess.WRITE)
		if restored_photo != null:
			restored_photo.store_buffer(previous_photo_bytes)
			restored_photo.close()
	elif FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	if previous_export_exists:
		var restored_export: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
		if restored_export != null:
			restored_export.store_buffer(previous_export_bytes)
			restored_export.close()
	elif FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(export_path))
	session.save_game()
	ui.call("_refresh")


func _test_event_branch_handoff(session: Node, ui: Control) -> void:
	ui.call("_close_panel")
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var event_director: EventDirector = session.get("event_director") as EventDirector
	var previous_event_director: Dictionary = event_director.to_dict().duplicate(true)
	var event_id := "event_rainy_window"
	var event: Dictionary = session.catalog.get_item("events", event_id)
	var photo_path: String = "%s/photos/%s.png" % [
		session.save_service.base_dir,
		str(event.get("photo_id", event_id)),
	]
	var previous_photo_exists: bool = FileAccess.file_exists(photo_path)
	var previous_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if previous_photo_exists else PackedByteArray()
	session.pig_state.familiarity_xp = 200
	session.pig_state.familiarity_level = 6
	session.pig_state.daily_points = 100
	if "furn_kettle_round" not in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.append("furn_kettle_round")
	session.pig_state.placed_furniture["snack_3"] = "furn_kettle_round"
	if event_id not in session.pig_state.discovered_events:
		session.pig_state.discovered_events.append(event_id)
	session.pig_state.seen_events.erase(event_id)
	session.pig_state.summarized_events.erase(event_id)
	if event_id not in session.pig_state.pending_events:
		session.pig_state.pending_events.append(event_id)
	session.pig_state.life_photos.erase(event_id)
	for expression_id: Variant in (event.get("rewards", {}) as Dictionary).get("expressions", []):
		if str(expression_id) not in session.pig_state.unlocked_expressions:
			session.pig_state.unlocked_expressions.append(str(expression_id))
	ui.call("_play_event", event, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var viewer: EventViewer = viewers[0] as EventViewer if not viewers.is_empty() else null
	var playing_event: Dictionary = viewer.get("_event") as Dictionary if viewer != null else {}
	var branch_line_rendered: bool = false
	if viewer != null:
		for node: Node in viewer.find_children("*", "Label", true, false):
			var label := node as Label
			branch_line_rendered = branch_line_rendered or (label != null and label.text == tr("EVENT_RAINY_WINDOW_LINE_2"))
	_expect_true(
		viewer != null
			and str(playing_event.get("resolved_branch_id", "")) == "warm_drink"
			and playing_event.get("variants", []) == ["EVENT_RAINY_WINDOW_LINE_2"]
			and branch_line_rendered,
		"event viewer renders only the branch prepared from the opening state"
	)
	session.pig_state.placed_furniture.erase("snack_3")
	_expect_eq(
		str(session.prepare_event(event_id).get("resolved_branch_id", "")),
		"default",
		"event branch conditions can change while the real viewer remains open"
	)
	if viewer != null:
		_press_event_skip(viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(
		event_id in session.pig_state.seen_events
			and event_id not in session.pig_state.pending_events
			and session.pig_state.daily_points == 134
			and session.pig_state.familiarity_xp == 215,
		"real viewer completion commits rewards from its displayed branch after conditions change"
	)
	if previous_photo_exists:
		var restored_photo := FileAccess.open(photo_path, FileAccess.WRITE)
		if restored_photo != null:
			restored_photo.store_buffer(previous_photo_bytes)
			restored_photo.close()
	elif FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	session.pig_state.load_dict(previous_pig_state)
	event_director.load_dict(previous_event_director)
	session.save_game()
	session.set_process(was_processing)
	ui.call("_refresh")


func _test_ending_flow(session: Node, ui: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var event_director: EventDirector = session.get("event_director") as EventDirector
	var previous_event_director: Dictionary = event_director.to_dict().duplicate(true)
	var ending_event: Dictionary = session.catalog.get_item("events", "event_ordinary_day")
	var ending_photo_path: String = "%s/photos/%s.png" % [
		session.save_service.base_dir,
		str(ending_event.get("photo_id", "event_ordinary_day")),
	]
	var previous_ending_photo_exists: bool = FileAccess.file_exists(ending_photo_path)
	var previous_ending_photo_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(ending_photo_path)
		if previous_ending_photo_exists
		else PackedByteArray()
	)
	var discovered_events: Array[String] = []
	var seen_events: Array[String] = []
	for event: Dictionary in session.catalog.events:
		var event_id: String = str(event.get("id", ""))
		discovered_events.append(event_id)
		if event_id != "event_ordinary_day":
			seen_events.append(event_id)
	session.pig_state.familiarity_xp = 2000
	session.pig_state.familiarity_level = 10
	session.pig_state.discovered_events = discovered_events
	session.pig_state.seen_events = seen_events
	var pending_events: Array[String] = ["event_ordinary_day"]
	var summarized_events: Array[String] = []
	session.pig_state.pending_events = pending_events
	session.pig_state.summarized_events = summarized_events
	session.pig_state.life_photos.erase("event_ordinary_day")
	session.pig_state.ending_unlocked = false
	session.pig_state.ending_seen = false
	for expression_id: String in ["expr_happy_ending", "expr_proud_ending"]:
		session.pig_state.unlocked_expressions.erase(expression_id)
		session.pig_state.expression_unlock_dates.erase(expression_id)
		if session.pig_state.favorite_desktop_expression == expression_id:
			session.pig_state.favorite_desktop_expression = ""
	session.pig_state.unlocked_achievements.erase("ach_events_24")
	ui.call("_refresh")
	await _press_album_event_action(ui, ending_event, tr("ALBUM_WATCH"))
	await get_tree().process_frame
	await get_tree().process_frame
	var ending_viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
	var ending_viewer: EventViewer = ending_viewers[0] as EventViewer if not ending_viewers.is_empty() else null
	var playing_event: Dictionary = ending_viewer.get("_event") as Dictionary if ending_viewer != null else {}
	_expect_true(
		ending_viewer != null
			and str(playing_event.get("id", "")) == "event_ordinary_day"
			and bool(ending_viewer.get("_capture_photo")),
		"the final queued memory opens as a real photo-capturing event performance"
	)
	if ending_viewer != null:
		_press_event_skip(ending_viewer)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	var ending_photo_record: Dictionary = session.pig_state.life_photos.get("event_ordinary_day", {}).duplicate(true)
	var stored_ending_photo_path: String = str(ending_photo_record.get("path", ""))
	var ending_photo_bytes: PackedByteArray = (
		FileAccess.get_file_as_bytes(stored_ending_photo_path)
		if not stored_ending_photo_path.is_empty() and FileAccess.file_exists(stored_ending_photo_path)
		else PackedByteArray()
	)
	_expect_true(
		session.pig_state.ending_unlocked
			and not session.pig_state.ending_seen
			and session.pig_state.seen_events.size() == session.catalog.events.size()
			and "event_ordinary_day" not in session.pig_state.pending_events,
		"completing the twenty-fourth core event unlocks the thematic ending exactly at the full collection"
	)
	_expect_true(
		str(ending_photo_record.get("photo_id", "")) == "photo_ordinary_day"
			and int(ending_photo_record.get("captured_unix", 0)) > 0
			and not ending_photo_bytes.is_empty(),
		"the thematic ending stores its automatic thank-you photo before opening the credits"
	)
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	var panel_title: Label = ui.get("_panel_title") as Label
	var panel_content: VBoxContainer = ui.get("_panel_content") as VBoxContainer
	var ending_textures: Array[Node] = panel_content.find_children("*", "TextureRect", true, false) if panel_content != null else []
	_expect_true(
		overlay != null
			and overlay.visible
			and panel_title != null
			and panel_title.text == tr("ENDING_TITLE")
			and not ending_textures.is_empty(),
		"the ending panel visibly presents the automatic thank-you photo"
	)
	_expect_true(
		panel_content != null
			and _count_labels_with_text(panel_content, tr("ENDING_THANKS").format({"name":session.pig_display_name()})) == 1
			and _count_labels_with_text(panel_content, tr("ENDING_CREDITS")) == 1,
		"the ending panel renders the localized personal thanks and full credits"
	)
	var continue_button: Button
	if panel_content != null:
		for node: Node in panel_content.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == tr("ENDING_CONTINUE"):
				continue_button = button
				break
	_expect_true(continue_button != null and not continue_button.disabled, "the ending offers an enabled transition into free companion mode")
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/thematic-ending.png")
	if continue_button != null:
		continue_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(
		session.pig_state.ending_seen and overlay != null and not overlay.visible and ui.visible,
		"continuing from the ending returns to the normal playable room without ending progression"
	)
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_nodes: Array[Node] = ui.find_children("*", "TabContainer", true, false)
	var album_tabs: TabContainer = tab_nodes[0] as TabContainer if not tab_nodes.is_empty() else null
	var album_titles: Array[String] = []
	if album_tabs != null:
		for index: int in album_tabs.get_tab_count():
			album_titles.append(album_tabs.get_tab_title(index))
	_expect_eq(
		album_titles,
		[tr("ALBUM_EXPRESSIONS"), tr("ALBUM_MEMORIES"), tr("ALBUM_DIARY"), tr("ALBUM_LIFE_PLANS")],
		"the real album preserves its three original pages and adds a distinct little-plans page"
	)
	var diary: Control = album_tabs.get_child(2) as Control if album_tabs != null and album_tabs.get_child_count() >= 3 else null
	if album_tabs != null and diary != null:
		album_tabs.current_tab = 2
	await get_tree().process_frame
	var replay_button: Button
	if diary != null:
		for node: Node in diary.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == tr("ENDING_REPLAY"):
				replay_button = button
				break
	_expect_true(
		diary != null
			and _count_labels_with_text(diary, tr("ENDING_FREE_COMPANION")) == 1
			and replay_button != null,
		"the chapter diary records free companion mode and keeps the ending replay available"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/chapter-diary-ending.png")
	var completed_points: int = session.pig_state.daily_points
	var completed_xp: int = session.pig_state.familiarity_xp
	var completed_seen_events: Array[String] = session.pig_state.seen_events.duplicate()
	if replay_button != null:
		replay_button.pressed.emit()
	await get_tree().process_frame
	panel_content = ui.get("_panel_content") as VBoxContainer
	ending_textures = panel_content.find_children("*", "TextureRect", true, false) if panel_content != null else []
	_expect_true(
		panel_content != null
			and _count_labels_with_text(panel_content, tr("ENDING_CREDITS")) == 1
			and not ending_textures.is_empty()
			and FileAccess.get_file_as_bytes(stored_ending_photo_path) == ending_photo_bytes,
		"replaying the ending from the diary reuses the original photo and credits"
	)
	_expect_true(
		session.pig_state.daily_points == completed_points
			and session.pig_state.familiarity_xp == completed_xp
			and session.pig_state.seen_events == completed_seen_events,
		"replaying the ending presentation cannot duplicate event rewards or collection progress"
	)
	var replay_continue: Button
	if panel_content != null:
		for node: Node in panel_content.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == tr("ENDING_CONTINUE"):
				replay_continue = button
				break
	if replay_continue != null:
		replay_continue.pressed.emit()
	if previous_ending_photo_exists:
		var restored_photo := FileAccess.open(ending_photo_path, FileAccess.WRITE)
		if restored_photo != null:
			restored_photo.store_buffer(previous_ending_photo_bytes)
			restored_photo.close()
	elif FileAccess.file_exists(ending_photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ending_photo_path))
	session.pig_state.load_dict(previous_pig_state)
	event_director.load_dict(previous_event_director)
	session.save_game()
	ui.call("_refresh")
	await get_tree().process_frame


func _test_desktop_animation_pause(main: Node, session: Node, ui: Control) -> void:
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_director: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_autosave: float = float(session.get("_autosave_elapsed"))
	var previous_event_elapsed: float = float(session.get("_event_elapsed"))
	var previous_focus: bool = session.focus_mode
	var previous_frequency: bool = session.reduce_desktop_action_frequency
	var session_was_processing: bool = session.is_processing()
	session.set_process(false)
	session.set_focus_mode(false)
	ui.call("_close_panel")
	for reduced: bool in [false, true]:
		var label: String = "paused desktop reduced=%s" % reduced
		session.pig_state.load_dict(previous_state)
		session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[5] + 5
		session.pig_state.familiarity_level = 6
		session.pig_state.energy = 60.0
		session.pig_state.interest = 60.0
		session.pig_state.tutorial_skipped = true
		session.pig_state.pending_events.clear()
		session.pig_state.summarized_events.clear()
		session.pig_state.seen_events.erase("event_radio_dance")
		session.pig_state.discovered_events.erase("event_radio_dance")
		if not "event_move_in" in session.pig_state.seen_events:
			session.pig_state.seen_events.append("event_move_in")
		if not "event_move_in" in session.pig_state.discovered_events:
			session.pig_state.discovered_events.append("event_move_in")
		if not "furn_radio" in session.pig_state.owned_furniture:
			session.pig_state.owned_furniture.append("furn_radio")
		for slot: String in session.pig_state.placed_furniture.keys():
			if str(session.pig_state.placed_furniture[slot]) == "furn_radio":
				session.pig_state.placed_furniture.erase(slot)
		session.pig_state.placed_furniture["window_3"] = "furn_radio"
		session.behavior_director.recent_ids.clear()
		session.behavior_director.cooldown_until.clear()
		session.event_director.last_triggered_unix.clear()
		session.event_director.recent_event_ids.clear()
		session.set("_event_elapsed", 0.0)
		session.set("_autosave_elapsed", 0.0)
		session.set_reduce_desktop_action_frequency(reduced)
		session.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":0.25}, session.catalog)
		session.simulation.announce_current_behavior()
		_expect_eq(session.save_game(), OK, "%s starts from a valid committed simulation checkpoint" % label)
		ui.call("_refresh")
		var desktop_button: Button = ui.get("_desktop_button") as Button
		if desktop_button != null:
			desktop_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var menus: Array[Node] = controller.find_children("*", "MenuButton", true, false)
		var menu: PopupMenu = (menus[0] as MenuButton).get_popup() if not menus.is_empty() else null
		_expect_true(controller.active and menu != null and not get_tree().paused, "%s enters through the real HUD and exposes the animation command" % label)
		if menu == null:
			continue
		if controller.transparent_mode:
			menu.id_pressed.emit(4)
		var before_pause_state: Dictionary = session.pig_state.to_dict().duplicate(true)
		var before_pause_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
		var save_paths: Array[String] = [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]
		var before_pause_generations: Array[PackedByteArray] = []
		for path: String in save_paths:
			before_pause_generations.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		menu.id_pressed.emit(3)
		var after_pause_generations: Array[PackedByteArray] = []
		for path: String in save_paths:
			after_pause_generations.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_true(session.pig_state.to_dict() == before_pause_state and session.simulation.to_dict() == before_pause_simulation, "%s pause command does not mutate shared progression or its timer" % label)
		_expect_eq(after_pause_generations, before_pause_generations, "%s pause command leaves the main save and both backup generations byte-identical" % label)
		var frozen_animation: String = pig.behavior_animation
		var frozen_phase: float = float(pig.get("_phase"))
		var frozen_position: Vector2 = pig.position
		var frozen_frame: Image = await _settled_desktop_frame()
		var pig_region := Rect2i(pig.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, frozen_frame.get_size()))
		_expect_true(not pig.is_processing() and frozen_animation == "idle" and Engine.max_fps == DesktopFramePolicy.DESKTOP_IDLE_FPS, "%s freezes the current visual and uses the idle frame budget" % label)
		var started_ids: Array[String] = []
		var started_listener := func(behavior: Dictionary) -> void: started_ids.append(str(behavior.get("id", "")))
		session.behavior_changed.connect(started_listener)
		for next_id: String in ["behavior_sleep", "behavior_walk"]:
			var now: int = session.clock.current_unix()
			for behavior: Dictionary in session.catalog.behaviors:
				session.behavior_director.cooldown_until[str(behavior.id)] = now + 3600
			session.behavior_director.cooldown_until.erase(next_id)
			var completed: Dictionary = session.current_behavior_snapshot()
			var points_before: int = session.pig_state.daily_points
			var xp_before: int = session.pig_state.familiarity_xp
			var time_before: float = session.pig_state.active_seconds
			session.simulation.remaining_seconds = 0.25
			session.set("_last_process_unix", now)
			session.call("_advance_runtime_frame", 0.5, now)
			_expect_eq(str(session.current_behavior_snapshot().get("id", "")), next_id, "%s real runtime completes and selects %s while visuals are paused" % [label, next_id])
			_expect_true(is_equal_approx(session.pig_state.active_seconds - time_before, 0.5), "%s consumes exactly the supplied runtime delta once for %s" % [label, next_id])
			var points: int = session.pig_state.daily_points - points_before
			_expect_true(points >= int(completed.points_min) and points <= int(completed.points_max), "%s grants the normal completion reward before %s" % [label, next_id])
			_expect_eq(session.pig_state.familiarity_xp, xp_before + 1, "%s preserves normal familiarity progress before %s" % [label, next_id])
			_expect_true(session.behavior_director.recent_ids[-1] == str(completed.id) and int(session.behavior_director.cooldown_until[str(completed.id)]) == now + int(completed.cooldown_seconds), "%s advances real completion history and cooldown before %s" % [label, next_id])
			controller.call("_update_behavior_presentation", DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS + 1.0)
			await get_tree().process_frame
			var current_frame: Image = await _settled_desktop_frame()
			_expect_eq(pig.behavior_animation, frozen_animation, "%s autonomous %s cannot replace the paused pose" % [label, next_id])
			_expect_true(float(pig.get("_phase")) == frozen_phase and pig.position == frozen_position and not pig.is_processing(), "%s autonomous %s cannot advance phase or roaming" % [label, next_id])
			_expect_true(pig_region.has_area() and current_frame.get_size() == frozen_frame.get_size() and current_frame.get_region(pig_region).get_data() == frozen_frame.get_region(pig_region).get_data(), "%s autonomous %s leaves the rendered pig pixels unchanged" % [label, next_id])
		_expect_eq(started_ids, ["behavior_sleep", "behavior_walk"], "%s uses two production behavior signals, not direct visual setters" % label)
		var memory_time_before: float = session.pig_state.active_seconds
		var memory_points_before: int = session.pig_state.daily_points
		var memory_now: int = session.clock.current_unix()
		for event: Dictionary in session.catalog.events:
			session.event_director.last_triggered_unix[str(event.id)] = memory_now
		session.event_director.last_triggered_unix.erase("event_radio_dance")
		session.set("_event_elapsed", GameSession.EVENT_CHECK_SECONDS)
		session.set("_last_process_unix", memory_now)
		session.call("_advance_runtime_frame", 0.0, memory_now)
		var memory_button: Button = controller.get("_event_bubble_button") as Button
		var persisted: Dictionary = session.save_service.load_game()
		_expect_true(bool(persisted.get("ok", false)) and "event_radio_dance" in persisted.data.pig_state.pending_events, "%s discovers and durably queues a real memory while animation is paused" % label)
		_expect_true(memory_button != null and memory_button.is_visible_in_tree() and "1" in memory_button.text and ui.find_children("*", "EventViewer", true, false).is_empty(), "%s still refreshes the single deferred-memory bubble without auto-playing" % label)
		_expect_true(session.pig_state.active_seconds == memory_time_before and session.pig_state.daily_points == memory_points_before, "%s memory discovery does not duplicate time or award watch rewards" % label)
		var visual_pending: Dictionary = controller.get("_pending_behavior") as Dictionary
		_expect_eq(str(visual_pending.get("id", "")), "behavior_walk", "%s retains only the newest pending visual behavior" % label)
		menu.id_pressed.emit(5)
		_expect_eq(pig.behavior_animation, frozen_animation, "%s frequency changes cannot bypass animation pause" % label)
		menu.id_pressed.emit(5)
		_expect_eq(pig.behavior_animation, frozen_animation, "%s restoring the frequency preference still leaves the pose frozen" % label)
		var pressed_kinds: Array[String] = []
		var pressed_listener := func(kind: String) -> void: pressed_kinds.append(kind)
		pig.pressed.connect(pressed_listener)
		var interaction_key: String = "pet:%s" % GameClock.local_date_string(session.clock.current_unix())
		var interactions_before: int = int(session.pig_state.interaction_counts.get(interaction_key, 0))
		var before_input_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
		_send_scaled_pig_input(pig)
		pig.pressed.disconnect(pressed_listener)
		_expect_eq(pressed_kinds, ["poke", "pet", "poke", "pet"], "%s deliberately requested mouse/touch interactions still reach the real pig" % label)
		_expect_eq(int(session.pig_state.interaction_counts.get(interaction_key, 0)), interactions_before + 4, "%s deliberate input still uses the production interaction transaction" % label)
		_expect_true(pig.active_reaction_signature() == "happy:expr_happy_soft" and not pig.is_processing() and float(pig.get("_phase")) == frozen_phase, "%s deliberate reaction feedback is allowed without restarting autonomous animation" % label)
		_expect_eq(session.simulation.to_dict(), before_input_simulation, "%s deliberate input does not rewind or restart the shared behavior timer" % label)
		var before_resume_state: Dictionary = session.pig_state.to_dict().duplicate(true)
		var before_resume_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
		menu.id_pressed.emit(3)
		_expect_true(pig.is_processing() and not bool(controller.get("_paused_animation")) and pig.behavior_animation == "walk", "%s explicit resume immediately presents the newest behavior, never the intermediate sleep" % label)
		_expect_true((controller.get("_pending_behavior") as Dictionary).is_empty() and Engine.max_fps == DesktopFramePolicy.DESKTOP_ACTIVE_FPS, "%s resume clears the pending visual and restores the active frame budget" % label)
		_expect_true(session.pig_state.to_dict() == before_resume_state and session.simulation.to_dict() == before_resume_simulation and started_ids == ["behavior_sleep", "behavior_walk"], "%s resume does not replay behaviors, duplicate time, or grant extra rewards" % label)
		await get_tree().create_timer(1.1).timeout
		_expect_true(float(pig.get("_phase")) > frozen_phase and pig.active_reaction_signature().is_empty(), "%s resumed visual advances normally and expires the deliberate reaction" % label)
		session.behavior_changed.disconnect(started_listener)
		menu.id_pressed.emit(3)
		var room_button: Button
		for node: Node in controller.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == tr("DESKTOP_ROOM"):
				room_button = button
				break
		if room_button != null:
			room_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not controller.active and not session.desktop_mode and pig.is_processing() and not bool(controller.get("_paused_animation")) and ui.visible, "%s real return button clears only the desktop pause state" % label)
		_expect_eq(pig.behavior_animation, "walk", "%s returning to the room presents the current shared behavior" % label)
		_expect_true(session.pig_state.to_dict() == before_resume_state and session.simulation.to_dict() == before_resume_simulation, "%s returning to the room preserves the simulation boundary and rewards" % label)
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_director)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.set("_autosave_elapsed", previous_autosave)
	session.set("_event_elapsed", previous_event_elapsed)
	session.set_focus_mode(previous_focus)
	session.set_reduce_desktop_action_frequency(previous_frequency)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	session.simulation.announce_current_behavior()
	main.call("_refresh_pig")
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(session_was_processing)
	ui.call("_refresh")


func _test_desktop_unobstructed_companion(main: Node, session: Node, ui: Control) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "foreground desktop-layout fixture acquires settled native focus")
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var previous_locale: String = TranslationServer.get_locale()
	var session_was_processing: bool = session.is_processing()
	var pig_was_processing: bool = pig.is_processing()
	var controller_was_processing: bool = controller.is_processing()
	session.set_process(false)
	session.pig_state.familiarity_xp = maxi(session.pig_state.familiarity_xp, PigState.FAMILIARITY_THRESHOLDS[1])
	session.pig_state.familiarity_level = maxi(session.pig_state.familiarity_level, 2)
	session.pig_state.tutorial_skipped = true
	ui.call("_refresh")
	ui.call("_close_panel")
	var main_handler := Callable(main, "_on_pig_pressed")
	pig.pressed.disconnect(main_handler)
	var pressed_kinds: Array[String] = []
	var pressed_handler := func(kind: String) -> void: pressed_kinds.append(kind)
	pig.pressed.connect(pressed_handler)
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		var desktop_button: Button = ui.get("_desktop_button") as Button
		if desktop_button != null:
			desktop_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		controller.set_process(false)
		pig.set_process(false)
		pig.set_behavior({"animation":"idle"})
		var menu_nodes: Array[Node] = controller.find_children("*", "MenuButton", true, false)
		var menu: PopupMenu = (menu_nodes[0] as MenuButton).get_popup() if not menu_nodes.is_empty() else null
		_expect_true(menu != null and controller.active, "%s unobstructed companion fixture uses the production scale menu" % locale)
		if menu != null and controller.transparent_mode:
			menu.id_pressed.emit(4)
		var bubble: PanelContainer = controller.get("_event_bubble") as PanelContainer
		var bubble_button: Button = controller.get("_event_bubble_button") as Button
		var memory_handler := Callable(controller, "_open_pending_memory")
		if bubble_button != null and bubble_button.pressed.is_connected(memory_handler):
			bubble_button.pressed.disconnect(memory_handler)
		for percentage: int in [50, 75, 100, 125, 150]:
			if menu != null:
				menu.id_pressed.emit(percentage)
			await get_tree().process_frame
			await get_tree().process_frame
			var window_size: Vector2i = DisplayServer.window_get_size()
			var window_position: Vector2i = DisplayServer.window_get_position()
			var settings_before: Dictionary = session.save_service.load_settings().duplicate(true)
			var simulation_before: Dictionary = session.simulation.to_dict().duplicate(true)
			for count: int in [1, 24]:
				var pending: Array[String] = []
				var summarized: Array[String] = []
				for event_index: int in count:
					var event_id: String = str(session.catalog.events[event_index].id)
					if event_index < 5:
						pending.append(event_id)
					else:
						summarized.append(event_id)
					if not event_id in session.pig_state.discovered_events:
						session.pig_state.discovered_events.append(event_id)
					session.pig_state.seen_events.erase(event_id)
				session.pig_state.pending_events = pending
				session.pig_state.summarized_events = summarized
				_expect_eq(session.save_game(), OK, "%s scale=%d%% memory count=%d fixture commits valid pending/summary queues before layout observation" % [locale, percentage, count])
				var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
				session.memory_queue_changed.emit()
				await RenderingServer.frame_post_draw
				var label: String = "%s scale=%d%% memories=%d" % [locale, percentage, count]
				var window_bounds := Rect2(Vector2.ZERO, Vector2(window_size))
				var pig_rect: Rect2 = pig.get_global_rect()
				var bubble_rect: Rect2 = bubble.get_global_rect() if bubble != null else Rect2()
				var controls: Array[Node] = controller.find_children("*", "MenuButton", true, false)
				var bar: Control = controls[0].get_parent().get_parent() as Control if not controls.is_empty() else null
				var bar_rect: Rect2 = bar.get_global_rect() if bar != null else Rect2()
				_expect_true(bubble_button != null and bubble_button.is_visible_in_tree() and str(count) in bubble_button.text, "%s keeps one visible localized deferred-memory action" % label)
				_expect_true(_rect_inside(window_bounds, pig_rect) and _rect_inside(window_bounds, bubble_rect) and _rect_inside(window_bounds, bar_rect), "%s keeps pig, memory bubble and return/menu controls wholly in the native window" % label)
				_expect_true(not pig_rect.intersects(bubble_rect) and not pig_rect.intersects(bar_rect), "%s reserves a control region outside the whole character canvas" % label)
				_expect_true(bubble_button != null and bubble_button.get_combined_minimum_size().x <= bubble_button.size.x + 1.0 and bubble_button.get_combined_minimum_size().y <= bubble_button.size.y + 1.0, "%s fits translated memory text at its real font size (minimum=%s actual=%s)" % [label, bubble_button.get_combined_minimum_size() if bubble_button != null else Vector2.ZERO, bubble_button.size if bubble_button != null else Vector2.ZERO])
				var with_controls: Image = await _settled_desktop_frame()
				controller.set_screenshot_controls_visible(false)
				var without_controls: Image = await _settled_desktop_frame()
				controller.set_screenshot_controls_visible(true)
				var reference_region: Rect2i = Rect2i(pig_rect).intersection(Rect2i(Vector2i.ZERO, window_size))
				var unchanged_pixels: bool = with_controls.get_size() == without_controls.get_size() and reference_region.has_area()
				if unchanged_pixels:
					unchanged_pixels = with_controls.get_region(reference_region).get_data() == without_controls.get_region(reference_region).get_data()
				_expect_true(unchanged_pixels, "%s renders the same complete character canvas with the real controls visible" % label)
				pressed_kinds.clear()
				_send_scaled_pig_input(pig)
				_expect_eq(pressed_kinds, ["poke", "pet", "poke", "pet"], "%s routes visible nose/body mouse and touch input to the pig rather than overlaid controls" % label)
				var polygon: PackedVector2Array = controller.call("_update_passthrough", window_size)
				_expect_true(not Geometry2D.triangulate_polygon(polygon).is_empty() and Geometry2D.is_point_in_polygon(bubble_rect.get_center(), polygon) and Geometry2D.is_point_in_polygon(bar_rect.get_center(), polygon), "%s native hit geometry preserves the memory and return/menu actions" % label)
				var controls_inside: bool = true
				for rectangle: Rect2 in [bubble_rect, bar_rect]:
					for point: Vector2 in [rectangle.position + Vector2.ONE, Vector2(rectangle.end.x - 1.0, rectangle.position.y + 1.0), rectangle.end - Vector2.ONE, Vector2(rectangle.position.x + 1.0, rectangle.end.y - 1.0)]:
						controls_inside = controls_inside and Geometry2D.is_point_in_polygon(point, polygon)
				_expect_true(controls_inside, "%s retains all native hit edges of the actual localized controls" % label)
				DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
				pig.position.x = float(window_size.x)
				controller.call("_update_desktop_roaming", 0.0)
				var right_rect: Rect2 = pig.get_global_rect()
				_expect_true(not right_rect.intersects(bubble_rect) and not right_rect.intersects(bar_rect), "%s protects controls across the entire roaming envelope" % label)
				pig.position.x = pig_rect.position.x
				_expect_true(DisplayServer.window_get_size() == window_size and DisplayServer.window_get_position() == window_position and session.save_service.load_settings() == settings_before, "%s queue updates never resize or re-dock the companion or rewrite window preferences" % label)
				_expect_true(session.pig_state.to_dict() == state_before and session.simulation.to_dict() == simulation_before, "%s defers all memories without presentation side effects, rewards or extra simulation time" % label)
				if percentage == 50 and count == 1 and not OS.get_environment("PIGGAME_LAYOUT_PROBE").is_empty():
					with_controls.save_png("user://desktop-control-layout-%s.png" % locale)
			get_window().size = Vector2i(215, 140)
			controller.set_process(true)
			await get_tree().process_frame
			await get_tree().process_frame
			controller.set_process(false)
			await RenderingServer.frame_post_draw
			var resized_bounds := Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size()))
			var resized_pig: Rect2 = pig.get_global_rect()
			var resized_bubble: Rect2 = bubble.get_global_rect() if bubble != null else Rect2()
			_expect_true(_rect_inside(resized_bounds, resized_pig) and _rect_inside(resized_bounds, resized_bubble), "%s scale=%d%% native resize floor protects the selected character size and memory action" % [locale, percentage])
			_expect_true(not resized_pig.intersects(resized_bubble), "%s scale=%d%% resizing cannot collapse the control rail onto the character" % [locale, percentage])
		if bubble_button != null:
			bubble_button.pressed.connect(memory_handler)
		controller.leave()
		await get_tree().process_frame
		await get_tree().process_frame
		pig.set_process(false)
	pig.pressed.disconnect(pressed_handler)
	pig.pressed.connect(main_handler)
	TranslationServer.set_locale(previous_locale)
	session.pig_state.load_dict(previous_state)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	main.call("_refresh_pig")
	pig.set_behavior(session.simulation.current_behavior)
	pig.set_process(pig_was_processing)
	controller.set_process(controller_was_processing)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(session_was_processing)
	ui.call("_refresh")
	await get_tree().process_frame


func _test_desktop_pig_scale_roundtrip(main: Node, session: Node, ui: Control, fixture_frame: int = 0) -> void:
	_expect_true(await _wait_for_foreground_focus(session), "foreground desktop-scale fixture acquires settled native focus")
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var was_processing: bool = session.is_processing()
	var pig_was_processing: bool = pig.is_processing()
	var controller_was_processing: bool = controller.is_processing()
	var previous_layout: Dictionary = _pig_control_layout(pig)
	session.set_process(false)
	session.pig_state.familiarity_xp = maxi(session.pig_state.familiarity_xp, PigState.FAMILIARITY_THRESHOLDS[1])
	session.pig_state.familiarity_level = maxi(session.pig_state.familiarity_level, 2)
	session.pig_state.tutorial_skipped = true
	_expect_eq(session.save_game(), OK, "desktop scale fixture commits unlocked companion progress")
	ui.call("_refresh")
	ui.call("_close_panel")
	var main_handler := Callable(main, "_on_pig_pressed")
	_expect_true(pig.pressed.is_connected(main_handler), "scale input fixture starts with the real scene interaction handler connected")
	pig.pressed.disconnect(main_handler)
	var pressed_kinds: Array[String] = []
	var pressed_handler := func(kind: String) -> void: pressed_kinds.append(kind)
	pig.pressed.connect(pressed_handler)
	for cycle: int in 2:
		for percentage: int in [50, 75, 100, 125, 150]:
			pig.set_anchors_preset(Control.PRESET_CENTER if cycle == 0 else Control.PRESET_CENTER_LEFT)
			pig.size = Vector2(280, 230) if cycle == 0 else Vector2(300, 245)
			pig.scale = Vector2.ONE if cycle == 0 else Vector2(0.9, 1.1)
			pig.position = Vector2(470 + cycle * 12, 310)
			var room_layout: Dictionary = _pig_control_layout(pig)
			var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
			var simulation_before: Dictionary = session.simulation.to_dict().duplicate(true)
			var label: String = "cycle=%d scale=%d%% frame=%d" % [cycle + 1, percentage, fixture_frame]
			_begin_scaled_pig_drag(pig, "mouse" if cycle == 0 else "touch")
			_expect_true(pig.position != room_layout.position, "%s begins a real temporary room drag before the mode transition" % label)
			var desktop_button: Button = ui.get("_desktop_button") as Button
			if desktop_button != null:
				desktop_button.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			controller.set_process(false)
			pig.set_process(false)
			pig.set("_phase", float(fixture_frame) * VisualFramePolicy.FRAME_STEP)
			pig.set("_frame_time", 0.0)
			pig.set_behavior({"animation":"idle"})
			var menu_nodes: Array[Node] = controller.find_children("*", "MenuButton", true, false)
			var menu: PopupMenu = (menu_nodes[0] as MenuButton).get_popup() if not menu_nodes.is_empty() else null
			_expect_true(menu != null and controller.active and session.desktop_mode, "%s enters the production companion and real scale menu" % label)
			if menu != null:
				if controller.transparent_mode:
					menu.id_pressed.emit(4)
				menu.id_pressed.emit(100)
			await get_tree().process_frame
			await get_tree().process_frame
			var reference_pixels: Rect2i = await _desktop_pig_pixel_bounds(controller, pig)
			if menu != null:
				menu.id_pressed.emit(percentage)
			await get_tree().process_frame
			await get_tree().process_frame
			var factor: float = float(percentage) / 100.0
			var visual_rect: Rect2 = pig.get_global_rect()
			var expected_size: Vector2 = Vector2(280, 230) * factor
			var window_size: Vector2i = DisplayServer.window_get_size()
			_expect_eq(visual_rect.size, expected_size, "%s scales the real character interaction rectangle uniformly" % label)
			_expect_true(_rect_inside(Rect2(Vector2.ZERO, Vector2(window_size)), visual_rect), "%s keeps the whole character interaction rectangle inside the window" % label)
			var pixels: Rect2i = await _desktop_pig_pixel_bounds(controller, pig)
			_expect_true(reference_pixels.has_area() and pixels.has_area(), "%s renders actual character pixels at both reference and selected scale" % label)
			_expect_true(
				absf(float(pixels.size.x) - float(reference_pixels.size.x) * factor) <= 3.0
					and absf(float(pixels.size.y) - float(reference_pixels.size.y) * factor) <= 3.0,
				"%s scales rendered character pixels (reference=%s selected=%s expected=%s)" % [label, reference_pixels.size, pixels.size, Vector2(reference_pixels.size) * factor]
			)
			pressed_kinds.clear()
			var controls_were_visible: bool = controller.set_screenshot_controls_visible(false)
			_send_scaled_pig_input(pig)
			controller.set_screenshot_controls_visible(controls_were_visible)
			_expect_eq(pressed_kinds, ["poke", "pet", "poke", "pet"], "%s routes native viewport mouse and touch positions to the scaled snout/body regions" % label)
			var bubble: PanelContainer = controller.get("_event_bubble") as PanelContainer
			var expected_polygon: PackedVector2Array = DesktopFramePolicy.mouse_passthrough_polygon(visual_rect, window_size, bubble != null and bubble.visible)
			var polygon: PackedVector2Array = controller.call("_update_passthrough", window_size)
			_expect_eq(polygon, expected_polygon, "%s submits the actual scaled character rectangle to the native passthrough adapter" % label)
			DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
			var hit_points_inside: bool = true
			for point: Vector2 in [_normalized_snout_point(pig), Vector2(0.72, 0.50)]:
				hit_points_inside = hit_points_inside and Geometry2D.is_point_in_polygon(pig.get_global_transform() * (pig.size * point), polygon)
			_expect_true(hit_points_inside, "%s keeps the visible snout/body hit points in the desktop passthrough geometry" % label)
			pig.position.x = float(window_size.x)
			controller.call("_update_desktop_roaming", 0.0)
			var bounds: Vector2 = DesktopFramePolicy.roaming_bounds(DesktopFramePolicy.character_area_width(float(window_size.x)), expected_size.x, session.desktop_roaming_reduced())
			_expect_true(is_equal_approx(pig.position.x, bounds.y), "%s clamps roaming with the scaled visual width" % label)
			_expect_true(session.pig_state.to_dict() == state_before and session.simulation.to_dict() == simulation_before, "%s leaves progression and simulation unchanged during visual scaling and synthetic input" % label)
			var return_button: Button
			for node: Node in controller.find_children("*", "Button", true, false):
				var button := node as Button
				if button != null and button.text == tr("DESKTOP_ROOM"):
					return_button = button
					break
			var return_available: bool = return_button != null
			if return_available:
				return_button.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			pig.set_process(false)
			_expect_true(return_available and not controller.active and not session.desktop_mode and ui.visible and pig.dragging_enabled, "%s returns through the real control and restores the playable room" % label)
			_expect_eq(_pig_control_layout(pig), room_layout, "%s restores the original room anchors, offsets, size, scale and position" % label)
			pressed_kinds.clear()
			_send_scaled_pig_input(pig)
			_expect_eq(pressed_kinds, ["poke", "pet", "poke", "pet"], "%s restores the room mouse/touch hit regions after returning" % label)
			var persisted: Dictionary = session.save_service.load_game()
			var expected_checkpoint: Dictionary = JSON.parse_string(JSON.stringify(state_before)) as Dictionary
			_expect_true(bool(persisted.get("ok", false)) and session.pig_state.to_dict() == state_before and session.simulation.to_dict() == simulation_before and (persisted.data.pig_state as Dictionary) == expected_checkpoint, "%s preserves the same progression checkpoint without extra rewards or time" % label)
	pig.pressed.disconnect(pressed_handler)
	pig.pressed.connect(main_handler)
	for side: int in 4:
		pig.set_anchor(side, previous_layout.anchors[side], false)
	for side: int in 4:
		pig.set_offset(side, previous_layout.offsets[side])
	pig.scale = previous_layout.scale
	session.pig_state.load_dict(previous_state)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	main.call("_refresh_pig")
	pig.set_behavior(session.simulation.current_behavior)
	pig.set_process(pig_was_processing)
	controller.set_process(controller_was_processing)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.call("_refresh")
	await get_tree().process_frame


func _pig_control_layout(pig: PigVisual) -> Dictionary:
	return {
		"anchors":[pig.anchor_left, pig.anchor_top, pig.anchor_right, pig.anchor_bottom],
		"offsets":[pig.offset_left, pig.offset_top, pig.offset_right, pig.offset_bottom],
		"size":pig.size,
		"scale":pig.scale,
		"position":pig.position,
	}


func _desktop_pig_pixel_bounds(controller: DesktopWindowController, pig: PigVisual) -> Rect2i:
	var controls_were_visible: bool = controller.set_screenshot_controls_visible(false)
	pig.hide()
	var background: Image = await _settled_desktop_frame()
	pig.show()
	var visible: Image = await _settled_desktop_frame()
	controller.set_screenshot_controls_visible(controls_were_visible)
	if background.is_empty() or visible.is_empty() or background.get_size() != visible.get_size():
		return Rect2i()
	var minimum := Vector2i(visible.get_width(), visible.get_height())
	var maximum := Vector2i(-1, -1)
	for pixel_y: int in visible.get_height():
		for pixel_x: int in visible.get_width():
			if visible.get_pixel(pixel_x, pixel_y) != background.get_pixel(pixel_x, pixel_y):
				minimum.x = mini(minimum.x, pixel_x)
				minimum.y = mini(minimum.y, pixel_y)
				maximum.x = maxi(maximum.x, pixel_x)
				maximum.y = maxi(maximum.y, pixel_y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()


func _settled_desktop_frame() -> Image:
	for _attempt: int in 12:
		await RenderingServer.frame_post_draw
		var captured: Image = get_window().get_texture().get_image()
		if not captured.is_empty() and captured.get_size() == DisplayServer.window_get_size():
			return captured
		await get_tree().process_frame
	return Image.new()


func _send_scaled_pig_input(pig: PigVisual) -> void:
	for source: String in ["mouse", "touch"]:
		for point: Vector2 in [_normalized_snout_point(pig), Vector2(0.72, 0.50)]:
			var position: Vector2 = pig.get_global_transform() * (pig.size * point)
			if source == "mouse":
				var press := InputEventMouseButton.new()
				press.position = position
				press.global_position = position
				press.button_index = MOUSE_BUTTON_LEFT
				press.button_mask = MOUSE_BUTTON_MASK_LEFT
				press.pressed = true
				get_viewport().push_input(press, true)
				var release := press.duplicate() as InputEventMouseButton
				release.pressed = false
				release.button_mask = 0
				get_viewport().push_input(release, true)
			else:
				var press := InputEventScreenTouch.new()
				press.position = position
				press.index = 32
				press.pressed = true
				get_viewport().push_input(press, true)
				var release := press.duplicate() as InputEventScreenTouch
				release.pressed = false
				get_viewport().push_input(release, true)


func _begin_scaled_pig_drag(pig: PigVisual, source: String) -> void:
	var position: Vector2 = pig.get_global_transform() * (pig.size * Vector2(0.72, 0.50))
	if source == "mouse":
		var press := InputEventMouseButton.new()
		press.position = position
		press.global_position = position
		press.button_index = MOUSE_BUTTON_LEFT
		press.button_mask = MOUSE_BUTTON_MASK_LEFT
		press.pressed = true
		get_viewport().push_input(press, true)
		var motion := InputEventMouseMotion.new()
		motion.position = position + Vector2(40, 0)
		motion.global_position = motion.position
		motion.relative = Vector2(40, 0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
	else:
		var press := InputEventScreenTouch.new()
		press.position = position
		press.index = 31
		press.pressed = true
		get_viewport().push_input(press, true)
		var motion := InputEventScreenDrag.new()
		motion.position = position + Vector2(40, 0)
		motion.relative = Vector2(40, 0)
		motion.index = 31
		get_viewport().push_input(motion, true)


func _test_manual_screenshot(main: Node, session: Node, ui: Control) -> void:
	var directory: String = session.save_service.base_dir + "/screenshots"
	var before: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else PackedStringArray()
	var screenshot_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("UI_SCREENSHOT"):
			screenshot_button = button
			break
	_expect_true(
		screenshot_button != null and screenshot_button.is_visible_in_tree() and not screenshot_button.disabled,
		"the manual photo action is available on the real HUD"
	)
	if screenshot_button != null:
		screenshot_button.pressed.emit()
	var after: PackedStringArray = before
	for _attempt: int in 12:
		await get_tree().process_frame
		after = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else PackedStringArray()
		if after.size() > before.size():
			break
	var created: Array[String] = []
	for file_name: String in after:
		if file_name.ends_with(".png") and file_name not in before:
			created.append(file_name)
	_expect_true(created.size() == 1, "the real manual photo HUD action writes one new PNG into the profile screenshot directory")
	var screenshot: Image
	if created.size() == 1:
		screenshot = Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [directory, created[0]]))
	_expect_true(
		screenshot != null and not screenshot.is_empty() and screenshot.get_size() == get_window().size,
		"manual photo captures the full current viewport"
	)
	_expect_true(ui.visible, "manual photo restores the HUD immediately after its UI-free capture")
	await RenderingServer.frame_post_draw
	var live_image: Image = get_window().get_texture().get_image()
	var compare_rect := Rect2i(0, 0, mini(260, live_image.get_width()), mini(150, live_image.get_height()))
	_expect_true(
		screenshot != null
			and not screenshot.is_empty()
			and not live_image.is_empty()
			and hash(screenshot.get_region(compare_rect).get_data()) != hash(live_image.get_region(compare_rect).get_data()),
		"manual photo omits the top HUD while the restored live frame includes it"
	)


func _test_manual_screenshot_frame_contract(main: Node, session: Node, ui: Control) -> void:
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var was_processing: bool = session.is_processing()
	var pig_was_processing: bool = pig.is_processing()
	var controller_was_processing: bool = controller.is_processing()
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	var previous_position: Vector2 = pig.position
	var previous_size: Vector2 = pig.size
	session.set_process(false)
	session.pig_state.familiarity_xp = maxi(session.pig_state.familiarity_xp, PigState.FAMILIARITY_THRESHOLDS[1])
	session.pig_state.familiarity_level = maxi(session.pig_state.familiarity_level, 2)
	if not "event_move_in" in session.pig_state.discovered_events:
		session.pig_state.discovered_events.append("event_move_in")
	session.pig_state.seen_events.erase("event_move_in")
	session.pig_state.summarized_events.erase("event_move_in")
	var pending: Array[String] = ["event_move_in"]
	session.pig_state.pending_events = pending
	ui.call("_refresh")
	for _generation: int in 3:
		_expect_eq(session.save_game(), OK, "screenshot input fixture protects three committed save generations")
	var screenshot_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("UI_SCREENSHOT"):
			screenshot_button = button
			break
	_expect_true(screenshot_button != null, "frame-boundary screenshot test uses the real HUD button")
	var toast_keys: Array[String] = []
	var toast_handler := func(key: String, _values: Dictionary) -> void: toast_keys.append(key)
	session.toast_requested.connect(toast_handler)
	var directory: String = session.manual_screenshot_directory()
	var save_paths: Array[String] = [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]
	for test_case: String in ["room_mouse", "room_key", "hidden_room_key", "desktop_key"]:
		if test_case == "desktop_key":
			var desktop_button: Button = ui.get("_desktop_button") as Button
			if desktop_button != null:
				desktop_button.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			var bubble: PanelContainer = controller.get("_event_bubble") as PanelContainer
			_expect_true(desktop_button != null and not desktop_button.disabled and controller.active and session.desktop_mode and not ui.visible and bubble != null and bubble.is_visible_in_tree(), "screenshot keyboard fixture enters the real desktop companion mode with an unread memory bubble")
		pig.set_process(false)
		controller.set_process(false)
		ui.visible = test_case in ["room_mouse", "room_key"]
		var ui_was_visible: bool = ui.visible
		var controls_value: Variant = controller.get("_controls_layer")
		var controls: CanvasLayer = controls_value as CanvasLayer if is_instance_valid(controls_value) else null
		var controls_were_visible: bool = is_instance_valid(controls) and controls.visible
		ui.hide()
		if is_instance_valid(controls):
			controls.hide()
		await RenderingServer.frame_post_draw
		var clean_frame: Image = get_window().get_texture().get_image()
		ui.visible = ui_was_visible
		if is_instance_valid(controls):
			controls.visible = controls_were_visible
		await RenderingServer.frame_post_draw
		var before: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else PackedStringArray()
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		var files_before: Array[PackedByteArray] = []
		for path: String in save_paths:
			files_before.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		toast_keys.clear()
		_send_manual_screenshot_input(screenshot_button if test_case == "room_mouse" else null)
		_send_manual_screenshot_input(null)
		_expect_true(bool(main.get("_screenshot_in_progress")), "%s starts one asynchronous capture at the rendered input boundary" % test_case)
		var created: Array[String] = await _wait_for_manual_screenshot(directory, before)
		_expect_eq(created.size(), 1, "%s and its immediate duplicate input write exactly one screenshot" % test_case)
		var screenshot: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [directory, created[0]])) if created.size() == 1 else null
		_expect_true(screenshot != null and not screenshot.is_empty() and screenshot.get_size() == clean_frame.get_size(), "%s preserves the full rendered viewport dimensions" % test_case)
		_expect_eq(ui.visible, ui_was_visible, "%s restores the previous room-HUD visibility instead of revealing hidden UI" % test_case)
		_expect_true(not is_instance_valid(controls) or controls.visible == controls_were_visible, "%s restores the previous desktop control-layer visibility" % test_case)
		_expect_true(screenshot != null and not screenshot.is_empty() and screenshot.get_data() == clean_frame.get_data(), "%s captures the freshly rendered clean frame without HUD, desktop controls or memory bubbles" % test_case)
		_expect_eq(session.pig_state.to_dict(), state_before, "%s cannot change progression, collections or queues" % test_case)
		var files_after: Array[PackedByteArray] = []
		for path: String in save_paths:
			files_after.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
		_expect_eq(files_after, files_before, "%s cannot rewrite or rotate three save generations" % test_case)
		_expect_eq(toast_keys, ["TOAST_SCREENSHOT_SAVED"], "%s reports exactly one completed screenshot" % test_case)
		_expect_true(not bool(main.get("_screenshot_in_progress")), "%s releases the duplicate-input guard after saving" % test_case)
	if controller.active:
		controller.leave()
		await get_tree().process_frame
		await get_tree().process_frame
	session.toast_requested.disconnect(toast_handler)
	ui.show()
	pig.position = previous_position
	pig.size = previous_size
	session.pig_state.load_dict(previous_state)
	session.save_game()
	session.save_service.save_settings(previous_settings)
	main.call("_refresh_pig")
	pig.set_process(pig_was_processing)
	controller.set_process(controller_was_processing)
	session.set_process(was_processing)
	ui.call("_refresh")
	await get_tree().process_frame


func _test_startup_save_recovery_ui(session: Node, ui: Control) -> void:
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
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
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	var previous_locale: String = TranslationServer.get_locale()
	var previous_scale: float = session.ui_scale
	var previous_size: Vector2i = get_window().size
	var previous_content_size: Vector2i = get_window().content_scale_size
	session.set_process(false)
	ui.hide()
	var service := SaveService.new("user://startup_recovery_ui_tests")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
	var cases: Array[Dictionary] = [
		{"locale":"zh_CN", "size":Vector2i(1280, 720), "scale":1.0},
		{"locale":"zh_TW", "size":Vector2i(1280, 800), "scale":0.8},
		{"locale":"en", "size":Vector2i(2560, 1080), "scale":1.0},
		{"locale":"en", "size":Vector2i(960, 540), "scale":1.5},
	]
	for test_case: Dictionary in cases:
		var label: String = "save recovery %s %s scale=%s" % [test_case.locale, test_case.size, test_case.scale]
		TranslationServer.set_locale(str(test_case.locale))
		session.ui_scale = float(test_case.scale)
		get_window().content_scale_size = Vector2i(1280, 720)
		get_window().size = test_case.size
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string("{unreadable original progress")
			file.close()
		session.last_offline_summary = {}
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var overlay: ColorRect = recovery_ui.get("_overlay") as ColorRect
		var title: Label = recovery_ui.get("_panel_title") as Label
		var body: Label = recovery_ui.find_child("SaveRecoveryMessage", true, false) as Label
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		var exit_button: Button = recovery_ui.find_child("SaveRecoveryExitButton", true, false) as Button
		_expect_true(session.save_recovery_required and overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE"), "%s startup prioritizes recovery over fresh-pig onboarding" % label)
		_expect_true(recovery_ui.find_child("NameConfirmButton", true, false) == null, "%s does not offer a replacement save through naming" % label)
		_expect_true(body != null and body.text == tr("SAVE_RECOVERY_MESSAGE").format({"path": ProjectSettings.globalize_path(service.base_dir)}) and not body.text.contains("SAVE_RECOVERY_MESSAGE"), "%s shows the localized protection explanation and actual save folder" % label)
		_expect_true(retry != null and retry.is_visible_in_tree() and exit_button != null and exit_button.is_visible_in_tree(), "%s offers retry and explicit exit without saving" % label)
		var viewport_rect := Rect2(Vector2.ZERO, recovery_ui.size)
		_expect_true(_rect_inside(viewport_rect, (recovery_ui.get("_panel") as PanelContainer).get_global_rect()), "%s keeps the recovery panel within safe viewport margins" % label)
		var scroll: ScrollContainer = recovery_ui.get("_panel_scroll") as ScrollContainer
		_expect_true(_rect_inside(scroll.get_global_rect(), body.get_global_rect()) and _rect_inside(scroll.get_global_rect(), retry.get_global_rect()) and _rect_inside(scroll.get_global_rect(), exit_button.get_global_rect()), "%s explanation and both actions are actually visible without scrolling" % label)
		_expect_true((recovery_ui.get("_toast_panel") as PanelContainer).modulate.a == 0.0, "%s does not obscure recovery with a misleading disk-write toast" % label)
		_expect_true(exit_button.pressed.is_connected(session.force_exit_without_saving), "%s explicit exit routes to the no-save production command" % label)
		var header: HBoxContainer = title.get_parent() as HBoxContainer
		_expect_true(header != null and not (header.get_child(1) as Control).visible, "%s recovery cannot be dismissed by the generic close button" % label)
		for event: InputEvent in InputMap.action_get_events("pause"):
			if event is InputEventKey:
				var pressed: InputEventKey = event.duplicate() as InputEventKey
				pressed.pressed = true
				Input.parse_input_event(pressed)
				var released: InputEventKey = pressed.duplicate() as InputEventKey
				released.pressed = false
				Input.parse_input_event(released)
				break
		await get_tree().process_frame
		_expect_true(overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE"), "%s bound Escape input cannot dismiss unresolved recovery" % label)
		recovery_ui.show_exit_choice()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE") and recovery_ui.find_child("ExitAllButton", true, false) == null, "%s window-close choice cannot replace the recovery page with normal save-and-exit" % label)
		recovery_ui.show_exit_save_failure()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE") and recovery_ui.find_child("ExitFailureCancelButton", true, false) == null, "%s a failed exit checkpoint cannot offer a bypass back to the replacement pig" % label)
		recovery_ui.call("_rebuild_ui")
		await get_tree().process_frame
		await get_tree().process_frame
		overlay = recovery_ui.get("_overlay") as ColorRect
		title = recovery_ui.get("_panel_title") as Label
		retry = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true(overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s UI rebuilding retains recovery and a live retry command" % label)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and overlay.visible, "%s real retry remains blocked while original files are unreadable" % label)
		var originals_preserved: bool = true
		for path: String in paths:
			originals_preserved = originals_preserved and FileAccess.get_file_as_string(path) == "{unreadable original progress"
		_expect_true(originals_preserved and not FileAccess.file_exists(service.temp_path), "%s failed retry leaves all original files untouched" % label)
		for path: String in paths:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and overlay.visible and title.text == tr("SAVE_RECOVERY_TITLE"), "%s retry with temporarily absent originals remains on the recovery page" % label)
		_expect_true(not FileAccess.file_exists(service.save_path) and not FileAccess.file_exists(service.backup_1_path) and not FileAccess.file_exists(service.backup_2_path) and not FileAccess.file_exists(service.temp_path), "%s absent originals do not create a fresh save through UI retry" % label)
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string("{unreadable original progress")
			file.close()
		var recovered := PigState.new()
		recovered.name = "Recovered Pig"
		recovered.daily_points = 321
		recovered.tutorial_skipped = true
		var backup := FileAccess.open(service.backup_2_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify({"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":3000, "pig_state":recovered.to_dict()}))
		backup.close()
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.last_save_error.is_empty(), "%s real retry resumes after a valid backup is restored" % label)
		_expect_true(session.pig_state.name == "Recovered Pig" and session.pig_state.daily_points == 321, "%s restores actual progress rather than starting over" % label)
		_expect_true(not (recovery_ui.get("_overlay") as ColorRect).visible and recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s successful recovery returns to a usable room without another blocking page" % label)
		_expect_eq(session.save_game(), OK, "%s recovered session can save through the normal facade" % label)
		recovery_ui.queue_free()
		await get_tree().process_frame
	TranslationServer.set_locale("zh_CN")
	session.ui_scale = 1.0
	get_window().size = Vector2i(1280, 720)
	for next_page: String in ["naming", "ending", "offline"]:
		session.last_offline_summary = {}
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string("{unreadable original progress")
			file.close()
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true((recovery_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE"), "%s handoff starts on the protected recovery page" % next_page)
		var recovered := PigState.new()
		recovered.name = "" if next_page == "naming" else "Recovered Pig"
		recovered.daily_points = 321
		recovered.tutorial_skipped = next_page != "naming"
		recovered.ending_unlocked = next_page == "ending"
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":2880 if next_page == "offline" else 3000, "pig_state":recovered.to_dict()}
		_expect_true(bool(service.call("_is_valid_game_payload", payload)), "%s handoff uses a schema-valid restored generation" % next_page)
		var backup := FileAccess.open(service.backup_2_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(payload))
		backup.close()
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var expected_title: String = str({"naming":"NAME_PROMPT_TITLE", "ending":"ENDING_TITLE", "offline":"OFFLINE_TITLE"}[next_page])
		_expect_true(not session.save_recovery_required and (recovery_ui.get("_overlay") as ColorRect).visible and (recovery_ui.get("_panel_title") as Label).text == tr(expected_title), "%s restored generation continues its real startup flow" % next_page)
		_expect_true(recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null and session.pig_state.daily_points == 321, "%s handoff removes the recovery command without replacing progression" % next_page)
		recovery_ui.queue_free()
		await get_tree().process_frame
	var user_directory: String = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	var isolated_profile_fixture: bool = user_directory.begins_with("PiggameUISmoke-") or user_directory.begins_with("PiggameGodotChecks-")
	_expect_true(isolated_profile_fixture, "profile-boundary UI fixture requires an explicitly isolated user directory")
	if isolated_profile_fixture:
		var source := SaveService.new(ReleaseProfile.save_base_dir("demo"))
		var source_paths: Array[String] = [source.save_path, source.backup_1_path, source.backup_2_path, source.temp_path]
		var source_snapshots: Array[Dictionary] = []
		for path: String in source_paths:
			source_snapshots.append(session.call("_snapshot_file", path) as Dictionary)
		var demo_pig := PigState.new()
		demo_pig.name = "Demo Pig"
		demo_pig.daily_points = 17
		demo_pig.tutorial_skipped = true
		var demo_payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"demo", "last_saved_unix":3000, "pig_state":demo_pig.to_dict()}
		_expect_eq(source.save_game(demo_payload), OK, "profile-boundary UI fixture creates a real separate Demo source")
		var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source.save_path)
		var original: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string("{broken original Full progression")
			file.close()
			original.append(FileAccess.get_file_as_bytes(path))
		session.last_offline_summary = {}
		session.call("_load_or_create_game")
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		var import_notices: Array[bool] = []
		var on_import: Callable = func() -> void: import_notices.append(true)
		session.demo_progress_imported.connect(on_import)
		var profile_ui := MainUI.new()
		get_window().add_child(profile_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and not session.demo_save_imported, "existing Full target initially blocks import from the real separate Demo")
		var moved_all: bool = true
		for path: String in paths:
			moved_all = DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".held")) == OK and moved_all
		_expect_true(moved_all, "profile-boundary UI fixture moves all Full originals aside without deleting them")
		var retry: Button = profile_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and not session.demo_save_imported, "real UI retry cannot treat an older separate Demo as recovered Full progress")
		_expect_true(import_notices.is_empty(), "real UI retry emits no misleading cross-profile import success")
		_expect_eq(session.pig_state.to_dict(), state_before, "real UI retry keeps the original in-memory recovery boundary")
		_expect_true(not FileAccess.file_exists(service.save_path) and not FileAccess.file_exists(service.backup_1_path) and not FileAccess.file_exists(service.backup_2_path) and not FileAccess.file_exists(service.temp_path), "real UI retry cannot write a substitute Full save from the Demo")
		var held_unchanged: bool = true
		for path_index: int in paths.size():
			held_unchanged = FileAccess.get_file_as_bytes(paths[path_index] + ".held") == original[path_index] and held_unchanged
		_expect_true(held_unchanged, "real UI retry preserves all moved Full generations byte-for-byte")
		_expect_eq(FileAccess.get_file_as_bytes(source.save_path), source_bytes, "real UI retry preserves the separate Demo source bytes")
		_expect_true((profile_ui.get("_overlay") as ColorRect).visible and (profile_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and profile_ui.find_child("SaveRecoveryRetryButton", true, false) != null, "real UI retry retains the recovery page and live command instead of silently returning to the Demo pig")
		var full_pig := PigState.new()
		full_pig.name = "Full Pig"
		full_pig.daily_points = 432
		full_pig.tutorial_skipped = true
		var full_payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":"full", "last_saved_unix":3000, "pig_state":full_pig.to_dict()}
		_expect_true(bool(service.call("_is_valid_game_payload", full_payload)), "profile-boundary UI restoration uses a schema-valid Full generation")
		var backup := FileAccess.open(service.backup_2_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(full_payload))
		backup.close()
		retry = profile_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and not session.demo_save_imported and session.pig_state.name == "Full Pig" and session.pig_state.daily_points == 432, "restoring the actual Full backup resumes Full identity and progression through the real retry button")
		_expect_true(not (profile_ui.get("_overlay") as ColorRect).visible and profile_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "actual Full restoration returns to the usable room without a misleading import page")
		session.demo_progress_imported.disconnect(on_import)
		profile_ui.queue_free()
		await get_tree().process_frame
		for path: String in paths:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".held"))
		for path_index: int in source_paths.size():
			_expect_eq(session.call("_restore_file", source_paths[path_index], source_snapshots[path_index]), OK, "profile-boundary UI fixture restores its separate source snapshot %d" % path_index)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(source.base_dir))
	var malformed_versions: Dictionary = {"numeric_string":"3", "fractional":3.5}
	for label: String in malformed_versions:
		var recovered := PigState.new()
		recovered.name = "Schema Pig"
		recovered.daily_points = 432
		recovered.tutorial_skipped = true
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":3000, "pig_state":recovered.to_dict()}
		var invalid: Dictionary = payload.duplicate(true)
		invalid["schema_version"] = malformed_versions[label]
		invalid.pig_state.name = "Damaged Pig"
		invalid.pig_state.daily_points = 17
		_expect_true(not bool(service.call("_is_valid_game_payload", invalid)), "%s UI fixture has a truly invalid source schema" % label)
		var originals: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			originals.append(FileAccess.get_file_as_bytes(path))
		session.last_offline_summary = {}
		session.last_recovery_source = ""
		session.last_save_error = ""
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_load_or_create_game")
		var schema_ui := MainUI.new()
		get_window().add_child(schema_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and session.pig_state.to_dict() == state_before, "%s malformed schema cannot become an apparently valid old progression" % label)
		var retry: Button = schema_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true((schema_ui.get("_overlay") as ColorRect).visible and (schema_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s malformed schema shows the real protected recovery page" % label)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and (schema_ui.get("_overlay") as ColorRect).visible, "%s real retry remains blocked before a valid schema is restored" % label)
		_expect_true(FileAccess.get_file_as_bytes(paths[0]) == originals[0] and FileAccess.get_file_as_bytes(paths[1]) == originals[1] and FileAccess.get_file_as_bytes(paths[2]) == originals[2] and not FileAccess.file_exists(service.temp_path), "%s failed retry preserves all malformed generations byte-for-byte" % label)
		_expect_true(bool(service.call("_is_valid_game_payload", payload)), "%s UI recovery uses a semantically valid current-schema generation" % label)
		var backup := FileAccess.open(service.backup_2_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(payload))
		backup.close()
		var restored_backup: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_2_path)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.pig_state.name == "Schema Pig" and session.pig_state.daily_points == 432, "%s real retry restores the valid backup rather than malformed 17-point progress" % label)
		_expect_eq(session.last_recovery_source, service.backup_2_path, "%s real retry identifies backup2 as the valid schema source" % label)
		_expect_true(not (schema_ui.get("_overlay") as ColorRect).visible and schema_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s valid schema recovery returns to a usable room" % label)
		_expect_true(FileAccess.get_file_as_bytes(paths[1]) == originals[1] and FileAccess.get_file_as_bytes(paths[2]) == restored_backup, "%s valid schema recovery preserves both backup generations" % label)
		var loaded: Dictionary = service.load_game()
		var saved: Dictionary = loaded.get("data", {}) as Dictionary
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(saved.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and int((saved.get("pig_state", {}) as Dictionary).get("daily_points", 0)) == 432, "%s recovered main reloads the exact current-schema balance" % label)
		schema_ui.queue_free()
		await get_tree().process_frame
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	TranslationServer.set_locale(previous_locale)
	session.ui_scale = previous_scale
	get_window().content_scale_size = previous_content_size
	get_window().size = previous_size
	ui.show()
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_unnamed_save_type_recovery_ui(session: Node, ui: Control) -> void:
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.hide()
	var service := SaveService.new("user://unnamed_save_type_recovery_ui_tests")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
	var fields: Dictionary = {"tutorial_step":SaveService.CURRENT_SCHEMA, "tutorial_skipped":SaveService.CURRENT_SCHEMA}
	for field: String in fields:
		var restored := PigState.new()
		restored.name = "Backup Pig"
		restored.daily_points = 432
		restored.tutorial_skipped = true
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":3000, "pig_state":restored.to_dict()}
		var invalid: Dictionary = payload.duplicate(true)
		invalid.schema_version = int(fields[field])
		invalid.pig_state.name = ""
		invalid.pig_state.daily_points = 17
		invalid.pig_state.tutorial_step = 1
		invalid.pig_state[field] = {"tutorial_step":{}, "tutorial_skipped":"false"}[field]
		var current_control: Dictionary = invalid.duplicate(true)
		current_control.schema_version = SaveService.CURRENT_SCHEMA
		_expect_true(not bool(service.call("_is_valid_game_payload", current_control)), "%s UI control confirms that the same current-schema onboarding field is invalid" % field)
		var originals: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			originals.append(FileAccess.get_file_as_bytes(path))
		session.last_offline_summary = {}
		session.last_recovery_source = ""
		session.last_save_error = ""
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and session.pig_state.to_dict() == state_before, "%s malformed unnamed onboarding field cannot replace progression or unlock a milestone" % field)
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true((recovery_ui.get("_overlay") as ColorRect).visible and (recovery_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s unnamed onboarding corruption shows the real recovery page instead of an unearned ending or ordinary room" % field)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and (recovery_ui.get("_overlay") as ColorRect).visible, "%s real retry remains blocked while every onboarding field is malformed" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[0]) == originals[0] and FileAccess.get_file_as_bytes(paths[1]) == originals[1] and FileAccess.get_file_as_bytes(paths[2]) == originals[2] and not FileAccess.file_exists(service.temp_path), "%s unsuccessful onboarding retry preserves the three original generations" % field)
		_expect_true(bool(service.call("_is_valid_game_payload", payload)), "%s onboarding recovery fixture supplies legitimate boolean milestone flags" % field)
		var backup := FileAccess.open(service.backup_1_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(payload))
		backup.close()
		var restored_backup: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.pig_state.name == "Backup Pig" and session.pig_state.daily_points == 432 and not session.pig_state.ending_unlocked and not session.pig_state.ending_seen and not session.pig_state.demo_completion_seen and session.pig_state.tutorial_step == 0 and session.pig_state.tutorial_skipped, "%s real retry restores backup identity, balance and all unacknowledged milestones" % field)
		_expect_eq(session.last_recovery_source, service.backup_1_path, "%s onboarding recovery identifies the actual backup1 source" % field)
		_expect_true(not (recovery_ui.get("_overlay") as ColorRect).visible and recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s legitimate backup returns to a usable room without an unearned ending" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[1]) == restored_backup and FileAccess.get_file_as_bytes(paths[2]) == originals[2], "%s successful onboarding recovery keeps both backup generations unchanged" % field)
		var loaded: Dictionary = service.load_game()
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var state: Dictionary = data.get("pig_state", {}) as Dictionary
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and int(state.get("daily_points", 0)) == 432 and state.get("ending_unlocked", true) == false and state.get("ending_seen", true) == false and state.get("demo_completion_seen", true) == false and state.get("tutorial_step", -1) == 0 and state.get("tutorial_skipped", false) == true, "%s restored main reloads exact legitimate milestone values" % field)
		recovery_ui.queue_free()
		await get_tree().process_frame
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.show()
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_integer_save_recovery_ui(session: Node, ui: Control) -> void:
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.hide()
	var service := SaveService.new("user://integer_save_recovery_ui_tests")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
	var fields: Dictionary = {"daily_points":SaveService.CURRENT_SCHEMA, "last_saved_unix":SaveService.CURRENT_SCHEMA}
	for field: String in fields:
		var restored := PigState.new()
		restored.name = "Backup Pig"
		restored.daily_points = 432
		restored.tutorial_skipped = true
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":3000, "pig_state":restored.to_dict()}
		var invalid: Dictionary = payload.duplicate(true)
		invalid.schema_version = int(fields[field])
		invalid.pig_state.name = "Damaged Pig"
		invalid.pig_state.daily_points = 17
		if field == "daily_points":
			invalid.pig_state.daily_points = 17.000001
		else:
			invalid.last_saved_unix = 3000.000001
		var current_control: Dictionary = invalid.duplicate(true)
		current_control.schema_version = SaveService.CURRENT_SCHEMA
		_expect_true(not bool(service.call("_is_valid_game_payload", current_control)), "%s UI control confirms that the same current-schema fractional counter or timestamp is invalid" % field)
		var originals: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			originals.append(FileAccess.get_file_as_bytes(path))
		session.last_offline_summary = {}
		session.last_recovery_source = ""
		session.last_save_error = ""
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and session.pig_state.to_dict() == state_before, "%s non-integral save field cannot replace progression or unlock a milestone" % field)
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true((recovery_ui.get("_overlay") as ColorRect).visible and (recovery_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s non-integral numeric corruption shows the real recovery page instead of an unearned ending or ordinary room" % field)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and (recovery_ui.get("_overlay") as ColorRect).visible, "%s real retry remains blocked while every numeric field is malformed" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[0]) == originals[0] and FileAccess.get_file_as_bytes(paths[1]) == originals[1] and FileAccess.get_file_as_bytes(paths[2]) == originals[2] and not FileAccess.file_exists(service.temp_path), "%s unsuccessful numeric retry preserves the three original generations" % field)
		_expect_true(bool(service.call("_is_valid_game_payload", payload)), "%s numeric recovery fixture supplies legitimate boolean milestone flags" % field)
		var backup := FileAccess.open(service.backup_1_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(payload))
		backup.close()
		var restored_backup: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.pig_state.name == "Backup Pig" and session.pig_state.daily_points == 432 and not session.pig_state.ending_unlocked and not session.pig_state.ending_seen and not session.pig_state.demo_completion_seen, "%s real retry restores backup identity, balance and all unacknowledged milestones" % field)
		_expect_eq(session.last_recovery_source, service.backup_1_path, "%s numeric recovery identifies the actual backup1 source" % field)
		_expect_true(not (recovery_ui.get("_overlay") as ColorRect).visible and recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s legitimate backup returns to a usable room without an unearned ending" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[1]) == restored_backup and FileAccess.get_file_as_bytes(paths[2]) == originals[2], "%s successful numeric recovery keeps both backup generations unchanged" % field)
		var loaded: Dictionary = service.load_game()
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var state: Dictionary = data.get("pig_state", {}) as Dictionary
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and int(state.get("daily_points", 0)) == 432 and state.get("ending_unlocked", true) == false and state.get("ending_seen", true) == false and state.get("demo_completion_seen", true) == false, "%s restored main reloads exact legitimate milestone values" % field)
		recovery_ui.queue_free()
		await get_tree().process_frame
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.show()
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_legacy_boolean_recovery_ui(session: Node, ui: Control) -> void:
	var previous_service: SaveService = session.save_service
	var previous_clock: GameClock = session.clock
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_behavior: Dictionary = session.behavior_director.to_dict().duplicate(true)
	var previous_events: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_simulation: Dictionary = session.simulation.to_dict().duplicate(true)
	var previous_summary: Dictionary = session.last_offline_summary.duplicate(true)
	var previous_pending_summary: Dictionary = (ui.get("_pending_offline_summary") as Dictionary).duplicate(true)
	var previous_error: String = session.last_save_error
	var previous_recovery: String = session.last_recovery_source
	var previous_imported: bool = session.demo_save_imported
	var previous_required: bool = session.save_recovery_required
	var previous_saved_unix: int = int(session.get("_last_saved_unix"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	ui.hide()
	var service := SaveService.new("user://legacy_boolean_recovery_ui_tests")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	service.recovery_used.connect(session._on_save_recovered)
	service.save_failed.connect(session._on_save_failed)
	session.save_service = service
	session.clock = GameClock.new(func() -> int: return 3000)
	var paths: Array[String] = [service.save_path, service.backup_1_path, service.backup_2_path]
	var fields: Dictionary = {"ending_unlocked":1, "demo_completion_seen":3}
	for field: String in fields:
		var restored := PigState.new()
		restored.name = "Backup Pig"
		restored.daily_points = 432
		restored.tutorial_skipped = true
		var payload := {"schema_version":SaveService.CURRENT_SCHEMA, "release_profile":ReleaseProfile.profile_id(), "last_saved_unix":3000, "pig_state":restored.to_dict()}
		var invalid: Dictionary = payload.duplicate(true)
		invalid.schema_version = int(fields[field])
		invalid.pig_state.name = "Damaged Pig"
		invalid.pig_state.daily_points = 17
		invalid.pig_state[field] = 1
		var current_control: Dictionary = invalid.duplicate(true)
		current_control.schema_version = SaveService.CURRENT_SCHEMA
		_expect_true(not bool(service.call("_is_valid_game_payload", current_control)), "%s UI control confirms that the same current-schema integer flag is invalid" % field)
		var originals: Array[PackedByteArray] = []
		for path: String in paths:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(invalid))
			file.close()
			originals.append(FileAccess.get_file_as_bytes(path))
		session.last_offline_summary = {}
		session.last_recovery_source = ""
		session.last_save_error = ""
		var state_before: Dictionary = session.pig_state.to_dict().duplicate(true)
		session.call("_load_or_create_game")
		var recovery_ui := MainUI.new()
		get_window().add_child(recovery_ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and session.pig_state.to_dict() == state_before, "%s malformed legacy flag cannot replace progression or unlock a milestone" % field)
		var retry: Button = recovery_ui.find_child("SaveRecoveryRetryButton", true, false) as Button
		_expect_true((recovery_ui.get("_overlay") as ColorRect).visible and (recovery_ui.get("_panel_title") as Label).text == tr("SAVE_RECOVERY_TITLE") and retry != null, "%s legacy corruption shows the real recovery page instead of an unearned ending or ordinary room" % field)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		_expect_true(session.save_recovery_required and (recovery_ui.get("_overlay") as ColorRect).visible, "%s real retry remains blocked while every legacy flag is malformed" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[0]) == originals[0] and FileAccess.get_file_as_bytes(paths[1]) == originals[1] and FileAccess.get_file_as_bytes(paths[2]) == originals[2] and not FileAccess.file_exists(service.temp_path), "%s unsuccessful legacy retry preserves the three original generations" % field)
		_expect_true(bool(service.call("_is_valid_game_payload", payload)), "%s legacy recovery fixture supplies legitimate boolean milestone flags" % field)
		var backup := FileAccess.open(service.backup_1_path, FileAccess.WRITE)
		backup.store_string(JSON.stringify(payload))
		backup.close()
		var restored_backup: PackedByteArray = FileAccess.get_file_as_bytes(service.backup_1_path)
		if retry != null:
			retry.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_expect_true(not session.save_recovery_required and session.pig_state.name == "Backup Pig" and session.pig_state.daily_points == 432 and not session.pig_state.ending_unlocked and not session.pig_state.ending_seen and not session.pig_state.demo_completion_seen, "%s real retry restores backup identity, balance and all unacknowledged milestones" % field)
		_expect_eq(session.last_recovery_source, service.backup_1_path, "%s legacy recovery identifies the actual backup1 source" % field)
		_expect_true(not (recovery_ui.get("_overlay") as ColorRect).visible and recovery_ui.find_child("SaveRecoveryRetryButton", true, false) == null, "%s legitimate backup returns to a usable room without an unearned ending" % field)
		_expect_true(FileAccess.get_file_as_bytes(paths[1]) == restored_backup and FileAccess.get_file_as_bytes(paths[2]) == originals[2], "%s successful legacy recovery keeps both backup generations unchanged" % field)
		var loaded: Dictionary = service.load_game()
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var state: Dictionary = data.get("pig_state", {}) as Dictionary
		_expect_true(bool(loaded.get("ok", false)) and not bool(loaded.get("recovered", true)) and int(data.get("schema_version", -1)) == SaveService.CURRENT_SCHEMA and int(state.get("daily_points", 0)) == 432 and state.get("ending_unlocked", true) == false and state.get("ending_seen", true) == false and state.get("demo_completion_seen", true) == false, "%s restored main reloads exact legitimate milestone values" % field)
		recovery_ui.queue_free()
		await get_tree().process_frame
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.base_dir))
	service.recovery_used.disconnect(session._on_save_recovered)
	service.save_failed.disconnect(session._on_save_failed)
	session.save_service = previous_service
	session.clock = previous_clock
	session.pig_state.load_dict(previous_state)
	session.behavior_director.load_dict(previous_behavior)
	session.event_director.load_dict(previous_events)
	session.simulation.load_dict(previous_simulation, session.catalog)
	session.last_offline_summary = previous_summary
	session.last_save_error = previous_error
	session.last_recovery_source = previous_recovery
	session.demo_save_imported = previous_imported
	session.save_recovery_required = previous_required
	session.set("_last_saved_unix", previous_saved_unix)
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	ui.show()
	ui.set("_pending_offline_summary", previous_pending_summary)
	ui.call("_rebuild_ui")
	await get_tree().process_frame
	await get_tree().process_frame


func _test_event_photo_capture_isolation(main: Node, session: Node, ui: Control) -> void:
	var was_processing: bool = session.is_processing()
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var pig_was_processing: bool = pig.is_processing()
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var previous_settings: Dictionary = session.save_service.load_settings().duplicate(true)
	session.set_process(false)
	pig.set_process(false)
	var previous_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var previous_event_director: Dictionary = session.event_director.to_dict().duplicate(true)
	var previous_ui_scale: float = session.ui_scale
	var previous_window_size: Vector2i = get_window().size
	var previous_content_size: Vector2i = get_window().content_scale_size
	var event: Dictionary = session.catalog.get_item("events", "event_move_in")
	var photo_path: String = "%s/photos/%s.png" % [session.save_service.base_dir, str(event.get("photo_id", ""))]
	var previous_photo_exists: bool = FileAccess.file_exists(photo_path)
	var previous_photo_bytes: PackedByteArray = FileAccess.get_file_as_bytes(photo_path) if previous_photo_exists else PackedByteArray()
	var directory: String = session.manual_screenshot_directory()
	var cases: Array[Dictionary] = [
		{"action":"close", "before":true, "size":Vector2i(1280, 720), "scale":1.0},
		{"action":"close", "before":false, "size":Vector2i(1280, 800), "scale":0.8},
		{"action":"manual", "before":true, "size":Vector2i(2560, 1080), "scale":1.0},
		{"action":"manual", "before":false, "size":Vector2i(1280, 720), "scale":1.5},
		{"action":"manual", "before":true, "size":Vector2i(960, 540), "scale":1.5},
		{"action":"close", "before":false, "size":Vector2i(960, 540), "scale":0.8},
		{"action":"resize", "before":false, "size":Vector2i(1280, 720), "scale":1.0},
		{"action":"desktop", "before":false, "size":Vector2i(1280, 720), "scale":1.0},
		{"action":"cancel", "before":false, "size":Vector2i(1280, 720), "scale":1.0},
	]
	for test_case: Dictionary in cases:
		var label: String = "event photo %s %s %s scale=%s" % [test_case.action, "before" if test_case.before else "after", test_case.size, test_case.scale]
		ui.call("_close_panel")
		get_window().size = test_case.size
		session.set_ui_scale(float(test_case.scale))
		ui.call("_rebuild_ui")
		await get_tree().process_frame
		await get_tree().process_frame
		var fixture := PigState.new()
		fixture.tutorial_skipped = true
		fixture.discovered_events = ["event_move_in"]
		fixture.pending_events = ["event_move_in"]
		if str(test_case.action) == "desktop":
			fixture.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
			fixture.familiarity_level = 2
		session.pig_state.load_dict(fixture.to_dict())
		var points_before_viewing: int = session.pig_state.daily_points
		var xp_before_viewing: int = session.pig_state.familiarity_xp
		_expect_eq(session.save_game(), OK, "%s commits a legal first-viewing fixture" % label)
		ui.call("_refresh")
		_expect_true(await _press_album_event_action(ui, event, tr("ALBUM_WATCH")), "%s begins through the actual album watch action" % label)
		var viewers: Array[Node] = ui.find_children("*", "EventViewer", true, false)
		var viewer: EventViewer = viewers[0] as EventViewer if viewers.size() == 1 else null
		_expect_true(viewer != null, "%s owns one production event viewer" % label)
		if viewer == null:
			continue
		viewer.set_process(false)
		var stage: EventStage = viewer.get("_stage") as EventStage
		stage.set_process(false)
		viewer.call("_apply_step", (viewer.get("_steps") as Array).size() - 1)
		stage.set_step_progress(0.72)
		stage.set("_phase", 0.0)
		var images: Array[Image] = []
		var completed: Array[bool] = []
		viewer.photo_captured.connect(func(_event_id: String, image: Image) -> void: images.append(image.duplicate()))
		viewer.finished.connect(func() -> void: completed.append(true))
		await get_tree().process_frame
		stage.size = (viewer.get("_stage_frame") as Control).size
		await RenderingServer.frame_post_draw
		var clean_room: Image
		if str(test_case.action) == "manual":
			ui.hide()
			await RenderingServer.frame_post_draw
			clean_room = get_window().get_texture().get_image()
			ui.show()
			await RenderingServer.frame_post_draw
		var reference: Image = _event_stage_pixels(stage)
		reference.convert(Image.FORMAT_RGBA8)
		var layers_before: int = get_window().find_children("*", "CanvasLayer", true, false).size()
		var viewports_before: int = get_window().find_children("*", "SubViewport", true, false).size()
		var committed_before: PackedByteArray = FileAccess.get_file_as_bytes(session.save_service.save_path)
		var manual_files_before: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else PackedStringArray()
		if bool(test_case.before):
			if str(test_case.action) == "close":
				main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			else:
				_send_manual_screenshot_input(null)
		viewer.call("_process", float(viewer.get("_duration")) * float(viewer.get("_duration_scale")))
		if not bool(test_case.before):
			if str(test_case.action) == "close":
				main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			elif str(test_case.action) == "manual":
				_send_manual_screenshot_input(null)
			elif str(test_case.action) == "resize":
				get_window().size = Vector2i(960, 540)
				get_window().content_scale_size = Vector2i(960, 540)
			elif str(test_case.action) == "desktop":
				main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
				var keep: Button = ui.find_child("ExitKeepDesktopButton", true, false) as Button
				_expect_true(keep != null and not keep.disabled, "%s uses the real close-window desktop choice" % label)
				if keep != null:
					keep.pressed.emit()
			elif str(test_case.action) == "cancel":
				ui.call("_rebuild_ui")
		if str(test_case.action) == "manual":
			_expect_true(bool(main.get("_screenshot_in_progress")) and not ui.visible, "%s overlaps a real bound screenshot input with the event capture frame" % label)
			_send_manual_screenshot_input(null)
		elif str(test_case.action) == "close":
			var title: Label = ui.get("_panel_title") as Label
			_expect_true((ui.get("_overlay") as ColorRect).visible and title.text == tr("EXIT_TITLE"), "%s overlaps the production close-window choice with the event capture frame" % label)
		elif str(test_case.action) == "desktop":
			_expect_true(controller.active and not ui.visible, "%s changes both the window geometry and parent visibility during capture" % label)
		elif str(test_case.action) == "resize":
			_expect_true(get_window().content_scale_size == Vector2i(960, 540), "%s changes the main viewport scale after capture has begun" % label)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await get_tree().process_frame
		if str(test_case.action) == "cancel":
			_expect_eq(images.size(), 0, "%s cannot publish a photo from a cancelled viewer" % label)
			_expect_eq(completed.size(), 0, "%s cannot publish phantom event completion" % label)
			_expect_true("event_move_in" in session.pig_state.pending_events and not "event_move_in" in session.pig_state.seen_events, "%s leaves the memory available to watch again" % label)
			_expect_eq(session.pig_state.daily_points, points_before_viewing, "%s cannot grant cancellation rewards" % label)
			_expect_eq(FileAccess.get_file_as_bytes(session.save_service.save_path), committed_before, "%s leaves committed progression byte-identical" % label)
			_expect_eq(get_window().find_children("*", "SubViewport", true, false).size(), viewports_before, "%s frees its owned capture viewport" % label)
			_expect_true(ui.find_children("*", "EventViewer", true, false).is_empty(), "%s releases the cancelled event viewer" % label)
			continue
		_expect_eq(images.size(), 1, "%s captures exactly one automatic event photo" % label)
		if not images.is_empty():
			images[0].convert(Image.FORMAT_RGBA8)
			_expect_eq(images[0].get_size(), reference.get_size(), "%s retains the actual stage pixel dimensions" % label)
			_expect_true(images[0].get_data() == reference.get_data(), "%s automatic photo cannot include an exit panel or a hidden underlying room" % label)
			var evidence_suffix: String = "%s-%s-%sx%s-%s.png" % [test_case.action, test_case.before, (test_case.size as Vector2i).x, (test_case.size as Vector2i).y, test_case.scale]
			images[0].save_png("user://event-photo-isolation-result-%s" % evidence_suffix)
			reference.save_png("user://event-photo-isolation-reference-%s" % evidence_suffix)
		var stored: Image = Image.load_from_file(ProjectSettings.globalize_path(photo_path))
		_expect_true(stored != null and not stored.is_empty(), "%s commits an actual life-photo PNG" % label)
		if stored != null and not stored.is_empty():
			stored.convert(Image.FORMAT_RGBA8)
			_expect_true(stored.get_data() == reference.get_data(), "%s committed PNG contains only the clean stage pixels" % label)
		_expect_eq(completed.size(), 1, "%s emits completion once" % label)
		_expect_true("event_move_in" in session.pig_state.seen_events and not "event_move_in" in session.pig_state.pending_events, "%s consumes the completed event once" % label)
		_expect_eq(session.pig_state.daily_points, points_before_viewing + 50, "%s grants only the configured event and first-expression points" % label)
		_expect_eq(session.pig_state.familiarity_xp, xp_before_viewing + 12, "%s grants only the configured event familiarity" % label)
		_expect_eq(ui.visible, str(test_case.action) != "desktop", "%s preserves the intended main-UI visibility after capture" % label)
		if controller.active:
			controller.leave()
			await get_tree().process_frame
			await get_tree().process_frame
			pig.set_process(false)
		_expect_eq(get_window().find_children("*", "CanvasLayer", true, false).size(), layers_before, "%s cannot leak a temporary capture layer" % label)
		_expect_eq(get_window().find_children("*", "SubViewport", true, false).size(), viewports_before, "%s cannot leak a temporary capture viewport" % label)
		if str(test_case.action) == "close":
			var cancel: Button = ui.find_child("ExitCancelButton", true, false) as Button
			_expect_true(cancel != null and cancel.is_visible_in_tree(), "%s preserves the usable close-window cancel choice" % label)
			if cancel != null:
				cancel.pressed.emit()
		elif str(test_case.action) == "manual":
			var new_files: Array[String] = []
			for file_name: String in DirAccess.get_files_at(directory):
				if not file_name in manual_files_before:
					new_files.append(file_name)
			_expect_eq(new_files.size(), 1, "%s still saves one independent manual PNG despite repeated input" % label)
			if new_files.size() == 1:
				var manual: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [directory, new_files[0]]))
				_expect_true(manual != null and manual.get_size() == get_window().get_texture().get_image().get_size(), "%s preserves the full-viewport manual screenshot contract" % label)
				_expect_true(manual != null and manual.get_data() == clean_room.get_data(), "%s manual screenshot still contains only the unoccluded room, never the promoted stage" % label)
			for file_name: String in new_files:
				DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [directory, file_name]))
		_expect_true(ui.find_children("*", "EventViewer", true, false).is_empty(), "%s releases the completed event viewer" % label)
	if previous_photo_exists:
		var restored := FileAccess.open(photo_path, FileAccess.WRITE)
		restored.store_buffer(previous_photo_bytes)
		restored.close()
	elif FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(photo_path))
	get_window().size = previous_window_size
	get_window().content_scale_size = previous_content_size
	session.set_ui_scale(previous_ui_scale)
	session.pig_state.load_dict(previous_state)
	session.event_director.load_dict(previous_event_director)
	session.save_service.save_settings(previous_settings)
	ui.call("_close_panel")
	ui.call("_rebuild_ui")
	_expect_eq(session.save_game(), OK, "event photo isolation restores its original committed progression")
	session.set("_last_process_unix", session.clock.current_unix())
	session.set_process(was_processing)
	pig.set_process(pig_was_processing)
	await get_tree().process_frame
	await get_tree().process_frame


func _send_manual_screenshot_input(button: Button) -> void:
	if button != null:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.button_mask = MOUSE_BUTTON_MASK_LEFT
		press.position = button.get_global_rect().get_center()
		press.global_position = press.position
		press.pressed = true
		get_viewport().push_input(press, true)
		var release := press.duplicate() as InputEventMouseButton
		release.pressed = false
		release.button_mask = 0
		get_viewport().push_input(release, true)
	else:
		var bindings: Array[InputEvent] = InputMap.action_get_events("screenshot")
		if bindings.is_empty():
			return
		var press := bindings[0].duplicate() as InputEventKey
		if press == null:
			return
		if press.physical_keycode != 0:
			press.keycode = press.physical_keycode
		press.pressed = true
		get_viewport().push_input(press)
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		get_viewport().push_input(release)


func _wait_for_manual_screenshot(directory: String, before: PackedStringArray) -> Array[String]:
	for _attempt: int in 12:
		await get_tree().process_frame
		var created: Array[String] = []
		var after: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)) else PackedStringArray()
		for file_name: String in after:
			if file_name.ends_with(".png") and file_name not in before:
				created.append(file_name)
		if not created.is_empty():
			return created
	return []


static func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 1.0
		and inner.position.y >= outer.position.y - 1.0
		and inner.end.x <= outer.end.x + 1.0
		and inner.end.y <= outer.end.y + 1.0
	)


static func _press_event_skip(viewer: Node) -> void:
	var skip: Button = viewer.find_child("EventSkipButton", true, false) as Button
	if skip != null:
		skip.pressed.emit()


func _test_outfit_visuals(session: Node) -> void:
	var output_dir := "res://build/validation/ui/outfits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var base_result: Dictionary = await _capture_outfit({}, "base", output_dir)
	var base_hash: int = int(base_result.get("hash", 0))
	var outfit_hashes: Dictionary = {}
	for outfit: Dictionary in session.catalog.outfits:
		var id: String = str(outfit.id)
		var result: Dictionary = await _capture_outfit(outfit, id, output_dir)
		var image: Image = result.get("image") as Image
		var image_hash: int = int(result.get("hash", 0))
		_expect_true(image != null and not image.is_empty(), "outfit renders to an image: %s" % id)
		_expect_true(image_hash != base_hash, "outfit changes the pig silhouette: %s" % id)
		_expect_true(not outfit_hashes.has(image_hash), "outfit visual is distinct: %s" % id)
		outfit_hashes[image_hash] = id
	_expect_true(outfit_hashes.size() == session.catalog.outfits.size(), "all outfits have distinct rendered smoke evidence")


func _test_outfit_controls(main: Node, session: Node, ui: Control) -> void:
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var target: Dictionary = session.catalog.get_item("outfits", "outfit_round_glasses")
	var target_id: String = str(target.get("id", ""))
	var target_price: int = int(target.get("price", 0))
	var starting_points: int = target_price + 500
	session.set_process(false)
	session.pig_state.familiarity_level = 10
	session.pig_state.daily_points = starting_points
	session.pig_state.owned_outfits.erase(target_id)
	session.pig_state.current_outfit = ""
	session.pig_state.tutorial_step = 7
	session.pig_state.tutorial_skipped = true
	ui.call("_close_panel")
	ui.call("_refresh")
	main.call("_refresh_pig")
	var outfits_entry: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("UI_OUTFITS"):
			outfits_entry = button
			break
	if outfits_entry != null:
		outfits_entry.pressed.emit()
	await get_tree().process_frame
	var buy_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	_expect_true(
		outfits_entry != null
			and buy_action != null
			and not buy_action.disabled
			and buy_action.text == tr("UI_BUY").format({"price":target_price}),
		"the real outfit entry opens a non-final unowned item in its buy state"
	)
	if buy_action != null:
		buy_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var equipped_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var remove: Button = ui.find_child("RemoveOutfitButton", true, false) as Button
	var equipped_save: Dictionary = session.save_service.load_game()
	var equipped_save_data: Dictionary = equipped_save.get("data", {}) as Dictionary
	var equipped_save_state: Dictionary = equipped_save_data.get("pig_state", {}) as Dictionary
	_expect_true(
		target_id in session.pig_state.owned_outfits
			and session.pig_state.current_outfit == target_id
			and session.pig_state.daily_points == starting_points - target_price
			and str(pig.outfit.get("id", "")) == target_id
			and equipped_action != null
			and equipped_action.disabled
			and equipped_action.text == tr("UI_EQUIPPED")
			and remove != null
			and not remove.disabled
			and bool(equipped_save.get("ok", false))
			and target_id in (equipped_save_state.get("owned_outfits", []) as Array)
			and str(equipped_save_state.get("current_outfit", "")) == target_id
			and int(equipped_save_state.get("daily_points", -1)) == starting_points - target_price,
		"the outfit buy button purchases, equips, refreshes the live pig and rebuilt catalog, and saves"
	)
	if remove != null:
		remove.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt_remove: Button = ui.find_child("RemoveOutfitButton", true, false) as Button
	var removed_save: Dictionary = session.save_service.load_game()
	var removed_save_data: Dictionary = removed_save.get("data", {}) as Dictionary
	var removed_save_state: Dictionary = removed_save_data.get("pig_state", {}) as Dictionary
	_expect_true(
		session.pig_state.current_outfit.is_empty()
			and target_id in session.pig_state.owned_outfits
			and pig.outfit.is_empty()
			and rebuilt_remove != null
			and rebuilt_remove.disabled
			and bool(removed_save.get("ok", false))
			and str(removed_save_state.get("current_outfit", "")).is_empty()
			and target_id in (removed_save_state.get("owned_outfits", []) as Array),
		"the real remove action clears the live outfit and rebuilt selector while preserving ownership in the save"
	)
	ui.call("_close_panel")
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")
	main.call("_refresh_pig")


func _test_shop_save_failure_recovery(main: Node, session: Node, ui: Control) -> void:
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var snack: Dictionary = session.catalog.get_item("snacks", "snack_apple")
	var furniture: Dictionary = session.catalog.get_item("furniture", "furn_nightlight_moon")
	var placed_furniture: Dictionary = session.catalog.get_item("furniture", "furn_pillow_cloud")
	var outfit: Dictionary = session.catalog.get_item("outfits", "outfit_round_glasses")
	var snack_id: String = str(snack.get("id", ""))
	var furniture_id: String = str(furniture.get("id", ""))
	var placed_furniture_id: String = str(placed_furniture.get("id", ""))
	var outfit_id: String = str(outfit.get("id", ""))
	var starting_points: int = 1000
	session.set_process(false)
	session.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[9]
	session.pig_state.familiarity_level = 10
	session.pig_state.daily_points = starting_points
	session.pig_state.satiety = 40.0
	session.pig_state.interest = 40.0
	session.pig_state.tutorial_skipped = true
	session.pig_state.owned_snacks.erase(snack_id)
	if placed_furniture_id not in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.append(placed_furniture_id)
	session.pig_state.owned_furniture.erase(furniture_id)
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	if outfit_id not in session.pig_state.owned_outfits:
		session.pig_state.owned_outfits.append(outfit_id)
	session.pig_state.current_outfit = ""
	_expect_eq(session.save_game(), OK, "shop save-failure UI fixture commits its stable progression baseline")
	var baseline: Dictionary = session.pig_state.to_dict().duplicate(true)
	var disk_generation_before: Dictionary = {}
	for path: String in [session.save_service.save_path, session.save_service.backup_1_path, session.save_service.backup_2_path]:
		disk_generation_before[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var blocker_path: String = session.save_service.base_dir + "/shop_save_failure_blocker"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	_expect_true(blocker != null, "shop save-failure UI fixture creates a file that blocks progression temp paths")
	if blocker != null:
		blocker.store_string("block child paths")
		blocker.close()
	var normal_temp_path: String = session.save_service.temp_path
	session.save_service.temp_path = blocker_path + "/savegame.tmp.json"
	ui.call("_close_panel")
	ui.call("_refresh")
	main.call("_refresh_pig")

	var snacks_entry: Button = ui.get("_snacks_button") as Button
	if snacks_entry != null:
		snacks_entry.pressed.emit()
	await get_tree().process_frame
	var snack_action: Button = _catalog_action_for_name(ui, tr(str(snack.get("name_key", ""))))
	var snack_action_found: bool = snack_action != null
	if snack_action != null:
		snack_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt_snack_action: Button = _catalog_action_for_name(ui, tr(str(snack.get("name_key", ""))))
	var points_label: Label = ui.get("_points_label") as Label
	var panel_title: Label = ui.get("_panel_title") as Label
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		snack_action_found
			and session.pig_state.to_dict() == baseline
			and points_label != null
			and points_label.text == tr("UI_POINTS").format({"points":starting_points})
			and panel_title != null
			and panel_title.text == tr("UI_SNACKS")
			and rebuilt_snack_action != null
			and rebuilt_snack_action.text == tr("UI_FEED").format({"price":int(snack.get("price", 0))})
			and toast_label != null
			and toast_label.text == tr("TOAST_SAVE_FAILED"),
		"failed real snack action restores the balance and catalog while preserving the save-failure message"
	)

	var furniture_entry: Button = ui.get("_furniture_button") as Button
	if furniture_entry != null:
		furniture_entry.pressed.emit()
	await get_tree().process_frame
	var furniture_action: Button = _catalog_action_for_name(ui, tr(str(furniture.get("name_key", ""))))
	var furniture_action_found: bool = furniture_action != null
	if furniture_action != null:
		furniture_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt_furniture_action: Button = _catalog_action_for_name(ui, tr(str(furniture.get("name_key", ""))))
	panel_title = ui.get("_panel_title") as Label
	toast_label = ui.get("_toast_label") as Label
	_expect_true(
		furniture_action_found
			and session.pig_state.to_dict() == baseline
			and furniture_id not in session.pig_state.owned_furniture
			and rebuilt_furniture_action != null
			and not rebuilt_furniture_action.disabled
			and rebuilt_furniture_action.text == tr("UI_BUY").format({"price":int(furniture.get("price", 0))})
			and panel_title != null
			and panel_title.text == tr("UI_FURNITURE")
			and toast_label != null
			and toast_label.text == tr("TOAST_SAVE_FAILED"),
		"failed real furniture purchase restores points and ownership in the rebuilt catalog"
	)

	if furniture_entry != null:
		furniture_entry.pressed.emit()
	await get_tree().process_frame
	var placement_action: Button = _catalog_action_for_name(ui, tr(str(placed_furniture.get("name_key", ""))))
	var placement_action_found: bool = placement_action != null
	if placement_action != null:
		placement_action.pressed.emit()
	await get_tree().process_frame
	var empty_slot_two_text: String = tr("FURNITURE_SLOT_LABEL").format({
		"area":tr("AREA_SLEEP"),
		"number":2,
		"current":tr("FURNITURE_SLOT_EMPTY"),
	})
	var slot_two: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == empty_slot_two_text:
			slot_two = button
			break
	var slot_two_found: bool = slot_two != null
	if slot_two != null:
		slot_two.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rebuilt_slot_two: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == empty_slot_two_text:
			rebuilt_slot_two = button
			break
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var furniture_hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary if room != null else {}
	panel_title = ui.get("_panel_title") as Label
	toast_label = ui.get("_toast_label") as Label
	_expect_true(
		placement_action_found
			and slot_two_found
			and session.pig_state.to_dict() == baseline
			and not session.pig_state.placed_furniture.has("sleep_2")
			and not furniture_hitboxes.has("sleep_2")
			and rebuilt_slot_two != null
			and not rebuilt_slot_two.disabled
			and panel_title != null
			and panel_title.text == tr("FURNITURE_CHOOSE_SLOT")
			and toast_label != null
			and toast_label.text == tr("TOAST_SAVE_FAILED"),
		"failed real fixed-slot placement restores the room and rebuilt chooser"
	)

	var outfits_entry: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("UI_OUTFITS"):
			outfits_entry = button
			break
	if outfits_entry != null:
		outfits_entry.pressed.emit()
	await get_tree().process_frame
	var outfit_action: Button = _catalog_action_for_name(ui, tr(str(outfit.get("name_key", ""))))
	var outfit_action_found: bool = outfit_action != null
	if outfit_action != null:
		outfit_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt_outfit_action: Button = _catalog_action_for_name(ui, tr(str(outfit.get("name_key", ""))))
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	panel_title = ui.get("_panel_title") as Label
	toast_label = ui.get("_toast_label") as Label
	_expect_true(
		outfit_action_found
			and session.pig_state.to_dict() == baseline
			and session.pig_state.current_outfit.is_empty()
			and pig != null
			and pig.outfit.is_empty()
			and rebuilt_outfit_action != null
			and not rebuilt_outfit_action.disabled
			and rebuilt_outfit_action.text == tr("UI_EQUIP")
			and panel_title != null
			and panel_title.text == tr("UI_OUTFITS")
			and toast_label != null
			and toast_label.text == tr("TOAST_SAVE_FAILED"),
		"failed real outfit equip restores the live pig and rebuilt selector"
	)

	var disk_generation_after: Dictionary = {}
	for path: String in disk_generation_before:
		disk_generation_after[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	_expect_eq(disk_generation_after, disk_generation_before, "all failed real shop actions preserve the exact committed disk generation")
	session.save_service.temp_path = normal_temp_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	ui.call("_close_panel")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")
	main.call("_refresh_pig")
	await get_tree().process_frame


func _test_hidden_expression_hint_gate(session: Node, ui: Control) -> void:
	var previous_level: int = session.pig_state.familiarity_level
	var previous_unlocked: Array[String] = session.pig_state.unlocked_expressions.duplicate()
	session.pig_state.unlocked_expressions.erase("expr_wronged_robot")
	session.pig_state.familiarity_level = 8
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_true(_count_labels_with_text(ui, tr("ALBUM_HIDDEN_HINT")) > 0, "familiarity level eight keeps advanced expression clues hidden")
	_expect_eq(_count_labels_with_text(ui, tr("EXPR_WRONGED_ROBOT_HINT")), 0, "advanced robot clue is not revealed before familiarity level nine")
	session.pig_state.familiarity_level = 9
	_press_visible_button_with_text(ui, tr("UI_CLOSE"))
	await get_tree().process_frame
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect_eq(_count_labels_with_text(ui, tr("ALBUM_HIDDEN_HINT")), 0, "familiarity level nine removes the generic hidden-clue message")
	_expect_true(_count_labels_with_text(ui, tr("EXPR_WRONGED_ROBOT_HINT")) > 0, "familiarity level nine reveals the advanced robot expression clue")
	session.pig_state.familiarity_level = previous_level
	session.pig_state.unlocked_expressions = previous_unlocked
	ui.call("_close_panel")


func _test_collection_cosmetic_controls(main: Node, session: Node, ui: Control) -> void:
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	session.pig_state.familiarity_level = 10
	session.pig_state.unlocked_expressions.clear()
	for expression: Dictionary in session.catalog.expressions:
		session.pig_state.unlocked_expressions.append(str(expression.id))
	session.pig_state.current_room_palette = "rose"
	session.pig_state.current_photo_frame = "plain"
	ui.call("_close_panel")
	ui.call("_refresh")
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	room.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before_image: Image = get_window().get_texture().get_image()
	var room_rect: Rect2 = room.get_global_rect()
	var sample_position: Vector2 = room_rect.position + room_rect.size * Vector2(0.5, 0.25)
	var texture_scale := Vector2(
		float(before_image.get_width()) / maxf(get_viewport().get_visible_rect().size.x, 1.0),
		float(before_image.get_height()) / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	)
	var sample_pixel := Vector2i(sample_position * texture_scale)
	var before_wall: Color = before_image.get_pixelv(sample_pixel)
	var furniture_button: Button = ui.get("_furniture_button") as Button
	if furniture_button != null:
		furniture_button.pressed.emit()
	await get_tree().process_frame
	var palette_buttons: Dictionary = {}
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		for palette_id: String in GameSession.ROOM_PALETTES:
			if button.text == tr("ROOM_PALETTE_%s" % palette_id.to_upper()):
				palette_buttons[palette_id] = button
	var rose_button: Button = palette_buttons.get("rose") as Button
	var mint_button: Button = palette_buttons.get("mint") as Button
	var night_button: Button = palette_buttons.get("night") as Button
	_expect_true(
		furniture_button != null
			and _count_labels_with_text(ui, tr("ROOM_PALETTE_TITLE")) == 1
			and rose_button != null
			and rose_button.disabled
			and mint_button != null
			and not mint_button.disabled
			and night_button != null
			and not night_button.disabled,
		"the real furniture catalog exposes the current and unlocked room palette choices"
	)
	if mint_button != null:
		mint_button.pressed.emit()
	await get_tree().process_frame
	var selected_mint: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("ROOM_PALETTE_MINT"):
			selected_mint = button
			break
	var mint_selected_in_rebuilt_catalog: bool = selected_mint != null and selected_mint.disabled
	var palette_save: Dictionary = session.save_service.load_game()
	var palette_save_data: Dictionary = palette_save.get("data", {}) as Dictionary
	var palette_save_state: Dictionary = palette_save_data.get("pig_state", {}) as Dictionary
	ui.call("_close_panel")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after_image: Image = get_window().get_texture().get_image()
	var after_wall: Color = after_image.get_pixelv(sample_pixel)
	_expect_true(
		session.pig_state.current_room_palette == "mint"
			and mint_selected_in_rebuilt_catalog
			and bool(palette_save.get("ok", false))
			and str(palette_save_state.get("current_room_palette", "")) == "mint"
			and not before_wall.is_equal_approx(after_wall),
		"the room palette button updates the session, live room, rebuilt selector, and save"
	)
	var album_button: Button = ui.get("_album_button") as Button
	if album_button != null:
		album_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var frame_buttons: Dictionary = {}
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		for frame_id: String in GameSession.PHOTO_FRAMES:
			if button.text == tr("PHOTO_FRAME_%s" % frame_id.to_upper()):
				frame_buttons[frame_id] = button
	var plain_button: Button = frame_buttons.get("plain") as Button
	var berry_button: Button = frame_buttons.get("berry") as Button
	var star_button: Button = frame_buttons.get("star") as Button
	_expect_true(
		album_button != null
			and _count_labels_with_text(ui, tr("PHOTO_FRAME_TITLE")) == 1
			and plain_button != null
			and plain_button.disabled
			and berry_button != null
			and not berry_button.disabled
			and star_button != null
			and not star_button.disabled,
		"the real album exposes the current and unlocked photo frame choices"
	)
	if berry_button != null:
		berry_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var selected_berry: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == tr("PHOTO_FRAME_BERRY"):
			selected_berry = button
			break
	var frame_save: Dictionary = session.save_service.load_game()
	var frame_save_data: Dictionary = frame_save.get("data", {}) as Dictionary
	var frame_save_state: Dictionary = frame_save_data.get("pig_state", {}) as Dictionary
	var sample := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	sample.fill(Color("#d9879b"))
	var framed: PanelContainer = ui.call("_framed_photo", sample, Vector2(96, 64)) as PanelContainer
	var frame_style: StyleBoxFlat = framed.get_theme_stylebox("panel") as StyleBoxFlat if framed != null else null
	var berry_colors: Array = MainUI.PHOTO_FRAME_COLORS["berry"] as Array
	_expect_true(
		session.pig_state.current_photo_frame == "berry"
			and selected_berry != null
			and selected_berry.disabled
			and bool(frame_save.get("ok", false))
			and str(frame_save_state.get("current_photo_frame", "")) == "berry"
			and frame_style != null
			and frame_style.border_width_left == 8
			and frame_style.border_color.is_equal_approx(berry_colors[1] as Color),
		"the photo frame button updates the session, rendered frame, rebuilt selector, and save"
	)
	if framed != null:
		framed.free()
	ui.call("_close_panel")
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")
	room.queue_redraw()


func _test_photo_frames(session: Node, ui: Control) -> void:
	var image := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("#d9879b"))
	var border_colors: Dictionary = {}
	for frame_id: String in GameSession.PHOTO_FRAMES:
		session.pig_state.current_photo_frame = frame_id
		var framed: Control = ui.call("_framed_photo", image, Vector2(96, 64)) as Control
		_expect_true(framed is PanelContainer, "album photo frame builds a panel: %s" % frame_id)
		var style: StyleBoxFlat = (framed as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		_expect_true(style != null and style.border_width_left > 0, "album photo frame has a visible placeholder border: %s" % frame_id)
		if style != null:
			border_colors[style.border_color.to_abgr32()] = frame_id
		framed.free()
	_expect_true(border_colors.size() == GameSession.PHOTO_FRAMES.size(), "all album frame placeholders render distinct styling")
	session.pig_state.current_photo_frame = "plain"
	session.pig_state.unlocked_expressions.clear()
	for expression: Dictionary in session.catalog.expressions:
		session.pig_state.unlocked_expressions.append(str(expression.id))
	var selector: Control = ui.call("_photo_frame_selector") as Control
	var enabled_buttons: int = 0
	for node: Node in selector.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and not button.disabled:
			enabled_buttons += 1
	_expect_true(enabled_buttons == 2, "full expression collection exposes both alternate album frames")
	selector.free()
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	_expect_true(ui.find_children("*", "ExpressionPortrait", true, false).size() == 48, "album page attaches all 48 expression cards to the visible tree")
	ui.call("_close_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var panel_content: Node = ui.get("_panel_content") as Node
	_expect_true(panel_content != null and panel_content.get_child_count() == 0, "closing the album releases its visible content tree")


func _test_event_camera_shake(session: Node) -> void:
	var previous_camera_shake: bool = session.camera_shake_enabled
	var previous_reduce_motion: bool = session.reduce_motion
	var event: Dictionary = session.catalog.get_item("events", "event_robot_knight").duplicate(true)
	event["steps"] = [{"animation":"scratch", "duration":10.0, "camera_shake":true}]
	var viewer: Control = EventViewerScript.new()
	viewer.call("play", event, false)
	get_tree().root.add_child(viewer)
	await get_tree().process_frame
	var stages: Array[Node] = viewer.find_children("*", "EventStage", true, false)
	var stage: EventStage = stages[0] as EventStage if not stages.is_empty() else null
	session.camera_shake_enabled = true
	session.reduce_motion = false
	viewer.call("_process", 5.0)
	_expect_true(stage != null and stage.position != Vector2.ZERO, "marked event step visibly shifts the real EventStage when camera shake is enabled")
	session.camera_shake_enabled = false
	viewer.call("_process", 0.1)
	_expect_true(stage != null and stage.position == Vector2.ZERO, "disabling camera shake recenters the real EventStage immediately")
	session.camera_shake_enabled = true
	session.reduce_motion = true
	viewer.call("_process", 0.1)
	_expect_true(stage != null and stage.position == Vector2.ZERO, "reduced motion also keeps the real EventStage centered")
	session.camera_shake_enabled = previous_camera_shake
	session.reduce_motion = previous_reduce_motion
	viewer.queue_free()
	await get_tree().process_frame


func _test_event_stage_catalog(session: Node) -> void:
	var output_dir := "res://build/validation/ui/events"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var hashes: Dictionary = {}
	for event: Dictionary in session.catalog.events:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(680, 265)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_tree().root.add_child(viewport)
		var stage := EventStage.new()
		stage.size = Vector2(viewport.size)
		var steps: Array = event.get("steps", []) as Array
		var climax: Dictionary = steps[-1] as Dictionary
		stage.set_step(event, climax, 0.72)
		viewport.add_child(stage)
		stage.set_process(false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var event_id: String = str(event.id)
		_expect_true(image != null and not image.is_empty(), "event climax renders: %s" % event_id)
		var image_hash: int = hash(image.get_data()) if image != null else 0
		_expect_true(not hashes.has(image_hash), "event climax composition is visually distinct: %s" % event_id)
		hashes[image_hash] = event_id
		if image != null and not image.is_empty():
			image.save_png("%s/%s.png" % [output_dir, event_id])
		viewport.queue_free()
		await get_tree().process_frame
	_expect_true(hashes.size() == session.catalog.events.size(), "all 24 event climax compositions have rendered evidence")


func _capture_outfit(outfit: Dictionary, id: String, output_dir: String) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 230)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#f7eee8")
	background.position = Vector2.ZERO
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var pig := PigVisual.new()
	pig.position = Vector2.ZERO
	pig.size = Vector2(viewport.size)
	pig.set_outfit(outfit)
	viewport.add_child(pig)
	pig.set_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/%s.png" % [output_dir, id])
	var image_hash: int = hash(image.get_data()) if image != null else 0
	viewport.queue_free()
	await get_tree().process_frame
	return {"image": image, "hash": image_hash}


func _test_behavior_visuals(session: Node) -> void:
	var output_dir := "res://build/validation/ui/behaviors"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var hashes: Dictionary = {}
	var previous_reduce_motion: bool = session.reduce_motion
	session.reduce_motion = true
	for behavior: Dictionary in session.catalog.behaviors:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(280, 230)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_tree().root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color("#f7eee8")
		background.size = Vector2(viewport.size)
		viewport.add_child(background)
		var pig := PigVisual.new()
		pig.size = Vector2(viewport.size)
		pig.set_behavior(behavior)
		viewport.add_child(pig)
		pig.set_process(false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var id: String = str(behavior.id)
		var image_hash: int = hash(image.get_data()) if image != null else 0
		_expect_true(image != null and not image.is_empty(), "behavior renders to an image: %s" % id)
		_expect_true(not hashes.has(image_hash), "behavior visual is distinct: %s" % id)
		hashes[image_hash] = id
		if image != null and not image.is_empty():
			image.save_png("%s/%s.png" % [output_dir, id])
		viewport.queue_free()
		await get_tree().process_frame
	session.reduce_motion = previous_reduce_motion
	_expect_true(hashes.size() == session.catalog.behaviors.size(), "all 36 behavior visuals have distinct rendered evidence")


func _test_furniture_visuals(session: Node) -> void:
	var output_dir := "res://build/validation/ui/furniture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var original_placed: Dictionary = session.pig_state.placed_furniture.duplicate(true)
	var original_level: int = session.pig_state.familiarity_level
	var hashes: Dictionary = {}
	session.pig_state.familiarity_level = 10
	for furniture: Dictionary in session.catalog.furniture:
		var id: String = str(furniture.id)
		var slots: Array[String] = session.compatible_furniture_slots(id)
		_expect_true(not slots.is_empty(), "furniture has a renderable room slot: %s" % id)
		if slots.is_empty():
			continue
		var slot_id: String = slots[0]
		session.pig_state.placed_furniture = {slot_id: id}
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_tree().root.add_child(viewport)
		var room := RoomVisual.new()
		room.size = Vector2(viewport.size)
		viewport.add_child(room)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var room_image: Image = viewport.get_texture().get_image()
		var area_index: int = ["sleep", "snack", "activity", "window"].find(str(furniture.area))
		var slot_number: int = clampi(int(slot_id.get_slice("_", 1)) - 1, 0, 3)
		var offsets: Array[Vector2i] = [Vector2i(70,72),Vector2i(145,90),Vector2i(220,68),Vector2i(270,96)]
		var center := Vector2i(area_index * 320, floori(720.0 * 0.72)) + offsets[slot_number]
		var image: Image = room_image.get_region(Rect2i(center - Vector2i(60,60), Vector2i(120,120))) if room_image != null else null
		var image_hash: int = hash(image.get_data()) if image != null else 0
		_expect_true(image != null and not image.is_empty(), "furniture renders to an image: %s" % id)
		_expect_true(not hashes.has(image_hash), "furniture silhouette is distinct: %s" % id)
		hashes[image_hash] = id
		if image != null and not image.is_empty():
			image.save_png("%s/%s.png" % [output_dir, id])
		viewport.queue_free()
		await get_tree().process_frame
	session.pig_state.placed_furniture = original_placed
	session.pig_state.familiarity_level = original_level
	_expect_true(hashes.size() == session.catalog.furniture.size(), "all 32 furniture silhouettes have distinct rendered evidence")


func _test_furniture_purchase_controls(main: Node, session: Node, ui: Control) -> void:
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var was_processing: bool = session.is_processing()
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var target: Dictionary = session.catalog.get_item("furniture", "furn_pillow_cloud")
	var target_id: String = str(target.get("id", ""))
	var target_price: int = int(target.get("price", 0))
	var starting_points: int = target_price + 500
	session.set_process(false)
	session.pig_state.familiarity_xp = 0
	session.pig_state.familiarity_level = 1
	session.pig_state.daily_points = target_price - 1
	while target_id in session.pig_state.owned_furniture:
		session.pig_state.owned_furniture.erase(target_id)
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	session.pig_state.tutorial_step = 7
	session.pig_state.tutorial_skipped = true
	ui.call("_close_panel")
	ui.call("_refresh")
	if room != null:
		room.queue_redraw()
	var furniture_entry: Button = ui.get("_furniture_button") as Button
	if furniture_entry != null:
		furniture_entry.pressed.emit()
	await get_tree().process_frame
	var buy_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var buy_state_visible: bool = (
		buy_action != null
		and not buy_action.disabled
		and buy_action.text == tr("UI_BUY").format({"price":target_price})
	)
	if buy_action != null:
		buy_action.pressed.emit()
	await get_tree().process_frame
	var panel_title: Label = ui.get("_panel_title") as Label
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		furniture_entry != null
			and buy_state_visible
			and target_id not in session.pig_state.owned_furniture
			and session.pig_state.daily_points == target_price - 1
			and panel_title != null
			and panel_title.text == tr("UI_FURNITURE")
			and toast_label != null
			and toast_label.text == tr("TOAST_NOT_ENOUGH_POINTS"),
		"the real furniture buy action shows an integer price and rejects an unaffordable purchase without mutation"
	)
	session.pig_state.daily_points = starting_points
	if buy_action != null:
		buy_action.pressed.emit()
	await get_tree().process_frame
	var empty_slot_two_text: String = tr("FURNITURE_SLOT_LABEL").format({
		"area":tr("AREA_SLEEP"),
		"number":2,
		"current":tr("FURNITURE_SLOT_EMPTY"),
	})
	var empty_slot_three_text: String = tr("FURNITURE_SLOT_LABEL").format({
		"area":tr("AREA_SLEEP"),
		"number":3,
		"current":tr("FURNITURE_SLOT_EMPTY"),
	})
	var slot_two: Button
	var slot_three: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == empty_slot_two_text:
			slot_two = button
		elif button.text == empty_slot_three_text:
			slot_three = button
	var purchase_save: Dictionary = session.save_service.load_game()
	var purchase_save_data: Dictionary = purchase_save.get("data", {}) as Dictionary
	var purchase_save_state: Dictionary = purchase_save_data.get("pig_state", {}) as Dictionary
	var purchase_save_placements: Dictionary = purchase_save_state.get("placed_furniture", {}) as Dictionary
	_expect_true(
		session.pig_state.owned_furniture.count(target_id) == 1
			and session.pig_state.daily_points == starting_points - target_price
			and target_id not in session.pig_state.placed_furniture.values()
			and panel_title != null
			and panel_title.text == tr("FURNITURE_CHOOSE_SLOT")
			and slot_two != null
			and not slot_two.disabled
			and slot_three != null
			and not slot_three.disabled
			and toast_label != null
			and toast_label.text == tr("TOAST_PURCHASED").format({"item":tr(str(target.get("name_key", "")))})
			and bool(purchase_save.get("ok", false))
			and int(purchase_save_state.get("daily_points", -1)) == starting_points - target_price
			and target_id in (purchase_save_state.get("owned_furniture", []) as Array)
			and target_id not in purchase_save_placements.values(),
		"the affordable real purchase charges once, persists ownership, and opens every compatible empty fixed slot"
	)
	if slot_two != null:
		slot_two.pressed.emit()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var placed_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var placed_hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary if room != null else {}
	var placed_hitbox: Dictionary = placed_hitboxes.get("sleep_2", {}) as Dictionary
	var placed_save: Dictionary = session.save_service.load_game()
	var placed_save_data: Dictionary = placed_save.get("data", {}) as Dictionary
	var placed_save_state: Dictionary = placed_save_data.get("pig_state", {}) as Dictionary
	var placed_save_placements: Dictionary = placed_save_state.get("placed_furniture", {}) as Dictionary
	_expect_true(
		str(session.pig_state.placed_furniture.get("sleep_2", "")) == target_id
			and session.pig_state.daily_points == starting_points - target_price
			and placed_action != null
			and not placed_action.disabled
			and placed_action.text == tr("UI_PLACE")
			and str(placed_hitbox.get("furniture_id", "")) == target_id
			and toast_label != null
			and toast_label.text == tr("TOAST_FURNITURE_PLACED").format({"item":tr(str(target.get("name_key", "")))})
			and bool(placed_save.get("ok", false))
			and int(placed_save_state.get("daily_points", -1)) == starting_points - target_price
			and str(placed_save_placements.get("sleep_2", "")) == target_id,
		"the purchased furniture places through the real chooser and updates the live room, rebuilt catalog, and save"
	)
	if placed_action != null:
		placed_action.pressed.emit()
	await get_tree().process_frame
	var occupied_slot_text: String = tr("FURNITURE_SLOT_LABEL").format({
		"area":tr("AREA_SLEEP"),
		"number":2,
		"current":tr(str(target.get("name_key", ""))),
	})
	var occupied_slot: Button
	var move_slot: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == occupied_slot_text:
			occupied_slot = button
		elif button.text == empty_slot_three_text:
			move_slot = button
	var move_chooser_valid: bool = (
		occupied_slot != null
		and occupied_slot.disabled
		and move_slot != null
		and not move_slot.disabled
	)
	if move_slot != null:
		move_slot.pressed.emit()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var moved_action: Button = _catalog_action_for_name(ui, tr(str(target.get("name_key", ""))))
	var moved_hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary if room != null else {}
	var moved_hitbox: Dictionary = moved_hitboxes.get("sleep_3", {}) as Dictionary
	var moved_save: Dictionary = session.save_service.load_game()
	var moved_save_data: Dictionary = moved_save.get("data", {}) as Dictionary
	var moved_save_state: Dictionary = moved_save_data.get("pig_state", {}) as Dictionary
	var moved_save_placements: Dictionary = moved_save_state.get("placed_furniture", {}) as Dictionary
	_expect_true(
		move_chooser_valid
			and session.pig_state.daily_points == starting_points - target_price
			and session.pig_state.placed_furniture.values().count(target_id) == 1
			and not session.pig_state.placed_furniture.has("sleep_2")
			and str(session.pig_state.placed_furniture.get("sleep_3", "")) == target_id
			and not moved_hitboxes.has("sleep_2")
			and str(moved_hitbox.get("furniture_id", "")) == target_id
			and moved_action != null
			and moved_action.text == tr("UI_PLACE")
			and bool(moved_save.get("ok", false))
			and int(moved_save_state.get("daily_points", -1)) == starting_points - target_price
			and moved_save_placements.values().count(target_id) == 1
			and not moved_save_placements.has("sleep_2")
			and str(moved_save_placements.get("sleep_3", "")) == target_id,
		"reopening an owned furniture card moves its single placement without charging again and persists the new slot"
	)
	ui.call("_close_panel")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.pig_state.load_dict(previous_pig_state)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")
	if room != null:
		room.queue_redraw()
	await get_tree().process_frame


func _test_furniture_controls(main: Node, session: Node, ui: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var was_processing: bool = session.is_processing()
	session.set_process(false)
	var previous_pig_state: Dictionary = session.pig_state.to_dict().duplicate(true)
	var simulation: Simulation = session.get("simulation") as Simulation
	var previous_simulation: Dictionary = simulation.to_dict().duplicate(true) if simulation != null else {}
	var behavior_director: BehaviorDirector = session.get("behavior_director") as BehaviorDirector
	var previous_behavior_director: Dictionary = behavior_director.to_dict().duplicate(true) if behavior_director != null else {}
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	var bed: Dictionary = session.catalog.get_item("furniture", "furn_bed_basic")
	var bookshelf: Dictionary = session.catalog.get_item("furniture", "furn_bookshelf_low")
	session.pig_state.familiarity_level = 10
	for furniture_id: String in ["furn_bed_basic", "furn_bookshelf_low", "furn_robot_dock", "furn_mini_oven"]:
		if furniture_id not in session.pig_state.owned_furniture:
			session.pig_state.owned_furniture.append(furniture_id)
	session.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	if simulation != null:
		simulation.load_dict({}, session.catalog)
	if behavior_director != null:
		behavior_director.cooldown_until.erase(str(bed.get("behavior_id", "")))
	room.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hitboxes: Dictionary = room.get("_furniture_hitboxes") as Dictionary
	var bed_hitbox: Dictionary = hitboxes.get("sleep_1", {}) as Dictionary
	var furniture_touch := InputEventScreenTouch.new()
	furniture_touch.index = 6
	furniture_touch.pressed = true
	furniture_touch.position = (bed_hitbox.get("rect", Rect2()) as Rect2).get_center()
	room.call("_gui_input", furniture_touch)
	await get_tree().process_frame
	var panel_title: Label = ui.get("_panel_title") as Label
	var invite_button: Button
	var replace_button: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == tr("FURNITURE_INVITE"):
			invite_button = button
		elif button.text == tr("FURNITURE_REPLACE"):
			replace_button = button
	_expect_true(
		str(bed_hitbox.get("furniture_id", "")) == "furn_bed_basic"
			and panel_title != null
			and panel_title.text == tr(str(bed.get("name_key", "")))
			and _count_labels_with_text(ui, tr(str(bed.get("description_key", "")))) == 1
			and _count_labels_with_text(ui, tr("FURNITURE_CURRENT_SLOT").format({"area":tr("AREA_SLEEP"), "number":1})) == 1
			and invite_button != null
			and not invite_button.disabled
			and replace_button != null,
		"touching the rendered placed furniture opens its description, slot, invite, and replace actions"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/furniture-detail.png")
	if invite_button != null:
		invite_button.pressed.emit()
	await get_tree().process_frame
	var overlay: ColorRect = ui.get("_overlay") as ColorRect
	var toast_label: Label = ui.get("_toast_label") as Label
	_expect_true(
		simulation != null
			and str(simulation.to_dict().get("current_behavior_id", "")) == str(bed.get("behavior_id", ""))
			and overlay != null
			and not overlay.visible
			and toast_label != null
			and toast_label.text == tr("TOAST_FURNITURE_INVITED").format({"item":tr(str(bed.get("name_key", "")))}),
		"the real invite button starts the furniture behavior and returns to the room with feedback"
	)
	room.call("_gui_input", furniture_touch)
	await get_tree().process_frame
	var active_invite_disabled: bool = false
	replace_button = null
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		if button.text == tr("FURNITURE_INVITE"):
			active_invite_disabled = button.disabled
		elif button.text == tr("FURNITURE_REPLACE"):
			replace_button = button
	if replace_button != null:
		replace_button.pressed.emit()
	await get_tree().process_frame
	var bookshelf_place: Button
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text != tr(str(bookshelf.get("name_key", ""))):
			continue
		var card: Node = label.get_parent().get_parent()
		for candidate: Node in card.find_children("*", "Button", true, false):
			bookshelf_place = candidate as Button
			break
		break
	_expect_true(
		panel_title != null
			and panel_title.text == tr("UI_FURNITURE")
			and active_invite_disabled
			and bookshelf_place != null
			and bookshelf_place.text == tr("UI_PLACE"),
		"the active invitation disables repeat starts before replacement opens the real furniture catalog"
	)
	if bookshelf_place != null:
		bookshelf_place.pressed.emit()
	await get_tree().process_frame
	var target_slot: Button
	var target_slot_text: String = tr("FURNITURE_SLOT_LABEL").format({
		"area":tr("AREA_SLEEP"),
		"number":1,
		"current":tr(str(bed.get("name_key", ""))),
	})
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == target_slot_text:
			target_slot = button
			break
	_expect_true(target_slot != null and not target_slot.disabled, "the slot chooser exposes the compatible occupied bed slot")
	if target_slot != null:
		target_slot.pressed.emit()
	await get_tree().process_frame
	toast_label = ui.get("_toast_label") as Label
	_expect_true(
		str(session.pig_state.placed_furniture.get("sleep_1", "")) == "furn_bookshelf_low"
			and toast_label != null
			and toast_label.text == tr("TOAST_FURNITURE_PLACED").format({"item":tr(str(bookshelf.get("name_key", "")))}),
		"choosing the real slot replaces the furniture and reports the placed item"
	)
	await RenderingServer.frame_post_draw
	get_window().get_texture().get_image().save_png("res://build/validation/ui/furniture-replaced.png")
	ui.call("_close_panel")
	session.pig_state.placed_furniture["sleep_2"] = "furn_robot_dock"
	ui.open_furniture_detail("furn_robot_dock", "sleep_2")
	await get_tree().process_frame
	var reaction: Button = ui.find_child("FurnitureReactionButton", true, false) as Button
	_expect_true(reaction != null and reaction.text == tr("FURNITURE_REACT"), "placed decoration exposes its localized short-reaction action")
	if reaction != null:
		reaction.pressed.emit()
	await get_tree().process_frame
	_expect_eq(
		str((ui.get("_toast_label") as Label).text),
		tr(str(session.catalog.get_item("furniture", "furn_robot_dock").get("reaction_key", ""))).format({
			"name":session.pig_display_name(),
			"item":tr(str(session.catalog.get_item("furniture", "furn_robot_dock").get("name_key", ""))),
		}),
		"the real decoration reaction button renders its localized short response"
	)
	session.pig_state.placed_furniture["snack_1"] = "furn_mini_oven"
	ui.open_furniture_detail("furn_mini_oven", "snack_1")
	await get_tree().process_frame
	var atmosphere_copy_found: bool = false
	for node: Node in ui.find_children("*", "Label", true, false):
		var label := node as Label
		atmosphere_copy_found = atmosphere_copy_found or (label != null and label.text == tr("FURNITURE_ATMOSPHERE_ONLY"))
	_expect_true(atmosphere_copy_found, "passive atmosphere furniture explains its room effect instead of calling itself decoration-only")
	_expect_true(ui.find_child("FurnitureReactionButton", true, false) == null, "atmosphere furniture without a reaction does not expose a fake reaction action")
	ui.call("_close_panel")
	var toast_tween: Tween = ui.get("_toast_tween") as Tween
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	var toast_panel: PanelContainer = ui.get("_toast_panel") as PanelContainer
	if toast_panel != null:
		toast_panel.modulate.a = 0.0
	session.pig_state.load_dict(previous_pig_state)
	if simulation != null:
		simulation.load_dict(previous_simulation, session.catalog)
	if behavior_director != null:
		behavior_director.load_dict(previous_behavior_director)
	session.set_process(was_processing)
	session.save_game()
	ui.call("_refresh")


func _test_atmosphere_visuals(session: Node) -> void:
	var output_dir := "res://build/validation/ui/atmosphere"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var original_placed: Dictionary = session.pig_state.placed_furniture.duplicate(true)
	var original_level: int = session.pig_state.familiarity_level
	var atmosphere_items: Array[Dictionary] = []
	var effect_ids: Dictionary = {}
	session.pig_state.familiarity_level = 10
	for furniture: Dictionary in session.catalog.furniture:
		if str(furniture.get("category", "")) == "atmosphere":
			atmosphere_items.append(furniture)
	_expect_true(atmosphere_items.size() == 5, "all five atmosphere furniture items participate in room ambience")
	for furniture: Dictionary in atmosphere_items:
		var id: String = str(furniture.get("id", ""))
		var effect: String = str(furniture.get("room_effect", ""))
		var slots: Array[String] = session.compatible_furniture_slots(id)
		_expect_true(not effect.is_empty() and not effect_ids.has(effect), "atmosphere furniture has a distinct data-driven effect: %s" % id)
		effect_ids[effect] = id
		if slots.is_empty():
			continue
		session.pig_state.placed_furniture = {slots[0]: id}
		var with_effect: Image = await _render_room_image()
		furniture.erase("room_effect")
		var without_effect: Image = await _render_room_image()
		furniture["room_effect"] = effect
		var effect_hash: int = hash(with_effect.get_data()) if with_effect != null else 0
		var baseline_hash: int = hash(without_effect.get_data()) if without_effect != null else 0
		_expect_true(
			with_effect != null and without_effect != null and effect_hash != baseline_hash,
			"atmosphere furniture changes the rendered room beyond its own silhouette: %s" % id
		)
		if with_effect != null and not with_effect.is_empty():
			with_effect.save_png("%s/%s.png" % [output_dir, id])
	session.pig_state.placed_furniture = original_placed
	session.pig_state.familiarity_level = original_level
	_expect_true(effect_ids.size() == atmosphere_items.size(), "all atmosphere effects keep distinct permanent routes")


func _render_room_image() -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(viewport)
	var room := RoomVisual.new()
	room.size = Vector2(viewport.size)
	viewport.add_child(room)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image


func _test_expression_portraits(session: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 660)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#f7eee8")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(20, 18)
	grid.size = Vector2(920, 624)
	viewport.add_child(grid)
	var signatures: Dictionary = {}
	for expression_index: int in session.catalog.expressions.size():
		var expression: Dictionary = session.catalog.expressions[expression_index]
		var portrait := ExpressionPortrait.new()
		portrait.custom_minimum_size = Vector2(112, 100)
		portrait.configure(str(expression.category), expression_index % 8, true, str(expression.id))
		grid.add_child(portrait)
		signatures[portrait.visual_signature()] = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect_true(image != null and not image.is_empty(), "all expression portraits render into a visual contact sheet")
	_expect_true(grid.get_child_count() == 48, "expression contact sheet contains all 48 portraits")
	_expect_true(signatures.size() == 48, "all expression portraits have distinct category/variant signatures")
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui/expressions"))
		image.save_png("res://build/validation/ui/expressions/all-expressions.png")
	viewport.queue_free()
	await get_tree().process_frame


func _test_desktop_expression_preference(main: Node, session: Node, ui: Control) -> void:
	var previous_desktop: bool = session.desktop_mode
	var previous_reduce_motion: bool = session.reduce_motion
	var previous_expressions: Array[String] = session.pig_state.unlocked_expressions.duplicate()
	var previous_expression_dates: Dictionary = session.pig_state.expression_unlock_dates.duplicate(true)
	var previous_favorite: String = session.pig_state.favorite_desktop_expression
	session.desktop_mode = true
	session.reduce_motion = true
	var hashes: Array[int] = []
	var signatures: Array[String] = []
	for fixture: Array in [
		["expr_happy_soft", 0],
		["expr_happy_snack", 1],
	]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(280, 230)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_tree().root.add_child(viewport)
		var pig := PigVisual.new()
		pig.size = Vector2(viewport.size)
		pig.set_behavior({"animation":"idle"})
		pig.set_favorite_expression(str(fixture[0]), "happy", int(fixture[1]))
		viewport.add_child(pig)
		pig.set_process(false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		hashes.append(hash(image.get_data()) if image != null else 0)
		signatures.append(pig.active_favorite_expression_signature())
		viewport.queue_free()
		await get_tree().process_frame
	_expect_true(signatures[0] != signatures[1], "desktop idle retains the selected permanent expression ID and variant")
	_expect_true(hashes[0] != hashes[1], "two favorites in the same expression category render differently on the desktop pig")
	session.desktop_mode = false
	var inactive := PigVisual.new()
	inactive.set_behavior({"animation":"idle"})
	inactive.set_favorite_expression("expr_happy_snack", "happy", 1)
	_expect_true(inactive.active_favorite_expression_signature().is_empty(), "desktop expression preference does not leak into the normal room")
	inactive.free()
	var target_id := "expr_happy_snack"
	var target_expression: Dictionary = session.catalog.get_item("expressions", target_id)
	var target_event: Dictionary = session.catalog.get_item("events", str(target_expression.get("associated_event", "")))
	var first_seen_unix: int = int(Time.get_unix_time_from_datetime_string("2026-08-10T12:00:00"))
	if target_id not in session.pig_state.unlocked_expressions:
		session.pig_state.unlocked_expressions.append(target_id)
	session.pig_state.expression_unlock_dates[target_id] = first_seen_unix
	session.pig_state.favorite_desktop_expression = ""
	session.desktop_mode = true
	var scene_pig: PigVisual = main.get_node("Pig") as PigVisual
	main.call("_refresh_pig")
	_press_visible_button_with_text(ui, tr("UI_ALBUM"))
	await get_tree().process_frame
	await get_tree().process_frame
	var panel_content: VBoxContainer = ui.get("_panel_content") as VBoxContainer
	var target_card: Control
	if panel_content != null:
		for node: Node in panel_content.find_children("*", "PanelContainer", true, false):
			if _count_labels_with_text(node, tr(str(target_expression.get("name_key", "")))) == 1:
				target_card = node as Control
				break
	var favorite_button: Button
	if target_card != null:
		for node: Node in target_card.find_children("*", "Button", true, false):
			var button := node as Button
			if button != null and button.text == "☆ " + tr("ALBUM_DESKTOP_FAVORITE"):
				favorite_button = button
				break
	var expected_date: String = tr("ALBUM_EXPRESSION_DATE").format({"date": GameClock.local_date_string(first_seen_unix)})
	var expected_event: String = tr("ALBUM_ASSOCIATED_EVENT").format({"event": tr(str(target_event.get("title_key", "")))})
	_expect_true(
		target_card != null
			and _count_labels_with_text(target_card, tr(str(target_expression.get("line_key", "")))) == 1
			and _count_labels_with_text(target_card, expected_date) == 1
			and _count_labels_with_text(target_card, expected_event) == 1,
		"an unlocked expression card shows its phrase, first date, and associated memory"
	)
	_expect_true(favorite_button != null and not favorite_button.disabled, "an unlocked expression card exposes an enabled desktop favorite command")
	if favorite_button != null:
		favorite_button.pressed.emit()
	await get_tree().process_frame
	scene_pig.set_behavior({"animation":"idle"})
	_expect_true(
		session.pig_state.favorite_desktop_expression == target_id
			and scene_pig.active_favorite_expression_signature() == "expr_happy_snack:happy:1",
		"the album command updates the session and the live desktop pig with the selected permanent expression"
	)
	var persisted: Dictionary = session.save_service.load_game()
	_expect_true(
		bool(persisted.get("ok", false))
			and str((persisted.get("data", {}) as Dictionary).get("pig_state", {}).get("favorite_desktop_expression", "")) == target_id,
		"the album desktop favorite command persists through the production session facade"
	)
	ui.call("_close_panel")
	session.pig_state.unlocked_expressions = previous_expressions
	session.pig_state.expression_unlock_dates = previous_expression_dates
	session.pig_state.favorite_desktop_expression = previous_favorite
	session.desktop_mode = previous_desktop
	session.reduce_motion = previous_reduce_motion
	main.call("_refresh_pig")
	session.save_game()


func _test_final_asset_runtime_switch(session: Node, ui: Control) -> void:
	var manifest_path := "user://final-asset-runtime-smoke.json"
	var original_placed: Dictionary = session.pig_state.placed_furniture.duplicate(true)
	var atmosphere_token: String = "room_effect:sleep_glow"
	var atmosphere_tokens: Array[String] = [atmosphere_token]
	var atmosphere_manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	atmosphere_manifest.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[{"path":"res://game/assets/ui/app_icon.svg", "covers":[atmosphere_token]}],
	}))
	atmosphere_manifest.close()
	_expect_eq(
		session.final_assets.load_manifest(manifest_path, atmosphere_tokens),
		[],
		"runtime visual fixture enables the dedicated room-atmosphere resolver"
	)
	session.pig_state.placed_furniture = {"sleep_1":"furn_nightlight_moon"}
	var final_atmosphere: Image = await _render_room_image()
	_expect_eq(session.final_assets.load_manifest(), [], "room-atmosphere fixture can return to the procedural fallback")
	var fallback_atmosphere: Image = await _render_room_image()
	_expect_true(
		final_atmosphere != null
			and fallback_atmosphere != null
			and hash(final_atmosphere.get_data()) != hash(fallback_atmosphere.get_data()),
		"dedicated room-atmosphere texture replaces the procedural effect through its permanent token"
	)
	var tokens: Array[String] = [
		"room:rose", "furniture:furn_bed_basic", "behavior:idle", "outfit:outfit_berry_beret",
		"expression:expr_happy_soft", "event:event_move_in", "snack:snack_apple", "ui:photo_frame_plain",
		atmosphere_token,
	]
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({
		"schema_version":1,
		"ready":true,
		"provided_by_user":true,
		"entries":[{"path":"res://game/assets/ui/app_icon.svg", "covers":tokens}],
	}))
	manifest.close()
	_expect_eq(session.final_assets.load_manifest(manifest_path, tokens), [], "runtime visual fixture enables the final-asset resolver")
	session.pig_state.placed_furniture = {"sleep_1":"furn_nightlight_moon"}
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 660)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(viewport)
	var room := RoomVisual.new()
	room.size = Vector2(640, 360)
	viewport.add_child(room)
	var pig := PigVisual.new()
	pig.position = Vector2(660, 8)
	pig.size = Vector2(280, 230)
	pig.set_behavior(session.catalog.get_item("behaviors", "behavior_idle_stand"))
	pig.set_outfit(session.catalog.get_item("outfits", "outfit_berry_beret"))
	viewport.add_child(pig)
	var portrait := ExpressionPortrait.new()
	portrait.position = Vector2(730, 245)
	portrait.size = Vector2(112, 104)
	portrait.configure("happy", 0, true, "expr_happy_soft")
	viewport.add_child(portrait)
	var stage := EventStage.new()
	stage.position = Vector2(0, 385)
	stage.size = Vector2(640, 245)
	var event: Dictionary = session.catalog.get_item("events", "event_move_in")
	stage.set_step(event, (event.get("steps", []) as Array)[0] as Dictionary)
	viewport.add_child(stage)
	var sample := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	sample.fill(Color("#d9879b"))
	var framed: Control = ui.call("_framed_photo", sample, Vector2(96, 64)) as Control
	_expect_true(framed.get_child_count() == 2, "final photo-frame texture overlays the album image")
	framed.free()
	var snack_card: Control = ui.call("_catalog_card", "snacks", session.catalog.get_item("snacks", "snack_apple")) as Control
	_expect_true(snack_card.find_children("*", "TextureRect", true, false).size() == 1, "final snack texture appears in its catalog card")
	snack_card.free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image()
	_expect_true(rendered != null and not rendered.is_empty(), "final room, atmosphere, furniture, behavior, outfit, expression and event branches render together")
	viewport.queue_free()
	await get_tree().process_frame
	session.pig_state.placed_furniture = original_placed
	_expect_eq(session.final_assets.load_manifest(), [], "runtime resolver restores the pending project manifest after its visual fixture")
	var project_asset_manifest: Dictionary = JsonStore.read_object(FinalAssetCatalog.MANIFEST_PATH)
	_expect_eq(session.final_assets.enabled, bool(project_asset_manifest.get("ready", false)) or bool(project_asset_manifest.get("visual_ready", false)), "runtime resolver restores the active project artwork without claiming final audio readiness")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manifest_path))


func _count_labels_with_text(root: Node, value: String) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text == value:
			count += 1
	return count


func _press_visible_button_with_text(root: Node, value: String) -> bool:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and not button.disabled and button.text == value:
			button.pressed.emit()
			return true
	return false


func _press_album_event_action(ui: Control, event: Dictionary, action_text: String) -> bool:
	if not _press_visible_button_with_text(ui, tr("UI_ALBUM")):
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_nodes: Array[Node] = ui.find_children("*", "TabContainer", true, false)
	var tabs: TabContainer = tab_nodes[0] as TabContainer if not tab_nodes.is_empty() else null
	if tabs == null or tabs.get_child_count() < 2:
		return false
	tabs.current_tab = 1
	await get_tree().process_frame
	var memories: Control = tabs.get_child(1) as Control
	var event_title: String = tr(str(event.get("title_key", "")))
	for node: Node in memories.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text != event_title:
			continue
		var row: Node = label.get_parent().get_parent()
		for candidate: Node in row.find_children("*", "Button", true, false):
			var button := candidate as Button
			if button != null and button.is_visible_in_tree() and not button.disabled and button.text == action_text:
				button.pressed.emit()
				return true
	return false


func _catalog_action_for_name(root: Node, value: String) -> Button:
	for node: Node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or label.text != value:
			continue
		var content: Node = label.get_parent()
		if content == null:
			continue
		for child: Node in content.get_children():
			var action := child as Button
			if action != null:
				return action
	return null


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(label)

func _normalized_snout_point(pig: PigVisual) -> Vector2:
	var performance: Dictionary = pig.get("_performance") as Dictionary
	var body_id: String = str(performance.get("body_id", PigVisualRig.body_for(pig.behavior_animation)))
	return PigVisualRig.snout_for(body_id, int(pig.call("_performance_frame"))) / Vector2(256, 256)
