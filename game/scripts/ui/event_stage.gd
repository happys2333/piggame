class_name EventStage
extends AssetCanvas

const BODY := Color("#f7b5bc")
const BODY_LIGHT := Color("#ffc9ca")
const SNOUT := Color("#ed7892")
const INK := Color("#49363e")

var animation_id: String = "sit"
var event_id: String = ""
var event_category: String = "chapter"
var event_anchor: String = "center"
var event_props: Array[String] = []
var step_progress: float = 0.0
var _phase: float = 0.0
var _frame_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(640, 245)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_step(event: Dictionary, step: Dictionary, progress: float = 0.0) -> void:
	event_id = str(event.get("id", ""))
	event_category = str(event.get("category", "chapter"))
	event_anchor = str(event.get("anchor", "center"))
	if event_anchor not in ["center", "sleep", "snack", "activity", "window"]:
		event_anchor = "center"
	event_props.clear()
	for value: Variant in event.get("props", []):
		event_props.append(str(value))
	animation_id = str(step.get("animation", "sit"))
	step_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


func set_step_progress(value: float) -> void:
	step_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or GameSession.reduce_motion:
		return
	_frame_time += delta
	var step: float = VisualFramePolicy.FRAME_STEP * PigVisualRig.stride_for(animation_id)
	if _frame_time < step:
		return
	_phase += floorf(_frame_time / step) * VisualFramePolicy.FRAME_STEP
	_frame_time = fmod(_frame_time, step)
	queue_redraw()


func _draw() -> void:
	begin_visual_draw()
	var event_texture: Texture2D = visual_texture("event:%s" % event_id) if not event_id.is_empty() else null
	if event_texture != null:
		draw_texture_rect(event_texture, Rect2(Vector2.ZERO, size), false)
	else:
		var background: Color = {
			"food": Color("#fff0dc"), "sleep": Color("#e9e5f6"), "sport": Color("#e2f1ed"),
			"hobby": Color("#f8eadf"), "weather": Color("#dfeaf2"), "chapter": Color("#f8e5e8"),
		}.get(event_category, Color("#f8e5e8"))
		draw_rect(Rect2(Vector2.ZERO, size), background, true)
		draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), background.darkened(0.12), true)
		_draw_anchor_environment()
		_draw_event_props(false)
		_draw_prop()
	var frame_index: int = 0 if GameSession.reduce_motion else floori(_phase / VisualFramePolicy.FRAME_STEP) % 4
	var pig_center: Vector2 = _pig_center()
	PigVisualRig.draw_pig(self, Rect2(pig_center - Vector2(140, 115), Vector2(280, 230)), PigVisualRig.body_for(animation_id), PigVisualRig.face_for(animation_id), frame_index)
	if event_texture == null:
		_draw_event_props(true)


func _pig_center() -> Vector2:
	var anchor_x: float = {
		"sleep": 0.42,
		"snack": 0.45,
		"activity": 0.41,
		"window": 0.39,
		"center": 0.48,
	}.get(event_anchor, 0.48)
	var center := Vector2(size.x * anchor_x, size.y * 0.57)
	if animation_id in ["walk", "run", "robot_ride", "ball"]:
		center.x = lerpf(size.x * maxf(anchor_x - 0.20, 0.18), size.x * minf(anchor_x + 0.20, 0.68), step_progress)
	if animation_id in ["sleep", "bed_nap", "window_nap", "lie", "pillow_flop", "blanket_roll"]:
		center.y += 24.0
	if not GameSession.reduce_motion:
		center.y += sin(_phase * (7.0 if animation_id == "run" else 3.0)) * (5.0 if animation_id in ["walk", "run"] else 2.0)
	return center


