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
