extends "res://tests/ui_smoke.gd"


func _run() -> void:
	var main: Node = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui: Control = main.get_node("UILayer/MainUI")
	var session: Node = get_tree().root.get_node("GameSession")
	var skip := ui.find_child("NameSkipTutorialButton", true, false) as Button
	var personality := ui.find_child("NamePersonalityChoice", true, false) as OptionButton
	if personality != null:
		personality.select(1)
	if skip != null:
		skip.pressed.emit()
	await _test_desktop_companion_protection(main, session, ui)
	main.queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: %d companion protection UI assertions" % _assertions)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			printerr("- %s" % failure)
		get_tree().quit(1)
