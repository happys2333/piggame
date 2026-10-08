class_name MainUI
extends Control

signal desktop_requested
signal screenshot_requested

const PHOTO_FRAME_COLORS := {
	"plain": [Color("#fff8f1"), Color("#d8bfc5")],
	"berry": [Color("#fff0f3"), Color("#c65d7b")],
	"star": [Color("#fff7d8"), Color("#d9a93f")],
}
const DEFAULT_PANEL_SIZE := Vector2(880, 570)
const OVERLAY_MARGIN: float = 16.0
const DEMO_LOCKED_EXPRESSION_PREVIEW_COUNT: int = 8

var _status_label: Label
var _status_icon: StatusIcon
var _name_label: Label
var _points_label: Label
var _album_button: Button
var _album_unread_dot: Panel
var _furniture_button: Button
var _snacks_button: Button
var _desktop_button: Button
var _tendency_button: Button
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _overlay: ColorRect
var _panel: PanelContainer
var _panel_title: Label
var _panel_scroll: ScrollContainer
var _panel_content: VBoxContainer
var _toast_tween: Tween
var _photo_lightbox: ColorRect
var _tutorial_highlight_style: StyleBoxFlat
var _pending_offline_summary: Dictionary = {}
var _life_plan_widgets: Dictionary = {}
var _life_plan_pause_button: Button
var _life_plan_summary: Label
var _displayed_companion_id: String = "pig_1"
var _focus_timer_label: Label
var _performance_navigation: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ThemeFactory.create(GameSession.ui_scale)
	_build_ui()
	GameSession.state_changed.connect(_refresh)
	GameSession.life_plan_changed.connect(_refresh_life_plan_album)
	_displayed_companion_id = GameSession.active_companion_id
	GameSession.companions_changed.connect(_on_companions_changed)
	GameSession.toast_requested.connect(_show_toast)
	GameSession.offline_summary_ready.connect(_show_offline_summary)
	GameSession.event_queued.connect(func(_id: String) -> void: _refresh())
	GameSession.ending_ready.connect(_on_automatic_ending)
	GameSession.demo_complete_ready.connect(_on_automatic_demo_complete)
	GameSession.desktop_companion_changed.connect(_on_companion_policy_changed)
	GameSession.focus_timer_changed.connect(_refresh_focus_timer)
	GameSession.focus_break_ready.connect(_on_focus_break_ready)
	GameSession.save_recovered.connect(func(_source: String) -> void: _show_toast("TOAST_SAVE_RECOVERED", {}))
	GameSession.save_failed.connect(func(_message: String) -> void: _show_toast("TOAST_SAVE_FAILED", {}))
	_refresh()
	_queue_startup_overlay()


func _queue_startup_overlay(explicit_request: bool = false) -> void:
	if not GameSession.last_offline_summary.is_empty():
		_pending_offline_summary = GameSession.last_offline_summary.duplicate(true)
	if not GameSession.last_save_error.is_empty():
		call_deferred("_show_toast", "TOAST_SAVE_FAILED", {})
	elif not GameSession.last_recovery_source.is_empty():
		call_deferred("_show_toast", "TOAST_SAVE_RECOVERED", {})
	if GameSession.demo_save_imported:
		call_deferred("_show_toast", "TOAST_DEMO_SAVE_IMPORTED", {})
	var startup_overlay_pending: bool = false
	if GameSession.save_recovery_required:
		startup_overlay_pending = true
		call_deferred("_show_save_recovery_required")
	elif GameSession.pig_state.tutorial_step == 0 and not GameSession.pig_state.tutorial_skipped:
		startup_overlay_pending = true
		call_deferred("_show_name_prompt")
	elif GameSession.pig_state.ending_unlocked and not GameSession.pig_state.ending_seen:
		startup_overlay_pending = true
		call_deferred("_show_ending" if explicit_request else "_on_automatic_ending")
	elif GameSession.should_show_demo_complete():
		startup_overlay_pending = true
		call_deferred("_show_demo_complete" if explicit_request else "_on_automatic_demo_complete")
	if not startup_overlay_pending and not _pending_offline_summary.is_empty():
		call_deferred("_show_pending_offline_summary")


func _unhandled_input(event: InputEvent) -> void:
	if GameSession.desktop_mode and not visible and event.is_action_pressed("pause"):
		return
	if event.is_action_pressed("pause") and is_instance_valid(_photo_lightbox):
		_close_photo_lightbox()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("screenshot"):
		screenshot_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _overlay.visible and not GameSession.save_recovery_required:
		_close_panel()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not event.canceled and event.device != InputEvent.DEVICE_ID_EMULATION:
		GameSession.note_explicit_companion_interaction()
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		GameSession.note_explicit_companion_interaction()
	elif event is InputEventKey and event.pressed and not event.echo:
		GameSession.note_explicit_companion_interaction()


func set_hud_visible(value: bool) -> void:
	for child: Node in get_children():
		child.visible = value


func _build_ui() -> void:
	var safe_margin := MarginContainer.new()
	safe_margin.name = "SafeMargin"
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 24)
	safe_margin.add_theme_constant_override("margin_top", 22)
	safe_margin.add_theme_constant_override("margin_right", 24)
	safe_margin.add_theme_constant_override("margin_bottom", 20)
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe_margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_margin.add_child(layout)
	layout.add_child(_build_top_bar())
	var flexible := Control.new()
	flexible.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flexible.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(flexible)
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_label = Label.new()
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_panel.add_child(_tutorial_label)
	layout.add_child(_tutorial_panel)
	layout.add_child(_build_bottom_bar())
	_build_toast()
	_build_overlay()


func _build_top_bar() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var identity := PanelContainer.new()
	identity.custom_minimum_size = Vector2(260, 86)
	var identity_text := VBoxContainer.new()
	identity.add_child(identity_text)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity_text.add_child(_name_label)
	var status_row := HBoxContainer.new()
	status_row.name = "StatusReadout"
	status_row.add_theme_constant_override("separation", 7)
	identity_text.add_child(status_row)
	_status_icon = StatusIcon.new()
	_status_icon.name = "CurrentStatusIcon"
	status_row.add_child(_status_icon)
	_status_label = Label.new()
	_status_label.name = "CurrentStatusText"
	_status_label.add_theme_color_override("font_color", ThemeFactory.ROSE_DARK)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_status_label)
	row.add_child(identity)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var actions := HBoxContainer.new()
	var points_panel := PanelContainer.new()
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 20)
	points_panel.add_child(_points_label)
	actions.add_child(points_panel)
	_album_button = _button("UI_ALBUM", _open_album)
	_album_unread_dot = Panel.new()
	_album_unread_dot.name = "AlbumUnreadDot"
	_album_unread_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_size: float = roundf(10.0 * clampf(GameSession.ui_scale, 0.8, 1.5))
	var dot_inset: float = roundf(5.0 * clampf(GameSession.ui_scale, 0.8, 1.5))
	_album_unread_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_album_unread_dot.offset_left = -dot_inset - dot_size
	_album_unread_dot.offset_top = dot_inset
	_album_unread_dot.offset_right = -dot_inset
	_album_unread_dot.offset_bottom = dot_inset + dot_size
	var unread_style := StyleBoxFlat.new()
	unread_style.bg_color = Color("#d95f86cc")
	unread_style.border_color = ThemeFactory.CREAM
	unread_style.set_border_width_all(1)
	unread_style.set_corner_radius_all(roundi(dot_size * 0.5))
	_album_unread_dot.add_theme_stylebox_override("panel", unread_style)
	_album_button.add_child(_album_unread_dot)
	actions.add_child(_album_button)
	actions.add_child(_button("UI_SCREENSHOT", func() -> void: screenshot_requested.emit()))
	var settings := _button("UI_SETTINGS", _open_settings)
	settings.name = "SettingsButton"
	actions.add_child(settings)
	row.add_child(actions)
	return row


func _build_bottom_bar() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	_furniture_button = _button("UI_FURNITURE", func() -> void: _open_catalog("furniture", "UI_FURNITURE"))
	row.add_child(_furniture_button)
	_snacks_button = _button("UI_SNACKS", func() -> void: _open_catalog("snacks", "UI_SNACKS"))
	row.add_child(_snacks_button)
	row.add_child(_button("UI_OUTFITS", func() -> void: _open_catalog("outfits", "UI_OUTFITS")))
	_tendency_button = _button("UI_TENDENCY", _open_tendency)
	row.add_child(_tendency_button)
	_desktop_button = _button("UI_DESKTOP", func() -> void: desktop_requested.emit())
	_desktop_button.disabled = GameSession.pig_state.familiarity_level < 2
	_desktop_button.tooltip_text = tr("UI_DESKTOP_LOCKED") if _desktop_button.disabled else tr("UI_DESKTOP_HINT")
	_tendency_button.disabled = GameSession.pig_state.familiarity_level < 5
	_tendency_button.tooltip_text = tr("UI_TENDENCY_LOCKED") if _tendency_button.disabled else tr("TENDENCY_INTRO")
	row.add_child(_desktop_button)
	return panel


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position = Vector2(-220, 110)
	_toast_panel.size = Vector2(440, 64)
	_toast_panel.modulate.a = 0.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(_toast_label)
	add_child(_toast_panel)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color("#4b354266")
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_top", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_right", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_bottom", int(OVERLAY_MARGIN))
	_overlay.add_child(safe_margin)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(center)
	_panel = PanelContainer.new()
	_set_panel_preferred_size(DEFAULT_PANEL_SIZE)
	center.add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var header := HBoxContainer.new()
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 28)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_panel_title)
	var close := _button("UI_CLOSE", _close_panel)
	header.add_child(close)
	outer.add_child(header)
	var divider := HSeparator.new()
	outer.add_child(divider)
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_panel_scroll)
	_panel_content = VBoxContainer.new()
	_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel_content)


