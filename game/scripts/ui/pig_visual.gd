class_name PigVisual
extends AssetCanvas

signal pressed(kind: String)
signal drag_finished(position: Vector2, origin: Vector2)
signal desktop_context_requested(local_position: Vector2)
signal desktop_drag_requested
signal desktop_drag_motion(relative: Vector2)
signal desktop_drag_ended(canceled: bool)

const FRAME_STEP: float = VisualFramePolicy.FRAME_STEP
const REACTION_CATEGORIES: Array[String] = ["happy", "sleepy", "hungry", "wronged", "proud", "shocked"]

var behavior_animation: String = "idle"
var outfit: Dictionary = {}
var expression_category: String = "happy"
var favorite_expression_category: String = "happy"
var favorite_expression_id: String = ""
var favorite_expression_variant_index: int = 0
var dragging_enabled: bool = true:
	set(value):
		if dragging_enabled == value:
			return
		_cancel_gesture()
		dragging_enabled = value
var _frame_time: float = 0.0
var _phase: float = 0.0
var _pose_time: float = 0.0
var _dragging: bool = false
var _active_touch_index: int = -1
var _touch_travel_distance: float = 0.0
var _mouse_max_distance: float = 0.0
var _desktop_window_dragging: bool = false
var _desktop_pending_motion := Vector2.ZERO
var _last_pointer_position := Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _start_position: Vector2 = Vector2.ZERO
var _reaction_category: String = ""
var _reaction_expression_id: String = ""
var _reaction_seconds: float = 0.0
var _performance: Dictionary = {}
var _motion := PigMotionPlayer.new()
var _body_motion: PigBodyMotion
var _has_drawn: bool = false
var _room_body_override: String = ""
var _item_interaction_active: bool = false
var _explicit_item_until: int = 0
const MAX_DRAG_DISTANCE: float = 180.0


func _ready() -> void:
	custom_minimum_size = Vector2(280, 230)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_window().focus_exited.connect(_cancel_gesture)
	_body_motion = PigBodyMotion.new()
	_body_motion.player = _motion
	add_child(_body_motion)
	_request_motion()
	set_process(true)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_cancel_gesture()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_gesture()


func _cancel_gesture() -> void:
	if _desktop_window_dragging:
		_desktop_window_dragging = false
		desktop_drag_ended.emit(true)
	if _dragging and dragging_enabled:
		position = _start_position
	_dragging = false
	_active_touch_index = -1
	_touch_travel_distance = 0.0
	_mouse_max_distance = 0.0
	_desktop_pending_motion = Vector2.ZERO
	_last_pointer_position = Vector2.ZERO
	_press_position = Vector2.ZERO
	_start_position = Vector2.ZERO


func cancel_desktop_drag() -> void:
	_cancel_gesture()


func desktop_drag_uses_touch() -> bool:
	return _active_touch_index >= 0


func _process(delta: float) -> void:
	if _reaction_seconds > 0.0:
		_reaction_seconds = maxf(_reaction_seconds - delta, 0.0)
		if _reaction_seconds <= 0.0:
			_reaction_category = ""
			_reaction_expression_id = ""
			_request_motion(GameSession.desktop_mode and not GameSession.desktop_companion.autonomous_motion_allowed())
			queue_redraw()
	if not is_visible_in_tree() or GameSession.reduce_motion:
		return
	if not _performance.is_empty() and not _item_interaction_active and not GameSession.performance_motion_allowed():
		return
	if (_performance.is_empty() or _item_interaction_active) and GameSession.desktop_mode and not desktop_motion_allowed():
		return
	if _dragging:
		return
	_motion.advance(delta)
	_pose_time = _motion.clock
	_phase = _motion.clock
	_frame_time += minf(delta, 0.1)
	var step: float = VisualFramePolicy.DESKTOP_POSE_FRAME_STEP if GameSession.desktop_mode else VisualFramePolicy.POSE_FRAME_STEP
	if _motion.transitioning() or _motion.profile().w > 0.0:
		step = VisualFramePolicy.DESKTOP_TRANSITION_FRAME_STEP if GameSession.desktop_mode else VisualFramePolicy.TRANSITION_FRAME_STEP
	if _frame_time < step:
		return
	_frame_time = fmod(_frame_time, step)
	queue_redraw()


