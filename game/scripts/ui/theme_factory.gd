class_name ThemeFactory
extends RefCounted

const INK := Color("#2b3030")
const MUTED := Color("#72766c")
const ROSE := Color("#ef7390")
const ROSE_DARK := Color("#ac3959")
const CREAM := Color("#fffdf7")
const PANEL := Color("#fffdf7")
const PANEL_STRONG := Color("#ffffff")
const OUTLINE := Color("#e6e4d9")
const SAGE := Color("#60765b")
const SAGE_LIGHT := Color("#e8efe3")
const BODY_FONT: Font = preload("res://game/assets/interface/fonts/pig-ui-body.ttf")
const TITLE_FONT: Font = preload("res://game/assets/interface/fonts/pig-ui-title.ttf")


static func create(ui_scale: float = 1.0) -> Theme:
	var result := Theme.new()
	var scale: float = clampf(ui_scale, 0.8, 1.5)
	result.default_font = BODY_FONT
	result.default_font_size = roundi(16.0 * scale)
	result.set_type_variation("TitleLabel", "Label")
	result.set_type_variation("MetaLabel", "Label")
	result.set_type_variation("SectionLabel", "Label")
	result.set_font("font", "TitleLabel", TITLE_FONT)
	result.set_font_size("font_size", "TitleLabel", roundi(30.0 * scale))
	result.set_font_size("font_size", "SectionLabel", roundi(19.0 * scale))
	result.set_font_size("font_size", "MetaLabel", roundi(13.0 * scale))
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "MetaLabel", MUTED)
	for type: String in ["Button", "OptionButton", "CheckBox", "MenuButton"]:
		result.set_font_size("font_size", type, roundi(15.0 * scale))
		for state: String in ["", "_focus", "_hover", "_pressed", "_hover_pressed"]:
			result.set_color("font%s_color" % state, type, INK)
		result.set_color("font_disabled_color", type, Color("#817f76"))
		for state: String in ["normal", "hover", "pressed", "focus"]:
			result.set_color("icon_%s_color" % state, type, INK)
		result.set_color("icon_disabled_color", type, Color("#817f76"))
		result.set_constant("h_separation", type, roundi(8.0 * scale))
		result.set_constant("icon_max_width", type, roundi(22.0 * scale))
		result.set_stylebox("normal", type, _style(CREAM, OUTLINE, 8, 1, 14 * scale))
		result.set_stylebox("hover", type, _style(Color("#f9edee"), ROSE, 8, 1, 14 * scale))
		result.set_stylebox("pressed", type, _style(Color("#f6c8d1"), ROSE, 8, 1, 14 * scale))
		result.set_stylebox("disabled", type, _style(Color("#f0eee7"), Color.TRANSPARENT, 8, 0, 14 * scale))
		result.set_stylebox("focus", type, _focus(8, scale))
	for type: String in ["CheckBox", "MenuButton"]:
		result.set_stylebox("normal", type, _style(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 10 * scale))
		result.set_stylebox("disabled", type, _style(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 10 * scale))
		result.set_stylebox("pressed", type, _style(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 10 * scale))
		result.set_stylebox("hover_pressed", type, _style(SAGE_LIGHT, Color.TRANSPARENT, 8, 0, 10 * scale))
	for state: String in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled"]:
		result.set_icon(state, "CheckBox", UIAssets.scaled_icon("circle-check", roundi(22 * scale)))
	for state: String in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]:
		result.set_icon(state, "CheckBox", UIAssets.scaled_icon("circle", roundi(22 * scale)))
	result.set_color("checkbox_checked_color", "CheckBox", SAGE)
	result.set_color("checkbox_unchecked_color", "CheckBox", MUTED)
	result.set_icon("arrow", "OptionButton", UIAssets.scaled_icon("chevron-down", roundi(18 * scale)))
	result.set_color("icon_normal_color", "OptionButton", INK)
	result.set_constant("modulate_arrow", "OptionButton", 1)
	result.set_constant("arrow_margin", "OptionButton", roundi(12 * scale))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ROSE_DARK)
	result.set_color("selection_color", "LineEdit", Color("#f8d9df"))
	result.set_font_size("font_size", "LineEdit", roundi(17.0 * scale))
	result.set_stylebox("normal", "LineEdit", _style(PANEL_STRONG, OUTLINE, 8, 1, 13 * scale))
	result.set_stylebox("focus", "LineEdit", _focus(8, scale))
	result.set_constant("separation", "VBoxContainer", roundi(12.0 * scale))
	result.set_constant("separation", "HBoxContainer", roundi(12.0 * scale))
	result.set_constant("h_separation", "GridContainer", roundi(18.0 * scale))
	result.set_constant("v_separation", "GridContainer", roundi(18.0 * scale))
	result.set_stylebox("panel", "PanelContainer", _style(PANEL_STRONG, OUTLINE, 12, 1, 18 * scale))
	result.set_type_variation("PaperPanel", "PanelContainer")
	var paper: StyleBoxFlat = _style(PANEL, OUTLINE, 18, 1, 28 * scale)
	paper.shadow_color = Color("#19221b30")
	paper.shadow_size = roundi(18.0 * scale)
	paper.shadow_offset = Vector2(0, 8 * scale)
	result.set_stylebox("panel", "PaperPanel", paper)
	result.set_type_variation("HudPanel", "PanelContainer")
	result.set_stylebox("panel", "HudPanel", _style(CREAM, OUTLINE, 10, 1, 12 * scale))
	result.set_type_variation("DockPanel", "PanelContainer")
	var dock: StyleBoxFlat = _style(CREAM, OUTLINE, 14, 1, 8 * scale)
	dock.shadow_color = Color("#27252c22")
	dock.shadow_size = 8
	dock.shadow_offset = Vector2(0, 4)
	result.set_stylebox("panel", "DockPanel", dock)
	result.set_type_variation("InsetPanel", "PanelContainer")
	result.set_stylebox("panel", "InsetPanel", _style(Color("#f1f0e8"), Color.TRANSPARENT, 10, 0, 16 * scale))
	result.set_type_variation("CatalogCard", "PanelContainer")
	result.set_stylebox("panel", "CatalogCard", _style(PANEL_STRONG, OUTLINE, 10, 1, 14 * scale))
	result.set_type_variation("EquippedCard", "PanelContainer")
	result.set_stylebox("panel", "EquippedCard", _style(PANEL_STRONG, SAGE, 10, 2, 14 * scale))
	result.set_type_variation("DesktopHudPanel", "PanelContainer")
	result.set_stylebox("panel", "DesktopHudPanel", _style(CREAM, OUTLINE, 10, 1, 6 * scale))
	result.set_type_variation("DesktopButton", "Button")
	result.set_font_size("font_size", "DesktopButton", roundi(14 * scale))
	for state: String in ["normal", "pressed", "hover", "disabled"]:
		result.set_stylebox(state, "DesktopButton", _style(SAGE_LIGHT if state == "hover" else Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 6 * scale))
	_button_variant(result, "PrimaryButton", ROSE, Color("#ee5e80"), INK, scale)
	_button_variant(result, "SelectedButton", SAGE_LIGHT, Color("#dce8d4"), SAGE, scale)
	_button_variant(result, "QuietButton", Color.TRANSPARENT, Color("#eeede5"), INK, scale)
	_button_variant(result, "NavButton", Color.TRANSPARENT, Color("#eeede5"), MUTED, scale)
	result.set_stylebox("pressed", "NavButton", _style(SAGE_LIGHT, Color.TRANSPARENT, 8, 0, 12 * scale))
	result.set_color("font_pressed_color", "NavButton", SAGE)
	result.set_color("icon_pressed_color", "NavButton", SAGE)
	result.set_stylebox("hover_pressed", "NavButton", _style(SAGE_LIGHT, Color.TRANSPARENT, 8, 0, 12 * scale))
	for type: String in ["TabContainer", "TabBar"]:
		result.set_color("font_selected_color", type, SAGE)
		result.set_color("font_unselected_color", type, MUTED)
		result.set_stylebox("tab_selected", type, _style(SAGE_LIGHT, Color.TRANSPARENT, 6, 0, 11 * scale))
		result.set_stylebox("tab_unselected", type, _style(Color.TRANSPARENT, Color.TRANSPARENT, 6, 0, 11 * scale))
		result.set_stylebox("tab_hovered", type, _style(Color("#eeede5"), Color.TRANSPARENT, 6, 0, 11 * scale))
	result.set_stylebox("panel", "TabContainer", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0))
	result.set_stylebox("background", "ProgressBar", _style(Color("#e8e8dd"), Color.TRANSPARENT, 5, 0, 0))
	result.set_stylebox("fill", "ProgressBar", _style(SAGE, Color.TRANSPARENT, 5, 0, 0))
	result.set_color("font_color", "ProgressBar", INK)
	var track: StyleBoxFlat = _style(Color("#e5e6dc"), Color.TRANSPARENT, 3, 0, 0)
	track.content_margin_top = 3 * scale
	track.content_margin_bottom = 3 * scale
	result.set_stylebox("slider", "HSlider", track)
	result.set_stylebox("grabber_area", "HSlider", _style(SAGE, Color.TRANSPARENT, 3, 0, 0))
	result.set_stylebox("grabber_area_highlight", "HSlider", _style(ROSE, Color.TRANSPARENT, 3, 0, 0))
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		result.set_icon(state, "HSlider", UIAssets.scaled_icon("circle", roundi(18 * scale)))
	result.set_color("grabber_color", "HSlider", SAGE)
	result.set_color("grabber_highlight_color", "HSlider", ROSE_DARK)
	result.set_color("grabber_disabled_color", "HSlider", MUTED)
	for type: String in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", type, _style(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0, 3 * scale))
		result.set_stylebox("grabber", type, _style(Color("#c9cebd"), Color.TRANSPARENT, 4, 0, 4 * scale))
		result.set_stylebox("grabber_highlight", type, _style(SAGE, Color.TRANSPARENT, 4, 0, 4 * scale))
		result.set_stylebox("grabber_pressed", type, _style(SAGE, Color.TRANSPARENT, 4, 0, 4 * scale))
	for type: String in ["HSeparator", "VSeparator"]:
		var rule := _style(Color.TRANSPARENT, OUTLINE, 0, 0, 0)
		if type == "HSeparator":
			rule.border_width_top = 1
		else:
			rule.border_width_left = 1
		result.set_stylebox("separator", type, rule)
		result.set_constant("separation", type, roundi(10 * scale))
	result.set_stylebox("panel", "PopupMenu", _style(CREAM, OUTLINE, 10, 1, 12 * scale))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_stylebox("hover", "PopupMenu", _style(SAGE_LIGHT, Color.TRANSPARENT, 6, 0, 8 * scale))
	return result


