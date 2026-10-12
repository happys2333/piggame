extends Node

const MOUTH_HIDDEN_BODIES: Array[String] = ["body_prone", "body_flat", "body_kneel", "body_corner", "body_crawl", "body_worker"]

class PoseSpecimen extends AssetCanvas:
	var body_id: String = "body_base"
	var face_id: String = "face_dot"
	var source_frame: int = 0

	func _draw() -> void:
		begin_visual_draw()
		PigVisualRig.draw_pig(self, Rect2(Vector2.ZERO, size), body_id, face_id, source_frame)

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var output: String = OS.get_environment("PIGGAME_ART_REVIEW_DIR")
	if output.is_empty() or OS.get_environment("PIGGAME_EXPECTED_USER_DIR").is_empty():
		get_tree().quit(1)
		return
	var session: Node = get_tree().root.get_node("GameSession")
	session.set_process(false)
	session.pig_state.tutorial_skipped = true
	var clips: Array[Dictionary] = session.catalog.performances.entries("clips")
	var faces: Array[String] = ["face_dot", "face_squint", "face_deadpan", "face_tears", "face_sly", "face_glare", "face_sleepy", "face_shock"]
	var verified: int = 0
	for face_id: String in faces:
		for page: int in 2:
			var viewport := _viewport(Vector2i(1120, 1380))
			var specimens: Array[PoseSpecimen] = []
			for row: int in 6:
				for frame: int in 4:
					var pig := PoseSpecimen.new()
					pig.size = Vector2(280, 230)
					pig.position = Vector2(frame * 280, row * 230)
					viewport.add_child(pig)
					pig.set_process(false)
					pig.body_id = str(clips[page * 6 + row].id)
					pig.face_id = face_id
					pig.source_frame = frame
					specimens.append(pig)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			for pig: PoseSpecimen in specimens:
				if not _verify_visible_parts(pig):
					get_tree().quit(1)
					return
				verified += 1
			if face_id == "face_dot":
				viewport.get_texture().get_image().save_png(output.path_join("pighub-motion-%d.png" % (page + 1)))
			viewport.queue_free()
			await get_tree().process_frame
	var face_viewport := _viewport(Vector2i(1120, 460))
	for index: int in faces.size():
		var pig := PoseSpecimen.new()
		pig.size = Vector2(280, 230)
		pig.position = Vector2((index % 4) * 280, (index / 4) * 230)
		face_viewport.add_child(pig)
		pig.set_process(false)
		pig.face_id = faces[index]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	face_viewport.get_texture().get_image().save_png(output.path_join("pighub-layered-faces.png"))
	var head_viewport := _viewport(Vector2i(1120, 230))
	for frame: int in 4:
		var pig := PoseSpecimen.new()
		pig.size = Vector2(280, 230)
		pig.position = Vector2(frame * 280, 0)
		head_viewport.add_child(pig)
		pig.set_process(false)
		pig.body_id = "body_head_hold"
		pig.source_frame = frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	head_viewport.get_texture().get_image().save_png(output.path_join("pighub-head-hold.png"))
	if verified != 384:
		push_error("pig visibility review did not cover all pose/face/frame combinations")
		get_tree().quit(1)
		return
	print("PASS: 384 rendered pose/face/frame visibility cases")
	get_tree().quit(0)


func _verify_visible_parts(pig: PoseSpecimen) -> bool:
	var body_id: String = pig.body_id
	var face_id: String = pig.face_id
	var frame: int = pig.source_frame
	var tokens: Array[String] = ["performance_body:%s" % body_id, "performance_face:%s_left" % face_id, "performance_face:%s_right" % face_id]
	if body_id not in MOUTH_HIDDEN_BODIES and face_id != "face_dot":
		tokens.append("performance_face:%s_mouth" % face_id)
	var drawn: Array = pig.get("_drawn_textures") as Array
	if drawn.size() != tokens.size():
		push_error("%s/%s/frame%d must retain only the intended body and facial parts" % [body_id, face_id, frame])
		return false
	for index: int in tokens.size():
		if drawn[index] != GameSession.final_assets.texture_for(tokens[index], frame if index == 0 else 0):
			push_error("%s/%s/frame%d lost a visible eye or used the wrong facial part" % [body_id, face_id, frame])
			return false
	return true


func _viewport(dimensions: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.size = Vector2(dimensions)
	viewport.add_child(background)
	return viewport
