extends TestCase
## Action-command grading (GDD "Action command framework") and assist scaling.


func _spec(type: Enums.ActionCommandType) -> CommandSpec:
	var spec := CommandSpec.new()
	spec.type = type
	spec.duration_ms = 1000.0
	spec.target_position = 0.75
	spec.good_window_ms = 300.0
	spec.perfect_window_ms = 100.0
	spec.lead_in_ms = 400.0
	spec.beat_count = 3
	spec.beat_interval_ms = 400.0
	return spec


func test_grade_offset_boundaries() -> void:
	assert_eq(CommandRules.grade_offset(0.0, 300.0, 100.0), Enums.ExecutionGrade.PERFECT)
	assert_eq(CommandRules.grade_offset(50.0, 300.0, 100.0), Enums.ExecutionGrade.PERFECT)
	assert_eq(CommandRules.grade_offset(-51.0, 300.0, 100.0), Enums.ExecutionGrade.GOOD)
	assert_eq(CommandRules.grade_offset(150.0, 300.0, 100.0), Enums.ExecutionGrade.GOOD)
	assert_eq(CommandRules.grade_offset(151.0, 300.0, 100.0), Enums.ExecutionGrade.MISS)


func test_timing_press() -> void:
	var spec := _spec(Enums.ActionCommandType.TIMING)
	assert_almost_eq(spec.target_time_ms(), 1150.0)
	assert_eq(CommandRules.grade_press(spec, 1150.0), Enums.ExecutionGrade.PERFECT)
	assert_eq(CommandRules.grade_press(spec, 1250.0), Enums.ExecutionGrade.GOOD)
	assert_eq(CommandRules.grade_press(spec, -1.0), Enums.ExecutionGrade.MISS, "no press")


func test_hold_release_and_overcharge() -> void:
	var spec := _spec(Enums.ActionCommandType.HOLD_RELEASE)
	assert_eq(CommandRules.grade_hold(spec, 750.0), Enums.ExecutionGrade.PERFECT)
	assert_eq(CommandRules.grade_hold(spec, 640.0), Enums.ExecutionGrade.GOOD)
	assert_eq(CommandRules.grade_hold(spec, 1001.0), Enums.ExecutionGrade.MISS, "overcharged")
	assert_eq(CommandRules.grade_hold(spec, -1.0), Enums.ExecutionGrade.MISS, "never pressed")


func test_rhythm_grading() -> void:
	var spec := _spec(Enums.ActionCommandType.RHYTHM)
	var all_perfect: Array[float] = [400.0, 800.0, 1200.0]
	assert_eq(CommandRules.grade_rhythm_presses(spec, all_perfect), Enums.ExecutionGrade.PERFECT)
	var mixed: Array[float] = [400.0, 900.0, 1500.0]
	assert_eq(CommandRules.grade_rhythm_presses(spec, mixed), Enums.ExecutionGrade.GOOD, "P + G + M averages Good")
	var mostly_missed: Array[float] = [400.0]
	assert_eq(CommandRules.grade_rhythm_presses(spec, mostly_missed), Enums.ExecutionGrade.MISS)
	var mashing: Array[float] = []
	for t in range(0, 1600, 20):
		mashing.append(float(t))
	assert_eq(CommandRules.grade_rhythm_presses(spec, mashing), Enums.ExecutionGrade.MISS,
		"mashing spends every beat early")
	assert_eq(CommandRules.rhythm_segment(spec, 560.0), 1)
	assert_eq(CommandRules.rhythm_segment(spec, 2000.0), -1)


func test_build_spec_applies_assist_and_modifiers() -> void:
	var weapon := Fixtures.sword()
	weapon.basic_attack.command.target_position = 0.5
	weapon.traits = [Fixtures.trait_with("Wide Grip", [
		Fixtures.modifier(Enums.ModifierStat.GOOD_WINDOW, Enums.ModifierOp.MULTIPLY, 1.5)])]
	var setup := Fixtures.setup([Fixtures.enemy()], Fixtures.loadout(weapon), 1, null,
		Enums.TacticalDifficulty.ADVENTURER, Enums.ExecutionAssist.GENEROUS)
	var engine := BattleEngine.new(setup)
	var hero := engine.get_state().protagonist()
	var spec := CommandRules.build_spec(engine.ctx, hero, hero.weapon.basic_attack)
	assert_almost_eq(spec.good_window_ms, 300.0 * 1.5 * 1.5, 0.01, "trait x assist")
	assert_almost_eq(spec.perfect_window_ms, 100.0 * 1.5, 0.01)


func test_windows_clamped_to_playable_range() -> void:
	var setup := Fixtures.setup([Fixtures.enemy()], null, 1, null, Enums.TacticalDifficulty.ADVENTURER,
		Enums.ExecutionAssist.ASSISTED)
	var engine := BattleEngine.new(setup)
	var hero := engine.get_state().protagonist()
	var action := hero.weapon.basic_attack
	action.command.good_window_ms = 2000.0
	var spec := CommandRules.build_spec(engine.ctx, hero, action)
	assert_lte(spec.good_window_ms, spec.duration_ms * 2.0 * 0.25 + 0.01, "zone fits inside the bar")
	action.command.good_window_ms = 300.0


func test_assist_floor() -> void:
	var setup := Fixtures.setup([Fixtures.enemy()], null, 1, null, Enums.TacticalDifficulty.ADVENTURER,
		Enums.ExecutionAssist.ASSISTED)
	var engine := BattleEngine.new(setup)
	assert_eq(CommandRules.apply_floor(engine.ctx, Enums.ExecutionGrade.MISS), Enums.ExecutionGrade.GOOD)
	assert_eq(CommandRules.apply_floor(engine.ctx, Enums.ExecutionGrade.PERFECT), Enums.ExecutionGrade.PERFECT)