func _refresh() -> void:
	if not is_instance_valid(_name_label) or not is_visible_in_tree():
		return
	_name_label.text = tr("UI_PIG_NAME_LEVEL").format({"name": GameSession.pig_display_name(), "level": GameSession.pig_state.familiarity_level})
	_name_label.tooltip_text = GameSession.pig_display_name()
	var status_key: String = GameSession.pig_state.status_key()
	_status_label.text = tr(status_key)
	_status_icon.set_status(status_key)
	_points_label.text = tr("UI_POINTS").format({"points": GameSession.pig_state.daily_points})
	var unread: int = GameSession.pig_state.pending_events.size() + GameSession.pig_state.summarized_events.size()
	_album_button.text = tr("UI_ALBUM")
	_album_unread_dot.visible = unread > 0
	_desktop_button.disabled = GameSession.pig_state.familiarity_level < 2
	_desktop_button.tooltip_text = tr("UI_DESKTOP_LOCKED") if _desktop_button.disabled else tr("UI_DESKTOP_HINT")
	_tendency_button.disabled = GameSession.pig_state.familiarity_level < 5
	_tendency_button.tooltip_text = tr("UI_TENDENCY_LOCKED") if _tendency_button.disabled else tr("TENDENCY_INTRO")
	_tutorial_panel.visible = not GameSession.pig_state.tutorial_skipped and GameSession.pig_state.tutorial_step < 7
	if _tutorial_panel.visible:
		var keys: Array[String] = ["TUTORIAL_NAME", "TUTORIAL_PET", "TUTORIAL_FEED", "TUTORIAL_FURNITURE", "TUTORIAL_ALBUM", "TUTORIAL_DESKTOP", "TUTORIAL_TENDENCY"]
		_tutorial_label.text = tr(keys[clampi(GameSession.pig_state.tutorial_step, 0, keys.size() - 1)])
	_refresh_tutorial_highlights()
	_refresh_life_plan_album()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and is_node_ready():
		_refresh()


func _refresh_tutorial_highlights() -> void:
	var step: int = GameSession.pig_state.tutorial_step if not GameSession.pig_state.tutorial_skipped else -1
	_set_tutorial_highlight(_snacks_button, step == 2)
	_set_tutorial_highlight(_furniture_button, step == 3)
	_set_tutorial_highlight(_album_button, step == 4)
	_set_tutorial_highlight(_desktop_button, step == 5)
	_set_tutorial_highlight(_tendency_button, step == 6)


func _set_tutorial_highlight(button: Button, enabled: bool) -> void:
	if not is_instance_valid(button):
		return
	if enabled:
		if _tutorial_highlight_style == null:
			_tutorial_highlight_style = StyleBoxFlat.new()
			_tutorial_highlight_style.bg_color = Color("#fff1b8")
			_tutorial_highlight_style.border_color = ThemeFactory.ROSE_DARK
			_tutorial_highlight_style.set_border_width_all(4)
			_tutorial_highlight_style.set_corner_radius_all(14)
			_tutorial_highlight_style.content_margin_left = 12.0
			_tutorial_highlight_style.content_margin_right = 12.0
			_tutorial_highlight_style.content_margin_top = 9.0
			_tutorial_highlight_style.content_margin_bottom = 9.0
		button.add_theme_stylebox_override("normal", _tutorial_highlight_style)
		button.add_theme_stylebox_override("hover", _tutorial_highlight_style)
		button.add_theme_stylebox_override("focus", _tutorial_highlight_style)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		button.remove_theme_stylebox_override("focus")


func _show_toast(text_key: String, values: Dictionary) -> void:
	if bool(values.get("companion_proactive", false)) and not GameSession.desktop_companion.proactive_allowed():
		return
	if not GameSession.desktop_companion.message_allowed():
		return
	if GameSession.save_recovery_required and text_key == "TOAST_SAVE_FAILED":
		return
	_toast_label.text = tr(text_key).format(values)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.2 * GameSession.bubble_duration_scale)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)


func _open_catalog(type: String, title_key: String) -> void:
	_show_panel(tr(title_key))
	var intro := Label.new()
	intro.text = tr("CATALOG_%s_INTRO" % type.to_upper())
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(intro)
	if type == "furniture":
		_add_palette_selector()
	elif type == "outfits":
		_add_outfit_reset()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_content.add_child(grid)
	var items: Array = GameSession.catalog.get_all(type)
	for value: Variant in items:
		var item: Dictionary = value as Dictionary
		grid.add_child(_catalog_card(type, item))


