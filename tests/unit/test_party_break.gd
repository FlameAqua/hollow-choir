extends TestCase
## Playtest revision, party Break: each controlled party member has its own Break meter. An enemy
## action removes Break once per target (the hit's Break scaled by the reaction, or a Parry's cost);
## at zero that member alone is Broken, loses its next activation without reacting, then recovers.
## None of the enemy Break consequences reach the party, and enemy Break is unchanged. Numbers are
## the BalanceConfig defaults (40 / 8 / Brace x0.5 / Evade x0 / Parry 6).

const T := BattleEvent.Type


func _driver(actions: Array[EnemyActionDefinition], with_companion: bool = false, tune: Callable = Callable(),
		enemy_tempo: int = 20) -> BattleDriver:
	var enemy := Fixtures.enemy(&"slasher", 500, 0, enemy_tempo, actions)
	var party := Fixtures.loadout(null, null, Fixtures.companion() if with_companion else null)
	var setup := Fixtures.setup([enemy], party)
	if tune.is_valid():
		tune.call(setup)
	return BattleDriver.new(setup)


func _attack(power: float = 20.0, area: bool = false) -> EnemyActionDefinition:
	var attack := Fixtures.enemy_attack(&"slash", power)
	if area:
		attack.target_rule = Enums.TargetRule.ALL_ENEMIES
	return attack


## Answers the pending reaction and resolves the enemy action.
func _react(driver: BattleDriver, reaction: ReactionResult) -> void:
	var request := driver.next_request()
	assert_true(request is ReactionRequest, "the enemy attacks first and the party may react")
	driver.engine.submit_reaction(reaction)
	driver.next_request()


func _break_events(driver: BattleDriver, uid: int) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in driver.events:
		if event.type == T.STAGGER_DAMAGE and event.subject == uid:
			result.append(event)
	return result


func test_each_party_member_has_its_own_full_break_meter() -> void:
	var driver := _driver([_attack()], true)
	driver.next_request()
	var party := driver.engine.get_state().party()
	assert_eq(party.size(), 2)
	for unit in party:
		assert_true(unit.has_break_meter(), unit.display_name)
		assert_almost_eq(unit.max_stagger, 40.0)
		assert_almost_eq(unit.stagger, 40.0)
		assert_true(unit.can_react())
		assert_false(unit.is_broken())
	assert_almost_eq(driver.enemy().max_stagger, 50.0, 0.001, "the enemy's own meter is its definition's")
	# The balance values are data and validated.
	var balance := BalanceConfig.new()
	assert_eq([balance.party_max_break, balance.party_break_hit, balance.party_break_brace_multiplier,
		balance.party_break_evade_multiplier, balance.party_break_failed_multiplier, balance.party_break_parry_cost,
		balance.party_break_turns], [40.0, 8.0, 0.5, 0.0, 1.0, 6.0, 1])
	balance.default_guard_action = Fixtures.guard_action()
	balance.default_inspect_action = Fixtures.inspect_action()
	assert_empty(balance.validate())
	balance.party_break_turns = 0
	balance.party_break_hit = -1.0
	assert_eq(balance.validate().size(), 2)
	assert_almost_eq(Database.registry.balance.party_max_break, 40.0, 0.001, "the shipped balance uses the defaults")


