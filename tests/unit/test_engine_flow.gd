extends TestCase
## State machine flow, initiative, intents, determinism (GDD "Battle state machine").


func test_reaches_player_select_with_intents_declared() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy()]))
	var request := driver.to_player_turn()
	assert_not_null(request, "player gets a turn")
	assert_eq(driver.engine.get_phase(), Enums.BattlePhase.PLAYER_SELECT)
	assert_not_null(driver.enemy().intent, "enemy intent is declared before the player acts")
	assert_eq(driver.count_of(BattleEvent.Type.INTENT_DECLARED), 1)
	assert_eq(driver.count_of(BattleEvent.Type.ROUND_STARTED), 1)


func test_turn_order_by_tempo_party_wins_ties() -> void:
	var fast := Fixtures.enemy(&"fast", 100, 0, 20)
	var tied := Fixtures.enemy(&"tied", 100, 0, 10)
	var driver := BattleDriver.new(Fixtures.setup([fast, tied]))
	driver.next_request()
	var order := driver.engine.get_state().turn_order
	assert_eq(order.size(), 3)
	assert_eq(driver.engine.get_unit(order[0]).definition.id, &"fast")
	assert_true(driver.engine.get_unit(order[1]).is_protagonist, "tie at Tempo 10: party first")


func test_party_ambush_acts_first_and_staggers() -> void:
	var setup := Fixtures.setup([Fixtures.enemy(&"fast", 100, 0, 30)])
	setup.advantage = Enums.Advantage.PARTY_AMBUSH
	var driver := BattleDriver.new(setup)
	driver.next_request()
	var order := driver.engine.get_state().turn_order
	assert_true(driver.engine.get_unit(order[0]).is_protagonist, "ambush: party acts first in round 1")
	assert_almost_eq(driver.enemy().stagger, 50.0 * 0.75, 0.001, "ambush removes 25% Stagger")


func test_victory_flow_and_result() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"weak", 30, 0)]))
	for i in 10:
		var request := driver.to_player_turn()
		if request == null:
			break
		driver.act(&"strike", driver.enemy().uid, Enums.ExecutionGrade.PERFECT)
	assert_true(driver.engine.is_finished())
	assert_eq(driver.engine.get_outcome(), Enums.BattleOutcome.VICTORY)
	var result := driver.engine.build_result()
	assert_true(result.is_victory())
	assert_has(result.defeated_enemies, &"weak")
	assert_has(result.research.keys(), &"weak")
	assert_has(result.weapon_uses.keys(), &"test_sword")


func test_defeat_when_party_falls() -> void:
	var brute := Fixtures.enemy(&"brute", 999, 0, 20, [Fixtures.enemy_attack(&"smash", 400.0)])
	var driver := BattleDriver.new(Fixtures.setup([brute]))
	for i in 10:
		var request := driver.to_player_turn()
		if request == null:
			break
		driver.act(&"guard")
	assert_eq(driver.engine.get_outcome(), Enums.BattleOutcome.DEFEAT)


func test_missed_command_still_resolves_the_action() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 100, 0)]))
	driver.to_player_turn()
	var enemy := driver.enemy()
	driver.act(&"strike", enemy.uid, Enums.ExecutionGrade.MISS)
	driver.next_request()
	assert_eq(enemy.hp, 100 - 17, "MISS deals 85% (20 * 0.85 = 17)")


func test_focus_from_execution_and_weakness() -> void:
	var enemy := Fixtures.enemy(&"dummy", 500, 0)
	enemy.weaknesses = [Enums.DamageType.SLASH]
	var driver := BattleDriver.new(Fixtures.setup([enemy]))
	driver.to_player_turn()
	var hero := driver.hero()
	var start := hero.focus
	driver.act(&"strike", driver.enemy().uid, Enums.ExecutionGrade.PERFECT)
	driver.next_request()
	assert_eq(hero.focus, start + 2 + 1, "Perfect basic +2, weakness +1")
	assert_has(driver.enemy().revealed_affinities, Enums.DamageType.SLASH, "hitting a weakness reveals it")


func test_focus_cost_and_illegal_option_reason() -> void:
	var weapon := Fixtures.sword()
	weapon.techniques = [Fixtures.technique(&"big_cut", 5, 2.0)]
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy()], Fixtures.loadout(weapon)))
	var request := driver.to_player_turn()
	var big_cut: ActionOption = null
	for option in request.options:
		if option.action.id == &"big_cut":
			big_cut = option
	assert_not_null(big_cut)
	assert_false(big_cut.legal, "2 Focus < 5 cost")
	assert_eq(big_cut.reason, "Needs 5 Focus")
	assert_eq(driver.act(&"big_cut"), ERR_INVALID_PARAMETER, "engine rejects illegal choices")


