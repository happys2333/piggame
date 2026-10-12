extends Node

const MAIN_SCENE: PackedScene = preload("res://game/scenes/main.tscn")

var _output: String
var _assertions: int = 0
var _failures: Array[String] = []
var _captures: Array[String] = []
var _layouts: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _process(_delta: float) -> void:
	RenderingServer.force_draw()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _settle() -> void:
	for frame: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	_output = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or _output.is_empty():
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.set_pig_name("猪持大局")
	GameSession.skip_tutorial()
	GameSession.pig_state.familiarity_level = 10
	GameSession.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[9]
	GameSession.pig_state.add_points(15000)
	GameSession.save_game()
	var main := MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(main)
	await _settle()
	var ui := main.get_node("UILayer/MainUI") as MainUI
	await _check_transactions(ui)
	var cases: Array[Array] = [[Vector2i(1280, 720), 1.0, "720p"], [Vector2i(1280, 800), 0.8, "16-10-80"], [Vector2i(2560, 1080), 1.0, "ultrawide"], [Vector2i(1280, 720), 1.5, "150"], [Vector2i(960, 540), 1.5, "minimum-150"]]
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		GameSession.set_locale(locale)
		for test_case: Array in cases:
			get_window().size = test_case[0]
			GameSession.set_ui_scale(float(test_case[1]))
			ui.call("_rebuild_ui")
			ui.call("_close_panel")
			await _settle()
			var label: String = "%s-%s" % [locale, test_case[2]]
			_layouts.append({"case":label, "requested":str(test_case[0]), "rendered":str(get_window().size), "ui_size":str(ui.size)})
			_check_hud(ui, label)
			await _capture("room-" + label)
			for kind: String in ["furniture", "snacks", "outfits"]:
				ui.call("_open_catalog", kind, "UI_%s" % kind.to_upper())
				await _settle()
				_check_panel(ui, label + kind)
				var grid := ui.find_child("CatalogGrid", true, false) as GridContainer
				_expect(grid != null and grid.columns >= 1 and grid.columns <= 3, "responsive catalog columns " + label + kind)
				if test_case[2] == "150":
					_expect(grid.columns == 2, "150% catalog uses available width rather than forced single column " + label)
				for card: Node in grid.get_children():
					_expect((card as Control).size.x <= (ui.get("_panel_scroll") as Control).size.x, "card fits available paper width " + label + str(card.name))
					for node: Node in card.find_children("*", "Button", true, false):
						_check_button(node as Button, label + str(card.name))
				if kind == "outfits":
					_expect(ui.find_children("AccessoryPreview_*", "Control", true, false).size() == 8, "all eight accessories use the real pig rig " + label)
					var first := grid.get_child(0) as Control
					var action := first.find_child("CatalogAction_*", true, false) as Button
					_expect(_inside((ui.get("_panel_scroll") as Control).get_global_rect(), action.get_global_rect()), "first accessory action visible without scrolling " + label)
				await _capture(kind + "-" + label)
			ui.open_album()
			await _settle()
			var tabs := ui.find_child("AlbumTabs", true, false) as TabContainer
			_expect(tabs.get_tab_count() == 5, "all original album pages retained " + label)
			for index: int in 5:
				var button := ui.find_child("AlbumNav%d" % index, true, false) as Button
				button.pressed.emit()
				await _settle()
				_expect(tabs.current_tab == index and button.button_pressed, "navigation selects page " + label + str(index))
				_expect(button.accessibility_name == tabs.get_tab_title(index), "accessible page title " + label + str(index))
				button.grab_focus()
				_expect(get_viewport().gui_get_focus_owner() == button, "keyboard focus reaches page navigation " + label + str(index))
				_check_panel(ui, label + str(index))
				_expect(_inside((ui.get("_panel_scroll") as Control).get_global_rect(), tabs.get_global_rect()), "album never exceeds real content area " + label + str(index))
				_expect((ui.get("_panel_scroll") as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "album has no competing outer scroll " + label)
				await _capture("album%d-%s" % [index, label])
			ui.call("_open_settings")
			await _settle()
			_check_panel(ui, "settings-" + label)
			_expect((ui.get("_panel_scroll") as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "normal panels restore scrolling " + label)
			await _capture("settings-" + label)
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "screenshots":_captures, "layouts":_layouts}, "\t"))
	file.close()
	for failure: String in _failures.slice(0, 30):
		printerr(failure)
	print("UI_REFINEMENT: assertions=%d failures=%d captures=%d" % [_assertions, _failures.size(), _captures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_transactions(ui: MainUI) -> void:
	ui.call("_open_catalog", "outfits", "UI_OUTFITS")
	await _settle()
	var item: Dictionary = GameSession.catalog.outfits.back()
	var scroll := ui.get("_panel_scroll") as ScrollContainer
	var action := ui.find_child("CatalogAction_%s" % str(item.id), true, false) as Button
	scroll.ensure_control_visible(action)
	await _settle()
	var previous_scroll: int = scroll.scroll_vertical
	var points: int = GameSession.pig_state.daily_points
	action.pressed.emit()
	await _settle()
	_expect(GameSession.pig_state.current_outfit == str(item.id), "purchase equips through GameSession")
	_expect(not (ui.find_child("CatalogState_outfit_berry_beret", true, false) as Label).text.contains(".0"), "point prices display integers")
	_expect(GameSession.pig_state.daily_points == points - int(item.price), "purchase charges once")
	_expect(abs(scroll.scroll_vertical - previous_scroll) <= 2, "purchase preserves rack scroll position")
	_expect((ui.find_child("CatalogAction_%s" % str(item.id), true, false) as Button).disabled, "equipped item prevents duplicate purchase")
	(ui.find_child("RemoveOutfitButton", true, false) as Button).pressed.emit()
	await _settle()
	_expect(GameSession.pig_state.current_outfit.is_empty(), "remove action clears accessory")
	points = GameSession.pig_state.daily_points
	(ui.find_child("CatalogAction_%s" % str(item.id), true, false) as Button).pressed.emit()
	await _settle()
	_expect(GameSession.pig_state.current_outfit == str(item.id) and GameSession.pig_state.daily_points == points, "owned accessory re-equips without charge")
	ui.call("_open_catalog", "snacks", "UI_SNACKS")
	await _settle()
	var snack: Dictionary = GameSession.catalog.snacks[0]
	(ui.find_child("CatalogAction_%s" % str(snack.id), true, false) as Button).pressed.emit()
	await _settle()
	points = GameSession.pig_state.daily_points
	(ui.find_child("CatalogAction_%s" % str(snack.id), true, false) as Button).pressed.emit()
	await _settle()
	_expect(GameSession.pig_state.daily_points == points - int(snack.price), "previously fed snacks still cost points")
	points = GameSession.pig_state.daily_points
	GameSession.pig_state.daily_points = 0
	ui.call("_open_catalog", "snacks", "UI_SNACKS")
	await _settle()
	var feed := ui.find_child("CatalogAction_%s" % str(snack.id), true, false) as Button
	_expect(feed.disabled and not feed.tooltip_text.is_empty(), "unaffordable feed explains disabled state")
	GameSession.pig_state.add_points(int(snack.price))
	await _settle()
	_expect(not feed.disabled and feed.tooltip_text.is_empty(), "income enables feed without reopening or resetting scroll")
	GameSession.pig_state.daily_points = points
	GameSession.state_changed.emit()
	ui.call("_open_catalog", "furniture", "UI_FURNITURE")
	await _settle()
	scroll.scroll_vertical = 180
	(ui.find_child("CatalogArea_sleep", true, false) as Button).pressed.emit()
	await _settle()
	_expect(scroll.scroll_vertical == 0, "changing category returns to top")
	for card: Node in (ui.find_child("CatalogGrid", true, false) as GridContainer).get_children():
		var definition: Dictionary = GameSession.catalog.get_item("furniture", str(card.name).trim_prefix("CatalogCard_"))
		_expect(str(definition.area) == "sleep", "category contains only selected area")
	(ui.find_child("CatalogArea_all", true, false) as Button).pressed.emit()
	ui.open_postcards()
	await _settle()
	var open := ui.find_child("PostcardOpen_postcard_wake", true, false) as Button
	_expect(open != null and not open.disabled, "earned postcard remains available")
	if open != null:
		open.pressed.emit()
		await _settle()
		_expect(ui.find_child("PostcardLetter", true, false) != null and "postcard_wake" in GameSession.pig_state.read_postcards, "letter opens with persistent read transaction")
	ui.call("_close_panel")


func _check_hud(ui: MainUI, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, ui.size)
	_expect(_inside(bounds, (ui.find_child("TopBar", true, false) as Control).get_global_rect()), "light HUD fits " + label)
	for node: Node in ui.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree():
			_expect(_inside(bounds, button.get_global_rect()), "HUD button fits " + label + str(button.name))
	for name: String in ["AlbumButton", "PhotoButton", "SettingsButton"]:
		var button := ui.find_child(name, true, false) as Button
		_expect(button.icon != null and not button.tooltip_text.is_empty() and not button.accessibility_name.is_empty(), "icon tools retain accessible labels " + label + name)


func _check_button(button: Button, label: String) -> void:
	_expect(button.get_global_rect().size.x >= button.get_combined_minimum_size().x - 1.0, "action text fits " + label)
	_expect(not button.text.begins_with("UI_"), "localized action " + label)


func _check_panel(ui: MainUI, label: String) -> void:
	var panel := ui.get("_panel") as PanelContainer
	_expect(_inside(Rect2(Vector2.ZERO, ui.size), panel.get_global_rect()), "paper panel fits " + label)
	_expect((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "paper remains opaque " + label)


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(get_window().get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK, "real screenshot " + label)
	_captures.append(label + ".png")
