extends TestCase
## M1.1 F1: the knowledge policy and honest previews (pure presenter models, no scene needed).
## These check the *rendered text* as well as the readout fields, because a leak can happen in
## formatting as easily as in data.

var _registry: DefinitionRegistry


func before_each() -> void:
	_registry = Database.registry


# --- F1-B: unknown affinity leaks nothing -----------------------------------------------------------

func test_unknown_affinity_hides_every_derived_value_for_slash_blunt_and_pierce() -> void:
	for loadout_id: StringName in [&"starter_sword", &"starter_hammer", &"starter_bow"]:
		var driver := _driver(&"fen_patrol", loadout_id)
		var request := driver.to_player_turn()
		var hero := driver.hero()
		if request.unit_uid != hero.uid:
			request = _to_hero_turn(driver)
		var bogshell := _enemy(driver, &"bogshell")
		var option := _option(request, hero.weapon.basic_attack.id)
		var readout := ActionReadout.build(driver.engine, hero.uid, option, bogshell.uid)
		var exact := driver.engine.preview(ActionChoice.from_option(hero.uid, option, bogshell.uid))
		var row := readout.targets[0]
		assert_false(row.has_numbers, "%s: no numbers at UNKNOWN" % loadout_id)
		assert_eq(row.kill_claim, ActionReadout.Claim.NONE)
		assert_eq(row.break_claim, ActionReadout.Claim.NONE)
		assert_empty(readout.breakdown, "%s: no formula" % loadout_id)
		assert_eq(readout.focus_weakness, 0, "no weakness Focus")
		assert_true(readout.focus_affinity_unknown)
		for details in [false, true]:
			var text := _plain(PreviewPanel.describe(readout, details))
			assert_true(text.contains("Affinity unknown"), "%s says the affinity is unknown" % loadout_id)
			for word in ["Weak to", "Resists", "Weakness?", "Resisted?", "Lethal", "Breaks it", "Formula", "x0.7", "×0.7", "x1.3"]:
				assert_false(text.contains(word), "%s leaks '%s' (details=%s): %s" % [loadout_id, word, details, text])
			for grade in [Enums.ExecutionGrade.MISS, Enums.ExecutionGrade.GOOD, Enums.ExecutionGrade.PERFECT]:
				var hidden := "%d–%d" % [exact.damage_min[grade], exact.damage_max[grade]]
				assert_false(text.contains(hidden), "%s leaks the exact range %s" % [loadout_id, hidden])


func test_a_revealing_hit_unlocks_only_that_damage_type() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	var bogshell := _enemy(driver, &"bogshell")
	driver.act(hero.weapon.basic_attack.id, bogshell.uid)
	request = _to_hero_turn(driver)
	if request == null or not bogshell.is_alive():
		fail("the Hollow should get a second turn with the Bogshell alive")
		return
	var slash := ActionReadout.build(driver.engine, hero.uid, _option(request, hero.weapon.basic_attack.id), bogshell.uid)
	assert_true(slash.targets[0].has_numbers, "Slash learned by hitting with it")
	assert_true(_plain(PreviewPanel.describe(slash, false)).contains("Resists Slash"))
	var spark := ActionReadout.build(driver.engine, hero.uid, _option(request, &"spark"), bogshell.uid)
	assert_false(spark.targets[0].has_numbers, "Storm is still unknown")
	assert_true(UnitDetails.affinity_line(driver.engine, bogshell).contains("Unknown: Blunt"), "other types stay unknown")


func test_studied_knowledge_shows_permitted_numbers() -> void:
	var driver := _driver(&"fen_patrol", &"starter_hammer", Enums.ResearchLevel.STUDIED)
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	var bogshell := _enemy(driver, &"bogshell")
	var readout := ActionReadout.build(driver.engine, hero.uid, _option(request, hero.weapon.basic_attack.id), bogshell.uid)
	assert_true(readout.targets[0].has_numbers)
	assert_true(readout.targets[0].weakness, "Bogshell is weak to Blunt")
	assert_eq(readout.focus_weakness, driver.engine.ctx.balance.weakness_focus)
	assert_true(_plain(PreviewPanel.describe(readout, false)).contains("Weak to Blunt"))
	var intent := _intent(driver, bogshell)
	if intent != null:
		assert_false(intent.named, "STUDIED does not reveal move names (UNDERSTOOD does)")
		assert_eq(intent.label, intent.category_text)


