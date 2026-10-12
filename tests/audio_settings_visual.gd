extends Node

const MAIN_SCENE: PackedScene = preload("res://game/scenes/main.tscn")

var _failures: Array[String] = []
var _assertions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _process(_delta: float) -> void:
	RenderingServer.force_draw()


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)


func _run() -> void:
	var output: String = OS.get_environment("PIGGAME_AUDIO_AUDIT_DIR")
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if output.is_empty() or expected.is_empty() or not OS.get_user_data_dir().ends_with(expected):
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.pig_state.name = "Audio Pig"
	GameSession.pig_state.personality_id = "personality_lively"
	GameSession.pig_state.tutorial_skipped = true
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	var ui: Control = main.get_node("UILayer/MainUI")
	var cases: Array[Array] = [
		[Vector2i(1280, 720), 1.0, "720p"],
		[Vector2i(1280, 800), 1.0, "16-10"],
		[Vector2i(2560, 1080), 1.0, "ultrawide"],
		[Vector2i(1280, 720), 0.8, "80"],
		[Vector2i(1280, 720), 1.5, "150"],
	]
	for locale: String in ["zh_CN", "zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		for configuration: Array in cases:
			get_window().size = configuration[0]
			GameSession.ui_scale = float(configuration[1])
			ui.call("_rebuild_ui")
			await get_tree().process_frame
			await get_tree().process_frame
			var settings: Button = ui.find_child("SettingsButton", true, false) as Button
			_expect(settings != null and settings.is_visible_in_tree(), "settings reachable " + locale)
			if settings != null:
				settings.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var mute: CheckBox = ui.find_child("SoundMuteToggle", true, false) as CheckBox
			var preview: Button = ui.find_child("SoundPreviewButton", true, false) as Button
			var scroll: ScrollContainer = ui.get("_panel_scroll") as ScrollContainer
			if scroll != null and preview != null:
				scroll.ensure_control_visible(preview)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
			var volume: HSlider
			for slider: Node in ui.find_children("*", "HSlider", true, false):
				if (slider as HSlider).accessibility_name == tr("SETTINGS_INTERACTION"):
					volume = slider as HSlider
			_expect(mute != null and not mute.disabled and preview != null and not preview.disabled and volume != null and volume.editable, "feedback controls usable " + locale)
			for control: Control in [mute, preview, volume]:
				if control != null:
					var panel: Control = ui.get("_panel") as Control
					var rect: Rect2 = control.get_global_rect()
					_expect(panel != null and rect.size.x > 0 and rect.position.x >= panel.get_global_rect().position.x - 1 and rect.end.x <= panel.get_global_rect().end.x + 1, "audio control fits panel " + locale)
					_expect(scroll != null and scroll.get_global_rect().grow(1.0).encloses(rect), "audio control visible after scrolling " + locale)
			for label: Node in ui.find_children("*", "Label", true, false):
				_expect(not (label as Label).text in ["SETTINGS_MUSIC", "SETTINGS_AMBIENT", "SETTINGS_AUDIO_SILENT"], "no obsolete audio labels")
			get_window().get_texture().get_image().save_png(output.path_join("settings-%s-%s.png" % [locale, configuration[2]]))
			ui.call("_close_panel")
	GameSession.ui_scale = 1.0
	TranslationServer.set_locale("zh_CN")
	var controller: Node = main.get("_desktop_controller") as Node
	GameSession.pig_state.add_familiarity(2000)
	ui.desktop_requested.emit()
	await get_tree().process_frame
	_expect(bool(controller.get("active")), "desktop entry uses the player-facing command")
	var popup := PopupMenu.new()
	controller.add_child(popup)
	controller.call("_populate_popup", popup)
	if popup != null:
		_expect(popup.get_item_index(38) >= 0, "desktop right-click offers mute")
		controller.call("_menu_action", 38, popup)
		_expect(AudioService.muted, "desktop mute uses persisted session command")
		GameSession.set_sound_muted(false)
	else:
		_expect(false, "desktop popup exists")
	controller.call("leave")
	main.queue_free()
	AudioService.stop_all()
	await get_tree().process_frame
	for failure: String in _failures:
		printerr(failure)
	print("AUDIO_SETTINGS_VISUAL: assertions=%d failures=%d layouts=15 physical_output=false" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
