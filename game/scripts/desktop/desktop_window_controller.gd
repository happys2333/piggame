class_name DesktopWindowController
extends Node

signal returned_to_room
signal hide_requested

const BASE_SIZE: Vector2i = DesktopFramePolicy.CHARACTER_AREA_BASE_SIZE
const MIN_SIZE: Vector2i = DesktopFramePolicy.MIN_COMPANION_WINDOW_SIZE
const MAIN_CONTENT_SIZE := Vector2i(1280, 720)
const MAIN_FPS: int = DesktopFramePolicy.MAIN_FPS

var active: bool = false
var scale_factor: float = 1.0
var dock: String = "bottom"
var desktop_screen: int = -1
var always_on_top: bool = true
var transparent_mode: bool = true
var pig_only_mode: bool = false
var _pig: PigVisual
var _room: RoomVisual
var _ui: MainUI
var _controls_layer: CanvasLayer
var _event_bubble: PanelContainer
var _event_bubble_button: Button
var _paused_animation: bool = false
var _visibility_check_elapsed: float = 0.0
var _frame_limit_check_elapsed: float = 0.0
var _roam_direction: float = 1.0
var _passthrough_dirty: bool = false
var _behavior_hold_elapsed: float = 0.0
var _pending_behavior: Dictionary = {}
var _last_window_size := Vector2i.ZERO
var _room_pig_anchors: Array[float] = []
var _room_pig_offsets: Array[float] = []
var _room_pig_scale := Vector2.ONE
var _context_popup: PopupMenu
var _pig_only_preference: bool = false
var _platform: Dictionary = {}


func _ready() -> void:
	set_process(false)
	get_window().size_changed.connect(_on_window_size_changed)
	GameSession.desktop_companion_changed.connect(_on_companion_policy_changed)
	if not GameSession.memory_queue_changed.is_connected(_on_memory_queue_changed):
		GameSession.memory_queue_changed.connect(_on_memory_queue_changed)


func _process(delta: float) -> void:
	if not active:
		return
	_update_behavior_presentation(delta)
	_update_desktop_roaming(delta)
	_visibility_check_elapsed += delta
	_frame_limit_check_elapsed += delta
	if _frame_limit_check_elapsed >= 0.25:
		_frame_limit_check_elapsed = 0.0
		_refresh_frame_limit()
		if _passthrough_dirty and bool(_platform.get("transparency", false)):
			_update_passthrough(_last_window_size)
	if _visibility_check_elapsed >= 1.0:
		_visibility_check_elapsed = 0.0
		_ensure_visible()


func _on_window_size_changed() -> void:
	if not active:
		return
	_last_window_size = get_window().size
	get_window().content_scale_size = _last_window_size
	_layout_controls(_last_window_size)
	_passthrough_dirty = true


func enter(pig: PigVisual, room: RoomVisual, ui: MainUI) -> void:
	if active:
		return
	if not GameSession.set_desktop_mode(true):
		return
	active = true
	set_process(true)
	_pig = pig
	if not _pig.desktop_context_requested.is_connected(_show_pig_context_menu):
		_pig.desktop_context_requested.connect(_show_pig_context_menu)
	if not _pig.desktop_drag_requested.is_connected(_begin_window_drag):
		_pig.desktop_drag_requested.connect(_begin_window_drag)
	_room = room
	_ui = ui
	_paused_animation = false
	_pig.set_process(true)
	_load_settings()
	_room.visible = false
	_ui.visible = false
	_pig.dragging_enabled = false
	_room_pig_anchors = [_pig.anchor_left, _pig.anchor_top, _pig.anchor_right, _pig.anchor_bottom]
	_room_pig_offsets = [_pig.offset_left, _pig.offset_top, _pig.offset_right, _pig.offset_bottom]
	_room_pig_scale = _pig.scale
	_pig.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_behavior_hold_elapsed = DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS
	_pending_behavior.clear()
	present_behavior(GameSession.current_behavior_snapshot())
	_apply_window_mode()
	_build_controls()
	_refresh_frame_limit(true)