func test_reaction_outcomes_decide_the_break_a_hit_removes() -> void:
	var cases := [
		[ReactionResult.none(), 8.0, 0, "no reaction: the whole hit"],
		[ReactionResult.make(Enums.ReactionType.BRACE, true), 4.0, 0, "a Brace halves it"],
		[ReactionResult.make(Enums.ReactionType.BRACE, false), 8.0, 0, "a failed Brace: the whole hit"],
		[ReactionResult.make(Enums.ReactionType.EVADE, true), 0.0, 0, "an Evade avoids it"],
		[ReactionResult.make(Enums.ReactionType.EVADE, false), 8.0, 0, "a failed Evade: the whole hit"],
		[ReactionResult.make(Enums.ReactionType.PARRY, true), 6.0, BattleEvent.FLAG_REACTION_COST, "a Parry pays its cost"],
		[ReactionResult.make(Enums.ReactionType.PARRY, false), 8.0, 0, "a failed Parry: the whole hit"],
	]
	for entry: Array in cases:
		var driver := _driver([_attack()])
		_react(driver, entry[0])
		var hero := driver.hero()
		assert_almost_eq(hero.stagger, 40.0 - float(entry[1]), 0.001, entry[3])
		var events := _break_events(driver, hero.uid)
		if float(entry[1]) <= 0.0:
			assert_empty(events, entry[3])
			continue
		assert_eq(events.size(), 1, "%s: one Break event per defender per action" % entry[3])
		assert_eq([events[0].other, events[0].flags], [driver.enemy().uid, entry[2]], entry[3])
		assert_almost_eq(events[0].amount, float(entry[1]), 0.001, entry[3])
		assert_almost_eq(events[0].amount2, 40.0 - float(entry[1]), 0.001, entry[3])
	# The same amounts are published before the choice: the reaction spec and the intent preview.
	var driver := _driver([_attack()])
	var request := driver.next_request() as ReactionRequest
	assert_eq([request.spec.break_unreacted, request.spec.break_brace, request.spec.break_evade,
		request.spec.break_parry_cost], [8.0, 4.0, 0.0, 6.0])
	var preview := driver.engine.preview_intent(driver.enemy().uid)
	assert_eq([preview.break_unreacted, preview.break_braced, preview.break_parry_cost],
		[{driver.hero().uid: 8.0} as Dictionary[int, float], {driver.hero().uid: 4.0} as Dictionary[int, float], 6.0])


func test_a_parry_keeps_its_rewards_and_pays_break_once_after_them() -> void:
	var driver := _driver([_attack()])
	var focus_before := 0
	var request := driver.next_request() as ReactionRequest
	focus_before = driver.hero().focus
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
	driver.next_request()
	var hero := driver.hero()
	assert_eq(hero.hp, 100, "the Parry still negates the hit")
	assert_eq(hero.focus, focus_before + 2, "and still earns its Focus")
	assert_almost_eq(driver.enemy().stagger, 50.0 - 18.0, 0.001, "and still staggers the attacker")
	# Order: reaction result, the attacker's Stagger, the Focus, then the defender's Break cost.
	var order: Array[String] = []
	for event in driver.events:
		if event.type == T.REACTION_RESULT:
			order.append("reaction")
		elif event.type == T.STAGGER_DAMAGE:
			order.append("stagger:%d" % event.subject)
		elif event.type == T.FOCUS_CHANGED and event.subject == hero.uid and event.amount > 0:
			order.append("focus")
	assert_eq(order, ["reaction", "stagger:%d" % driver.enemy().uid, "focus", "stagger:%d" % hero.uid] as Array[String])
	assert_not_null(request)


func test_an_area_attack_charges_each_target_once() -> void:
	# Unreacted: both take the hit's Break, once each.
	var driver := _driver([_attack(20.0, true)], true)
	_react(driver, ReactionResult.none())
	var party := driver.engine.get_state().party()
	assert_eq(party.map(func(unit: BattleUnit) -> float: return unit.stagger), [32.0, 32.0])
	for unit in party:
		assert_eq(_break_events(driver, unit.uid).size(), 1, unit.display_name)
	# One shared Parry: the Focus and Stagger reward is paid once (existing rule), and each parrying
	# unit pays the Break cost once, never once per hit of the sequence.
	var parried := _driver([_attack(20.0, true)], true)
	var request := parried.next_request() as ReactionRequest
	assert_eq(request.target_uids.size(), 2)
	var focus := parried.engine.get_state().party().map(func(unit: BattleUnit) -> int: return unit.focus)
	parried.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
	parried.next_request()
	var after := parried.engine.get_state().party()
	assert_eq(after.map(func(unit: BattleUnit) -> float: return unit.stagger), [34.0, 34.0])
	assert_eq(after.map(func(unit: BattleUnit) -> int: return unit.focus), [focus[0] + 2, focus[1]], "one Parry reward")
	assert_almost_eq(parried.enemy().stagger, 50.0 - 18.0, 0.001, "the attacker is staggered once")
	for unit in after:
		var events := _break_events(parried, unit.uid)
		assert_eq([events.size(), events[0].flags], [1, BattleEvent.FLAG_REACTION_COST], unit.display_name)