func set_behavior(behavior: Dictionary) -> void:
	var next_animation: String = str(behavior.get("animation", "idle"))
	if behavior_animation == next_animation:
		return
	behavior_animation = next_animation
	if behavior_animation in ["sleep", "bed_nap", "window_nap", "lie", "pillow_flop", "blanket_roll"]:
		expression_category = "sleepy"
	elif behavior_animation in ["fridge", "table_snack", "sniff", "cookie_guard", "drink", "tea"]:
		expression_category = "hungry"
	elif behavior_animation in ["run", "yoga", "mirror_pose", "paint", "drum", "camera", "robot_ride"]:
		expression_category = "proud"
	elif behavior_animation in ["alarm", "scratch"]:
		expression_category = "wronged"
	elif behavior_animation in ["telescope", "weather", "wind_chime", "puzzle", "castle"]:
		expression_category = "shocked"
	else:
		expression_category = favorite_expression_category if _favorite_expression_active() else "happy"
	_request_motion()
	queue_redraw()


func set_outfit(data: Dictionary) -> void:
	if outfit == data:
		return
	outfit = data
	_request_motion()
	queue_redraw()


func set_favorite_expression(expression_id: String, category: String, variant_index: int = 0) -> void:
	var normalized_category: String = category if category in REACTION_CATEGORIES else "happy"
	var normalized_variant: int = clampi(variant_index, 0, 7)
	if favorite_expression_id == expression_id and favorite_expression_category == normalized_category and favorite_expression_variant_index == normalized_variant:
		return
	favorite_expression_id = expression_id
	favorite_expression_category = normalized_category
	favorite_expression_variant_index = normalized_variant
	if behavior_animation in ["idle", "sit", "stare"]:
		expression_category = favorite_expression_category if _favorite_expression_active() else "happy"
	_request_motion()
	queue_redraw()


func active_favorite_expression_signature() -> String:
	if not _favorite_expression_active():
		return ""
	return "%s:%s:%d" % [favorite_expression_id, favorite_expression_category, favorite_expression_variant_index]


func show_reaction(category: String, expression_id: String, duration_seconds: float = 0.9) -> void:
	_performance = {}
	_reaction_category = category if category in REACTION_CATEGORIES else "happy"
	_reaction_expression_id = expression_id
	_reaction_seconds = maxf(duration_seconds, 0.1)
	_request_motion(not is_processing() or (GameSession.desktop_mode and not GameSession.desktop_companion.autonomous_motion_allowed()))
	queue_redraw()


func set_performance(value: Dictionary) -> void:
	if _performance == value:
		return
	_performance = value.duplicate(true)
	_request_motion()
	queue_redraw()


func active_performance_signature() -> String:
	return "%s:%s:%s" % [_performance.get("id", ""), _performance.get("body_id", ""), _performance.get("face_id", "")] if not _performance.is_empty() else ""


func active_reaction_signature() -> String:
	if not _reaction_active():
		return ""
	return "%s:%s" % [_reaction_category, _reaction_expression_id]


func interaction_kind_at(local_position: Vector2) -> String:
	if size.x <= 0.0 or size.y <= 0.0:
		return "pet"
	var anchor: Vector2 = visible_snout_position()
	var half_size: Vector2 = size * Vector2(0.11, 0.11)
	return "poke" if Rect2(anchor - half_size, half_size * 2.0).has_point(local_position) else "pet"


func visible_snout_position() -> Vector2:
	if _motion.source.is_empty():
		_request_motion()
	return _motion.pose_transform(size, _motion.weight() >= 0.5) * PigVisualRig.snout_for(str(_motion.selected().body_id), 0)


func set_locomotion_direction(direction: float) -> void:
	_motion.face_direction(direction)


func set_room_grounded(value: bool) -> void:
	_motion.room_grounded = value
	if not value:
		set_room_body_override("")
	queue_redraw()


