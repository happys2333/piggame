class_name EventViewer
extends Control

signal finished
signal photo_captured(event_id: String, image: Image)

const VISUAL_FRAME_STEP: float = VisualFramePolicy.FRAME_STEP
const PANEL_PREFERRED_SIZE := Vector2(760, 560)
const OVERLAY_MARGIN: float = 16.0

var _event: Dictionary = {}
var _elapsed: float = 0.0
var _duration: float = 1.0
var _duration_scale: float = 1.0
var _progress: ProgressBar
var _stage: EventStage
var _stage_frame: Control
var _steps: Array = []
var _step_index: int = 0
var _step_elapsed: float = 0.0
var _capture_photo: bool = true
var _finished: bool = false
var _last_visual_progress: float = -1.0
var _capture_viewport: SubViewport
var _capture_pixel_rect: Rect2i


func play(event: Dictionary, capture_photo: bool = true) -> void:
	_event = event
	_capture_photo = capture_photo
	_duration_scale = clampf(GameSession.bubble_duration_scale, 0.75, 2.0)
	_steps = event.get("steps", []) as Array
	_duration = 0.0
	for step: Variant in _steps:
		if step is Dictionary:
			_duration += float((step as Dictionary).get("duration", 0.0))
	_duration = maxf(_duration, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color("#4e344477")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_top", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_right", int(OVERLAY_MARGIN))
	safe_margin.add_theme_constant_override("margin_bottom", int(OVERLAY_MARGIN))
	add_child(safe_margin)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "EventPanel"
	var viewport_size: Vector2 = get_viewport_rect().size
	panel.custom_minimum_size = Vector2(
		minf(PANEL_PREFERRED_SIZE.x, maxf(viewport_size.x - OVERLAY_MARGIN * 2.0, 720.0)),
		minf(PANEL_PREFERRED_SIZE.y, maxf(viewport_size.y - OVERLAY_MARGIN * 2.0, 480.0))
	)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)
	var title := Label.new()
	title.text = tr(str(_event.get("title_key", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var line := Label.new()
	var variants: Array = _event.get("variants", []) as Array
	line.text = tr(str(variants.pick_random())) if not variants.is_empty() else tr(str(_event.get("summary_key", "")))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(680, 52)
	line.add_theme_font_size_override("font_size", 22)
	content.add_child(line)
	_stage_frame = Control.new()
	_stage_frame.custom_minimum_size = Vector2(680, 265)
	_stage_frame.clip_contents = true
	content.add_child(_stage_frame)
	_stage = EventStage.new()
	_stage.size = _stage_frame.custom_minimum_size
	_stage_frame.add_child(_stage)
	_apply_step(0)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(560, 12)
	content.add_child(_progress)
	var skip := Button.new()
	skip.name = "EventSkipButton"
	skip.text = tr("EVENT_SKIP")
	skip.pressed.connect(_finish)
	content.add_child(skip)


func _process(delta: float) -> void:
	if _finished or _event.is_empty():
		return
	var presentation_delta: float = maxf(delta, 0.0) / _duration_scale
	_elapsed += presentation_delta
	_step_elapsed += presentation_delta
	if not _steps.is_empty():
		var current: Dictionary = _steps[_step_index] as Dictionary
		var step_duration: float = maxf(float(current.get("duration", 1.0)), 0.01)
		var visual_frame_step: float = VISUAL_FRAME_STEP / _duration_scale
		var visual_elapsed: float = floorf(_step_elapsed / visual_frame_step) * visual_frame_step
		var visual_progress: float = clampf(visual_elapsed / step_duration, 0.0, 1.0)
		if not is_equal_approx(visual_progress, _last_visual_progress):
			_last_visual_progress = visual_progress
			_stage.set_step_progress(visual_progress)
		_update_camera_shake(current, visual_progress)
		if _step_elapsed >= step_duration and _step_index < _steps.size() - 1:
			_step_elapsed -= step_duration
			_step_index += 1
			_apply_step(_step_index)
	if is_instance_valid(_progress):
		_progress.value = _elapsed / _duration * 100.0
	if _elapsed >= _duration:
		_finish()


func _apply_step(index: int) -> void:
	if _steps.is_empty() or not is_instance_valid(_stage):
		return
	var step: Dictionary = _steps[clampi(index, 0, _steps.size() - 1)] as Dictionary
	_last_visual_progress = -1.0
	_stage.position = Vector2.ZERO
	_stage.set_step(_event, step)
	var audio: Node = get_node_or_null("/root/AudioService")
	if audio != null:
		audio.call("play_event_step", str(step.get("animation", "")))


func _update_camera_shake(step: Dictionary, progress: float) -> void:
	if not is_instance_valid(_stage) or not is_instance_valid(_stage_frame):
		return
	var session: Node = get_node_or_null("/root/GameSession")
	var camera_shake_enabled: bool = bool(session.get("camera_shake_enabled")) if session != null else true
	var reduce_motion: bool = bool(session.get("reduce_motion")) if session != null else false
	_stage.size = _stage_frame.size
	_stage.position = VisualFramePolicy.camera_shake_offset(
		bool(step.get("camera_shake", false)),
		progress,
		_elapsed,
		camera_shake_enabled,
		reduce_motion
	)
func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _capture_photo:
		if not _steps.is_empty():
			_step_index = _steps.size() - 1
			_apply_step(_step_index)
			_stage.set_step_progress(0.72)
		var viewport: Viewport = get_viewport()
		var viewport_pixels: Vector2i = viewport.get_texture().get_image().get_size()
		var pixel_scale: Vector2 = Vector2(viewport_pixels) / get_viewport_rect().size
		var pixel_rect: Rect2i = _stage_photo_pixel_rect(pixel_scale, viewport_pixels)
		_capture_pixel_rect = pixel_rect
		_capture_viewport = SubViewport.new()
		_capture_viewport.size = viewport_pixels
		_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_capture_viewport)
		var capture_frame := Control.new()
		capture_frame.position = _stage_frame.get_global_rect().position
		capture_frame.size = _stage_frame.size
		capture_frame.clip_contents = true
		_capture_viewport.add_child(capture_frame)
		_capture_viewport.canvas_transform = Transform2D(
			0.0, pixel_scale, 0.0, Vector2.ZERO
		)
		var stage_position: Vector2 = _stage.position
		_stage.set_process(false)
		_stage.reparent(capture_frame, false)
		_stage.position = stage_position
		RenderingServer.frame_post_draw.connect(_on_photo_frame_drawn, CONNECT_ONE_SHOT)
		return
	finished.emit()
	queue_free()


func _on_photo_frame_drawn() -> void:
	var photo: Image = _capture_viewport.get_texture().get_image().get_region(_capture_pixel_rect)
	_capture_viewport.queue_free()
	_capture_viewport = null
	photo_captured.emit(str(_event.get("id", "")), photo)
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_photo_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_photo_frame_drawn)


func _stage_photo_pixel_rect(pixel_scale: Vector2, viewport_pixels: Vector2i) -> Rect2i:
	var frame_rect: Rect2 = _stage_frame.get_global_rect()
	var clip_start: Vector2 = frame_rect.position.ceil()
	var clip_end: Vector2 = frame_rect.end.floor()
	var rect: Rect2 = _stage.get_global_rect().intersection(Rect2(clip_start, clip_end - clip_start))
	var first_pixel := Vector2i((rect.position * pixel_scale).ceil())
	var last_pixel := Vector2i((rect.end * pixel_scale).floor())
	first_pixel = first_pixel.clamp(Vector2i.ZERO, viewport_pixels - Vector2i.ONE)
	last_pixel = last_pixel.clamp(first_pixel + Vector2i.ONE, viewport_pixels)
	return Rect2i(first_pixel, last_pixel - first_pixel)