func test_a_broken_member_loses_one_activation_and_recovers_alone() -> void:
	# A meter of 8: the first unreacted hit breaks whichever member it lands on. The other is untouched.
	var driver := _driver([_attack()], true, func(setup: BattleSetup) -> void: setup.library.balance.party_max_break = 8.0)
	var request := driver.next_request() as ReactionRequest
	assert_eq(request.target_uids.size(), 1)
	var victim := driver.engine.get_unit(request.target_uids[0])
	var other: BattleUnit = driver.engine.get_state().party().filter(func(unit: BattleUnit) -> bool: return unit != victim)[0]
	var enemy := driver.enemy()
	driver.engine.submit_reaction(ReactionResult.none())
	# Play the rest of the round: the other member acts, the victim's activation is skipped.
	var acted: Array[int] = []
	var next := driver.next_request()
	for step in 6:
		if driver.count_of(T.RECOVERED) > 0 and not acted.is_empty():
			break
		if next is ActionSelectRequest:
			acted.append(next.unit_uid)
			driver.act(&"guard")
		elif next is ReactionRequest:
			break
		next = driver.next_request()
	assert_eq(acted, [other.uid] as Array[int], "the other member still acts: one unit's break never costs the other's turn")
	assert_eq(driver.count_of(T.BROKEN), 1)
	var broken := driver.events_of(T.BROKEN)[0]
	assert_eq([broken.subject, broken.other, broken.flags], [victim.uid, enemy.uid, 0])
	assert_eq(driver.events_of(T.TURN_SKIPPED).map(func(event: BattleEvent) -> int: return event.subject), [victim.uid],
		"exactly one activation was lost, the victim's")
	assert_eq(driver.events_of(T.RECOVERED).map(func(event: BattleEvent) -> int: return event.subject), [victim.uid])
	# The lost activation ends the Broken state with the same full meter: the cap did not grow.
	assert_false(victim.is_broken())
	assert_true(victim.can_react())
	assert_eq([victim.stagger, victim.max_stagger, victim.break_count], [8.0, 8.0, 1])
	assert_eq([other.stagger, other.break_count], [8.0, 0], "the other member's meter is its own")
	# None of the enemy consequences: no Focus for the breaker, no weak point, no trigger.
	var gained := driver.events_of(T.FOCUS_CHANGED).filter(func(event: BattleEvent) -> bool:
		return event.subject == enemy.uid and event.text in ["Break", "Interrupt"])
	assert_empty(gained, "the enemy earns no Break Focus")
	assert_false(victim.is_weak_point_exposed())
	assert_eq(driver.count_of(T.WEAK_POINT_EXPOSED), 0)
	# Event order for the break itself: the hit, the Break it removed, Broken; later the skip and recovery.
	var order: Array[int] = []
	for event in driver.events:
		if event.subject == victim.uid and event.type in [T.DAMAGE, T.STAGGER_DAMAGE, T.BROKEN, T.TURN_SKIPPED, T.RECOVERED]:
			order.append(event.type)
	assert_eq(order, [T.DAMAGE, T.STAGGER_DAMAGE, T.BROKEN, T.TURN_SKIPPED, T.RECOVERED] as Array[int])


