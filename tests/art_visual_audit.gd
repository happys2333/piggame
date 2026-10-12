extends Node

var _failures: Array[String] = []
var _assertions: int = 0
var _output: String
var _cases: Array[Dictionary] = []
var _screenshots: Array[String] = []

class TokenSpecimen extends AssetCanvas:
	var token: String

	func _draw() -> void:
		begin_visual_draw()
		var texture: Texture2D = visual_texture(token)
		if texture != null:
			draw_texture_rect(texture, PigVisualRig._fit_texture(texture, Rect2(Vector2.ZERO, size)), false)

class FrameSpecimen extends AssetCanvas:
	var body_id: String
	var frame: int

	func _draw() -> void:
		begin_visual_draw()
		PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), body_id, "face_dot", frame)

class FurnitureSpecimen extends RoomVisual:
	var furniture_id: String

	func _draw() -> void:
		begin_visual_draw()
		_draw_furniture_item(furniture_id, size * 0.5, Color.WHITE)


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	_output = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or _output.is_empty():
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.reduce_motion = false
	GameSession.desktop_mode = false
	GameSession.pig_state.tutorial_skipped = true
	await _capture_turns()
	await _capture_pose_transitions()
	await _capture_all_transitions()
	await _capture_bodies_and_faces()
	await _capture_original_frames()
	await _capture_outfits()
	await _capture_tokens()
	await _capture_events()
	await _capture_modulation()
	var file := FileAccess.open(_output.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "cases":_cases, "screenshots":_screenshots}, "\t"))
	file.close()
	print("ART_AUDIT: assertions=%d failures=%d" % [_assertions, _failures.size()])
	for failure: String in _failures.slice(0, 20):
		printerr(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _viewport(dimensions: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#fff8f1")
	background.size = Vector2(dimensions)
	viewport.add_child(background)
	return viewport


func _specimen(viewport: SubViewport, column: int, row: int, label: String) -> PigVisual:
	var pig := PigVisual.new()
	pig.size = Vector2(280, 230)
	pig.position = Vector2(column * 280, row * 270 + 30)
	viewport.add_child(pig)
	pig.set_process(false)
	var caption := Label.new()
	caption.text = label
	caption.add_theme_color_override("font_color", Color("#49363e"))
	caption.position = Vector2(column * 280 + 8, row * 270 + 4)
	viewport.add_child(caption)
	return pig


func _capture_turns() -> void:
	var viewport := _viewport(Vector2i(1400, 540))
	for sample: int in 10:
		var pig: PigVisual = _specimen(viewport, sample % 5, sample / 5, "turn %.3f s" % (float(sample) / 30.0))
		var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
		motion.face_direction(1.0)
		for tick: int in sample:
			motion.advance(1.0 / 30.0)
		pig.queue_redraw()
		_expect(absf(motion.facing) >= 0.98, "turn sample %d must not squeeze the character into a thin sheet" % sample)
		_cases.append({"kind":"turn", "sample":sample, "horizontal_scale":motion.facing})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(viewport, "turns.png")
	viewport.queue_free()
	await get_tree().process_frame


func _capture_pose_transitions() -> void:
	var pairs: Array[Array] = [["body_base", "body_prone"], ["body_base", "body_kneel"], ["body_base", "body_peek"], ["body_peek", "body_flat"], ["body_kneel", "body_head_hold"], ["body_flat", "body_arms"]]
	var viewport := _viewport(Vector2i(1400, 1620))
	for row: int in pairs.size():
		for sample: int in 5:
			var pig: PigVisual = _specimen(viewport, sample, row, "%s -> %s / %d" % [pairs[row][0], pairs[row][1], sample])
			var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
			motion.present({"body_id":pairs[row][0], "face_id":"face_dot", "animation":"idle", "outfit":{}}, true)
			motion.present({"body_id":pairs[row][1], "face_id":"face_dot", "animation":"idle", "outfit":{}})
			motion.elapsed = motion.duration * float(sample) / 4.0
			pig.queue_redraw()
			var selected: Dictionary = motion.selected()
			var face_parts: Array = PigVisualRig._rects_for(str(selected.body_id), "face_dot")[0] as Array
			for part_index: int in 2:
				var placement: Rect2 = face_parts[part_index] as Rect2
				var transform: Transform2D = PigVisualRig.motion_detail_transform(placement, Vector2.ZERO, pig.size / Vector2(256, 256), motion, motion.weight() >= 0.5)
				var horizontal: Vector2 = transform.x / placement.size.x
				var vertical: Vector2 = transform.y / placement.size.y
				var ratio: float = horizontal.length() / maxf(vertical.length(), 0.00001)
				var shear: float = absf(horizontal.normalized().dot(vertical.normalized()))
				_expect(ratio > 0.98 and ratio < 1.02 and shear < 0.02, "pose %s/%s/sample%d/eye%d must preserve glyph aspect and orthogonal axes (ratio=%.3f shear=%.3f)" % [pairs[row][0], pairs[row][1], sample, part_index, ratio, shear])
				_cases.append({"kind":"eye", "source":pairs[row][0], "target":pairs[row][1], "sample":sample, "ratio":ratio, "shear":shear})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(viewport, "pose-transitions.png")
	viewport.queue_free()
	await get_tree().process_frame


func _save(viewport: SubViewport, filename: String) -> void:
	_expect(viewport.get_texture().get_image().save_png(_output.path_join(filename)) == OK, "capture " + filename)
	_screenshots.append(filename)


func _finish_page(viewport: SubViewport, filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(viewport, filename)
	viewport.queue_free()
	await get_tree().process_frame


func _caption(viewport: SubViewport, position: Vector2, text_value: String, width: float = 270.0) -> void:
	var caption := Label.new()
	caption.text = text_value
	caption.position = position
	caption.size.x = width
	caption.clip_text = true
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color("#49363e"))
	viewport.add_child(caption)


func _pose(pig: PigVisual, body_id: String, face_id: String = "face_dot", attire: Dictionary = {}) -> void:
	var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
	motion.present({"body_id":body_id, "face_id":face_id, "animation":"idle", "outfit":attire}, true)
	pig.queue_redraw()


func _assert_rigid(pig: PigVisual, label: String) -> void:
	var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
	var transform: Transform2D = motion.pose_transform(pig.size, motion.weight() >= 0.5)
	_expect(absf(transform.x.length() / transform.y.length() - 1.0) < 0.00001 and absf(transform.x.normalized().dot(transform.y.normalized())) < 0.00001, label + " body preserves uniform orthogonal axes")
	_expect(pig.interaction_kind_at(pig.visible_snout_position()) == "poke", label + " nose input uses the same rigid transform")


func _capture_all_transitions() -> void:
	var clips: Array[Dictionary] = GameSession.catalog.performances.entries("clips")
	for amount: float in [0.49, 0.5, 0.51]:
		var viewport := _viewport(Vector2i(1680, 1680))
		var specimens: Array[PigVisual] = []
		for row: int in clips.size():
			for column: int in clips.size():
				var pig := PigVisual.new()
				pig.size = Vector2(140, 115)
				pig.position = Vector2(column * 140, row * 140 + 22)
				viewport.add_child(pig)
				pig.custom_minimum_size = Vector2.ZERO
				pig.size = Vector2(140, 115)
				pig.set_process(false)
				var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
				_pose(pig, str(clips[row].id))
				motion.present({"body_id":clips[column].id, "face_id":"face_dot", "animation":"idle", "outfit":{}})
				motion.elapsed = motion.duration * amount
				pig.queue_redraw()
				_caption(viewport, Vector2(column * 140 + 3, row * 140), "%d > %d / %.2f" % [row, column, amount], 135)
				_assert_rigid(pig, "%s -> %s at %.2f" % [clips[row].id, clips[column].id, amount])
				specimens.append(pig)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		for pig: PigVisual in specimens:
			var body: PigBodyMotion = pig.get("_body_motion") as PigBodyMotion
			_expect((body.get("_drawn_textures") as Array).size() == 1, "transitions draw exactly one coherent body, never doubled limbs")
		_save(viewport, "all-transitions-%d.png" % roundi(amount * 100))
		viewport.queue_free()
		await get_tree().process_frame
	_cases.append({"kind":"transition_matrix", "body_ids":clips.map(func(clip: Dictionary) -> String: return str(clip.id)), "fractions":[0.49, 0.5, 0.51]})


func _capture_bodies_and_faces() -> void:
	var clips: Array[Dictionary] = GameSession.catalog.performances.entries("clips")
	var faces: Array[String] = ["face_dot", "face_squint", "face_deadpan", "face_tears", "face_sly", "face_glare", "face_sleepy", "face_shock"]
	for page: int in 3:
		var viewport := _viewport(Vector2i(1600, 840))
		for row: int in 4:
			for column: int in 8:
				var pig := PigVisual.new()
				pig.size = Vector2(200, 180)
				pig.position = Vector2(column * 200, row * 210 + 25)
				viewport.add_child(pig)
				pig.custom_minimum_size = Vector2.ZERO
				pig.size = Vector2(200, 180)
				pig.set_process(false)
				var body_id: String = str(clips[page * 4 + row].id)
				_pose(pig, body_id, faces[column])
				_caption(viewport, Vector2(column * 200 + 4, row * 210), body_id + "/" + faces[column], 195)
				_assert_rigid(pig, body_id + "/" + faces[column])
				_cases.append({"kind":"body_face", "body":body_id, "face":faces[column]})
		await _finish_page(viewport, "body-faces-%d.png" % page)


func _capture_original_frames() -> void:
	var clips: Array[Dictionary] = GameSession.catalog.performances.entries("clips")
	for page: int in 2:
		var viewport := _viewport(Vector2i(1120, 1620))
		for row: int in 6:
			for column: int in 4:
				var pig := FrameSpecimen.new()
				pig.body_id = str(clips[page * 6 + row].id)
				pig.frame = column
				pig.position = Vector2(column * 280, row * 270 + 30)
				pig.size = Vector2(280, 230)
				viewport.add_child(pig)
				_caption(viewport, pig.position - Vector2(0, 25), "%s / frame%d" % [pig.body_id, column])
				_cases.append({"kind":"original_frame", "body":pig.body_id, "frame":column})
		await _finish_page(viewport, "original-frames-%d.png" % page)


func _capture_outfits() -> void:
	var clips: Array[Dictionary] = GameSession.catalog.performances.entries("clips")
	var outfits: Array = GameSession.catalog.outfits
	var total: int = clips.size() * outfits.size()
	for page: int in ceili(float(total) / 24.0):
		var viewport := _viewport(Vector2i(1120, 1620))
		for index: int in 24:
			var combination: int = page * 24 + index
			if combination >= total:
				break
			var body_id: String = str(clips[combination / outfits.size()].id)
			var attire: Dictionary = outfits[combination % outfits.size()] as Dictionary
			var pig: PigVisual = _specimen(viewport, index % 4, index / 4, body_id + "/" + str(attire.id))
			_pose(pig, body_id, "face_dot", attire)
			_assert_rigid(pig, body_id + "/" + str(attire.id))
			_cases.append({"kind":"outfit", "body":body_id, "outfit":attire.id})
		await _finish_page(viewport, "outfits-%d.png" % page)


func _capture_tokens() -> void:
	var manifest: Dictionary = JsonStore.read_object(FinalAssetCatalog.MANIFEST_PATH)
	var groups: Dictionary = {}
	var count: int = 0
	for entry: Dictionary in manifest.entries:
		for token: String in entry.covers:
			var category: String = token.get_slice(":", 0)
			if not groups.has(category):
				groups[category] = []
			(groups[category] as Array).append(token)
			count += 1
	_expect(count == 222, "all 222 active manifest tokens are included, no retired body accessories")
	for category: String in groups:
		var tokens: Array = groups[category] as Array
		for page: int in ceili(float(tokens.size()) / 24.0):
			var total: int = mini(24, tokens.size() - page * 24)
			var viewport := _viewport(Vector2i(1120, ceili(float(total) / 4.0) * 220))
			for index: int in total:
				var token: String = str(tokens[page * 24 + index])
				var specimen: Control
				if category == "behavior":
					var pig := PigVisual.new()
					viewport.add_child(pig)
					pig.custom_minimum_size = Vector2.ZERO
					pig.set_process(false)
					pig.set_behavior({"animation":token.get_slice(":", 1)})
					var motion: PigMotionPlayer = pig.get("_motion") as PigMotionPlayer
					motion.present(motion.target, true)
					specimen = pig
				elif category == "expression":
					var portrait := ExpressionPortrait.new()
					portrait.expression_id = token.get_slice(":", 1)
					specimen = portrait
					viewport.add_child(specimen)
				elif category == "furniture":
					var furniture := FurnitureSpecimen.new()
					furniture.furniture_id = token.get_slice(":", 1)
					specimen = furniture
					viewport.add_child(specimen)
				else:
					var raw := TokenSpecimen.new()
					raw.token = token
					specimen = raw
					viewport.add_child(specimen)
				var texture: Texture2D = GameSession.final_assets.texture_for(token)
				_expect(texture != null, "real texture loads: " + token)
				specimen.size = Vector2(280, 185)
				specimen.position = Vector2((index % 4) * 280, (index / 4) * 220 + 25)
				_caption(viewport, specimen.position - Vector2(-4, 23), token)
				specimen.queue_redraw()
				_cases.append({"kind":"token", "token":token, "renderer":specimen.get_class()})
			await _finish_page(viewport, "tokens-%s-%d.png" % [category, page])


func _capture_events() -> void:
	var events: Array = GameSession.catalog.events
	for page: int in 4:
		var viewport := _viewport(Vector2i(1280, 840))
		for index: int in 6:
			var event: Dictionary = events[page * 6 + index] as Dictionary
			var stage := EventStage.new()
			stage.position = Vector2((index % 2) * 640, (index / 2) * 280 + 28)
			stage.size = Vector2(640, 245)
			viewport.add_child(stage)
			stage.set_process(false)
			var steps: Array = event.steps as Array
			stage.set_step(event, steps[mini(1, steps.size() - 1)] as Dictionary)
			_caption(viewport, stage.position - Vector2(-4, 23), str(event.id), 630)
			_cases.append({"kind":"stage", "event":event.id})
		await _finish_page(viewport, "events-stage-%d.png" % page)


func _capture_modulation() -> void:
	var viewport := _viewport(Vector2i(1400, 540))
	var colors: Array[Color] = [Color.WHITE, Color(1, 1, 1, 0.5), Color("#bfcfee"), Color(0.7, 0.5, 0.5, 0.75), Color(1, 1, 1, 0.2)]
	for row: int in 2:
		for column: int in 5:
			var parent := Control.new()
			viewport.add_child(parent)
			var pig := PigVisual.new()
			pig.size = Vector2(280, 230)
			pig.position = Vector2(column * 280, row * 270 + 30)
			parent.add_child(pig)
			pig.set_process(false)
			if row == 0:
				parent.modulate = colors[column]
			else:
				pig.modulate = colors[column]
			_pose(pig, "body_head_hold")
			_caption(viewport, pig.position - Vector2(-4, 25), "parent tint" if row == 0 else "pig tint")
			_assert_rigid(pig, "tint variation")
	await _finish_page(viewport, "parent-modulation.png")
