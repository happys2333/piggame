extends SceneTree

var _room_draws: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_user_dir: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected_user_dir.is_empty() or not OS.get_user_data_dir().ends_with(expected_user_dir):
		push_error("runtime profile requires isolated user data")
		quit(1)
		return
	var main: Node = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var session: Node = root.get_node("GameSession")
	session.set_process(false)
	await process_frame
	var ui: Control = main.get_node("UILayer/MainUI") as Control
	(ui.find_child("NameSkipTutorialButton", true, false) as Button).pressed.emit()
	var room: Control = main.get_node("Room") as Control
	room.draw.connect(func() -> void: _room_draws += 1)
	RenderingServer.force_draw()
	await process_frame
	_room_draws = 0
	var started: int = Time.get_ticks_usec()
	for frame_index: int in 120:
		session.state_changed.emit()
		RenderingServer.force_draw()
		await process_frame
	var state_refresh_usec: int = Time.get_ticks_usec() - started
	var room_draws: int = _room_draws
	var points_before: String = (ui.get("_points_label") as Label).text
	ui.hide()
	session.pig_state.add_points(17)
	session.state_changed.emit()
	var hidden_hud_updates: bool = (ui.get("_points_label") as Label).text != points_before
	ui.show()
	var restored_hud: bool = (ui.get("_points_label") as Label).text == tr("UI_POINTS").format({"points":session.pig_state.daily_points})
	var assets := FinalAssetCatalog.new()
	var errors: Array[String] = assets.load_manifest()
	if not errors.is_empty():
		push_error("runtime profile cannot load visual manifest")
		quit(1)
		return
	for token: String in FinalAssetCatalog.expected_coverage_tokens():
		if token.begins_with("audio:"):
			continue
		for frame_index: int in 4:
			if assets.texture_for(token, frame_index) == null:
				push_error("runtime profile lost visual coverage")
				quit(1)
				return
	var retained: Dictionary = {}
	for texture: Texture2D in (assets.get("_texture_cache") as Dictionary).values():
		var base: Texture2D = (texture as AtlasTexture).atlas if texture is AtlasTexture else texture
		retained[base.resource_path] = base.get_width() * base.get_height() * 4
	var retained_rgba_bytes: int = 0
	for byte_count: int in retained.values():
		retained_rgba_bytes += byte_count
	print("PROFILE=" + JSON.stringify({
		"server":DisplayServer.get_name(), "engine":Engine.get_version_info().string,
		"room_draws_per_120_unchanged_state_signals":room_draws,
		"state_refresh_wall_usec":state_refresh_usec,
		"hidden_hud_updates":hidden_hud_updates, "restored_hud":restored_hud,
		"catalog_retained_atlases":retained.size(), "catalog_retained_rgba_bytes":retained_rgba_bytes,
		"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
	}))
	quit(0)
