class_name HoldReleaseWidget
extends CommandWidget
## HOLD_RELEASE: hold the command input to charge the gauge, release in the bright zone.
## Holding past a full gauge overcharges into a Miss.

const START_TIMEOUT_MS := 3500.0

var _hold_start_us: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(520, 120)
	size = custom_minimum_size


func held_ms() -> float:
	if _hold_start_us < 0:
		return 0.0
	return (Time.get_ticks_usec() - _hold_start_us) / 1000.0


func _process(_delta: float) -> void:
	if not _done:
		if _hold_start_us < 0 and elapsed_ms() > START_TIMEOUT_MS:
			_finish(Enums.ExecutionGrade.MISS)
		elif _hold_start_us >= 0 and held_ms() > spec.duration_ms + 60.0:
			_finish(Enums.ExecutionGrade.MISS)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if _hold_start_us < 0 and event.is_action_pressed(InputBindings.COMMAND, false):
		_hold_start_us = Time.get_ticks_usec()
		AudioManager.play(AudioManager.Cue.CHARGE)
		get_viewport().set_input_as_handled()
	elif _hold_start_us >= 0 and event.is_action_released(InputBindings.COMMAND):
		get_viewport().set_input_as_handled()
		_finish(CommandRules.grade_hold(spec, held_ms()))


func _draw() -> void:
	if spec == null:
		return
	var hint := "Hold %s, release in the bright zone" % _key_hint() if _hold_start_us < 0 else "Release!"
	_draw_frame(hint)
	var bar := Rect2(30, 48, size.x - 60, 26)
	_draw_zone_bar(bar, spec.target_position, spec.good_window_ms / spec.duration_ms, spec.perfect_window_ms / spec.duration_ms)
	var fill := clampf(held_ms() / spec.duration_ms, 0.0, 1.0)
	var color := Color(0.55, 0.85, 1.0, 0.6) if held_ms() <= spec.duration_ms else Color(1, 0.3, 0.25, 0.7)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), color)
	draw_rect(Rect2(bar.position.x + bar.size.x * fill - 2, bar.position.y - 6, 4, bar.size.y + 12), Color.WHITE)
