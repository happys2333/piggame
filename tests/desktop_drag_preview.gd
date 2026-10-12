extends Node

const MainScene = preload("res://game/scenes/main.tscn")

var _output: String
var _controller: DesktopWindowController
var _pig: PigVisual
var _elapsed: float = 0.0
var _requests: int = 0
var _before: Dictionary
var _initial_position: Vector2i
var _motions: Array[Vector2] = []
var _ends: Array[bool] = []


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_output = OS.get_environment("PIGGAME_DRAG_PROBE_DIR")
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if _output.is_empty() or expected.is_empty() or not OS.get_user_data_dir().ends_with(expected):
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.set_pig_name("拖拖猪 QA")
	GameSession.skip_tutorial()
	GameSession.pig_state.familiarity_level = 2
	GameSession.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[1]
	GameSession.save_game()
	GameSession.desktop_companion.load_settings({"desktop_behavior_frequency":"off"})
	GameSession.set_reduce_motion(true)
	var main: Control = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_controller = main.get("_desktop_controller") as DesktopWindowController
	_pig = main.get_node("Pig") as PigVisual
	_controller.enter(_pig, main.get_node("Room"), main.get_node("UILayer/MainUI"))
	_controller.transparent_mode = true
	_controller.always_on_top = true
	_controller.call("_apply_window_mode")
	get_window().title = "Piggame Drag QA — isolated save"
	DisplayServer.window_set_position(Vector2i(650, 240))
	_initial_position = DisplayServer.window_get_position()
	_pig.desktop_drag_requested.connect(func() -> void: _requests += 1)
	_pig.desktop_drag_motion.connect(func(relative: Vector2) -> void: _motions.append(relative))
	_pig.desktop_drag_ended.connect(func(canceled: bool) -> void: _ends.append(canceled))
	_before = GameSession.pig_state.to_dict().duplicate(true)
	_record()
	print("DRAG_QA_READY " + _output)


func _process(delta: float) -> void:
	if _before.is_empty():
		return
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_record()


func _record() -> void:
	var position: Vector2i = DisplayServer.window_get_position()
	var report: Dictionary = {
		"server":DisplayServer.get_name(),
		"window_position":[position.x, position.y],
		"initial_position":[_initial_position.x, _initial_position.y],
		"window_focused":get_window().has_focus(),
		"policy_focused":GameSession.desktop_companion.application_focused,
		"native_on_top":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
		"expected_on_top":_controller.effective_always_on_top(),
		"drag_requests":_requests,
		"drag_motions":str(_motions),
		"drag_ends":_ends,
		"pig_only":_controller.pig_only_mode,
		"platform":_controller.get("_platform"),
		"state_unchanged":GameSession.pig_state.to_dict() == _before,
		"isolated_save":OS.get_user_data_dir(),
		"pig_rect":str(_pig.get_global_rect()),
		"menu_visible":is_instance_valid(_controller.get("_context_popup")) and bool(_controller.get("_context_popup").visible),
	}
	var file := FileAccess.open(_output.path_join("live.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
