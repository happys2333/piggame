extends DesktopWindowController

var native_drag_calls: int = 0
var manual_drag_calls: int = 0
var drag_delta := Vector2.ZERO


func _start_manual_window_drag() -> void:
	manual_drag_calls += 1
	set("_drag_window_position", Vector2(10, 20))


func _write_window_drag_position(position: Vector2i) -> void:
	drag_delta = Vector2(position) - Vector2(10, 20)


func _ensure_visible() -> void:
	pass


func _start_native_window_drag() -> void:
	native_drag_calls += 1