func test_presentation_follows_each_party_bar_from_the_events() -> void:
	var driver := _driver([_attack()], true, func(setup: BattleSetup) -> void: setup.library.balance.party_max_break = 8.0)
	var ledger := PresentationLedger.new()
	ledger.snapshot(driver.engine)
	var party := driver.engine.get_state().party()
	for member in party:
		var display := ledger.unit(member.uid)
		assert_eq([display.has_break, display.stagger, display.max_stagger, display.broken], [true, 8.0, 8.0, false],
			member.display_name)
	var request := driver.next_request() as ReactionRequest
	var victim := driver.engine.get_unit(request.target_uids[0])
	var other: BattleUnit = party.filter(func(unit: BattleUnit) -> bool: return unit != victim)[0]
	driver.engine.submit_reaction(ReactionResult.none())
	var next := driver.next_request()
	for step in 6:
		if driver.count_of(T.RECOVERED) > 0 or next is ReactionRequest:
			break
		if next is ActionSelectRequest:
			driver.act(&"guard")
		next = driver.next_request()
	assert_eq(driver.count_of(T.RECOVERED), 1, "the fixture breaks and recovers one member")
	# Replaying the batch moves only the victim's bar, in event order; the UI derives nothing.
	ledger.begin_batch(driver.events)
	var seen: Array[String] = []
	for index in driver.events.size():
		var event := driver.events[index]
		ledger.apply(event, index, driver.engine)
		if event.subject != victim.uid or not event.type in [T.STAGGER_DAMAGE, T.BROKEN, T.RECOVERED]:
			continue
		var display := ledger.unit(victim.uid)
		seen.append("%d:%.0f:%s" % [event.type, display.stagger, display.broken])
		var readout := UnitReadout.build(driver.engine, victim, display, null, false)
		assert_eq([readout.has_break, readout.break_current, readout.break_max, readout.broken],
			[true, roundi(display.stagger), 8, display.broken])
		assert_eq([readout.resource, readout.max_resource], [display.focus, display.max_focus],
			"a party member's resource stays Focus")
	assert_eq(seen, ["%d:0:false" % T.STAGGER_DAMAGE, "%d:0:true" % T.BROKEN, "%d:8:false" % T.RECOVERED])
	assert_eq([ledger.unit(other.uid).stagger, ledger.unit(other.uid).broken], [8.0, false], "the other bar is its own")
	var enemy_readout := UnitReadout.build(driver.engine, driver.enemy(), ledger.unit(driver.enemy().uid), null, false)
	assert_true(enemy_readout.has_break)
	assert_eq(enemy_readout.resource, enemy_readout.break_current, "an enemy's resource is still its Break")


func test_a_broken_member_cannot_react_and_takes_normal_damage() -> void:
	# Two enemies act before the Hollow. The first breaks it (a meter of 8); the second then hits a
	# Broken unit: no reaction window opens, the damage is not multiplied and no more Break is lost.
	var first := Fixtures.enemy(&"first", 500, 0, 20, [_attack()])
	var second := Fixtures.enemy(&"second", 500, 0, 15, [_attack()])
	var setup := Fixtures.setup([first, second])
	setup.library.balance.party_max_break = 8.0
	var driver := BattleDriver.new(setup)
	var request := driver.next_request()
	assert_true(request is ReactionRequest)
	driver.engine.submit_reaction(ReactionResult.none())
	request = driver.next_request()
	var hero := driver.hero()
	assert_eq(driver.count_of(T.REACTION_RESULT), 1, "only the first attack was answered; the second opened no window")
	var hits := driver.events_of(T.DAMAGE).filter(func(event: BattleEvent) -> bool: return event.subject == hero.uid)
	assert_eq(hits.map(func(event: BattleEvent) -> float: return event.amount), [20.0, 20.0],
		"the hit on the Broken Hollow is not multiplied")
	assert_true(hits.all(func(event: BattleEvent) -> bool: return not event.has_flag(BattleEvent.FLAG_BROKEN_BONUS)))
	assert_eq(hero.hp, 60)
	assert_eq(_break_events(driver, hero.uid).size(), 1, "a Broken unit takes no further Break")
	assert_eq([driver.count_of(T.BROKEN), driver.count_of(T.TURN_SKIPPED), driver.count_of(T.RECOVERED)], [1, 1, 1])
	assert_false(hero.is_broken(), "recovered at the end of its lost activation")
	assert_true(request is ReactionRequest, "next round it can react again")
	# The rules behind it.
	hero.broken_turns_left = 1
	hero.stagger = 0.0
	var calc := DamageCalculator.calculate_hit(driver.engine.ctx, driver.enemy(), hero, _attack(), Enums.ExecutionGrade.GOOD)
	assert_false(calc.broken_bonus)
	assert_eq(calc.maximum, 20)
	assert_false(StaggerRules.vulnerable_when_broken(hero))
	assert_true(StaggerRules.vulnerable_when_broken(driver.enemy()))
	assert_almost_eq(StaggerRules.apply_party_break(driver.engine.ctx, hero, driver.enemy(), _attack(), null), 0.0)
	assert_false(hero.can_react())


