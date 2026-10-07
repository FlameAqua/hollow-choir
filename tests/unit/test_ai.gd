extends TestCase
## Utility AI behaviour (GDD "Enemy intelligence", acceptance "AI test" and "Hard-mode test").


func _consideration(type: Enums.ConsiderationType, weight: float, fields: Dictionary = {}) -> AIConsiderationDefinition:
	var consideration := AIConsiderationDefinition.new()
	consideration.type = type
	consideration.weight = weight
	for key: String in fields:
		consideration.set(key, fields[key])
	return consideration


func _mend() -> EnemyActionDefinition:
	var mend := EnemyActionDefinition.new()
	mend.id = &"mend"
	mend.display_name = "Mend"
	mend.category = Enums.ActionCategory.MAGIC
	mend.target_rule = Enums.TargetRule.OTHER_ALLY
	mend.intent_category = Enums.IntentCategory.HEAL
	mend.telegraph_text = "Tends to an ally."
	mend.effects = [Fixtures.effect(Enums.EffectType.HEAL, Enums.EffectTarget.TARGET, 30.0)]
	mend.considerations = [
		_consideration(Enums.ConsiderationType.TARGET_HP_BELOW, 4.0, {"threshold": 0.5, "else_weight": 0.15, "reason": "Ally badly hurt"}),
	]
	return mend


func _healer_engine(ally_hp_fraction: float, tier: Enums.TacticalDifficulty = Enums.TacticalDifficulty.ADVENTURER) -> BattleEngine:
	var healer := Fixtures.enemy(&"healer", 80, 0, 5, [Fixtures.enemy_attack(&"prod", 5.0), _mend()])
	var brute := Fixtures.enemy(&"brute", 100, 0, 4)
	var engine := BattleEngine.new(Fixtures.setup([healer, brute], null, 3, null, tier))
	var brute_unit := engine.get_state().enemies()[1]
	brute_unit.hp = roundi(brute_unit.max_hp * ally_hp_fraction)
	return engine


func test_healer_does_not_heal_trivial_damage() -> void:
	var engine := _healer_engine(0.95)
	var healer := engine.get_state().enemies()[0]
	EnemyAI.decide(engine.ctx, healer)
	assert_eq(healer.intent.action.id, &"prod", "ally at 95%: attack instead of healing")


func test_healer_heals_when_justified_and_explains_why() -> void:
	var engine := _healer_engine(0.3)
	var healer := engine.get_state().enemies()[0]
	EnemyAI.decide(engine.ctx, healer)
	assert_eq(healer.intent.action.id, &"mend", "ally at 30%: heal")
	assert_eq(healer.intent.target_uids, [engine.get_state().enemies()[1].uid] as Array[int])
	assert_true(healer.intent.reasons.size() > 0 and healer.intent.reasons[0].begins_with("Ally badly hurt"))


func test_difficulty_gates_considerations() -> void:
	var smart := Fixtures.enemy_attack(&"smart", 5.0)
	smart.base_priority = 1.0
	smart.considerations = [_consideration(Enums.ConsiderationType.ROUND_AT_LEAST, 5.0,
		{"threshold": 1.0, "min_difficulty": Enums.TacticalDifficulty.TACTICIAN})]
	var plain := Fixtures.enemy_attack(&"plain", 5.0)
	plain.base_priority = 2.0
	for case: Array in [[Enums.TacticalDifficulty.ADVENTURER, &"plain"], [Enums.TacticalDifficulty.TACTICIAN, &"smart"]]:
		var engine := BattleEngine.new(Fixtures.setup([Fixtures.enemy(&"e", 100, 0, 5, [smart, plain])], null, 1, null, case[0]))
		engine.advance()
		assert_eq(engine.get_state().enemies()[0].intent.action.id, case[1], EnumText.difficulty(case[0]))


func test_story_noise_varies_tactician_is_consistent() -> void:
	var near_a := Fixtures.enemy_attack(&"near_a", 5.0)
	near_a.base_priority = 1.0
	var near_b := Fixtures.enemy_attack(&"near_b", 5.0)
	near_b.base_priority = 1.1
	var story_choices := {}
	var tactician_choices := {}
	for seed in 40:
		for tier: Enums.TacticalDifficulty in [Enums.TacticalDifficulty.STORY, Enums.TacticalDifficulty.TACTICIAN]:
			var setup := Fixtures.setup([Fixtures.enemy(&"e", 100, 0, 5, [near_a, near_b])], null, seed, null, tier)
			setup.difficulty.score_variance = 0.45 if tier == Enums.TacticalDifficulty.STORY else 0.04
			var engine := BattleEngine.new(setup)
			engine.advance()
			var chosen: StringName = engine.get_state().enemies()[0].intent.action.id
			(story_choices if tier == Enums.TacticalDifficulty.STORY else tactician_choices)[chosen] = true
	assert_eq(story_choices.size(), 2, "Story sometimes picks the weaker option")
	assert_eq(tactician_choices.keys(), [&"near_b"], "Tactician reliably picks the better option")


