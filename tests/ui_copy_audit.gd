extends "res://tests/ui_smoke.gd"

var _output: String
var _captures: Array[String] = []


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	_output = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or _output.is_empty():
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.set_pig_name("猪持大局")
	GameSession.skip_tutorial()
	GameSession.pig_state.familiarity_level = 10
	GameSession.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[9]
	for item: Dictionary in GameSession.catalog.furniture:
		if str(item.id) not in GameSession.pig_state.owned_furniture:
			GameSession.pig_state.owned_furniture.append(str(item.id))
	GameSession.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	GameSession.pig_state.add_points(15000)
	GameSession.save_game()
	var main: Control = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := main.get_node("UILayer/MainUI") as MainUI
	await _check_actions(ui)
	await _test_main_window_mode_switch(GameSession, ui)
	await _check_desktop_chrome(main, ui)
	var views: Array[Dictionary] = [
		{"id":"furniture", "open":func() -> void: ui.call("_open_catalog", "furniture", "UI_FURNITURE")},
		{"id":"snacks", "open":func() -> void: ui.call("_open_catalog", "snacks", "UI_SNACKS")},
		{"id":"outfits", "open":func() -> void: ui.call("_open_catalog", "outfits", "UI_OUTFITS")},
		{"id":"item", "open":func() -> void: ui.open_furniture_detail("furn_bed_basic", "sleep_1")},
		{"id":"tendency", "open":func() -> void: ui.call("_open_tendency")},
		{"id":"mail", "open":ui.open_postcards},
		{"id":"memories", "open":func() -> void: ui.open_album(); (ui.find_child("AlbumTabs", true, false) as TabContainer).current_tab = 1},
		{"id":"plans", "open":func() -> void: ui.open_album(); (ui.find_child("AlbumTabs", true, false) as TabContainer).current_tab = 3},
		{"id":"residents", "open":func() -> void: ui.call("_open_companions")},
		{"id":"performances", "open":ui.open_pig_performances},
		{"id":"companion", "open":ui.open_desktop_companion_settings},
		{"id":"settings", "open":func() -> void: ui.call("_open_settings")},
	]
	var cases: Array[Array] = [[Vector2i(1280, 720), 1.0, "720p"], [Vector2i(1280, 800), 0.8, "16-10-80"], [Vector2i(2560, 1080), 1.0, "ultrawide"], [Vector2i(1280, 720), 1.5, "150"]]
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		GameSession.set_locale(locale)
		for test_case: Array in cases:
			get_window().size = test_case[0]
			GameSession.set_ui_scale(float(test_case[1]))
			ui.call("_rebuild_ui")
			ui.call("_close_panel")
			await _capture("room-%s-%s" % [locale, test_case[2]])
			for view: Dictionary in views:
				(view.open as Callable).call()
				await get_tree().process_frame
				await get_tree().process_frame
				var label: String = "%s-%s-%s" % [view.id, locale, test_case[2]]
				_expect_true(_rect_inside(Rect2(Vector2.ZERO, ui.size), (ui.get("_panel") as Control).get_global_rect()), "clean panel fits " + label)
				var panel := ui.get("_panel") as PanelContainer
				_expect_true((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "paper content is opaque " + label)
				var navigation := ui.find_child("AlbumNavigation", true, false) as BoxContainer
				if navigation != null:
					var tabs := ui.find_child("AlbumTabs", true, false) as TabContainer
					_expect_true(not tabs.tabs_visible and navigation.get_child_count() == 5, "album has five real navigation controls " + label)
					_expect_true(_rect_inside((ui.get("_panel_scroll") as Control).get_global_rect(), tabs.get_global_rect()), "album fills but does not exceed paper body " + label)
					for index: int in 5:
						var button := navigation.get_child(index) as Button
						_expect_true(button.icon != null and button.accessibility_name == tabs.get_tab_title(index) and button.button_pressed == (tabs.current_tab == index), "named icon and correct selected page " + label)
					_expect_true((navigation is HBoxContainer) == (float(test_case[1]) > 1.15), "responsive album navigation " + label)
				var sections := ui.find_child("SettingsSections", true, false) as GridContainer
				if sections != null:
					_expect_eq(sections.columns, 1 if float(test_case[1]) > 1.15 else 2, "responsive grouped settings " + label)
				for node: Node in (ui.get("_panel_content") as Control).find_children("*", "Label", true, false):
					var copy: String = (node as Label).text
					_expect_true(not copy.contains("INTRO") and not copy.contains("INBOX_HINT") and not copy.contains("不扣点数") and not copy.contains("不影响寄信进度") and not copy.contains("不需要额外付费"), "no retired explanation " + label)
				await _capture(label)
	var file := FileAccess.open(_output.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "screenshots":_captures}, "\t"))
	file.close()
	for failure: String in _failures:
		printerr(failure)
	print("UI_COPY: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_actions(ui: MainUI) -> void:
	ui.open_album()
	await get_tree().process_frame
	var tabs := ui.find_child("AlbumTabs", true, false) as TabContainer
	for index: int in 5:
		var navigation := ui.find_child("AlbumNav%d" % index, true, false) as Button
		navigation.pressed.emit()
		_expect_eq(tabs.current_tab, index, "sidebar button selects original album page")
		_expect_eq((ui.get("_panel_title") as Label).text, tabs.get_tab_title(index), "sidebar title follows page")
	ui.open_postcards()
	await get_tree().process_frame
	var open := ui.find_child("PostcardOpen_postcard_wake", true, false) as Button
	_expect_true(open != null and not open.disabled, "removing inbox explanation keeps real postcard action")
	if open != null:
		open.pressed.emit()
	await get_tree().process_frame
	_expect_true(ui.find_child("PostcardLetter", true, false) != null and "postcard_wake" in GameSession.pig_state.read_postcards, "letter content and persistent read action remain")
	_expect_true(_count_labels_with_text(ui, tr("POSTCARD_SOURCE")) == 1, "compact PigHub attribution remains")
	ui.call("_open_companions")
	var options := ui.find_child("ResidentInitialPersonality", true, false) as OptionButton
	var description := ui.find_child("ResidentInitialPersonalityDescription", true, false) as Label
	_expect_true(options != null and description != null and not description.visible and description.text.is_empty(), "random personality shows no generic explainer or empty spacing")
	if options != null and description != null:
		options.select(1)
		options.item_selected.emit(1)
		_expect_true(description.visible and not description.text.is_empty(), "actual personality characterization remains on selection")
		options.select(0)
		options.item_selected.emit(0)
		_expect_true(not description.visible and description.text.is_empty(), "returning to random hides characterization cleanly")
	ui.open_desktop_companion_settings()
	var quiet := ui.find_child("DesktopQuietToggle", true, false) as CheckBox
	_expect_true(quiet != null, "quiet control remains")
	if quiet != null:
		quiet.button_pressed = true
	_expect_true(GameSession.desktop_companion.quiet, "quiet checkbox still saves policy")
	(ui.find_child("FocusTimerStart", true, false) as Button).pressed.emit()
	_expect_eq(GameSession.desktop_companion.timer_phase, "work", "focus start button works without introductory paragraph")
	(ui.find_child("FocusTimerStop", true, false) as Button).pressed.emit()
	_expect_eq(GameSession.desktop_companion.timer_phase, "idle", "focus stop button remains usable")
	ui.call("_open_legal")
	_expect_eq(_count_labels_with_text(ui, tr("DESKTOP_PRIVACY_BOUNDARY")), 1, "desktop privacy explanation is available only in legal page")
	ui.call("_show_save_recovery_required")
	_expect_true(ui.find_child("SaveRecoveryMessage", true, false) != null, "critical save recovery warning is not removed")
	ui.call("_close_panel")
	GameSession.desktop_companion.load_settings({})


func _check_desktop_chrome(main: Control, ui: MainUI) -> void:
	ui.call("_close_panel")
	var controller: DesktopWindowController = main.get("_desktop_controller")
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		GameSession.set_locale(locale)
		controller.enter(main.get_node("Pig"), main.get_node("Room"), ui)
		controller.set_process(false)
		controller.transparent_mode = false
		controller.set("_pig_only_preference", false)
		for scale_value: float in [0.5, 0.75, 1.0, 1.25, 1.5]:
			controller.scale_factor = scale_value
			controller.call("_apply_window_mode")
			await get_tree().process_frame
			await get_tree().process_frame
			var layer := controller.get("_controls_layer") as CanvasLayer
			var controls := layer.get_child(0) as Control
			var bubble := controller.get("_event_bubble") as Control
			bubble.visible = true
			await get_tree().process_frame
			var window := Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size()))
			var label: String = "%s-%d" % [locale, roundi(scale_value * 100)]
			_expect_true(_rect_inside(window, controls.get_global_rect()) and _rect_inside(window, bubble.get_global_rect()), "desktop chrome fits native window " + label)
			_expect_true(_rect_inside(Rect2(DesktopFramePolicy.control_bar_rect(DisplayServer.window_get_size())), controls.get_global_rect()), "return/menu stays within its native hit region " + label)
			_expect_true(_rect_inside(DesktopFramePolicy.event_bubble_rect(DisplayServer.window_get_size()), bubble.get_global_rect()), "mail stays within its native hit region " + label)
			await _capture("desktop-" + label)
		controller.leave()
		await get_tree().process_frame
	GameSession.set_locale("zh_CN")
	get_window().size = Vector2i(1280, 720)


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_expect_eq(get_window().get_texture().get_image().save_png(_output.path_join(label + ".png")), OK, "real clean UI capture " + label)
	_captures.append(label + ".png")
