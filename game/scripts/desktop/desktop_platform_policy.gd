class_name DesktopPlatformPolicy
extends RefCounted


static func resolve(server: String, transparency_feature: bool, drag_feature: bool, transparency_requested: bool, pig_only_requested: bool) -> Dictionary:
	var positioning: bool = supports_global_positioning(server)
	var native_drag: bool = drag_feature and server in ["Windows", "macOS", "X11", "Wayland"]
	var transparency_available: bool = positioning and transparency_feature
	var transparency: bool = transparency_requested and transparency_available
	return {
		"positioning":positioning,
		"native_drag":native_drag,
		"transparency_available":transparency_available,
		"transparency":transparency,
		"pig_only":pig_only_requested and transparency and native_drag,
	}


static func supports_global_positioning(server: String) -> bool:
	return server in ["Windows", "macOS", "X11"]


static func detect(transparency_requested: bool, pig_only_requested: bool) -> Dictionary:
	return resolve(
		DisplayServer.get_name(),
		DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY),
		DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG),
		transparency_requested,
		pig_only_requested
	)
