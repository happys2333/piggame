extends SceneTree

const GameSessionScript = preload("res://game/scripts/core/game_session.gd")

const MAX_SECONDS := 72 * 3600
const START_UNIX := 1784131200
const ENDING_MIN_SECONDS := 8 * 3600
const ENDING_MAX_SECONDS := 12 * 3600
const EVENT_CHECK_SECONDS := 75
const SESSION_SECONDS := 2 * 3600
const CADENCE_MAX_ACTIVE_SECONDS := 20 * 3600
const CADENCE_SESSION_SECONDS := 15 * 60
const CADENCE_TARGET_SHARE := 0.75
const SESSION_START_HOURS: Array[int] = [6, 12, 18, 22]
const AUDIT_AREA_LEVELS := {"sleep": 1, "snack": 3, "activity": 4, "window": 6}
const AUDIT_ROOM_SLOTS := {
	"sleep_1": ["sleep", "large"], "sleep_2": ["sleep", "small"], "sleep_3": ["sleep", "small"], "sleep_4": ["sleep", "wall"],
	"snack_1": ["snack", "large"], "snack_2": ["snack", "large"], "snack_3": ["snack", "small"], "snack_4": ["snack", "small"],
	"activity_1": ["activity", "large"], "activity_2": ["activity", "large"], "activity_3": ["activity", "small"], "activity_4": ["activity", "small"],
	"window_1": ["window", "large"], "window_2": ["window", "small"], "window_3": ["window", "small"], "window_4": ["window", "wall"],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := ContentCatalog.new()
	var errors: Array[String] = catalog.load_all()
	if not errors.is_empty():
		printerr("Progression audit could not load content: %s" % errors)
		quit(1)
		return
	var state := PigState.new()
	# The opening pet and first feed, including the first expression unlock, leave the player at 75 points and 5 familiarity XP.
	state.daily_points = 75
	state.familiarity_xp = 5
	state.normalize()
	var simulation := Simulation.new(20260716)
	var director := BehaviorDirector.new(20260716)
	var cheapest_furniture: int = 1_000_000
	var total_shop_price: int = 0
	for furniture: Dictionary in catalog.furniture:
		var price: int = int(furniture.get("price", 0))
		total_shop_price += price
		if price > 0 and int(furniture.get("min_level", 1)) <= 1:
			cheapest_furniture = mini(cheapest_furniture, price)
	for snack: Dictionary in catalog.snacks:
		total_shop_price += int(snack.get("price", 0))
	for outfit: Dictionary in catalog.outfits:
		total_shop_price += int(outfit.get("price", 0))
	var event_familiarity: int = 0
	for event: Dictionary in catalog.events:
		event_familiarity += int(event.get("rewards", {}).get("familiarity", 0))
	var event_assisted_target: int = PigState.FAMILIARITY_THRESHOLDS[-1] - event_familiarity
	var first_furniture_ready: int = -1
	var event_assisted_level_ten_ready: int = -1
	var level_times: Dictionary = {1: 0}
	var previous_level: int = state.familiarity_level
	var snapshots: Dictionary = {}
	for second: int in range(1, MAX_SECONDS + 1):
		simulation.advance(1.0, state, catalog.behaviors, director, START_UNIX + second, false, false)
		if first_furniture_ready < 0 and state.daily_points >= cheapest_furniture:
			first_furniture_ready = second
		if event_assisted_level_ten_ready < 0 and state.familiarity_xp >= event_assisted_target:
			event_assisted_level_ten_ready = second
		if state.familiarity_level != previous_level:
			for level: int in range(previous_level + 1, state.familiarity_level + 1):
				level_times[level] = second
			previous_level = state.familiarity_level
		if second in [15 * 60, 30 * 60, 8 * 3600, 12 * 3600, 20 * 3600, 30 * 3600, 48 * 3600, 72 * 3600]:
			snapshots[second] = {
				"points": state.daily_points,
				"level": state.familiarity_level,
				"satiety": snappedf(state.satiety, 0.1),
				"energy": snappedf(state.energy, 0.1),
				"interest": snappedf(state.interest, 0.1),
			}
	var failures: Array[String] = []
	if first_furniture_ready < 8 * 60 or first_furniture_ready > 15 * 60:
		failures.append("first furniture affordability falls outside the 8–15 minute onboarding window")
	var desktop_unlock_second: int = int(level_times.get(2, -1))
	if desktop_unlock_second < 20 * 60 or desktop_unlock_second > 30 * 60:
		failures.append("desktop mode level unlock falls outside the 20–30 minute onboarding window")
	for level: int in [3, 4, 5]:
		var unlock_second: int = int(level_times.get(level, -1))
		if unlock_second < desktop_unlock_second or unlock_second > 30 * 60:
			failures.append("onboarding level %d does not unlock in order by 30 minutes" % level)
	if int((snapshots[30 * 60] as Dictionary).level) < 5:
		failures.append("familiarity level 5 is not reached within the 30-minute onboarding window")
	var level_ten_time: int = int(level_times.get(10, -1))
	if level_ten_time < 8 * 3600 or level_ten_time > 12 * 3600:
		failures.append("behavior-only level 10 falls outside the 8–12 hour target")
	if event_assisted_level_ten_ready < 8 * 3600 or event_assisted_level_ten_ready > 12 * 3600:
		failures.append("event-assisted level 10 falls outside the 8–12 hour target")
	if int((snapshots[8 * 3600] as Dictionary).points) >= total_shop_price:
		failures.append("the entire shop is affordable before the ending window begins")
	if int((snapshots[12 * 3600] as Dictionary).points) >= total_shop_price:
		failures.append("the entire shop is affordable inside the 8–12 hour ending window")
	if int((snapshots[20 * 3600] as Dictionary).points) < ceili(float(total_shop_price) * 0.75):
		failures.append("twenty active hours cannot fund most of the launch collection")
	if int((snapshots[30 * 3600] as Dictionary).points) < total_shop_price:
		failures.append("thirty active hours still cannot fund the complete launch shop")
	for checkpoint: int in [8 * 3600, 12 * 3600, 20 * 3600, 30 * 3600, 48 * 3600, 72 * 3600]:
		var snapshot: Dictionary = snapshots[checkpoint] as Dictionary
		for state_name: String in ["satiety", "energy", "interest"]:
			var value: float = float(snapshot[state_name])
			if value <= 5.0 or value >= 95.0:
				failures.append("%s saturates outside the long-running comfort band at %d active hours" % [state_name, checkpoint / 3600])
	var ending_audit: Dictionary = _audit_theme_ending(catalog)
	var first_memory_second: int = int(ending_audit.get("first_memory_second", -1))
	if first_memory_second < 0 or first_memory_second > 10 * 60:
		failures.append("an engaged new player does not reach the first personality memory within ten minutes")
	var ending_second: int = int(ending_audit.get("completion_second", -1))
	if ending_second < ENDING_MIN_SECONDS or ending_second > ENDING_MAX_SECONDS:
		failures.append("level 10 plus all 24 core memories does not reach the theme ending within 8–12 active hours")
	if int(ending_audit.get("seen_events", 0)) != catalog.events.size():
		failures.append("theme-ending audit did not watch every core memory")
	var cadence_audit: Dictionary = _audit_short_session_cadence(catalog)
	if int(cadence_audit.get("completion_second", -1)) < 0:
		failures.append("daily short-session collector cannot acquire most launch shop content within twenty active hours")
	if int(cadence_audit.get("max_empty_sessions", 99)) > 1:
		failures.append("daily collector has two consecutive short sessions without clear new content")
	if int(cadence_audit.get("acquired_items", -1)) < int(cadence_audit.get("target_items", 0)):
		failures.append("daily short-session cadence audit does not reach its launch-content target")
	var report := "first_furniture=%ds onboarding_levels=%s event_assisted_level10=%ds level10=%ds ending=%s cadence=%s shop=%d snapshots=%s" % [
		first_furniture_ready, level_times, event_assisted_level_ten_ready, level_ten_time, ending_audit, cadence_audit, total_shop_price, snapshots,
	]
	var contract := "PASS-CONTRACT: progression first_furniture=%ds levels=2:%d,3:%d,4:%d,5:%d event_assisted_level10=%ds level10=%ds ending=%ds first_memory=%ds events=%d shop=%d points=8h:%d,12h:%d,20h:%d,30h:%d,48h:%d,72h:%d cadence=%ds sessions=%d items=%d/%d max_empty=%d" % [
		first_furniture_ready,
		int(level_times.get(2, -1)), int(level_times.get(3, -1)), int(level_times.get(4, -1)), int(level_times.get(5, -1)),
		event_assisted_level_ten_ready, level_ten_time,
		ending_second, first_memory_second, int(ending_audit.get("seen_events", 0)), total_shop_price,
		int((snapshots[8 * 3600] as Dictionary).points), int((snapshots[12 * 3600] as Dictionary).points),
		int((snapshots[20 * 3600] as Dictionary).points), int((snapshots[30 * 3600] as Dictionary).points),
		int((snapshots[48 * 3600] as Dictionary).points), int((snapshots[72 * 3600] as Dictionary).points),
		int(cadence_audit.get("completion_second", -1)), int(cadence_audit.get("sessions", 0)),
		int(cadence_audit.get("acquired_items", 0)), int(cadence_audit.get("target_items", 0)),
		int(cadence_audit.get("max_empty_sessions", 99)),
	]
	if failures.is_empty():
		print("PASS: progression pacing (%s)" % report)
		print(contract)
		quit(0)
	else:
		printerr("FAIL: progression pacing (%s)" % report)
		for failure: String in failures:
			printerr("- %s" % failure)
		quit(1)


func _audit_short_session_cadence(catalog: ContentCatalog) -> Dictionary:
	var state := PigState.new()
	state.daily_points = 75
	state.familiarity_xp = 5
	state.normalize()
	var simulation := Simulation.new(20260718)
	var behavior_director := BehaviorDirector.new(20260718)
	var event_director := EventDirector.new(20260718)
	var total_items: int = _remaining_paid_content_count(catalog, state)
	var target_items: int = ceili(float(total_items) * CADENCE_TARGET_SHARE)
	var previous_level: int = state.familiarity_level
	var previous_unix: int = 0
	var session_has_content: bool = false
	var watched_this_session: bool = false
	var empty_sessions: int = 0
	var max_empty_sessions: int = 0
	var sessions: int = 0
	var watched_events: int = 0
	var purchased_items: int = 0
	for active_second: int in range(1, CADENCE_MAX_ACTIVE_SECONDS + 1):
		var unix_time: int = _cadence_session_unix(active_second)
		if (active_second - 1) % CADENCE_SESSION_SECONDS == 0 and previous_unix > 0:
			var settlement: Dictionary = GameClock.settle(previous_unix, unix_time)
			simulation.apply_offline(state, settlement)
			for sample_unix: int in GameSessionScript.offline_event_sample_times(settlement, unix_time):
				event_director.discover_one(catalog.events, state, sample_unix, false)
			if _watch_next_pending_event(catalog, event_director, state, unix_time):
				session_has_content = true
				watched_this_session = true
				watched_events += 1
		simulation.advance(1.0, state, catalog.behaviors, behavior_director, unix_time, false, false)
		previous_unix = unix_time
		if state.familiarity_level != previous_level:
			previous_level = state.familiarity_level
			session_has_content = true
		if active_second % EVENT_CHECK_SECONDS == 0:
			event_director.discover_one(catalog.events, state, unix_time, false)
		if active_second % CADENCE_SESSION_SECONDS != 0:
			continue
		if not watched_this_session and _watch_next_pending_event(catalog, event_director, state, unix_time):
			session_has_content = true
			watched_events += 1
		if not _buy_cheapest_content(catalog, state, unix_time).is_empty():
			session_has_content = true
			purchased_items += 1
		sessions += 1
		if session_has_content:
			empty_sessions = 0
		else:
			empty_sessions += 1
			max_empty_sessions = maxi(max_empty_sessions, empty_sessions)
		var acquired_items: int = total_items - _remaining_paid_content_count(catalog, state)
		if acquired_items >= target_items:
			return {
				"completion_second": active_second,
				"sessions": sessions,
				"target_items": target_items,
				"acquired_items": acquired_items,
				"max_empty_sessions": max_empty_sessions,
				"watched_events": watched_events,
				"purchased_items": purchased_items,
				"points": state.daily_points,
				"level": state.familiarity_level,
			}
		session_has_content = false
		watched_this_session = false
	return {
		"completion_second": -1,
		"sessions": sessions,
		"target_items": target_items,
		"acquired_items": total_items - _remaining_paid_content_count(catalog, state),
		"max_empty_sessions": max_empty_sessions,
		"watched_events": watched_events,
		"purchased_items": purchased_items,
		"points": state.daily_points,
		"level": state.familiarity_level,
	}


func _watch_next_pending_event(
	catalog: ContentCatalog,
	event_director: EventDirector,
	state: PigState,
	unix_time: int
) -> bool:
	if state.pending_events.is_empty():
		return false
	var event: Dictionary = catalog.get_item("events", state.pending_events[0])
	if event.is_empty():
		return false
	var rewards: Dictionary = event_director.mark_watched(event, state, unix_time)
	return bool(rewards.get("first_watch", false))


func _remaining_paid_content_count(catalog: ContentCatalog, state: PigState) -> int:
	var count: int = 0
	for item: Dictionary in catalog.furniture:
		if int(item.get("price", 0)) > 0 and not str(item.get("id", "")) in state.owned_furniture:
			count += 1
	for item: Dictionary in catalog.snacks:
		if not str(item.get("id", "")) in state.owned_snacks:
			count += 1
	for item: Dictionary in catalog.outfits:
		if not str(item.get("id", "")) in state.owned_outfits:
			count += 1
	return count


func _buy_cheapest_content(catalog: ContentCatalog, state: PigState, unix_time: int) -> String:
	var best: Dictionary = {}
	var best_type: String = ""
	for type: String in ["furniture", "snack", "outfit"]:
		var items: Array = catalog.furniture if type == "furniture" else (catalog.snacks if type == "snack" else catalog.outfits)
		var owned: Array[String] = state.owned_furniture if type == "furniture" else (state.owned_snacks if type == "snack" else state.owned_outfits)
		for item_value: Variant in items:
			var item: Dictionary = item_value as Dictionary
			var id: String = str(item.get("id", ""))
			var price: int = int(item.get("price", 0))
			if id in owned or price <= 0 or state.familiarity_level < int(item.get("min_level", 1)):
				continue
			if type == "furniture" and state.familiarity_level < int(AUDIT_AREA_LEVELS.get(str(item.get("area", "")), 11)):
				continue
			if best.is_empty() or price < int(best.get("price", 0)):
				best = item
				best_type = type
	if best.is_empty() or not state.spend_points(int(best.get("price", 0))):
		return ""
	var id: String = str(best.get("id", ""))
	state.unlock(best_type, id, unix_time)
	if best_type == "furniture":
		_place_event_furniture(catalog, state, id)
	elif best_type == "snack":
		state.satiety = minf(state.satiety + float(best.get("satiety", 0.0)), 100.0)
		state.interest = minf(state.interest + float(best.get("interest", 0.0)), 100.0)
	return "%s:%s" % [best_type, id]


func _cadence_session_unix(active_second: int) -> int:
	var session_index: int = (active_second - 1) / CADENCE_SESSION_SECONDS
	var within_session: int = (active_second - 1) % CADENCE_SESSION_SECONDS
	var timezone: Dictionary = Time.get_time_zone_from_system()
	var bias_seconds: int = int(timezone.get("bias", 0)) * 60
	var start_local_day: int = floori(float(START_UNIX + bias_seconds) / 86400.0) * 86400
	var start_hour: int = SESSION_START_HOURS[session_index % SESSION_START_HOURS.size()]
	return start_local_day + session_index * 86400 + start_hour * 3600 + within_session - bias_seconds


func _audit_theme_ending(catalog: ContentCatalog) -> Dictionary:
	var state := PigState.new()
	state.daily_points = 75
	state.familiarity_xp = 5
	state.normalize()
	var simulation := Simulation.new(20260717)
	var behavior_director := BehaviorDirector.new(20260717)
	var event_director := EventDirector.new(20260717)
	var purchased: Array[String] = []
	var first_memory_second: int = -1
	for active_second: int in range(1, ENDING_MAX_SECONDS + 1):
		var unix_time: int = _session_unix(active_second)
		simulation.advance(1.0, state, catalog.behaviors, behavior_director, unix_time, false, false)
		if active_second % EVENT_CHECK_SECONDS == 0:
			_prepare_next_unseen_event(catalog, state, unix_time, purchased)
			var discovery: Dictionary = event_director.discover_one(catalog.events, state, unix_time)
			if not discovery.is_empty():
				var event: Dictionary = discovery.get("event", {}) as Dictionary
				event_director.mark_watched(event, state, unix_time)
				if first_memory_second < 0:
					first_memory_second = active_second
		if state.familiarity_level >= 10 and state.seen_events.size() == catalog.events.size():
			return {
				"completion_second": active_second,
				"first_memory_second": first_memory_second,
				"level": state.familiarity_level,
				"seen_events": state.seen_events.size(),
				"purchased_event_furniture": purchased.size(),
				"state": {"satiety": snappedf(state.satiety, 0.1), "energy": snappedf(state.energy, 0.1), "interest": snappedf(state.interest, 0.1)},
			}
	return {
		"completion_second": -1,
		"first_memory_second": first_memory_second,
		"level": state.familiarity_level,
		"seen_events": state.seen_events.size(),
		"seen_event_ids": state.seen_events,
		"missing_events": _missing_event_ids(catalog, state),
		"purchased_event_furniture": purchased,
		"state": {"satiety": state.satiety, "energy": state.energy, "interest": state.interest, "points": state.daily_points},
	}


func _prepare_next_unseen_event(
	catalog: ContentCatalog,
	state: PigState,
	unix_time: int,
	purchased: Array[String]
) -> void:
	var hour: int = GameClock.local_hour(unix_time)
	for event: Dictionary in catalog.events:
		var event_id: String = str(event.get("id", ""))
		if event_id in state.seen_events or event_id in state.pending_events or event_id in state.summarized_events:
			continue
		if state.familiarity_level < int(event.get("min_level", 1)):
			continue
		if not EventDirector._contains_all(state.seen_events, event.get("prerequisite_events", []) as Array):
			continue
		if not BehaviorDirector._matches_time(str(event.get("time", "any")), hour):
			continue
		if not EventDirector._matches_state_ranges(event.get("state_ranges", {}) as Dictionary, state):
			continue
		var ready: bool = true
		for furniture_value: Variant in event.get("required_furniture", []):
			var furniture_id: String = str(furniture_value)
			if not furniture_id in state.owned_furniture:
				var item: Dictionary = catalog.get_item("furniture", furniture_id)
				if item.is_empty() or state.familiarity_level < int(item.get("min_level", 1)):
					ready = false
					break
				if not state.spend_points(int(item.get("price", 0))):
					# An ending-focused player saves for the next prerequisite instead of
					# spending the remaining balance on a later optional target.
					return
				state.unlock("furniture", furniture_id, unix_time)
				purchased.append(furniture_id)
			if not _place_event_furniture(catalog, state, furniture_id):
				ready = false
				break
		if ready:
			# Calling the production director still decides which of the currently
			# eligible memories appears; this helper only models an engaged player
			# rotating owned furniture to pursue unseen content.
			return


func _place_event_furniture(catalog: ContentCatalog, state: PigState, furniture_id: String) -> bool:
	var item: Dictionary = catalog.get_item("furniture", furniture_id)
	if item.is_empty():
		return false
	for slot_id: String in AUDIT_ROOM_SLOTS:
		var spec: Array = AUDIT_ROOM_SLOTS[slot_id] as Array
		if str(spec[0]) == str(item.get("area", "")) and str(spec[1]) == str(item.get("slot", "")):
			state.placed_furniture[slot_id] = furniture_id
			return true
	return false


func _session_unix(active_second: int) -> int:
	var session_index: int = (active_second - 1) / SESSION_SECONDS
	var within_session: int = (active_second - 1) % SESSION_SECONDS
	var timezone: Dictionary = Time.get_time_zone_from_system()
	var bias_seconds: int = int(timezone.get("bias", 0)) * 60
	var start_local_day: int = floori(float(START_UNIX + bias_seconds) / 86400.0) * 86400
	var start_hour: int = SESSION_START_HOURS[session_index % SESSION_START_HOURS.size()]
	return start_local_day + session_index * 86400 + start_hour * 3600 + within_session - bias_seconds


func _missing_event_ids(catalog: ContentCatalog, state: PigState) -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in catalog.events:
		var event_id: String = str(event.get("id", ""))
		if not event_id in state.seen_events:
			result.append(event_id)
	return result
