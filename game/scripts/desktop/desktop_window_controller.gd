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
var _paused_animation: bool = false
var _visibility_check_elapsed: float = 0.0
var _frame_limit_check_elapsed: float = 0.0
var _roam_direction: float = 1.0
var _roam_speed: float = 0.0
var _turn_wait_seconds: float = 0.0
var _passthrough_dirty: bool = false
var _behavior_hold_elapsed: float = 0.0
var _pending_behavior: Dictionary = {}
var _last_window_size := Vector2i.ZERO
var _room_pig_anchors: Array[float] = []
var _room_pig_offsets: Array[float] = []
var _room_pig_scale := Vector2.ONE
var _context_popup: PopupMenu
var _platform: Dictionary = {}
var _items: RoomInteractionController
var _manual_window_dragging: bool = false
var _drag_window_position := Vector2.ZERO


func configure_items(controller: RoomInteractionController) -> void:
	_items = controller
	_items.stage.furniture_pressed.connect(_on_item_pressed)
	GameSession.furniture_invited.connect(_on_furniture_invited)


func _ready() -> void:
	set_process(false)
	get_window().size_changed.connect(_on_window_size_changed)
	GameSession.desktop_companion_changed.connect(_on_companion_policy_changed)
	if not GameSession.memory_queue_changed.is_connected(_on_memory_queue_changed):
		GameSession.memory_queue_changed.connect(_on_memory_queue_changed)
	GameSession.postcard_mail_changed.connect(_on_memory_queue_changed)


func _process(delta: float) -> void:
	if not active:
		return
	if _manual_window_dragging and is_instance_valid(_pig) and not _pig.desktop_drag_uses_touch() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pig.cancel_desktop_drag()
	_update_behavior_presentation(delta)
	_update_desktop_roaming(delta)
	_visibility_check_elapsed += delta
	_frame_limit_check_elapsed += delta
	if _frame_limit_check_elapsed >= 0.25:
		_frame_limit_check_elapsed = 0.0
		_refresh_frame_limit()
		if _item_active():
			_passthrough_dirty = true
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
	if is_instance_valid(_items):
		_items.resize_desktop(_item_bounds(), scale_factor)
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
	if not _pig.desktop_drag_motion.is_connected(_move_window_drag):
		_pig.desktop_drag_motion.connect(_move_window_drag)
	if not _pig.desktop_drag_ended.is_connected(_end_window_drag):
		_pig.desktop_drag_ended.connect(_end_window_drag)
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
	if is_instance_valid(_items):
		_items.enter_desktop(Rect2(), scale_factor)
	_apply_window_mode()
	_build_context_menu()
	present_behavior(GameSession.current_behavior_snapshot())
	_refresh_frame_limit(true)


func leave() -> void:
	if not active:
		return
	_save_settings()
	active = false
	_manual_window_dragging = false
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
	_pig.clear_explicit_item_motion()
	_pig.set_item_interaction_active(false)
	_pig.set_behavior(GameSession.current_behavior_snapshot())
	_pig.set_locomotion_direction(-1.0)
	if is_instance_valid(_context_popup):
		_context_popup.queue_free()
	_context_popup = null
	_roam_direction = 1.0
	_roam_speed = 0.0
	_turn_wait_seconds = 0.0
	_passthrough_dirty = false
	_last_window_size = Vector2i.ZERO
	returned_to_room.emit()


func set_screenshot_controls_visible(value: bool) -> bool:
	if not is_instance_valid(_context_popup):
		return false
	var previous: bool = _context_popup.visible
	_context_popup.visible = value and active
	return previous


func _apply_window_mode() -> void:
	_platform = DesktopPlatformPolicy.detect(transparent_mode, true)
	var use_transparency: bool = bool(_platform.transparency)
	pig_only_mode = true
	var minimum_size: Vector2i = DesktopFramePolicy.minimum_companion_window_size(scale_factor, true)
	get_window().min_size = minimum_size
	DisplayServer.window_set_min_size(minimum_size)
	get_window().transparent_bg = use_transparency
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, use_transparency)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, use_transparency)
	if bool(_platform.positioning):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, effective_always_on_top())
	var requested_window_size: Vector2i = DesktopFramePolicy.companion_window_size(scale_factor, true)
	DisplayServer.window_set_size(requested_window_size)
	var window_size: Vector2i = DisplayServer.window_get_size()
	_last_window_size = window_size
	get_window().content_scale_size = window_size
	_dock_window(window_size)
	_pig.size = Vector2(DesktopFramePolicy.CHARACTER_BASE_SIZE)
	if not _item_active():
		_restore_free_pig_layout()
	if is_instance_valid(_items):
		_items.resize_desktop(_item_bounds(), scale_factor)
	if use_transparency:
		_update_passthrough(window_size)
	else:
		_clear_passthrough()
	_update_context_menu()


