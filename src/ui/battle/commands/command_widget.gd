class_name CommandWidget
extends Control
## Base for the reusable action-command components, shown in the decision dock (M1.1 F2). Grading
## always goes through CommandRules (the same pure functions the simulator uses).
##
## Input ownership: the press that confirmed the action never counts (a command key still held when
## the widget opens is latched until released); key repeat never counts; while the window has no
## focus the clock freezes, and it resumes only after every command key is released. The battle
## scene ignores Pause while this widget is open (pausing must never help timing). Feedback waits are
## tweens bound to this node, so freeing the battle mid-feedback drops them instead of resuming on a
## freed node (D-014).

signal finished(grade: Enums.ExecutionGrade)

const RESULT_HOLD := 0.4
const GRADE_COLORS := [Color("c9b9a8"), Color("f1ead5"), Color("e2c681")]
const GRADE_WORDS := ["MISS", "GOOD", "PERFECT"]

var spec: CommandSpec
## "STRIKE → THORNHOUND".
var title: String = ""
var clock := TimingClock.new()
var latch := FreshPressLatch.new()
var _done := false
var _result: int = -1
## Why a Miss happened, when measured ("early", "late", "no press", "overcharged").
var _miss_reason: String = ""
var _focus_lost := false
var _preparing := false
var _font: Font


func begin(p_spec: CommandSpec, p_title: String, preparing: bool = false) -> void:
	spec = p_spec
	title = p_title
	_font = get_theme_default_font()
	_done = false
	_result = -1
	_miss_reason = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preparing = preparing
	if _preparing:
		clock.freeze()
		clock.set_elapsed(0.0)
	else:
		clock.start()
	latch.latch_held([InputBindings.COMMAND])
	set_process(true)
	set_process_input(true)
	queue_redraw()


## The same visible widget stays in place; grading starts only after its preparation preview.
func start_timing() -> void:
	if not _preparing:
		return
	_preparing = false
	latch.poll()
	latch.latch_held([InputBindings.COMMAND])
	clock.start()
	if _focus_lost:
		clock.freeze()
	queue_redraw()


func is_preparing() -> bool:
	return _preparing


func elapsed_ms() -> float:
	return clock.elapsed_ms()


func is_done() -> bool:
	return _done


## The press that was measured, as "early"/"late" relative to [param target_ms] (or "" if on time).
static func timing_word(offset_ms: float) -> String:
	return "early" if offset_ms < 0.0 else "late"


func _process(_delta: float) -> void:
	latch.poll()
	if not _preparing and clock.is_frozen() and not _focus_lost and not latch.is_latched(InputBindings.COMMAND):
		clock.resume()
	if not _preparing and not _done and not clock.is_frozen():
		_tick()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _preparing:
		if event.is_action(InputBindings.COMMAND):
			get_viewport().set_input_as_handled()
		return
	if _done or clock.is_frozen():
		if event.is_action_released(InputBindings.COMMAND):
			latch.is_fresh_press(event, InputBindings.COMMAND)
		return
	_handle(event)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if spec != null and not _done and not _focus_lost:
				_focus_lost = true
				clock.freeze()
				_on_focus_lost()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _focus_lost:
				_focus_lost = false
				# Keys still down after alt-tab are not new presses; the clock waits for release.
				latch.latch_held([InputBindings.COMMAND])


## Per-frame timeout checks (not called while frozen).
func _tick() -> void:
	pass


## Input while the clock runs.
func _handle(_event: InputEvent) -> void:
	pass


## Called once when focus is lost mid-command (the clock is already frozen).
func _on_focus_lost() -> void:
	pass


func _fresh_press(event: InputEvent) -> bool:
	if latch.is_fresh_press(event, InputBindings.COMMAND):
		get_viewport().set_input_as_handled()
		return true
	return false


func _finish(grade: Enums.ExecutionGrade, miss_reason: String = "") -> void:
	if _done:
		return
	_done = true
	_result = grade
	_miss_reason = miss_reason if grade == Enums.ExecutionGrade.MISS else ""
	set_process_input(false)
	match grade:
		Enums.ExecutionGrade.PERFECT:
			AudioManager.play(AudioManager.Cue.PERFECT)
		Enums.ExecutionGrade.GOOD:
			AudioManager.play(AudioManager.Cue.GOOD)
		_:
			AudioManager.play(AudioManager.Cue.MISS)
	queue_redraw()
	var hold := create_tween()
	hold.tween_interval(RESULT_HOLD)
	await hold.finished
	finished.emit(grade)