func leave() -> void:
	if not active:
		return
	_save_settings()
	active = false
	set_process(false)
	_paused_animation = false
	_pig.set_process(true)
	GameSession.set_desktop_mode(false)
	Engine.max_fps = MAIN_FPS
	_clear_passthrough()
	if bool(_platform.get("positioning", false)):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	get_window().transparent_bg = false
	get_window().content_scale_size = MAIN_CONTENT_SIZE
	GameSession.apply_main_window_settings()
	_room.visible = true
	_ui.visible = true
	_pig.dragging_enabled = true
	for side: int in 4:
		_pig.set_anchor(side, _room_pig_anchors[side], false)
	for side: int in 4:
		_pig.set_offset(side, _room_pig_offsets[side])
	_pig.scale = _room_pig_scale
	_room_pig_anchors.clear()
	_room_pig_offsets.clear()
	_pending_behavior.clear()
	_behavior_hold_elapsed = 0.0
	_pig.set_behavior(GameSession.current_behavior_snapshot())
	if is_instance_valid(_controls_layer):
		_controls_layer.queue_free()
	if is_instance_valid(_context_popup):
		_context_popup.queue_free()
	_context_popup = null
	_event_bubble = null
	_event_bubble_button = null
	_roam_direction = 1.0
	_passthrough_dirty = false
	_last_window_size = Vector2i.ZERO
	returned_to_room.emit()


func set_screenshot_controls_visible(value: bool) -> bool:
	if not is_instance_valid(_controls_layer):
		return false
	var previous: bool = _controls_layer.visible
	_controls_layer.visible = value and not pig_only_mode
	return previous


func _apply_window_mode() -> void:
	_platform = DesktopPlatformPolicy.detect(transparent_mode, _pig_only_preference)
	var use_transparency: bool = bool(_platform.transparency)
	pig_only_mode = bool(_platform.pig_only)
	var minimum_size: Vector2i = DesktopFramePolicy.minimum_companion_window_size(scale_factor, pig_only_mode)
	get_window().min_size = minimum_size
	DisplayServer.window_set_min_size(minimum_size)
	get_window().transparent_bg = use_transparency
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, use_transparency)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, use_transparency)
	if bool(_platform.positioning):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, effective_always_on_top())
	var requested_window_size: Vector2i = DesktopFramePolicy.companion_window_size(scale_factor, pig_only_mode)
	DisplayServer.window_set_size(requested_window_size)
	var window_size: Vector2i = DisplayServer.window_get_size()
	_last_window_size = window_size
	get_window().content_scale_size = window_size
	_dock_window(window_size)
	_pig.size = Vector2(DesktopFramePolicy.CHARACTER_BASE_SIZE)
	_pig.scale = Vector2.ONE * scale_factor
	var visual_size: Vector2 = _pig.get_global_rect().size
	_layout_controls(window_size)
	var roam_bounds: Vector2 = DesktopFramePolicy.roaming_bounds(DesktopFramePolicy.character_area_width(float(window_size.x), pig_only_mode), visual_size.x, GameSession.desktop_roaming_reduced())
	_pig.position = Vector2(clampf(24.0 * scale_factor, roam_bounds.x, roam_bounds.y), window_size.y - visual_size.y - 8)
	if is_instance_valid(_controls_layer):
		_controls_layer.visible = not pig_only_mode
	if use_transparency:
		_update_passthrough(window_size)
	else:
		_clear_passthrough()
	_update_event_bubble()


func _clear_passthrough() -> void:
	if bool(_platform.get("positioning", false)):
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())


func _dock_window(window_size: Vector2i) -> void:
	if not bool(_platform.get("positioning", false)):
		return
	var screen_count: int = DisplayServer.get_screen_count()
	desktop_screen = DesktopFramePolicy.resolve_screen(
		desktop_screen,
		DisplayServer.window_get_current_screen(),
		DisplayServer.get_primary_screen(),
		screen_count
	)
	if desktop_screen < 0:
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(desktop_screen)
	DisplayServer.window_set_position(DesktopFramePolicy.docked_window_position(window_size, usable, dock))