func _draw_anchor_environment() -> void:
	match event_anchor:
		"sleep":
			var bed := Rect2(size.x * 0.10, size.y * 0.62, size.x * 0.47, size.y * 0.18)
			draw_rect(bed, Color("#d9b3c4"), true)
			draw_rect(Rect2(bed.position + Vector2(8, -22), Vector2(bed.size.x * 0.34, 36)), Color("#fff5ef"), true)
			draw_line(Vector2(bed.position.x, bed.end.y), Vector2(bed.position.x, size.y * 0.91), Color("#9d7558"), 7.0)
			draw_line(Vector2(bed.end.x, bed.end.y), Vector2(bed.end.x, size.y * 0.91), Color("#9d7558"), 7.0)
		"snack":
			var counter := Rect2(size.x * 0.62, size.y * 0.58, size.x * 0.31, size.y * 0.16)
			draw_rect(counter, Color("#d0a27c"), true)
			draw_rect(Rect2(counter.position + Vector2(0, -9), Vector2(counter.size.x, 12)), Color("#fff2db"), true)
			draw_rect(Rect2(counter.position + Vector2(12, 24), Vector2(counter.size.x - 24, counter.size.y - 29)), Color("#b98768"), false, 3.0)
		"activity":
			var rug := Rect2(size.x * 0.12, size.y * 0.72, size.x * 0.60, size.y * 0.15)
			draw_rect(rug, Color("#b8a4d566"), true)
			draw_rect(rug, Color("#8a77ad88"), false, 3.0)
		"window":
			_draw_window_frame()
		_:
			var rug := Rect2(size.x * 0.23, size.y * 0.73, size.x * 0.50, size.y * 0.13)
			draw_rect(rug, Color("#f2c3c755"), true)
			draw_rect(rug, Color("#b77b8c66"), false, 3.0)


func _window_rect() -> Rect2:
	return Rect2(size.x * 0.64, size.y * 0.10, size.x * 0.30, size.y * 0.46)


func _draw_window_frame() -> void:
	var rect := _window_rect()
	draw_rect(rect, Color("#b9d7e7"), true)
	draw_rect(rect, Color("#fffaf3"), false, 8.0)
	draw_line(rect.position + Vector2(rect.size.x * 0.5, 0), rect.position + Vector2(rect.size.x * 0.5, rect.size.y), Color("#fffaf3"), 6.0)
	draw_line(rect.position + Vector2(0, rect.size.y * 0.56), rect.position + Vector2(rect.size.x, rect.size.y * 0.56), Color("#fffaf3"), 6.0)


func _draw_event_props(foreground: bool) -> void:
	for index: int in event_props.size():
		var prop_id: String = event_props[index]
		if _is_atmospheric_prop(prop_id) == foreground:
			continue
		_draw_event_prop(prop_id, index, _prop_position(index))


func _is_atmospheric_prop(prop_id: String) -> bool:
	return prop_id in ["crumbs", "dream_bubble", "sun_patch", "paint_splotch", "music_notes", "rain", "sunrise", "leaf"]


func _prop_position(index: int) -> Vector2:
	var positions: Array[Vector2] = [
		Vector2(size.x * 0.76, size.y * 0.67),
		Vector2(size.x * 0.87, size.y * 0.70),
	]
	return positions[mini(index, positions.size() - 1)]