func _item_bounds() -> Rect2:
	var width: float = DesktopFramePolicy.character_area_width(float(_last_window_size.x), true)
	return Rect2(Vector2(8, 8), Vector2(maxf(width - 16.0, 1.0), maxf(_last_window_size.y - 16.0, 1.0)))


func _item_active() -> bool:
	return is_instance_valid(_items) and not str(_items.snapshot().furniture_id).is_empty()


func _restore_free_pig_layout() -> void:
	_pig.scale = Vector2.ONE * scale_factor
	var visual_size: Vector2 = _pig.size * scale_factor
	var bounds: Vector2 = DesktopFramePolicy.roaming_bounds(DesktopFramePolicy.character_area_width(float(_last_window_size.x), true), visual_size.x, GameSession.desktop_roaming_reduced())
	_pig.position = Vector2(clampf(24.0 * scale_factor, bounds.x, bounds.y), _last_window_size.y - visual_size.y - 8)


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
	# DisplayServer accepts one polygon, so disjoint hit regions are joined by
	# a four-pixel corridor. Geometry2D keeps the result simple and prevents a
	# self-intersection from swallowing a large transparent desktop area.
	var item_rect := Rect2()
	if _item_active():
		item_rect = _items.stage.interaction_layout().rect
	var points: PackedVector2Array = DesktopFramePolicy.mouse_passthrough_polygon(pig_rect, window_size, false, true, item_rect)
	if bool(_platform.get("transparency", false)):
		DisplayServer.window_set_mouse_passthrough(points)
	_passthrough_dirty = false
	return points


func _update_desktop_roaming(delta: float) -> void:
	if not is_instance_valid(_pig) or _paused_animation or _item_active() or not GameSession.desktop_companion.autonomous_motion_allowed():
		return
	if bool(_pig.get("_dragging")):
		_roam_speed = 0.0
		return
	var reduced_roaming: bool = GameSession.desktop_roaming_reduced()
	var bounds: Vector2 = DesktopFramePolicy.roaming_bounds(DesktopFramePolicy.character_area_width(float(_last_window_size.x), true), _pig.get_global_rect().size.x, reduced_roaming)
	var previous_x: float = _pig.position.x
	var speed: float = DesktopFramePolicy.roaming_speed(scale_factor, reduced_roaming)
	var moving: bool = _pig.behavior_animation == "walk" and not _paused_animation
	_turn_wait_seconds = maxf(_turn_wait_seconds - minf(delta, 0.1), 0.0)
	_roam_speed = move_toward(_roam_speed, speed if moving and _turn_wait_seconds <= 0.0 else 0.0, speed * 4.0 * minf(delta, 0.1))
	if _roam_speed > 0.0:
		var step: Vector2 = DesktopFramePolicy.advance_roaming_x(
			previous_x,
			_roam_direction,
			minf(delta, 0.1),
			bounds,
			_roam_speed
		)
		_pig.position.x = step.x
		if step.y != _roam_direction:
			_turn_wait_seconds = 0.3
			_roam_speed = 0.0
		_roam_direction = step.y
		_pig.set_locomotion_direction(_roam_direction)
	else:
		_pig.position.x = clampf(previous_x, bounds.x, bounds.y)
	if not is_equal_approx(previous_x, _pig.position.x):
		_passthrough_dirty = true


func _build_context_menu() -> void:
	var controls_scale: float = clampf(GameSession.ui_scale, 1.0, 1.5)
	var controls_theme: Theme = ThemeFactory.create(controls_scale)
	controls_theme.set_font_size("font_size", "PopupMenu", roundi(18 * controls_scale))
	_context_popup = PopupMenu.new()
	_context_popup.name = "PigContextMenu"
	_context_popup.force_native = true
	_context_popup.prefer_native_menu = false
	_context_popup.theme = controls_theme
	add_child(_context_popup)
	_populate_popup(_context_popup)
	_update_context_menu()


