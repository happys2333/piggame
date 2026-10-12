class_name RoomVisual
extends AssetCanvas

signal furniture_pressed(furniture_id: String, slot_id: String)

const PALETTES := {
	"rose": [Color("#f6c9cd"), Color("#fff1e7"), Color("#e5b5aa")],
	"mint": [Color("#b9d9ca"), Color("#f2f0df"), Color("#a8c7bd")],
	"night": [Color("#677093"), Color("#ddd9e8"), Color("#565e7d")],
}
const FURNITURE_INK := Color("#654f58")
const FURNITURE_LIGHT := Color("#fff7ef")

var item_stage: PigItemStage
var _visual_state: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	GameSession.state_changed.connect(_refresh_visual_state)
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	if not is_visible_in_tree():
		return
	var next_state: Array = [
		GameSession.pig_state.current_room_palette,
		GameSession.pig_state.familiarity_level,
		GameSession.pig_state.placed_furniture.duplicate(),
		TranslationServer.get_locale(),
	]
	if next_state != _visual_state:
		_visual_state = next_state
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and is_node_ready():
		_refresh_visual_state()


func _draw() -> void:
	begin_visual_draw()
	var palette: Array = PALETTES.get(GameSession.pig_state.current_room_palette, PALETTES.rose)
	var room_texture: Texture2D = visual_texture("room:%s" % GameSession.pig_state.current_room_palette)
	if room_texture != null:
		draw_cover_texture(room_texture, Rect2(Vector2.ZERO, size))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), palette[1], true)
		draw_rect(Rect2(0, 0, size.x, size.y * 0.72), palette[0], true)
		for y: int in range(52, floori(size.y * 0.72), 72):
			draw_line(Vector2(0,y), Vector2(size.x,y), Color(palette[1], 0.18), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0,size.y*0.72),Vector2(size.x,size.y*0.72),Vector2(size.x,size.y),Vector2(0,size.y)]), palette[2])
		var window_rect := Rect2(size.x * 0.70, size.y * 0.13, size.x * 0.19, size.y * 0.26)
		draw_rect(window_rect, Color("#d9edf0"), true)
		draw_rect(window_rect, Color("#fffaf3"), false, 10.0)
		draw_line(window_rect.position + Vector2(window_rect.size.x*0.5,0), window_rect.position + Vector2(window_rect.size.x*0.5,window_rect.size.y), Color("#fffaf3"), 7.0)
		draw_line(window_rect.position + Vector2(0,window_rect.size.y*0.55), window_rect.position + Vector2(window_rect.size.x,window_rect.position.y + window_rect.size.y*0.55), Color("#fffaf3"), 7.0)
	_draw_atmosphere()


func atmosphere_effects() -> Array[String]:
	var effects: Array[String] = []
	for furniture_value: Variant in GameSession.pig_state.placed_furniture.values():
		var furniture: Dictionary = GameSession.catalog.get_item("furniture", str(furniture_value))
		var effect: String = str(furniture.get("room_effect", ""))
		if not effect.is_empty() and not effect in effects:
			effects.append(effect)
	effects.sort()
	return effects


func _draw_atmosphere() -> void:
	var window_rect := Rect2(size.x * 0.70, size.y * 0.13, size.x * 0.19, size.y * 0.26)
	for effect: String in atmosphere_effects():
		var final_texture: Texture2D = visual_texture("room_effect:%s" % effect)
		if final_texture != null:
			draw_cover_texture(final_texture, Rect2(Vector2.ZERO, size))
			continue
		match effect:
			"sleep_glow":
				draw_circle(
					Vector2(size.x * 0.17, size.y * 0.58),
					minf(size.x, size.y) * 0.21,
					Color("#ffd77a28")
				)
			"oven_warmth":
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(size.x * 0.25, size.y * 0.43),
						Vector2(size.x * 0.54, size.y * 0.43),
						Vector2(size.x * 0.62, size.y * 0.72),
						Vector2(size.x * 0.22, size.y * 0.72),
					]),
					Color("#f3a36e20")
				)
			"rainy_window":
				draw_rect(window_rect.grow(-7.0), Color("#7faac832"), true)
				for offset: float in [0.10, 0.28, 0.47, 0.66, 0.84]:
					var start := window_rect.position + Vector2(window_rect.size.x * offset, window_rect.size.y * 0.08)
					draw_line(start, start + Vector2(-9, 31), Color("#6f9fbd99"), 3.0)
			"breeze":
				for offset: float in [0.18, 0.46, 0.72]:
					var center := window_rect.position + Vector2(window_rect.size.x * offset, window_rect.size.y * 0.62)
					draw_arc(center, 24.0, -0.7, 0.7, 12, Color("#f8ffff88"), 3.0, true)
			"window_glow":
				draw_circle(
					Vector2(size.x * 0.81, size.y * 0.57),
					minf(size.x, size.y) * 0.19,
					Color("#f8ce7824")
				)


