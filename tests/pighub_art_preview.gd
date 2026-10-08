extends Node

const MOUTH_HIDDEN_BODIES: Array[String] = ["body_prone", "body_flat", "body_corner", "body_crawl", "body_worker"]

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
			var specimens: Array[PigVisual] = []
			for row: int in 6:
				for frame: int in 4:
					var pig := PigVisual.new()
					pig.size = Vector2(280, 230)
					pig.position = Vector2(frame * 280, row * 230)
					viewport.add_child(pig)
					pig.set_process(false)
					pig.set_performance({"id":"review", "body_id":str(clips[page * 6 + row].id), "face_id":face_id, "manual":true})
					pig.set("_phase", frame * PigVisual.FRAME_STEP)
					specimens.append(pig)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			for pig: PigVisual in specimens:
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
		var pig := PigVisual.new()
		pig.size = Vector2(280, 230)
		pig.position = Vector2((index % 4) * 280, (index / 4) * 230)
		face_viewport.add_child(pig)
		pig.set_process(false)
		pig.set_performance({"id":"review", "body_id":"body_base", "face_id":faces[index], "manual":true})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	face_viewport.get_texture().get_image().save_png(output.path_join("pighub-layered-faces.png"))
	if verified != 384:
		push_error("pig visibility review did not cover all pose/face/frame combinations")
		get_tree().quit(1)
		return
	print("PASS: 384 rendered pose/face/frame visibility cases")
	get_tree().quit(0)


func _verify_visible_parts(pig: PigVisual) -> bool:
	var performance: Dictionary = pig.get("_performance") as Dictionary
	var body_id: String = str(performance.body_id)
	var face_id: String = str(performance.face_id)
	var frame: int = floori(float(pig.get("_phase")) / PigVisual.FRAME_STEP) % 4
	var tokens: Array[String] = ["performance_body:%s" % body_id, "performance_face:%s_left" % face_id, "performance_face:%s_right" % face_id]
	if body_id not in MOUTH_HIDDEN_BODIES:
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