func test_the_shared_reaction_covers_only_the_units_that_can_react() -> void:
	var first := Fixtures.enemy(&"first", 500, 0, 20, [_attack(20.0, true)])
	var second := Fixtures.enemy(&"second", 500, 0, 15, [_attack(20.0, true)])
	var driver := BattleDriver.new(Fixtures.setup([first, second], Fixtures.loadout(null, null, Fixtures.companion())))
	var request := driver.next_request() as ReactionRequest
	var hero := driver.hero()
	var buddy := driver.engine.get_state().party()[1]
	assert_eq(request.target_uids, [hero.uid, buddy.uid] as Array[int])
	var targets: Array[BattleUnit] = [hero, buddy]
	assert_eq(IntentRules.reacting_targets(request.action, targets), targets)
	# The Hollow is one hit from breaking; the companion is not.
	hero.stagger = 8.0
	driver.engine.submit_reaction(ReactionResult.none())
	request = driver.next_request() as ReactionRequest
	assert_true(hero.is_broken())
	assert_false(buddy.is_broken())
	assert_almost_eq(buddy.stagger, 32.0)
	# The second area attack: the reaction is asked of the companion alone.
	assert_not_null(request)
	assert_eq(request.target_uids, [buddy.uid] as Array[int], "a Broken unit is left out of the shared reaction")
	assert_eq(IntentRules.reacting_targets(request.action, targets), [buddy] as Array[BattleUnit])
	driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.EVADE, true))
	driver.next_request()
	assert_eq([hero.hp, buddy.hp], [60, 80], "the Broken Hollow is hit unreacted; the companion's Evade works")
	assert_almost_eq(buddy.stagger, 32.0, 0.001, "and its Evade avoided the Break")
	# The Hollow lost its activation; the companion did not.
	assert_eq(driver.events_of(T.TURN_SKIPPED).map(func(event: BattleEvent) -> int: return event.subject), [hero.uid])
	assert_eq((driver.engine.get_request() as ActionSelectRequest).unit_uid, buddy.uid)
	# With every party target Broken no window opens at all.
	buddy.broken_turns_left = 1
	hero.broken_turns_left = 1
	assert_empty(IntentRules.reacting_targets(request.action, targets))
	assert_false(IntentRules.needs_reaction(request.action, targets))


