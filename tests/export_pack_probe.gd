extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var expected_user_dir: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	var expected_profile: int = int(OS.get_environment("PIGGAME_EXPECTED_APP_TYPE"))
	if expected_user_dir.is_empty() or not OS.get_user_data_dir().ends_with(expected_user_dir):
		_fail("pack probe requires isolated user data")
		return
	var actual_profile: Variant = ProjectSettings.get_setting_with_override("steam/initialization/app_data/app_type")
	if not actual_profile is int or actual_profile != expected_profile or OS.has_feature("demo") != (expected_profile == 1):
		_fail("pack probe observed the wrong profile")
		return
	var profile: Script = load("res://game/scripts/core/release_profile.gdc") as Script
	if profile == null or profile.get_script_constant_map().get("AUDIO_PLAYBACK_ENABLED", true) != false:
		_fail("pack probe refused non-silent playback")
		return
	var session: Node = root.get_node_or_null("GameSession")
	if session == null or not bool(session.get("loaded_successfully")):
		_fail("pack probe could not load the session")
		return
	session.set_process(false)
	var assets: RefCounted = session.get("final_assets") as RefCounted
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/catalog/final_asset_manifest.json")) as Dictionary
	if assets == null or not bool(assets.get("enabled")) or manifest.get("ready", true) != false or manifest.get("provided_by_user", true) != false:
		_fail("pack probe observed invalid generated asset readiness")
		return
	var count: int = 0
	for entry: Dictionary in manifest.get("entries", []) as Array:
		for token: String in entry.get("covers", []) as Array:
			if not str(assets.call("path_for", token)).begins_with("res://game/assets/final/generated/"):
				_fail("pack probe lost a permanent visual path")
				return
			var frame_regions: Array = (entry.get("frames", {}) as Dictionary).get(token, []) as Array
			var frame_trims: Array = (entry.get("frame_trims", {}) as Dictionary).get(token, []) as Array
			if not frame_regions.is_empty() and frame_regions.size() != 4:
				_fail("pack probe observed an incomplete animation loop")
				return
			for frame_index: int in 4:
				var texture: Texture2D = assets.call("texture_for", token, frame_index) as Texture2D
				if texture == null or (assets.get("_atlas_cache") as Dictionary).size() > 8:
					_fail("pack probe lost a visual frame or exceeded the catalogue cache budget")
					return
				if not frame_regions.is_empty():
					var coordinates: Array = frame_regions[frame_index] as Array
					var region := Rect2(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]), float(coordinates[3]))
					var trim_coordinates: Array = frame_trims[frame_index] as Array if not frame_trims.is_empty() else coordinates
					var trimmed := Rect2(float(trim_coordinates[0]), float(trim_coordinates[1]), float(trim_coordinates[2]), float(trim_coordinates[3]))
					var atlas: AtlasTexture = texture as AtlasTexture
					if atlas == null or atlas.get_size() != region.size or atlas.region != trimmed or atlas.margin != Rect2(trimmed.position - region.position, region.size - trimmed.size):
						_fail("pack probe lost animation canvas registration")
						return
			count += 1
	if count != 218:
		_fail("pack probe observed incomplete visual coverage")
		return
	var catalog: RefCounted = session.get("catalog") as RefCounted
	if (catalog.get("life_plans") as Array).size() != (1 if expected_profile == 1 else 6):
		_fail("pack probe lost the profile-specific life plans")
		return
	if (session.call("personality_choices") as Array).size() != 5 or not bool(session.call("initialize_current_companion", "猪持大局🐷", "personality_lazy")) or not bool(session.call("add_companion", "食不相瞒", "personality_foodie")) or not bool(session.call("switch_companion", "pig_2")):
		_fail("pack probe could not name, welcome or switch a resident")
		return
	if str((session.get("pig_state") as RefCounted).get("name")) != "食不相瞒" or str((session.get("pig_state") as RefCounted).get("personality_id")) != "personality_foodie" or not bool(session.call("switch_companion", "pig_1")):
		_fail("pack probe lost independent resident names")
		return
	session.call("_load_or_create_game")
	if str(session.get("active_companion_id")) != "pig_1" or str((session.get("pig_state") as RefCounted).get("name")) != "猪持大局🐷" or str((session.get("pig_state") as RefCounted).get("personality_id")) != "personality_lazy" or (session.call("companion_summaries") as Array).size() != 2:
		_fail("pack probe could not reload the complete resident roster")
		return
	var scene: PackedScene = load("res://game/scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("pack probe could not load the main scene")
		return
	root.add_child(scene.instantiate())
	for frame_index: int in 5:
		await process_frame
	var companion: RefCounted = session.get("desktop_companion") as RefCounted
	if companion == null or bool(companion.get("application_focused")) != root.has_focus():
		_fail("pack probe did not synchronize startup focus with its own window")
		return
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if bool(companion.call("proactive_allowed")) or bool(companion.call("effective_always_on_top", true)):
		_fail("pack probe did not start protected in the background")
		return
	if not bool(session.call("set_desktop_companion_settings", true, true, "rare")):
		_fail("pack probe could not save interruption preferences")
		return
	session.call("start_focus_timer")
	if int(companion.get("timer_remaining")) != 1500 or not str(companion.call("timer_animation")).is_empty():
		_fail("pack probe lost timer configuration or background protection")
		return
	companion.call("advance", 1500.0)
	if str(companion.get("timer_phase")) != "rest_ready" or not bool(session.call("start_focus_rest")) or int(companion.get("timer_remaining")) != 300:
		_fail("pack probe lost the deliberate five-minute rest")
		return
	session.call("stop_focus_timer")
	session.call("_load_machine_settings")
	if not bool(companion.get("quiet")) or not bool(companion.get("do_not_disturb")) or str(companion.get("frequency")) != "rare":
		_fail("pack probe lost machine-local interruption preferences")
		return
	if session.catalog.performances.validate(JsonStore.read_array("res://game/data/catalog/outfits.json")).size() != 0 or not session.perform_pig("meme_worker") or str(session.pig_performance.snapshot(session.catalog.performances).body_id) != "body_worker":
		_fail("pack probe lost the shared pig performance library")
		return
	session.stop_pig_performance()
	print("PASS: exported pack startup app_type=%d visuals=218 frames=4 residents=2 cache<=8 silent=true protection=true timer=25/5 personalities=5 performances=9/9/6/2" % expected_profile)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
