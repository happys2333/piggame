extends "res://tests/art_visual_audit.gd"

const MOUTH_BODIES: Array[String] = ["body_base", "body_arms", "body_upside"]


func _process(_delta: float) -> void:
	RenderingServer.force_draw()


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
	await _capture_bodies_and_faces()
	var rig: Dictionary = JsonStore.read_object(PigVisualRig.PATH)
	for body_id: String in rig.clips:
		for face_id: String in rig.faces:
			for frame: int in 4:
				var visible: bool = PigVisualRig.mouth_visible(body_id, face_id, frame)
				_expect(visible == (body_id in MOUTH_BODIES and face_id != "face_dot"), "shared static and dynamic mouth policy %s/%s/%d" % [body_id, face_id, frame])
				if not visible:
					continue
				var rect: Rect2 = (PigVisualRig._rects_for(body_id, face_id)[frame] as Array)[2]
				var dimensions: Array = (rig.clips[body_id].frames[frame] as Dictionary).mouth_area
				var area := Rect2(float(dimensions[0]), float(dimensions[1]), float(dimensions[2]), float(dimensions[3]))
				_expect(area.encloses(rect), "entire mouth stays inside the face strip rather than on a paw or collar")
				var glyph: Texture2D = GameSession.final_assets.texture_for("performance_face:%s_mouth" % face_id)
				_expect(absf(rect.size.x / glyph.get_width() - rect.size.y / glyph.get_height()) < 0.001, "mouth retains its original aspect while reduced uniformly")
	await _capture_dynamic_mouths()
	await _capture_sly_transitions()
	var file := FileAccess.open(_output.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":_assertions, "failures":_failures, "screenshots":_screenshots}, "\t"))
	file.close()
	for failure: String in _failures.slice(0, 20):
		printerr(failure)
	print("MOUTH_AUDIT: assertions=%d failures=%d" % [_assertions, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _capture_dynamic_mouths() -> void:
	var viewport: SubViewport = _viewport(Vector2i(840, 230))
	var pig: PigVisual = _specimen(viewport, 0, 0, "mouth transition")
	pig.position = Vector2.ZERO
	var motion: PigMotionPlayer = pig.get("_motion")
	var sequence: Array[String] = ["body_base", "body_peek", "body_head_hold", "body_ruler", "body_arms", "body_upside", "body_base"]
	for grounded: bool in [false, true]:
		pig.set_room_grounded(grounded)
		for facing: float in [-1.0, 1.0]:
			pig.set_locomotion_direction(facing)
			for body_id: String in sequence:
				motion.present({"body_id":body_id, "face_id":"face_shock", "animation":"idle", "outfit":{}})
				for sample: int in 45:
					pig.call("_process", 1.0 / 60.0)
					pig.queue_redraw()
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var appearance: Dictionary = motion.selected()
					var selected: String = str(appearance.body_id)
					var face: String = str(appearance.face_id)
					var expected_visible: bool = selected in MOUTH_BODIES and face != "face_dot"
					if motion.transitioning():
						expected_visible = expected_visible and str(motion.source.body_id) in MOUTH_BODIES and str(motion.target.body_id) in MOUTH_BODIES
						expected_visible = expected_visible and str(motion.source.face_id) != "face_dot" and str(motion.target.face_id) != "face_dot"
					_expect(_has_mouth_texture(pig, face) == expected_visible, "runtime mouth grounded=%s facing=%.1f body=%s source=%s target=%s sample=%d weight=%.3f expected=%s" % [grounded, facing, selected, motion.source.body_id, motion.target.body_id, sample, motion.weight(), expected_visible])
					_assert_rigid(pig, "mouth safety during turn and pose transition")
					if facing < 0.0 and not grounded and sample in [0, 16, 32, 44]:
						_save(viewport, "%s-%02d.png" % [body_id, sample])
	viewport.queue_free()
	await get_tree().process_frame


func _capture_sly_transitions() -> void:
	var phases: Array[float] = [0.0, 0.1, 0.35, 0.49, 0.5, 0.51, 0.65, 0.9, 1.0]
	for grounded: bool in [false, true]:
		for facing: float in [-1.0, 1.0]:
			var viewport := _viewport(Vector2i(2520, 1080))
			var pigs: Array[PigVisual] = []
			for row: int in 4:
				var hidden_body: String = "body_kneel" if row < 2 else "body_prone"
				var source_body: String = "body_base" if row % 2 == 0 else hidden_body
				var target_body: String = hidden_body if row % 2 == 0 else "body_base"
				for column: int in phases.size():
					var phase: float = phases[column]
					var pig := _specimen(viewport, column, row, "%s > %s / %.2f" % [source_body, target_body, phase])
					pig.set_room_grounded(grounded)
					var motion := pig.get("_motion") as PigMotionPlayer
					_pose(pig, source_body, "face_sly")
					motion.facing = facing
					motion.present({"body_id":target_body, "face_id":"face_sly", "animation":"idle", "outfit":{}})
					motion.elapsed = motion.duration * phase
					if phase == 1.0:
						motion.advance(0.0)
					pig.queue_redraw()
					pigs.append(pig)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			for index: int in pigs.size():
				var phase: float = phases[index % phases.size()]
				var row: int = index / phases.size()
				var expected_visible: bool = row % 2 == 1 and phase == 1.0
				_expect(_has_mouth_texture(pigs[index], "face_sly") == expected_visible, "sly mouth stays hidden throughout kneel/prone transitions grounded=%s facing=%s row=%d phase=%.2f" % [grounded, facing, row, phase])
				_assert_rigid(pigs[index], "sly face alignment")
			_save(viewport, "sly-transitions-grounded-%s-facing-%s.png" % [grounded, facing])
			viewport.queue_free()
			await get_tree().process_frame
	var queued := PigMotionPlayer.new()
	queued.present({"body_id":"body_base", "face_id":"face_sly", "animation":"idle", "outfit":{}}, true)
	queued.present({"body_id":"body_prone", "face_id":"face_sly", "animation":"idle", "outfit":{}})
	queued.present({"body_id":"body_kneel", "face_id":"face_sly", "animation":"idle", "outfit":{}})
	for sample: int in 100:
		queued.advance(0.02)
		_expect(not PigVisualRig.motion_mouth_visible(queued), "queued hidden poses never flash a mouth")


func _has_mouth_texture(pig: PigVisual, face_id: String) -> bool:
	var glyph := GameSession.final_assets.texture_for("performance_face:%s_mouth" % face_id) as AtlasTexture
	for texture: Texture2D in pig.get("_drawn_textures") as Array:
		var atlas := texture as AtlasTexture
		if atlas != null and atlas.atlas.resource_path == glyph.atlas.resource_path and atlas.region == glyph.region:
			return true
	return false
