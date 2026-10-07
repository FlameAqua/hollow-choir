extends TestCase
## Damage, Stagger and grade math (GDD "Stats", "Execution grades", "Stagger").


func _engine_with(hero_force: int, enemy_guard: int, weakness: Array[Enums.DamageType] = []) -> BattleEngine:
	var enemy := Fixtures.enemy(&"target", 500, enemy_guard)
	enemy.weaknesses = weakness
	var setup := Fixtures.setup([enemy], Fixtures.loadout(Fixtures.sword(24.0), Fixtures.hero(hero_force)))
	return BattleEngine.new(setup)


func test_gdd_tooltip_example() -> void:
	# GDD: base 24, Force modifier +4.8 (Force 20), vulnerability, Guard 20 -> estimated ~30.
	var engine := _engine_with(20, 20, [Enums.DamageType.SLASH])
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var calc := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	# 24 * 1.2 * 1.3 (weakness) * 100/120 = 31.2
	assert_almost_eq(calc.expected, 31.2, 0.001)
	assert_true(calc.is_weakness)


func test_grade_multipliers_miss_good_perfect() -> void:
	var engine := _engine_with(0, 0)
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var strike := hero.weapon.basic_attack
	var miss := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, strike, Enums.ExecutionGrade.MISS)
	var good := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, strike, Enums.ExecutionGrade.GOOD)
	var perfect := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, strike, Enums.ExecutionGrade.PERFECT)
	assert_almost_eq(good.expected, 24.0)
	assert_almost_eq(miss.expected, 24.0 * 0.85, 0.001, "a missed command still lands at 85%")
	assert_almost_eq(perfect.expected, 24.0 * 1.15, 0.001)


func test_guard_mitigation_formula() -> void:
	var engine := _engine_with(0, 100)
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var calc := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(calc.expected, 12.0, 0.001, "Guard 100 halves damage")


func test_resistance_and_pure_damage_ignores_guard() -> void:
	var engine := _engine_with(0, 100)
	var enemy := engine.get_state().enemies()[0]
	enemy.enemy_def().resistances = [Enums.DamageType.FIRE]
	var calc := DamageCalculator.calculate_effect_damage(engine.ctx, null, enemy, 10.0, Enums.DamageType.PURE)
	assert_eq(calc.minimum, 10, "PURE ignores Guard")
	var fire := DamageCalculator.calculate_effect_damage(engine.ctx, null, enemy, 20.0, Enums.DamageType.FIRE)
	assert_eq(fire.minimum, 7, "20 * 0.7 resist * 0.5 guard = 7")
	assert_true(fire.is_resisted)


func test_variance_range_and_roll_within_range() -> void:
	var lib := Fixtures.library()
	lib.balance.damage_variance = 0.1
	var setup := Fixtures.setup([Fixtures.enemy()], null, 7, lib)
	var engine := BattleEngine.new(setup)
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var calc := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	assert_eq(calc.minimum, 18)
	assert_eq(calc.maximum, 22)
	for i in 50:
		var rolled := calc.roll(engine.ctx)
		assert_true(rolled >= calc.minimum and rolled <= calc.maximum, "roll %d outside range" % rolled)


func test_weak_point_and_broken_multipliers() -> void:
	var engine := _engine_with(0, 0)
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	enemy.weak_point_turns = 1
	enemy.broken_turns_left = 1
	var calc := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(calc.expected, 24.0 * 1.25 * 1.5, 0.001)
	assert_eq(calc.stagger, 0.0, "a Broken enemy takes no further Stagger")


func test_precision_tag_boosts_weak_point() -> void:
	var engine := _engine_with(0, 0)
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	enemy.weak_point_turns = 1
	var shot := Fixtures.strike(&"shot")
	shot.tags = [Enums.ActionTag.PRECISION]
	var calc := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, shot, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(calc.expected, 24.0 * 1.25 * 1.4, 0.001)


func test_stagger_weakness_and_interrupt_bonus() -> void:
	var engine := _engine_with(0, 0, [Enums.DamageType.SLASH])
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var hit := Fixtures.strike(&"cut")
	hit.tags = [Enums.ActionTag.INTERRUPT]
	var calm := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hit, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(calm.stagger, 10.0 * 1.5, 0.001, "weakness x1.5 stagger")
	var intent := EnemyIntent.new()
	intent.action = Fixtures.enemy_attack()
	intent.channeling = true
	enemy.intent = intent
	var channeling := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hit, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(channeling.stagger, 10.0 * 1.5 * 1.75, 0.001, "INTERRUPT bonus vs channel")


func test_modifiers_add_then_multiply() -> void:
	var weapon := Fixtures.sword(20.0)
	weapon.traits = [Fixtures.trait_with("Edge", [
		Fixtures.modifier(Enums.ModifierStat.FORCE, Enums.ModifierOp.ADD, 50.0),
		Fixtures.modifier(Enums.ModifierStat.DAMAGE_DEALT, Enums.ModifierOp.MULTIPLY, 2.0,
			[Fixtures.condition(Enums.ConditionType.HAS_STATUS, {"on": Enums.ConditionOn.TARGET, "status": Enums.StatusId.WET})]),
	])]
	var engine := BattleEngine.new(Fixtures.setup([Fixtures.enemy()], Fixtures.loadout(weapon)))
	var hero := engine.get_state().protagonist()
	var enemy := engine.get_state().enemies()[0]
	var dry := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(dry.expected, 30.0, 0.001, "Force +50 -> x1.5")
	StatusRules.apply_status(engine.ctx, enemy, Enums.StatusId.WET, 1, 0, null)
	var wet := DamageCalculator.calculate_hit(engine.ctx, hero, enemy, hero.weapon.basic_attack, Enums.ExecutionGrade.GOOD)
	assert_almost_eq(wet.expected, 60.0, 0.001, "conditional x2 vs Wet")


func test_preview_matches_resolution() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 500, 25)]))
	var request := driver.to_player_turn()
	assert_not_null(request)
	var enemy := driver.enemy()
	var choice := ActionChoice.make(request.unit_uid, driver.hero().weapon.basic_attack, enemy.uid)
	var preview := driver.engine.preview(choice)
	var hp_before := enemy.hp
	driver.act(&"strike", enemy.uid, Enums.ExecutionGrade.PERFECT)
	driver.next_request()
	var dealt := hp_before - enemy.hp
	assert_true(dealt >= preview.damage_min[Enums.ExecutionGrade.PERFECT]
		and dealt <= preview.damage_max[Enums.ExecutionGrade.PERFECT], "dealt %d outside preview" % dealt)
	assert_false(preview.breakdown.is_empty(), "preview carries an analysis breakdown")
