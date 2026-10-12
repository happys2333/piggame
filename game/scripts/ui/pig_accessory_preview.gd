class_name PigAccessoryPreview
extends AssetCanvas

var outfit: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	begin_visual_draw()
	PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), "body_base", "face_dot", 0, outfit)