func _catalog_card(type: String, item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(385, 165)
	var content := VBoxContainer.new()
	card.add_child(content)
	var token_kind: String = str({"furniture":"furniture", "snacks":"snack", "outfits":"outfit"}.get(type, ""))
	var final_texture: Texture2D = GameSession.final_assets.texture_for("%s:%s" % [token_kind, str(item.get("id", ""))]) if not token_kind.is_empty() else null
	if final_texture != null:
		var preview := TextureRect.new()
		preview.texture = final_texture
		preview.custom_minimum_size = Vector2(108, 76)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(preview)
	var name := Label.new()
	name.text = tr(str(item.get("name_key", "")))
	name.add_theme_font_size_override("font_size", 20)
	content.add_child(name)
	var description := Label.new()
	description.text = tr(str(item.get("description_key", "")))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var level: int = int(item.get("min_level", 1))
	var price: int = int(item.get("price", 0))
	var locked: bool = GameSession.pig_state.familiarity_level < level
	var action := Button.new()
	if locked:
		action.text = tr("UI_UNLOCK_LEVEL").format({"level": level})
		action.disabled = true
	elif type == "furniture":
		var owned: bool = str(item.id) in GameSession.pig_state.owned_furniture
		action.text = tr("UI_PLACE") if owned else tr("UI_BUY").format({"price":price})
		action.pressed.connect(_furniture_action.bind(item))
	elif type == "snacks":
		action.text = tr("UI_FEED").format({"price":price})
		action.pressed.connect(_snack_action.bind(item))
	elif type == "outfits":
		var owned: bool = str(item.id) in GameSession.pig_state.owned_outfits
		var equipped: bool = GameSession.pig_state.current_outfit == str(item.id)
		action.text = tr("UI_EQUIPPED") if equipped else (tr("UI_EQUIP") if owned else tr("UI_BUY").format({"price":price}))
		action.disabled = equipped
		action.pressed.connect(_outfit_action.bind(item))
	content.add_child(action)
	return card


func _furniture_action(item: Dictionary) -> void:
	var id: String = str(item.id)
	if not id in GameSession.pig_state.owned_furniture:
		var can_afford: bool = GameSession.pig_state.daily_points >= int(item.get("price", 0))
		if not GameSession.purchase("furniture", id):
			if not can_afford:
				_show_toast("TOAST_NOT_ENOUGH_POINTS", {})
			else:
				_open_catalog("furniture", "UI_FURNITURE")
			return
	_open_furniture_slots(item)


func _add_palette_selector() -> void:
	var title := Label.new()
	title.text = tr("ROOM_PALETTE_TITLE")
	title.add_theme_font_size_override("font_size", 20)
	_panel_content.add_child(title)
	var row := HBoxContainer.new()
	var unlocked: Array[String] = GameSession.unlocked_room_palettes()
	for palette_id: String in GameSession.ROOM_PALETTES:
		var button := Button.new()
		button.text = tr("ROOM_PALETTE_%s" % palette_id.to_upper())
		button.disabled = palette_id == GameSession.pig_state.current_room_palette or not palette_id in unlocked
		if not palette_id in unlocked:
			button.tooltip_text = tr("ROOM_PALETTE_MINT_LOCKED" if palette_id == "mint" else "ROOM_PALETTE_NIGHT_LOCKED")
		button.pressed.connect(func() -> void:
			GameSession.set_room_palette(palette_id)
			_open_catalog("furniture", "UI_FURNITURE")
		)
		row.add_child(button)
	_panel_content.add_child(row)
	_panel_content.add_child(HSeparator.new())


func _open_furniture_slots(item: Dictionary) -> void:
	_show_panel(tr("FURNITURE_CHOOSE_SLOT"))
	var intro := Label.new()
	intro.text = tr("FURNITURE_CHOOSE_SLOT_DESC").format({"item": tr(str(item.get("name_key", "")))})
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(intro)
	for slot_id: String in GameSession.compatible_furniture_slots(str(item.get("id", ""))):
		var current_id: String = str(GameSession.pig_state.placed_furniture.get(slot_id, ""))
		var current: Dictionary = GameSession.catalog.get_item("furniture", current_id)
		var area_key: String = "AREA_%s" % slot_id.get_slice("_", 0).to_upper()
		var slot_number: int = int(slot_id.get_slice("_", 1))
		var button := Button.new()
		button.text = tr("FURNITURE_SLOT_LABEL").format({
			"area": tr(area_key),
			"number": slot_number,
			"current": tr(str(current.get("name_key", "FURNITURE_SLOT_EMPTY"))),
		})
		button.disabled = current_id == str(item.get("id", ""))
		button.pressed.connect(func() -> void:
			if GameSession.place_furniture(slot_id, str(item.get("id", ""))):
				_show_toast("TOAST_FURNITURE_PLACED", {"item": tr(str(item.get("name_key", "")))})
				_open_catalog("furniture", "UI_FURNITURE")
			else:
				_open_furniture_slots(item)
		)
		_panel_content.add_child(button)


func open_furniture_detail(furniture_id: String, slot_id: String) -> void:
	var item: Dictionary = GameSession.catalog.get_item("furniture", furniture_id)
	if item.is_empty():
		return
	_show_panel(tr(str(item.get("name_key", ""))))
	var description := Label.new()
	description.text = tr(str(item.get("description_key", "")))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(description)
	var location := Label.new()
	location.text = tr("FURNITURE_CURRENT_SLOT").format({
		"area": tr("AREA_%s" % slot_id.get_slice("_", 0).to_upper()),
		"number": int(slot_id.get_slice("_", 1)),
	})
	_panel_content.add_child(location)
	if not str(item.get("behavior_id", "")).is_empty():
		var invite := Button.new()
		invite.text = tr("FURNITURE_INVITE")
		invite.disabled = not GameSession.can_invite_to_furniture(furniture_id)
		invite.pressed.connect(func() -> void:
			if GameSession.invite_to_furniture(furniture_id):
				_close_panel()
		)
		_panel_content.add_child(invite)
	else:
		var passive := Label.new()
		passive.text = tr(
			"FURNITURE_ATMOSPHERE_ONLY"
			if str(item.get("category", "")) == "atmosphere"
			else "FURNITURE_DECORATION_ONLY"
		)
		passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_content.add_child(passive)
	if not str(item.get("reaction_key", "")).is_empty():
		var react := Button.new()
		react.name = "FurnitureReactionButton"
		react.text = tr("FURNITURE_REACT")
		react.pressed.connect(func() -> void:
			if GameSession.react_to_furniture(furniture_id):
				_close_panel()
		)
		_panel_content.add_child(react)
	var replace := Button.new()
	replace.text = tr("FURNITURE_REPLACE")
	replace.pressed.connect(func() -> void: _open_catalog("furniture", "UI_FURNITURE"))
	_panel_content.add_child(replace)


func _snack_action(item: Dictionary) -> void:
	var can_afford: bool = GameSession.pig_state.daily_points >= int(item.get("price", 0))
	if not GameSession.feed(str(item.id)) and not can_afford:
		_show_toast("TOAST_NOT_ENOUGH_POINTS", {})
	_open_catalog("snacks", "UI_SNACKS")


func _outfit_action(item: Dictionary) -> void:
	var id: String = str(item.id)
	if not id in GameSession.pig_state.owned_outfits:
		var can_afford: bool = GameSession.pig_state.daily_points >= int(item.get("price", 0))
		if not GameSession.purchase("outfits", id):
			if not can_afford:
				_show_toast("TOAST_NOT_ENOUGH_POINTS", {})
			_open_catalog("outfits", "UI_OUTFITS")
			return
	if not GameSession.equip_outfit(id):
		_open_catalog("outfits", "UI_OUTFITS")
		return
	_open_catalog("outfits", "UI_OUTFITS")


func _add_outfit_reset() -> void:
	var remove := Button.new()
	remove.name = "RemoveOutfitButton"
	remove.text = tr("UI_REMOVE_OUTFIT")
	remove.disabled = GameSession.pig_state.current_outfit.is_empty()
	remove.pressed.connect(func() -> void:
		if GameSession.equip_outfit(""):
			_open_catalog("outfits", "UI_OUTFITS")
	)
	_panel_content.add_child(remove)
	var action: Dictionary = GameSession.catalog.performances.outfit_action(GameSession.pig_state.current_outfit)
	if not action.is_empty():
		var perform: Button = _button("PERFORMANCE_OUTFIT_ACTION", func() -> void:
			if GameSession.perform_pig(str(action.id)):
				_close_panel()
		)
		perform.name = "OutfitPerformanceButton"
		_panel_content.add_child(perform)
	_panel_content.add_child(HSeparator.new())


func _open_tendency() -> void:
	if GameSession.pig_state.familiarity_level < 5:
		_show_toast("UI_TENDENCY_LOCKED", {})
		return
	_show_panel(tr("UI_TENDENCY"))
	var intro := Label.new()
	intro.text = tr("TENDENCY_INTRO")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(intro)
	var options := {
		"rest": ["TENDENCY_REST_NAME", "TENDENCY_REST_DESC"],
		"food": ["TENDENCY_FOOD_NAME", "TENDENCY_FOOD_DESC"],
		"active": ["TENDENCY_ACTIVE_NAME", "TENDENCY_ACTIVE_DESC"],
		"explore": ["TENDENCY_EXPLORE_NAME", "TENDENCY_EXPLORE_DESC"],
	}
	for id: String in options:
		var card := PanelContainer.new()
		var row := HBoxContainer.new()
		card.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := Label.new()
		name.text = tr(options[id][0])
		name.add_theme_font_size_override("font_size", 20)
		copy.add_child(name)
		var description := Label.new()
		description.text = tr(options[id][1])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(description)
		row.add_child(copy)
		var choose := Button.new()
		choose.text = tr("UI_SELECTED") if GameSession.pig_state.tendency == id else tr("UI_CHOOSE")
		choose.disabled = GameSession.pig_state.tendency == id
		choose.pressed.connect(_select_tendency.bind(id))
		row.add_child(choose)
		_panel_content.add_child(card)


func _select_tendency(id: String) -> void:
	GameSession.set_tendency(id)
	_open_tendency()


func _open_album() -> void:
	_show_panel(tr("UI_ALBUM"))
	GameSession.complete_tutorial_step(4)
	_refresh()
	var tabs := TabContainer.new()
	tabs.name = "AlbumTabs"
	tabs.custom_minimum_size.y = minf(480.0, maxf(320.0, get_viewport_rect().size.y - 140.0))
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_content.add_child(tabs)
	tabs.add_child(_expression_album())
	tabs.add_child(_event_album())
	tabs.add_child(_chapter_diary())
	tabs.add_child(_life_plan_album())


func open_album() -> void:
	_open_album()


func play_next_pending_memory() -> void:
	var event_id: String = ""
	if not GameSession.pig_state.pending_events.is_empty():
		event_id = GameSession.pig_state.pending_events[0]
	elif not GameSession.pig_state.summarized_events.is_empty():
		event_id = GameSession.pig_state.summarized_events[0]
	var event: Dictionary = GameSession.catalog.get_item("events", event_id)
	if event.is_empty():
		_open_album()
		return
	_play_event(event)


func _expression_album() -> Control:
	var page := VBoxContainer.new()
	page.name = tr("ALBUM_EXPRESSIONS")
	page.add_child(_photo_frame_selector())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for expression_index: int in GameSession.catalog.expressions.size():
		var expression: Dictionary = GameSession.catalog.expressions[expression_index]
		var unlocked: bool = str(expression.id) in GameSession.pig_state.unlocked_expressions
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(390, 178)
		var row := HBoxContainer.new()
		card.add_child(row)
		var portrait := ExpressionPortrait.new()
		portrait.custom_minimum_size = Vector2(118, 112)
		portrait.configure(str(expression.category), expression_index % 8, unlocked, str(expression.id))
		row.add_child(portrait)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var event: Dictionary = GameSession.catalog.get_item("events", str(expression.get("associated_event", "")))
		if unlocked:
			var favorite: bool = GameSession.pig_state.favorite_desktop_expression == str(expression.id)
			var name := Label.new()
			name.text = tr(str(expression.name_key))
			name.add_theme_font_size_override("font_size", 19)
			copy.add_child(name)
			var line := Label.new()
			line.text = tr(str(expression.line_key))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			copy.add_child(line)
			var first_seen: int = int(GameSession.pig_state.expression_unlock_dates.get(str(expression.id), 0))
			var date_value: String = GameClock.local_date_string(first_seen) if first_seen > 0 else tr("ALBUM_DATE_UNKNOWN")
			var date := Label.new()
			date.text = tr("ALBUM_EXPRESSION_DATE").format({"date": date_value})
			copy.add_child(date)
			var related := Label.new()
			related.text = tr("ALBUM_ASSOCIATED_EVENT").format({"event": tr(str(event.get("title_key", "")))})
			copy.add_child(related)
			var favorite_button := Button.new()
			favorite_button.text = ("★ " if favorite else "☆ ") + tr("ALBUM_DESKTOP_FAVORITE")
			favorite_button.disabled = favorite
			favorite_button.pressed.connect(_select_expression_favorite.bind(str(expression.id)))
			copy.add_child(favorite_button)
		else:
			var hidden_hint: bool = int(event.get("min_level", 1)) >= 8 and GameSession.pig_state.familiarity_level < 9
			var unknown := Label.new()
			unknown.text = tr("ALBUM_UNKNOWN_EXPRESSION")
			unknown.add_theme_font_size_override("font_size", 18)
			copy.add_child(unknown)
			var hint := Label.new()
			hint.text = tr("ALBUM_HIDDEN_HINT" if hidden_hint else str(expression.hint_key))
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			copy.add_child(hint)
		grid.add_child(card)
	page.add_child(scroll)
	return page


func _photo_frame_selector() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var title := Label.new()
	title.text = tr("PHOTO_FRAME_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var unlocked: Array[String] = GameSession.unlocked_photo_frames()
	for frame_id: String in GameSession.PHOTO_FRAMES:
		var button := Button.new()
		button.text = tr("PHOTO_FRAME_%s" % frame_id.to_upper())
		button.disabled = frame_id == GameSession.pig_state.current_photo_frame or frame_id not in unlocked
		if frame_id not in unlocked:
			button.tooltip_text = tr("PHOTO_FRAME_BERRY_LOCKED" if frame_id == "berry" else "PHOTO_FRAME_STAR_LOCKED")
		button.pressed.connect(func() -> void:
			if GameSession.set_photo_frame(frame_id):
				_open_album()
		)
		row.add_child(button)
	return panel


func _select_expression_favorite(expression_id: String) -> void:
	if GameSession.set_favorite_desktop_expression(expression_id):
		_open_album()


func _event_album() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = tr("ALBUM_MEMORIES")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for event: Dictionary in GameSession.catalog.events:
		var id: String = str(event.id)
		var discovered: bool = id in GameSession.pig_state.discovered_events
		var watched: bool = id in GameSession.pig_state.seen_events
		var waiting: bool = id in GameSession.pig_state.pending_events or id in GameSession.pig_state.summarized_events
		var card := PanelContainer.new()
		var row := HBoxContainer.new()
		card.add_child(row)
		var photo_record: Dictionary = GameSession.pig_state.life_photos.get(id, {}) as Dictionary
		var photo_path: String = GameSession.event_photo_path(id)
		if watched and not photo_path.is_empty():
			var image := Image.load_from_file(ProjectSettings.globalize_path(photo_path))
			if image != null and not image.is_empty():
				row.add_child(_framed_photo(image, Vector2(155, 92)))
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = tr(str(event.title_key)) if discovered else tr("ALBUM_UNKNOWN_MEMORY")
		copy.add_child(title)
		var summary := Label.new()
		summary.text = tr(str(event.summary_key)) if watched else tr("ALBUM_MEMORY_HINT")
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(summary)
		if watched and not photo_path.is_empty():
			var date := Label.new()
			date.text = tr("ALBUM_PHOTO_DATE").format({"date": GameClock.local_date_string(int(photo_record.get("captured_unix", 0)))})
			copy.add_child(date)
		row.add_child(copy)
		var actions := VBoxContainer.new()
		if waiting:
			var watch := Button.new()
			watch.text = tr("ALBUM_WATCH")
			watch.pressed.connect(_play_event.bind(event))
			actions.add_child(watch)
		elif watched:
			var replay := Button.new()
			replay.text = tr("ALBUM_REPLAY")
			replay.pressed.connect(_play_event.bind(event, false))
			actions.add_child(replay)
			if not photo_path.is_empty():
				var view := Button.new()
				view.text = tr("ALBUM_VIEW_PHOTO")
				view.pressed.connect(_view_photo.bind(id))
				actions.add_child(view)
				var export := Button.new()
				export.text = tr("ALBUM_EXPORT")
				export.pressed.connect(_export_photo.bind(id))
				actions.add_child(export)
		row.add_child(actions)
		list.add_child(card)
	return scroll


func _chapter_diary() -> Control:
	var page := VBoxContainer.new()
	page.name = tr("ALBUM_DIARY")
	var chapters: Array[Array] = [
		[1, "DIARY_CHAPTER_1"], [2, "DIARY_CHAPTER_2"], [4, "DIARY_CHAPTER_3"],
		[6, "DIARY_CHAPTER_4"], [10, "DIARY_CHAPTER_5"],
	]
	for chapter: Array in chapters:
		var label := Label.new()
		label.text = tr(str(chapter[1])) if GameSession.pig_state.familiarity_level >= int(chapter[0]) else tr("DIARY_LOCKED").format({"level": chapter[0]})
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(label)
	if GameSession.pig_state.ending_unlocked:
		var ending_copy := Label.new()
		ending_copy.text = tr("ENDING_FREE_COMPANION" if GameSession.pig_state.ending_seen else "ENDING_READY")
		ending_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(ending_copy)
		var ending_button := Button.new()
		ending_button.text = tr("ENDING_REPLAY")
		ending_button.pressed.connect(_show_ending)
		page.add_child(ending_button)
	return page


func _life_plan_album() -> Control:
	var page := ScrollContainer.new()
	page.name = tr("ALBUM_LIFE_PLANS")
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(content)
	content.add_child(_life_plan_label(tr("LIFE_PLAN_INTRO")))
	_life_plan_summary = _life_plan_label("")
	_life_plan_summary.name = "LifePlanSummary"
	content.add_child(_life_plan_summary)
	_life_plan_pause_button = _button("LIFE_PLAN_PAUSE", func() -> void: GameSession.pause_life_plan())
	_life_plan_pause_button.name = "LifePlanPauseButton"
	content.add_child(_life_plan_pause_button)
	_life_plan_widgets.clear()
	for plan: Dictionary in GameSession.catalog.life_plans:
		var card := PanelContainer.new()
		card.name = "LifePlanCard_%s" % str(plan.id)
		content.add_child(card)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(copy)
		var header := HBoxContainer.new()
		copy.add_child(header)
		var portrait := PigBehaviorPortrait.new()
		portrait.custom_minimum_size = Vector2(80, 72)
		portrait.behavior_animation = str(plan.animation)
		header.add_child(portrait)
		var introduction := VBoxContainer.new()
		introduction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(introduction)
		introduction.add_child(_life_plan_label(tr(str(plan.name_key))))
		introduction.add_child(_life_plan_label(tr(str(plan.description_key))))
		var progress := ProgressBar.new()
		progress.name = "LifePlanProgress_%s" % str(plan.id)
		progress.max_value = LifePlanRules.maximum_seconds(plan)
		progress.show_percentage = false
		progress.custom_minimum_size.y = 12
		copy.add_child(progress)
		var status: Label = _life_plan_label("")
		status.name = "LifePlanStatus_%s" % str(plan.id)
		copy.add_child(status)
		var furniture_names: Array[String] = []
		for furniture_id: String in plan.inspiration_furniture as Array:
			furniture_names.append(tr(str(GameSession.catalog.get_item("furniture", furniture_id).get("name_key", ""))))
		copy.add_child(_life_plan_label(tr("LIFE_PLAN_FURNITURE").format({"items":", ".join(furniture_names)})))
		var rate: Label = _life_plan_label("")
		copy.add_child(rate)
		var notes: Array[Label] = []
		for entry: Dictionary in plan.entries as Array:
			var note: Label = _life_plan_label("")
			note.name = "LifePlanEntry_%s" % str(entry.id)
			copy.add_child(note)
			notes.append(note)
		var choose: Button = _button("LIFE_PLAN_CHOOSE", _select_life_plan.bind(str(plan.id)))
		choose.name = "LifePlanChoose_%s" % str(plan.id)
		copy.add_child(choose)
		_life_plan_widgets[str(plan.id)] = {"progress":progress, "status":status, "rate":rate, "notes":notes, "choose":choose}
	_refresh_life_plan_album()
	return page


func _life_plan_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _select_life_plan(plan_id: String) -> void:
	GameSession.select_life_plan(plan_id)


func _refresh_life_plan_album() -> void:
	if not is_instance_valid(_life_plan_summary) or not is_visible_in_tree():
		return
	_life_plan_summary.text = tr("LIFE_PLAN_COLLECTION").format({"count":GameSession.pig_state.life_plan_entries.size(), "total":GameSession.catalog.life_plans.size() * 3})
	_life_plan_pause_button.disabled = GameSession.pig_state.active_life_plan.is_empty()
	for plan: Dictionary in GameSession.catalog.life_plans:
		var id: String = str(plan.id)
		if not _life_plan_widgets.has(id):
			continue
		var widgets: Dictionary = _life_plan_widgets[id] as Dictionary
		var snapshot: Dictionary = GameSession.life_plan_snapshot(id)
		(widgets.progress as ProgressBar).value = float(snapshot.progress)
		(widgets.status as Label).text = tr("LIFE_PLAN_PROGRESS").format({"done":snapshot.earned, "total":3, "percent":floori(float(snapshot.progress) / float(snapshot.maximum) * 100.0)})
		(widgets.rate as Label).text = tr("LIFE_PLAN_RATE").format({"rate":roundi(float(snapshot.room_rate) * 100.0)})
		var notes: Array[Label] = widgets.notes as Array[Label]
		for index: int in (plan.entries as Array).size():
			var entry: Dictionary = (plan.entries as Array)[index] as Dictionary
			var written: bool = str(entry.id) in (snapshot.entries as Array)
			notes[index].text = tr("LIFE_PLAN_ENTRY_WRITTEN" if written else "LIFE_PLAN_ENTRY_WAITING").format({"title":tr(str(entry.title_key)), "note":tr(str(entry.text_key)) if written else "", "minutes":roundi(float(entry.seconds) / 60.0)})
		var choose: Button = widgets.choose as Button
		choose.disabled = not bool(snapshot.unlocked) or bool(snapshot.active) or bool(snapshot.complete)
		if not bool(snapshot.unlocked):
			choose.text = tr("UI_UNLOCK_LEVEL").format({"level":plan.min_level})
		elif bool(snapshot.complete):
			choose.text = tr("LIFE_PLAN_COMPLETE")
		elif bool(snapshot.active):
			choose.text = tr("LIFE_PLAN_ACTIVE")
		else:
			choose.text = tr("LIFE_PLAN_CONTINUE" if float(snapshot.progress) > 0.0 else "LIFE_PLAN_CHOOSE")


func _play_event(event: Dictionary, grant_rewards: bool = true) -> void:
	_close_panel()
	var prepared: Dictionary = GameSession.prepare_event(str(event.get("id", "")))
	if prepared.is_empty():
		return
	var viewer := EventViewer.new()
	viewer.play(prepared, grant_rewards)
	viewer.photo_captured.connect(func(event_id: String, image: Image) -> void:
		var result: Dictionary = GameSession.complete_event_with_photo(
			event_id,
			image,
			str(prepared.get("resolved_branch_id", ""))
		)
		if result.is_empty():
			_show_toast("TOAST_SCREENSHOT_FAILED", {})
		elif result.get("save_error", FAILED) == OK:
			_show_toast("TOAST_PHOTO_ADDED", {})
	)
	add_child(viewer)
	viewer.finished.connect(_on_event_playback_finished.bind(grant_rewards))


func _on_event_playback_finished(grant_rewards: bool) -> void:
	if grant_rewards:
		_refresh()
	if not _pending_offline_summary.is_empty():
		call_deferred("_show_pending_offline_summary")


func _export_photo(event_id: String) -> void:
	var path: String = GameSession.export_event_photo(event_id)
	_show_toast("TOAST_PHOTO_EXPORTED" if not path.is_empty() else "TOAST_SCREENSHOT_FAILED", {"path": path})


func _view_photo(event_id: String) -> void:
	var event: Dictionary = GameSession.catalog.get_item("events", event_id)
	var photo_path: String = GameSession.event_photo_path(event_id)
	if event.is_empty() or photo_path.is_empty():
		_show_toast("TOAST_SCREENSHOT_FAILED", {})
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(photo_path))
	if image == null or image.is_empty():
		_show_toast("TOAST_SCREENSHOT_FAILED", {})
		return
	_show_photo_lightbox(image)


func _show_photo_lightbox(image: Image) -> void:
	_close_panel()
	_close_photo_lightbox()
	_photo_lightbox = ColorRect.new()
	_photo_lightbox.color = Color("#1d171b")
	_photo_lightbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo_lightbox.mouse_filter = Control.MOUSE_FILTER_STOP
	_photo_lightbox.gui_input.connect(func(input: InputEvent) -> void:
		if input is InputEventScreenTouch and input.pressed and not input.canceled:
			_close_photo_lightbox()
		elif input is InputEventMouseButton and input.device != InputEvent.DEVICE_ID_EMULATION and input.button_index == MOUSE_BUTTON_LEFT and input.pressed:
			_close_photo_lightbox()
	)
	add_child(_photo_lightbox)
	_photo_lightbox.move_to_front()
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_top", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_right", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_bottom", int(OVERLAY_MARGIN))
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_lightbox.add_child(safe_margin)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_margin.add_child(center)
	center.add_child(_framed_photo(image, _fit_overlay_size(Vector2(900, 560), 72.0)))


func _framed_photo(image: Image, minimum_size: Vector2) -> Control:
	var frame_id: String = GameSession.pig_state.current_photo_frame
	if frame_id not in PHOTO_FRAME_COLORS:
		frame_id = "plain"
	var colors: Array = PHOTO_FRAME_COLORS[frame_id] as Array
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0] as Color
	style.border_color = colors[1] as Color
	style.set_border_width_all(10 if frame_id == "star" else (8 if frame_id == "berry" else 5))
	style.set_corner_radius_all(12 if frame_id == "star" else 8)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var photo := TextureRect.new()
	photo.texture = ImageTexture.create_from_image(image)
	photo.custom_minimum_size = minimum_size
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(photo)
	var final_frame: Texture2D = GameSession.final_assets.texture_for("ui:photo_frame_%s" % frame_id)
	if final_frame != null:
		var frame_overlay := TextureRect.new()
		frame_overlay.texture = final_frame
		frame_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame_overlay)
	return panel


