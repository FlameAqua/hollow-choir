class_name AimWidget
extends CommandWidget
## OPTIONAL_AIM: a reticle sweeps across the target's silhouette; fire as it crosses the weak spot.
## Same timing maths as TIMING, presented spatially (bows' weak-point shots).


func _ready() -> void:
	custom_minimum_size = Vector2(520, 150)
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
	_draw_frame("Fire %s on the weak spot" % _key_hint())
	var field := Rect2(30, 40, size.x - 60, 76)
	draw_rect(field, Color(0.08, 0.09, 0.12))
	var center := Vector2(field.position.x + field.size.x * spec.target_position, field.get_center().y)
	var good_radius := spec.good_window_ms / spec.duration_ms * field.size.x * 0.5
	var perfect_radius := spec.perfect_window_ms / spec.duration_ms * field.size.x * 0.5
	draw_circle(center, good_radius, Color(0.85, 0.7, 0.3, 0.25))
	draw_circle(center, perfect_radius, Color(1.0, 0.85, 0.35, 0.8))
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(8, 0), center + Vector2(0, 8),
		center + Vector2(-8, 0)]), Color.WHITE)
	var progress := clampf((elapsed_ms() - spec.lead_in_ms) / spec.duration_ms, 0.0, 1.0)
	var reticle := Vector2(field.position.x + progress * field.size.x, field.get_center().y + sin(progress * TAU * 1.5) * 14.0)
	var color := Color.WHITE if elapsed_ms() >= spec.lead_in_ms else UITheme.TEXT_DIM
	draw_arc(reticle, 14.0, 0, TAU, 24, color, 2.0)
	draw_line(reticle + Vector2(-20, 0), reticle + Vector2(-8, 0), color, 2.0)
	draw_line(reticle + Vector2(8, 0), reticle + Vector2(20, 0), color, 2.0)
	draw_line(reticle + Vector2(0, -20), reticle + Vector2(0, -8), color, 2.0)
	draw_line(reticle + Vector2(0, 8), reticle + Vector2(0, 20), color, 2.0)