func test_only_a_resolved_enemy_hit_removes_break() -> void:
	# A lethal hit: the defeated unit takes no Break and is never Broken.
	var lethal := _driver([_attack(999.0)], true)
	_react(lethal, ReactionResult.none())
	assert_false(lethal.hero().is_alive())
	assert_empty(_break_events(lethal, lethal.hero().uid))
	assert_eq(lethal.count_of(T.BROKEN), 0)
	assert_false(lethal.hero().is_broken())
	# Damage over time and effect damage are not hits.
	var burning := _driver([_attack()])
	_react(burning, ReactionResult.make(Enums.ReactionType.EVADE, true))
	var hero := burning.hero()
	StatusRules.apply_status(burning.engine.ctx, hero, Enums.StatusId.BURN, 3, 3, burning.enemy())
	burning.act(&"guard")
	_react(burning, ReactionResult.make(Enums.ReactionType.EVADE, true))
	assert_lt(hero.hp, 100, "the Burn ticked")
	assert_almost_eq(hero.stagger, 40.0, 0.001, "and removed no Break")
	# Authored Stagger effects and restoration stay enemy-only.
	assert_almost_eq(StaggerRules.apply_stagger(burning.engine.ctx, hero, 30.0, burning.enemy()), 0.0)
	hero.stagger = 10.0
	StaggerRules.restore(burning.engine.ctx, hero, 30.0)
	assert_almost_eq(hero.stagger, 10.0)
	# A non-damaging action deals none, unless it is parried (the Parry still costs).
	var hex := Fixtures.enemy_attack(&"hex", 0.0)
	hex.category = Enums.ActionCategory.MAGIC
	hex.effects = [Fixtures.effect(Enums.EffectType.APPLY_STATUS, Enums.EffectTarget.TARGET, 1.0, {"status": Enums.StatusId.WET})]
	assert_false(hex.deals_damage())
	var balance := BalanceConfig.new()
	assert_almost_eq(StaggerRules.party_break_amount(balance, hex, null), 0.0)
	assert_almost_eq(StaggerRules.party_break_amount(balance, hex, ReactionResult.make(Enums.ReactionType.BRACE, true)), 0.0)
	assert_almost_eq(StaggerRules.party_break_amount(balance, hex, ReactionResult.make(Enums.ReactionType.PARRY, true)), 6.0)
	# An authored per-attack value replaces the default hit and is scaled the same way.
	var heavy := _attack()
	heavy.party_break = 20.0
	assert_almost_eq(StaggerRules.party_break_amount(balance, heavy, null), 20.0)
	assert_almost_eq(StaggerRules.party_break_amount(balance, heavy, ReactionResult.make(Enums.ReactionType.BRACE, true)), 10.0)
	assert_almost_eq(StaggerRules.party_break_amount(balance, heavy, ReactionResult.make(Enums.ReactionType.EVADE, true)), 0.0)
	assert_almost_eq(StaggerRules.party_break_amount(balance, heavy, ReactionResult.make(Enums.ReactionType.PARRY, true)), 6.0)
	# Party actions never remove party Break (a unit hitting its own side, or healing it).
	assert_almost_eq(StaggerRules.apply_party_break(burning.engine.ctx, burning.enemy(), hero, _attack(), null), 0.0,
		0.001, "an enemy is not a party defender")


func test_an_interceptor_takes_the_break_and_a_broken_one_does_not_cover() -> void:
	# The party acts first here. The companion covers the Hollow during its own activation (cover
	# lasts until its next one), then the enemy's attack on the Hollow lands on the companion.
	var driver := _driver([_attack()], true, Callable(), 5)
	var request := driver.to_player_turn()
	var hero := driver.hero()
	var buddy := driver.engine.get_state().party()[1]
	assert_eq(request.unit_uid, hero.uid)
	driver.act(&"guard")
	request = driver.next_request() as ActionSelectRequest
	assert_eq(request.unit_uid, buddy.uid)
	InterceptRules.cover(driver.engine.ctx, buddy, hero)
	driver.enemy().intent.target_uids = [hero.uid]
	var action := driver.enemy().intent.action
	assert_eq(InterceptRules.final_target(driver.engine.ctx, action, hero), buddy)
	driver.act(&"guard")
	var reaction := driver.next_request() as ReactionRequest
	assert_eq(reaction.target_uids, [buddy.uid] as Array[int], "the interceptor is the target and the one who reacts")
	driver.engine.submit_reaction(ReactionResult.none())
	driver.next_request()
	assert_eq([hero.stagger, buddy.stagger], [40.0, 32.0], "the unit that is hit pays the Break")
	buddy.broken_turns_left = 1
	assert_eq(InterceptRules.final_target(driver.engine.ctx, action, hero), hero, "a Broken interceptor covers nobody")


