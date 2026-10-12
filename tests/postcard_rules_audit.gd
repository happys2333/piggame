extends SceneTree

class FailingMailSave:
	extends SaveService
	var fail_writes: bool = false
	func save_game(data: Dictionary) -> Error:
		return FAILED if fail_writes else super.save_game(data)

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var expected: String = OS.get_environment("PIGGAME_EXPECTED_USER_DIR")
	if expected.is_empty():
		expected = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not expected.begins_with("PiggameGodotChecks-") or not OS.get_user_data_dir().ends_with(expected):
		quit(1)
		return
	var session: Node = root.get_node("GameSession")
	session.set_process(false)
	var cards: Array[Dictionary] = session.catalog.postcards
	_check(cards.size() == 8 and PostcardRules.validate_content(cards).is_empty(), "eight valid permanent milestones")
	var state := PigState.new()
	_check(state.daily_points == 70 and state.earned_points == 0, "starting gift does not count as income")
	_check(PostcardRules.deliver(cards, state, 123).is_empty(), "no welcome gift skips the first milestone")
	state.add_points(99)
	_check(PostcardRules.deliver(cards, state, 123).is_empty(), "one point below threshold stays locked")
	state.add_points(1)
	_check(PostcardRules.deliver(cards, state, 123) == ["postcard_wake"], "exact threshold automatically delivers")
	_check(state.spend_points(100) and state.earned_points == 100, "spending never reverses cumulative progress")
	state.add_points(-20)
	_check(state.earned_points == 100, "negative balance adjustment never removes income")
	_check(PostcardRules.deliver(cards, state, 999).is_empty() and int(state.received_postcards.postcard_wake) == 123, "repeat settlement cannot replace or duplicate delivery")
	state.read_postcards.append("postcard_wake")
	state.add_points(14900)
	_check(PostcardRules.deliver(cards, state, 999).size() == 7 and PostcardRules.unread_count(state) == 7, "one offline settlement can cross every remaining milestone")
	var restored := PigState.new()
	restored.load_dict(state.to_dict())
	_check(PostcardRules.deliver(cards, restored, 1200).is_empty() and PostcardRules.unread_count(restored) == 7, "reload preserves delivery and read state")
	var legacy: Dictionary = state.to_dict().duplicate(true)
	for field: String in ["earned_points", "received_postcards", "read_postcards"]:
		legacy.erase(field)
	legacy.daily_points = 370
	restored.load_dict(legacy)
	_check(restored.earned_points == 300 and restored.received_postcards.is_empty() and restored.read_postcards.is_empty(), "old save conservatively recovers balance minus starting gift without inheriting another pig's mail")
	legacy.daily_points = 20
	restored.load_dict(legacy)
	_check(restored.earned_points == 0, "old spent balance cannot produce negative income")
	var invalid_cards: Array[Dictionary] = cards.duplicate(true)
	invalid_cards[1].points = invalid_cards[0].points
	_check(not PostcardRules.validate_content(invalid_cards).is_empty(), "duplicate thresholds rejected")
	invalid_cards = cards.duplicate(true)
	invalid_cards[0].points = 1.5
	_check(not PostcardRules.validate_content(invalid_cards).is_empty(), "fractional thresholds rejected")
	await _test_session(session, cards)
	for failure: String in _failures:
		printerr(failure)
	print("POSTCARD_RULES: assertions=%d failures=%d" % [_assertions, _failures.size()])
	if _failures.is_empty():
		print("PASS: postcard rules")
	quit(0 if _failures.is_empty() else 1)