static func _button_variant(result: Theme, type: String, background: Color, hover: Color, ink: Color, scale: float) -> void:
	result.set_type_variation(type, "Button")
	for state: String in ["normal", "pressed", "disabled"]:
		result.set_stylebox(state, type, _style(background, Color.TRANSPARENT, 8, 0, 14 * scale))
	result.set_stylebox("hover", type, _style(hover, Color.TRANSPARENT, 8, 0, 14 * scale))
	result.set_stylebox("hover_pressed", type, _style(hover, Color.TRANSPARENT, 8, 0, 14 * scale))
	result.set_stylebox("focus", type, _focus(8, scale))
	for state: String in ["", "_focus", "_hover", "_pressed", "_disabled"]:
		result.set_color("font%s_color" % state, type, ink)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.set_color("icon_%s_color" % state, type, ink)
	if type != "SelectedButton":
		result.set_stylebox("disabled", type, _style(Color("#f0eee7") if type == "PrimaryButton" else Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 14 * scale))
		result.set_color("font_disabled_color", type, MUTED)
		result.set_color("icon_disabled_color", type, MUTED)


static func _focus(radius: int, scale: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = _style(Color.TRANSPARENT, INK, radius, 2, 0)
	box.set_expand_margin_all(2 * scale)
	return box


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
