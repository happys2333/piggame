extends Node

var _assertions: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _appearance(body_id: String, animation: String = "idle", face_id: String = "face_dot") -> Dictionary:
	return {"body_id":body_id, "animation":animation, "face_id":face_id, "outfit":{}}


func _run() -> void:
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty() or not OS.get_user_data_dir().ends_with(expected):
		get_tree().quit(1)
		return
	GameSession.set_process(false)
	GameSession.reduce_motion = false
	GameSession.desktop_mode = false
	GameSession.pig_state.tutorial_skipped = true
	var player := PigMotionPlayer.new()
	player.present(_appearance("body_base"))
	player.advance(0.05)
	var initial_clock: float = player.clock
	player.present(_appearance("body_prone", "bed_nap", "face_sleepy"))
	_expect(player.clock == initial_clock and player.weight() == 0.0, "a pose change preserves phase and begins at the previous appearance")
	player.advance(0.1)
	var previous_weight: float = player.weight()
	player.present(_appearance("body_kneel", "sit"))
	_expect(player.weight() == previous_weight and str(player.target.body_id) == "body_prone", "interruption keeps the visible blend and queues only the latest target")
	player.present(_appearance("body_peek", "stare"))
	_expect(str(player.pending.body_id) == "body_peek", "rapid requests replace the pending pose instead of accumulating stale actions")
	for sample: int in 20:
		player.advance(0.1)
	_expect(not player.transitioning() and str(player.target.body_id) == "body_peek", "a queued transition reaches its exact target")
	player.present(_appearance("body_base"), true)
	var frozen: float = player.clock
	player.advance(30.0)
	_expect(is_equal_approx(player.clock - frozen, 0.1), "a long runtime gap never catches up missed visual motion")
	player.present(_appearance("body_flat", "sleep"), true)
	_expect(not player.transitioning() and player.pending.is_empty(), "reduced-motion presentation can choose an endpoint without playing a transition")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(840, 230)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.size = Vector2(840, 230)
	viewport.add_child(background)
	var pigs: Array[PigVisual] = []
	for column: int in 3:
		var pig := PigVisual.new()
		pig.size = Vector2(280, 230)
		pig.position.x = column * 280
		viewport.add_child(pig)
		pig.set_process(false)
		pigs.append(pig)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("PIGGAME_MOTION_REVIEW_DIR")
	var maximum_jump: float = 0.0
	var maximum_render_error: float = 0.0
	var previous: Array[Vector2] = []
	var sequence: Array[String] = ["idle", "walk", "sit", "lie", "sleep", "stare", "scratch", "yoga", "sniff", "idle"]
	var signatures: Dictionary = {}
	var clips: Array[Dictionary] = GameSession.catalog.performances.entries("clips")
	for sample: int in 480:
		if sample % 48 == 0:
			pigs[0].set_behavior({"animation":sequence[sample / 48]})
			pigs[1].set_performance({"id":"probe", "body_id":str(clips[sample / 48].id), "face_id":"face_dot"})
			pigs[2].set_behavior({"animation":"walk"})
			pigs[2].set_locomotion_direction(1.0 if sample % 96 == 0 else -1.0)
		var centers: Array[Vector2] = []
		for pig: PigVisual in pigs:
			pig.call("_process", 1.0 / 60.0)
			var center: Vector2 = pig.visible_snout_position()
			centers.append(center)
			_expect(pig.interaction_kind_at(center) == "poke", "moving and morphing nose shares the rendered hit anchor")
			_expect(int(pig.call("_performance_frame")) == 0, "all runtime poses retain one coherent original body frame")
		if not previous.is_empty():
			for column: int in 2:
				var jump: float = centers[column].distance_to(previous[column])
				maximum_jump = maxf(maximum_jump, jump)
				_expect(jump < 3.0, "pose transition nose must not jump more than three pixels per 60 Hz sample")
		previous = centers
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image = viewport.get_texture().get_image()
		if sample % 12 == 0:
			for column: int in 2:
				var actual: Vector2 = _nose_centroid(rendered, centers[column], column * 280)
				var error: float = actual.distance_to(centers[column])
				maximum_render_error = maxf(maximum_render_error, error)
				_expect(actual.x >= 0.0 and error < 3.0, "rendered nostrils follow the interaction anchor at sample %d, pig %d (error %.2f)" % [sample, column, error])
		signatures[hash(rendered.get_data())] = true
		if not output.is_empty() and sample % 2 == 0:
			rendered.save_png(output.path_join("frame-%03d.png" % (sample / 2)))
	_expect(signatures.size() > 200, "real rendering contains continuous intermediate images instead of four cut frames")
	for pig: PigVisual in pigs:
		var before: float = float(pig.get("_pose_time"))
		GameSession.reduce_motion = true
		pig.call("_process", 1.0)
		_expect(float(pig.get("_pose_time")) == before, "reduced motion freezes the continuous clock")
		GameSession.reduce_motion = false
		pig.hide()
		pig.call("_process", 1.0)
		_expect(float(pig.get("_pose_time")) == before, "hidden characters never catch up their visual clock")
		pig.show()
	GameSession.desktop_mode = true
	GameSession.desktop_companion.set_application_focused(true)
	for protection: String in ["desktop_quiet", "desktop_do_not_disturb"]:
		GameSession.desktop_companion.load_settings({protection:true})
		var before: float = float(pigs[0].get("_pose_time"))
		pigs[0].call("_process", 1.0)
		_expect(float(pigs[0].get("_pose_time")) == before, "quiet and do-not-disturb freeze transitions as well as breathing")
	GameSession.desktop_companion.load_settings({"desktop_quiet":false, "desktop_do_not_disturb":false})
	GameSession.desktop_companion.set_application_focused(false)
	var before: float = float(pigs[0].get("_pose_time"))
	pigs[0].call("_process", 1.0)
	_expect(float(pigs[0].get("_pose_time")) == before, "background applications cannot advance autonomous visual motion")
	print("CONTINUITY: max_nose_jump=%.3f max_render_anchor_error=%.3f distinct_frames=%d assertions=%d" % [maximum_jump, maximum_render_error, signatures.size(), _assertions])
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("PASS: continuous pig bodies, pose transitions, turns, facial anchoring and protection policies")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _nose_centroid(rendered: Image, expected: Vector2, offset: int) -> Vector2:
	var total := Vector2.ZERO
	var count: int = 0
	for row: int in range(maxi(0, floori(expected.y) - 12), mini(rendered.get_height(), ceili(expected.y) + 13)):
		for column: int in range(maxi(offset, floori(expected.x) + offset - 35), mini(offset + 280, ceili(expected.x) + offset + 36)):
			var pixel: Color = rendered.get_pixel(column, row)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.32:
				continue
			var nose: bool = false
			for shift: int in [-10, 10]:
				var adjacent: Color = rendered.get_pixel(clampi(column + shift, offset, offset + 279), row)
				nose = nose or (adjacent.r > 0.6 and adjacent.g < 0.6 and adjacent.b > 0.25)
			if nose:
				total += Vector2(column - offset, row)
				count += 1
	return total / float(count) if count > 0 else Vector2(-100.0, -100.0)