func _update_passthrough(window_size: Vector2i) -> PackedVector2Array:
	var pig_rect: Rect2 = _pig.get_global_rect()
	var show_bubble: bool = is_instance_valid(_event_bubble) and _event_bubble.visible and not pig_only_mode
	# DisplayServer accepts one polygon, so disjoint hit regions are joined by
	# a four-pixel corridor. Geometry2D keeps the result simple and prevents a
	# self-intersection from swallowing a large transparent desktop area.
	var points: PackedVector2Array = DesktopFramePolicy.mouse_passthrough_polygon(pig_rect, window_size, show_bubble, pig_only_mode)
	if bool(_platform.get("transparency", false)):
		DisplayServer.window_set_mouse_passthrough(points)
	_passthrough_dirty = false
	return points


func _update_desktop_roaming(delta: float) -> void:
	if not is_instance_valid(_pig) or not GameSession.desktop_companion.autonomous_motion_allowed():
		return
	var reduced_roaming: bool = GameSession.desktop_roaming_reduced()
	var bounds: Vector2 = DesktopFramePolicy.roaming_bounds(DesktopFramePolicy.character_area_width(float(_last_window_size.x), pig_only_mode), _pig.get_global_rect().size.x, reduced_roaming)
	var previous_x: float = _pig.position.x
	if _pig.behavior_animation == "walk" and not _paused_animation:
		var step: Vector2 = DesktopFramePolicy.advance_roaming_x(
			previous_x,
			_roam_direction,
			delta,
			bounds,
			DesktopFramePolicy.roaming_speed(scale_factor, reduced_roaming)
		)
		_pig.position.x = step.x
		_roam_direction = step.y
	else:
		_pig.position.x = clampf(previous_x, bounds.x, bounds.y)
	if not is_equal_approx(previous_x, _pig.position.x):
		_passthrough_dirty = true


func _build_controls() -> void:
	_controls_layer = CanvasLayer.new()
	_controls_layer.layer = 100
	_controls_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_controls_layer)
	var panel := PanelContainer.new()
	panel.theme = ThemeFactory.create(0.8)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-DesktopFramePolicy.CONTROL_BAR_SIZE.x - DesktopFramePolicy.DESKTOP_CONTROL_MARGIN, DesktopFramePolicy.DESKTOP_CONTROL_MARGIN)
	panel.size = Vector2(DesktopFramePolicy.CONTROL_BAR_SIZE)
	_controls_layer.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var room_button := Button.new()
	room_button.text = tr("DESKTOP_ROOM")
	room_button.tooltip_text = tr("DESKTOP_ROOM_HINT")
	room_button.pressed.connect(leave)
	row.add_child(room_button)
	var menu_button := MenuButton.new()
	menu_button.text = "⋯"
	row.add_child(menu_button)
	var popup: PopupMenu = menu_button.get_popup()
	_populate_popup(popup)
	_context_popup = PopupMenu.new()
	_context_popup.name = "PigOnlyContextMenu"
	add_child(_context_popup)
	_populate_popup(_context_popup)
	_event_bubble = PanelContainer.new()
	_event_bubble.theme = ThemeFactory.create(0.8)
	_event_bubble.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_controls_layer.add_child(_event_bubble)
	_event_bubble_button = Button.new()
	_event_bubble_button.pressed.connect(_open_pending_memory)
	_event_bubble.add_child(_event_bubble_button)
	_controls_layer.visible = not pig_only_mode
	_layout_controls(DisplayServer.window_get_size())
	_update_event_bubble()