func test_illegal_actions_are_never_chosen() -> void:
	var expensive := Fixtures.enemy_attack(&"expensive", 50.0)
	expensive.base_priority = 99.0
	expensive.focus_cost = 3
	var once := Fixtures.enemy_attack(&"once", 50.0)
	once.base_priority = 50.0
	once.max_uses = 1
	var basic := Fixtures.enemy_attack(&"basic", 5.0)
	var engine := BattleEngine.new(Fixtures.setup([Fixtures.enemy(&"e", 100, 0, 5, [expensive, once, basic])]))
	var enemy := engine.get_state().enemies()[0]
	EnemyAI.decide(engine.ctx, enemy)
	assert_eq(enemy.intent.action.id, &"once", "0 Focus: cannot afford 'expensive'")
	enemy.action_uses[&"once"] = 1
	EnemyAI.decide(engine.ctx, enemy)
	assert_eq(enemy.intent.action.id, &"basic", "'once' used up")
	enemy.focus = 3
	EnemyAI.decide(engine.ctx, enemy)
	assert_eq(enemy.intent.action.id, &"expensive")


func test_tactician_sets_up_combos_for_later_allies() -> void:
	var drench := Fixtures.enemy_attack(&"drench", 1.0)
	drench.synergy_setup = [Enums.SynergyTag.WET]
	drench.considerations = [_consideration(Enums.ConsiderationType.ALLY_SYNERGY_FOLLOWUP, 3.0,
		{"min_difficulty": Enums.TacticalDifficulty.TACTICIAN, "reason": "Setting up an ally"})]
	var poke := Fixtures.enemy_attack(&"poke", 5.0)
	poke.base_priority = 1.5
	var zap := Fixtures.enemy_attack(&"zap", 5.0)
	zap.synergy_payoff = [Enums.SynergyTag.WET]
	var setter := Fixtures.enemy(&"setter", 100, 0, 15, [drench, poke])
	var finisher := Fixtures.enemy(&"finisher", 100, 0, 1, [zap])
	for case: Array in [[Enums.TacticalDifficulty.ADVENTURER, &"poke"], [Enums.TacticalDifficulty.TACTICIAN, &"drench"]]:
		var engine := BattleEngine.new(Fixtures.setup([setter, finisher], null, 1, null, case[0]))
		engine.advance()
		assert_eq(engine.get_state().enemies()[0].intent.action.id, case[1], EnumText.difficulty(case[0]))


func test_tactician_avoids_channel_party_can_break() -> void:
	var channel := Fixtures.enemy_attack(&"doom", 80.0)
	channel.channel_turns = 1
	channel.base_priority = 2.0
	channel.considerations = [_consideration(Enums.ConsiderationType.CHANNEL_AT_RISK, 0.2,
		{"min_difficulty": Enums.TacticalDifficulty.TACTICIAN, "reason": "Would be interrupted"})]
	var jab := Fixtures.enemy_attack(&"jab", 5.0)
	var fragile := Fixtures.enemy(&"fragile", 300, 0, 5, [channel, jab])
	fragile.max_stagger = 15.0
	for case: Array in [[Enums.TacticalDifficulty.ADVENTURER, &"doom"], [Enums.TacticalDifficulty.TACTICIAN, &"jab"]]:
		var engine := BattleEngine.new(Fixtures.setup([fragile], null, 1, null, case[0]))
		engine.advance()
		assert_eq(engine.get_state().enemies()[0].intent.action.id, case[1], EnumText.difficulty(case[0]))


func test_story_avoids_stacking_lethal_attacks() -> void:
	var big := Fixtures.enemy_attack(&"big", 60.0)
	var party := Fixtures.loadout(null, null, Fixtures.companion())
	var first := Fixtures.enemy(&"first", 100, 0, 20, [big])
	var second := Fixtures.enemy(&"second", 100, 0, 19, [big])
	var engine := BattleEngine.new(Fixtures.setup([first, second], party, 1, null, Enums.TacticalDifficulty.STORY))
	engine.ctx.state.round = 1
	engine.ctx.state.turn_order = TurnOrder.compute(engine.ctx)
	var hero := engine.get_state().protagonist()
	hero.hp = 100
	var enemies := engine.get_state().enemies()
	EnemyAI.decide(engine.ctx, enemies[0])
	var first_target := enemies[0].intent.target_uids[0]
	EnemyAI.decide(engine.ctx, enemies[1])
	assert_ne(enemies[1].intent.target_uids[0], first_target, "Story spreads lethal pressure")


func test_role_defaults_are_merged_by_category() -> void:
	var role := EnemyRoleDefinition.new()
	role.role = Enums.EnemyRole.STALKER
	role.display_name = "Stalker"
	var hunt := _consideration(Enums.ConsiderationType.TARGET_HP_BELOW, 3.0, {"threshold": 0.5, "reason": "Wounded prey"})
	hunt.applies_to = [Enums.IntentCategory.ATTACK]
	role.default_considerations = [hunt]
	var lib := Fixtures.library()
	lib.add_role(role)
	var stalker := Fixtures.enemy(&"stalker", 100, 0, 5)
	stalker.role = Enums.EnemyRole.STALKER
	var party := Fixtures.loadout(null, null, Fixtures.companion())
	var engine := BattleEngine.new(Fixtures.setup([stalker], party, 1, lib))
	var companion := engine.get_state().party()[1]
	companion.hp = 20
	var enemy := engine.get_state().enemies()[0]
	EnemyAI.decide(engine.ctx, enemy)
	assert_eq(enemy.intent.target_uids, [companion.uid] as Array[int], "stalkers go for the wounded")
	assert_true(enemy.intent.reasons[0].begins_with("Wounded prey"))