func _close_photo_lightbox() -> void:
	if is_instance_valid(_photo_lightbox):
		_photo_lightbox.queue_free()
	_photo_lightbox = null


func _show_ending() -> void:
	_show_panel(tr("ENDING_TITLE"), false)
	_set_panel_preferred_size(Vector2(820, 640))
	var photo_path: String = GameSession.event_photo_path("event_ordinary_day")
	if not photo_path.is_empty():
		var image := Image.load_from_file(ProjectSettings.globalize_path(photo_path))
		if image != null and not image.is_empty():
			_panel_content.add_child(_framed_photo(image, Vector2(680, 260)))
	var thanks := Label.new()
	thanks.text = tr("ENDING_THANKS").format({"name": GameSession.pig_display_name()})
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thanks.add_theme_font_size_override("font_size", 25)
	_panel_content.add_child(thanks)
	var credits := Label.new()
	credits.text = tr("ENDING_CREDITS")
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(credits)
	var continue_button := Button.new()
	continue_button.text = tr("ENDING_CONTINUE")
	continue_button.pressed.connect(func() -> void:
		if GameSession.mark_ending_seen():
			_close_panel()
	)
	_panel_content.add_child(continue_button)


func _show_demo_complete() -> void:
	_show_demo_complete_for_profile("")