func _populate_popup(popup: PopupMenu) -> void:
	popup.add_check_item(tr("DESKTOP_FOCUS"), 1)
	popup.set_item_checked(popup.get_item_index(1), GameSession.focus_mode)
	popup.add_check_item(tr("DESKTOP_ALWAYS_ON_TOP"), 2)
	popup.set_item_checked(popup.get_item_index(2), always_on_top)
	popup.set_item_disabled(popup.get_item_index(2), not bool(_platform.positioning))
	popup.add_check_item(tr("SETTINGS_REDUCE_DESKTOP_ACTION_FREQUENCY"), 5)
	popup.set_item_checked(popup.get_item_index(5), GameSession.reduce_desktop_action_frequency)
	popup.add_item(tr("DESKTOP_PAUSE"), 3)
	popup.add_check_item(tr("DESKTOP_TRANSPARENT_MODE"), 4)
	popup.set_item_checked(popup.get_item_index(4), transparent_mode)
	popup.set_item_disabled(popup.get_item_index(4), not bool(_platform.transparency_available))
	popup.add_check_item(tr("DESKTOP_PIG_ONLY"), 6)
	popup.set_item_checked(popup.get_item_index(6), pig_only_mode)
	popup.set_item_disabled(popup.get_item_index(6), not bool(_platform.transparency) or not bool(_platform.native_drag))
	if not bool(_platform.transparency_available) or not bool(_platform.native_drag):
		popup.add_item(tr("DESKTOP_COMPATIBILITY_FALLBACK"), 7)
		popup.set_item_disabled(popup.get_item_index(7), true)
	popup.add_separator()
	popup.add_check_item(tr("DESKTOP_QUIET"), 30)
	popup.add_check_item(tr("DESKTOP_DO_NOT_DISTURB"), 31)
	popup.add_item(tr("FOCUS_TIMER_START"), 32)
	popup.add_item(tr("FOCUS_TIMER_STOP"), 33)
	popup.add_item(tr("DESKTOP_COMPANION_SETTINGS"), 34)
	popup.add_separator()
	popup.add_item(tr("DESKTOP_SCALE_50"), 50)
	popup.add_item(tr("DESKTOP_SCALE_75"), 75)
	popup.add_item(tr("DESKTOP_SCALE_100"), 100)
	popup.add_item(tr("DESKTOP_SCALE_125"), 125)
	popup.add_item(tr("DESKTOP_SCALE_150"), 150)
	popup.add_separator()
	var allowed_docks: Array[String] = ReleaseProfile.desktop_docks()
	if "bottom" in allowed_docks:
		popup.add_item(tr("DESKTOP_DOCK_BOTTOM"), 10)
	if "left" in allowed_docks:
		popup.add_item(tr("DESKTOP_DOCK_LEFT"), 11)
	if "right" in allowed_docks:
		popup.add_item(tr("DESKTOP_DOCK_RIGHT"), 12)
	for action_id: int in [10, 11, 12]:
		var item_index: int = popup.get_item_index(action_id)
		if item_index >= 0:
			popup.set_item_disabled(item_index, not bool(_platform.positioning))
	popup.add_separator()
	popup.add_item(tr("DESKTOP_ROOM"), 22)
	popup.add_item(tr("DESKTOP_MINIMIZE"), 20)
	popup.add_item(tr("DESKTOP_EXIT"), 21)
	popup.id_pressed.connect(_menu_action.bind(popup))
	popup.about_to_popup.connect(_sync_popup.bind(popup))


func _sync_popup(popup: PopupMenu) -> void:
	popup.set_item_checked(popup.get_item_index(30), GameSession.desktop_companion.quiet)
	popup.set_item_checked(popup.get_item_index(31), GameSession.desktop_companion.do_not_disturb)
	popup.set_item_checked(popup.get_item_index(1), GameSession.focus_mode)
	popup.set_item_checked(popup.get_item_index(2), always_on_top)
	popup.set_item_checked(popup.get_item_index(4), transparent_mode)
	popup.set_item_disabled(popup.get_item_index(4), not bool(_platform.transparency_available))
	popup.set_item_checked(popup.get_item_index(5), GameSession.reduce_desktop_action_frequency)
	popup.set_item_checked(popup.get_item_index(6), pig_only_mode)
	popup.set_item_disabled(popup.get_item_index(6), not bool(_platform.transparency) or not bool(_platform.native_drag))
	popup.set_item_text(popup.get_item_index(3), tr("DESKTOP_RESUME" if _paused_animation else "DESKTOP_PAUSE"))


func _show_pig_context_menu(local_position: Vector2) -> void:
	if not active or not is_instance_valid(_context_popup):
		return
	var origin := Vector2i.ZERO if _context_popup.is_embedded() else DisplayServer.window_get_position()
	_context_popup.position = origin + Vector2i(local_position)
	_context_popup.popup()


func _begin_window_drag() -> void:
	if active and pig_only_mode and is_instance_valid(_pig) and bool(_platform.get("native_drag", false)):
		DisplayServer.window_start_drag()


