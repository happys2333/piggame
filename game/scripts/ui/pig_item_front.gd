class_name PigItemFront
extends AssetCanvas

var stage: PigItemStage


func _draw() -> void:
	begin_visual_draw()
	if is_instance_valid(stage):
		stage.draw_foreground(self)
