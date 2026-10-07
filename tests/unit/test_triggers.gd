extends TestCase
## Traits: triggered effects, relations, limits, recursion, buffs, conditions, phases.

var engine: BattleEngine
var ctx: BattleContext
var hero: BattleUnit
var enemy: BattleUnit


func _make(party: PartyLoadout = null, enemies: Array[EnemyDefinition] = []) -> void:
	if enemies.is_empty():
		enemies = [Fixtures.enemy(&"dummy", 500, 0)]
	engine = BattleEngine.new(Fixtures.setup(enemies, party))
	ctx = engine.ctx
	hero = engine.get_state().protagonist()
	enemy = engine.get_state().enemies()[0]


func _bell_crow() -> FamiliarDefinition:
	var familiar := FamiliarDefinition.new()
	familiar.id = &"crow"
	familiar.display_name = "Crow"
	familiar.trait_def = Fixtures.trait_with("Crow", [], [Fixtures.trigger(Enums.TriggerType.REACTION,
		Enums.TriggerWatch.TARGET, Enums.TriggerRelation.OWNER_ALLY,
		[Fixtures.effect(Enums.EffectType.STAGGER_DAMAGE, Enums.EffectTarget.ACTOR, 10.0)],
		[Fixtures.condition(Enums.ConditionType.REACTION_SUCCEEDED, {"reaction": Enums.ReactionType.PARRY})], 1)])
	return familiar


func test_familiar_triggers_on_party_parry_once_per_round() -> void:
	var party := Fixtures.loadout()
	party.familiar = _bell_crow()
	var attack := Fixtures.enemy_attack(&"jab", 5.0)
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"jabber", 500, 0, 20, [attack])], party))
	driver.next_request()
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
	driver.next_request()
	var jabber := driver.enemy()
	assert_almost_eq(jabber.stagger, 50.0 - 18.0 - 10.0, 0.001, "parry 18 + crow 10")
	var announced := driver.events_of(BattleEvent.Type.TRIGGER_ACTIVATED)
	assert_eq(announced.size(), 1)
	assert_eq(announced[0].text, "Crow", "every trigger announces its source")


func test_relation_filters() -> void:
	_make()
	var trig := Fixtures.trigger(Enums.TriggerType.HIT_LANDED, Enums.TriggerWatch.ACTOR,
		Enums.TriggerRelation.OWNER, [] as Array[EffectDefinition])
	var rc := RuleContext.make(Enums.TriggerType.HIT_LANDED, hero, enemy)
	assert_true(TriggerDispatcher.relation_ok(trig, rc, hero))
	assert_false(TriggerDispatcher.relation_ok(trig, rc, enemy))
	trig.relation = Enums.TriggerRelation.OWNER_ENEMY
	assert_true(TriggerDispatcher.relation_ok(trig, rc, enemy))
	trig.relation = Enums.TriggerRelation.ANY
	assert_true(TriggerDispatcher.relation_ok(trig, rc, null), "battlefield traits use ANY")


func test_perfect_hit_converts_stagger_to_focus() -> void:
	var weapon := Fixtures.sword(20.0, 10.0)
	weapon.traits = [Fixtures.trait_with("Pilgrim", [], [Fixtures.trigger(Enums.TriggerType.HIT_LANDED,
		Enums.TriggerWatch.ACTOR, Enums.TriggerRelation.OWNER,
		[Fixtures.effect(Enums.EffectType.GAIN_FOCUS, Enums.EffectTarget.OWNER, 0.2, {"scaling": Enums.AmountScaling.EVENT_STAGGER})],
		[Fixtures.condition(Enums.ConditionType.GRADE_IS, {"grade": Enums.ExecutionGrade.PERFECT})])])]
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 500)], Fixtures.loadout(weapon)))
	driver.to_player_turn()
	var focus_before := driver.hero().focus
	driver.act(&"strike", driver.enemy().uid, Enums.ExecutionGrade.PERFECT)
	driver.next_request()
	# Perfect basic +2; trigger: 20% of 11.5 stagger = 2.3 -> 2.
	assert_eq(driver.hero().focus, focus_before + 4)


