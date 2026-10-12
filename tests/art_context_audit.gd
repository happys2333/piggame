extends "res://tests/ui_smoke.gd"


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	var output: String = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or output.is_empty():
		get_tree().quit(1)
		return
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = main.get_node("UILayer/MainUI")
	var skip := ui.find_child("NameSkipTutorialButton", true, false) as Button
	if skip != null:
		skip.pressed.emit()
	GameSession.set_process(false)
	await _test_furniture_visuals(GameSession)
	await _test_atmosphere_visuals(GameSession)
	for palette: String in ["rose", "mint", "night"]:
		GameSession.pig_state.current_room_palette = palette
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_tree().root.add_child(viewport)
		var room := RoomVisual.new()
		room.size = Vector2(1280, 720)
		viewport.add_child(room)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		_expect_true(image.save_png(output.path_join("room-%s.png" % palette)) == OK, "full room palette capture " + palette)
		viewport.queue_free()
		await get_tree().process_frame
	var stage_viewport := SubViewport.new()
	stage_viewport.size = Vector2i(640, 245)
	stage_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(stage_viewport)
	var stage := EventStage.new()
	stage.size = Vector2(640, 245)
	stage_viewport.add_child(stage)
	stage.set_process(false)
	stage.set_step(GameSession.catalog.events[0], {"animation":"sit"})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sample: Image = stage_viewport.get_texture().get_image()
	var framed_viewport := SubViewport.new()
	framed_viewport.size = Vector2i(1980, 275)
	framed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(framed_viewport)
	for index: int in GameSession.PHOTO_FRAMES.size():
		GameSession.pig_state.current_photo_frame = GameSession.PHOTO_FRAMES[index]
		var frame: Control = ui.call("_framed_photo", sample, Vector2(640, 245)) as Control
		frame.position = Vector2(index * 660, 0)
		framed_viewport.add_child(frame)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_expect_true(framed_viewport.get_texture().get_image().save_png(output.path_join("actual-photo-frames.png")) == OK, "all production photo frames on an actual event photo")
	framed_viewport.queue_free()
	stage_viewport.queue_free()
	main.queue_free()
	await get_tree().process_frame
	for failure: String in _failures:
		printerr(failure)
	print("ART_CONTEXT: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
