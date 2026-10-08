class_name PigVisualRig
extends RefCounted

const PATH: String = "res://game/data/catalog/pig_visual_rig.json"
const PARTS: Array[String] = ["left", "right", "mouth"]

static var _data: Dictionary = {}
static var _face_rects: Dictionary = {}
static var _fallback_texture: AtlasTexture


static func _ensure_loaded() -> void:
	if _data.is_empty():
		_data = JsonStore.read_object(PATH)


static func body_for(animation: String) -> String:
	_ensure_loaded()
	return str((_data.behaviors.get(animation, {}) as Dictionary).get("body_id", "body_base"))


static func stride_for(animation: String) -> int:
	_ensure_loaded()
	return int((_data.behaviors.get(animation, {}) as Dictionary).get("frame_stride", 2))


static func face_for(animation: String, expression_id: String = "") -> String:
	_ensure_loaded()
	if _data.expressions.has(expression_id):
		return str(_data.expressions[expression_id])
	return str((_data.behaviors.get(animation, {}) as Dictionary).get("face_id", "face_dot"))


static func category_face(category: String, variant: int = 0) -> String:
	_ensure_loaded()
	var faces: Array = _data.category_faces.get(category, _data.category_faces.happy) as Array
	return str(faces[clampi(variant, 0, faces.size() - 1)])


static func snout_for(body_id: String, frame: int) -> Vector2:
	_ensure_loaded()
	var frames: Array = (_data.clips.get(body_id, _data.clips.body_base) as Dictionary).frames as Array
	var anchor: Array = (frames[posmod(frame, 4)] as Dictionary).snout as Array
	return Vector2(float(anchor[0]), float(anchor[1]))


static func _rects_for(body_id: String, face_id: String) -> Array:
	var key: String = "%s:%s" % [body_id, face_id]
	if not _face_rects.has(key):
		var result: Array = []
		var frames: Array = (_data.clips[body_id] as Dictionary).frames as Array
		for frame: Dictionary in frames:
			var parts: Array[Rect2] = []
			for part: String in PARTS:
				var glyph: Dictionary = (_data.faces[face_id] as Dictionary)[part] as Dictionary
				var anchor: Array = (frame.landmarks as Dictionary)[part] as Array
				var origin := Vector2(float(anchor[0]), float(anchor[1])) + Vector2(float(glyph.offset[0]), float(glyph.offset[1])) * float(frame.scale)
				parts.append(Rect2(origin, Vector2(float(glyph.size[0]), float(glyph.size[1])) * float(frame.scale)))
			result.append(parts)
		_face_rects[key] = result
	return _face_rects[key] as Array


static func draw_pig(canvas: AssetCanvas, rect: Rect2, body_id: String, face_id: String, frame: int, outfit: Dictionary = {}, animation: String = "") -> bool:
	_ensure_loaded()
	if not _data.clips.has(body_id):
		body_id = "body_base"
	face_id = str(_data.face_aliases.get(face_id, face_id))
	if not _data.faces.has(face_id):
		face_id = "face_dot"
	var body: Texture2D = canvas.visual_texture("performance_body:%s" % body_id, frame)
	if body == null:
		return _draw_fallback(canvas, rect)
	_fallback_texture = null
	canvas.draw_texture_rect(body, rect, false)
	var unit: Vector2 = rect.size / Vector2(256, 256)
	var parts: Array = _rects_for(body_id, face_id)[posmod(frame, 4)] as Array
	var mouth_visible: bool = bool((_data.clips[body_id] as Dictionary).get("mouth_visible", true))
	for index: int in PARTS.size():
		if PARTS[index] == "mouth" and not mouth_visible:
			continue
		var glyph: Texture2D = canvas.visual_texture("performance_face:%s_%s" % [face_id, PARTS[index]])
		if glyph != null:
			var placement: Rect2 = parts[index] as Rect2
			canvas.draw_texture_rect(glyph, Rect2(rect.position + placement.position * unit, placement.size * unit), false)
	if not outfit.is_empty() and not bool((_data.clips[body_id] as Dictionary).integrated_outfit):
		_draw_outfit(canvas, rect, body_id, frame, outfit)
	var mapping: Dictionary = _data.behaviors.get(animation, {}) as Dictionary
	var prop_id: String = str(mapping.get("prop", ""))
	if not prop_id.is_empty():
		var prop: Texture2D = canvas.visual_texture("furniture:%s" % prop_id)
		if prop != null:
			canvas.draw_texture_rect(prop, Rect2(rect.position + rect.size * Vector2(0.72, 0.66), rect.size * Vector2(0.27, 0.31)), false)
	return true


static func _draw_fallback(canvas: AssetCanvas, rect: Rect2) -> bool:
	if _fallback_texture == null:
		var source: Texture2D = load("res://game/assets/final/generated/pighub_expressions.png") as Texture2D
		if source == null:
			return false
		_fallback_texture = AtlasTexture.new()
		_fallback_texture.atlas = source
		_fallback_texture.region = Rect2(0, 0, roundf(source.get_width() / 4.0), roundf(source.get_height() / 2.0))
		_fallback_texture.filter_clip = true
	canvas.draw_texture_rect(canvas.retain_visual_texture(_fallback_texture), rect, false)
	return true


static func _draw_outfit(canvas: AssetCanvas, rect: Rect2, body_id: String, frame: int, outfit: Dictionary) -> void:
	var accessory: Texture2D = canvas.visual_texture("outfit:%s" % str(outfit.get("id", "")))
	if accessory == null:
		return
	var snout: Vector2 = snout_for(body_id, frame)
	var head_frame: Dictionary = ((_data.clips[body_id] as Dictionary).frames as Array)[posmod(frame, 4)] as Dictionary
	var origin := Vector2(snout.x - 43.0, float(head_frame.head_top) - 28.0)
	var width: float = 112.0
	match str(outfit.get("shape", "")):
		"glasses", "star_glasses":
			origin = snout + Vector2(-30, -46)
			width = 80.0
		"scarf", "bow_tie":
			origin = snout + Vector2(17, 23)
			width = 55.0
		"cape", "hero_cape":
			origin = snout + Vector2(73, -31)
			width = 93.0
	var height: float = width * accessory.get_height() / maxf(accessory.get_width(), 1.0)
	var unit: Vector2 = rect.size / Vector2(256, 256)
	canvas.draw_texture_rect(accessory, Rect2(rect.position + origin * unit, Vector2(width, height) * unit), false)
