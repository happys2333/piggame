extends SceneTree

const START_UNIX: int = 1784131200
const MIN_SECONDS: int = 20 * 60
const MAX_SECONDS: int = 40 * 60


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := ContentCatalog.new()
	var errors: Array[String] = catalog.load_all()
	if not errors.is_empty():
		printerr("Demo progression audit could not load content: %s" % errors)
		quit(1)
		return
	catalog.apply_demo_profile()
	var state := PigState.new()
	state.daily_points = 75
	state.familiarity_xp = 5
	state.normalize()
	var simulation := Simulation.new(20260716)
	var behavior_director := BehaviorDirector.new(20260716)
	var event_director := EventDirector.new(20260716)
	var completion_second: int = -1
	var purchased: Array[String] = []
	for second: int in range(1, MAX_SECONDS + 1):
		simulation.advance(1.0, state, catalog.behaviors, behavior_director, START_UNIX + second, false, false)
		_try_buy_and_place("furn_pillow_cloud", "sleep_2", catalog, state, purchased)
		_try_buy_and_place("furn_clock_sleepy", "sleep_3", catalog, state, purchased)
		if second % 75 == 0:
			var discovery: Dictionary = event_director.discover_one(catalog.events, state, START_UNIX + second)
			if bool(discovery.get("queued", false)):
				var event: Dictionary = discovery.get("event", {}) as Dictionary
				event_director.mark_watched(event, state, START_UNIX + second)
		if state.seen_events.size() == catalog.events.size():
			completion_second = second
			break
	var failures: Array[String] = []
	if completion_second >= 0 and completion_second < MIN_SECONDS:
		failures.append("all four demo memories complete before the 20-minute target")
	if completion_second < 0 or completion_second > MAX_SECONDS:
		failures.append("all four demo memories do not complete within 40 minutes")
	if not "furn_pillow_cloud" in purchased or not "furn_clock_sleepy" in purchased:
		failures.append("demo completion did not exercise both required furniture purchases")
	var report := "completion=%ds level=%d points=%d events=%s furniture=%s" % [
		completion_second, state.familiarity_level, state.daily_points, state.seen_events, purchased,
	]
	var contract := "PASS-CONTRACT: demo completion=%ds level=%d points=%d events=%d furniture=%d" % [
		completion_second, state.familiarity_level, state.daily_points, state.seen_events.size(), purchased.size(),
	]
	if failures.is_empty():
		print("PASS: demo progression (%s)" % report)
		print(contract)
		quit(0)
	else:
		printerr("FAIL: demo progression (%s)" % report)
		for failure: String in failures:
			printerr("- %s" % failure)
		quit(1)


func _try_buy_and_place(id: String, slot_id: String, catalog: ContentCatalog, state: PigState, purchased: Array[String]) -> void:
	if id in purchased:
		return
	var item: Dictionary = catalog.get_item("furniture", id)
	if item.is_empty() or state.familiarity_level < int(item.get("min_level", 1)):
		return
	if not state.spend_points(int(item.get("price", 0))):
		return
	state.unlock("furniture", id, START_UNIX)
	state.placed_furniture[slot_id] = id
	purchased.append(id)
