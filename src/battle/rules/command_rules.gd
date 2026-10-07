class_name CommandRules
extends RefCounted
## Builds final command parameters and grades inputs. The four command widgets and the simulator
## all grade through these pure functions, so execution rules live in exactly one place.


static func build_spec(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition) -> CommandSpec:
	var spec := CommandSpec.new()
	var definition := action.command
	if definition == null or definition.type == Enums.ActionCommandType.NONE:
		return spec
	spec.type = definition.type
	var rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, actor, null, action)
	var window_scale := ctx.assist.window_scale
	var good := ModifierQuery.apply(ctx, Enums.ModifierStat.GOOD_WINDOW, definition.good_window_ms, actor, rc) * window_scale
	var perfect := ModifierQuery.apply(ctx, Enums.ModifierStat.PERFECT_WINDOW, definition.perfect_window_ms, actor, rc) * window_scale
	var speed := maxf(0.1, ModifierQuery.apply(ctx, Enums.ModifierStat.COMMAND_SPEED, 1.0, actor, rc))
	var time_scale := ctx.assist.time_scale / speed
	spec.duration_ms = definition.duration_ms * time_scale
	spec.beat_interval_ms = definition.beat_interval_ms * time_scale
	spec.lead_in_ms = definition.lead_in_ms * time_scale
	spec.target_position = definition.target_position
	spec.beat_count = clampi(definition.beat_count, 2, 4)
	# Windows must fit inside the playable range so a generous assist never overlaps zones.
	var room := spec.duration_ms * 2.0 * minf(spec.target_position, 1.0 - spec.target_position)
	if spec.type == Enums.ActionCommandType.RHYTHM:
		room = spec.beat_interval_ms * 0.9
	good = minf(good, room * 0.98)
	spec.good_window_ms = maxf(good, 1.0)
	spec.perfect_window_ms = clampf(perfect, 1.0, spec.good_window_ms)
	return spec


## Grades an input [param offset_ms] away from the sweet spot (negative = early).
static func grade_offset(offset_ms: float, good_window_ms: float, perfect_window_ms: float) -> Enums.ExecutionGrade:
	var distance := absf(offset_ms)
	if distance <= perfect_window_ms * 0.5:
		return Enums.ExecutionGrade.PERFECT
	if distance <= good_window_ms * 0.5:
		return Enums.ExecutionGrade.GOOD
	return Enums.ExecutionGrade.MISS


## TIMING / OPTIONAL_AIM: [param press_ms] measured from the start of the sequence (< 0 = no press).
static func grade_press(spec: CommandSpec, press_ms: float) -> Enums.ExecutionGrade:
	if press_ms < 0.0:
		return Enums.ExecutionGrade.MISS
	return grade_offset(press_ms - spec.target_time_ms(), spec.good_window_ms, spec.perfect_window_ms)


## HOLD_RELEASE: [param held_ms] = how long the input was held (< 0 = never pressed).
## Holding past a full gauge overcharges into a MISS.
static func grade_hold(spec: CommandSpec, held_ms: float) -> Enums.ExecutionGrade:
	if held_ms < 0.0 or held_ms > spec.duration_ms:
		return Enums.ExecutionGrade.MISS
	return grade_offset(held_ms - spec.target_time_ms(), spec.good_window_ms, spec.perfect_window_ms)


## RHYTHM: [param press_times_ms] = every press, measured from the start. Beat i owns the time
## segment that starts when beat i-1's Good window closes and ends when its own closes; only the
## FIRST press in that segment counts, so mashing spends the beat early instead of helping.
static func grade_rhythm_presses(spec: CommandSpec, press_times_ms: Array[float]) -> Enums.ExecutionGrade:
	var presses := press_times_ms.duplicate()
	presses.sort()
	var beat_grades: Array[Enums.ExecutionGrade] = []
	var half_good := spec.good_window_ms * 0.5
	for beat in spec.beat_count:
		var beat_time := spec.beat_time_ms(beat)
		var segment_start := 0.0 if beat == 0 else spec.beat_time_ms(beat - 1) + half_good
		var segment_end := beat_time + half_good
		var grade := Enums.ExecutionGrade.MISS
		for press: float in presses:
			if press >= segment_start and press <= segment_end:
				grade = grade_offset(press - beat_time, spec.good_window_ms, spec.perfect_window_ms)
				break
		beat_grades.append(grade)
	return combine_beats(beat_grades)


## RHYTHM live helper: which beat a press at [param press_ms] belongs to (-1 = after the last).
static func rhythm_segment(spec: CommandSpec, press_ms: float) -> int:
	var half_good := spec.good_window_ms * 0.5
	for beat in spec.beat_count:
		if press_ms <= spec.beat_time_ms(beat) + half_good:
			return beat
	return -1


## PERFECT if every beat is Perfect; GOOD if the beats average at least Good; otherwise MISS.
static func combine_beats(beat_grades: Array[Enums.ExecutionGrade]) -> Enums.ExecutionGrade:
	if beat_grades.is_empty():
		return Enums.ExecutionGrade.MISS
	var total := 0
	var all_perfect := true
	for grade in beat_grades:
		total += int(grade)
		if grade != Enums.ExecutionGrade.PERFECT:
			all_perfect = false
	if all_perfect:
		return Enums.ExecutionGrade.PERFECT
	if total >= beat_grades.size():
		return Enums.ExecutionGrade.GOOD
	return Enums.ExecutionGrade.MISS


## Execution Assist floor (e.g. ASSISTED never drops below GOOD).
static func apply_floor(ctx: BattleContext, grade: Enums.ExecutionGrade) -> Enums.ExecutionGrade:
	return maxi(int(grade), int(ctx.assist.minimum_grade)) as Enums.ExecutionGrade
