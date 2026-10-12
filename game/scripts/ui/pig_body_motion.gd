class_name PigBodyMotion
extends AssetCanvas

var player: PigMotionPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	begin_visual_draw()
	if player == null or player.target.is_empty():
		return
	var body_id: String = str(player.selected().body_id)
	var texture: Texture2D = visual_texture("performance_body:%s" % body_id, 0)
	if texture == null:
		return
	draw_set_transform_matrix(player.pose_transform(size, player.weight() >= 0.5))
	draw_texture_rect(texture, Rect2(Vector2.ZERO, PigVisualRig.canvas_for(body_id)), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
