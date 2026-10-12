extends "res://tests/ui_smoke.gd"

var _output: String


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	_output = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or _output.is_empty():
		get_tree().quit(1)
		return
	var main: Control = MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := main.get_node("UILayer/MainUI") as MainUI
	var pig := main.get_node("Pig") as PigVisual
	var room := main.get_node("Room") as RoomVisual
	var skip := ui.find_child("NameSkipTutorialButton", true, false) as Button
	if skip != null:
		skip.pressed.emit()
	GameSession.set_process(false)
	pig.set_process(false)
	GameSession.pig_state.familiarity_level = 10
	GameSession.pig_state.familiarity_xp = PigState.FAMILIARITY_THRESHOLDS[9]
	for item: Dictionary in GameSession.catalog.furniture:
		if not str(item.id) in GameSession.pig_state.owned_furniture:
			GameSession.pig_state.owned_furniture.append(str(item.id))
	GameSession.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	GameSession.state_changed.emit()
	GameSession.behavior_changed.emit(GameSession.catalog.get_item("behaviors", "behavior_bed_nap"))
	var controller: Node = main.get_node_or_null("RoomInteraction")
	if controller != null:
		controller.set_process(false)
	for step: int in 360:
		if controller != null:
			controller.call("advance", 1.0 / 60.0)
		pig.call("_process", 1.0 / 60.0)
	await _capture("bed-room")
	var boxes: Dictionary = room.furniture_hitboxes()
	var bed: Rect2 = boxes.get("sleep_1", {}).get("rect", Rect2())
	var center: Vector2 = pig.get_global_transform() * (pig.size * 0.5)
	_expect_true(center.distance_to(bed.get_center()) < 160.0, "sleeping pig rests on the actual bed in the main scene")
	_expect_true(absf(bed.get_center().x - main.size.x * 0.5) < 40.0, "bed use is presented centrally, not in a category corner")
	var furniture_texture: Texture2D = GameSession.final_assets.texture_for("furniture:furn_bed_basic")
	var drawn: Array = pig.get("_drawn_textures")
	_expect_true(not furniture_texture in drawn, "room pig must not draw a miniature duplicate bed")
	GameSession.pig_state.unlocked_expressions = ["expr_happy_soft"]
	ui.open_album()
	await get_tree().process_frame
	await _capture("actual-album")
	for node: Node in ui.find_children("*", "", true, false):
		if node is ExpressionPortrait and node.unlocked:
			var texture: Texture2D = GameSession.final_assets.texture_for("expression:%s" % node.expression_id)
			var fitted: Rect2 = PigVisualRig._fit_texture(texture, Rect2(Vector2.ZERO, node.size))
			var transform: Transform2D = node.get_global_transform_with_canvas()
			var horizontal: float = transform.basis_xform(Vector2(fitted.size.x, 0)).length() / texture.get_width()
			var vertical: float = transform.basis_xform(Vector2(0, fitted.size.y)).length() / texture.get_height()
			_expect_true(absf(horizontal - vertical) < 0.001, "actual album artwork uses uniform world-space pixel scale")
	ui.call("_close_panel")
	if controller != null:
		await _main_invitation(ui)
		await _all_interactions(main, ui, room, pig, controller)
		await _main_stage_layouts(main, ui, pig, controller as RoomInteractionController)
		await _album_layouts(main, ui)
		await _lifecycle(main, room, pig, controller)
		await _desktop_interactions(main, ui, pig, controller as RoomInteractionController)
	for frame_id: String in GameSession.PHOTO_FRAMES:
		GameSession.pig_state.current_photo_frame = frame_id
		var image := Image.create(640, 245, false, Image.FORMAT_RGBA8)
		var frame: Control = ui.call("_framed_photo", image, Vector2(640, 245))
		main.add_child(frame)
		for child: Node in frame.get_children():
			if child is TextureRect:
				_expect_true(child.stretch_mode != TextureRect.STRETCH_SCALE, "generated photo-frame art must not stretch to arbitrary photo dimensions")
		frame.queue_free()
	main.queue_free()
	await get_tree().process_frame
	for failure: String in _failures:
		printerr(failure)
	print("ROOM_INTERACTION: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _all_interactions(main: Control, ui: MainUI, room: RoomVisual, pig: PigVisual, controller: Node) -> void:
	var before_simulation: Dictionary = GameSession.simulation.to_dict()
	var before_points: int = GameSession.pig_state.daily_points
	for behavior: Dictionary in GameSession.catalog.behaviors:
		var furniture_id: String = str(behavior.get("required_furniture", ""))
		if furniture_id.is_empty():
			continue
		var item: Dictionary = GameSession.catalog.get_item("furniture", furniture_id)
		var slot: String = str(item.area) + "_1"
		GameSession.pig_state.placed_furniture = {slot:furniture_id}
		GameSession.state_changed.emit()
		GameSession.behavior_changed.emit(behavior)
		var previous: Vector2 = pig.position + pig.visible_ground_position() * pig.scale.x
		for step: int in 420:
			controller.call("advance", 1.0 / 60.0)
			pig.call("_process", 1.0 / 60.0)
			var ground: Vector2 = pig.position + pig.visible_ground_position() * pig.scale.x
			_expect_true(ground.distance_to(previous) < 6.0, "continuous support point without teleports %s frame=%d distance=%.3f elapsed=%.3f duration=%.3f" % [furniture_id, step, ground.distance_to(previous), controller.get("_elapsed"), controller.get("_duration")])
			previous = ground
			var motion: PigMotionPlayer = pig.get("_motion")
			var transform: Transform2D = pig.get_global_transform() * motion.pose_transform(pig.size, motion.weight() >= 0.5)
			_expect_true(absf(transform.x.length() / transform.y.length() - 1.0) < 0.0001, "uniform rigid artwork during approach and interaction " + furniture_id)
		var state: Dictionary = controller.call("snapshot")
		_expect_true(state.arrived and state.furniture_id == furniture_id, "arrives at actual required furniture " + furniture_id)
		_expect_true(pig.behavior_animation == str(behavior.animation), "plays the requested furniture action after arrival " + furniture_id)
		var layout: Dictionary = room.interaction_layout(furniture_id)
		var profile: Dictionary = layout.profile
		var contact: Vector2 = pig.position + (pig.visible_snout_position() if str(profile.anchor) == "snout" else pig.visible_ground_position()) * pig.scale.x
		if str(profile.anchor) == "snout":
			_expect_true(contact.distance_to(layout.contact) < 2.5, "nose touches the actual object surface " + furniture_id)
		else:
			_expect_true(contact.distance_to(state.contact) < 2.5, "body rests on the stable support plane " + furniture_id)
		_expect_true(_rect_inside(Rect2(Vector2.ZERO, main.size), pig.get_global_rect()), "whole actor stays in the actual room " + furniture_id)
		var texture: Texture2D = GameSession.final_assets.texture_for("furniture:%s" % furniture_id)
		var rect: Rect2 = layout.rect
		var combined: Rect2 = rect.merge(pig.get_global_rect())
		_expect_true(absf(combined.get_center().x - main.size.x * 0.5) < 20.0, "pig and item share the central main-scene stage " + furniture_id)
		_expect_true((controller.call("snapshot") as Dictionary).bounds.encloses(rect), "actual item stays in the hero stage " + furniture_id)
		if furniture_id in ["furn_table_snack", "furn_fridge_pink", "furn_telescope", "furn_soft_ball"]:
			_expect_true(absf(contact.y - rect.end.y) < 2.5, "tall objects and ball play keep feet on the floor " + furniture_id)
		_expect_true(absf(rect.size.x / texture.get_width() - rect.size.y / texture.get_height()) < 0.001, "placed furniture preserves its authored aspect " + furniture_id)
		await _capture(str(behavior.animation))
		await _outfit_contacts(pig, "room-" + str(behavior.animation))
	_expect_eq(GameSession.simulation.to_dict(), before_simulation, "presentation does not change simulation timing or current behavior")
	_expect_eq(GameSession.pig_state.daily_points, before_points, "presentation adds no duplicate rewards")
	ui.call("_close_panel")


func _main_invitation(ui: MainUI) -> void:
	ui.call("_open_catalog", "furniture", "UI_FURNITURE")
	await get_tree().process_frame
	var details := ui.find_child("FurnitureDetails_furn_bed_basic", true, false) as Button
	_expect_true(details != null, "configured item has a real catalog details/use entry without a corner thumbnail")
	if details == null:
		return
	details.pressed.emit()
	await get_tree().process_frame
	var invite: Button
	for node: Node in ui.find_children("*", "Button", true, false):
		if (node as Button).text == tr("FURNITURE_INVITE"):
			invite = node as Button
			break
	_expect_true(invite != null and not invite.disabled, "main scene offers a real item invitation from the configured catalog")
	if invite != null:
		invite.pressed.emit()
	_expect_eq(str(GameSession.current_behavior_snapshot().get("id", "")), "behavior_bed_nap", "main item UI commits its action through GameSession")
	ui.call("_close_panel")


func _main_stage_layouts(main: Control, ui: MainUI, pig: PigVisual, items: RoomInteractionController) -> void:
	var cases: Array[Array] = [[Vector2i(1280,720),1.0,"720"],[Vector2i(1280,800),1.0,"16x10"],[Vector2i(2560,1080),1.0,"wide"],[Vector2i(1280,720),0.8,"80"],[Vector2i(1280,720),1.5,"150"]]
	GameSession.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	GameSession.state_changed.emit()
	for layout: Array in cases:
		get_window().size = layout[0]
		GameSession.ui_scale = layout[1]
		ui.call("_rebuild_ui")
		ui.call("_close_panel")
		await get_tree().process_frame
		await get_tree().process_frame
		items.present(GameSession.catalog.get_item("behaviors", "behavior_bed_nap"))
		for step: int in 360:
			items.advance(1.0 / 60.0)
			pig.call("_process", 1.0 / 60.0)
		var rect: Rect2 = items.stage.interaction_layout().rect
		var combined: Rect2 = rect.merge(pig.get_global_rect())
		_expect_true(absf(combined.get_center().x - main.size.x * 0.5) < 20.0, "central main scene at " + str(layout[2]))
		_expect_true(_rect_inside(Rect2(Vector2.ZERO, main.size), combined), "complete main pig/item stays on canvas at " + str(layout[2]))
		await _capture("main-stage-" + str(layout[2]))
	get_window().size = Vector2i(1280,720)
	GameSession.ui_scale = 1.0
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame


func _album_layouts(main: Control, ui: MainUI) -> void:
	GameSession.pig_state.unlocked_expressions.clear()
	for expression: Dictionary in GameSession.catalog.expressions:
		GameSession.pig_state.unlocked_expressions.append(str(expression.id))
	var cases: Array[Array] = [[Vector2i(1280,720),1.0,"720"],[Vector2i(1280,800),1.0,"16x10"],[Vector2i(2560,1080),1.0,"wide"],[Vector2i(1280,720),0.8,"80"],[Vector2i(1280,720),1.5,"150"]]
	for layout: Array in cases:
		get_window().size = layout[0]
		GameSession.ui_scale = layout[1]
		ui.call("_rebuild_ui")
		ui.open_album()
		await get_tree().process_frame
		await get_tree().process_frame
		var count: int = 0
		for node: Node in ui.find_children("*", "", true, false):
			if not node is ExpressionPortrait:
				continue
			count += 1
			var portrait := node as ExpressionPortrait
			var texture: Texture2D = GameSession.final_assets.texture_for("expression:%s" % portrait.expression_id)
			var rect: Rect2 = PigVisualRig._fit_texture(texture, Rect2(Vector2.ZERO, portrait.size))
			var transform: Transform2D = portrait.get_global_transform_with_canvas()
			var horizontal: float = transform.basis_xform(Vector2(rect.size.x, 0)).length() / texture.get_width()
			var vertical: float = transform.basis_xform(Vector2(0, rect.size.y)).length() / texture.get_height()
			_expect_true(absf(horizontal - vertical) < 0.001, "actual album card keeps aspect at " + str(layout[2]))
			var card := portrait.get_parent().get_parent() as Control
			var scroll := card.get_parent().get_parent() as ScrollContainer
			_expect_true(card.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1.0, "album columns fit inside the real scroller at " + str(layout[2]))
			if float(layout[1]) > 1.15:
				_expect_true(card.size.x >= scroll.size.x - 20.0, "large-font single column uses the available width")
		_expect_eq(count, GameSession.catalog.expressions.size(), "all collection portraits covered at " + str(layout[2]))
		_expect_true(main.size.x >= 1280, "actual expandable canvas is used")
		await _capture("album-" + str(layout[2]))
		ui.call("_close_panel")
	get_window().size = Vector2i(1280,720)
	GameSession.ui_scale = 1.0
	ui.call("_rebuild_ui")
	ui.call("_close_panel")
	await get_tree().process_frame


func _lifecycle(main: Control, room: RoomVisual, pig: PigVisual, controller: Node) -> void:
	GameSession.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic","sleep_2":"furn_pillow_cloud","sleep_3":"furn_blanket_roll","sleep_4":"furn_clock_sleepy"}
	GameSession.state_changed.emit()
	GameSession.behavior_changed.emit(GameSession.catalog.get_item("behaviors", "behavior_bed_nap"))
	for step: int in 360:
		controller.call("advance", 1.0 / 60.0)
		pig.call("_process", 1.0 / 60.0)
	await _capture("four-sleep-items")
	for slot: String in GameSession.pig_state.placed_furniture:
		var layout: Dictionary = room.furniture_layout(slot)
		if slot != "sleep_1":
			_expect_true(layout.is_empty(), "category configuration does not create corner-stage actors " + slot)
			continue
		var rect: Rect2 = layout.rect
		_expect_true(_rect_inside(Rect2(Vector2.ZERO, room.size), rect), "crowded room items remain inside canvas " + slot)
		_expect_eq(room.furniture_at_position(rect.get_center()), str(layout.furniture_id), "hit testing uses the same fitted item rect " + slot)
	var before: Vector2 = pig.position
	room.visible = false
	controller.call("advance", 0.1)
	_expect_eq(pig.position, before, "room controller cannot move a hidden desktop pig")
	room.visible = true
	GameSession.pig_state.placed_furniture.clear()
	GameSession.state_changed.emit()
	for step: int in 360:
		controller.call("advance", 1.0 / 60.0)
		pig.call("_process", 1.0 / 60.0)
	var snapshot: Dictionary = controller.call("snapshot")
	_expect_true(str(snapshot.furniture_id).is_empty(), "removed furniture clears contact rather than leaving invisible support")
	GameSession.reduce_motion = true
	GameSession.pig_state.placed_furniture = {"sleep_1":"furn_bed_basic"}
	GameSession.state_changed.emit()
	controller.call("present", GameSession.catalog.get_item("behaviors", "behavior_bed_nap"))
	_expect_true(bool((controller.call("snapshot") as Dictionary).arrived), "reduced motion positions the pig without autonomous travel")
	GameSession.reduce_motion = false
	_expect_true(_rect_inside(Rect2(Vector2.ZERO, main.size), pig.get_global_rect()), "reduced-motion placement stays in room")
	room.scale = Vector2(0.9, 0.85)
	room.position = Vector2(140, 0)
	controller.call("present", GameSession.catalog.get_item("behaviors", "behavior_bed_nap"))
	for step: int in 360:
		controller.call("advance", 1.0 / 60.0)
		pig.call("_process", 1.0 / 60.0)
	var layout: Dictionary = room.interaction_layout("furn_bed_basic")
	var desired: Vector2 = room.item_stage.get_global_transform() * (layout.contact as Vector2)
	var actual: Vector2 = pig.get_global_transform() * pig.visible_ground_position()
	_expect_true(actual.distance_to(desired) < 2.5, "background transforms cannot stretch or displace the shared pig-item stage")
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO


func _desktop_interactions(main: Control, ui: MainUI, pig: PigVisual, items: RoomInteractionController) -> void:
	var desktop: DesktopWindowController = main.get("_desktop_controller")
	GameSession.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":60.0}, GameSession.catalog)
	GameSession.behavior_changed.emit(GameSession.current_behavior_snapshot())
	GameSession.desktop_companion.load_settings({"desktop_quiet":true, "desktop_do_not_disturb":true})
	GameSession.desktop_companion.set_application_focused(true)
	ui.call("_close_panel")
	desktop.enter(pig, main.get_node("Room") as RoomVisual, ui)
	desktop.set_process(false)
	pig.set_process(false)
	items.set_process(false)
	var popup: PopupMenu = desktop.get("_context_popup")
	var menu := popup.get_node("ItemMenu") as PopupMenu
	for pig_only: bool in [false, true]:
		desktop.set("_pig_only_preference", pig_only)
		desktop.call("_apply_window_mode")
		for behavior: Dictionary in GameSession.catalog.behaviors:
			var furniture_id: String = str(behavior.get("required_furniture", ""))
			if furniture_id.is_empty():
				continue
			var filter: String = OS.get_environment("PIGGAME_ITEM_AUDIT_FILTER")
			if not filter.is_empty() and furniture_id != filter:
				continue
			var slots: Array[String] = GameSession.compatible_furniture_slots(furniture_id)
			GameSession.pig_state.placed_furniture = {slots[0]:furniture_id}
			GameSession.state_changed.emit()
			for percentage: int in [50, 75, 100, 125, 150]:
				desktop.scale_factor = float(percentage) / 100.0
				desktop.call("_apply_window_mode")
				_expect_true(await _wait_for_foreground_focus(GameSession), "real desktop focus settles before explicit item input")
				GameSession.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":60.0}, GameSession.catalog)
				GameSession.behavior_director.cooldown_until.erase(str(behavior.id))
				desktop.call("_sync_popup", popup)
				_expect_true(menu.item_count == 1 and not menu.is_item_disabled(0), "placed item is available in the real desktop menu " + furniture_id)
				menu.index_pressed.emit(0)
				_expect_eq(str(GameSession.current_behavior_snapshot().get("id", "")), str(behavior.id), "desktop item menu uses the committed invitation command " + furniture_id)
				_expect_true(not GameSession.desktop_companion.autonomous_motion_allowed() and pig.desktop_motion_allowed(), "manual item response does not enable ambient motion in quiet/DND " + furniture_id)
				var before_simulation: Dictionary = GameSession.simulation.to_dict()
				var before_points: int = GameSession.pig_state.daily_points
				for step: int in 360:
					items.advance(1.0 / 60.0)
					pig.call("_process", 1.0 / 60.0)
				var layout: Dictionary = items.stage.interaction_layout(furniture_id)
				var bounds: Rect2 = desktop.call("_item_bounds")
				_expect_true(not layout.is_empty() and items.snapshot().arrived, "desktop presents the actual active item " + furniture_id)
				if layout.is_empty():
					continue
				var motion: PigMotionPlayer = pig.get("_motion")
				_expect_eq(str(motion.selected().body_id), str(layout.body_id), "desktop item uses the actual intended body pose " + furniture_id)
				_expect_true(_rect_inside(bounds.grow(2.5), layout.rect) and _rect_inside(bounds.grow(2.5), pig.get_global_rect()), "pig and item fit the unchanged character area scale=%d item=%s bounds=%s actor=%s source=%s target=%s clock=%.3f motion=%s focused=%s deadline=%s ticks=%s" % [percentage, furniture_id, bounds, pig.get_global_rect(), motion.source, motion.target, motion.clock, pig.desktop_motion_allowed(), GameSession.desktop_companion.application_focused, pig.get("_explicit_item_until"), Time.get_ticks_msec()])
				var texture: Texture2D = GameSession.final_assets.texture_for("furniture:" + furniture_id)
				var rect: Rect2 = layout.rect
				_expect_true(absf(rect.size.x / texture.get_width() - rect.size.y / texture.get_height()) < 0.001 and is_equal_approx(pig.scale.x, pig.scale.y), "desktop pig and item keep uniform aspect " + furniture_id)
				var profile: Dictionary = layout.profile
				var contact: Vector2 = pig.get_global_transform() * (pig.visible_snout_position() if str(profile.anchor) == "snout" else pig.visible_ground_position())
				_expect_true(contact.distance_to(layout.contact) < 2.5, "actual desktop surface contact " + furniture_id)
				var polygon: PackedVector2Array = desktop.call("_update_passthrough", DisplayServer.window_get_size())
				_expect_true(not polygon.is_empty() and Geometry2D.is_point_in_polygon(rect.get_center(), polygon), "desktop passthrough keeps the actual prop interactive " + furniture_id)
				var position_before: Vector2 = pig.position
				desktop.call("_update_desktop_roaming", 0.1)
				_expect_eq(pig.position, position_before, "roaming cannot tear the pig away from its item " + furniture_id)
				if percentage == 100:
					await _capture("desktop-%s-%s" % ["only" if pig_only else "controls", str(behavior.animation)])
					await _outfit_contacts(pig, "desktop-%s-%s" % ["only" if pig_only else "controls", str(behavior.animation)])
				_expect_eq(GameSession.simulation.to_dict(), before_simulation, "desktop presentation never restarts reward timers " + furniture_id)
				_expect_eq(GameSession.pig_state.daily_points, before_points, "desktop item fitting creates no duplicate rewards " + furniture_id)
	var previous: Dictionary = items.stage.interaction_layout()
	var phase: float = (pig.get("_motion") as PigMotionPlayer).clock
	GameSession.desktop_companion.set_application_focused(false)
	desktop.present_behavior(GameSession.catalog.get_item("behaviors", "behavior_walk"))
	desktop.call("_update_behavior_presentation", 200.0)
	pig.call("_process", 1.0)
	items.advance(1.0)
	_expect_eq(items.stage.interaction_layout(), previous, "switching to another game freezes props without replacing the stage")
	_expect_eq((pig.get("_motion") as PigMotionPlayer).clock, phase, "background protection stops even an explicitly requested item's animation")
	_expect_true(not pig.desktop_motion_allowed() and not desktop.effective_always_on_top(), "background game has no item animation or forced topmost window")
	GameSession.desktop_companion.set_application_focused(true)
	_expect_true(not pig.desktop_motion_allowed(), "returning in quiet mode does not revive stale explicit item permission")
	GameSession.simulation.load_dict({"current_behavior_id":"behavior_idle_stand", "remaining_seconds":60.0}, GameSession.catalog)
	desktop.leave()
	GameSession.desktop_companion.load_settings({})
	await get_tree().process_frame


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_expect_true(get_window().get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK, "real render capture " + label)


func _outfit_contacts(pig: PigVisual, label: String) -> void:
	get_window().grab_focus()
	var previous: Dictionary = pig.outfit
	var choices: Array[Dictionary] = [{}]
	for attire: Dictionary in GameSession.catalog.outfits:
		choices.append(attire)
	var sheet := Image.create(2560, 864, false, Image.FORMAT_RGBA8)
	for index: int in choices.size():
		pig.set_outfit(choices[index])
		pig.call("_request_motion", true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var motion: PigMotionPlayer = pig.get("_motion")
		var body_id: String = str(motion.selected().body_id)
		var pose: Transform2D = pig.get_global_transform() * motion.pose_transform(pig.size, true)
		if PigVisualRig.outfit_visible(body_id, choices[index]):
			var texture: Texture2D = GameSession.final_assets.texture_for("outfit:%s" % choices[index].id)
			var transformed: Transform2D = pose * PigVisualRig.outfit_transform(body_id, 0, choices[index], texture)
			_expect_true(absf((transformed.x / texture.get_width()).length() / (transformed.y / texture.get_height()).length() - 1.0) < 0.0001, "actual scene accessory preserves aspect " + label + "/" + str(choices[index].id))
			for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
				_expect_true(Rect2(Vector2.ZERO, Vector2(get_window().size)).grow(2).has_point(transformed * corner), "actual scene keeps accessory inside its window " + label + "/" + str(choices[index].id))
		var image: Image = get_window().get_texture().get_image()
		var uniform: float = minf(512.0 / image.get_width(), 288.0 / image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * uniform)), maxi(1, roundi(image.get_height() * uniform)), Image.INTERPOLATE_LANCZOS)
		var origin := Vector2i((index % 5) * 512 + (512 - image.get_width()) / 2, (index / 5) * 288 + (288 - image.get_height()) / 2)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), origin)
	_expect_true(sheet.save_png(_output.path_join("outfit-contacts-" + label + ".png")) == OK, "all thirteen equipped/unequipped actual-scene captures " + label)
	pig.set_outfit(previous)
	pig.call("_request_motion", true)


func _wait_for_foreground_focus(session: Node) -> bool:
	get_window().grab_focus()
	var stable: int = 0
	for attempt: int in 60:
		await get_tree().create_timer(0.1).timeout
		if not get_window().has_focus():
			get_window().grab_focus()
		stable = stable + 1 if get_window().has_focus() and session.desktop_companion.application_focused else 0
		if stable >= 3:
			return true
	return false