func _draw_event_prop(prop_id: String, index: int, p: Vector2) -> void:
	match prop_id:
		"moving_box":
			draw_rect(Rect2(p - Vector2(38, 34), Vector2(76, 68)), Color("#c9986e"), true)
			draw_line(p + Vector2(-38, -5), p + Vector2(38, -5), Color("#8d654c"), 4.0)
			draw_line(p + Vector2(0, -34), p + Vector2(0, -5), Color("#8d654c"), 4.0)
		"fridge":
			draw_rect(Rect2(p - Vector2(32, 62), Vector2(64, 124)), Color("#ee91ab"), true)
			draw_rect(Rect2(p - Vector2(32, 62), Vector2(64, 124)), Color("#7d5f68"), false, 4.0)
			draw_line(p + Vector2(-32, -5), p + Vector2(32, -5), Color("#fff6ef"), 4.0)
		"original_ice_pop":
			draw_rect(Rect2(p - Vector2(14, 42), Vector2(28, 58)), Color("#80c4cf"), true)
			draw_circle(p + Vector2(0, -40), 14, Color("#80c4cf"))
			draw_line(p + Vector2(0, 16), p + Vector2(0, 40), Color("#b98b5f"), 8.0)
		"cookie_jar":
			draw_rect(Rect2(p - Vector2(29, 35), Vector2(58, 70)), Color("#c8e1e2aa"), true)
			draw_rect(Rect2(p - Vector2(34, 42), Vector2(68, 12)), Color("#7d9ca3"), true)
			for offset: Vector2 in [Vector2(-14,-12), Vector2(12,-4), Vector2(-3,18)]:
				draw_circle(p + offset, 9, Color("#d2a468"))
		"crumbs":
			for offset: Vector2 in [Vector2(-24,22), Vector2(-5,12), Vector2(16,27), Vector2(31,17)]:
				draw_circle(p + offset, 4, Color("#9e744e"))
		"cocoa_cup", "warm_drink":
			draw_rect(Rect2(p - Vector2(24, 20), Vector2(43, 42)), Color("#f4d8bd"), true)
			draw_arc(p + Vector2(20, 1), 15, -PI * 0.5, PI * 0.5, 14, Color("#a87965"), 5.0, true)
			draw_arc(p + Vector2(-6, -28), 8, PI, TAU, 10, Color("#ffffff99"), 3.0, true)
		"snack_bag":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-31,-42),p+Vector2(31,-42),p+Vector2(26,38),p+Vector2(-25,38)]), Color("#efb061"))
			draw_circle(p, 13, Color("#fff0c7"))
		"single_pea":
			draw_circle(p, 13, Color("#76a968"))
			draw_arc(p, 23, 0.0, PI, 18, Color("#f9f0df"), 5.0, true)
		"yoga_mat":
			draw_rect(Rect2(p - Vector2(55, 12), Vector2(110, 24)), Color("#9c86c5"), true)
			draw_circle(p + Vector2(55, 0), 12, Color("#7865a2"))
		"alarm_clock":
			draw_circle(p, 31, Color("#ef8d91"))
			draw_line(p, p + Vector2(0, -19), INK, 4.0)
			draw_line(p, p + Vector2(15, 5), INK, 4.0)
		"cloud_pillow", "soft_cushion":
			for offset: Vector2 in [Vector2(-25,0), Vector2(0,-12), Vector2(25,0), Vector2(0,12)]:
				draw_circle(p + offset, 25, Color("#fff5ef"))
		"dream_bubble":
			draw_circle(p + Vector2(-42,-58), 6, Color("#ffffffaa"))
			draw_circle(p + Vector2(-25,-77), 10, Color("#ffffffbb"))
			draw_circle(p + Vector2(8,-100), 29, Color("#ffffffcc"))
		"sun_patch":
			draw_colored_polygon(PackedVector2Array([Vector2(size.x*.52,size.y*.72),Vector2(size.x*.88,size.y*.72),Vector2(size.x*.77,size.y*.96),Vector2(size.x*.40,size.y*.96)]), Color("#ffe5a966"))
		"treadmill":
			draw_rect(Rect2(p - Vector2(62, 10), Vector2(124, 20)), Color("#77859a"), true)
			draw_line(p + Vector2(50, -10), p + Vector2(72, -76), Color("#77859a"), 8.0)
		"towel":
			draw_rect(Rect2(p - Vector2(30, 20), Vector2(60, 40)), Color("#f6eee4"), true)
			draw_line(p + Vector2(-23,-4), p + Vector2(23,-4), Color("#d9c9bd"), 3.0)
		"soft_ball":
			draw_circle(p, 30, Color("#7fbac8"))
			draw_arc(p, 22, -1.2, 1.2, 14, Color("#f7d58a"), 6.0, true)
		"paper_medal":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-17,-45),p+Vector2(0,-5),p+Vector2(17,-45)]), Color("#c37786"))
			draw_circle(p + Vector2(0,10), 26, Color("#e5bd5f"))
		"easel":
			draw_line(p + Vector2(-38,44), p + Vector2(-12,-55), Color("#8f6b50"), 7.0)
			draw_line(p + Vector2(38,44), p + Vector2(12,-55), Color("#8f6b50"), 7.0)
			draw_rect(Rect2(p - Vector2(38, 49), Vector2(76, 72)), Color("#fff5e8"), true)
		"paint_splotch":
			for offset: Vector2 in [Vector2(-22,10),Vector2(0,0),Vector2(23,15),Vector2(8,29)]:
				draw_circle(p + offset, 11, Color("#d77c91aa"))
		"plant":
			draw_rect(Rect2(p - Vector2(28, 2), Vector2(56, 48)), Color("#c88768"), true)
			draw_line(p + Vector2(0,-2), p + Vector2(0,-58), Color("#5f8f5d"), 7.0)
			draw_circle(p + Vector2(-17,-48), 20, Color("#83b878"))
			draw_circle(p + Vector2(17,-61), 22, Color("#74a96b"))
		"watering_can":
			draw_rect(Rect2(p - Vector2(25, 17), Vector2(50, 34)), Color("#76a8bc"), true)
			draw_line(p + Vector2(-25,-5), p + Vector2(-52,-28), Color("#76a8bc"), 9.0)
			draw_arc(p + Vector2(10,-18), 20, PI, TAU, 16, Color("#5f8797"), 5.0)
		"radio":
			draw_rect(Rect2(p - Vector2(43, 29), Vector2(86, 58)), Color("#d69a72"), true)
			draw_circle(p + Vector2(22,5), 18, Color("#6f5962"))
			draw_line(p + Vector2(-28,-35), p + Vector2(17,-64), Color("#6f5962"), 4.0)
		"music_notes":
			for offset: Vector2 in [Vector2(-22,-66),Vector2(18,-91),Vector2(43,-54)]:
				draw_circle(p + offset, 7, Color("#826aa2"))
				draw_line(p + offset, p + offset + Vector2(0,-27), Color("#826aa2"), 4.0)
		"cleaning_robot":
			draw_set_transform(p, 0.0, Vector2(1.35, 0.52))
			draw_circle(Vector2.ZERO, 39, Color("#79889e"))
			draw_set_transform(Vector2.ZERO)
		"rain":
			var rect := _window_rect()
			draw_circle(rect.position + Vector2(rect.size.x*.30, 19), 22, Color("#8299ad"))
			for drop_index: int in 6:
				var x: float = rect.position.x + 18.0 + float(drop_index) * (rect.size.x - 36.0) / 5.0
				var y: float = rect.position.y + 37.0 + fmod(float(drop_index * 29), rect.size.y - 51.0)
				draw_line(Vector2(x,y), Vector2(x-8,y+27), Color("#6598b5cc"), 3.0)
		"sunrise":
			var rect := _window_rect()
			draw_circle(rect.position + Vector2(rect.size.x*.66, rect.size.y*.69), 30, Color("#f4bb63"))
			for ray: int in 7:
				var angle: float = float(ray) * PI / 6.0 + PI
				var center := rect.position + Vector2(rect.size.x*.66, rect.size.y*.69)
				draw_line(center + Vector2(cos(angle),sin(angle))*37, center + Vector2(cos(angle),sin(angle))*52, Color("#f4bb63aa"), 3.0)
		"wind_chime":
			draw_line(p + Vector2(0,-58), p + Vector2(0,24), Color("#857184"), 4.0)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-30,-38),p+Vector2(30,-38),p+Vector2(20,-2),p+Vector2(-20,-2)]), Color("#c6b4d9"))
			draw_circle(p + Vector2(0,31), 8, Color("#d39a77"))
		"leaf":
			for offset: Vector2 in [Vector2(-25,-42),Vector2(6,-25),Vector2(32,-56)]:
				draw_set_transform(p + offset, -0.4, Vector2(1.6, 0.75))
				draw_circle(Vector2.ZERO, 10, Color("#7ca66b"))
				draw_set_transform(Vector2.ZERO)
		"photo_album":
			draw_rect(Rect2(p - Vector2(42, 31), Vector2(84, 62)), Color("#b77d91"), true)
			draw_rect(Rect2(p - Vector2(28, 21), Vector2(56, 42)), Color("#fff1e7"), true)
			draw_circle(p, 10, Color("#ef9bac"))
		"thank_you_photo":
			draw_rect(Rect2(p - Vector2(40, 34), Vector2(80, 68)), Color("#fffaf3"), true)
			draw_rect(Rect2(p - Vector2(40, 34), Vector2(80, 68)), Color("#8e7680"), false, 4.0)
			draw_circle(p + Vector2(0,-4), 18, BODY)
			draw_circle(p + Vector2(-7,-7), 3, INK)
			draw_circle(p + Vector2(7,-7), 3, INK)
		_:
			var hue: float = fmod(float(abs(prop_id.hash())), 360.0) / 360.0
			draw_circle(p, 25, Color.from_hsv(hue, 0.32, 0.86))