func _test_session(session: Node, cards: Array[Dictionary]) -> void:
	var service := FailingMailSave.new("user://postcard_rules")
	service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	session.save_service = service
	session.pig_state = PigState.new()
	session.pig_state.changed.connect(session._on_pig_state_changed)
	session.pig_state.familiarity_level_changed.connect(session._on_familiarity_level_changed)
	session.pig_state.content_unlocked.connect(session._on_content_unlocked)
	service.save_failed.connect(session._on_save_failed)
	session.set("_companions", {})
	var notifications: Array[bool] = []
	session.postcard_mail_changed.connect(func() -> void: notifications.append(true))
	_check(session.save_game() == OK, "initial save commits")
	session.pig_state.add_points(100)
	service.fail_writes = true
	_check(session.save_game() == FAILED and session.pig_state.received_postcards.is_empty() and notifications.is_empty(), "failed delivery save exposes no mail or notification")
	await process_frame
	service.fail_writes = false
	_check(session.save_game() == OK and notifications.size() == 1 and session.unread_postcard_count() == 1, "retry saves and announces delivery exactly once")
	var balance: int = session.pig_state.daily_points
	var xp: int = session.pig_state.familiarity_xp
	service.fail_writes = true
	_check(not session.open_postcard("postcard_wake") and session.unread_postcard_count() == 1, "failed read transaction preserves unread letter")
	_check(not session.open_postcard("postcard_carrot") and not session.open_postcard("postcard_unknown"), "locked and unknown letters cannot be opened")
	service.fail_writes = false
	_check(session.open_postcard("postcard_wake") and session.unread_postcard_count() == 0, "read transaction commits")
	var announced: int = notifications.size()
	_check(session.open_postcard("postcard_wake") and notifications.size() == announced, "reopening never duplicates a read notification")
	_check(session.pig_state.daily_points == balance and session.pig_state.familiarity_xp == xp, "collecting does not change economy or progression")
	var saved: Dictionary = service.load_game().data
	_check(service.call("_is_valid_game_payload", saved), "valid production mail payload accepted")
	for value: Variant in [-1, 1.5, true, "100"]:
		var malformed: Dictionary = saved.duplicate(true)
		malformed.pig_state.earned_points = value
		_check(not service.call("_is_valid_game_payload", malformed), "invalid earned point type rejected " + str(value))
	for record: Dictionary in [{"postcard_unknown":123}, {"postcard_carrot":123}, {"postcard_wake":-1}, {"postcard_wake":1.5}, {"postcard_wake":true}]:
		var malformed: Dictionary = saved.duplicate(true)
		malformed.pig_state.received_postcards = record
		_check(not service.call("_is_valid_game_payload", malformed), "invalid/unknown/unearned delivery rejected " + str(record))
	for reads: Array in [["postcard_wake", "postcard_wake"], ["postcard_carrot"], [123]]:
		var malformed: Dictionary = saved.duplicate(true)
		malformed.pig_state.read_postcards = reads
		_check(not service.call("_is_valid_game_payload", malformed), "invalid read state rejected " + str(reads))
	session.call("_load_or_create_game")
	_check(session.pig_state.earned_points == 100 and session.unread_postcard_count() == 0, "production reload keeps income and already opened mail")
	_check(session.add_companion("萝卜", "personality_foodie") and session.switch_companion("pig_2"), "second resident created and selected")
	_check(session.pig_state.earned_points == 0 and session.pig_state.received_postcards.is_empty(), "resident mail is independent")
	session.pig_state.add_points(300)
	_check(session.save_game() == OK and session.unread_postcard_count() == 2, "second pig reaches its own milestones")
	_check(session.switch_companion("pig_1") and session.unread_postcard_count() == 0 and session.pig_state.earned_points == 100, "switching back retains original mail")
	var now: int = session.clock.current_unix()
	session.pig_state.add_points(199)
	session.save_game()
	session.call("_settle_companion_until", now - 86400, now)
	_check(session.pig_state.received_postcards.size() > 1 and session.save_game() == OK, "production offline income delivers newly crossed milestones")
	var demo := ContentCatalog.new()
	_check(demo.load_all().is_empty(), "full content imports")
	demo.apply_demo_profile()
	_check(demo.postcards == cards, "Demo and full share permanent postcard IDs")
	var demo_service := SaveService.new("user://postcard_demo_import")
	demo_service.configure_content_ids(demo, session.ROOM_SLOTS)
	var demo_state := PigState.new()
	demo_state.add_points(600)
	PostcardRules.deliver(cards, demo_state, now)
	demo_state.read_postcards.append("postcard_wake")
	_check(demo_service.save_game({"release_profile":"demo", "last_saved_unix":now, "pig_state":demo_state.to_dict()}) == OK, "Demo saves offline mail")
	session.save_service = SaveService.new("user://postcard_full_import")
	session.save_service.configure_content_ids(session.catalog, session.ROOM_SLOTS)
	var imported: Dictionary = session.call("_load_game_with_profile_import", "full", demo_service)
	_check(imported.ok and imported.data.release_profile == "full" and imported.data.pig_state.received_postcards.size() == 3 and imported.data.pig_state.read_postcards == ["postcard_wake"], "production Demo import preserves postcard progress and reads")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