# --- F1-C: Inspect changes knowledge, never stats or results ------------------------------------

func test_inspect_reveals_without_changing_stats_or_results() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	var wisp := _enemy(driver, &"fen_wisp")
	var ctx := driver.engine.ctx
	var option := _option(request, hero.weapon.basic_attack.id)
	var before := driver.engine.preview(ActionChoice.from_option(hero.uid, option, wisp.uid))
	var stats := [wisp.hp, wisp.max_hp, wisp.stagger, Stats.guard(ctx, wisp), Stats.force(ctx, wisp)]
	var intent_before := _intent(driver, wisp)
	if intent_before != null:
		assert_false(intent_before.named, "move name hidden before Inspect")
	driver.act(&"inspect", wisp.uid)
	request = _to_hero_turn(driver)
	if request == null or not wisp.is_alive():
		fail("expected another Hollow turn with the wisp alive")
		return
	assert_true(wisp.inspected)
	assert_eq([wisp.max_hp, Stats.guard(ctx, wisp), Stats.force(ctx, wisp)], [stats[1], stats[3], stats[4]],
		"Inspect changes no enemy stat")
	option = _option(request, hero.weapon.basic_attack.id)
	var after := driver.engine.preview(ActionChoice.from_option(hero.uid, option, wisp.uid))
	assert_eq(after.damage_min, before.damage_min, "the exact preview is unchanged by knowledge")
	assert_eq(after.damage_max, before.damage_max)
	var readout := ActionReadout.build(driver.engine, hero.uid, option, wisp.uid)
	assert_true(readout.targets[0].has_numbers, "Inspect reveals the affinity")
	var hp_before := wisp.hp
	driver.act(hero.weapon.basic_attack.id, wisp.uid, Enums.ExecutionGrade.GOOD)
	driver.next_request()
	var dealt := hp_before - wisp.hp
	var good := Enums.ExecutionGrade.GOOD
	assert_true(dealt == 0 or (dealt >= readout.targets[0].damage_min[good] and dealt <= readout.targets[0].damage_max[good]),
		"a known direct preview matches resolution (dealt %d)" % dealt)


# --- F1-D: scope matches resolution -------------------------------------------------------------

func test_area_preview_is_per_target_with_mixed_knowledge_and_no_total() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	var thornhound := _enemy(driver, &"thornhound")
	thornhound.research_level = Enums.ResearchLevel.STUDIED
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	hero.focus = 10
	request = driver.engine.get_request() as ActionSelectRequest
	request.options = driver.engine.options_for(hero.uid)
	var readout := ActionReadout.build(driver.engine, hero.uid, _option(request, &"arc_cleave"))
	assert_eq(readout.scope, ActionReadout.Scope.PER_TARGET)
	assert_eq(readout.targets.size(), driver.engine.get_state().enemies().size(), "one row per living enemy")
	var known := 0
	for row in readout.targets:
		if row.uid == thornhound.uid:
			assert_true(row.has_numbers, "the studied target shows numbers")
			known += 1
		else:
			assert_false(row.has_numbers, "unknown targets stay hidden")
	assert_eq(known, 1)
	var text := _plain(PreviewPanel.describe(readout, true))
	assert_true(text.contains("per target · no total"), text)
	assert_false(text.to_lower().contains("total damage"))


func test_status_qualifiers_are_honest() -> void:
	var action := Fixtures.technique(&"gated", 0, 1.0)
	var gated := Fixtures.effect(Enums.EffectType.APPLY_STATUS, Enums.EffectTarget.TARGET, 1.0, {"status": Enums.StatusId.BURN})
	gated.conditions = [Fixtures.condition(Enums.ConditionType.GRADE_AT_LEAST, {"grade": Enums.ExecutionGrade.PERFECT})]
	var lucky := Fixtures.effect(Enums.EffectType.APPLY_STATUS, Enums.EffectTarget.TARGET, 1.0, {"status": Enums.StatusId.BLEED})
	lucky.chance = 0.3
	var plain := Fixtures.effect(Enums.EffectType.APPLY_STATUS, Enums.EffectTarget.TARGET, 1.0, {"status": Enums.StatusId.SHOCK})
	action.effects = [gated, lucky, plain]
	var notes := RuleNotes.applied_statuses(action)
	assert_eq(notes.size(), 3)
	assert_eq(notes[0].text(), "May apply Burn (conditional)")
	assert_eq(notes[1].text(), "Applies Bleed · 30% chance")
	assert_eq(notes[2].text(), "Applies Shock")


