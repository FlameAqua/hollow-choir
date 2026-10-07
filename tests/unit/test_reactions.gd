extends TestCase
## Brace / Evade / Parry rules (GDD "Defensive reactions") and Execution Assist interplay.


func _driver_with_attack(power: float, setup_mod: Callable = Callable()) -> BattleDriver:
	var attack := Fixtures.enemy_attack(&"slash", power)
	var enemy := Fixtures.enemy(&"slasher", 500, 0, 20, [attack])
	var setup := Fixtures.setup([enemy])
	if setup_mod.is_valid():
		setup_mod.call(setup)
	return BattleDriver.new(setup)


func _first_reaction(driver: BattleDriver) -> ReactionRequest:
	return driver.next_request() as ReactionRequest


func test_enemy_attack_opens_reaction_window_with_spec() -> void:
	var driver := _driver_with_attack(20.0)
	var request := _first_reaction(driver)
	assert_not_null(request, "fast enemy attacks first and the party may react")
	assert_eq(request.spec.allowed.size(), 3)
	assert_almost_eq(request.spec.parry_window_ms, 150.0)
	assert_true(request.spec.parry_window_ms < request.spec.evade_window_ms
		and request.spec.evade_window_ms < request.spec.brace_window_ms, "Parry < Evade < Brace windows")


func test_no_reaction_full_damage() -> void:
	var driver := _driver_with_attack(20.0)
	_first_reaction(driver)
	driver.engine.submit_reaction(ReactionResult.none())
	driver.next_request()
	assert_eq(driver.hero().hp, 80)


func test_brace_reduces_damage_by_forty_percent() -> void:
	var driver := _driver_with_attack(20.0)
	_first_reaction(driver)
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.BRACE, true))
	driver.next_request()
	assert_eq(driver.hero().hp, 88, "20 * 0.6 = 12")


func test_evade_success_and_failure() -> void:
	var driver := _driver_with_attack(20.0)
	_first_reaction(driver)
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.EVADE, true))
	driver.next_request()
	assert_eq(driver.hero().hp, 100, "successful Evade avoids all damage")
	var failing := _driver_with_attack(20.0)
	_first_reaction(failing)
	failing.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.EVADE, false))
	failing.next_request()
	assert_eq(failing.hero().hp, 77, "failed Evade: 20 * 1.15 = 23")


func test_parry_negates_staggers_and_grants_focus() -> void:
	var driver := _driver_with_attack(20.0)
	_first_reaction(driver)
	var focus_before := driver.hero().focus
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
	driver.next_request()
	assert_eq(driver.hero().hp, 100)
	assert_almost_eq(driver.enemy().stagger, 50.0 - 18.0, 0.001, "parry deals Stagger to the attacker")
	assert_eq(driver.hero().focus, focus_before + 2)
	var failing := _driver_with_attack(20.0)
	_first_reaction(failing)
	failing.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, false))
	failing.next_request()
	assert_eq(failing.hero().hp, 74, "failed Parry: 20 * 1.3 = 26")


func test_disallowed_reaction_counts_as_none() -> void:
	var attack := Fixtures.enemy_attack(&"sweep", 20.0)
	attack.can_parry = false
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"sweeper", 500, 0, 20, [attack])]))
	var request := _first_reaction(driver)
	assert_false(request.spec.is_allowed(Enums.ReactionType.PARRY))
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
	driver.next_request()
	assert_eq(driver.hero().hp, 80, "parrying an unparryable attack does nothing")


func test_evade_and_parry_block_statuses_brace_does_not() -> void:
	var attack := Fixtures.enemy_attack(&"rend", 10.0)
	attack.effects = [Fixtures.effect(Enums.EffectType.APPLY_STATUS, Enums.EffectTarget.TARGET, 1.0,
		{"status": Enums.StatusId.BLEED})]
	for case: Array in [[Enums.ReactionType.BRACE, true], [Enums.ReactionType.EVADE, false], [Enums.ReactionType.PARRY, false]]:
		var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"render", 500, 0, 20, [attack])]))
		_first_reaction(driver)
		var reaction: Enums.ReactionType = case[0]
		driver.engine.submit_reaction(ReactionResult.make(reaction, true))
		driver.next_request()
		assert_eq(driver.hero().has_status(Enums.StatusId.BLEED), case[1],
			"%s and Bleed" % EnumText.reaction(reaction))


func test_assisted_auto_brace_and_grade_floor() -> void:
	var driver := _driver_with_attack(20.0, func(setup: BattleSetup) -> void:
		setup.assist = Fixtures.assist(Enums.ExecutionAssist.ASSISTED))
	var request := _first_reaction(driver)
	assert_true(request.spec.auto_brace)
	assert_true(request.spec.pause_before)
	assert_almost_eq(request.spec.parry_window_ms, 300.0, 0.001, "Assisted doubles windows")
	driver.engine.submit_reaction(ReactionResult.none())
	var request2 := driver.next_request()
	assert_eq(driver.hero().hp, 88, "no input + auto-Brace = braced hit")
	assert_true(driver.events_of(BattleEvent.Type.REACTION_RESULT)[0].has_flag(BattleEvent.FLAG_AUTO))
	assert_true(request2 is ActionSelectRequest)
	var enemy := driver.enemy()
	var hp_before := enemy.hp
	driver.act(&"strike", enemy.uid, Enums.ExecutionGrade.MISS)
	driver.next_request()
	assert_eq(hp_before - enemy.hp, 20, "Assisted raises MISS to GOOD")


func test_assist_does_not_change_ai_or_numbers() -> void:
	var standard := _driver_with_attack(20.0)
	var assisted := _driver_with_attack(20.0, func(setup: BattleSetup) -> void:
		setup.assist = Fixtures.assist(Enums.ExecutionAssist.ASSISTED))
	_first_reaction(standard)
	_first_reaction(assisted)
	assert_eq(standard.enemy().intent.action.id, assisted.enemy().intent.action.id)
	assert_eq(standard.enemy().intent.target_uids, assisted.enemy().intent.target_uids)


func test_area_attack_single_window_applies_to_all() -> void:
	var sweep := Fixtures.enemy_attack(&"sweep", 20.0)
	sweep.target_rule = Enums.TargetRule.ALL_ENEMIES
	var party := Fixtures.loadout(null, null, Fixtures.companion())
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"sweeper", 500, 0, 20, [sweep])], party))
	var request := _first_reaction(driver)
	assert_eq(request.target_uids.size(), 2, "one window covers both party members")
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.BRACE, true))
	driver.next_request()
	for member in driver.engine.get_state().party():
		assert_eq(member.hp, 88)


func test_reaction_grading_windows() -> void:
	var spec := ReactionSpec.new()
	spec.allowed = [Enums.ReactionType.BRACE, Enums.ReactionType.PARRY]
	spec.brace_window_ms = 500.0
	spec.parry_window_ms = 140.0
	assert_true(ReactionRules.is_success(spec, Enums.ReactionType.PARRY, 69.0))
	assert_false(ReactionRules.is_success(spec, Enums.ReactionType.PARRY, -71.0))
	assert_true(ReactionRules.is_success(spec, Enums.ReactionType.BRACE, -240.0))
	assert_false(ReactionRules.is_success(spec, Enums.ReactionType.EVADE, 0.0), "not allowed")
