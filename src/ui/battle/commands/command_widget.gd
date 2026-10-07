class_name CommandWidget
extends Control
## Base for the four reusable action-command components. Real-time input; grading always goes
## through CommandRules (the same pure functions the simulator uses).

signal finished(grade: Enums.ExecutionGrade)

const RESULT_HOLD := 0.35
const GRADE_COLORS := [Color(0.6, 0.6, 0.6), Color(0.9, 0.9, 0.85), Color(1.0, 0.82, 0.3)]
const GRADE_WORDS := ["MISS", "GOOD", "PERFECT!"]

var spec: CommandSpec
var action_name: String = ""
var _start_us: int = 0
var _done := false
var _result: int = -1
var _font: Font


func begin(p_spec: CommandSpec, p_action_name: String) -> void:
	spec = p_spec
	action_name = p_action_name
	_font = get_theme_default_font()
	_start_us = Time.get_ticks_usec()
	_done = false
	_result = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_input(true)


func elapsed_ms() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1000.0


func _finish(grade: Enums.ExecutionGrade) -> void:
	if _done:
		return
	_done = true
	_result = grade
	set_process_input(false)
	match grade:
		Enums.ExecutionGrade.PERFECT:
			AudioManager.play(AudioManager.Cue.PERFECT)
		Enums.ExecutionGrade.GOOD:
			AudioManager.play(AudioManager.Cue.GOOD)
		_:
			AudioManager.play(AudioManager.Cue.MISS)
	queue_redraw()
	await get_tree().create_timer(RESULT_HOLD).timeout
	finished.emit(grade)


func _draw_frame(title_hint: String) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.04, 0.04, 0.07, 0.9))
	draw_rect(rect, UITheme.ACCENT.darkened(0.3), false, 1.5)
	var font_size := UITheme.font_size(0.85)
	draw_string(_font, Vector2(14, 8 + font_size), action_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.ACCENT)
	draw_string(_font, Vector2(0, 8 + font_size), title_hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14, UITheme.font_size(0.75), UITheme.TEXT_DIM)
	if _result >= 0:
		var big := UITheme.font_size(1.5)
		draw_string(_font, Vector2(0, size.y - 14), GRADE_WORDS[_result], HORIZONTAL_ALIGNMENT_CENTER, size.x, big, GRADE_COLORS[_result])


## Horizontal bar with Good and Perfect zones centred on [param target] (0..1 along the bar).
func _draw_zone_bar(bar: Rect2, target: float, good_fraction: float, perfect_fraction: float) -> void:
	draw_rect(bar, Color(0.1, 0.1, 0.14))
	var good := Rect2(bar.position.x + (target - good_fraction * 0.5) * bar.size.x, bar.position.y,
		good_fraction * bar.size.x, bar.size.y)
	var perfect := Rect2(bar.position.x + (target - perfect_fraction * 0.5) * bar.size.x, bar.position.y,
		perfect_fraction * bar.size.x, bar.size.y)
	draw_rect(good.intersection(bar), Color(0.85, 0.7, 0.3, 0.35))
	draw_rect(perfect.intersection(bar), Color(1.0, 0.85, 0.35, 0.85))
	draw_rect(bar, UITheme.BORDER, false, 1.0)


func _key_hint() -> String:
	return "[%s]" % InputBindings.key_label(InputBindings.COMMAND)