func _show_demo_complete_for_profile(for_profile: String) -> void:
	_show_panel(tr("DEMO_COMPLETE_TITLE"))
	_set_panel_preferred_size(Vector2(760, 500))
	var body := Label.new()
	body.text = tr("DEMO_COMPLETE_BODY")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 22)
	_panel_content.add_child(body)
	var silhouettes := Label.new()
	silhouettes.text = tr("DEMO_COMPLETE_SILHOUETTES")
	silhouettes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouettes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(silhouettes)
	var preview := PanelContainer.new()
	preview.name = "DemoLockedAlbumPreview"
	_panel_content.add_child(preview)
	var grid := GridContainer.new()
	grid.name = "DemoLockedExpressionSilhouettes"
	grid.columns = DEMO_LOCKED_EXPRESSION_PREVIEW_COUNT
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.add_child(grid)
	var categories: Array[String] = ["happy", "sleepy", "hungry", "wronged", "proud", "shocked"]
	for index: int in DEMO_LOCKED_EXPRESSION_PREVIEW_COUNT:
		var portrait := ExpressionPortrait.new()
		portrait.name = "DemoLockedExpression%02d" % (index + 1)
		portrait.configure(categories[index % categories.size()], index % 8, false)
		grid.add_child(portrait)
		portrait.custom_minimum_size = Vector2(68, 64)
	var continue_button := Button.new()
	continue_button.text = tr("DEMO_CONTINUE")
	continue_button.pressed.connect(func() -> void:
		if GameSession.mark_demo_completion_seen(for_profile):
			_close_panel()
	)
	_panel_content.add_child(continue_button)


func _open_companions() -> void:
	_show_panel(tr("RESIDENTS_TITLE"))
	_panel_content.add_child(_life_plan_label(tr("RESIDENTS_INTRO")))
	var summaries: Array[Dictionary] = GameSession.companion_summaries()
	for resident: Dictionary in summaries:
		var card := PanelContainer.new()
		card.name = "ResidentCard_%s" % str(resident.id)
		_panel_content.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		var display_name: String = str(resident.name) if not str(resident.name).is_empty() else tr("NAME_DEFAULT")
		content.add_child(_life_plan_label(tr("RESIDENTS_CARD").format({"number":CompanionRules.IDS.find(str(resident.id)) + 1, "name":display_name, "level":resident.level, "notes":resident.notes})))
		var personality: Dictionary = GameSession.catalog.get_item("personalities", str(resident.personality_id))
		var personality_label := _life_plan_label(tr("PERSONALITY_CARD").format({"personality":tr(str(personality.get("name_key", "PERSONALITY_UNASSIGNED")))}))
		personality_label.name = "ResidentPersonality_%s" % str(resident.id)
		content.add_child(personality_label)
		var choose: Button = _button("RESIDENTS_CURRENT" if bool(resident.active) else "RESIDENTS_SWITCH", func() -> void: GameSession.switch_companion(str(resident.id)))
		choose.name = "ResidentSwitch_%s" % str(resident.id)
		choose.disabled = bool(resident.active)
		content.add_child(choose)
	if GameSession.pig_state.personality_id.is_empty():
		_panel_content.add_child(_life_plan_label(tr("PERSONALITY_LEGACY_INTRO")))
		var initial_personality: OptionButton = _add_personality_selector("ResidentInitialPersonality")
		var initial_submit: Button = _button("PERSONALITY_INITIAL_CONFIRM", func() -> void:
			if GameSession.choose_initial_personality(str(initial_personality.get_item_metadata(initial_personality.selected))):
				_open_companions()
		)
		initial_submit.name = "ResidentInitialPersonalitySubmit"
		_panel_content.add_child(initial_submit)
	_panel_content.add_child(_life_plan_label(tr("RESIDENTS_RENAME").format({"name":GameSession.pig_display_name()})))
	var rename_input := LineEdit.new()
	rename_input.name = "ResidentRenameInput"
	rename_input.max_length = 16
	rename_input.text = GameSession.pig_state.name
	rename_input.placeholder_text = tr("NAME_PROMPT_PLACEHOLDER")
	rename_input.accessibility_name = tr("RESIDENTS_RENAME_INPUT")
	_panel_content.add_child(rename_input)
	var rename: Button = _button("RESIDENTS_RENAME_CONFIRM", func() -> void:
		if GameSession.set_pig_name(rename_input.text):
			_open_companions()
	)
	rename.name = "ResidentRenameSubmit"
	rename.disabled = CompanionRules.clean_name(rename_input.text).is_empty()
	rename_input.text_changed.connect(func(value: String) -> void: rename.disabled = CompanionRules.clean_name(value).is_empty())
	rename_input.text_submitted.connect(func(_value: String) -> void:
		if not rename.disabled:
			rename.pressed.emit()
	)
	_panel_content.add_child(rename)
	_panel_content.add_child(_life_plan_label(tr("RESIDENTS_CAPACITY").format({"count":summaries.size(), "maximum":CompanionRules.IDS.size()})))
	var add_input := LineEdit.new()
	add_input.name = "ResidentAddInput"
	add_input.max_length = 16
	add_input.placeholder_text = tr("RESIDENTS_ADD_INPUT")
	add_input.accessibility_name = tr("RESIDENTS_ADD_INPUT")
	add_input.editable = summaries.size() < CompanionRules.IDS.size()
	_panel_content.add_child(add_input)
	var add_personality: OptionButton = _add_personality_selector("ResidentAddPersonality")
	add_personality.disabled = summaries.size() >= CompanionRules.IDS.size()
	var add_button: Button = _button("RESIDENTS_ADD", func() -> void: GameSession.add_companion(add_input.text, str(add_personality.get_item_metadata(add_personality.selected))))
	add_button.name = "ResidentAddSubmit"
	add_button.disabled = true
	add_input.text_changed.connect(func(value: String) -> void: add_button.disabled = summaries.size() >= CompanionRules.IDS.size() or CompanionRules.clean_name(value).is_empty())
	add_input.text_submitted.connect(func(_value: String) -> void:
		if not add_button.disabled:
			add_button.pressed.emit()
	)
	_panel_content.add_child(add_button)


