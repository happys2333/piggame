extends Control

@onready var room: RoomVisual = $Room
@onready var pig: PigVisual = $Pig
@onready var ui: MainUI = $UILayer/MainUI

var _desktop_controller: DesktopWindowController
var _screenshot_in_progress: bool = false


func _ready() -> void:
	Engine.max_fps = 60
	_desktop_controller = DesktopWindowController.new()
	add_child(_desktop_controller)
	pig.pressed.connect(_on_pig_pressed)
	pig.drag_finished.connect(_on_pig_drag_finished)
	room.furniture_pressed.connect(ui.open_furniture_detail)
	ui.desktop_requested.connect(_enter_desktop_mode)
	ui.screenshot_requested.connect(_take_screenshot)
	GameSession.behavior_changed.connect(_on_behavior_changed)
	GameSession.state_changed.connect(_refresh_pig)
	GameSession.pig_performance_changed.connect(_refresh_performance)
	GameSession.desktop_companion_changed.connect(_refresh_performance)
	GameSession.mode_changed.connect(func(_desktop: bool) -> void: _refresh_pig())
	GameSession.exit_checkpoint_failed.connect(_on_exit_checkpoint_failed)
	_refresh_pig()
	if GameSession.desktop_mode:
		if GameSession.pig_state.familiarity_level >= 2:
			call_deferred("_enter_desktop_mode")
		else:
			GameSession.set_desktop_mode(false)
	else:
		GameSession.apply_main_window_settings()


func _refresh_pig() -> void:
	var outfit: Dictionary = GameSession.catalog.get_item("outfits", GameSession.pig_state.current_outfit)
	pig.set_outfit(outfit)
	var expression: Dictionary = GameSession.catalog.get_item("expressions", GameSession.pig_state.favorite_desktop_expression)
	var expression_index: int = GameSession.catalog.expressions.find(expression) if not expression.is_empty() else 0
	pig.set_favorite_expression(
		str(expression.get("id", "")),
		str(expression.get("category", "happy")),
		maxi(expression_index, 0) % 8
	)
	_refresh_performance()


func _refresh_performance() -> void:
	var snapshot: Dictionary = GameSession.pig_performance.snapshot(GameSession.catalog.performances)
	if GameSession.desktop_companion.message_allowed() and (pig.is_processing() or bool(snapshot.get("manual", false))):
		pig.set_performance(snapshot)


func _on_behavior_changed(behavior: Dictionary) -> void:
	if is_instance_valid(_desktop_controller) and _desktop_controller.active:
		_desktop_controller.present_behavior(behavior)
	else:
		pig.set_behavior(behavior)


func _on_pig_pressed(kind: String) -> void:
	var reaction: Dictionary = GameSession.interact_with_pig(kind)
	if reaction.is_empty():
		return
	pig.show_reaction(
		str(reaction.get("category", "happy")),
		str(reaction.get("expression_id", "expr_happy_soft"))
	)


func _enter_desktop_mode() -> void:
	if GameSession.pig_state.familiarity_level < 2:
		return
	_desktop_controller.enter(pig, room, ui)



func _on_pig_drag_finished(_position: Vector2, origin: Vector2) -> void:
	var pig_center_in_room: Vector2 = room.get_global_transform().affine_inverse() * (pig.get_global_transform() * (pig.size * 0.5))
	var furniture_id: String = room.furniture_at_position(pig_center_in_room)
	if not furniture_id.is_empty() and GameSession.invite_to_furniture(furniture_id):
		return
	pig.position = origin
	GameSession.notify_pig_placed()


func _take_screenshot() -> void:
	if _screenshot_in_progress:
		return
	_screenshot_in_progress = true
	var ui_was_visible: bool = ui.visible
	ui.visible = false
	var controls_were_visible: bool = _desktop_controller.set_screenshot_controls_visible(false)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	GameSession.save_manual_screenshot(image)
	ui.visible = ui_was_visible
	_desktop_controller.set_screenshot_controls_visible(controls_were_visible)
	_screenshot_in_progress = false


func _on_exit_checkpoint_failed(_result: Dictionary) -> void:
	if is_instance_valid(_desktop_controller) and _desktop_controller.active:
		_desktop_controller.leave()
	ui.show_exit_save_failure()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if is_instance_valid(_desktop_controller) and _desktop_controller.active:
		GameSession.request_exit()
	else:
		ui.show_exit_choice()