func test_determinism_same_seed_same_battle() -> void:
	var lib := Fixtures.library()
	lib.balance.damage_variance = 0.1
	var first := _play_scripted(Fixtures.setup([Fixtures.enemy(&"a", 120), Fixtures.enemy(&"b", 120)], null, 42, lib,
		Enums.TacticalDifficulty.STORY))
	var second := _play_scripted(Fixtures.setup([Fixtures.enemy(&"a", 120), Fixtures.enemy(&"b", 120)], null, 42, lib,
		Enums.TacticalDifficulty.STORY))
	assert_eq(first, second, "identical seed + inputs produce identical event streams")


func _play_scripted(setup: BattleSetup) -> PackedStringArray:
	var trace := PackedStringArray()
	var driver := BattleDriver.new(setup)
	for i in 30:
		var request := driver.to_player_turn(ReactionResult.make(Enums.ReactionType.BRACE, true))
		if request == null:
			break
		var target := driver.engine.get_state().enemies()[0].uid
		driver.act(&"strike", target, Enums.ExecutionGrade.GOOD)
	for event in driver.events:
		trace.append("%s|%d|%d|%.2f" % [event.type_name(), event.subject, event.other, event.amount])
	return trace


func test_replay_reproduces_battle() -> void:
	var setup := Fixtures.setup([Fixtures.enemy(&"a", 90)], null, 9)
	var driver := BattleDriver.new(setup)
	for i in 20:
		var request := driver.to_player_turn(ReactionResult.make(Enums.ReactionType.EVADE, false))
		if request == null:
			break
		driver.act(&"strike", driver.enemy().uid, Enums.ExecutionGrade.PERFECT if i % 2 == 0 else Enums.ExecutionGrade.MISS)
	var original := driver.engine.build_result()
	var replayed := BattleReplay.replay(Fixtures.setup([Fixtures.enemy(&"a", 90)], null, 9), original.input_log)
	assert_eq(replayed.get_outcome(), driver.engine.get_outcome())
	assert_eq(replayed.get_state().round, driver.engine.get_state().round)
	assert_eq(replayed.get_state().protagonist().hp, driver.hero().hp)


func test_cooldown_blocks_reuse_for_one_activation() -> void:
	var weapon := Fixtures.sword()
	var tech := Fixtures.technique(&"cd_cut", 0, 1.0)
	tech.cooldown = 1
	weapon.techniques = [tech]
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"dummy", 999)], Fixtures.loadout(weapon)))
	driver.to_player_turn()
	assert_eq(driver.act(&"cd_cut"), OK)
	var request := driver.to_player_turn()
	var legal := true
	for option in request.options:
		if option.action.id == &"cd_cut":
			legal = option.legal
	assert_false(legal, "cooldown 1: unavailable on the next activation")
	driver.act(&"strike")
	request = driver.to_player_turn()
	for option in request.options:
		if option.action.id == &"cd_cut":
			legal = option.legal
	assert_true(legal, "available again one activation later")


func test_inspect_reveals_and_awards_research() -> void:
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy()]))
	driver.to_player_turn()
	var focus_before := driver.hero().focus
	driver.act(&"inspect", driver.enemy().uid)
	driver.next_request()
	assert_true(driver.enemy().inspected)
	assert_eq(driver.hero().focus, focus_before + 1)
	var sources: Array[int] = []
	for event in driver.events_of(BattleEvent.Type.RESEARCH):
		sources.append(int(event.amount))
	assert_has(sources, Enums.ResearchSource.ENCOUNTER)
	assert_has(sources, Enums.ResearchSource.INSPECT)
	assert_eq(ResearchRules.detail_level(driver.engine.ctx, driver.enemy()), Enums.ResearchLevel.UNDERSTOOD)


func test_guard_buff_halves_damage_until_next_turn() -> void:
	var brute := Fixtures.enemy(&"brute", 999, 0, 5, [Fixtures.enemy_attack(&"smash", 20.0)])
	var driver := BattleDriver.new(Fixtures.setup([brute]))
	driver.to_player_turn()
	driver.act(&"guard")
	var incoming := driver.next_request()
	assert_true(incoming is ReactionRequest, "brute attacks after the hero")
	assert_true(driver.hero().is_guarding(), "guarding while the attack lands")
	driver.to_player_turn()
	assert_eq(driver.hero().hp, 90, "20 damage halved by Guard")
	assert_false(driver.hero().is_guarding(), "stance ends when the owner acts again")