func _draw_prop() -> void:
	match animation_id:
		"fridge":
			var rect := Rect2(size.x * 0.72, size.y * 0.19, 92, 145)
			draw_rect(rect, Color("#ee91ab"), true)
			draw_rect(rect, Color("#7d5f68"), false, 4.0)
			draw_line(rect.position + Vector2(0, 67), rect.position + Vector2(rect.size.x, 67), Color("#fff6ef"), 4.0)
			draw_circle(rect.position + Vector2(15, 55), 4, Color("#7d5f68"))
		"run":
			draw_rect(Rect2(size.x * 0.18, size.y * 0.76, size.x * 0.57, 14), Color("#77859a"), true)
			draw_line(Vector2(size.x * 0.72, size.y * 0.76), Vector2(size.x * 0.78, size.y * 0.35), Color("#77859a"), 8.0)
		"yoga", "blanket_roll":
			draw_rect(Rect2(size.x * 0.18, size.y * 0.72, size.x * 0.56, 20), Color("#b9a0df"), true)
		"table_snack", "cookie_guard", "tea", "drink":
			draw_rect(Rect2(size.x * 0.66, size.y * 0.61, 130, 18), Color("#c99b75"), true)
			draw_line(Vector2(size.x * 0.69, size.y * 0.66), Vector2(size.x * 0.69, size.y * 0.86), Color("#9d7558"), 10.0)
			draw_circle(Vector2(size.x * 0.75, size.y * 0.56), 18, Color("#e6bd77"))
		"mirror_pose":
			draw_circle(Vector2(size.x * 0.76, size.y * 0.35), 54, Color("#d9c5ec"))
			draw_circle(Vector2(size.x * 0.76, size.y * 0.35), 43, Color("#eff4f6"))
		"paint":
			draw_colored_polygon(PackedVector2Array([Vector2(size.x*.70,size.y*.78),Vector2(size.x*.78,size.y*.18),Vector2(size.x*.86,size.y*.78)]), Color("#9b765d"))
			draw_rect(Rect2(size.x * 0.72, size.y * 0.23, 78, 86), Color("#fff6e9"), true)
			draw_circle(Vector2(size.x * 0.78, size.y * 0.40), 20, Color("#d77c91"))
		"water_plant":
			draw_rect(Rect2(size.x * 0.74, size.y * 0.60, 65, 58), Color("#c88768"), true)
			draw_line(Vector2(size.x*.77,size.y*.60), Vector2(size.x*.72,size.y*.40), Color("#6d9d68"), 8.0)
			draw_circle(Vector2(size.x*.70,size.y*.38), 24, Color("#83b878"))
			draw_circle(Vector2(size.x*.76,size.y*.34), 25, Color("#74a96b"))
		"weather", "window_nap", "wind_chime":
			var rect := Rect2(size.x * 0.68, size.y * 0.14, 150, 115)
			draw_rect(rect, Color("#b9d7e7"), true)
			draw_rect(rect, Color("#fffaf3"), false, 8.0)
			for x: int in range(0, 4):
				draw_line(rect.position + Vector2(22 + x * 34, 18), rect.position + Vector2(6 + x * 34, 72), Color("#7eaec6aa"), 3.0)
		"robot_ride":
			draw_set_transform(Vector2(size.x * 0.50, size.y * 0.82), 0.0, Vector2(1.6, 0.55))
			draw_circle(Vector2.ZERO, 42, Color("#79889e"))
			draw_set_transform(Vector2.ZERO)
		"ball":
			draw_circle(Vector2(size.x * 0.77, size.y * 0.76), 31, Color("#7fbac8"))
		"alarm":
			draw_circle(Vector2(size.x * 0.76, size.y * 0.58), 38, Color("#ef8d91"))
			draw_line(Vector2(size.x*.76,size.y*.58), Vector2(size.x*.76,size.y*.36), INK, 4.0)
		_:
			draw_circle(Vector2(size.x * 0.78, size.y * 0.76), 24, Color("#fffaf388"))