func test_burn_on_a_wet_target_is_shown_as_doused() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	var wisp := _enemy(driver, &"fen_wisp")
	StatusRules.apply_status(driver.engine.ctx, wisp, Enums.StatusId.WET, 1, 3, null)
	hero.focus = 10
	request.options = driver.engine.options_for(hero.uid)
	var readout := ActionReadout.build(driver.engine, hero.uid, _option(request, &"kindle"), wisp.uid)
	assert_has(readout.targets[0].doused, Enums.StatusId.BURN)
	assert_true(_plain(PreviewPanel.describe(readout, false)).contains("would be doused"))


func test_claims_need_proof_at_the_minimum_roll() -> void:
	var lib := Fixtures.library()
	lib.balance.damage_variance = 0.1
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy(&"target", 500)], null, 1, lib))
	var request := driver.to_player_turn()
	var hero := driver.hero()
	var enemy := driver.enemy()
	enemy.research_level = Enums.ResearchLevel.STUDIED
	var option := _option(request, &"strike")
	var exact := driver.engine.preview(ActionChoice.from_option(hero.uid, option, enemy.uid))
	var perfect := Enums.ExecutionGrade.PERFECT
	enemy.hp = exact.damage_max[perfect]
	assert_lt(exact.damage_min[perfect], enemy.hp, "fixture: only a high Perfect roll kills")
	var readout := ActionReadout.build(driver.engine, hero.uid, option, enemy.uid)
	assert_eq(readout.targets[0].kill_claim, ActionReadout.Claim.POSSIBLE)
	var text := _plain(PreviewPanel.describe(readout, false))
	assert_false(text.contains("Lethal at any timing") or text.contains("Lethal with Good"), text)
	assert_true(text.contains("Can be lethal on a high roll"))
	enemy.hp = exact.damage_min[Enums.ExecutionGrade.GOOD]
	readout = ActionReadout.build(driver.engine, hero.uid, option, enemy.uid)
	assert_eq(readout.targets[0].kill_claim, ActionReadout.Claim.GOOD_OR_BETTER, "a Good minimum roll proves it at Good+")


func test_previews_consume_no_rng_or_focus() -> void:
	var driver := _driver(&"fen_patrol", &"starter_bow")
	var request := _to_hero_turn(driver)
	var hero := driver.hero()
	var ctx := driver.engine.ctx
	var rng_state := ctx.rng.state
	var focus := hero.focus
	var events := ctx.events.size()
	for option in request.options:
		for uid in option.target_uids:
			PreviewPanel.describe(ActionReadout.build(driver.engine, hero.uid, option, uid), true)
	for enemy in driver.engine.get_state().enemies():
		var preview := driver.engine.preview_intent(enemy.uid)
		if preview != null:
			UnitDetails.intent_text(driver.engine, IntentReadout.build(driver.engine, preview, true))
		UnitDetails.describe(driver.engine, enemy, true)
	assert_eq(ctx.rng.state, rng_state, "previews never touch the battle RNG")
	assert_eq(hero.focus, focus, "or Focus")
	assert_eq(ctx.events.size(), events, "or emit events")


# --- Intent readout -------------------------------------------------------------------------------

func test_intent_label_is_the_category_until_understood() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	driver.to_player_turn()
	for enemy in driver.engine.get_state().enemies():
		var intent := _intent(driver, enemy)
		if intent == null:
			continue
		assert_false(intent.named)
		assert_eq(intent.label, EnumText.intent_category(intent.action.intent_category), "category label at UNKNOWN")
		assert_true(intent.telegraph_detail.is_empty(), "telegraph detail hidden")
		assert_false(intent.damage_known)
		enemy.inspected = true
		var known := _intent(driver, enemy)
		assert_true(known.named)
		assert_eq(known.label, known.action.display_name)


