class_name ExpressionPortrait
extends AssetCanvas

var category: String = "happy"
var variant_index: int = 0
var unlocked: bool = true
var expression_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(112, 104)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(value_category: String, value_variant_index: int, value_unlocked: bool, value_expression_id: String = "") -> void:
	category = value_category if value_category in ["happy", "sleepy", "hungry", "wronged", "proud", "shocked"] else "happy"
	variant_index = clampi(value_variant_index, 0, 7)
	unlocked = value_unlocked
	expression_id = value_expression_id
	queue_redraw()


func visual_signature() -> String:
	return "%s:%d" % [category, variant_index]


func _draw() -> void:
	begin_visual_draw()
	var final_texture: Texture2D = visual_texture("expression:%s" % expression_id) if unlocked and not expression_id.is_empty() else null
	if final_texture != null:
		draw_texture_rect(final_texture, Rect2(Vector2.ZERO, size), false)
		return
	var drawing_scale: float = minf(size.x / 112.0, size.y / 104.0)
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * drawing_scale)
	if not unlocked:
		draw_circle(Vector2.ZERO, 42, Color("#8d7c84"))
		draw_colored_polygon(PackedVector2Array([Vector2(-38,-24),Vector2(-25,-51),Vector2(-11,-27)]), Color("#8d7c84"))
		draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, size * 0.5 + Vector2(-9, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#fff5ef"))
		return
	draw_set_transform(Vector2.ZERO)
	PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), "body_base", PigVisualRig.category_face(category, variant_index), 0)