## One short instruction with the bound key (overridden per command type).
func instruction() -> String:
	return ""


func _key() -> String:
	return InputBindings.prompt(InputBindings.COMMAND)


func _draw_frame() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UITheme.PANEL)
	draw_rect(rect, UITheme.ACCENT.darkened(0.25), false, 2.0)
	# Stepped corner brackets and an attack glyph share the combat art language.
	var glyph := "action_blunt" if spec.type == Enums.ActionCommandType.HOLD_RELEASE else "action_flurry" if spec.type == Enums.ActionCommandType.RHYTHM else "action_pierce" if spec.type == Enums.ActionCommandType.OPTIONAL_AIM else "action_slash"
	CombatIcons.paint(self, glyph, Rect2(12, 12, 26, 26))
	for point in [Vector2(4, 4), Vector2(size.x - 16, 4), Vector2(4, size.y - 6), Vector2(size.x - 16, size.y - 6)]:
		draw_rect(Rect2(point, Vector2(12, 2)), UITheme.ACCENT)
	var body := UITheme.body_size()
	var secondary := UITheme.secondary_size()
	var pad := 16.0
	draw_string(_font, Vector2(46, pad + body), UITheme.fit_text(title, size.x - 62, _font, body), HORIZONTAL_ALIGNMENT_LEFT, -1, body, UITheme.ACCENT)
	var hint := instruction()
	if _focus_lost:
		hint = "Paused · window lost focus"
	elif _preparing:
		hint = "Prepare · " + instruction()
	elif clock.is_frozen() and not _done:
		hint = "Release %s to continue" % _key()
	elif not _done and latch.is_latched(InputBindings.COMMAND):
		hint = "Release %s, then %s" % [_key(), instruction().to_lower()]
	draw_string(_font, Vector2(pad, pad + body + secondary + 10), UITheme.fit_text(hint, size.x - pad * 2.0, _font, secondary), HORIZONTAL_ALIGNMENT_LEFT, -1, secondary, UITheme.TEXT)
	if _result >= 0:
		var big := UITheme.font_size(1.6)
		var word: String = GRADE_WORDS[_result]
		if not _miss_reason.is_empty():
			word += " · " + _miss_reason
		draw_string(_font, Vector2(0, size.y - pad), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, GRADE_COLORS[_result])


## The bar area below the title, leaving room for the result line.
func _bar_rect() -> Rect2:
	var body := UITheme.body_size()
	var top := 16.0 + body + UITheme.secondary_size() + 28.0
	var bottom_room := UITheme.font_size(1.6) + 22.0
	var height := clampf(size.y - top - bottom_room, 20.0, 40.0)
	return Rect2(32.0, top + maxf(0.0, (size.y - top - bottom_room - height) * 0.5), maxf(1.0, size.x - 64.0), height)


## Horizontal bar with Good and Perfect zones centred on [param target] (0..1 along the bar).
## The zones are labelled so they never rely on colour alone.
func _draw_zone_bar(bar: Rect2, target: float, good_fraction: float, perfect_fraction: float) -> void:
	draw_rect(bar, UITheme.BG)
	var good := Rect2(bar.position.x + (target - good_fraction * 0.5) * bar.size.x, bar.position.y,
		good_fraction * bar.size.x, bar.size.y)
	var perfect := Rect2(bar.position.x + (target - perfect_fraction * 0.5) * bar.size.x, bar.position.y,
		perfect_fraction * bar.size.x, bar.size.y)
	draw_rect(good.intersection(bar), Color(UITheme.ACCENT, 0.3))
	draw_rect(perfect.intersection(bar), Color(UITheme.ACCENT, 0.85))
	draw_rect(bar, UITheme.BORDER, false, 1.0)
	for tick in 21:
		var x := bar.position.x + bar.size.x * tick / 20.0
		draw_line(Vector2(x, bar.end.y - 4), Vector2(x, bar.end.y), UITheme.BORDER)
	draw_line(Vector2(perfect.get_center().x, bar.position.y - 5), Vector2(perfect.get_center().x, bar.end.y + 5), UITheme.TEXT, 2)
	var small := UITheme.secondary_size()
	draw_string(_font, Vector2(good.position.x, bar.end.y + small + 2.0), "Good", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT_DIM)
	draw_string(_font, Vector2(perfect.get_center().x - 30.0, bar.position.y - 4.0), "Perfect", HORIZONTAL_ALIGNMENT_CENTER, 60.0,
		small, UITheme.ACCENT)