func _populate_popup(popup: PopupMenu) -> void:
	var icon_size: int = roundi(24 * clampf(GameSession.ui_scale, 1.0, 1.5))
	popup.add_icon_item(UIAssets.scaled_icon("armchair", icon_size), tr("DESKTOP_ROOM"), 22)
	popup.add_icon_item(UIAssets.scaled_icon("book-open", icon_size), tr("UI_ALBUM"), 37)
	popup.add_icon_item(UIAssets.scaled_icon("mail", icon_size), tr("POSTCARD_INBOX"), 36)
	for action_id: int in [22, 37, 36]:
		popup.set_item_icon_modulate(popup.get_item_index(action_id), ThemeFactory.INK)
	popup.add_separator()
	var item_menu := PopupMenu.new()
	item_menu.name = "ItemMenu"
	item_menu.force_native = true
	item_menu.prefer_native_menu = false
	popup.add_child(item_menu)
	item_menu.index_pressed.connect(_use_item.bind(item_menu))
	popup.add_submenu_item(tr("DESKTOP_USE_ITEM"), "ItemMenu", 35)
	_fill_item_menu(item_menu)
	popup.add_separator()
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
	if not bool(_platform.transparency_available) or not bool(_platform.window_drag):
		popup.add_item(tr("DESKTOP_COMPATIBILITY_FALLBACK"), 7)
		popup.set_item_disabled(popup.get_item_index(7), true)
	popup.add_separator()
	popup.add_check_item(tr("DESKTOP_QUIET"), 30)
	popup.add_check_item(tr("DESKTOP_DO_NOT_DISTURB"), 31)
	popup.add_item(tr("FOCUS_TIMER_START"), 32)
	popup.add_item(tr("FOCUS_TIMER_STOP"), 33)
	popup.add_item(tr("DESKTOP_COMPANION_SETTINGS"), 34)
	popup.add_separator()
	var size_menu := PopupMenu.new()
	size_menu.name = "SizeMenu"
	size_menu.force_native = true
	size_menu.prefer_native_menu = false
	popup.add_child(size_menu)
	for percentage: int in [50, 75, 100, 125, 150]:
		size_menu.add_radio_check_item(tr("DESKTOP_SCALE_%d" % percentage), percentage)
	size_menu.id_pressed.connect(_menu_action.bind(size_menu))
	popup.add_submenu_item(tr("DESKTOP_SCALE_MENU"), "SizeMenu")
	var dock_menu := PopupMenu.new()
	dock_menu.name = "DockMenu"
	dock_menu.force_native = true
	dock_menu.prefer_native_menu = false
	popup.add_child(dock_menu)
	var allowed_docks: Array[String] = ReleaseProfile.desktop_docks()
	if "bottom" in allowed_docks:
		dock_menu.add_radio_check_item(tr("DESKTOP_DOCK_BOTTOM"), 10)
	if "left" in allowed_docks:
		dock_menu.add_radio_check_item(tr("DESKTOP_DOCK_LEFT"), 11)
	if "right" in allowed_docks:
		dock_menu.add_radio_check_item(tr("DESKTOP_DOCK_RIGHT"), 12)
	for action_id: int in [10, 11, 12]:
		var item_index: int = dock_menu.get_item_index(action_id)
		if item_index >= 0:
			dock_menu.set_item_disabled(item_index, not bool(_platform.positioning))
	dock_menu.id_pressed.connect(_menu_action.bind(dock_menu))
	popup.add_submenu_item(tr("DESKTOP_DOCK_MENU"), "DockMenu")
	popup.add_separator()
	popup.add_item(tr("DESKTOP_MINIMIZE"), 20)
	popup.add_item(tr("DESKTOP_EXIT"), 21)
	popup.id_pressed.connect(_menu_action.bind(popup))
	popup.about_to_popup.connect(_sync_popup.bind(popup))