func test_channel_countdown_counts_activations() -> void:
	var preview := IntentPreview.new()
	preview.action = Fixtures.enemy_attack(&"storm", 10.0)
	var driver := BattleDriver.new(Fixtures.setup([Fixtures.enemy()]))
	driver.to_player_turn()
	preview.enemy_uid = driver.enemy().uid
	preview.turns_until_release = 1
	preview.channeling = false
	var declared := IntentReadout.build(driver.engine, preview)
	assert_eq(declared.activations_to_release, 2, "starts this activation, releases on the next")
	assert_eq(declared.channel_text(), "2 activations until release")
	preview.channeling = true
	var due := IntentReadout.build(driver.engine, preview)
	assert_eq(due.channel_text(), "Releases this activation")


func test_reaction_readout_reads_rules_not_literals() -> void:
	var driver := _driver(&"fen_patrol", &"starter_sword")
	var reaction: ReactionRequest = null
	for i in 60:
		var request := driver.next_request()
		if request is ReactionRequest:
			reaction = request
			break
		if request is ActionSelectRequest:
			driver.act(&"guard")
		elif request is CommandRequest:
			driver.engine.submit_command_result(Enums.ExecutionGrade.GOOD)
	if reaction == null:
		fail("no reaction window opened")
		return
	var readout := ReactionReadout.build(driver.engine, reaction)
	var balance := driver.engine.ctx.balance
	assert_eq(readout.rows.size(), 3)
	assert_eq(readout.rows[0].reaction, Enums.ReactionType.BRACE, "fixed order")
	assert_eq(readout.rows[2].reaction, Enums.ReactionType.PARRY)
	assert_true(readout.rows[1].risk.contains("+%d%%" % roundi((balance.evade_fail_multiplier - 1.0) * 100.0)))
	assert_true(readout.rows[2].effect.contains("%d Stagger" % roundi(balance.parry_stagger)), readout.rows[2].effect)
	var evade_notes := " ".join(readout.rows[1].caveats)
	assert_true(evade_notes.contains("Flooded Ground") and evade_notes.contains("Wet") and evade_notes.contains("even on success"),
		"Flooded Ground's Evade drawback is derived from its rule: %s" % evade_notes)
	for index in readout.rows.size():
		assert_eq(readout.rows[index].allowed, reaction.spec.is_allowed(readout.rows[index].reaction))
		assert_almost_eq(readout.rows[index].window_ms, reaction.spec.window_for(readout.rows[index].reaction), 0.01)


# --- Helpers --------------------------------------------------------------------------------------

func _driver(encounter_id: StringName, loadout_id: StringName,
		knowledge: Enums.ResearchLevel = Enums.ResearchLevel.UNKNOWN) -> BattleDriver:
	var encounter := _registry.encounters[encounter_id]
	var setup := BattleSetup.from_encounter(_registry.loadouts[loadout_id], encounter, Database.library,
		_registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), _registry.assist(Enums.ExecutionAssist.STANDARD), 7)
	for enemy in encounter.enemies:
		setup.research_levels[enemy.id] = knowledge
	return BattleDriver.new(setup)


## Advances (answering everything with simple defaults) until the Hollow is asked to act.
func _to_hero_turn(driver: BattleDriver) -> ActionSelectRequest:
	for i in 40:
		var request := driver.to_player_turn()
		if request == null:
			return null
		if request.unit_uid == driver.hero().uid:
			return request
		if _option(request, &"guard") != null:
			driver.act(&"guard")
		else:
			driver.act(request.options[0].action.id)
	return null


func _option(request: ActionSelectRequest, action_id: StringName) -> ActionOption:
	for option in request.options:
		if option.action.id == action_id:
			return option
	return null


func _enemy(driver: BattleDriver, id: StringName) -> BattleUnit:
	for unit in driver.engine.get_state().enemies(false):
		if unit.definition.id == id:
			return unit
	return null


func _intent(driver: BattleDriver, enemy: BattleUnit) -> IntentReadout:
	var preview := driver.engine.preview_intent(enemy.uid)
	return IntentReadout.build(driver.engine, preview) if preview != null else null


## BBCode stripped, so tests read what the player reads.
func _plain(bbcode: String) -> String:
	var regex := RegEx.create_from_string("\\[[^\\]]*\\]")
	return regex.sub(bbcode, "", true)
