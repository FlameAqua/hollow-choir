extends TestCase
## Burn / Wet / Shock / Bleed rules and their interactions (GDD "Status system").

var engine: BattleEngine
var ctx: BattleContext
var hero: BattleUnit
var enemy: BattleUnit


func before_each() -> void:
	engine = BattleEngine.new(Fixtures.setup([Fixtures.enemy(&"dummy", 300, 0)]))
	ctx = engine.ctx
	hero = engine.get_state().protagonist()
	enemy = engine.get_state().enemies()[0]


func test_wet_washes_away_burn() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 1, 0, hero)
	assert_true(enemy.has_status(Enums.StatusId.BURN))
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.WET, 1, 0, hero)
	assert_false(enemy.has_status(Enums.StatusId.BURN), "Wet removes Burn")
	assert_true(enemy.has_status(Enums.StatusId.WET))


func test_burn_on_wet_target_is_doused() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.WET, 1, 0, hero)
	var applied := StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 1, 0, hero)
	assert_false(applied)
	assert_false(enemy.has_status(Enums.StatusId.BURN))
	assert_false(enemy.has_status(Enums.StatusId.WET), "the Wet is consumed dousing the Burn")


func test_burn_ticks_when_bearer_acts() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 2, 0, hero)
	var hp_before := enemy.hp
	StatusRules.tick(ctx, enemy, Enums.TickTiming.TURN_START)
	assert_eq(hp_before - enemy.hp, 6, "3 per stack x 2 stacks")


func test_stacks_cap_and_duration_refresh() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 2, 2, hero)
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 5, 3, hero)
	var burn := enemy.get_status(Enums.StatusId.BURN)
	assert_eq(burn.stacks, 3, "max_stacks 3")
	assert_eq(burn.remaining, 3, "refresh to the longer duration")


func test_turn_durations_expire() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.WET, 1, 2, hero)
	StatusRules.on_turn_end(ctx, enemy)
	assert_true(enemy.has_status(Enums.StatusId.WET))
	StatusRules.on_turn_end(ctx, enemy)
	assert_false(enemy.has_status(Enums.StatusId.WET))


func test_shock_raises_stagger_taken() -> void:
	StaggerRules.apply_stagger(ctx, enemy, 10.0, hero, false)
	assert_almost_eq(enemy.stagger, 40.0)
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.SHOCK, 1, 0, hero)
	StaggerRules.apply_stagger(ctx, enemy, 10.0, hero, false)
	assert_almost_eq(enemy.stagger, 25.0, 0.001, "Shock: x1.5 stagger taken")


func test_shock_conducts_through_wet() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.WET, 1, 0, hero)
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.SHOCK, 1, 0, hero)
	# Conduct trigger deals 10 Stagger, amplified by Shock itself (x1.5).
	assert_almost_eq(enemy.stagger, 50.0 - 15.0, 0.001)


func test_bleed_only_hurts_on_strenuous_actions_and_spends_charges() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BLEED, 1, 2, hero)
	var hp_before := enemy.hp
	StatusRules.on_turn_end(ctx, enemy)
	assert_eq(enemy.hp, hp_before, "time alone does not trigger Bleed")
	StatusRules.on_strenuous_action(ctx, enemy)
	assert_eq(hp_before - enemy.hp, 4)
	assert_eq(enemy.get_status(Enums.StatusId.BLEED).remaining, 1)
	StatusRules.on_strenuous_action(ctx, enemy)
	assert_false(enemy.has_status(Enums.StatusId.BLEED), "charges spent")


func test_bleed_expires_after_turn_cap() -> void:
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BLEED, 1, 3, hero)
	for i in 4:
		StatusRules.on_turn_end(ctx, enemy)
	assert_false(enemy.has_status(Enums.StatusId.BLEED), "Bleed cannot sit forever")


func test_strenuous_action_triggers_bleed_in_battle() -> void:
	var heavy := Fixtures.enemy_attack(&"heavy", 10.0)
	heavy.tags = [Enums.ActionTag.STRENUOUS]
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"heavy_hitter", 300, 0, 20, [heavy])]))
	var bleeder := driver.engine.get_state().enemies()[0]
	StatusRules.apply_status(driver.engine.ctx, bleeder, Enums.StatusId.BLEED, 2, 3, null)
	driver.next_request()
	driver.engine.submit_reaction(ReactionResult.none())
	driver.next_request()
	assert_eq(bleeder.hp, 300 - 8, "strenuous attack: 4 x 2 stacks")


func test_immunity_blocks_status() -> void:
	enemy.enemy_def().status_immunities = [Enums.StatusId.BURN]
	assert_false(StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 1, 0, hero))
	enemy.enemy_def().status_immunities = []


func test_duration_modifiers_dealt_and_taken() -> void:
	hero.traits.append(TraitInstance.new(Fixtures.trait_with("Ember", [
		Fixtures.modifier(Enums.ModifierStat.STATUS_DURATION_DEALT, Enums.ModifierOp.ADD, 2.0,
			[Fixtures.condition(Enums.ConditionType.EVENT_STATUS_IS, {"status": Enums.StatusId.BURN})])]), hero.uid))
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.BURN, 1, 2, hero)
	assert_eq(enemy.get_status(Enums.StatusId.BURN).remaining, 4)
	StatusRules.apply_status(ctx, enemy, Enums.StatusId.SHOCK, 1, 2, hero)
	assert_eq(enemy.get_status(Enums.StatusId.SHOCK).remaining, 2, "modifier is Burn-only")


func test_cleanse_removes_negative_statuses() -> void:
	StatusRules.apply_status(ctx, hero, Enums.StatusId.BLEED, 1, 0, enemy)
	StatusRules.apply_status(ctx, hero, Enums.StatusId.SHOCK, 1, 0, enemy)
	assert_eq(StatusRules.cleanse(ctx, hero), 2)
	assert_empty(hero.statuses)
