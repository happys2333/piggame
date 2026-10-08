class_name PigBehaviorPortrait
extends AssetCanvas

var behavior_animation: String = "idle"


func _ready() -> void:
	custom_minimum_size = Vector2(80, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	begin_visual_draw()
	PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), PigVisualRig.body_for(behavior_animation), PigVisualRig.face_for(behavior_animation), 0, {}, behavior_animation)
