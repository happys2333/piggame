class_name FinalAssetCatalog
extends RefCounted

const MANIFEST_PATH: String = "res://game/data/catalog/final_asset_manifest.json"
const MAX_CACHED_ATLASES: int = 8

var enabled: bool = false
var _paths: Dictionary = {}
var _regions: Dictionary = {}
var _frames: Dictionary = {}
var _frame_trims: Dictionary = {}
var _placements: Dictionary = {}
var _full_characters: Dictionary = {}
var _texture_cache: Dictionary = {}
var _atlas_cache: Dictionary = {}
var _atlas_recency: Array[String] = []
var _texture_paths: Dictionary = {}


func load_manifest(path: String = MANIFEST_PATH, expected_tokens: Array[String] = []) -> Array[String]:
	_reset()
	var errors: Array[String] = []
	var data: Dictionary = JsonStore.read_object(path)
	if data.is_empty():
		errors.append("could not read %s" % path)
		return errors
	if int(data.get("schema_version", -1)) != 1:
		errors.append("final asset manifest schema_version must be 1")
	if not data.get("ready", null) is bool or not data.get("provided_by_user", null) is bool:
		errors.append("final asset readiness flags must be boolean")
		return errors
	var ready: bool = bool(data.ready)
	var provided: bool = bool(data.provided_by_user)
	var visual_ready: bool = data.get("visual_ready", false) is bool and data.get("visual_ready", false)
	if visual_ready and data.get("generation_authorized", false) != true:
		errors.append("generated visuals require explicit generation authorization")
		return errors
	if ready != provided:
		errors.append("final asset ready and provided_by_user flags must change together")
		return errors
	if not ready and not visual_ready:
		return errors
	var entries_value: Variant = data.get("entries", null)
	if not entries_value is Array:
		errors.append("final asset manifest entries must be an array")
		return errors
	for entry_index: int in (entries_value as Array).size():
		var entry_value: Variant = (entries_value as Array)[entry_index]
		if not entry_value is Dictionary:
			errors.append("final asset entry %d must be an object" % entry_index)
			continue
		var entry: Dictionary = entry_value as Dictionary
		var resource_path: String = str(entry.get("path", ""))
		if not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path):
			errors.append("final asset entry %d references a missing resource %s" % [entry_index, resource_path])
			continue
		var covers_value: Variant = entry.get("covers", null)
		if not covers_value is Array or (covers_value as Array).is_empty():
			errors.append("final asset entry %d must cover at least one token" % entry_index)
			continue
		var regions_value: Variant = entry.get("regions", {})
		if not regions_value is Dictionary:
			errors.append("final asset entry %d regions must be an object" % entry_index)
			continue
		var regions: Dictionary = regions_value as Dictionary
		var frames_value: Variant = entry.get("frames", {})
		var trims_value: Variant = entry.get("frame_trims", {})
		var placements_value: Variant = entry.get("placements", {})
		if not frames_value is Dictionary or not trims_value is Dictionary or not placements_value is Dictionary:
			errors.append("final asset entry %d frames and placements must be objects" % entry_index)
			continue
		for token_value: Variant in covers_value as Array:
			if not token_value is String or str(token_value).is_empty():
				errors.append("final asset entry %d contains an empty coverage token" % entry_index)
				continue
			var token: String = str(token_value)
			if _paths.has(token):
				errors.append("duplicate final asset coverage token %s" % token)
				continue
			_paths[token] = resource_path
			if entry.get("full_character", false) == true:
				_full_characters[token] = true
			if (frames_value as Dictionary).has(token):
				var frame_values: Variant = (frames_value as Dictionary)[token]
				var frame_regions: Array[Rect2] = []
				if frame_values is Array:
					for frame_value: Variant in frame_values as Array:
						var frame_region: Rect2 = _parse_region(frame_value)
						if frame_region.size.x > 0.0 and frame_region.size.y > 0.0:
							frame_regions.append(frame_region)
				if not frame_values is Array or frame_regions.is_empty() or frame_regions.size() != (frame_values as Array).size():
					errors.append("final asset frames for %s must be non-empty positive regions" % token)
				else:
					_frames[token] = frame_regions
			if (trims_value as Dictionary).has(token):
				var trim_values: Variant = (trims_value as Dictionary)[token]
				var trim_regions: Array[Rect2] = []
				if trim_values is Array and _frames.has(token) and (trim_values as Array).size() == (_frames[token] as Array).size():
					for trim_index: int in (trim_values as Array).size():
						var trim_region: Rect2 = _parse_region((trim_values as Array)[trim_index])
						var frame_region: Rect2 = (_frames[token] as Array)[trim_index] as Rect2
						if trim_region.has_area() and frame_region.encloses(trim_region):
							trim_regions.append(trim_region)
				if not trim_values is Array or not _frames.has(token) or trim_regions.size() != (_frames[token] as Array).size():
					errors.append("final asset trims for %s must match and stay inside their frames" % token)
				else:
					_frame_trims[token] = trim_regions
			if (placements_value as Dictionary).has(token):
				var placement: Rect2 = _parse_region((placements_value as Dictionary)[token])
				if placement.size.x <= 0.0 or placement.size.y <= 0.0:
					errors.append("final asset placement for %s must have positive size" % token)
				else:
					_placements[token] = placement
			if regions.has(token):
				var region: Rect2 = _parse_region(regions[token])
				if region.size.x <= 0.0 or region.size.y <= 0.0:
					errors.append("final asset region for %s must have positive width and height" % token)
				else:
					_regions[token] = region
		for region_token_value: Variant in regions:
			if region_token_value not in covers_value:
				errors.append("final asset region %s is not listed in covers" % str(region_token_value))
		for mapping: Dictionary in [frames_value as Dictionary, trims_value as Dictionary, placements_value as Dictionary]:
			for mapping_token: Variant in mapping:
				if mapping_token not in covers_value:
					errors.append("final asset mapping %s is not listed in covers" % str(mapping_token))
	var required_tokens: Array[String] = expected_tokens.duplicate() if not expected_tokens.is_empty() else expected_coverage_tokens()
	if visual_ready and not ready:
		var visual_tokens: Array[String] = []
		for required_token: String in required_tokens:
			if not required_token.begins_with("audio:"):
				visual_tokens.append(required_token)
		required_tokens = visual_tokens
	var required: Dictionary = {}
	for token: String in required_tokens:
		if token.is_empty() or required.has(token):
			errors.append("expected final asset coverage contains an empty or duplicate token %s" % token)
		else:
			required[token] = true
	for token: String in required:
		if not _paths.has(token):
			errors.append("missing final asset coverage token %s" % token)
	for token: String in _paths:
		if not required.has(token):
			errors.append("unknown final asset coverage token %s" % token)
	if not errors.is_empty():
		_reset()
		return errors
	enabled = true
	return errors


