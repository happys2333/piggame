extends Node

const DragSpy = preload("res://tests/desktop_drag_spy.gd")

var _failures: Array[String] = []
var _assertions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for server: String in ["Windows", "macOS", "X11", "Wayland", "headless"]:
		for active: bool in [false, true]:
			for pig_only: bool in [false, true]:
				for capability: bool in [false, true]:
					var controller := DragSpy.new()
					var pig := PigVisual.new()
					controller.active = active
					controller.pig_only_mode = pig_only
					controller.set("_pig", pig)
					var platform: Dictionary = DesktopPlatformPolicy.resolve(server, true, capability, true, pig_only)
					controller.set("_platform", platform)
					pig.desktop_drag_requested.connect(controller._begin_window_drag)
					pig.desktop_drag_requested.emit()
					var expected: int = 1 if active and bool(platform.window_drag) else 0
					_expect(controller.native_drag_calls + controller.manual_drag_calls == expected, "%s active=%s pig_only=%s native=%s routes desktop drag" % [server, active, pig_only, capability])
					controller.free()
					pig.free()
	var previous_mode: bool = GameSession.desktop_mode
	GameSession.desktop_mode = true
	for touch: bool in [false, true]:
		var controller := DragSpy.new()
		var pig := PigVisual.new()
		add_child(pig)
		pig.dragging_enabled = false
		controller.active = true
		controller.pig_only_mode = false
		controller.set("_pig", pig)
		controller.set("_platform", DesktopPlatformPolicy.resolve("macOS", true, true, true, false))
		pig.desktop_drag_requested.connect(controller._begin_window_drag)
		pig.desktop_drag_motion.connect(controller._move_window_drag)
		pig.desktop_drag_ended.connect(controller._end_window_drag)
		var interactions: Array[String] = []
		pig.pressed.connect(func(kind: String) -> void: interactions.append(kind))
		if touch:
			var press := InputEventScreenTouch.new()
			press.index = 2
			press.pressed = true
			press.position = Vector2(160, 150)
			pig._gui_input(press)
			var motion := InputEventScreenDrag.new()
			motion.index = 2
			motion.position = Vector2(180, 150)
			motion.relative = Vector2(20, 0)
			pig._gui_input(motion)
			press.pressed = false
			press.position = motion.position
			pig._gui_input(press)
		else:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = Vector2(160, 150)
			press.global_position = press.position
			pig._gui_input(press)
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(180, 150)
			motion.global_position = motion.position
			motion.relative = Vector2(20, 0)
			pig._gui_input(motion)
			press.pressed = false
			press.position = motion.position
			press.global_position = motion.global_position
			pig._gui_input(press)
		_expect(controller.manual_drag_calls == 1 and controller.native_drag_calls == 0 and controller.drag_delta == Vector2(20, 0), "real pig gesture reaches one positioned host-window drag touch=" + str(touch))
		_expect(interactions.is_empty() and not pig.is_dragging(), "drag release is not a pet/poke and leaves no held gesture")
		controller.free()
		pig.free()
	_test_mouse_drag_deltas()
	for touch: bool in [false, true]:
		_test_drag_cancel(touch)
	GameSession.desktop_mode = previous_mode
	for focused: bool in [false, true]:
		for no_disturb: bool in [false, true]:
			var policy := DesktopCompanionPolicy.new()
			policy.load_settings({"desktop_do_not_disturb":no_disturb})
			policy.set_application_focused(focused)
			_expect(policy.effective_always_on_top(true) == (focused and not no_disturb), "strict focus-only stacking remains " + str([focused, no_disturb]))
			_expect(not policy.effective_always_on_top(false), "disabled top preference remains off")
	for failure: String in _failures:
		printerr(failure)
	print("DESKTOP_DRAG_RULES: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_mouse_drag_deltas() -> void:
	for source: String in ["screen", "relative", "position"]:
		var controller := DragSpy.new()
		var pig := PigVisual.new()
		add_child(pig)
		pig.scale = Vector2.ONE * 2.0
		pig.dragging_enabled = false
		controller.active = true
		controller.set("_pig", pig)
		controller.set("_platform", DesktopPlatformPolicy.resolve("macOS", true, true, true, false))
		pig.desktop_drag_requested.connect(controller._begin_window_drag)
		pig.desktop_drag_motion.connect(controller._move_window_drag)
		pig.desktop_drag_ended.connect(controller._end_window_drag)
		var interactions: Array[String] = []
		var ends: Array[bool] = []
		pig.pressed.connect(func(kind: String) -> void: interactions.append(kind))
		pig.desktop_drag_ended.connect(func(canceled: bool) -> void: ends.append(canceled))
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(160, 150)
		press.global_position = press.position * 2.0
		pig._gui_input(press)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(162, 150)
		motion.global_position = motion.position * 2.0
		motion.relative = Vector2(91 if source == "screen" else 2 if source == "relative" else 0, 0)
		motion.screen_relative = Vector2(4, 0) if source == "screen" else Vector2.ZERO
		pig._gui_input(motion)
		_expect(controller.manual_drag_calls == 0 and pig.is_dragging(), source + " waits below the drag threshold")
		motion.position.x += 2.0
		motion.global_position = motion.position * 2.0
		pig._gui_input(motion)
		_expect(controller.manual_drag_calls == 1 and controller.drag_delta == Vector2(8, 0), source + " preserves pending distance and maps scale once")
		motion.relative = Vector2.ZERO
		motion.screen_relative = Vector2(6, 0)
		pig._gui_input(motion)
		_expect(controller.drag_delta == Vector2(14, 0), source + " continues with a stable window-local pointer")
		controller._move_window_drag(Vector2(INF, 0))
		_expect(controller.drag_delta == Vector2(14, 0), source + " rejects nonfinite motion")
		press.pressed = false
		press.position = motion.position
		press.global_position = motion.global_position
		pig._gui_input(press)
		_expect(ends == [false] and interactions.is_empty() and not pig.is_dragging(), source + " releases without petting")
		pig._gui_input(motion)
		_expect(controller.drag_delta == Vector2(14, 0) and controller.manual_drag_calls == 1, source + " ignores late motion")
		press.pressed = true
		pig._gui_input(press)
		press.pressed = false
		pig._gui_input(press)
		_expect(interactions.size() == 1, source + " permits the next independent click")
		controller.free()
		pig.free()


func _test_drag_cancel(touch: bool) -> void:
	for cancel_source: String in ["pointer", "focus"]:
		var controller := DragSpy.new()
		var pig := PigVisual.new()
		add_child(pig)
		pig.dragging_enabled = false
		controller.active = true
		controller.set("_pig", pig)
		controller.set("_platform", DesktopPlatformPolicy.resolve("Windows", true, true, true, true))
		pig.desktop_drag_requested.connect(controller._begin_window_drag)
		pig.desktop_drag_motion.connect(controller._move_window_drag)
		pig.desktop_drag_ended.connect(controller._end_window_drag)
		var ends: Array[bool] = []
		var interactions: Array[String] = []
		pig.desktop_drag_ended.connect(func(canceled: bool) -> void: ends.append(canceled))
		pig.pressed.connect(func(kind: String) -> void: interactions.append(kind))
		var press: InputEvent
		var motion: InputEvent
		if touch:
			var touch_press := InputEventScreenTouch.new()
			touch_press.index = 2
			touch_press.pressed = true
			touch_press.position = Vector2(160, 150)
			press = touch_press
			var touch_motion := InputEventScreenDrag.new()
			touch_motion.index = 2
			touch_motion.position = Vector2(180, 150)
			touch_motion.relative = Vector2(20, 0)
			motion = touch_motion
		else:
			var mouse_press := InputEventMouseButton.new()
			mouse_press.button_index = MOUSE_BUTTON_LEFT
			mouse_press.pressed = true
			mouse_press.position = Vector2(160, 150)
			mouse_press.global_position = mouse_press.position
			press = mouse_press
			var mouse_motion := InputEventMouseMotion.new()
			mouse_motion.position = Vector2(180, 150)
			mouse_motion.global_position = mouse_motion.position
			mouse_motion.relative = Vector2(20, 0)
			motion = mouse_motion
		pig._gui_input(press)
		pig._gui_input(motion)
		_expect(pig.desktop_drag_uses_touch() == touch and controller.drag_delta == Vector2(20, 0), "active gesture identifies its own input source")
		if cancel_source == "focus":
			pig.get_window().focus_exited.emit()
		else:
			press.set("canceled", true)
			pig._gui_input(press)
		_expect(ends == [true] and not pig.is_dragging() and not controller.get("_manual_window_dragging"), cancel_source + " cancels both pig and host drag")
		pig._gui_input(motion)
		press.set("pressed", false)
		press.set("canceled", false)
		pig._gui_input(press)
		_expect(controller.drag_delta == Vector2(20, 0) and interactions.is_empty() and ends.size() == 1, cancel_source + " ignores late release/motion without petting")
		controller.free()
		pig.free()


func _expect(value: bool, description: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(description)
