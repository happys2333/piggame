class_name PigVisualRig
extends RefCounted

const PATH: String = "res://game/data/catalog/pig_visual_rig.json"
const OUTFIT_PATH: String = "res://game/data/catalog/pig_outfit_rig.json"
const PARTS: Array[String] = ["left", "right", "mouth"]
const NO_POSE_MOTION: Dictionary = {}

static var _data: Dictionary = {}
static var _outfit_data: Dictionary = {}
static var _face_rects: Dictionary = {}
static var _fallback_texture: AtlasTexture


static func _ensure_loaded() -> void:
	if _data.is_empty():
		_data = JsonStore.read_object(PATH)
	if _outfit_data.is_empty():
		_outfit_data = JsonStore.read_object(OUTFIT_PATH)


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


static func ground_for(body_id: String) -> float:
	_ensure_loaded()
	return float(((_data.clips.get(body_id, _data.clips.body_base) as Dictionary).frames[0] as Dictionary).get("ground", 240.0))


static func canvas_for(body_id: String, frame: int = 0) -> Vector2:
	_ensure_loaded()
	var dimensions: Array = ((_data.clips.get(body_id, _data.clips.body_base) as Dictionary).frames[posmod(frame, 4)] as Dictionary).canvas as Array
	return Vector2(float(dimensions[0]), float(dimensions[1]))


static func fit_transform(dimensions: Vector2, body_id: String, frame: int = 0) -> Transform2D:
	var authored: Vector2 = canvas_for(body_id, frame)
	var uniform: float = minf(dimensions.x / authored.x, dimensions.y / authored.y) * 0.94
	return Transform2D(0.0, Vector2(uniform, uniform), 0.0, (dimensions - authored * uniform) * 0.5)


static func draw_motion_details(canvas: AssetCanvas, rect: Rect2, player: PigMotionPlayer) -> void:
	_ensure_loaded()
	var selected: Dictionary = player.selected()
	var body_id: String = str(selected.body_id)
	var face_id: String = str(_data.face_aliases.get(str(selected.face_id), str(selected.face_id)))
	var target_selected: bool = player.weight() >= 0.5
	var parts: Array = _rects_for(body_id, face_id)[0] as Array
	var unit: Vector2 = rect.size / Vector2(256, 256)
	for index: int in PARTS.size():
		var part: String = PARTS[index]
		if part == "mouth" and not motion_mouth_visible(player):
			continue
		var glyph: Texture2D = canvas.visual_texture("performance_face:%s_%s" % [face_id, part])
		if glyph == null:
			continue
		var placement: Rect2 = parts[index] as Rect2
		if part != "mouth":
			var height: float = placement.size.y * player.blink()
			placement.position.y += (placement.size.y - height) * 0.5
			placement.size.y = height
		_draw_motion_texture(canvas, glyph, placement, rect.position, unit, player, target_selected)
	var attire: Dictionary = selected.get("outfit", {}) as Dictionary
	var pose: Transform2D = player.pose_transform(rect.size, target_selected)
	pose.origin += rect.position
	_draw_outfit_with_pose(canvas, body_id, 0, attire, pose)


static func _draw_motion_texture(canvas: AssetCanvas, texture: Texture2D, placement: Rect2, origin: Vector2, unit: Vector2, player: PigMotionPlayer, target_selected: bool) -> void:
	var pose: Transform2D = player.pose_transform(unit * 256.0, target_selected)
	pose.origin += origin
	canvas.draw_set_transform_matrix(pose)
	canvas.draw_texture_rect(texture, placement, false)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func motion_detail_transform(placement: Rect2, origin: Vector2, unit: Vector2, player: PigMotionPlayer, target_selected: bool) -> Transform2D:
	var pose: Transform2D = player.pose_transform(unit * 256.0, target_selected)
	pose.origin += origin
	return pose * Transform2D(0.0, placement.size, 0.0, placement.position)


static func pose_motion_for(body_id: String, animation: String = "") -> Dictionary:
	_ensure_loaded()
	if not _data.clips.has(body_id):
		return NO_POSE_MOTION
	var profile: Dictionary = (_data.clips[body_id] as Dictionary).get("motion", NO_POSE_MOTION) as Dictionary
	if profile.is_empty() or animation in (profile.exclude_animations as Array):
		return NO_POSE_MOTION
	return profile


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
				var uniform: float = float(frame.scale) * float(glyph.get("relative_scale", 1.0))
				var origin := Vector2(float(anchor[0]), float(anchor[1])) + Vector2(float(glyph.offset[0]), float(glyph.offset[1])) * uniform
				parts.append(Rect2(origin, Vector2(float(glyph.size[0]), float(glyph.size[1])) * uniform))
			result.append(parts)
		_face_rects[key] = result
	return _face_rects[key] as Array


static func mouth_visible(body_id: String, face_id: String, frame_index: int = 0) -> bool:
	_ensure_loaded()
	face_id = str(_data.face_aliases.get(face_id, face_id))
	var clip: Dictionary = _data.clips.get(body_id, {})
	var face: Dictionary = _data.faces.get(face_id, {})
	if not bool(clip.get("mouth_visible", false)) or not bool(face.get("mouth_visible", false)):
		return false
	var frame: Dictionary = (clip.frames as Array)[posmod(frame_index, 4)]
	var coordinates: Array = frame.get("mouth_area", [])
	if coordinates.size() != 4:
		return false
	var area := Rect2(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]), float(coordinates[3]))
	return area.encloses((_rects_for(body_id, face_id)[posmod(frame_index, 4)] as Array)[2] as Rect2)


