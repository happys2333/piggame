extends "res://tests/ui_smoke.gd"

var _output: String
var _captures: Array[Dictionary] = []


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	_output = OS.get_environment("PIGGAME_MENU_OUTPUT")
	if expected.is_empty() or _output.is_empty() or not OS.get_user_data_dir().ends_with(expected):
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.set_pig_name("菜单 QA")
	GameSession.skip_tutorial()
	GameSession.pig_state.familiarity_level = 2
	GameSession.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
	for card: Dictionary in GameSession.catalog.postcards:
		GameSession.pig_state.earned_points = maxi(GameSession.pig_state.earned_points, int(card.points))
	GameSession.save_game()
	GameSession.save_machine_settings({"desktop_pig_only":false})
	GameSession.set_reduce_motion(true)
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var controller: DesktopWindowController = main.get("_desktop_controller") as DesktopWindowController
	var pig: PigVisual = main.get_node("Pig") as PigVisual
	var ui: MainUI = main.get_node("UILayer/MainUI") as MainUI
	var room: RoomVisual = main.get_node("Room") as RoomVisual
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		GameSession.set_locale(locale)
		for ui_scale: float in [0.8, 1.0, 1.5]:
			GameSession.set_ui_scale(ui_scale)
			for percentage: int in [50, 75, 100, 125, 150]:
				controller.enter(pig, room, ui)
				controller.transparent_mode = true
				controller.scale_factor = float(percentage) / 100.0
				controller.call("_apply_window_mode")
				controller.set_process(false)
				pig.set_process(false)
				var label: String = "%s-ui%d-pig%d" % [locale, roundi(ui_scale * 100), percentage]
				_expect_true(await _wait_for_foreground_focus(GameSession), "foreground " + label)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var popup: PopupMenu = controller.get("_context_popup") as PopupMenu
				var window_size: Vector2i = DisplayServer.window_get_size()
				var expected_size: Vector2i = DesktopFramePolicy.companion_window_size(controller.scale_factor, true)
				_expect_true(absi(window_size.x - expected_size.x) <= 1 and absi(window_size.y - expected_size.y) <= 1, "no reserved rail space " + label)
				_expect_true(controller.pig_only_mode and _no_permanent_controls(controller), "desktop creates no permanent controls " + label)
				_expect_true(not popup.visible and not room.visible and not ui.visible and _rect_inside(Rect2(Vector2.ZERO, Vector2(window_size)), pig.get_global_rect()), "only complete pig is visible " + label)
				_expect_true(popup.get_theme_font_size("font_size") == roundi(18 * clampf(ui_scale, 1.0, 1.5)), "readable menu independent of pig scale " + label)
				_expect_true(popup.get_item_index(6) == -1 and popup.get_item_index(22) >= 0 and popup.get_item_index(34) >= 0 and popup.get_item_index(36) >= 0 and popup.get_item_index(37) >= 0, "all navigation lives in context menu without a rail toggle " + label)
				for card: Dictionary in GameSession.catalog.postcards:
					GameSession.pig_state.received_postcards[str(card.id)] = GameSession.clock.current_unix()
				GameSession.pig_state.read_postcards.clear()
				var before: Dictionary = GameSession.pig_state.to_dict().duplicate(true)
				controller.call("_on_memory_queue_changed")
				_expect_true(not popup.visible and popup.get_item_text(popup.get_item_index(36)).contains("8"), "new mail updates menu silently " + label)
				var image: Image = get_window().get_texture().get_image()
				var path: String = _output.path_join(label + ".png")
				_expect_eq(image.save_png(path), OK, "capture pig-only desktop " + label)
				_captures.append({"label":label,"path":path,"size":[image.get_width(),image.get_height()]})
				var right := InputEventMouseButton.new()
				right.button_index = MOUSE_BUTTON_RIGHT
				right.pressed = true
				right.position = pig.size * 0.5
				right.global_position = pig.get_global_transform() * right.position
				pig._gui_input(right)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				_expect_true(popup.visible and not popup.is_embedded(), "pig right click opens a native popup outside the tiny host " + label)
				if percentage == 100 and is_equal_approx(ui_scale, 1.0):
					_expect_eq(popup.get_texture().get_image().save_png(_output.path_join("menu-" + locale + ".png")), OK, "capture menu " + label)
				popup.hide()
				var sizes: PopupMenu = popup.get_node("SizeMenu") as PopupMenu
				_expect_true(sizes.item_count == 5 and (popup.get_node("DockMenu") as PopupMenu).item_count == ReleaseProfile.desktop_docks().size(), "size and docking are compact submenus " + label)
				sizes.id_pressed.emit(percentage)
				_expect_true(is_equal_approx(controller.scale_factor, float(percentage) / 100.0), "size command reaches controller " + label)
				popup.id_pressed.emit(4)
				await get_tree().process_frame
				_expect_true(not get_window().transparent_bg and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) and controller.pig_only_mode and _no_permanent_controls(controller), "ordinary fallback also has no sidebar " + label)
				if percentage == 50 and is_equal_approx(ui_scale, 1.0):
					await RenderingServer.frame_post_draw
					_expect_eq(get_window().get_texture().get_image().save_png(_output.path_join("fallback-" + locale + ".png")), OK, "capture ordinary fallback " + label)
				_expect_true(GameSession.pig_state.to_dict() == before, "opening and operating menus never earns rewards " + label)
				popup.id_pressed.emit(22)
				_expect_true(not controller.active and room.visible and ui.visible, "return room remains accessible " + label)
				await get_tree().process_frame
	controller.enter(pig, room, ui)
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	controller._unhandled_input(escape)
	_expect_true(not controller.active and ui.visible, "Escape returns to room rather than revealing a sidebar")
	var report: Dictionary = {"assertions":_assertions,"failures":_failures,"captures":_captures,"windows_native_verified":false}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for failure: String in _failures:
		printerr(failure)
	print("DESKTOP_CONTEXT_AUDIT: assertions=%d failures=%d screenshots=%d" % [_assertions, _failures.size(), _captures.size()])
	if _failures.is_empty():
		print("PASS: desktop context menu audit")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _no_permanent_controls(controller: DesktopWindowController) -> bool:
	for child: Node in controller.get_children():
		if child is Control or child is CanvasLayer:
			return false
	return true