func test_chain_status_does_not_recurse() -> void:
	var flood := BattlefieldConditionDefinition.new()
	flood.id = &"flood"
	flood.display_name = "Flood"
	flood.description = "Shock chains through Wet units."
	flood.traits = [Fixtures.trait_with("Flood", [], [Fixtures.trigger(Enums.TriggerType.STATUS_APPLIED,
		Enums.TriggerWatch.TARGET, Enums.TriggerRelation.ANY,
		[Fixtures.effect(Enums.EffectType.CHAIN_STATUS, Enums.EffectTarget.TARGET_ALLIES_OTHER, 1.0,
			{"status": Enums.StatusId.SHOCK, "filter_status": Enums.StatusId.WET})],
		[Fixtures.condition(Enums.ConditionType.EVENT_STATUS_IS, {"status": Enums.StatusId.SHOCK}),
			Fixtures.condition(Enums.ConditionType.FROM_CHAIN, {"negate": true})])])]
	var enemies: Array[EnemyDefinition] = [Fixtures.enemy(&"a", 500), Fixtures.enemy(&"b", 500), Fixtures.enemy(&"c", 500)]
	_make(null, enemies)
	BattlefieldRules.add(ctx, flood)
	var units := engine.get_state().enemies()
	for unit in units.slice(0, 2):
		StatusRules.apply_status(ctx, unit, Enums.StatusId.WET, 1, 0, null)
	StatusRules.apply_status(ctx, units[0], Enums.StatusId.SHOCK, 1, 0, hero)
	assert_true(units[1].has_status(Enums.StatusId.SHOCK), "chains to the other Wet unit")
	assert_false(units[2].has_status(Enums.StatusId.SHOCK), "dry unit is not shocked")
	var chained := 0
	for event in ctx.events:
		if event.type == BattleEvent.Type.STATUS_APPLIED and event.has_flag(BattleEvent.FLAG_CHAIN):
			chained += 1
	assert_eq(chained, 1, "the chained Shock does not chain again")


func test_trigger_depth_is_bounded() -> void:
	var echo := Fixtures.trait_with("Echo", [], [Fixtures.trigger(Enums.TriggerType.DAMAGE_TAKEN,
		Enums.TriggerWatch.TARGET, Enums.TriggerRelation.ANY,
		[Fixtures.effect(Enums.EffectType.DAMAGE, Enums.EffectTarget.TARGET, 1.0, {"damage_type": Enums.DamageType.PURE})])])
	_make()
	enemy.traits.append(TraitInstance.new(echo, enemy.uid))
	HealthRules.apply_damage(ctx, enemy, 1, hero, Enums.DamageType.PURE, null)
	assert_lt(500 - enemy.hp, 10, "self-feeding trigger stops at max depth")
	assert_gt(500 - enemy.hp, 1)


func test_next_action_buff_is_consumed_by_qualifying_action() -> void:
	var empower := BuffDefinition.new()
	empower.id = &"empowered"
	empower.display_name = "Empowered"
	empower.expiry = Enums.BuffExpiry.NEXT_ACTION
	empower.consume_conditions = [Fixtures.condition(Enums.ConditionType.ACTION_CATEGORY_IS, {"category": Enums.ActionCategory.ATTACK})]
	empower.trait_def = Fixtures.trait_with("Empowered", [Fixtures.modifier(Enums.ModifierStat.DAMAGE_DEALT, Enums.ModifierOp.MULTIPLY, 2.0)])
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 500)]))
	driver.to_player_turn()
	BuffRules.grant(driver.engine.ctx, driver.hero(), empower, driver.hero())
	driver.act(&"strike", driver.enemy().uid)
	driver.next_request()
	assert_eq(driver.enemy().hp, 460, "empowered strike deals 40")
	assert_false(driver.hero().has_buff(empower), "consumed by the attack")


