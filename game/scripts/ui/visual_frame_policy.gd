class_name VisualFramePolicy
extends RefCounted

const FRAME_STEP: float = 0.1


static func camera_shake_offset(requested: bool, progress: float, elapsed: float, enabled: bool, reduce_motion: bool) -> Vector2:
	if not requested or not enabled or reduce_motion:
		return Vector2.ZERO
	var envelope: float = maxf(sin(PI * clampf(progress, 0.0, 1.0)), 0.0)
	var strength: float = 3.5 * envelope
	return Vector2(
		roundf(sin(elapsed * 31.0) * strength),
		roundf(cos(elapsed * 29.0) * strength * 0.75)
	)