func furniture_layout(slot_id: String) -> Dictionary:
	var layout: Dictionary = interaction_layout(str(GameSession.pig_state.placed_furniture.get(slot_id, "")))
	return layout if not layout.is_empty() and str(layout.slot_id) == slot_id else {}


func interaction_layout(furniture_id: String) -> Dictionary:
	return item_stage.interaction_layout(furniture_id) if is_instance_valid(item_stage) else {}


func furniture_hitboxes() -> Dictionary:
	if not is_instance_valid(item_stage):
		return {}
	var layout: Dictionary = item_stage.interaction_layout()
	if layout.is_empty():
		return {}
	var transform: Transform2D = get_global_transform().affine_inverse() * item_stage.get_global_transform()
	return {str(layout.slot_id):{"rect":transform * (layout.rect as Rect2), "furniture_id":str(layout.furniture_id)}}


func _draw_furniture_item(furniture_id: String, center: Vector2, color: Color) -> void:
	var final_texture: Texture2D = visual_texture("furniture:%s" % furniture_id)
	if final_texture != null:
		draw_texture_rect(final_texture, _fit_texture_rect(final_texture, Rect2(center - Vector2(48, 50), Vector2(96, 100))), false)
		return
	match furniture_id:
		"furn_bed_basic":
			draw_rect(Rect2(center + Vector2(-47,-17), Vector2(94,38)), color, true)
			draw_rect(Rect2(center + Vector2(-42,-13), Vector2(35,20)), FURNITURE_LIGHT, true)
			draw_line(center + Vector2(-43,20), center + Vector2(-43,39), FURNITURE_INK, 5.0)
			draw_line(center + Vector2(43,20), center + Vector2(43,39), FURNITURE_INK, 5.0)
		"furn_pillow_cloud":
			for offset: Vector2 in [Vector2(-23,5),Vector2(-7,-10),Vector2(13,-9),Vector2(28,7),Vector2(2,13)]:
				draw_circle(center + offset, 18.0, color)
			draw_arc(center + Vector2(0,4), 34.0, 0.15, PI - 0.15, 20, FURNITURE_INK, 2.0)
		"furn_nightlight_moon":
			draw_line(center + Vector2(0,10), center + Vector2(0,37), FURNITURE_INK, 5.0)
			draw_line(center + Vector2(-18,37), center + Vector2(18,37), FURNITURE_INK, 5.0)
			draw_arc(center + Vector2(0,-11), 27.0, -1.25, 1.55, 28, color, 13.0, true)
			draw_circle(center + Vector2(12,-12), 3.5, FURNITURE_LIGHT)
		"furn_blanket_roll":
			draw_rect(Rect2(center + Vector2(-41,-16), Vector2(72,34)), color, true)
			draw_circle(center + Vector2(31,1), 17.0, color.darkened(0.12))
			draw_circle(center + Vector2(31,1), 9.0, color.lightened(0.25))
			draw_line(center + Vector2(-27,-8), center + Vector2(12,-8), FURNITURE_LIGHT, 3.0)
		"furn_mirror_round":
			draw_circle(center + Vector2(0,-8), 31.0, color)
			draw_circle(center + Vector2(0,-8), 23.0, Color("#e9f3f5"))
			draw_line(center + Vector2(0,23), center + Vector2(0,40), FURNITURE_INK, 5.0)
			draw_line(center + Vector2(-18,40), center + Vector2(18,40), FURNITURE_INK, 5.0)
		"furn_bookshelf_low":
			draw_rect(Rect2(center + Vector2(-43,-31), Vector2(86,67)), color, true)
			for shelf_y: float in [-8.0, 16.0]:
				draw_line(center + Vector2(-38,shelf_y), center + Vector2(38,shelf_y), FURNITURE_INK, 4.0)
			for book_x: float in [-28.0,-16.0,3.0,17.0,29.0]:
				draw_rect(Rect2(center + Vector2(book_x,-25), Vector2(8,15 + fmod(absf(book_x),8.0))), FURNITURE_LIGHT.darkened(fmod(absf(book_x),15.0)/80.0), true)
		"furn_clock_sleepy":
			draw_circle(center, 29.0, color)
			draw_line(center, center + Vector2(0,-17), FURNITURE_INK, 4.0)
			draw_line(center, center + Vector2(13,5), FURNITURE_INK, 4.0)
			draw_arc(center + Vector2(-20,-25), 12.0, PI, TAU, 14, FURNITURE_INK, 4.0)
			draw_arc(center + Vector2(20,-25), 12.0, PI, TAU, 14, FURNITURE_INK, 4.0)
		"furn_robot_dock":
			draw_rect(Rect2(center + Vector2(-39,10), Vector2(78,22)), color, true)
			draw_rect(Rect2(center + Vector2(-24,-22), Vector2(48,34)), color.lightened(0.18), true)
			draw_colored_polygon(PackedVector2Array([center+Vector2(3,-17),center+Vector2(-8,-2),center+Vector2(1,-2),center+Vector2(-5,8),center+Vector2(14,-7),center+Vector2(5,-7)]), FURNITURE_LIGHT)
		"furn_table_snack":
			draw_rect(Rect2(center + Vector2(-45,-8), Vector2(90,15)), color, true)
			draw_line(center + Vector2(-34,7), center + Vector2(-34,39), FURNITURE_INK, 6.0)
			draw_line(center + Vector2(34,7), center + Vector2(34,39), FURNITURE_INK, 6.0)
			draw_circle(center + Vector2(5,-21), 12.0, FURNITURE_LIGHT)
		"furn_fridge_pink":
			draw_rect(Rect2(center + Vector2(-31,-46), Vector2(62,91)), color, true)
			draw_rect(Rect2(center + Vector2(-31,-46), Vector2(62,91)), FURNITURE_INK, false, 3.0)
			draw_line(center + Vector2(-30,-6), center + Vector2(30,-6), FURNITURE_LIGHT, 3.0)
			draw_line(center + Vector2(18,-31), center + Vector2(18,-16), FURNITURE_INK, 4.0)
		"furn_drink_crate":
			draw_rect(Rect2(center + Vector2(-40,-12), Vector2(80,45)), color.darkened(0.12), true)
			for bottle_x: float in [-25.0,0.0,25.0]:
				draw_rect(Rect2(center + Vector2(bottle_x-7,-31), Vector2(14,44)), color.lightened(0.17), true)
				draw_rect(Rect2(center + Vector2(bottle_x-4,-39), Vector2(8,9)), FURNITURE_LIGHT, true)
			draw_line(center + Vector2(-36,4), center + Vector2(36,4), FURNITURE_LIGHT, 4.0)
		"furn_kettle_round":
			draw_circle(center + Vector2(0,6), 28.0, color)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-25,-2),center+Vector2(-49,8),center+Vector2(-25,14)]), color)
			draw_arc(center + Vector2(8,-3), 31.0, -1.4, 0.45, 20, FURNITURE_INK, 5.0)
			draw_line(center + Vector2(-11,-25), center + Vector2(12,-25), FURNITURE_INK, 4.0)
		"furn_cookie_jar":
			draw_rect(Rect2(center + Vector2(-28,-29), Vector2(56,62)), Color(color,0.58), true)
			draw_rect(Rect2(center + Vector2(-33,-35), Vector2(66,10)), FURNITURE_INK, true)
			for offset: Vector2 in [Vector2(-13,-7),Vector2(12,2),Vector2(-4,20)]:
				draw_circle(center + offset, 8.0, color)
		"furn_fruit_bowl":
			for offset: Vector2 in [Vector2(-18,-9),Vector2(0,-17),Vector2(19,-7)]:
				draw_circle(center + offset, 14.0, color.lightened((offset.x+20.0)/150.0))
			draw_arc(center + Vector2(0,0), 35.0, 0.1, PI - 0.1, 24, FURNITURE_INK, 8.0)
		"furn_mini_oven":
			draw_rect(Rect2(center + Vector2(-43,-32), Vector2(86,68)), color, true)
			draw_rect(Rect2(center + Vector2(-34,-16), Vector2(68,40)), Color("#574b52"), true)
			draw_rect(Rect2(center + Vector2(-26,-9), Vector2(52,25)), Color("#f4d29b"), true)
			for knob_x: float in [-20.0,0.0,20.0]: draw_circle(center + Vector2(knob_x,-24), 4.0, FURNITURE_LIGHT)
		"furn_cleaning_robot":
			draw_set_transform(center, 0.0, Vector2(1.5,0.62))
			draw_circle(Vector2.ZERO, 31.0, color)
			draw_set_transform(Vector2.ZERO)
			draw_circle(center + Vector2(16,-5), 5.0, FURNITURE_LIGHT)
			draw_line(center + Vector2(-35,17), center + Vector2(-48,29), FURNITURE_INK, 3.0)
		"furn_treadmill":
			draw_rect(Rect2(center + Vector2(-50,20), Vector2(100,14)), color, true)
			draw_line(center + Vector2(35,20), center + Vector2(48,-35), FURNITURE_INK, 7.0)
			draw_line(center + Vector2(47,-35), center + Vector2(20,-35), FURNITURE_INK, 6.0)
			draw_circle(center + Vector2(-35,35), 7.0, FURNITURE_INK)
		"furn_yoga_mat":
			draw_rect(Rect2(center + Vector2(-48,-8), Vector2(83,24)), color, true)
			draw_circle(center + Vector2(36,4), 13.0, color.darkened(0.17))
			draw_circle(center + Vector2(36,4), 6.0, color.lightened(0.25))
		"furn_easel":
			draw_line(center + Vector2(-34,40), center + Vector2(-12,-39), FURNITURE_INK, 6.0)
			draw_line(center + Vector2(34,40), center + Vector2(12,-39), FURNITURE_INK, 6.0)
			draw_rect(Rect2(center + Vector2(-31,-36), Vector2(62,55)), FURNITURE_LIGHT, true)
			draw_circle(center + Vector2(7,-9), 13.0, color)
		"furn_soft_ball":
			draw_circle(center, 32.0, color)
			draw_arc(center, 23.0, -1.2, 1.2, 16, FURNITURE_LIGHT, 6.0)
			draw_arc(center, 16.0, 1.9, 4.0, 12, FURNITURE_INK, 3.0)
		"furn_tiny_drum":
			draw_rect(Rect2(center + Vector2(-31,-18), Vector2(62,48)), color, true)
			draw_arc(center + Vector2(0,-18), 31.0, 0.0, PI, 18, FURNITURE_LIGHT, 5.0)
			draw_line(center + Vector2(-26,-11), center + Vector2(26,23), FURNITURE_LIGHT, 4.0)
			draw_line(center + Vector2(26,-11), center + Vector2(-26,23), FURNITURE_LIGHT, 4.0)
			draw_line(center + Vector2(-25,-30), center + Vector2(26,-43), FURNITURE_INK, 4.0)
		"furn_camera":
			draw_rect(Rect2(center + Vector2(-39,-24), Vector2(78,53)), color, true)
			draw_circle(center + Vector2(4,2), 20.0, FURNITURE_INK)
			draw_circle(center + Vector2(4,2), 11.0, Color("#9fc5d3"))
			draw_rect(Rect2(center + Vector2(-24,-34), Vector2(25,12)), color.lightened(0.18), true)
		"furn_puzzle_box":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-37,-18),center+Vector2(9,-36),center+Vector2(40,-18),center+Vector2(-6,1)]), color.lightened(0.16))
			draw_colored_polygon(PackedVector2Array([center+Vector2(-37,-18),center+Vector2(-6,1),center+Vector2(-6,38),center+Vector2(-37,19)]), color.darkened(0.12))
			draw_colored_polygon(PackedVector2Array([center+Vector2(-6,1),center+Vector2(40,-18),center+Vector2(40,19),center+Vector2(-6,38)]), color)
			draw_string(ThemeDB.fallback_font, center + Vector2(5,22), "?", HORIZONTAL_ALIGNMENT_CENTER, 25, 22, FURNITURE_INK)
		"furn_cardboard_castle":
			draw_rect(Rect2(center + Vector2(-45,-24), Vector2(90,62)), color, true)
			for tower_x: float in [-34.0,34.0]:
				draw_rect(Rect2(center + Vector2(tower_x-13,-42), Vector2(26,35)), color.lightened(0.09), true)
				draw_colored_polygon(PackedVector2Array([center+Vector2(tower_x-14,-42),center+Vector2(tower_x,-58),center+Vector2(tower_x+14,-42)]), color)
			draw_arc(center + Vector2(0,38), 23.0, PI, TAU, 18, FURNITURE_INK, 7.0)
		"furn_plant_sprout":
			draw_rect(Rect2(center + Vector2(-24,5), Vector2(48,37)), color.darkened(0.12), true)
			draw_line(center + Vector2(0,5), center + Vector2(0,-42), FURNITURE_INK, 5.0)
			draw_set_transform(center + Vector2(-15,-31), -0.35, Vector2(1.5,0.75)); draw_circle(Vector2.ZERO, 13.0, color); draw_set_transform(Vector2.ZERO)
			draw_set_transform(center + Vector2(16,-43), 0.35, Vector2(1.5,0.75)); draw_circle(Vector2.ZERO, 14.0, color.lightened(0.08)); draw_set_transform(Vector2.ZERO)
		"furn_radio":
			draw_rect(Rect2(center + Vector2(-42,-24), Vector2(84,54)), color, true)
			draw_circle(center + Vector2(21,4), 17.0, FURNITURE_INK)
			for line_y: float in [-12.0,-2.0,8.0,18.0]: draw_line(center + Vector2(-31,line_y), center + Vector2(-5,line_y), FURNITURE_LIGHT, 3.0)
			draw_line(center + Vector2(-27,-29), center + Vector2(20,-48), FURNITURE_INK, 3.0)
		"furn_weather_charm":
			draw_line(center + Vector2(0,-46), center + Vector2(0,35), FURNITURE_INK, 4.0)
			draw_circle(center + Vector2(0,-18), 20.0, color)
			for offset: Vector2 in [Vector2(-18,14),Vector2(0,22),Vector2(18,14)]: draw_line(center + offset, center + offset + Vector2(-7,17), color, 4.0)
		"furn_window_cushion":
			draw_rect(Rect2(center + Vector2(-45,-18), Vector2(90,43)), color, true)
			draw_arc(center + Vector2(0,-16), 42.0, 0.15, PI - 0.15, 24, FURNITURE_LIGHT, 4.0)
			draw_circle(center + Vector2(-30,4), 4.0, FURNITURE_INK)
			draw_circle(center + Vector2(30,4), 4.0, FURNITURE_INK)
		"furn_telescope":
			draw_set_transform(center + Vector2(-4,-17), -0.35, Vector2(1.35,0.65)); draw_rect(Rect2(-35,-16,70,32), color, true); draw_set_transform(Vector2.ZERO)
			draw_circle(center + Vector2(39,-32), 13.0, color.lightened(0.18))
			draw_line(center + Vector2(0,0), center + Vector2(-23,41), FURNITURE_INK, 5.0)
			draw_line(center + Vector2(0,0), center + Vector2(27,41), FURNITURE_INK, 5.0)
		"furn_wind_chime":
			draw_line(center + Vector2(0,-45), center + Vector2(0,38), FURNITURE_INK, 4.0)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-29,-30),center+Vector2(29,-30),center+Vector2(18,-2),center+Vector2(-18,-2)]), color)
			for chime_x: float in [-17.0,0.0,17.0]: draw_line(center + Vector2(chime_x,-1), center + Vector2(chime_x,25 + absf(chime_x)*0.35), FURNITURE_LIGHT, 5.0)
			draw_circle(center + Vector2(0,39), 7.0, color.darkened(0.15))
		"furn_tea_tray":
			draw_rect(Rect2(center + Vector2(-43,17), Vector2(86,12)), color, true)
			draw_rect(Rect2(center + Vector2(-21,-9), Vector2(36,29)), FURNITURE_LIGHT, true)
			draw_arc(center + Vector2(17,5), 11.0, -PI*0.5, PI*0.5, 12, FURNITURE_INK, 4.0)
			draw_circle(center + Vector2(29,-3), 10.0, color.lightened(0.12))
		"furn_tiny_lamp":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-29,-6),center+Vector2(-17,-38),center+Vector2(17,-38),center+Vector2(29,-6)]), color)
			draw_line(center + Vector2(0,-6), center + Vector2(0,31), FURNITURE_INK, 5.0)
			draw_line(center + Vector2(-20,31), center + Vector2(20,31), FURNITURE_INK, 6.0)
		_:
			draw_circle(center, 28.0, color)


static func _fit_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds
	var scale: float = minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var fitted_size: Vector2 = texture_size * scale
	return Rect2(bounds.position + (bounds.size - fitted_size) * 0.5, fitted_size)


func furniture_at_position(room_position: Vector2) -> String:
	if not is_instance_valid(item_stage):
		return ""
	var point: Vector2 = item_stage.get_global_transform().affine_inverse() * (get_global_transform() * room_position)
	return item_stage.furniture_at_position(point, 26.0)
