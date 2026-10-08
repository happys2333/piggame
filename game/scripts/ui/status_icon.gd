class_name StatusIcon
extends AssetCanvas

const STATUS_TOKENS := {
	"STATUS_SLEEPY": "ui:status_sleepy",
	"STATUS_HUNGRY": "ui:status_hungry",
	"STATUS_BORED": "ui:status_bored",
	"STATUS_ENERGETIC": "ui:status_energetic",
	"STATUS_CONTENT": "ui:status_content",
}
const INK := Color("#8f3f5c")
const BACKGROUND := Color("#fff0f3")
const ACCENT := Color("#d95f86")

var status_key: String = "STATUS_CONTENT"


func _ready() -> void:
	custom_minimum_size = Vector2(30, 30)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_accessible_text()
	resized.connect(queue_redraw)


func set_status(next_status_key: String) -> void:
	status_key = next_status_key if STATUS_TOKENS.has(next_status_key) else "STATUS_CONTENT"
	_update_accessible_text()
	queue_redraw()


func asset_token() -> String:
	return str(STATUS_TOKENS[status_key])


func _update_accessible_text() -> void:
	tooltip_text = tr(status_key)


func _draw() -> void:
	begin_visual_draw()
	var bounds := Rect2(Vector2.ZERO, size)
	var final_texture: Texture2D = visual_texture(asset_token())
	if final_texture != null:
		draw_texture_rect(final_texture, _fit_texture_rect(final_texture, bounds.grow(-1.0)), false)
		return
	var extent: float = minf(size.x, size.y)
	if extent <= 0.0:
		return
	var scale: float = extent / 32.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * scale)
	draw_circle(Vector2.ZERO, 14.0, BACKGROUND)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 32, Color("#dcb8bd"), 1.5, true)
	match status_key:
		"STATUS_SLEEPY":
			_draw_sleepy()
		"STATUS_HUNGRY":
			_draw_hungry()
		"STATUS_BORED":
			_draw_bored()
		"STATUS_ENERGETIC":
			_draw_energetic()
		_:
			_draw_content()
	draw_set_transform(Vector2.ZERO)


func _draw_sleepy() -> void:
	draw_arc(Vector2(-3.0, 0.0), 7.0, 0.15, PI - 0.15, 16, INK, 2.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(4.0, -8.0),
		Vector2(10.0, -8.0),
		Vector2(4.0, -2.0),
		Vector2(10.0, -2.0),
	]), ACCENT, 1.8, true)


func _draw_hungry() -> void:
	draw_arc(Vector2(0.0, 0.0), 8.0, 0.15, PI - 0.15, 18, INK, 2.2, true)
	draw_line(Vector2(-7.0, 3.0), Vector2(7.0, 3.0), INK, 2.2, true)
	draw_line(Vector2(-4.5, 6.0), Vector2(4.5, 6.0), INK, 2.0, true)
	for x: float in [-5.0, 0.0, 5.0]:
		draw_circle(Vector2(x, -6.0 + absf(x) * 0.25), 1.3, ACCENT)


func _draw_bored() -> void:
	draw_line(Vector2(-8.0, -4.0), Vector2(-2.0, -4.0), INK, 2.0, true)
	draw_line(Vector2(2.0, -4.0), Vector2(8.0, -4.0), INK, 2.0, true)
	draw_line(Vector2(-4.0, 6.0), Vector2(4.0, 6.0), INK, 2.0, true)
	draw_arc(Vector2.ZERO, 4.0, -0.2, PI * 1.6, 18, ACCENT, 1.5, true)


func _draw_energetic() -> void:
	var star := PackedVector2Array()
	for index: int in 10:
		var radius: float = 9.0 if index % 2 == 0 else 4.0
		var angle: float = -PI * 0.5 + index * PI / 5.0
		star.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(star, ACCENT)
	draw_polyline(star + PackedVector2Array([star[0]]), INK, 1.4, true)


func _draw_content() -> void:
	draw_circle(Vector2(-5.0, -3.0), 1.7, INK)
	draw_circle(Vector2(5.0, -3.0), 1.7, INK)
	draw_arc(Vector2(0.0, 0.0), 7.0, 0.25, PI - 0.25, 18, INK, 2.0, true)


static func _fit_texture_rect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds
	var scale: float = minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var fitted_size: Vector2 = texture_size * scale
	return Rect2(bounds.position + (bounds.size - fitted_size) * 0.5, fitted_size)
