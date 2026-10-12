class_name UIAssets
extends RefCounted

static var _icons: Dictionary = {}
static var _scaled_icons: Dictionary = {}


static func scaled_icon(id: String, pixels: int) -> Texture2D:
	var key: String = "%s:%d" % [id, pixels]
	if not _scaled_icons.has(key):
		var source: Texture2D = icon(id)
		if source == null:
			return null
		var raster: Image = source.get_image()
		raster.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
		_scaled_icons[key] = ImageTexture.create_from_image(raster)
	return _scaled_icons[key] as Texture2D


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path: String = "res://game/assets/interface/lucide/%s.svg" % id
		_icons[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[id] as Texture2D


static func decorate(button: Button, id: String, variant: String = "") -> void:
	button.icon = scaled_icon(id, roundi(21 * GameSession.ui_scale))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", roundi(21 * GameSession.ui_scale))
	if not variant.is_empty():
		button.theme_type_variation = variant