func path_for(token: String) -> String:
	return str(_paths.get(token, "")) if enabled else ""


func has_token(token: String) -> bool:
	return enabled and _paths.has(token)


func texture_for(token: String, frame_index: int = 0) -> Texture2D:
	if not enabled or not _paths.has(token):
		return null
	var frame_number: int = maxi(frame_index, 0) % (_frames[token] as Array).size() if _frames.has(token) else 0
	var resource_path: String = str(_paths[token])
	var region: Rect2 = (_frames[token] as Array)[frame_number] as Rect2 if _frames.has(token) else _regions.get(token, Rect2()) as Rect2
	var trimmed: Rect2 = (_frame_trims[token] as Array)[frame_number] as Rect2 if _frame_trims.has(token) else region
	var cache_key: String = "%s:%s:%s" % [resource_path, region, trimmed]
	if _texture_cache.has(cache_key):
		_touch_atlas(resource_path)
		return _texture_cache[cache_key] as Texture2D
	var resource: Resource = _atlas_cache.get(resource_path) as Resource
	if resource == null:
		resource = load(resource_path)
	if not resource is Texture2D:
		return null
	_atlas_cache[resource_path] = resource
	_touch_atlas(resource_path)
	var texture: Texture2D = resource as Texture2D
	if _regions.has(token) or _frames.has(token):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		if _frame_trims.has(token):
			var original_region: Rect2 = atlas.region
			atlas.region = trimmed
			atlas.margin = Rect2(atlas.region.position - original_region.position, original_region.size - atlas.region.size)
		atlas.filter_clip = true
		texture = atlas
	_texture_cache[cache_key] = texture
	_texture_paths[cache_key] = resource_path
	return texture