func test_boss_phase_swaps_actions_and_adds_condition() -> void:
	var calm := Fixtures.enemy_attack(&"calm", 1.0)
	var rage := Fixtures.enemy_attack(&"rage", 1.0)
	var storm := BattlefieldConditionDefinition.new()
	storm.id = &"storm"
	storm.display_name = "Storm"
	storm.description = "It storms."
	var phase := BossPhaseDefinition.new()
	phase.display_name = "Rage"
	phase.hp_threshold = 0.5
	phase.actions = [rage]
	phase.add_conditions = [storm]
	phase.opening_action = rage
	var boss := Fixtures.enemy(&"boss", 100, 0, 1, [calm])
	boss.tier = Enums.EnemyTier.BOSS
	boss.phases = [phase]
	var driver := BattleDriver.new(Fixtures.setup([boss]))
	driver.to_player_turn()
	var unit := driver.enemy()
	HealthRules.apply_damage(driver.engine.ctx, unit, 55, driver.hero(), Enums.DamageType.PURE, null)
	assert_eq(unit.phase_index, 0)
	assert_eq(unit.enemy_actions, [rage] as Array[EnemyActionDefinition])
	assert_true(driver.engine.get_state().has_condition(storm))
	assert_eq(unit.intent.action, calm, "declared intent is honoured")
	driver.act(&"guard")
	driver.to_player_turn()
	driver.act(&"guard")
	driver.next_request()
	assert_eq(unit.intent.action, rage, "phase opening move declared next round")


func test_condition_replacement_by_severity() -> void:
	_make()
	var a := BattlefieldConditionDefinition.new()
	a.id = &"a"
	a.display_name = "A"
	a.description = "a"
	var b := BattlefieldConditionDefinition.new()
	b.id = &"b"
	b.display_name = "B"
	b.description = "b"
	var minor := BattlefieldConditionDefinition.new()
	minor.id = &"m"
	minor.display_name = "M"
	minor.description = "m"
	minor.severity = Enums.ConditionSeverity.MINOR
	BattlefieldRules.add(ctx, a)
	BattlefieldRules.add(ctx, minor)
	BattlefieldRules.add(ctx, b)
	var ids: Array[StringName] = []
	for active in engine.get_state().conditions:
		ids.append(active.definition.id)
	assert_eq(ids, [&"m", &"b"] as Array[StringName], "new MAJOR replaces old MAJOR; MINOR stays")


func test_item_consumes_charge_and_fires_item_used() -> void:
	var potion := PotionDefinition.new()
	potion.id = &"tonic"
	potion.display_name = "Tonic"
	potion.charges = 1
	var drink := ActionDefinition.new()
	drink.id = &"drink_tonic"
	drink.display_name = "Drink"
	drink.category = Enums.ActionCategory.ITEM
	drink.target_rule = Enums.TargetRule.SINGLE_ALLY
	drink.effects = [Fixtures.effect(Enums.EffectType.HEAL, Enums.EffectTarget.TARGET, 30.0)]
	potion.action = drink
	var party := Fixtures.loadout()
	party.potions = [potion]
	party.familiar = FamiliarDefinition.new()
	party.familiar.id = &"moss"
	party.familiar.display_name = "Moss"
	party.familiar.trait_def = Fixtures.trait_with("Moss", [], [Fixtures.trigger(Enums.TriggerType.ITEM_USED,
		Enums.TriggerWatch.ACTOR, Enums.TriggerRelation.OWNER_ALLY,
		[Fixtures.effect(Enums.EffectType.GAIN_FOCUS, Enums.EffectTarget.ACTOR, 1.0)])])
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 500)], party))
	var request := driver.to_player_turn()
	driver.hero().hp = 50
	var focus_before := driver.hero().focus
	var option: ActionOption = null
	for candidate in request.options:
		if candidate.item_slot == 0:
			option = candidate
	assert_not_null(option)
	assert_eq(driver.engine.submit_action(ActionChoice.from_option(request.unit_uid, option, driver.hero().uid)), OK)
	driver.next_request()
	assert_eq(driver.hero().hp, 80)
	assert_eq(driver.engine.get_state().potion_slots[0].charges, 0)
	assert_eq(driver.hero().focus, focus_before + 1, "ITEM_USED familiar trigger")
	request = driver.to_player_turn()
	for candidate in request.options:
		if candidate.item_slot == 0:
			assert_false(candidate.legal)
			assert_eq(candidate.reason, "Empty")
