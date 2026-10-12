class_name AssetCanvas
extends Control

var _drawn_textures: Array[Texture2D] = []


func begin_visual_draw() -> void:
	_drawn_textures.clear()


func visual_texture(token: String, frame_index: int = 0) -> Texture2D:
	var texture: Texture2D = GameSession.final_assets.texture_for(token, frame_index)
	return retain_visual_texture(texture)


func retain_visual_texture(texture: Texture2D) -> Texture2D:
	if texture != null:
		_drawn_textures.append(texture)
	return texture


func draw_cover_texture(texture: Texture2D, bounds: Rect2) -> void:
	var dimensions := Vector2(texture.get_size())
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var uniform: float = maxf(bounds.size.x / dimensions.x, bounds.size.y / dimensions.y)
	var source_size: Vector2 = bounds.size / uniform
	draw_texture_rect_region(texture, bounds, Rect2((dimensions - source_size) * 0.5, source_size))
