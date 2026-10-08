class_name RhythmWidget
extends CommandWidget
## RHYTHM: 2-4 beats travel toward the hit line; press once per beat. Only the first press in each
## beat's segment counts (mashing spends beats early). Final grade: CommandRules.combine_beats.

const PIXELS_PER_MS := 0.32

var _presses: Array[float] = []
var _beat_grades: Dictionary[int, int] = {}


func instruction() -> String:
	return "Press %s on each beat (%d)" % [_key(), spec.beat_count]


func _tick() -> void:
	if elapsed_ms() > spec.end_time_ms() + 40.0:
		_finish(CommandRules.grade_rhythm_presses(spec, _presses), "beats missed")


func _handle(event: InputEvent) -> void:
	if not _fresh_press(event):
		return
	var now := elapsed_ms()
	var beat := CommandRules.rhythm_segment(spec, now)
	if beat < 0 or _beat_grades.has(beat):
		return
	_presses.append(now)
	var grade := CommandRules.grade_offset(now - spec.beat_time_ms(beat), spec.good_window_ms, spec.perfect_window_ms)
	_beat_grades[beat] = grade
	AudioManager.play(AudioManager.Cue.BEAT, 0.0, 0.0 if grade != Enums.ExecutionGrade.MISS else -8.0)
	if _beat_grades.size() == spec.beat_count:
		_finish(CommandRules.grade_rhythm_presses(spec, _presses), "beats missed")


func _draw() -> void:
	if spec == null:
		return
	_draw_frame()
	var track := _bar_rect()
	draw_rect(track, UITheme.BG)
	var hit_x := track.position.x + 60.0
	var good_px := spec.good_window_ms * PIXELS_PER_MS
	var perfect_px := spec.perfect_window_ms * PIXELS_PER_MS
	draw_rect(Rect2(hit_x - good_px * 0.5, track.position.y, good_px, track.size.y), Color(UITheme.ACCENT, 0.3))
	draw_rect(Rect2(hit_x - perfect_px * 0.5, track.position.y, perfect_px, track.size.y), Color(UITheme.ACCENT, 0.85))
	draw_rect(track, UITheme.BORDER, false, 1.0)
	draw_line(Vector2(hit_x, track.position.y - 8), Vector2(hit_x, track.end.y + 8), UITheme.TEXT, 2)
	draw_string(_font, Vector2(track.position.x, track.position.y - 14), "Impact", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.secondary_size(), UITheme.ACCENT)
	var now := elapsed_ms()
	var radius := minf(11.0, track.size.y * 0.4)
	for beat in spec.beat_count:
		var x := hit_x + (spec.beat_time_ms(beat) - now) * PIXELS_PER_MS
		if x < track.position.x - 12 or x > track.end.x + 12:
			continue
		var color := UITheme.TEXT
		if _beat_grades.has(beat):
			color = GRADE_COLORS[_beat_grades[beat]]
		var point := Vector2(x, track.get_center().y)
		var diamond := PackedVector2Array([point + Vector2(0, -radius - 3), point + Vector2(radius + 3, 0), point + Vector2(0, radius + 3), point + Vector2(-radius - 3, 0)])
		draw_colored_polygon(diamond, color)
		draw_string(_font, point + Vector2(-5, 5), str(beat + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.BG)
	var small := UITheme.secondary_size()
	var index := 0
	for beat in spec.beat_count:
		var measured := _beat_grades.has(beat)
		var color: Color = GRADE_COLORS[_beat_grades[beat]] if measured else UITheme.TEXT_DIM
		var glyph := "focus" if measured and _beat_grades[beat] == Enums.ExecutionGrade.PERFECT else "action_slash" if measured and _beat_grades[beat] == Enums.ExecutionGrade.GOOD else "unavailable" if measured else "intent_wait"
		var x := track.position.x + index * track.size.x / spec.beat_count
		CombatIcons.paint(self, glyph, Rect2(x, track.end.y + 10, 24, 24))
		draw_string(_font, Vector2(track.position.x + index * track.size.x / spec.beat_count, track.end.y + small + 10.0),
			"    %d %s" % [beat + 1, String(GRADE_WORDS[_beat_grades[beat]]).capitalize() if measured else ""], HORIZONTAL_ALIGNMENT_LEFT, track.size.x / spec.beat_count,
			small, color)
		index += 1