func _unhandled_input(event: InputEvent) -> void:
	if active and pig_only_mode and event.is_action_pressed("pause"):
		_pig_only_preference = false
		_apply_window_mode()
		_update_event_bubble()
		_save_settings()
		get_viewport().set_input_as_handled()


func _layout_controls(window_size: Vector2i) -> void:
	if not is_instance_valid(_event_bubble):
		return
	var bubble_rect: Rect2 = DesktopFramePolicy.event_bubble_rect(window_size)
	_event_bubble.offset_left = -bubble_rect.size.x - DesktopFramePolicy.DESKTOP_CONTROL_MARGIN
	_event_bubble.offset_right = -DesktopFramePolicy.DESKTOP_CONTROL_MARGIN
	_event_bubble.offset_top = bubble_rect.position.y
	_event_bubble.offset_bottom = bubble_rect.end.y


func _menu_action(id: int, popup: PopupMenu) -> void:
	GameSession.note_explicit_companion_interaction()
	match id:
		1:
			GameSession.set_focus_mode(not GameSession.focus_mode)
			popup.set_item_checked(popup.get_item_index(1), GameSession.focus_mode)
		2:
			if not bool(_platform.positioning):
				return
			always_on_top = not always_on_top
			popup.set_item_checked(popup.get_item_index(2), always_on_top)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, effective_always_on_top())
		30:
			GameSession.set_desktop_companion_settings(not GameSession.desktop_companion.quiet, GameSession.desktop_companion.do_not_disturb, GameSession.desktop_companion.frequency)
		31:
			GameSession.set_desktop_companion_settings(GameSession.desktop_companion.quiet, not GameSession.desktop_companion.do_not_disturb, GameSession.desktop_companion.frequency)
		32:
			GameSession.start_focus_timer()
		33:
			GameSession.stop_focus_timer()
		34:
			leave()
			_ui.open_desktop_companion_settings()
			return
		5:
			var reduced: bool = not GameSession.reduce_desktop_action_frequency
			GameSession.set_reduce_desktop_action_frequency(reduced)
			popup.set_item_checked(popup.get_item_index(5), reduced)
			_behavior_hold_elapsed = 0.0
			if not reduced and not _pending_behavior.is_empty() and GameSession.desktop_companion.presentation_hold_seconds(false) <= 0.0:
				_apply_presented_behavior(_pending_behavior)
		3:
			_paused_animation = not _paused_animation
			_pig.set_process(not _paused_animation)
			if not _paused_animation and GameSession.desktop_companion.message_allowed():
				_pig.set_performance(GameSession.pig_performance.snapshot(GameSession.catalog.performances))
			if not _paused_animation and not _pending_behavior.is_empty():
				_apply_presented_behavior(_pending_behavior)
			_refresh_frame_limit(true)
		4:
			transparent_mode = not transparent_mode
			popup.set_item_checked(popup.get_item_index(4), transparent_mode)
			_apply_window_mode()
		6:
			_pig_only_preference = not pig_only_mode
			_apply_window_mode()
			popup.set_item_checked(popup.get_item_index(6), pig_only_mode)
			_update_event_bubble()
		22:
			leave()
			return
		10:
			dock = "bottom"
			_apply_window_mode()
		11:
			dock = "left"
			_apply_window_mode()
		12:
			dock = "right"
			_apply_window_mode()
		20:
			hide_requested.emit()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		21:
			GameSession.request_exit()
			return
		_:
			if id in [50, 75, 100, 125, 150]:
				scale_factor = float(id) / 100.0
				_apply_window_mode()
	_save_settings()


func present_behavior(behavior: Dictionary) -> void:
	if not active or not is_instance_valid(_pig):
		return
	if GameSession.desktop_companion.autonomous_motion_allowed() and _behavior_hold_elapsed >= GameSession.desktop_companion.presentation_hold_seconds(GameSession.reduce_desktop_action_frequency):
		_apply_presented_behavior(behavior)
	else:
		_pending_behavior = behavior.duplicate(true)


func _update_behavior_presentation(delta: float) -> void:
	if _paused_animation or not GameSession.desktop_companion.autonomous_motion_allowed():
		return
	_behavior_hold_elapsed += maxf(delta, 0.0)
	if not _pending_behavior.is_empty() and _behavior_hold_elapsed >= GameSession.desktop_companion.presentation_hold_seconds(GameSession.reduce_desktop_action_frequency):
		_apply_presented_behavior(_pending_behavior)


