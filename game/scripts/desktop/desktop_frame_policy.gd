class_name DesktopFramePolicy
extends RefCounted

const MAIN_FPS: int = 60
const DESKTOP_ACTIVE_FPS: int = 30
const DESKTOP_IDLE_FPS: int = 12
const DESKTOP_MINIMIZED_FPS: int = 4
const DESKTOP_WALK_SPEED: float = 48.0
const REDUCED_ROAM_RATIO: float = 0.35
const REDUCED_ACTION_HOLD_SECONDS: float = 45.0
const PASSTHROUGH_CONNECTOR_WIDTH: float = 4.0
const DESKTOP_CONTROL_MARGIN: float = 8.0
const CONTROL_BAR_SIZE := Vector2i(128, 52)
const MIN_VISIBLE_CONTROL_SIZE := Vector2i(120, 48)
const EVENT_BUBBLE_TOP: float = 68.0
const EVENT_BUBBLE_MAX_SIZE := Vector2(180.0, 52.0)
const CHARACTER_AREA_BASE_SIZE := Vector2i(430, 280)
const CHARACTER_BASE_SIZE := Vector2i(280, 230)
const CONTROL_RAIL_WIDTH: float = 180.0
const MIN_COMPANION_WINDOW_SIZE := Vector2i(403, 140)


static func companion_window_size(scale_factor: float, pig_only: bool = false) -> Vector2i:
	var character_area := Vector2i(Vector2(CHARACTER_AREA_BASE_SIZE) * scale_factor)
	return character_area if pig_only else character_area + Vector2i(int(CONTROL_RAIL_WIDTH + DESKTOP_CONTROL_MARGIN), 0)


static func minimum_companion_window_size(scale_factor: float, pig_only: bool = false) -> Vector2i:
	var character_size := Vector2i((Vector2(CHARACTER_BASE_SIZE) * scale_factor).ceil())
	if pig_only:
		return character_size + Vector2i(int(DESKTOP_CONTROL_MARGIN * 2.0), int(DESKTOP_CONTROL_MARGIN * 2.0))
	var content_size := character_size + Vector2i(int(CONTROL_RAIL_WIDTH + DESKTOP_CONTROL_MARGIN * 3.0), int(DESKTOP_CONTROL_MARGIN * 2.0))
	return Vector2i(maxi(content_size.x, MIN_COMPANION_WINDOW_SIZE.x), maxi(content_size.y, MIN_COMPANION_WINDOW_SIZE.y))


static func character_area_width(window_width: float, pig_only: bool = false) -> float:
	return maxf(window_width, 0.0) if pig_only else maxf(window_width - CONTROL_RAIL_WIDTH - DESKTOP_CONTROL_MARGIN, 0.0)


static func recommended_fps(animation: String, paused: bool, reduce_motion: bool, minimized: bool = false) -> int:
	if minimized:
		return DESKTOP_MINIMIZED_FPS
	if paused or animation in ["sleep", "bed_nap", "window_nap", "lie", "pillow_flop", "blanket_roll"]:
		return DESKTOP_IDLE_FPS
	if reduce_motion and animation in ["idle", "sit", "stare", "look_mouse"]:
		return DESKTOP_IDLE_FPS
	return DESKTOP_ACTIVE_FPS


static func roaming_bounds(window_width: float, pig_width: float, reduce_roaming: bool) -> Vector2:
	var left: float = 8.0
	var right: float = maxf(left, window_width - pig_width - 8.0)
	if not reduce_roaming:
		return Vector2(left, right)
	var center: float = (left + right) * 0.5
	var half_range: float = (right - left) * REDUCED_ROAM_RATIO * 0.5
	return Vector2(center - half_range, center + half_range)


static func roaming_speed(scale_factor: float, reduce_roaming: bool) -> float:
	return DESKTOP_WALK_SPEED * maxf(scale_factor, 0.0) * (0.45 if reduce_roaming else 1.0)


static func action_transition_ready(elapsed_seconds: float, reduce_frequency: bool) -> bool:
	return not reduce_frequency or elapsed_seconds >= REDUCED_ACTION_HOLD_SECONDS


static func advance_roaming_x(current_x: float, direction: float, delta: float, bounds: Vector2, speed: float) -> Vector2:
	var left: float = minf(bounds.x, bounds.y)
	var right: float = maxf(bounds.x, bounds.y)
	var width: float = right - left
	if width <= 0.001 or speed <= 0.0 or delta <= 0.0:
		return Vector2(clampf(current_x, left, right), 1.0 if direction >= 0.0 else -1.0)
	var normalized_x: float = clampf(current_x, left, right) - left
	var phase: float = normalized_x if direction >= 0.0 else width * 2.0 - normalized_x
	phase = fposmod(phase + speed * delta, width * 2.0)
	if phase <= width:
		return Vector2(left + phase, 1.0)
	return Vector2(right - (phase - width), -1.0)


static func event_bubble_rect(window_size: Vector2i) -> Rect2:
	var available_width: float = maxf(float(window_size.x) - DESKTOP_CONTROL_MARGIN * 2.0, 0.0)
	var available_height: float = maxf(float(window_size.y) - EVENT_BUBBLE_TOP - DESKTOP_CONTROL_MARGIN, 0.0)
	var bubble_size := Vector2(
		minf(EVENT_BUBBLE_MAX_SIZE.x, available_width),
		minf(EVENT_BUBBLE_MAX_SIZE.y, available_height)
	)
	var bubble_position := Vector2(
		maxf(float(window_size.x) - bubble_size.x - DESKTOP_CONTROL_MARGIN, 0.0),
		minf(EVENT_BUBBLE_TOP, maxf(float(window_size.y) - bubble_size.y - DESKTOP_CONTROL_MARGIN, 0.0))
	)
	return Rect2(bubble_position, bubble_size)