func set_item_interaction_active(value: bool) -> void:
	if _item_interaction_active == value:
		return
	_item_interaction_active = value
	if not value:
		clear_explicit_item_motion()
	_request_motion()
	queue_redraw()


func allow_explicit_item_motion(seconds: float) -> void:
	_explicit_item_until = Time.get_ticks_msec() + int(clampf(seconds, 1.0, 45.0) * 1000.0)


func clear_explicit_item_motion() -> void:
	_explicit_item_until = 0


func desktop_motion_allowed() -> bool:
	return GameSession.desktop_companion.autonomous_motion_allowed() or (_item_interaction_active and GameSession.desktop_companion.application_focused and Time.get_ticks_msec() < _explicit_item_until)


func set_room_body_override(body_id: String) -> void:
	if _room_body_override == body_id:
		return
	_room_body_override = body_id
	_request_motion()
	queue_redraw()


func present_room_behavior(behavior: Dictionary, body_id: String = "") -> void:
	var previous: String = behavior_animation
	_room_body_override = body_id
	set_behavior(behavior)
	if previous == behavior_animation:
		_request_motion()
		queue_redraw()


func visible_ground_position() -> Vector2:
	if _motion.source.is_empty():
		_request_motion()
	var body_id: String = str(_motion.selected().body_id)
	return _motion.pose_transform(size, _motion.weight() >= 0.5) * Vector2(128, PigVisualRig.ground_for(body_id))


func is_dragging() -> bool:
	return _dragging


