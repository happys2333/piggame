extends "res://tests/ui_smoke.gd"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/validation/ui"))
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = main.get_node("UILayer/MainUI")
	var session: Node = get_tree().root.get_node("GameSession")
	var skip: Button = ui.find_child("NameSkipTutorialButton", true, false) as Button
	var personality := ui.find_child("NamePersonalityChoice", true, false) as OptionButton
	if personality != null:
		personality.select(1)
	if skip != null:
		skip.pressed.emit()
	await get_tree().process_frame
	for frame_index: int in 4:
		await _test_desktop_pig_scale_roundtrip(main, session, ui, frame_index)
	await _test_event_photo_capture_isolation(main, session, ui)
	if _failures.is_empty():
		print("PASS: %d generated art regression assertions" % _assertions)
		get_tree().quit(0)
	else:
		print("FAIL: %d of %d generated art regression assertions failed" % [_failures.size(), _assertions])
		for failure: String in _failures:
			print("- %s" % failure)
		get_tree().quit(1)