func _sync_popup(popup: PopupMenu) -> void:
	_fill_item_menu(popup.get_node("ItemMenu") as PopupMenu)
	popup.set_item_checked(popup.get_item_index(30), GameSession.desktop_companion.quiet)
	popup.set_item_checked(popup.get_item_index(31), GameSession.desktop_companion.do_not_disturb)
	popup.set_item_checked(popup.get_item_index(1), GameSession.focus_mode)
	popup.set_item_checked(popup.get_item_index(2), always_on_top)
	popup.set_item_checked(popup.get_item_index(4), transparent_mode)
	popup.set_item_disabled(popup.get_item_index(4), not bool(_platform.transparency_available))
	popup.set_item_checked(popup.get_item_index(5), GameSession.reduce_desktop_action_frequency)
	popup.set_item_text(popup.get_item_index(3), tr("DESKTOP_RESUME" if _paused_animation else "DESKTOP_PAUSE"))
	var size_menu: PopupMenu = popup.get_node("SizeMenu") as PopupMenu
	for percentage: int in [50, 75, 100, 125, 150]:
		size_menu.set_item_checked(size_menu.get_item_index(percentage), percentage == roundi(scale_factor * 100))
	var dock_menu: PopupMenu = popup.get_node("DockMenu") as PopupMenu
	for action_id: int in [10, 11, 12]:
		var index: int = dock_menu.get_item_index(action_id)
		if index >= 0:
			dock_menu.set_item_checked(index, dock == {10:"bottom", 11:"left", 12:"right"}[action_id])
	_update_context_menu()


func _fill_item_menu(menu: PopupMenu) -> void:
	menu.clear()
	for item: Dictionary in GameSession.catalog.furniture:
		var furniture_id: String = str(item.id)
		if not furniture_id in GameSession.pig_state.placed_furniture.values() or str(item.get("behavior_id", "")).is_empty():
			continue
		menu.add_item(tr(str(item.name_key)))
		var index: int = menu.item_count - 1
		menu.set_item_metadata(index, furniture_id)
		menu.set_item_disabled(index, _paused_animation or not GameSession.can_invite_to_furniture(furniture_id))
	if menu.item_count == 0:
		menu.add_item(tr("DESKTOP_NO_ITEMS"))
		menu.set_item_disabled(0, true)


func _use_item(index: int, menu: PopupMenu) -> void:
	if not active or _paused_animation or index < 0 or index >= menu.item_count or menu.is_item_disabled(index):
		return
	GameSession.invite_to_furniture(str(menu.get_item_metadata(index)))


func _on_item_pressed(_furniture_id: String, _slot_id: String) -> void:
	if active:
		_show_pig_context_menu(_items.stage.get_local_mouse_position())


func _on_furniture_invited(furniture_id: String) -> void:
	if not active or _paused_animation:
		return
	var behavior: Dictionary = GameSession.current_behavior_snapshot()
	if str(behavior.get("required_furniture", "")) != furniture_id:
		return
	_pig.allow_explicit_item_motion(float(behavior.get("duration_seconds", 1.0)))
	_apply_presented_behavior(behavior, true)


func _show_pig_context_menu(local_position: Vector2) -> void:
	if not active or not is_instance_valid(_context_popup):
		return
	var origin := Vector2i.ZERO if _context_popup.is_embedded() else DisplayServer.window_get_position()
	_context_popup.position = origin + Vector2i(local_position)
	_context_popup.popup()


func _begin_window_drag() -> void:
	if not active or not is_instance_valid(_pig):
		return
	if bool(_platform.get("positioning", false)):
		_manual_window_dragging = true
		_start_manual_window_drag()
		_refresh_frame_limit(true)
	elif bool(_platform.get("native_drag", false)):
		_start_native_window_drag()
		_pig.cancel_desktop_drag()
	else:
		_pig.cancel_desktop_drag()


func _start_manual_window_drag() -> void:
	_drag_window_position = Vector2(DisplayServer.window_get_position())


func _move_window_drag(relative: Vector2) -> void:
	if not active or not _manual_window_dragging or not is_instance_valid(_pig) or not _pig.is_dragging():
		return
	if not relative.is_finite():
		return
	_drag_window_position += relative
	_write_window_drag_position(Vector2i(_drag_window_position.round()))


func _write_window_drag_position(position: Vector2i) -> void:
	DisplayServer.window_set_position(position)


func _end_window_drag(_canceled: bool) -> void:
	var was_dragging: bool = _manual_window_dragging
	_manual_window_dragging = false
	if active and was_dragging:
		_ensure_visible()
		_refresh_frame_limit(true)