func _favorite_expression_active() -> bool:
	return (
		GameSession.desktop_mode
		and behavior_animation in ["idle", "sit", "stare"]
		and not favorite_expression_id.is_empty()
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not event.canceled and GameSession.desktop_mode:
		desktop_context_requested.emit(get_global_transform() * event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.canceled:
			if _dragging and _active_touch_index == -1:
				_cancel_gesture()
			accept_event()
			return
		if event.pressed:
			if _dragging:
				return
			_dragging = true
			_mouse_max_distance = 0.0
			_desktop_pending_motion = Vector2.ZERO
			_press_position = event.global_position
			_last_pointer_position = event.global_position
			_start_position = position
			accept_event()
		elif _dragging and _active_touch_index == -1:
			var moved: float = maxf(_mouse_max_distance, event.global_position.distance_to(_press_position))
			_dragging = false
			if _desktop_window_dragging:
				_desktop_window_dragging = false
				desktop_drag_ended.emit(false)
			elif moved < 8.0:
				pressed.emit(interaction_kind_at(event.position))
			elif dragging_enabled:
					drag_finished.emit(position, _start_position)
			accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _dragging and _active_touch_index == -1:
		_mouse_max_distance = maxf(_mouse_max_distance, event.global_position.distance_to(_press_position))
		var screen_delta: Vector2 = event.screen_relative if not event.screen_relative.is_zero_approx() else get_global_transform().basis_xform(event.relative)
		if screen_delta.is_zero_approx():
			screen_delta = event.global_position - _last_pointer_position
		_last_pointer_position = event.global_position
		if dragging_enabled:
			var desired: Vector2 = _start_position + event.global_position - _press_position
			_apply_drag_position(desired)
		elif GameSession.desktop_mode and _mouse_max_distance >= 8.0:
			_desktop_pending_motion += screen_delta
			_continue_desktop_drag()
		elif GameSession.desktop_mode and not dragging_enabled:
			_desktop_pending_motion += screen_delta
		accept_event()
	elif event is InputEventScreenTouch:
		if event.canceled:
			if _dragging and event.index == _active_touch_index:
				_cancel_gesture()
			accept_event()
			return
		if event.pressed:
			if _dragging:
				return
			_dragging = true
			_active_touch_index = event.index
			_touch_travel_distance = 0.0
			_desktop_pending_motion = Vector2.ZERO
			_press_position = event.position
			_start_position = position
			accept_event()
		elif _dragging and event.index == _active_touch_index:
			_dragging = false
			_active_touch_index = -1
			if _desktop_window_dragging:
				_desktop_window_dragging = false
				desktop_drag_ended.emit(false)
			elif _touch_travel_distance < 8.0:
				pressed.emit(interaction_kind_at(event.position))
			elif dragging_enabled:
				drag_finished.emit(position, _start_position)
			accept_event()
	elif event is InputEventScreenDrag and _dragging and event.index == _active_touch_index:
		_touch_travel_distance += event.relative.length()
		if dragging_enabled:
			_apply_drag_position(position + event.relative)
		elif GameSession.desktop_mode and _touch_travel_distance >= 8.0:
			_desktop_pending_motion += event.screen_relative if not event.screen_relative.is_zero_approx() else get_global_transform().basis_xform(event.relative)
			_continue_desktop_drag()
		elif GameSession.desktop_mode and not dragging_enabled:
			_desktop_pending_motion += event.screen_relative if not event.screen_relative.is_zero_approx() else get_global_transform().basis_xform(event.relative)
		accept_event()


func _continue_desktop_drag() -> void:
	if not _desktop_window_dragging:
		_desktop_window_dragging = true
		desktop_drag_requested.emit()
	if _desktop_window_dragging:
		desktop_drag_motion.emit(_desktop_pending_motion)
	_desktop_pending_motion = Vector2.ZERO


func _apply_drag_position(desired_position: Vector2) -> void:
	var desired: Vector2 = desired_position
	var offset: Vector2 = desired - _start_position
	if offset.length() > MAX_DRAG_DISTANCE:
		desired = _start_position + offset.normalized() * MAX_DRAG_DISTANCE
	var parent_control := get_parent() as Control
	if parent_control != null:
		desired.x = clampf(desired.x, 0.0, maxf(parent_control.size.x - size.x, 0.0))
		desired.y = clampf(desired.y, 100.0, maxf(parent_control.size.y - size.y - 70.0, 100.0))
	position = desired


func _draw() -> void:
	begin_visual_draw()
	if _motion.target.is_empty():
		_request_motion()
	_has_drawn = true
	if _body_motion != null:
		_body_motion.size = size
		_body_motion.refresh()
	var source_texture: Texture2D = retain_visual_texture(GameSession.final_assets.texture_for("performance_body:%s" % str(_motion.source.body_id), 0))
	if source_texture == null:
		PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), str(_motion.target.body_id), str(_motion.target.face_id), 0, outfit)
		return
	if str(_motion.target.body_id) != str(_motion.source.body_id):
		retain_visual_texture(GameSession.final_assets.texture_for("performance_body:%s" % str(_motion.target.body_id), 0))
	if _tutorial_highlight_active():
		draw_arc(size * 0.5, minf(size.x, size.y) * 0.46, 0.0, TAU, 48, Color("#d9a93fcc"), 5.0, true)
	PigVisualRig.draw_motion_details(self, Rect2(Vector2.ZERO, size), _motion)


func _request_motion(immediate: bool = false) -> void:
	var body_id: String = _room_body_override if not _room_body_override.is_empty() else PigVisualRig.body_for(behavior_animation)
	var expression_id: String = _reaction_expression_id if _reaction_active() else favorite_expression_id if _favorite_expression_active() else ""
	var face_id: String = PigVisualRig.face_for(behavior_animation, expression_id)
	if _reaction_active() and expression_id.is_empty():
		face_id = PigVisualRig.category_face(_reaction_category)
	if not _performance.is_empty() and not _item_interaction_active:
		body_id = str(_performance.get("body_id", "body_base"))
		face_id = str(_performance.get("face_id", "face_dot"))
	_motion.present({"body_id":body_id, "face_id":face_id, "outfit":outfit, "animation":behavior_animation if _performance.is_empty() or _item_interaction_active else ""}, immediate or not _has_drawn or GameSession.reduce_motion or not is_visible_in_tree())


func _tutorial_highlight_active() -> bool:
	return not GameSession.pig_state.tutorial_skipped and GameSession.pig_state.tutorial_step == 1


func _performance_frame() -> int:
	return 0


func _reaction_active() -> bool:
	return _reaction_seconds > 0.0 and not _reaction_category.is_empty()
