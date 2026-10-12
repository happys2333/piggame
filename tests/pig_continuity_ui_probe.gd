extends "res://tests/ui_smoke.gd"


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected):
		get_tree().quit(1)
		return
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = main.get_node("UILayer/MainUI")
	var session: Node = get_tree().root.get_node("GameSession")
	var skip := ui.find_child("NameSkipTutorialButton", true, false) as Button
	if skip != null:
		skip.pressed.emit()
	session.set_process(false)
	session.pig_state.personality_id = "personality_lively"
	var noon: int = int(Time.get_unix_time_from_datetime_string("2026-10-09T12:00:00")) - int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	session.clock = GameClock.new(func() -> int: return noon)
	session.simulation.invite_behavior(session.catalog.get_item("behaviors", "behavior_idle_stand"), false)
	session.behavior_changed.emit(session.simulation.current_behavior)
	await _test_pig_performance_library(main, session, ui)
	await _test_desktop_companion_protection(main, session, ui)
	await _test_pig_only_companion(main, session, ui)
	await _test_desktop_unobstructed_companion(main, session, ui)
	await _test_desktop_pig_scale_roundtrip(main, session, ui)
	await _test_event_photo_capture_isolation(main, session, ui)
	var output: String = OS.get_environment("PIGGAME_MOTION_REVIEW_DIR")
	var cases: Array[Array] = [
		[Vector2i(1280, 720), 1.0, "1280x720"],
		[Vector2i(1280, 800), 1.0, "16x10"],
		[Vector2i(2560, 1080), 1.0, "ultrawide"],
		[Vector2i(1280, 720), 0.8, "scale80"],
		[Vector2i(1280, 720), 1.5, "scale150"],
	]
	for layout: Array in cases:
		get_window().size = layout[0]
		session.ui_scale = layout[1]
		ui.call("_rebuild_ui")
		ui.call("_close_panel")
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var bounds := Rect2(Vector2.ZERO, (main as Control).size)
		var pig := main.get_node("Pig") as PigVisual
		_expect_true(_rect_inside(bounds, pig.get_global_rect()), "the continuous character remains inside the real canvas at %s" % layout[2])
		_expect_true(pig.visible and is_instance_valid(pig.get("_body_motion")), "the continuous body renderer remains present at %s" % layout[2])
		if not output.is_empty():
			get_window().get_texture().get_image().save_png(output.path_join("layout-%s.png" % layout[2]))
	var stage := EventStage.new()
	stage.size = Vector2(640, 245)
	main.add_child(stage)
	stage.set_process(false)
	stage.set_step({}, {"animation":"sleep"})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var actor: PigVisual = stage.get("_pig") as PigVisual
	_expect_true(actor != null and not actor.is_processing(), "the event stage owns a continuous pig driven by the stage clock")
	var phase: float = float(actor.get("_pose_time"))
	await get_tree().process_frame
	_expect_eq(actor.get("_pose_time"), phase, "a frozen event stage also freezes its child actor for photo capture")
	stage.call("_process", 0.05)
	_expect_true(float(actor.get("_pose_time")) > phase, "the event stage advances its shared character continuously")
	stage.queue_free()
	main.queue_free()
	await get_tree().process_frame
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("PASS: %d continuity UI assertions" % _assertions)
	get_tree().quit(0 if _failures.is_empty() else 1)
