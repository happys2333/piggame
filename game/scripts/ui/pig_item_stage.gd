class_name PigItemStage
extends AssetCanvas

signal furniture_pressed(furniture_id: String, slot_id: String)

const FOREGROUND_SPLITS := {"furn_bed_basic":0.66, "furn_window_cushion":0.73, "furn_treadmill":0.86, "furn_tiny_drum":0.25, "furn_cardboard_castle":0.0}

var _profiles: Dictionary = JsonStore.read_object("res://game/data/catalog/room_interactions.json")
var _layout: Dictionary = {}
var _offset := Vector2.ZERO
var _feedback_elapsed: float = 0.0
var _foreground: PigItemFront


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_foreground = PigItemFront.new()
	_foreground.stage = self
	_foreground.z_index = 2
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foreground)


func layout_for(behavior: Dictionary, pig: PigVisual, bounds: Rect2, actor_scale: float) -> Dictionary:
	var furniture_id: String = str(behavior.get("required_furniture", ""))
	if not _profiles.has(furniture_id):
		return {}
	var slots: Array[String] = []
	for slot: String in GameSession.pig_state.placed_furniture:
		if str(GameSession.pig_state.placed_furniture[slot]) == furniture_id:
			slots.append(slot)
	if slots.is_empty():
		return {}
	slots.sort()
	var profile: Dictionary = _profiles[furniture_id]
	var texture: Texture2D = GameSession.final_assets.texture_for("furniture:%s" % furniture_id)
	if texture == null:
		return {}
	var width: float = float(profile.width)
	var rect := Rect2(Vector2.ZERO, Vector2(width, width * texture.get_height() / texture.get_width()))
	var normalized: Array = profile.contact
	var contact: Vector2 = rect.size * Vector2(float(normalized[0]), float(normalized[1]))
	var body_id: String = str(profile.get("body_id", PigVisualRig.body_for(str(behavior.get("animation", "idle")))))
	var fitted: Transform2D = PigVisualRig.fit_transform(pig.size, body_id)
	var ground: Vector2 = fitted * Vector2(128, PigVisualRig.ground_for(body_id))
	var anchor: Vector2 = fitted * PigVisualRig.snout_for(body_id, 0) if str(profile.anchor) == "snout" else ground
	var pig_scale: float = float(profile.pig_scale)
	var actor_position: Vector2 = contact - anchor * pig_scale
	var combined: Rect2 = rect.merge(Rect2(actor_position, pig.size * pig_scale)).grow(7.0)
	var uniform: float = minf(actor_scale / pig_scale, minf(bounds.size.x / combined.size.x, bounds.size.y / combined.size.y))
	var origin := Vector2(bounds.get_center().x - combined.get_center().x * uniform, bounds.end.y - combined.end.y * uniform)
	return {"slot_id":slots[0], "furniture_id":furniture_id, "rect":Rect2(origin, rect.size * uniform), "contact":origin + contact * uniform, "ground":origin + (actor_position + ground * pig_scale) * uniform, "pig_scale":pig_scale * uniform, "uniform":uniform, "body_id":body_id, "profile":profile}


func present_layout(layout: Dictionary) -> void:
	_layout = layout
	_offset = Vector2.ZERO
	_feedback_elapsed = 0.0
	_redraw()


func clear_interaction() -> void:
	if _layout.is_empty():
		return
	_layout = {}
	_offset = Vector2.ZERO
	_redraw()


func interaction_layout(furniture_id: String = "") -> Dictionary:
	if _layout.is_empty() or (not furniture_id.is_empty() and furniture_id != str(_layout.furniture_id)):
		return {}
	var result: Dictionary = _layout.duplicate()
	result.rect = Rect2((_layout.rect as Rect2).position + _offset, (_layout.rect as Rect2).size)
	result.contact = (_layout.contact as Vector2) + _offset
	return result


func update_interaction(phase: float) -> Vector2:
	if _layout.is_empty():
		return Vector2.ZERO
	var next := Vector2.ZERO
	match str((_layout.profile as Dictionary).get("motion", "none")):
		"roll":
			next.x = sin(phase * TAU / 4.0) * 6.0
		"tap":
			next.y = -pow(maxf(sin(phase * TAU / 1.2), 0.0), 6.0) * 2.0
		"sway":
			next.x = sin(phase * TAU / 3.4) * 3.0
	next *= float(_layout.uniform)
	if not next.is_equal_approx(_offset) and phase - _feedback_elapsed >= 1.0 / 20.0:
		_feedback_elapsed = phase
		_offset = next
		_redraw()
	return _offset


func _redraw() -> void:
	queue_redraw()
	if is_instance_valid(_foreground):
		_foreground.queue_redraw()


func _draw() -> void:
	begin_visual_draw()
	var layout: Dictionary = interaction_layout()
	if layout.is_empty():
		return
	var texture: Texture2D = visual_texture("furniture:%s" % str(layout.furniture_id))
	if texture != null:
		draw_texture_rect(texture, layout.rect, false)


func draw_foreground(canvas: AssetCanvas) -> void:
	var layout: Dictionary = interaction_layout()
	if layout.is_empty():
		return
	var split: float = float(FOREGROUND_SPLITS.get(str(layout.furniture_id), 1.0))
	if split >= 1.0:
		return
	var texture: Texture2D = canvas.visual_texture("furniture:%s" % str(layout.furniture_id))
	if texture == null:
		return
	var rect: Rect2 = layout.rect
	var region := Rect2(0, texture.get_height() * split, texture.get_width(), texture.get_height() * (1.0 - split))
	var destination := Rect2(rect.position + Vector2(0, rect.size.y * split), Vector2(rect.size.x, rect.size.y * (1.0 - split)))
	canvas.draw_texture_rect_region(texture, destination, region)


func furniture_at_position(point: Vector2, margin: float = 0.0) -> String:
	var layout: Dictionary = interaction_layout()
	return str(layout.furniture_id) if not layout.is_empty() and (layout.rect as Rect2).grow(margin).has_point(point) else ""


func _gui_input(event: InputEvent) -> void:
	var point: Vector2
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		point = event.position
	elif event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			return
		point = event.position
	else:
		return
	if not furniture_at_position(point).is_empty():
		furniture_pressed.emit(str(_layout.furniture_id), str(_layout.slot_id))
		accept_event()
