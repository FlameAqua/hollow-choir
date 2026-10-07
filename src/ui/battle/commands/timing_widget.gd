class_name TimingWidget
extends CommandWidget
## TIMING: an indicator sweeps across the bar; press as it crosses the bright zone.


func _ready() -> void:
	custom_minimum_size = Vector2(520, 120)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	if not _done and elapsed_ms() > spec.end_time_ms() + 80.0:
		_finish(Enums.ExecutionGrade.MISS)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _done and event.is_action_pressed(InputBindings.COMMAND, false):
		get_viewport().set_input_as_handled()
		_finish(CommandRules.grade_press(spec, elapsed_ms()))


func _draw() -> void:
	if spec == null:
		return
	_draw_frame("Press %s in the bright zone" % _key_hint())
	var bar := Rect2(30, 48, size.x - 60, 26)
	_draw_zone_bar(bar, spec.target_position, spec.good_window_ms / spec.duration_ms, spec.perfect_window_ms / spec.duration_ms)
	var progress := clampf((elapsed_ms() - spec.lead_in_ms) / spec.duration_ms, 0.0, 1.0)
	var x := bar.position.x + progress * bar.size.x
	draw_rect(Rect2(x - 2, bar.position.y - 8, 4, bar.size.y + 16), Color.WHITE if elapsed_ms() >= spec.lead_in_ms else UITheme.TEXT_DIM)
