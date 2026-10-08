class_name TimingWidget
extends CommandWidget
## TIMING: an indicator sweeps across the bar; press as it crosses the bright zone.


func instruction() -> String:
	return "Press %s in the bright zone" % _key()


func _tick() -> void:
	if elapsed_ms() > spec.end_time_ms() + 80.0:
		_finish(Enums.ExecutionGrade.MISS, "no press")


func _handle(event: InputEvent) -> void:
	if _fresh_press(event):
		var press := elapsed_ms()
		var grade := CommandRules.grade_press(spec, press)
		_finish(grade, timing_word(press - spec.target_time_ms()))


func _draw() -> void:
	if spec == null:
		return
	_draw_frame()
	var bar := _bar_rect()
	_draw_zone_bar(bar, spec.target_position, spec.good_window_ms / spec.duration_ms, spec.perfect_window_ms / spec.duration_ms)
	var progress := clampf((elapsed_ms() - spec.lead_in_ms) / spec.duration_ms, 0.0, 1.0)
	var x := bar.position.x + progress * bar.size.x
	var color := UITheme.TEXT if elapsed_ms() >= spec.lead_in_ms else UITheme.TEXT_FAINT
	draw_rect(Rect2(x - 2, bar.position.y - 8, 4, bar.size.y + 16), color)
