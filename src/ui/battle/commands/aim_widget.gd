class_name AimWidget
extends CommandWidget
## OPTIONAL_AIM: a reticle sweeps across the field; fire as it crosses the weak spot. Same timing
## maths as TIMING, presented spatially (bows' weak-point shots). Never mandatory: a Miss still hits.


func instruction() -> String:
	return "Fire %s on the weak spot" % _key()


func _tick() -> void:
	if elapsed_ms() > spec.end_time_ms() + 80.0:
		_finish(Enums.ExecutionGrade.MISS, "no shot")


func _handle(event: InputEvent) -> void:
	if _fresh_press(event):
		var press := elapsed_ms()
		_finish(CommandRules.grade_press(spec, press), timing_word(press - spec.target_time_ms()))


func _draw() -> void:
	if spec == null:
		return
	_draw_frame()
	var bar := _bar_rect()
	var field := Rect2(bar.position.x, bar.position.y - 10.0, bar.size.x, bar.size.y + 20.0)
	_draw_zone_bar(field, spec.target_position, spec.good_window_ms / spec.duration_ms, spec.perfect_window_ms / spec.duration_ms)
	var center := Vector2(field.position.x + field.size.x * spec.target_position, field.get_center().y)
	var good_radius := spec.good_window_ms / spec.duration_ms * field.size.x * 0.5
	var perfect_radius := spec.perfect_window_ms / spec.duration_ms * field.size.x * 0.5
	draw_circle(center, minf(good_radius, field.size.y * 0.5), Color(UITheme.ACCENT, 0.25))
	draw_circle(center, minf(perfect_radius, field.size.y * 0.45), Color(UITheme.ACCENT, 0.85))
	var progress := clampf((elapsed_ms() - spec.lead_in_ms) / spec.duration_ms, 0.0, 1.0)
	var reticle := Vector2(field.position.x + progress * field.size.x, field.get_center().y)
	var color := UITheme.TEXT if elapsed_ms() >= spec.lead_in_ms else UITheme.TEXT_FAINT
	draw_arc(reticle, 12.0, 0, TAU, 24, color, 2.0)
	draw_line(reticle + Vector2(-18, 0), reticle + Vector2(-7, 0), color, 2.0)
	draw_line(reticle + Vector2(7, 0), reticle + Vector2(18, 0), color, 2.0)
	draw_line(reticle + Vector2(0, -18), reticle + Vector2(0, -7), color, 2.0)
	draw_line(reticle + Vector2(0, 7), reticle + Vector2(0, 18), color, 2.0)
