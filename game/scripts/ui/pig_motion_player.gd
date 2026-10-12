class_name PigMotionPlayer
extends RefCounted

var source: Dictionary = {}
var target: Dictionary = {}
var pending: Dictionary = {}
var elapsed: float = 0.0
var duration: float = 0.0
var clock: float = 0.0
var breath_phase: float = 0.0
var facing: float = 1.0
var room_grounded: bool = false
var _facing_target: float = 1.0
var _turn_elapsed: float = 0.3


func present(appearance: Dictionary, immediate: bool = false) -> void:
	if immediate or target.is_empty():
		source = appearance
		target = appearance
		pending = {}
		elapsed = 0.0
		duration = 0.0
		return
	if appearance == target:
		pending = {}
		return
	if transitioning():
		pending = appearance
		return
	_begin(appearance)


func advance(delta: float) -> void:
	var consumed: float = clampf(delta, 0.0, 0.1)
	clock += consumed
	breath_phase = fposmod(breath_phase + consumed * TAU / profile().z, TAU)
	_turn_elapsed = minf(_turn_elapsed + consumed, 0.3)
	if _turn_elapsed >= 0.15:
		facing = _facing_target
	if not transitioning():
		return
	elapsed = minf(elapsed + consumed, duration)
	if elapsed >= duration:
		source = target
		duration = 0.0
		elapsed = 0.0
		if not pending.is_empty():
			var next: Dictionary = pending
			pending = {}
			_begin(next)


func transitioning() -> bool:
	return duration > 0.0


func weight() -> float:
	if not transitioning():
		return 1.0
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	return progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)


func _begin(appearance: Dictionary) -> void:
	source = target
	target = appearance
	elapsed = 0.0
	if str(source.body_id) != str(target.body_id):
		duration = 0.75 if str(target.body_id) in ["body_prone", "body_flat", "body_corner"] else 0.55
	else:
		duration = 0.3


func selected() -> Dictionary:
	return source if weight() < 0.5 else target


func blink() -> float:
	var result: float = 1.0
	var blink_phase: float = fposmod(clock, 5.8)
	if blink_phase > 5.55:
		result = _eyelid((blink_phase - 5.55) / 0.25)
	if transitioning() and (str(source.face_id) != str(target.face_id) or str(source.body_id) != str(target.body_id)):
		result = minf(result, _eyelid(weight()))
	if _turn_elapsed < 0.3:
		result = minf(result, _eyelid(_turn_elapsed / 0.3))
	return result


static func _eyelid(progress: float) -> float:
	return maxf(1.0 - pow(sin(PI * progress), 4.0), 0.04)


func face_direction(direction: float) -> void:
	var next: float = -1.0 if direction > 0.0 else 1.0
	if next == _facing_target:
		return
	_facing_target = next
	_turn_elapsed = 0.0


func orientation(dimensions: Vector2) -> Transform2D:
	return Transform2D(Vector2(facing, 0.0), Vector2(0.0, 1.0), Vector2((1.0 - facing) * dimensions.x * 0.5, 0.0))


func profile() -> Vector4:
	return _profile_for(source).lerp(_profile_for(target), weight())


static func _profile_for(appearance: Dictionary) -> Vector4:
	var motion: Dictionary = PigVisualRig.pose_motion_for(str(appearance.get("body_id", "body_base")))
	var animation: String = str(appearance.get("animation", ""))
	return Vector4(float(motion.get("breath_amount", 0.008)), float(motion.get("sway_radians", 0.008)), float(motion.get("period_seconds", 4.8)), 1.0 if animation in ["walk", "run", "crawl"] else 0.0)


func pose_transform(dimensions: Vector2, from_target: bool) -> Transform2D:
	var source_id: String = str(source.body_id)
	var target_id: String = str(target.body_id)
	var source_fit: Transform2D = PigVisualRig.fit_transform(dimensions, source_id)
	var target_fit: Transform2D = PigVisualRig.fit_transform(dimensions, target_id)
	var amount: float = weight()
	var anchor: Vector2 = (source_fit * PigVisualRig.snout_for(source_id, 0)).lerp(target_fit * PigVisualRig.snout_for(target_id, 0), amount)
	var motion: Vector4 = profile()
	var pulse: float = sin(breath_phase)
	var transition_pulse: float = sin(PI * amount) if transitioning() else 0.0
	var turn_pulse: float = sin(PI * _turn_elapsed / 0.3)
	var rotation: float = motion.y * pulse + transition_pulse * 0.016 + turn_pulse * 0.025
	var uniform: float = lerpf(source_fit.x.length(), target_fit.x.length(), amount) * (1.0 + motion.x * pulse)
	anchor.y -= (1.0 - cos(clock * TAU / 0.8)) * 0.8 * motion.w
	anchor.y += transition_pulse * 1.5 + turn_pulse * 1.5
	var basis := Transform2D(rotation, Vector2(uniform, uniform), 0.0, Vector2.ZERO)
	var nose: Vector2 = PigVisualRig.snout_for(target_id if from_target else source_id, 0)
	basis.origin = anchor - basis * nose
	if room_grounded:
		var selected_id: String = target_id if from_target else source_id
		var ground := Vector2(128, PigVisualRig.ground_for(selected_id))
		var support: Vector2 = (source_fit * Vector2(128, PigVisualRig.ground_for(source_id))).lerp(target_fit * Vector2(128, PigVisualRig.ground_for(target_id)), amount)
		basis.origin = support - basis.basis_xform(ground)
	return orientation(dimensions) * basis
