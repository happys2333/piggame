class_name RoomInteractionController
extends Node

var stage: PigItemStage
var _pig: PigVisual
var _room: RoomVisual
var _behavior: Dictionary = {}
var _layout: Dictionary = {}
var _start_contact := Vector2.ZERO
var _target_contact := Vector2.ZERO
var _contact := Vector2.ZERO
var _start_scale: float = 1.0
var _target_scale: float = 1.0
var _elapsed: float = 0.0
var _duration: float = 0.0
var _phase: float = 0.0
var _arrived: bool = false
var _desktop: bool = false
var _bounds := Rect2()
var _actor_scale: float = 1.0
var _canvas_size := Vector2.ZERO
var _placement_state: Dictionary = {}


func configure(pig: PigVisual, room: RoomVisual) -> void:
	_pig = pig
	_room = room
	stage = PigItemStage.new()
	stage.name = "PigItemStage"
	pig.get_parent().add_child(stage)
	pig.get_parent().move_child(stage, pig.get_index())
	room.item_stage = stage
	stage.furniture_pressed.connect(room.furniture_pressed.emit)
	_placement_state = GameSession.pig_state.placed_furniture.duplicate()
	GameSession.state_changed.connect(_refresh_layout)


func present(behavior: Dictionary) -> void:
	_behavior = behavior.duplicate(true)
	if GameSession.desktop_mode != _desktop:
		return
	_plan()


func enter_desktop(bounds: Rect2, actor_scale: float) -> void:
	_desktop = true
	_bounds = bounds
	_actor_scale = actor_scale
	_duration = 0.0
	_layout = {}
	stage.clear_interaction()
	_pig.set_item_interaction_active(false)
	_pig.set_room_grounded(false)


func resize_desktop(bounds: Rect2, actor_scale: float) -> void:
	_bounds = bounds
	_actor_scale = actor_scale
	if not _layout.is_empty():
		_plan()


func resume() -> void:
	_desktop = false
	_actor_scale = 1.0
	stage.clear_interaction()
	_pig.set_item_interaction_active(false)
	_pig.set_room_grounded(true)
	_behavior = GameSession.current_behavior_snapshot()
	_layout = {}
	_duration = 0.0
	_canvas_size = (_pig.get_parent() as Control).size
	if not str(_behavior.get("required_furniture", "")) in GameSession.pig_state.placed_furniture.values():
		return
	_plan()


func _refresh_layout() -> void:
	if _placement_state == GameSession.pig_state.placed_furniture:
		return
	_placement_state = GameSession.pig_state.placed_furniture.duplicate()
	if GameSession.desktop_mode == _desktop:
		_plan()


func _plan() -> void:
	_canvas_size = (_pig.get_parent() as Control).size
	if not _desktop:
		_bounds = Rect2(_canvas_size * Vector2(0.20, 0.30), _canvas_size * Vector2(0.60, 0.51))
	_layout = stage.layout_for(_behavior, _pig, _bounds, _actor_scale)
	stage.present_layout(_layout)
	_phase = 0.0
	_arrived = false
	_start_contact = _pig.position + _pig.visible_ground_position() * _pig.scale.x
	_start_scale = _pig.scale.x
	_contact = _start_contact
	_target_scale = float(_layout.get("pig_scale", _actor_scale))
	_target_contact = _canvas_size * Vector2(0.5, 0.74) if _layout.is_empty() else _layout.ground as Vector2
	_pig.set_item_interaction_active(not _layout.is_empty())
	_pig.set_room_grounded(not _desktop or not _layout.is_empty())
	if _desktop and _layout.is_empty():
		_duration = 0.0
		_pig.present_room_behavior(_behavior)
		return
	var distance: float = _start_contact.distance_to(_target_contact)
	_duration = clampf(distance / 160.0, 0.35, 4.2)
	_elapsed = 0.0
	_pig.set_locomotion_direction(_target_contact.x - _start_contact.x if distance > 28.0 else -1.0)
	_pig.present_room_behavior({"animation":"walk"} if not _layout.is_empty() and distance > 28.0 and not GameSession.reduce_motion else _behavior)
	if GameSession.reduce_motion:
		_elapsed = _duration
		_contact = _target_contact
		_pig.scale = Vector2.ONE * _target_scale
		_arrive()
		_place()


func _process(delta: float) -> void:
	if not is_instance_valid(_pig) or not _pig.is_processing():
		return
	if _desktop and not _pig.desktop_motion_allowed():
		return
	advance(delta)


func advance(delta: float) -> void:
	if not is_instance_valid(_pig) or GameSession.desktop_mode != _desktop or (not _desktop and not _room.visible):
		return
	if _desktop and not _pig.desktop_motion_allowed():
		return
	if _duration <= 0.0 or _pig.is_dragging():
		return
	if not _desktop and not (_pig.get_parent() as Control).size.is_equal_approx(_canvas_size):
		_plan()
	_elapsed = minf(_elapsed + minf(delta, 0.1), _duration)
	var progress: float = _elapsed / _duration
	var eased: float = progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
	_contact = _start_contact.lerp(_target_contact, eased)
	_pig.scale = Vector2.ONE * lerpf(_start_scale, _target_scale, eased)
	if _elapsed >= _duration and not _arrived:
		_arrive()
	if _arrived and not _layout.is_empty() and not GameSession.reduce_motion:
		_phase += minf(delta, 0.1)
		_contact += stage.update_interaction(_phase)
	_place()


func _arrive() -> void:
	_arrived = true
	_pig.set_locomotion_direction(-1.0)
	_pig.present_room_behavior(_behavior, str(_layout.get("body_id", "")))


func _place() -> void:
	_pig.position = _contact - _pig.visible_ground_position() * _pig.scale.x


func snapshot() -> Dictionary:
	return {"furniture_id":_layout.get("furniture_id", ""), "slot_id":_layout.get("slot_id", ""), "arrived":_arrived, "contact":_contact, "target_contact":_target_contact, "pig_scale":_target_scale, "desktop":_desktop, "bounds":_bounds}
