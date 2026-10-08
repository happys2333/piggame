class_name GameClock
extends RefCounted

const FULL_RATE_SECONDS: int = 8 * 60 * 60
const LOW_RATE_SECONDS: int = 16 * 60 * 60
const MAX_OFFLINE_SECONDS: int = FULL_RATE_SECONDS + LOW_RATE_SECONDS
const FULL_RATE_POINT_CAP: int = 100
const LOW_RATE_POINT_CAP: int = 40

var _unix_time_provider: Callable


func _init(unix_time_provider: Callable = Callable()) -> void:
	_unix_time_provider = unix_time_provider


static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func current_unix() -> int:
	if _unix_time_provider.is_valid():
		return int(_unix_time_provider.call())
	return now_unix()


static func local_hour(unix_time: int) -> int:
	var timezone: Dictionary = Time.get_time_zone_from_system()
	return hour_with_timezone_bias(unix_time, int(timezone.get("bias", 0)))


static func hour_with_timezone_bias(unix_time: int, bias_minutes: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60).hour)


static func local_date_string(unix_time: int) -> String:
	var timezone: Dictionary = Time.get_time_zone_from_system()
	return date_string_with_timezone_bias(unix_time, int(timezone.get("bias", 0)))


static func date_string_with_timezone_bias(unix_time: int, bias_minutes: int) -> String:
	return Time.get_date_string_from_unix_time(unix_time + bias_minutes * 60)


static func settle(last_unix: int, current_unix: int) -> Dictionary:
	var raw_seconds: int = current_unix - last_unix
	var elapsed_seconds: int = clampi(raw_seconds, 0, MAX_OFFLINE_SECONDS)
	var full_seconds: int = mini(elapsed_seconds, FULL_RATE_SECONDS)
	var low_seconds: int = mini(maxi(elapsed_seconds - FULL_RATE_SECONDS, 0), LOW_RATE_SECONDS)
	var full_points: int = roundi(float(full_seconds) / float(FULL_RATE_SECONDS) * FULL_RATE_POINT_CAP)
	var low_points: int = roundi(float(low_seconds) / float(LOW_RATE_SECONDS) * LOW_RATE_POINT_CAP)
	var summary_key := "OFFLINE_NONE"
	if raw_seconds > MAX_OFFLINE_SECONDS:
		summary_key = "OFFLINE_MANY_DAYS"
	elif elapsed_seconds >= FULL_RATE_SECONDS:
		summary_key = "OFFLINE_LONG"
	elif elapsed_seconds >= 60:
		summary_key = "OFFLINE_SHORT"
	return {
		"raw_seconds": raw_seconds,
		"elapsed_seconds": elapsed_seconds,
		"full_seconds": full_seconds,
		"low_seconds": low_seconds,
		"points": full_points + low_points,
		"summary_key": summary_key,
		"clock_went_backwards": raw_seconds < 0,
		"was_capped": raw_seconds > MAX_OFFLINE_SECONDS,
	}