func _on_companions_changed() -> void:
	if _displayed_companion_id != GameSession.active_companion_id:
		_displayed_companion_id = GameSession.active_companion_id
		_pending_offline_summary.clear()
		_close_photo_lightbox()
		_rebuild_ui()
		_queue_startup_overlay()
	else:
		_open_companions()


func open_pig_performances(kind: String = "faces") -> void:
	_show_panel(tr("PERFORMANCE_TITLE"))
	_performance_navigation = VBoxContainer.new()
	_performance_navigation.name = "PerformanceNavigation"
	var outer: Node = _panel_scroll.get_parent()
	outer.add_child(_performance_navigation)
	outer.move_child(_performance_navigation, _panel_scroll.get_index())
	_panel_content.add_child(_life_plan_label(tr("PERFORMANCE_INTRO")))
	var sections: Array[String] = ["faces", "poses", "outfit_actions", "states", "forms"]
	var selector := OptionButton.new()
	selector.name = "PerformanceCategory"
	selector.accessibility_name = tr("PERFORMANCE_CATEGORY")
	for section: String in sections:
		selector.add_item(tr("PERFORMANCE_%s" % section.to_upper()))
	selector.select(maxi(sections.find(kind), 0))
	selector.item_selected.connect(func(index: int) -> void: open_pig_performances(sections[index]))
	_performance_navigation.add_child(selector)
	var stop_button: Button = _button("PERFORMANCE_STOP", GameSession.stop_pig_performance)
	stop_button.name = "PerformanceStopButton"
	_performance_navigation.add_child(stop_button)
	for entry: Dictionary in GameSession.catalog.performances.entries(kind):
		var unlocked: bool = kind != "outfit_actions" or str(entry.outfit_id) == GameSession.pig_state.current_outfit
		var action := Button.new()
		action.name = "Performance_%s" % str(entry.id)
		action.text = tr(str(entry.get("name_key", "")))
		if kind == "outfit_actions":
			var outfit: Dictionary = GameSession.catalog.get_item("outfits", str(entry.outfit_id))
			if outfit.is_empty():
				continue
			action.text = tr("PERFORMANCE_OUTFIT_COMBO").format({"outfit":tr(str(outfit.name_key)), "pose":tr(str(GameSession.catalog.performances.item(str(entry.pose_id)).name_key))})
			action.disabled = not unlocked
			action.tooltip_text = tr("PERFORMANCE_WEAR_FIRST") if not unlocked else ""
		action.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if unlocked:
			action.tooltip_text = action.text
		action.accessibility_name = action.text
		action.pressed.connect(func() -> void:
			if GameSession.perform_pig(str(entry.id)):
				_close_panel()
		)
		_panel_content.add_child(action)
	_panel_content.add_child(_life_plan_label(tr("PERFORMANCE_TEMPORARY")))
	_panel_scroll.scroll_vertical = 0


func _open_settings() -> void:
	_show_panel(tr("UI_SETTINGS"))
	var performances: Button = _button("PERFORMANCE_TITLE", open_pig_performances)
	performances.name = "PigPerformanceLibraryButton"
	_panel_content.add_child(performances)
	var companion: Button = _button("DESKTOP_COMPANION_SETTINGS", open_desktop_companion_settings)
	companion.name = "DesktopCompanionSettingsButton"
	_panel_content.add_child(companion)
	var residents: Button = _button("RESIDENTS_TITLE", _open_companions)
	residents.name = "ResidentsSettingsButton"
	_panel_content.add_child(residents)
	_panel_content.add_child(_slider_row("SETTINGS_UI_SCALE", 0.8, 1.5, GameSession.ui_scale, _set_ui_scale))
	var audio_enabled: bool = AudioService.is_playback_enabled()
	if not audio_enabled:
		var silent_notice := Label.new()
		silent_notice.text = tr("SETTINGS_AUDIO_SILENT")
		silent_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		silent_notice.add_theme_color_override("font_color", Color("#8d5f72"))
		_panel_content.add_child(silent_notice)
	_panel_content.add_child(_slider_row("SETTINGS_MUSIC", 0.0, 1.0, AudioService.music_volume, func(value: float) -> void: AudioService.music_volume = value; AudioService.apply(), audio_enabled))
	_panel_content.add_child(_slider_row("SETTINGS_AMBIENT", 0.0, 1.0, AudioService.ambient_volume, func(value: float) -> void: AudioService.ambient_volume = value; AudioService.apply(), audio_enabled))
	_panel_content.add_child(_slider_row("SETTINGS_INTERACTION", 0.0, 1.0, AudioService.interaction_volume, func(value: float) -> void: AudioService.interaction_volume = value; AudioService.apply(), audio_enabled))
	_panel_content.add_child(_slider_row("SETTINGS_BUBBLE_TIME", 0.75, 2.0, GameSession.bubble_duration_scale, GameSession.set_bubble_duration_scale))
	var reduce := CheckBox.new()
	reduce.text = tr("SETTINGS_REDUCE_MOTION")
	reduce.button_pressed = GameSession.reduce_motion
	reduce.toggled.connect(GameSession.set_reduce_motion)
	_panel_content.add_child(reduce)
	var camera_shake := CheckBox.new()
	camera_shake.text = tr("SETTINGS_CAMERA_SHAKE")
	camera_shake.button_pressed = GameSession.camera_shake_enabled
	camera_shake.toggled.connect(GameSession.set_camera_shake_enabled)
	_panel_content.add_child(camera_shake)
	var reduce_roaming := CheckBox.new()
	reduce_roaming.text = tr("SETTINGS_REDUCE_DESKTOP_ROAMING")
	reduce_roaming.button_pressed = GameSession.reduce_desktop_roaming
	reduce_roaming.toggled.connect(GameSession.set_reduce_desktop_roaming)
	_panel_content.add_child(reduce_roaming)
	var reduce_desktop_actions := CheckBox.new()
	reduce_desktop_actions.text = tr("SETTINGS_REDUCE_DESKTOP_ACTION_FREQUENCY")
	reduce_desktop_actions.button_pressed = GameSession.reduce_desktop_action_frequency
	reduce_desktop_actions.toggled.connect(GameSession.set_reduce_desktop_action_frequency)
	_panel_content.add_child(reduce_desktop_actions)
	var desktop_music := CheckBox.new()
	desktop_music.text = tr("SETTINGS_DESKTOP_MUSIC")
	desktop_music.button_pressed = AudioService.desktop_music_enabled
	desktop_music.disabled = not audio_enabled
	desktop_music.toggled.connect(func(value: bool) -> void: AudioService.desktop_music_enabled = value; AudioService.apply(); GameSession.save_machine_settings())
	_panel_content.add_child(desktop_music)
	var fullscreen := CheckBox.new()
	fullscreen.text = tr("SETTINGS_FULLSCREEN")
	fullscreen.button_pressed = GameSession.main_window_fullscreen
	fullscreen.toggled.connect(GameSession.set_main_window_fullscreen)
	_panel_content.add_child(fullscreen)
	var language_row := HBoxContainer.new()
	var language_label := Label.new()
	language_label.text = tr("SETTINGS_LANGUAGE")
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_row.add_child(language_label)
	var languages := OptionButton.new()
	languages.name = "LanguageSelector"
	var language_options: Array[Array] = [
		["LANGUAGE_ZH_CN", "zh_CN"],
		["LANGUAGE_ZH_TW", "zh_TW"],
		["LANGUAGE_EN", "en"],
	]
	for pair: Array in language_options:
		languages.add_item(tr(str(pair[0])))
		languages.set_item_metadata(languages.item_count - 1, pair[1])
		if pair[1] == GameSession.locale:
			languages.select(languages.item_count - 1)
	languages.item_selected.connect(_select_language.bind(languages))
	language_row.add_child(languages)
	_panel_content.add_child(language_row)
	var skip := Button.new()
	skip.text = tr("SETTINGS_SKIP_TUTORIAL")
	skip.disabled = GameSession.pig_state.tutorial_skipped
	skip.pressed.connect(func() -> void:
		if GameSession.skip_tutorial():
			_close_panel()
	)
	_panel_content.add_child(skip)
	var help := Button.new()
	help.name = "SettingsHelpButton"
	help.text = tr("SETTINGS_HELP")
	help.pressed.connect(_open_help)
	_panel_content.add_child(help)
	var legal := Button.new()
	legal.text = tr("SETTINGS_LEGAL")
	legal.pressed.connect(_open_legal)
	_panel_content.add_child(legal)