static func mouse_passthrough_polygon(pig_rect: Rect2, window_size: Vector2i, show_bubble: bool, pig_only: bool = false) -> PackedVector2Array:
	var window_bounds := Rect2(Vector2.ZERO, Vector2(window_size))
	var clipped_pig: Rect2 = pig_rect.intersection(window_bounds)
	if pig_only:
		return _rect_polygon(clipped_pig) if clipped_pig.has_area() else PackedVector2Array()
	var controls: Rect2 = Rect2(control_bar_rect(window_size)).intersection(window_bounds)
	var bubble: Rect2 = event_bubble_rect(window_size).intersection(window_bounds)
	if show_bubble and clipped_pig.has_area() and clipped_pig.intersects(bubble):
		var pig_and_bubble: PackedVector2Array = _join_hit_region(_rect_polygon(clipped_pig), clipped_pig.get_center(), bubble, window_bounds)
		return _join_hit_region(pig_and_bubble, bubble.get_center(), controls, window_bounds)
	var merged: PackedVector2Array = _rect_polygon(controls) if controls.has_area() else PackedVector2Array()
	var control_center: Vector2 = controls.get_center()
	if show_bubble:
		merged = _join_hit_region(merged, control_center, bubble, window_bounds)
		control_center = bubble.get_center()
	return _join_hit_region(merged, control_center, clipped_pig, window_bounds)


static func _join_hit_region(existing: PackedVector2Array, origin: Vector2, target: Rect2, window_bounds: Rect2) -> PackedVector2Array:
	if not target.has_area():
		return existing
	if existing.is_empty():
		return _rect_polygon(target)
	var direct: Array[PackedVector2Array] = Geometry2D.merge_polygons(existing, _rect_polygon(target))
	if direct.size() == 1:
		return direct[0]
	var center: Vector2 = target.get_center()
	var half_width: float = PASSTHROUGH_CONNECTOR_WIDTH * 0.5
	var horizontal := Rect2(
		Vector2(minf(origin.x, center.x) - half_width, origin.y - half_width),
		Vector2(absf(center.x - origin.x) + PASSTHROUGH_CONNECTOR_WIDTH, PASSTHROUGH_CONNECTOR_WIDTH)
	).intersection(window_bounds)
	var vertical := Rect2(
		Vector2(center.x - half_width, minf(origin.y, center.y) - half_width),
		Vector2(PASSTHROUGH_CONNECTOR_WIDTH, absf(center.y - origin.y) + PASSTHROUGH_CONNECTOR_WIDTH)
	).intersection(window_bounds)
	var merged: PackedVector2Array = existing
	for part: Rect2 in [horizontal, vertical, target]:
		if not part.has_area():
			continue
		var unions: Array[PackedVector2Array] = Geometry2D.merge_polygons(merged, _rect_polygon(part))
		if unions.size() != 1:
			return PackedVector2Array()
		merged = unions[0]
	return merged


static func control_bar_rect(window_size: Vector2i) -> Rect2i:
	var margin: int = int(DESKTOP_CONTROL_MARGIN)
	return Rect2i(Vector2i(window_size.x - CONTROL_BAR_SIZE.x - margin, margin), CONTROL_BAR_SIZE)


static func docked_window_position(window_size: Vector2i, usable: Rect2i, dock: String) -> Vector2i:
	var margin: int = int(DESKTOP_CONTROL_MARGIN)
	var position: Vector2i
	match dock:
		"left": position = usable.position + Vector2i(margin, usable.size.y - window_size.y - margin)
		"right": position = usable.end - window_size - Vector2i(margin, margin)
		_: position = usable.position + Vector2i((usable.size.x - window_size.x) / 2, usable.size.y - window_size.y - margin)
	var last_left: int = usable.end.x - window_size.x
	position.x = clampi(position.x, usable.position.x, last_left) if last_left >= usable.position.x else last_left
	position.y = clampi(position.y, usable.position.y, maxi(usable.position.y, usable.end.y - window_size.y))
	return position


static func pig_has_accessible_region(pig_rect: Rect2i, usable_rects: Array[Rect2i]) -> bool:
	var required := Vector2i(mini(120, pig_rect.size.x), mini(48, pig_rect.size.y))
	if required.x <= 0 or required.y <= 0:
		return false
	for usable: Rect2i in usable_rects:
		var overlap: Rect2i = pig_rect.intersection(usable)
		if overlap.size.x >= required.x and overlap.size.y >= required.y:
			return true
	return false


static func window_has_accessible_region(window_rect: Rect2i, usable_rects: Array[Rect2i]) -> bool:
	if window_rect.size.x < CONTROL_BAR_SIZE.x or window_rect.size.y < CONTROL_BAR_SIZE.y:
		return false
	var controls: Rect2i = control_bar_rect(window_rect.size)
	controls.position += window_rect.position
	for usable: Rect2i in usable_rects:
		var overlap: Rect2i = usable.intersection(controls)
		if overlap.size.x >= MIN_VISIBLE_CONTROL_SIZE.x and overlap.size.y >= MIN_VISIBLE_CONTROL_SIZE.y:
			return true
	return false


static func resolve_screen(preferred_screen: int, current_screen: int, primary_screen: int, screen_count: int) -> int:
	if screen_count <= 0:
		return -1
	for candidate: int in [preferred_screen, current_screen, primary_screen, 0]:
		if candidate >= 0 and candidate < screen_count:
			return candidate
	return -1


static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