func _apply_presented_behavior(behavior: Dictionary) -> void:
	if _paused_animation or not GameSession.desktop_companion.autonomous_motion_allowed():
		_pending_behavior = behavior.duplicate(true)
		return
	var next_behavior: Dictionary = behavior.duplicate(true)
	var timer_animation: String = GameSession.desktop_companion.timer_animation()
	if not timer_animation.is_empty():
		next_behavior["animation"] = timer_animation
	_pending_behavior.clear()
	_behavior_hold_elapsed = 0.0
	_pig.set_behavior(next_behavior)
	_refresh_frame_limit(true)


func _refresh_frame_limit(force: bool = false) -> void:
	if not active or not is_instance_valid(_pig):
		return
	var minimized: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	var frozen: bool = _paused_animation or not GameSession.desktop_companion.autonomous_motion_allowed()
	var desired: int = DesktopFramePolicy.recommended_fps(_pig.behavior_animation, frozen, GameSession.reduce_motion, minimized)
	if force or Engine.max_fps != desired:
		Engine.max_fps = desired


func effective_always_on_top() -> bool:
	return GameSession.desktop_companion.effective_always_on_top(always_on_top)


func _on_companion_policy_changed() -> void:
	if not active:
		return
	if bool(_platform.get("positioning", false)):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, effective_always_on_top())
	_pending_behavior.clear()
	_behavior_hold_elapsed = DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS
	present_behavior(GameSession.current_behavior_snapshot())
	_refresh_frame_limit(true)
	_update_event_bubble()


func _on_memory_queue_changed() -> void:
	if active:
		_update_event_bubble()


func _update_event_bubble() -> void:
	if not is_instance_valid(_event_bubble) or not is_instance_valid(_event_bubble_button):
		return
	var count: int = GameSession.pig_state.pending_events.size() + GameSession.pig_state.summarized_events.size()
	_event_bubble.visible = active and count > 0 and not pig_only_mode and GameSession.desktop_companion.proactive_allowed()
	_event_bubble_button.text = tr("DESKTOP_MEMORY_BUBBLE").format({"count": count})
	if bool(_platform.get("transparency", false)):
		_update_passthrough(_last_window_size)


func _open_pending_memory() -> void:
	if not active:
		return
	leave()
	if is_instance_valid(_ui):
		_ui.call_deferred("play_next_pending_memory")


func _load_settings() -> void:
	var data: Dictionary = GameSession.desktop_window_settings()
	scale_factor = float(data.desktop_scale)
	dock = str(data.desktop_dock)
	desktop_screen = int(data.desktop_screen)
	always_on_top = bool(data.get("desktop_always_on_top", true))
	transparent_mode = bool(data.get("desktop_transparent_mode", true))
	_pig_only_preference = bool(data.get("desktop_pig_only", false))


func _save_settings() -> void:
	desktop_screen = DesktopFramePolicy.resolve_screen(
		DisplayServer.window_get_current_screen(),
		desktop_screen,
		DisplayServer.get_primary_screen(),
		DisplayServer.get_screen_count()
	)
	GameSession.save_machine_settings({
		"desktop_scale": scale_factor,
		"desktop_dock": dock,
		"desktop_screen": desktop_screen,
		"desktop_always_on_top": always_on_top,
		"desktop_transparent_mode": transparent_mode,
		"desktop_pig_only": _pig_only_preference,
	})


func _ensure_visible() -> void:
	if not bool(_platform.get("positioning", false)):
		return
	var window_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var usable_rects: Array[Rect2i] = []
	for screen: int in DisplayServer.get_screen_count():
		usable_rects.append(DisplayServer.screen_get_usable_rect(screen))
	var accessible: bool = DesktopFramePolicy.window_has_accessible_region(window_rect, usable_rects)
	if pig_only_mode:
		var pig_rect := Rect2i(_pig.get_global_rect())
		pig_rect.position += window_rect.position
		accessible = DesktopFramePolicy.pig_has_accessible_region(pig_rect, usable_rects)
	if not accessible:
		_dock_window(window_rect.size)