func open_desktop_companion_settings() -> void:
	_show_panel(tr("DESKTOP_COMPANION_SETTINGS"))
	_panel_content.add_child(_life_plan_label(tr("DESKTOP_BACKGROUND_SHIELD")))
	var quiet := CheckBox.new()
	quiet.name = "DesktopQuietToggle"
	quiet.text = tr("DESKTOP_QUIET")
	quiet.button_pressed = GameSession.desktop_companion.quiet
	quiet.toggled.connect(func(value: bool) -> void:
		GameSession.set_desktop_companion_settings(value, GameSession.desktop_companion.do_not_disturb, GameSession.desktop_companion.frequency)
	)
	_panel_content.add_child(quiet)
	var no_disturb := CheckBox.new()
	no_disturb.name = "DesktopDoNotDisturbToggle"
	no_disturb.text = tr("DESKTOP_DO_NOT_DISTURB")
	no_disturb.button_pressed = GameSession.desktop_companion.do_not_disturb
	no_disturb.toggled.connect(func(value: bool) -> void:
		GameSession.set_desktop_companion_settings(GameSession.desktop_companion.quiet, value, GameSession.desktop_companion.frequency)
	)
	_panel_content.add_child(no_disturb)
	var frequencies := OptionButton.new()
	frequencies.name = "DesktopBehaviorFrequency"
	for id: String in DesktopCompanionPolicy.FREQUENCIES:
		frequencies.add_item(tr("DESKTOP_FREQUENCY_%s" % id.to_upper()))
		frequencies.set_item_metadata(frequencies.item_count - 1, id)
		if id == GameSession.desktop_companion.frequency:
			frequencies.select(frequencies.item_count - 1)
	frequencies.item_selected.connect(func(index: int) -> void:
		GameSession.set_desktop_companion_settings(GameSession.desktop_companion.quiet, GameSession.desktop_companion.do_not_disturb, str(frequencies.get_item_metadata(index)))
	)
	_panel_content.add_child(_life_plan_label(tr("DESKTOP_BEHAVIOR_FREQUENCY")))
	_panel_content.add_child(frequencies)
	_panel_content.add_child(_life_plan_label(tr("FOCUS_TIMER_INTRO")))
	_focus_timer_label = Label.new()
	_focus_timer_label.name = "FocusCompanionTimerStatus"
	_focus_timer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(_focus_timer_label)
	for pair: Array in [
		["FOCUS_TIMER_START", "FocusTimerStart", GameSession.start_focus_timer],
		["FOCUS_TIMER_PAUSE", "FocusTimerPause", GameSession.toggle_focus_timer_pause],
		["FOCUS_TIMER_REST", "FocusTimerRest", GameSession.start_focus_rest],
		["FOCUS_TIMER_STOP", "FocusTimerStop", GameSession.stop_focus_timer],
	]:
		var button: Button = _button(str(pair[0]), pair[2] as Callable)
		button.name = str(pair[1])
		_panel_content.add_child(button)
	_panel_content.add_child(_life_plan_label(tr("DESKTOP_PRIVACY_BOUNDARY")))
	_refresh_focus_timer()


func _refresh_focus_timer() -> void:
	if not is_instance_valid(_focus_timer_label) or not _focus_timer_label.is_visible_in_tree():
		return
	var snapshot: Dictionary = GameSession.desktop_companion.timer_snapshot()
	var remaining: int = int(snapshot.remaining)
	_focus_timer_label.text = tr("FOCUS_TIMER_STATUS").format({
		"phase":tr("FOCUS_PHASE_%s" % str(snapshot.phase).to_upper()),
		"time":"%02d:%02d" % [remaining / 60, remaining % 60],
		"paused":tr("FOCUS_PAUSED") if bool(snapshot.paused) else "",
	})
	var running: bool = str(snapshot.phase) in ["work", "rest"]
	var pause_button := _panel_content.get_node_or_null("FocusTimerPause") as Button
	if pause_button != null:
		pause_button.disabled = not running
		pause_button.text = tr("FOCUS_TIMER_RESUME" if bool(snapshot.paused) else "FOCUS_TIMER_PAUSE")
	var rest_button := _panel_content.get_node_or_null("FocusTimerRest") as Button
	if rest_button != null:
		rest_button.disabled = str(snapshot.phase) != "rest_ready"
	var stop_button := _panel_content.get_node_or_null("FocusTimerStop") as Button
	if stop_button != null:
		stop_button.disabled = str(snapshot.phase) == "idle"


func _on_focus_break_ready() -> void:
	_show_toast("FOCUS_BREAK_READY", {})


func _on_automatic_ending() -> void:
	if GameSession.desktop_companion.proactive_allowed():
		_show_ending()


func _on_automatic_demo_complete() -> void:
	if GameSession.desktop_companion.proactive_allowed():
		_show_demo_complete()


func _on_companion_policy_changed() -> void:
	if not GameSession.desktop_companion.proactive_allowed() and is_instance_valid(_toast_panel):
		if _toast_tween != null and _toast_tween.is_valid():
			_toast_tween.kill()
		_toast_panel.modulate.a = 0.0
	if is_instance_valid(_panel_content):
		var quiet := _panel_content.get_node_or_null("DesktopQuietToggle") as CheckBox
		if quiet != null:
			quiet.set_pressed_no_signal(GameSession.desktop_companion.quiet)
		var no_disturb := _panel_content.get_node_or_null("DesktopDoNotDisturbToggle") as CheckBox
		if no_disturb != null:
			no_disturb.set_pressed_no_signal(GameSession.desktop_companion.do_not_disturb)
		var frequencies := _panel_content.get_node_or_null("DesktopBehaviorFrequency") as OptionButton
		if frequencies != null:
			frequencies.select(DesktopCompanionPolicy.FREQUENCIES.find(GameSession.desktop_companion.frequency))
	_refresh_focus_timer()


func _open_help() -> void:
	_show_panel(tr("SETTINGS_HELP"))
	for key: String in ["HELP_CORE", "HELP_DESKTOP", "HELP_ALBUM", "HELP_SAVING"]:
		var label := Label.new()
		label.text = tr(key)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_content.add_child(label)
	var replay := Button.new()
	replay.name = "HelpReplayTutorialButton"
	replay.text = tr("HELP_REPLAY_NAMING" if GameSession.pig_state.name.strip_edges().is_empty() else "HELP_REPLAY_TUTORIAL")
	replay.pressed.connect(_restart_tutorial_from_help)
	_panel_content.add_child(replay)


func _restart_tutorial_from_help() -> void:
	if not GameSession.restart_tutorial():
		return
	if GameSession.pig_state.name.strip_edges().is_empty():
		_show_name_prompt()
	else:
		_close_panel()


func _open_legal() -> void:
	_show_panel(tr("SETTINGS_LEGAL"))
	for key: String in ["LEGAL_PRIVACY", "LEGAL_THIRD_PARTY", "LEGAL_NO_BRANDS"]:
		var label := Label.new()
		label.text = tr(key)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_content.add_child(label)


func _slider_row(label_key: String, minimum: float, maximum: float, value: float, callback: Callable, enabled: bool = true) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_key)
	label.custom_minimum_size.x = 260
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.editable = enabled
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSession.save_machine_settings())
	row.add_child(slider)
	return row


func _set_ui_scale(value: float) -> void:
	GameSession.set_ui_scale(value)
	theme = ThemeFactory.create(GameSession.ui_scale)


func _select_language(index: int, options: OptionButton) -> void:
	if GameSession.set_locale(str(options.get_item_metadata(index))):
		call_deferred("_rebuild_ui")


func _add_personality_selector(control_name: String) -> OptionButton:
	_panel_content.add_child(_life_plan_label(tr("PERSONALITY_SETUP_INTRO")))
	var options := OptionButton.new()
	options.name = control_name
	options.accessibility_name = tr("PERSONALITY_SELECTOR")
	options.add_item(tr("PERSONALITY_RANDOM"))
	options.set_item_metadata(0, PersonalityRules.RANDOM_CHOICE)
	var profiles: Array[Dictionary] = GameSession.personality_choices()
	for profile: Dictionary in profiles:
		options.add_item(tr(str(profile.name_key)))
		options.set_item_metadata(options.item_count - 1, str(profile.id))
	_panel_content.add_child(options)
	var description := _life_plan_label(tr("PERSONALITY_RANDOM_DESCRIPTION"))
	description.name = control_name + "Description"
	options.item_selected.connect(func(index: int) -> void:
		description.text = tr("PERSONALITY_RANDOM_DESCRIPTION") if index == 0 else tr(str(profiles[index - 1].description_key))
	)
	_panel_content.add_child(description)
	return options