func _start_native_window_drag() -> void:
	DisplayServer.window_start_drag()


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("pause"):
		leave()
		get_viewport().set_input_as_handled()


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
		36:
			leave()
			_ui.open_postcards()
			return
		37:
			var pending: bool = not GameSession.pig_state.pending_events.is_empty() or not GameSession.pig_state.summarized_events.is_empty()
			leave()
			if pending:
				_ui.play_next_pending_memory()
			else:
				_ui.open_album()
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


func _apply_presented_behavior(behavior: Dictionary, explicit: bool = false) -> void:
	if _paused_animation or (not explicit and not GameSession.desktop_companion.autonomous_motion_allowed()):
		_pending_behavior = behavior.duplicate(true)
		return
	var next_behavior: Dictionary = behavior.duplicate(true)
	var timer_animation: String = GameSession.desktop_companion.timer_animation()
	if not explicit and not timer_animation.is_empty():
		next_behavior["animation"] = timer_animation
		next_behavior.erase("required_furniture")
	_pending_behavior.clear()
	_behavior_hold_elapsed = 0.0
	var had_item: bool = _item_active()
	if is_instance_valid(_items):
		_items.present(next_behavior)
	else:
		_pig.set_behavior(next_behavior)
	if had_item and not _item_active():
		_restore_free_pig_layout()
	_passthrough_dirty = true
	_refresh_frame_limit(true)


func _refresh_frame_limit(force: bool = false) -> void:
	if not active or not is_instance_valid(_pig):
		return
	var minimized: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	var frozen: bool = _paused_animation or not _pig.desktop_motion_allowed()
	var desired: int = DesktopFramePolicy.recommended_fps(_pig.behavior_animation, frozen, GameSession.reduce_motion, minimized)
	if _manual_window_dragging and not minimized:
		desired = maxi(desired, DesktopFramePolicy.DESKTOP_ACTIVE_FPS)
	var motion: PigMotionPlayer = _pig.get("_motion") as PigMotionPlayer
	if motion.transitioning() and not frozen and not minimized and not GameSession.reduce_motion:
		desired = maxi(desired, DesktopFramePolicy.DESKTOP_ACTIVE_FPS)
	if force or Engine.max_fps != desired:
		Engine.max_fps = desired


func effective_always_on_top() -> bool:
	return GameSession.desktop_companion.effective_always_on_top(always_on_top)


func _on_companion_policy_changed() -> void:
	if not active:
		return
	if bool(_platform.get("positioning", false)):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, effective_always_on_top())
	if not GameSession.desktop_companion.application_focused:
		_pig.clear_explicit_item_motion()
	_pending_behavior.clear()
	_behavior_hold_elapsed = DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS
	present_behavior(GameSession.current_behavior_snapshot())
	_refresh_frame_limit(true)
	_update_context_menu()


func _on_memory_queue_changed() -> void:
	if active:
		_update_context_menu()


func _update_context_menu() -> void:
	if not is_instance_valid(_context_popup):
		return
	var count: int = GameSession.pig_state.pending_events.size() + GameSession.pig_state.summarized_events.size()
	var postcards: int = GameSession.unread_postcard_count()
	_context_popup.set_item_text(_context_popup.get_item_index(37), tr("DESKTOP_MEMORY_BUBBLE").format({"count":count}) if count > 0 else tr("UI_ALBUM"))
	_context_popup.set_item_text(_context_popup.get_item_index(36), tr("DESKTOP_MAIL_MENU").format({"count":postcards}) if postcards > 0 else tr("POSTCARD_INBOX"))


func _load_settings() -> void:
	var data: Dictionary = GameSession.desktop_window_settings()
	scale_factor = float(data.desktop_scale)
	dock = str(data.desktop_dock)
	desktop_screen = int(data.desktop_screen)
	always_on_top = bool(data.get("desktop_always_on_top", true))
	transparent_mode = bool(data.get("desktop_transparent_mode", true))


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
		"desktop_pig_only": true,
	})


func _ensure_visible() -> void:
	if _manual_window_dragging or not bool(_platform.get("positioning", false)):
		return
	var window_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var usable_rects: Array[Rect2i] = []
	for screen: int in DisplayServer.get_screen_count():
		usable_rects.append(DisplayServer.screen_get_usable_rect(screen))
	var pig_rect := Rect2i(_pig.get_global_rect())
	pig_rect.position += window_rect.position
	var accessible: bool = DesktopFramePolicy.pig_has_accessible_region(pig_rect, usable_rects)
	if not accessible:
		_dock_window(window_rect.size)
