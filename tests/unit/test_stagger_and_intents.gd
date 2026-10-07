extends TestCase
## Stagger/Break, channels, intent honesty, retargeting and Intercept.


func _channel_action(turns: int = 1) -> EnemyActionDefinition:
	var action := Fixtures.enemy_attack(&"cataclysm", 60.0)
	action.channel_turns = turns
	action.intent_category = Enums.IntentCategory.HEAVY_ATTACK
	return action


func test_break_skips_next_turn_and_recovers_with_growth() -> void:
	var enemy_def := Fixtures.enemy(&"tank", 999, 0, 5)
	enemy_def.stagger_growth_on_break = 1.5
	var driver := BattleDriver.new(Fixtures.setup([enemy_def]))
	driver.to_player_turn()
	var enemy := driver.enemy()
	StaggerRules.apply_stagger(driver.engine.ctx, enemy, 60.0, driver.hero())
	assert_true(enemy.is_broken())
	assert_eq(enemy.intent, null, "Broken enemy loses its declared action")
	driver.act(&"strike", enemy.uid)
	driver.to_player_turn()
	assert_eq(driver.count_of(BattleEvent.Type.TURN_SKIPPED), 1)
	assert_false(enemy.is_broken(), "recovers at the end of the lost activation")
	assert_almost_eq(enemy.max_stagger, 75.0, 0.001, "max Stagger grows after a break")
	assert_almost_eq(enemy.stagger, 75.0, 0.001)
	assert_eq(driver.hero().hp, 100, "the broken enemy never attacked")


func test_break_grants_focus_and_exposes_weak_point() -> void:
	var enemy_def := Fixtures.enemy(&"beetle", 999)
	enemy_def.has_weak_point = true
	var driver := BattleDriver.new(Fixtures.setup([enemy_def]))
	driver.to_player_turn()
	var hero := driver.hero()
	var focus_before := hero.focus
	StaggerRules.apply_stagger(driver.engine.ctx, driver.enemy(), 999.0, hero)
	assert_eq(hero.focus, focus_before + 2)
	assert_true(driver.enemy().is_weak_point_exposed())


func test_channel_is_telegraphed_then_released_after_a_round() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"caster", 999, 0, 20, [_channel_action(1)])]))
	driver.to_player_turn()
	var enemy := driver.enemy()
	assert_true(enemy.intent.is_channel())
	assert_eq(driver.count_of(BattleEvent.Type.CHANNEL_STARTED), 1, "fast caster starts channeling first")
	assert_eq(enemy.intent.turns_until_release(), 1)
	driver.act(&"guard")
	var request := driver.next_request()
	assert_true(request is ReactionRequest, "released on its next activation")
	assert_eq((request as ReactionRequest).action.id, &"cataclysm")


func test_breaking_a_channel_interrupts_it() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"caster", 999, 0, 20, [_channel_action(1)])]))
	driver.to_player_turn()
	var hero := driver.hero()
	var focus_before := hero.focus
	StaggerRules.apply_stagger(driver.engine.ctx, driver.enemy(), 999.0, hero)
	assert_eq(driver.engine.drain_events().filter(func(e: BattleEvent) -> bool:
		return e.type == BattleEvent.Type.CHANNEL_INTERRUPTED).size(), 1)
	assert_eq(hero.focus, focus_before + 3, "break +2, interrupt +1")
	driver.act(&"guard")
	driver.to_player_turn()
	assert_eq(hero.hp, 100, "the interrupted channel never lands")


func test_story_gives_extra_channel_turn() -> void:
	var setup := Fixtures.setup([Fixtures.enemy(&"caster", 999, 0, 20, [_channel_action(1)])], null, 1, null,
		Enums.TacticalDifficulty.STORY)
	var driver := BattleDriver.new(setup)
	driver.to_player_turn()
	assert_eq(driver.enemy().intent.channel_total, 2, "Story: same attack, more time to answer")


func test_uninterruptible_channel_survives_break() -> void:
	var action := _channel_action(1)
	action.interruptible = false
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"caster", 999, 0, 20, [action])]))
	driver.to_player_turn()
	StaggerRules.apply_stagger(driver.engine.ctx, driver.enemy(), 999.0, driver.hero())
	assert_not_null(driver.enemy().intent)
	assert_true(driver.enemy().intent.channeling)


func test_dead_target_is_retargeted_by_rule_not_swapped() -> void:
	var attack := Fixtures.enemy_attack(&"bite", 10.0)
	var party := Fixtures.loadout(null, null, Fixtures.companion(9))
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"biter", 999, 0, 1, [attack])], party))
	driver.to_player_turn()
	driver.act(&"guard")
	var companion_turn := driver.to_player_turn()
	var enemy := driver.enemy()
	var original_target := driver.engine.get_unit(enemy.intent.target_uids[0])
	assert_true(original_target.is_protagonist, "ties resolve to the first valid target")
	HealthRules.apply_damage(driver.engine.ctx, original_target, 999, null, Enums.DamageType.PURE, null)
	driver.act(&"guard")
	var request := driver.next_request() as ReactionRequest
	assert_not_null(request)
	assert_eq(request.target_uids, [companion_turn.unit_uid] as Array[int], "re-aimed at the survivor")
	assert_eq(request.action.id, &"bite", "same declared action")
	assert_true(enemy.intent.retargeted)
	assert_eq(driver.count_of(BattleEvent.Type.INTENT_CHANGED), 1, "retargeting is announced")


func test_intercept_redirects_single_target_attack() -> void:
	var attack := Fixtures.enemy_attack(&"bite", 10.0)
	var guardian := Fixtures.companion(15)
	var cover := Fixtures.technique(&"cover", 0, 0.0)
	cover.uses_weapon_power = false
	cover.uses_weapon_stagger = false
	cover.command = null
	cover.target_rule = Enums.TargetRule.OTHER_ALLY
	cover.effects = [Fixtures.effect(Enums.EffectType.INTERCEPT, Enums.EffectTarget.TARGET)]
	guardian.techniques = [cover, Fixtures.technique(&"other", 1, 1.0)]
	var party := Fixtures.loadout(null, Fixtures.hero(0, 0, 10), guardian)
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"biter", 999, 0, 1, [attack])], party))
	var request := driver.to_player_turn()
	var companion_unit := driver.engine.get_unit(request.unit_uid)
	assert_true(companion_unit.is_companion, "companion (Tempo 15) acts first")
	driver.act(&"cover", driver.hero().uid)
	driver.to_player_turn()
	driver.act(&"guard")
	var incoming := driver.next_request() as ReactionRequest
	assert_not_null(incoming)
	assert_eq(incoming.target_uids, [companion_unit.uid] as Array[int], "attack redirected to the interceptor")
	assert_eq(driver.count_of(BattleEvent.Type.INTERCEPTED), 1)


func test_intent_preview_reports_reactions_and_threat() -> void:
	var attack := Fixtures.enemy_attack(&"maul", 50.0)
	attack.can_parry = false
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"mauler", 999, 0, 5, [attack])]))
	driver.to_player_turn()
	var preview := driver.engine.preview_intent(driver.enemy().uid)
	assert_not_null(preview)
	assert_eq(preview.allowed, [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE] as Array[Enums.ReactionType])
	var hero_uid := driver.hero().uid
	assert_eq(preview.unreacted[hero_uid], Vector2i(50, 50))
	assert_eq(preview.braced[hero_uid], Vector2i(30, 30))
	assert_eq(preview.threat, IntentPreview.Threat.SEVERE)