func _show_name_prompt() -> void:
	_show_panel(tr("NAME_PROMPT_TITLE"), false)
	_set_panel_preferred_size(Vector2(650, 540))
	var prompt := Label.new()
	prompt.text = tr("NAME_PROMPT_TEXT")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_content.add_child(prompt)
	var input := LineEdit.new()
	input.name = "NameInput"
	input.placeholder_text = tr("NAME_PROMPT_PLACEHOLDER")
	input.max_length = 16
	input.custom_minimum_size = Vector2(420, 54)
	_panel_content.add_child(input)
	var personality: OptionButton = _add_personality_selector("NamePersonalityChoice") if GameSession.pig_state.personality_id.is_empty() else null
	var confirm := Button.new()
	confirm.name = "NameConfirmButton"
	confirm.text = tr("UI_CONFIRM")
	confirm.pressed.connect(func() -> void:
		GameSession.note_explicit_companion_interaction()
		var saved: bool = GameSession.initialize_current_companion(input.text, str(personality.get_item_metadata(personality.selected))) if personality != null else GameSession.set_pig_name(input.text)
		if saved:
			_close_panel()
		else:
			input.grab_focus()
		)
	_panel_content.add_child(confirm)
	var skip := _button("SETTINGS_SKIP_TUTORIAL", func() -> void:
		var saved: bool = GameSession.initialize_current_companion("", str(personality.get_item_metadata(personality.selected)), true) if personality != null else GameSession.skip_tutorial()
		if saved:
			_close_panel()
	)
	skip.name = "NameSkipTutorialButton"
	_panel_content.add_child(skip)
	input.text_submitted.connect(func(_value: String) -> void: confirm.pressed.emit())
	input.grab_focus()


func _show_save_recovery_required() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_show_panel(tr("SAVE_RECOVERY_TITLE"), false)
	var message := Label.new()
	message.name = "SaveRecoveryMessage"
	message.text = tr("SAVE_RECOVERY_MESSAGE").format({"path": GameSession.progression_save_directory()})
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(message)
	var retry := Button.new()
	retry.name = "SaveRecoveryRetryButton"
	retry.text = tr("SAVE_RECOVERY_RETRY")
	retry.pressed.connect(func() -> void:
		if GameSession.retry_save_recovery():
			_rebuild_ui()
			_queue_startup_overlay(true)
	)
	_panel_content.add_child(retry)
	var exit_without_saving := Button.new()
	exit_without_saving.name = "SaveRecoveryExitButton"
	exit_without_saving.text = tr("EXIT_WITHOUT_SAVING")
	exit_without_saving.pressed.connect(GameSession.force_exit_without_saving)
	_panel_content.add_child(exit_without_saving)


func show_exit_choice() -> void:
	if GameSession.save_recovery_required:
		_show_save_recovery_required()
		return
	_show_panel(tr("EXIT_TITLE"))
	_set_panel_preferred_size(Vector2(620, 360))
	var message := Label.new()
	message.text = tr("EXIT_MESSAGE")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(message)
	var desktop := Button.new()
	desktop.name = "ExitKeepDesktopButton"
	desktop.text = tr("EXIT_KEEP_DESKTOP")
	desktop.disabled = GameSession.pig_state.familiarity_level < 2
	desktop.pressed.connect(func() -> void: _close_panel(); desktop_requested.emit())
	_panel_content.add_child(desktop)
	var exit_all := Button.new()
	exit_all.name = "ExitAllButton"
	exit_all.text = tr("EXIT_ALL")
	exit_all.pressed.connect(GameSession.request_exit)
	_panel_content.add_child(exit_all)
	var cancel := Button.new()
	cancel.name = "ExitCancelButton"
	cancel.text = tr("EXIT_CANCEL")
	cancel.pressed.connect(_close_panel)
	_panel_content.add_child(cancel)


func show_exit_save_failure() -> void:
	if GameSession.save_recovery_required:
		_show_save_recovery_required()
		return
	_show_panel(tr("EXIT_SAVE_FAILED_TITLE"))
	_set_panel_preferred_size(Vector2(620, 400))
	var message := Label.new()
	message.text = tr("EXIT_SAVE_FAILED_MESSAGE")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_content.add_child(message)
	var retry := Button.new()
	retry.name = "ExitRetryButton"
	retry.text = tr("EXIT_RETRY")
	retry.pressed.connect(GameSession.request_exit)
	_panel_content.add_child(retry)
	var exit_without_saving := Button.new()
	exit_without_saving.name = "ExitWithoutSavingButton"
	exit_without_saving.text = tr("EXIT_WITHOUT_SAVING")
	exit_without_saving.pressed.connect(GameSession.force_exit_without_saving)
	_panel_content.add_child(exit_without_saving)
	var cancel := Button.new()
	cancel.name = "ExitFailureCancelButton"
	cancel.text = tr("EXIT_CANCEL")
	cancel.pressed.connect(_close_panel)
	_panel_content.add_child(cancel)


func _event_playback_active() -> bool:
	for child: Node in get_children():
		if child is EventViewer and not child.is_queued_for_deletion():
			return true
	return false


func _show_offline_summary(summary: Dictionary, explicit_request: bool = false) -> void:
	if not (GameSession.desktop_companion.message_allowed() if explicit_request else GameSession.desktop_companion.proactive_allowed()):
		_pending_offline_summary = summary.duplicate(true)
		return
	if not is_instance_valid(_panel_content):
		_pending_offline_summary = summary.duplicate(true)
		return
	if _overlay.visible or _event_playback_active():
		_pending_offline_summary = summary.duplicate(true)
		return
	_pending_offline_summary.clear()
	_show_panel(tr("OFFLINE_TITLE"))
	_set_panel_preferred_size(Vector2(680, 360))
	var message := Label.new()
	message.text = tr(str(summary.get("summary_key", "OFFLINE_SHORT"))).format({
		"hours": snappedf(float(summary.get("elapsed_seconds", 0)) / 3600.0, 0.1),
		"points": summary.get("points", 0),
	})
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_content.add_child(message)
	var memory_count: int = GameSession.pig_state.pending_events.size() + GameSession.pig_state.summarized_events.size()
	var plan_notes: Array = summary.get("life_plan_entries", []) as Array
	if not plan_notes.is_empty():
		_panel_content.add_child(_life_plan_label(tr("LIFE_PLAN_OFFLINE").format({"count":plan_notes.size()})))
	if memory_count > 0:
		var waiting := Label.new()
		waiting.text = tr("OFFLINE_MEMORIES").format({"count": memory_count})
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel_content.add_child(waiting)


func _show_pending_offline_summary() -> void:
	if _pending_offline_summary.is_empty() or _overlay.visible or _event_playback_active():
		return
	var summary: Dictionary = _pending_offline_summary.duplicate(true)
	_pending_offline_summary.clear()
	_show_offline_summary(summary, true)


func _show_panel(title: String, closable: bool = true) -> void:
	_clear_performance_navigation()
	_focus_timer_label = null
	_life_plan_widgets.clear()
	_life_plan_summary = null
	_life_plan_pause_button = null
	_close_photo_lightbox()
	_clear_container(_panel_content)
	_set_panel_preferred_size(DEFAULT_PANEL_SIZE)
	_panel_title.text = title
	var header := _panel_title.get_parent() as HBoxContainer
	if header != null and header.get_child_count() > 1:
		header.get_child(1).visible = closable
	_overlay.visible = true
	_overlay.move_to_front()
	_toast_panel.move_to_front()
	call_deferred("_focus_first_panel_control")


func _set_panel_preferred_size(preferred_size: Vector2) -> void:
	_panel.custom_minimum_size = _fit_overlay_size(preferred_size)


func _fit_overlay_size(preferred_size: Vector2, total_inset: float = OVERLAY_MARGIN * 2.0) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		minf(preferred_size.x, maxf(viewport_size.x - total_inset, 320.0)),
		minf(preferred_size.y, maxf(viewport_size.y - total_inset, 240.0))
	)


func _focus_first_panel_control() -> void:
	if is_instance_valid(_performance_navigation):
		(_performance_navigation.get_child(0) as Control).grab_focus()
		return
	var controls: Array[Node] = _panel_content.find_children("*", "Control", true, false)
	for node: Node in controls:
		var control := node as Control
		if control != null and control.visible and control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
			return


func _close_panel() -> void:
	if GameSession.save_recovery_required:
		return
	_overlay.visible = false
	_clear_performance_navigation()
	_life_plan_widgets.clear()
	_life_plan_summary = null
	_life_plan_pause_button = null
	_clear_container(_panel_content)
	if not _pending_offline_summary.is_empty():
		call_deferred("_show_pending_offline_summary")


func _rebuild_ui() -> void:
	_clear_performance_navigation()
	_focus_timer_label = null
	_life_plan_widgets.clear()
	_life_plan_summary = null
	_life_plan_pause_button = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	theme = ThemeFactory.create(GameSession.ui_scale)
	_build_ui()
	_refresh()
	if GameSession.save_recovery_required:
		call_deferred("_show_save_recovery_required")
	if not _pending_offline_summary.is_empty():
		call_deferred("_show_pending_offline_summary")


func _clear_performance_navigation() -> void:
	if is_instance_valid(_performance_navigation):
		_performance_navigation.get_parent().remove_child(_performance_navigation)
		_performance_navigation.queue_free()
	_performance_navigation = null


static func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _button(text_key: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = tr(text_key)
	result.focus_mode = Control.FOCUS_ALL
	result.pressed.connect(func() -> void: AudioService.play_sfx("ui_click"))
	result.pressed.connect(GameSession.note_explicit_companion_interaction)
	result.pressed.connect(callback)
	return result
