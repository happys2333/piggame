extends "res://tests/art_visual_audit.gd"

const CELL := Vector2(170, 160)
const ACTOR := Vector2(154, 132)
const FRACTIONS: Array[float] = [0.0, 0.49, 0.5, 0.51, 1.0]

var _static_samples: int = 0
var _runtime_samples: int = 0
var _transition_samples: int = 0
var _mapping_samples: int = 0
var _event_samples: int = 0
var _nose_error: float = 0.0
var _outfit_images: Dictionary = {}

class JointSpecimen extends AssetCanvas:
	var body_id: String
	var face_id: String
	var frame: int
	var attire: Dictionary

	func _draw() -> void:
		begin_visual_draw()
		PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), body_id, face_id, frame, attire)


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	_output = OS.get_environment("PIGGAME_ART_AUDIT_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected) or _output.is_empty():
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.pig_state.tutorial_skipped = true
	GameSession.reduce_motion = false
	GameSession.desktop_mode = false
	get_window().grab_focus()
	var rig: Dictionary = JsonStore.read_object(PigVisualRig.PATH)
	var attire_choices: Array[Dictionary] = [{}]
	for attire: Dictionary in GameSession.catalog.outfits:
		attire_choices.append(attire)
	for body_id: String in rig.clips:
		for direction: int in [1, -1]:
			for frame: int in 4:
				await _matrix(body_id, direction, frame, false, rig.faces, attire_choices)
			for phase: int in 4:
				await _matrix(body_id, direction, phase, true, rig.faces, attire_choices)
	_transition_geometry(rig, attire_choices)
	_content_mappings(rig, attire_choices)
	await _event_wardrobe(attire_choices)
	_expect(GameSession.catalog.outfits.size() == 8, "only the eight head and face accessories remain active")
	for attire: Dictionary in GameSession.catalog.outfits:
		_expect(str(attire.anchor) in ["head", "eyes"], "no body or neck accessory remains in the wardrobe")
	for retired: Dictionary in GameSession.catalog.retired_outfits:
		_expect(GameSession.catalog.get_item("outfits", str(retired.id)).is_empty(), "retired outfits are not sold or equipped")
		_expect(GameSession.final_assets.texture_for("outfit:%s" % retired.id) == null, "retired outfit artwork has no runtime route")
	var report := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	var inventory: Dictionary = {"bodies":rig.clips.keys(), "faces":rig.faces.keys(), "outfits":attire_choices.map(func(attire: Dictionary) -> String: return str(attire.get("id", "none"))), "physical_frames":4, "directions":[1,-1], "runtime_breath_phases":4, "transition_fractions":FRACTIONS}
	report.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "inventory":inventory, "static_samples":_static_samples, "runtime_samples":_runtime_samples, "transition_geometry_samples":_transition_samples, "content_mapping_samples":_mapping_samples, "event_samples":_event_samples, "maximum_nose_pixel_error":_nose_error, "screenshots":_screenshots}, "\t"))
	report.close()
	print("OUTFIT_AUDIT: assertions=%d failures=%d" % [_assertions, _failures.size()])
	for failure: String in _failures.slice(0, 20):
		printerr(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _matrix(body_id: String, direction: int, sample: int, runtime: bool, faces: Dictionary, outfits: Array[Dictionary]) -> void:
	get_window().grab_focus()
	var viewport: SubViewport = _viewport(Vector2i(CELL.x * faces.size(), CELL.y * outfits.size()))
	var specimens: Array[Control] = []
	var noses: Array[Vector2] = []
	var face_ids: Array = faces.keys()
	for row: int in outfits.size():
		for column: int in face_ids.size():
			var face_id: String = str(face_ids[column])
			var attire: Dictionary = outfits[row]
			var specimen: Control
			var pose: Transform2D
			if runtime:
				var pig := PigVisual.new()
				viewport.add_child(pig)
				pig.custom_minimum_size = Vector2.ZERO
				pig.set_process(false)
				pig.size = ACTOR
				_pose(pig, body_id, face_id, attire)
				var motion: PigMotionPlayer = pig.get("_motion")
				motion.breath_phase = float(sample) * PI * 0.5
				motion.facing = float(direction)
				pose = motion.pose_transform(ACTOR, true)
				specimen = pig
				_runtime_samples += 1
			else:
				var pig := JointSpecimen.new()
				pig.body_id = body_id
				pig.face_id = face_id
				pig.frame = sample
				pig.attire = attire
				viewport.add_child(pig)
				pig.size = ACTOR
				if direction == -1:
					pig.scale.x = -1.0
				pose = PigVisualRig.fit_transform(ACTOR, body_id, sample)
				specimen = pig
				_static_samples += 1
			specimen.position = Vector2(column * CELL.x + 8, row * CELL.y + 24)
			if not runtime and direction == -1:
				specimen.position.x += ACTOR.x
			var frame: int = 0 if runtime else sample
			_geometry(body_id, face_id, frame, attire, pose, ACTOR, "%s/%s/%s/%d/%d/%s" % [body_id, face_id, attire.get("id", "none"), sample, direction, runtime])
			noses.append(specimen.get_global_transform() * pose * PigVisualRig.snout_for(body_id, frame))
			specimens.append(specimen)
			_caption(viewport, Vector2(column * CELL.x + 4, row * CELL.y), str(attire.get("shape", "none")) + " / " + face_id.trim_prefix("face_"), CELL.x - 4)
			specimen.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image()
	for index: int in specimens.size():
		var canvas: AssetCanvas = specimens[index] as AssetCanvas
		var attire: Dictionary = outfits[index / faces.size()]
		var face_id: String = str(face_ids[index % faces.size()])
		var drawn: Array = canvas.get("_drawn_textures")
		var expected_parts: int = 2 + int(PigVisualRig.mouth_visible(body_id, face_id, 0 if runtime else sample)) + int(PigVisualRig.outfit_visible(body_id, attire))
		_expect(drawn.size() == expected_parts + 1, "actual face/outfit layer inventory including the retained body reference " + body_id + "/" + face_id + "/" + str(attire.get("id", "none")))
		if runtime:
			var body: PigBodyMotion = canvas.get("_body_motion")
			_expect((body.get("_drawn_textures") as Array).size() == 1, "runtime never doubles the body or limbs")
			_expect((canvas as PigVisual).interaction_kind_at((canvas as PigVisual).visible_snout_position()) == "poke", "runtime hit anchor matches face and accessory pose")
		var actual: Vector2 = _nose_pixels(rendered, noses[index])
		var error: float = actual.distance_to(noses[index])
		_nose_error = maxf(_nose_error, error)
		_expect(error < 4.5, "uncovered rendered nostrils %s/%s/%s sample=%d direction=%d runtime=%s error=%.2f" % [body_id, face_id, attire.get("id", "none"), sample, direction, runtime, error])
	_expect((GameSession.final_assets.get("_atlas_cache") as Dictionary).size() <= 8, "complete combinations keep the eight-atlas catalogue budget")
	_save(viewport, "%s-%s-%d-%d.png" % ["runtime" if runtime else "static", body_id, direction, sample])
	viewport.queue_free()
	await get_tree().process_frame


func _geometry(body_id: String, face_id: String, frame: int, attire: Dictionary, pose: Transform2D, dimensions: Vector2, label: String) -> void:
	_expect(absf(pose.x.length() / pose.y.length() - 1.0) < 0.00001, "uniform body transform " + label)
	if not PigVisualRig.outfit_visible(body_id, attire):
		return
	var accessory: Texture2D = GameSession.final_assets.texture_for("outfit:%s" % attire.id)
	var attachment: Transform2D = PigVisualRig.outfit_transform(body_id, frame, attire, accessory)
	var transform: Transform2D = pose * attachment
	var horizontal: Vector2 = transform.x / accessory.get_width()
	var vertical: Vector2 = transform.y / accessory.get_height()
	_expect(absf(horizontal.length() / vertical.length() - 1.0) < 0.00001 and absf(horizontal.normalized().dot(vertical.normalized())) < 0.00001, "rigid accessory aspect and perpendicular axes " + label)
	for point: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		_expect(Rect2(Vector2.ZERO, dimensions).grow(1.0).has_point(transform * point), "accessory remains inside actor canvas " + label)
	if not _outfit_images.has(str(attire.id)):
		_outfit_images[str(attire.id)] = accessory.get_image()
	var image: Image = _outfit_images[str(attire.id)]
	var nose: Vector2 = attachment.affine_inverse() * PigVisualRig.snout_for(body_id, frame)
	_expect(_alpha_at(image, nose) < 0.2, "accessory cannot cover the nose " + label)
	if PigVisualRig.mouth_visible(body_id, face_id, frame):
		var mouth: Rect2 = (PigVisualRig._rects_for(body_id, face_id)[frame] as Array)[2]
		_expect(_alpha_at(image, attachment.affine_inverse() * mouth.get_center()) < 0.2, "accessory cannot cover the independently placed mouth " + label)


func _alpha_at(image: Image, point: Vector2) -> float:
	if point.x < 0.0 or point.y < 0.0 or point.x >= 1.0 or point.y >= 1.0:
		return 0.0
	return image.get_pixel(mini(floori(point.x * image.get_width()), image.get_width() - 1), mini(floori(point.y * image.get_height()), image.get_height() - 1)).a


func _nose_pixels(image: Image, expected: Vector2) -> Vector2:
	var total := Vector2.ZERO
	var count: int = 0
	for row: int in range(maxi(0, floori(expected.y) - 5), mini(image.get_height(), ceili(expected.y) + 6)):
		for column: int in range(maxi(0, floori(expected.x) - 12), mini(image.get_width(), ceili(expected.x) + 13)):
			var pixel: Color = image.get_pixel(column, row)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.25:
				total += Vector2(column, row)
				count += 1
	return total / float(count) if count > 0 else Vector2(-100, -100)


func _transition_geometry(rig: Dictionary, outfits: Array[Dictionary]) -> void:
	var player := PigMotionPlayer.new()
	for source_id: String in rig.clips:
		for target_id: String in rig.clips:
			for face_id: String in rig.faces:
				for attire: Dictionary in outfits:
					for direction: int in [1, -1]:
						for fraction: float in FRACTIONS:
							player.present({"body_id":source_id, "face_id":face_id, "animation":"idle", "outfit":attire}, true)
							player.present({"body_id":target_id, "face_id":face_id, "animation":"idle", "outfit":attire})
							player.elapsed = player.duration * fraction
							player.facing = float(direction)
							var selected: Dictionary = player.selected()
							var pose: Transform2D = player.pose_transform(Vector2(280, 230), player.weight() >= 0.5)
							_geometry(str(selected.body_id), face_id, 0, attire, pose, Vector2(280, 230), "transition %s>%s/%s/%s/%d/%.2f" % [source_id, target_id, face_id, attire.get("id", "none"), direction, fraction])
							_transition_samples += 1


func _content_mappings(rig: Dictionary, outfits: Array[Dictionary]) -> void:
	var pig := PigVisual.new()
	add_child(pig)
	pig.set_process(false)
	for behavior: Dictionary in GameSession.catalog.behaviors:
		for expression: Dictionary in GameSession.catalog.expressions:
			for attire: Dictionary in outfits:
				pig.set_behavior(behavior)
				pig.set_outfit(attire)
				pig.show_reaction(str(expression.category), str(expression.id))
				var motion: PigMotionPlayer = pig.get("_motion")
				_expect(str(motion.selected().body_id) == PigVisualRig.body_for(str(behavior.animation)), "joint behavior selects its physical pose " + str(behavior.id))
				_expect(str(motion.selected().face_id) == str(rig.expressions[expression.id]) and motion.selected().outfit == attire, "joint reaction keeps its face and wardrobe " + str(expression.id))
				_mapping_samples += 1
	for personality: Dictionary in GameSession.catalog.personalities:
		for interaction: String in ["pet", "poke"]:
			var reaction: Dictionary = personality[interaction]
			pig.show_reaction(str(reaction.category), str(reaction.expression_id))
			_expect(str((pig.get("_motion") as PigMotionPlayer).selected().face_id) == PigVisualRig.face_for("idle", str(reaction.expression_id)), "personality reaction remains in the audited face library")
	pig.queue_free()


func _event_wardrobe(outfits: Array[Dictionary]) -> void:
	var saved: String = GameSession.pig_state.current_outfit
	for attire: Dictionary in outfits:
		get_window().grab_focus()
		GameSession.pig_state.current_outfit = str(attire.get("id", ""))
		var viewport: SubViewport = _viewport(Vector2i(1280, 960))
		for index: int in GameSession.catalog.events.size():
			var event: Dictionary = GameSession.catalog.events[index]
			var stage := EventStage.new()
			viewport.add_child(stage)
			stage.size = Vector2(640, 245)
			stage.scale = Vector2(0.5, 0.5)
			stage.position = Vector2((index % 4) * 320, (index / 4) * 160 + 25)
			stage.set_process(false)
			stage.set_step(event, event.steps[mini(1, event.steps.size() - 1)])
			var pig: PigVisual = stage.get("_pig")
			var motion: PigMotionPlayer = pig.get("_motion")
			motion.present(motion.target, true)
			_expect(pig.outfit == attire, "event stage keeps the resident's actual equipped outfit " + str(event.id))
			_caption(viewport, stage.position - Vector2(-4, 23), str(event.id), 310)
			_event_samples += 1
		await _finish_page(viewport, "events-%s.png" % str(attire.get("shape", "none")))
	GameSession.pig_state.current_outfit = saved
