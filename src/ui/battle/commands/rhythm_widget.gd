class_name RhythmWidget
extends CommandWidget
## RHYTHM: 2-4 beats travel toward the hit line; press once per beat. Only the first press in each
## beat's segment counts (mashing spends beats early). Final grade: CommandRules.combine_beats.

const PIXELS_PER_MS := 0.32

var _presses: Array[float] = []
var _beat_grades: Dictionary[int, int] = {}


func _ready() -> void:
	custom_minimum_size = Vector2(520, 120)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	if not _done and elapsed_ms() > spec.end_time_ms() + 40.0:
		_finish(CommandRules.grade_rhythm_presses(spec, _presses))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _done or not event.is_action_pressed(InputBindings.COMMAND, false):
		return
	get_viewport().set_input_as_handled()
	var now := elapsed_ms()
	var beat := CommandRules.rhythm_segment(spec, now)
	if beat < 0 or _beat_grades.has(beat):
		return
	_presses.append(now)
	var grade := CommandRules.grade_offset(now - spec.beat_time_ms(beat), spec.good_window_ms, spec.perfect_window_ms)
	_beat_grades[beat] = grade
	AudioManager.play(AudioManager.Cue.BEAT, 0.0, 0.0 if grade != Enums.ExecutionGrade.MISS else -8.0)
	if _beat_grades.size() == spec.beat_count:
		_finish(CommandRules.grade_rhythm_presses(spec, _presses))


func _draw() -> void:
	if spec == null:
		return
	_draw_frame("Press %s on each beat (%d)" % [_key_hint(), spec.beat_count])
	var track := Rect2(30, 50, size.x - 60, 22)
	draw_rect(track, Color(0.1, 0.1, 0.14))
	var hit_x := track.position.x + 40.0
	var good_px := spec.good_window_ms * PIXELS_PER_MS
	var perfect_px := spec.perfect_window_ms * PIXELS_PER_MS
	draw_rect(Rect2(hit_x - good_px * 0.5, track.position.y, good_px, track.size.y), Color(0.85, 0.7, 0.3, 0.3))
	draw_rect(Rect2(hit_x - perfect_px * 0.5, track.position.y, perfect_px, track.size.y), Color(1.0, 0.85, 0.35, 0.8))
	var now := elapsed_ms()
	for beat in spec.beat_count:
		var x := hit_x + (spec.beat_time_ms(beat) - now) * PIXELS_PER_MS
		if x < track.position.x - 10 or x > track.end.x + 10:
			continue
		var color := Color.WHITE
		if _beat_grades.has(beat):
			color = GRADE_COLORS[_beat_grades[beat]]
		draw_circle(Vector2(x, track.get_center().y), 9.0, color)
		draw_arc(Vector2(x, track.get_center().y), 9.0, 0, TAU, 16, Color.BLACK, 1.5)
	var index := 0
	for beat: int in _beat_grades:
		draw_string(_font, Vector2(hit_x - 30 + index * 70, 96), GRADE_WORDS[_beat_grades[beat]].trim_suffix("!"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(0.7), GRADE_COLORS[_beat_grades[beat]])
		index += 1