func _touch_atlas(resource_path: String) -> void:
	if not _atlas_recency.is_empty() and _atlas_recency[-1] == resource_path:
		return
	_atlas_recency.erase(resource_path)
	_atlas_recency.append(resource_path)
	while _atlas_recency.size() > MAX_CACHED_ATLASES:
		var evicted_path: String = _atlas_recency.pop_front()
		_atlas_cache.erase(evicted_path)
		for cache_key: String in _texture_paths.keys():
			if str(_texture_paths[cache_key]) == evicted_path:
				_texture_cache.erase(cache_key)
				_texture_paths.erase(cache_key)


func is_full_character(token: String) -> bool:
	return enabled and _full_characters.has(token)


func placement_for(token: String) -> Rect2:
	return _placements.get(token, Rect2(Vector2.ZERO, Vector2(280, 230))) as Rect2


static func expected_coverage_tokens() -> Array[String]:
	var result: Array[String] = []
	var catalogs := {
		"furniture": "res://game/data/furniture/furniture.json",
		"outfit": "res://game/data/catalog/outfits.json",
		"snack": "res://game/data/catalog/snacks.json",
		"expression": "res://game/data/expressions/expressions.json",
		"event": "res://game/data/events/events.json",
	}
	for kind: String in catalogs:
		for item: Dictionary in JsonStore.read_array(str(catalogs[kind])):
			result.append("%s:%s" % [kind, str(item.get("id", ""))])
			if kind == "furniture":
				var room_effect: String = str(item.get("room_effect", ""))
				if not room_effect.is_empty():
					result.append("room_effect:%s" % room_effect)
	for behavior: Dictionary in JsonStore.read_array("res://game/data/catalog/behaviors.json"):
		result.append("behavior:%s" % str(behavior.get("animation", "")))
	var performances: Dictionary = JsonStore.read_object(PigPerformanceLibrary.PATH)
	for clip: Dictionary in performances.get("clips", []) as Array:
		result.append("performance_body:%s" % str(clip.id))
	for face: Dictionary in performances.get("faces", []) as Array:
		for part: String in ["left", "right", "mouth"]:
			result.append("performance_face:%s_%s" % [str(face.id), part])
	for palette: String in ["rose", "mint", "night"]:
		result.append("room:%s" % palette)
	result.append("ui:app_icon")
	for frame: String in ["plain", "berry", "star"]:
		result.append("ui:photo_frame_%s" % frame)
	for status: String in ["sleepy", "hungry", "bored", "energetic", "content"]:
		result.append("ui:status_%s" % status)
	var audio: Dictionary = JsonStore.read_object("res://game/assets/audio/audio_manifest.json")
	for kind: String in ["music", "sfx"]:
		for entry: Dictionary in audio.get(kind, []) as Array:
			result.append("audio:%s" % str(entry.get("id", "")))
	var unique: Array[String] = []
	for token: String in result:
		if token not in unique:
			unique.append(token)
	return unique


func _reset() -> void:
	enabled = false
	_paths.clear()
	_regions.clear()
	_frames.clear()
	_frame_trims.clear()
	_placements.clear()
	_full_characters.clear()
	_texture_cache.clear()
	_atlas_cache.clear()
	_atlas_recency.clear()
	_texture_paths.clear()


static func _parse_region(value: Variant) -> Rect2:
	if value is Array and (value as Array).size() == 4:
		for component: Variant in value as Array:
			if not (component is int or component is float) or not is_finite(float(component)) or float(component) < 0.0:
				return Rect2()
		return Rect2(
			float((value as Array)[0]),
			float((value as Array)[1]),
			float((value as Array)[2]),
			float((value as Array)[3])
		)
	if value is Dictionary:
		var data: Dictionary = value as Dictionary
		return Rect2(
			float(data.get("x", 0.0)),
			float(data.get("y", 0.0)),
			float(data.get("width", 0.0)),
			float(data.get("height", 0.0))
		)
	return Rect2()