func test_enemy_break_is_unchanged() -> void:
	var enemy_def := Fixtures.enemy(&"tank", 999, 0, 5)
	enemy_def.stagger_growth_on_break = 1.5
	enemy_def.has_weak_point = true
	var driver := BattleDriver.new(Fixtures.setup([enemy_def]))
	driver.to_player_turn()
	var enemy := driver.enemy()
	var hero := driver.hero()
	var focus_before := hero.focus
	StaggerRules.apply_stagger(driver.engine.ctx, enemy, 60.0, hero)
	assert_true(enemy.is_broken())
	assert_eq(hero.focus, focus_before + 2, "the breaker still gains Focus")
	assert_true(enemy.is_weak_point_exposed())
	var calc := DamageCalculator.calculate_hit(driver.engine.ctx, hero, enemy, Fixtures.strike(), Enums.ExecutionGrade.GOOD)
	assert_true(calc.broken_bonus, "a Broken enemy still takes extra damage")
	driver.act(&"strike", enemy.uid)
	driver.to_player_turn()
	assert_almost_eq(enemy.max_stagger, 75.0, 0.001, "and its cap still grows on recovery")
	assert_almost_eq(hero.stagger, 40.0, 0.001, "the Hollow's own meter was never touched by its attack")


func test_party_break_is_deterministic_and_replays_exactly() -> void:
	var make := func() -> BattleSetup:
		var enemy := Fixtures.enemy(&"slasher", 400, 0, 20, [_attack(12.0, true), _attack(9.0)])
		var setup := Fixtures.setup([enemy, Fixtures.enemy(&"second", 300, 0, 7, [_attack(8.0)])],
			Fixtures.loadout(null, null, Fixtures.companion()), 31)
		setup.library.balance.party_max_break = 14.0
		setup.library.balance.damage_variance = 0.05
		return setup
	var first := WorldKit.fingerprint(make.call())
	assert_eq(WorldKit.fingerprint(make.call()), first, "same setup and policy: the same battle, Break events included")
	# A recorded battle replays to the same result from its input log.
	var driver := BattleDriver.new(make.call())
	var reactions := [ReactionResult.none(), ReactionResult.make(Enums.ReactionType.PARRY, true),
		ReactionResult.make(Enums.ReactionType.BRACE, true), ReactionResult.make(Enums.ReactionType.EVADE, false)]
	var turn := 0
	for step in 60:
		var request := driver.next_request()
		if request == null:
			break
		if request is ReactionRequest:
			driver.engine.submit_reaction(reactions[turn % reactions.size()])
			turn += 1
		elif request is ActionSelectRequest:
			driver.act((request as ActionSelectRequest).legal_options()[0].action.id)
	assert_gt(driver.count_of(T.BROKEN), 0.0, "the fixture really breaks a party member")
	var broken_party := driver.events_of(T.BROKEN).filter(func(event: BattleEvent) -> bool:
		return not driver.engine.get_unit(event.subject).is_enemy())
	assert_gt(broken_party.size(), 0.0)
	var original := driver.engine.build_result()
	var replayed := BattleReplay.replay(make.call(), original.input_log)
	var state := replayed.get_state()
	var live := driver.engine.get_state()
	assert_eq(state.round, live.round)
	for index in live.units.size():
		assert_eq([state.units[index].hp, state.units[index].stagger, state.units[index].break_count, state.units[index].focus],
			[live.units[index].hp, live.units[index].stagger, live.units[index].break_count, live.units[index].focus],
			live.units[index].display_name)
	# Metrics count party breaks apart from enemy breaks.
	var metrics := BattleMetrics.new()
	metrics.consume(driver.engine, driver.events)
	assert_eq(metrics.party_breaks, broken_party.size())
	assert_eq(metrics.stagger_breaks, driver.count_of(T.BROKEN) - broken_party.size())
