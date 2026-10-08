class_name ThemeFactory
extends RefCounted

const INK := Color("#503b45")
const ROSE := Color("#d95f86")
const ROSE_DARK := Color("#b8466d")
const CREAM := Color("#fff8f1")
const PANEL := Color("#fffdf9e8")
const PANEL_STRONG := Color("#fffaf5")
const OUTLINE := Color("#dcb8bd")


static func create(ui_scale: float = 1.0) -> Theme:
	var result := Theme.new()
	var scale: float = clampf(ui_scale, 0.8, 1.5)
	result.default_font_size = roundi(18.0 * scale)
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_hover_color", "Button", ROSE_DARK)
	result.set_color("font_pressed_color", "Button", CREAM)
	result.set_color("font_color", "CheckBox", INK)
	result.set_color("font_color", "OptionButton", INK)
	result.set_color("font_color", "LineEdit", INK)
	result.set_font_size("font_size", "Button", roundi(16.0 * scale))
	result.set_font_size("font_size", "Label", roundi(17.0 * scale))
	result.set_font_size("font_size", "LineEdit", roundi(18.0 * scale))
	result.set_constant("separation", "VBoxContainer", roundi(10.0 * scale))
	result.set_constant("separation", "HBoxContainer", roundi(10.0 * scale))
	result.set_constant("h_separation", "GridContainer", roundi(12.0 * scale))
	result.set_constant("v_separation", "GridContainer", roundi(12.0 * scale))
	result.set_stylebox("panel", "PanelContainer", _style(PANEL, OUTLINE, 18, 2, 16 * scale))
	result.set_stylebox("normal", "Button", _style(CREAM, OUTLINE, 14, 2, 12 * scale))
	result.set_stylebox("hover", "Button", _style(Color("#fff0f2"), ROSE, 14, 2, 12 * scale))
	result.set_stylebox("pressed", "Button", _style(ROSE, ROSE_DARK, 14, 2, 12 * scale))
	result.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, ROSE, 14, 3, 12 * scale))
	result.set_stylebox("normal", "LineEdit", _style(PANEL_STRONG, OUTLINE, 12, 2, 10 * scale))
	result.set_stylebox("focus", "LineEdit", _style(PANEL_STRONG, ROSE, 12, 2, 10 * scale))
	result.set_stylebox("panel", "TabContainer", _style(PANEL_STRONG, OUTLINE, 14, 2, 12 * scale))
	result.set_stylebox("tab_unselected", "TabBar", _style(CREAM, OUTLINE, 10, 1, 9 * scale))
	result.set_stylebox("tab_selected", "TabBar", _style(Color("#ffdce5"), ROSE, 10, 2, 9 * scale))
	return result


static func _style(background: Color, border: Color, radius: int, width: int, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.72
	box.content_margin_bottom = margin * 0.72
	return box