static func motion_mouth_visible(player: PigMotionPlayer) -> bool:
	if player.target.is_empty():
		return false
	if player.transitioning():
		for appearance: Dictionary in [player.source, player.target]:
			if not mouth_visible(str(appearance.body_id), str(appearance.face_id)):
				return false
	var selected: Dictionary = player.selected()
	return mouth_visible(str(selected.body_id), str(selected.face_id))


static func draw_pig(canvas: AssetCanvas, rect: Rect2, body_id: String, face_id: String, frame: int, outfit: Dictionary = {}, _animation: String = "") -> bool:
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
	var fitted: Transform2D = fit_transform(rect.size, body_id, frame)
	fitted.origin += rect.position
	canvas.draw_set_transform_matrix(fitted)
	canvas.draw_texture_rect(body, Rect2(Vector2.ZERO, canvas_for(body_id, frame)), false)
	var parts: Array = _rects_for(body_id, face_id)[posmod(frame, 4)] as Array
	var show_mouth: bool = mouth_visible(body_id, face_id, frame)
	for index: int in PARTS.size():
		if PARTS[index] == "mouth" and not show_mouth:
			continue
		var glyph: Texture2D = canvas.visual_texture("performance_face:%s_%s" % [face_id, PARTS[index]])
		if glyph != null:
			var placement: Rect2 = parts[index] as Rect2
			canvas.draw_texture_rect(glyph, placement, false)
	_draw_outfit_with_pose(canvas, body_id, frame, outfit, fitted)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
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
	canvas.draw_texture_rect(canvas.retain_visual_texture(_fallback_texture), _fit_texture(_fallback_texture, rect), false)
	return true


static func _draw_outfit_with_pose(canvas: AssetCanvas, body_id: String, frame: int, outfit: Dictionary, pose: Transform2D) -> void:
	if not outfit_visible(body_id, outfit):
		return
	var accessory: Texture2D = canvas.visual_texture("outfit:%s" % str(outfit.get("id", "")))
	if accessory == null:
		return
	canvas.draw_set_transform_matrix(pose * outfit_transform(body_id, frame, outfit, accessory))
	canvas.draw_texture_rect(accessory, Rect2(Vector2.ZERO, Vector2.ONE), false)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _fit_texture(texture: Texture2D, rect: Rect2) -> Rect2:
	var dimensions := Vector2(texture.get_size())
	var fitted: Vector2 = dimensions * minf(rect.size.x / dimensions.x, rect.size.y / dimensions.y)
	return Rect2(rect.position + (rect.size - fitted) * 0.5, fitted)


static func _outfit_rect(body_id: String, frame: int, outfit: Dictionary, accessory: Texture2D) -> Rect2:
	var transform: Transform2D = outfit_transform(body_id, frame, outfit, accessory)
	return Rect2(transform.origin, Vector2(transform.x.length(), transform.y.length()))


static func outfit_visible(body_id: String, outfit: Dictionary) -> bool:
	_ensure_loaded()
	var shape: Dictionary = _outfit_data.shapes.get(str(outfit.get("shape", "")), {})
	if shape.is_empty() or not _data.clips.has(body_id) or str(outfit.get("anchor", "")) not in ["head", "eyes"]:
		return false
	var pose: Dictionary = _outfit_data.poses.get(body_id, {})
	return not bool(_data.clips[body_id].integrated_outfit) and not str(shape.anchor) in (pose.get("hidden_anchors", []) as Array)


static func outfit_transform(body_id: String, frame: int, outfit: Dictionary, accessory: Texture2D) -> Transform2D:
	_ensure_loaded()
	var profile: Dictionary = _outfit_data.shapes[str(outfit.shape)]
	var head: Dictionary = (_data.clips[body_id].frames as Array)[posmod(frame, 4)]
	var nose_width: float = float(head.scale) * 60.0
	var anchor: Vector2 = snout_for(body_id, frame)
	var width: float = nose_width * float(profile.get("width", 1.0))
	var angle: float = float(profile.rotation)
	if str(profile.anchor) == "head":
		anchor.y = float(head.head_top)
	elif str(profile.anchor) == "eyes":
		var left: Array = head.landmarks.left
		var right: Array = head.landmarks.right
		var left_eye := Vector2(float(left[0]), float(left[1]))
		var right_eye := Vector2(float(right[0]), float(right[1]))
		anchor = (left_eye + right_eye) * 0.5
		width = left_eye.distance_to(right_eye) / float(profile.eye_spacing)
		angle += (right_eye - left_eye).angle()
	anchor += Vector2(float(profile.offset[0]), float(profile.offset[1])) * nose_width
	var dimensions := Vector2(width, width * accessory.get_height() / maxf(accessory.get_width(), 1.0))
	var pivot := Vector2(float(profile.pivot[0]), float(profile.pivot[1]))
	return Transform2D(angle, Vector2.ONE, 0.0, anchor) * Transform2D(0.0, dimensions, 0.0, -dimensions * pivot)
