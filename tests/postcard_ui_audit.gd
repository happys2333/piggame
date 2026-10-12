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
	GameSession.initialize_current_companion("猪持大局", "personality_lazy")
	GameSession.skip_tutorial()
	var main: Control = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := main.get_node("UILayer/MainUI") as MainUI
	ui.open_postcards()
	await get_tree().process_frame
	var tabs := ui.find_child("AlbumTabs", true, false) as TabContainer
	_expect_true(tabs != null and tabs.get_tab_count() == 5 and tabs.current_tab == 4, "real inbox is fifth album page")
	_expect_eq(ui.find_children("PostcardArt_*", "TextureRect", true, false).size(), 0, "locked cards load no art")
	_expect_true(not GameSession.open_postcard("postcard_wake"), "locked postcard cannot be opened")
	GameSession.pig_state.add_points(99)
	_expect_true((ui.get("_postcard_progress") as Label).text.contains("99"), "open inbox tracks cumulative progress without rebuilding")
	await _capture("locked-99")
	ui.call("_close_panel")
	var dot := ui.get("_album_unread_dot") as Panel
	GameSession.desktop_companion.set_application_focused(false)
	GameSession.pig_state.add_points(1)
	_expect_eq(GameSession.save_game(), OK, "background crossing persists delivery")
	_expect_true(dot.visible and not (ui.get("_overlay") as Control).visible, "mail uses unread dot without opening a modal in another game")
	var desktop: DesktopWindowController = main.get("_desktop_controller")
	GameSession.pig_state.add_familiarity(PigState.FAMILIARITY_THRESHOLDS[1])
	desktop.enter(main.get_node("Pig"), main.get_node("Room"), ui)
	desktop.set_process(false)
	GameSession.desktop_companion.set_application_focused(false)
	desktop.call("_update_event_bubble")
	_expect_true(not (desktop.get("_event_bubble") as Control).visible and not desktop.effective_always_on_top(), "background game sees no mail bubble or topmost window")
	GameSession.pig_state.add_points(200)
	GameSession.save_game()
	_expect_true(not (desktop.get("_event_bubble") as Control).visible and desktop.active, "new background mail never leaves desktop mode")
	for preferences: Dictionary in [{"desktop_quiet":true}, {"desktop_do_not_disturb":true}, {"desktop_behavior_frequency":"off"}]:
		GameSession.desktop_companion.load_settings(preferences)
		GameSession.desktop_companion.set_application_focused(true)
		desktop.call("_update_event_bubble")
		_expect_true(not (desktop.get("_event_bubble") as Control).visible, "quiet/DND/frequency-off suppress automatic mail " + str(preferences))
	GameSession.desktop_companion.load_settings({})
	_expect_true(await _wait_for_foreground_focus(GameSession), "native focus settles for deliberate desktop mail click")
	desktop.call("_update_event_bubble")
	_expect_true((desktop.get("_event_bubble") as Control).visible, "foreground unread mail uses existing bubble")
	await _capture("desktop-mail")
	(desktop.get("_event_bubble_button") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	tabs = ui.find_child("AlbumTabs", true, false) as TabContainer
	_expect_true(not desktop.active and ui.visible and tabs != null and tabs.current_tab == 4, "deliberate desktop bubble opens inbox in room")
	desktop.enter(main.get_node("Pig"), main.get_node("Room"), ui)
	var menu: PopupMenu = desktop.get("_context_popup") as PopupMenu
	_expect_true(menu.get_item_index(36) >= 0, "pig-only context menu keeps mail accessible without proactive bubble")
	menu.id_pressed.emit(36)
	await get_tree().process_frame
	_expect_true(not desktop.active and ui.find_child("AlbumTabs", true, false) != null, "deliberate context mail action returns to inbox")
	var open := ui.find_child("PostcardOpen_postcard_wake", true, false) as Button
	_expect_true(open != null, "real received letter has open action")
	if open != null:
		open.pressed.emit()
	await get_tree().process_frame
	_expect_true(ui.find_child("PostcardLetter", true, false) != null and "postcard_wake" in GameSession.pig_state.read_postcards, "real button presents letter after persistent read command")
	GameSession.pig_state.add_points(14700)
	GameSession.save_game()
	await _test_layouts(ui)
	for card: Dictionary in GameSession.catalog.postcards:
		GameSession.open_postcard(str(card.id))
	ui.open_postcards()
	await get_tree().process_frame
	_expect_true(GameSession.unread_postcard_count() == 0 and not (ui.get("_album_unread_dot") as Panel).visible, "all opened postcards clear album dot")
	var file := FileAccess.open(_output.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "screenshots":_captures}, "\t"))
	file.close()
	for failure: String in _failures:
		printerr(failure)
	print("POSTCARD_UI: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_layouts(ui: MainUI) -> void:
	var cases: Array[Array] = [[Vector2i(1280, 720), 1.0, "720p"], [Vector2i(1280, 800), 0.8, "16-10-80"], [Vector2i(2560, 1080), 1.0, "ultrawide"], [Vector2i(1280, 720), 1.5, "150"], [Vector2i(960, 540), 1.5, "minimum-150"]]
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		GameSession.set_locale(locale)
		for test_case: Array in cases:
			get_window().size = test_case[0]
			GameSession.set_ui_scale(float(test_case[1]))
			ui.call("_rebuild_ui")
			ui.open_postcards()
			await get_tree().process_frame
			await get_tree().process_frame
			var viewport := Rect2(Vector2.ZERO, ui.size)
			var label: String = "%s-%s" % [locale, test_case[2]]
			_expect_true(_rect_inside(viewport, (ui.get("_panel") as Control).get_global_rect()), "inbox panel fits " + label)
			_expect_eq(ui.find_children("PostcardArt_*", "TextureRect", true, false).size(), 8, "all original postcards are available " + label)
			await _capture("inbox-" + label)
			for card: Dictionary in GameSession.catalog.postcards:
				ui.call("_open_postcard", str(card.id))
				await get_tree().process_frame
				await get_tree().process_frame
				var art := ui.find_child("PostcardArt_" + str(card.id), true, false) as TextureRect
				_expect_true(art != null and art.texture != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.scale.is_equal_approx(Vector2.ONE), "original artwork is uniform and uncropped " + label + str(card.id))
				var letter := ui.find_child("PostcardLetter", true, false) as Label
				_expect_true(letter != null and not letter.text.contains("POSTCARD_") and not letter.text.contains("{name}"), "localized pig letter has no keys/placeholders " + label)
				var scroll := ui.get("_panel_scroll") as ScrollContainer
				var back: Button = null
				for node: Node in ui.find_children("*", "Button", true, false):
					if (node as Button).text == tr("POSTCARD_BACK"):
						back = node as Button
				_expect_true(back != null, "back navigation exists " + label)
				if back != null:
					scroll.ensure_control_visible(back)
					await get_tree().process_frame
					_expect_true(viewport.intersects(back.get_global_rect()), "back navigation remains reachable at high scale " + label)
				scroll.scroll_vertical = 0
				if locale == "zh_CN" or str(card.id) == "postcard_flat":
					await _capture("%s-%s" % [str(card.id), label])
	GameSession.set_ui_scale(1.0)
	get_window().size = Vector2i(1280, 720)
	ui.call("_rebuild_ui")


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_expect_eq(get_window().get_texture().get_image().save_png(_output.path_join(label + ".png")), OK, "real rendered capture " + label)
	_captures.append(label + ".png")
