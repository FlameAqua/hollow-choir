class_name HoldReleaseWidget
extends CommandWidget
## HOLD_RELEASE: hold the command input to charge the gauge, release in the bright zone. Holding
## past a full gauge overcharges into a Miss. Losing window focus mid-charge counts as releasing at
## that instant (the hold cannot be paused and resumed, so focus loss is never a free retry).

const START_TIMEOUT_MS := 3500.0

## Clock time (ms) when the charge began, or -1.
var _hold_start_ms: float = -1.0


func instruction() -> String:
	return "Hold %s, release in the bright zone" % _key() if _hold_start_ms < 0.0 else "Release!"


func held_ms() -> float:
	if _hold_start_ms < 0.0:
		return 0.0
	return elapsed_ms() - _hold_start_ms


func is_holding() -> bool:
	return _hold_start_ms >= 0.0


func _tick() -> void:
	if _hold_start_ms < 0.0 and elapsed_ms() > START_TIMEOUT_MS:
		_finish(Enums.ExecutionGrade.MISS, "no press")
	elif _hold_start_ms >= 0.0 and held_ms() > spec.duration_ms + 60.0:
		_finish(Enums.ExecutionGrade.MISS, "overcharged")


func _handle(event: InputEvent) -> void:
	if _hold_start_ms < 0.0:
		if _fresh_press(event):
			_hold_start_ms = elapsed_ms()
			AudioManager.play(AudioManager.Cue.CHARGE)
	elif event.is_action_released(InputBindings.COMMAND):
		get_viewport().set_input_as_handled()
		_release()


func _on_focus_lost() -> void:
	if _hold_start_ms >= 0.0:
		_release()


func _release() -> void:
	var held := held_ms()
	var grade := CommandRules.grade_hold(spec, held)
	var reason := "overcharged" if held > spec.duration_ms else timing_word(held - spec.target_time_ms())
	_finish(grade, reason)


func _draw() -> void:
	if spec == null:
		return
	_draw_frame()
	var bar := _bar_rect()
	_draw_zone_bar(bar, spec.target_position, spec.good_window_ms / spec.duration_ms, spec.perfect_window_ms / spec.duration_ms)
	var fill := clampf(held_ms() / spec.duration_ms, 0.0, 1.0)
	var color := Color(UITheme.WET, 0.6) if held_ms() <= spec.duration_ms else Color(UITheme.THREAT, 0.7)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), color)
	draw_rect(Rect2(bar.position.x + bar.size.x * fill - 2, bar.position.y - 6, 4, bar.size.y + 12), UITheme.TEXT)
