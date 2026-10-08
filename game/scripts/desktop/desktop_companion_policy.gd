class_name DesktopCompanionPolicy
extends RefCounted

signal changed
signal timer_changed
signal break_ready

const FREQUENCIES: Array[String] = ["frequent", "normal", "rare", "off"]
const CONFIG_PATH: String = "res://game/data/catalog/desktop_companion.json"

var quiet: bool = false
var do_not_disturb: bool = false
var frequency: String = "normal"
var application_focused: bool = false
var timer_phase: String = "idle"
var timer_remaining: float = 0.0
var timer_paused: bool = false
var _last_timer_second: int = -1
var _explicit_feedback_until: int = 0
var _configuration: Dictionary = JsonStore.read_object(CONFIG_PATH)


func load_settings(data: Dictionary) -> void:
	quiet = data.get("desktop_quiet", false) if data.get("desktop_quiet", false) is bool else false
	do_not_disturb = data.get("desktop_do_not_disturb", false) if data.get("desktop_do_not_disturb", false) is bool else false
	var value: Variant = data.get("desktop_behavior_frequency", "normal")
	frequency = str(value) if value is String and str(value) in FREQUENCIES else "normal"
	changed.emit()


func settings() -> Dictionary:
	return {"desktop_quiet":quiet, "desktop_do_not_disturb":do_not_disturb, "desktop_behavior_frequency":frequency}


func set_application_focused(focused: bool) -> void:
	if not focused:
		_explicit_feedback_until = 0
	if application_focused == focused:
		return
	application_focused = focused
	changed.emit()


func proactive_allowed() -> bool:
	return application_focused and not quiet and not do_not_disturb and frequency != "off"


func autonomous_motion_allowed() -> bool:
	return proactive_allowed()


func effective_always_on_top(requested: bool) -> bool:
	return requested and application_focused and not do_not_disturb


func explicit_feedback_allowed() -> bool:
	return true


func note_explicit_interaction() -> void:
	_explicit_feedback_until = Time.get_ticks_msec() + int(_configuration.explicit_feedback_milliseconds)


func message_allowed() -> bool:
	return proactive_allowed() or Time.get_ticks_msec() < _explicit_feedback_until


func presentation_hold_seconds(legacy_reduced: bool) -> float:
	if frequency == "off":
		return INF
	return maxf(float(_configuration.presentation_hold_seconds[frequency]), DesktopFramePolicy.REDUCED_ACTION_HOLD_SECONDS if legacy_reduced else 0.0)


func start_work() -> void:
	timer_phase = "work"
	timer_remaining = float(_configuration.work_seconds)
	timer_paused = false
	_notify_timer()
	changed.emit()


func start_rest() -> bool:
	if timer_phase != "rest_ready":
		return false
	timer_phase = "rest"
	timer_remaining = float(_configuration.rest_seconds)
	timer_paused = false
	_notify_timer()
	changed.emit()
	return true


func stop_timer() -> void:
	timer_phase = "idle"
	timer_remaining = 0.0
	timer_paused = false
	_notify_timer()
	changed.emit()


func toggle_timer_pause() -> void:
	if timer_phase not in ["work", "rest"]:
		return
	timer_paused = not timer_paused
	_notify_timer()
	changed.emit()


func advance(seconds: float) -> void:
	if timer_paused or timer_phase not in ["work", "rest"] or not is_finite(seconds) or seconds <= 0.0:
		return
	timer_remaining = maxf(timer_remaining - seconds, 0.0)
	if timer_remaining <= 0.0:
		var finished_work: bool = timer_phase == "work"
		timer_phase = "rest_ready" if finished_work else "finished"
		_notify_timer()
		changed.emit()
		if finished_work and proactive_allowed():
			break_ready.emit()
	elif ceili(timer_remaining) != _last_timer_second:
		_notify_timer()


func timer_animation() -> String:
	if not proactive_allowed() or timer_paused:
		return ""
	if timer_phase == "work":
		return str(_configuration.work_animation)
	if timer_phase == "rest":
		return str(_configuration.rest_animation)
	return ""


func timer_snapshot() -> Dictionary:
	return {"phase":timer_phase, "remaining":ceili(timer_remaining), "paused":timer_paused}


func _notify_timer() -> void:
	_last_timer_second = ceili(timer_remaining)
	timer_changed.emit()
