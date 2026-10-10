extends TestCase
## V0.5 UI combat arrangement rules (CombatRules): candidate order, the deterministic default,
## resolution of saved, edited or outdated arrangements, the put/swap/move semantics, typed checks,
## the repair of invalid saves, the readout and how UnitFactory applies an arrangement. Capacity
## (six) stays separate from the engine ceiling (PartyLoadout.MAX_ACTIONS = eight).

const SWORD := [&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect", &"spark", &"kindle"]


func _progress(weapon: StringName = &"pilgrims_edge") -> ProgressState:
	var progress := ProgressState.new()
	progress.loadout_weapon = weapon
	return progress


static func _ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func test_capacity_positions_and_candidates_follow_the_gear() -> void:
	var registry := Database.registry
	assert_eq(CombatRules.STARTING_CAPACITY, 6)
	assert_eq(CombatRules.POSITIONS, PartyLoadout.MAX_ACTIONS, "eight shown positions: the engine's grid")
	assert_lt(CombatRules.capacity(_progress(), registry), CombatRules.POSITIONS, "two stay locked")
	assert_eq(CombatRules.ids_of(CombatRules.candidates(_progress(), registry)), _ids(SWORD),
		"Actions in grid order, then Magic")
	for weapon_id in [&"pilgrims_edge", &"mire_maul", &"reedbow"]:
		var progress := _progress(weapon_id)
		var candidates := CombatRules.candidates(progress, registry)
		var weapon: WeaponDefinition = registry.weapons[weapon_id]
		assert_eq(candidates.size(), 7, "%s: every starter grants seven actions" % weapon_id)
		assert_eq(candidates[0], weapon.basic_attack)
		assert_eq(candidates.slice(5).map(func(action: ActionDefinition) -> StringName: return action.id),
			[&"spark", &"kindle"], "magic last")
		var arranged := CombatRules.arrangement(progress, registry)
		assert_eq(arranged, CombatRules.ids_of(candidates).slice(0, 6), "%s: the default is the first six" % weapon_id)
		assert_false(arranged.has(&"kindle"), "the seventh waits outside, visibly (never hidden)")
		assert_true(arranged.has(&"inspect") and arranged.has(weapon.guard_action.id))


func test_resolve_keeps_positions_and_fills_freed_ones_deterministically() -> void:
	var pool := _ids(SWORD)
	var cases := [
		[[], [&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect", &"spark"], "empty = the default"],
		[[&"kindle", &"sword_strike"], [&"kindle", &"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect"],
			"a short saved list keeps its order and fills the rest in candidate order"],
		[[&"spark", &"crush", &"spark", &"inspect"], [&"spark", &"sword_strike", &"lunge", &"inspect", &"arc_cleave", &"riposte_stance"],
			"an ungranted id and a duplicate free their positions, filled in candidate order"],
		[[&"inspect", &"spark", &"kindle", &"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance"],
			[&"inspect", &"spark", &"kindle", &"sword_strike", &"lunge", &"arc_cleave"],
			"an older arrangement larger than six keeps its first six"],
		[[&"inspect", &"bogus", &"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"kindle", &"spark"],
			[&"inspect", &"kindle", &"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance"],
			"a freed position prefers the saved overflow, in saved order"],
	]
	for case: Array in cases:
		assert_eq(CombatRules.resolve(_ids(case[0]), pool, 6), _ids(case[1]), case[2])
	assert_eq(CombatRules.resolve(_ids([&"sword_strike"]), _ids([&"sword_strike", &"inspect"]), 6), _ids([&"sword_strike", &"inspect"]),
		"fewer candidates than positions: every candidate, no padding")
	assert_eq(CombatRules.resolve(_ids([&"sword_strike"]), pool, 0), [] as Array[StringName], "no capacity, no action")
	# A weapon swap: the new weapon's actions take the old weapon's positions; shared ones stay put.
	var maul := CombatRules.ids_of(CombatRules.candidates(_progress(&"mire_maul"), Database.registry))
	var sword_layout := _ids([&"inspect", &"sword_strike", &"spark", &"lunge", &"riposte_stance", &"arc_cleave"])
	var swapped := CombatRules.resolve(sword_layout, maul, 6)
	assert_eq([swapped[0], swapped[2]], [&"inspect", &"spark"], "shared actions keep their positions")
	assert_eq(swapped.size(), 6)
	for id in swapped:
		assert_true(maul.has(id), "only granted actions")
	assert_eq(CombatRules.resolve(sword_layout, maul, 6), swapped, "deterministic")


func test_put_swap_and_move_keep_one_of_each_action() -> void:
	var current := _ids([&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect", &"spark"])
	assert_eq(CombatRules.put(current, 5, &"kindle"), _ids([&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance",
		&"inspect", &"kindle"]), "an unarranged action replaces the position's action")
	assert_eq(CombatRules.put(current, 0, &"spark"), _ids([&"spark", &"lunge", &"arc_cleave", &"riposte_stance",
		&"inspect", &"sword_strike"]), "an arranged action swaps places")
	assert_eq(CombatRules.put(current, 2, &"arc_cleave"), current, "the same position is a no-op")
	var short := _ids([&"sword_strike", &"lunge"])
	assert_eq(CombatRules.put(short, 4, &"kindle"), _ids([&"sword_strike", &"lunge", &"kindle"]), "an empty position fills next")
	assert_eq(CombatRules.put(short, 4, &"sword_strike"), _ids([&"lunge", &"sword_strike"]), "moving into the empty end")
	assert_eq(CombatRules.swap(current, 1, 4), _ids([&"sword_strike", &"inspect", &"arc_cleave", &"riposte_stance", &"lunge",
		&"spark"]))
	assert_eq(CombatRules.move(current, &"spark", 0), _ids([&"spark", &"sword_strike", &"lunge", &"arc_cleave",
		&"riposte_stance", &"inspect"]), "reorder shifts the actions between")
	assert_eq(CombatRules.move(current, &"sword_strike", 5), _ids([&"lunge", &"arc_cleave", &"riposte_stance", &"inspect",
		&"spark", &"sword_strike"]))
	for result in [CombatRules.put(current, 5, &"kindle"), CombatRules.swap(current, 0, 5), CombatRules.move(current, &"lunge", 3)]:
		var seen := {}
		for id in result:
			assert_false(seen.has(id), "no duplicate active choices")
			seen[id] = true
	assert_eq(current, _ids([&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect", &"spark"]),
		"the input list is never changed")


func test_checks_are_typed() -> void:
	var registry := Database.registry
	var library := Database.library
	var progress := _progress()
	for case: Array in [
			[0, &"kindle", CombatResult.Reason.OK],
			[5, &"sword_strike", CombatResult.Reason.OK],
			[6, &"kindle", CombatResult.Reason.LOCKED_POSITION],
			[7, &"sword_strike", CombatResult.Reason.LOCKED_POSITION],
			[8, &"sword_strike", CombatResult.Reason.INVALID_POSITION],
			[-1, &"sword_strike", CombatResult.Reason.INVALID_POSITION],
			[0, &"earthsplitter", CombatResult.Reason.NOT_GRANTED],
			[0, &"pilgrims_patience", CombatResult.Reason.PASSIVE_SKILL],
			[0, &"litany", CombatResult.Reason.PASSIVE_SKILL],
			[0, &"no_such_action", CombatResult.Reason.UNKNOWN_ACTION]]:
		assert_eq(CombatRules.put_check(progress, registry, library, case[0], case[1]), case[2], "%s at %d" % [case[1], case[0]])
	assert_eq(CombatRules.swap_check(progress, registry, 0, 5), CombatResult.Reason.OK)
	assert_eq(CombatRules.swap_check(progress, registry, 0, 6), CombatResult.Reason.LOCKED_POSITION)
	assert_eq(CombatRules.move_check(progress, registry, library, &"spark", 0), CombatResult.Reason.OK)
	assert_eq(CombatRules.move_check(progress, registry, library, &"kindle", 0), CombatResult.Reason.EMPTY_POSITION,
		"an unarranged action is placed, not moved")
	progress.combat_actions = _ids([&"sword_strike", &"lunge"])
	assert_eq(CombatRules.arrangement(progress, registry).size(), 6, "a short save is filled")
	progress.world.pending_entry = EncounterEntry.new()
	assert_eq(CombatRules.availability(progress), CombatResult.Reason.ENCOUNTER_PENDING)


func test_repair_rewrites_only_invalid_explicit_arrangements() -> void:
	var registry := Database.registry
	var fresh := _progress()
	assert_true(CombatRules.repair(fresh, registry).is_empty(), "a never-arranged save keeps the derived default")
	assert_true(fresh.combat_actions.is_empty())
	var valid := _progress()
	valid.combat_actions = _ids([&"kindle", &"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect"])
	assert_true(CombatRules.repair(valid, registry).is_empty(), "a valid explicit arrangement is kept")
	var larger := _progress()
	larger.combat_actions = _ids(SWORD)
	var lines := CombatRules.repair(larger, registry)
	assert_eq(lines.size(), 1)
	assert_true(lines[0].contains("not in a position: kindle"), lines[0])
	assert_eq(larger.combat_actions, _ids(SWORD.slice(0, 6)), "the first six positions are kept")
	var edited := _progress(&"reedbow")
	edited.combat_actions = _ids([&"sword_strike", &"inspect", &"inspect", &"spark"])
	CombatRules.repair(edited, registry)
	assert_eq(edited.combat_actions, CombatRules.arrangement(edited, registry))
	assert_true(CombatRules.repair(edited, registry).is_empty(), "repaired once")


func test_unit_factory_applies_an_arrangement_and_static_loadouts_keep_every_action() -> void:
	var registry := Database.registry
	var balance := registry.balance
	var starter: PartyLoadout = registry.loadouts[&"starter_sword"]
	assert_true(starter.action_ids.is_empty())
	assert_eq(UnitFactory.protagonist_actions(starter, balance), UnitFactory.granted_actions(starter, balance),
		"Practice, the Lab and static loadouts are unchanged")
	var ids := {"weapon": "pilgrims_edge", "companion": "mara", "actions": ["inspect", "kindle", "sword_strike", "inspect", 5, "", "crush"]}
	var arranged := PartyLoadout.from_ids(registry, ids)
	assert_eq(arranged.action_ids, _ids([&"inspect", &"kindle", &"sword_strike", &"crush"]), "strings only, once each")
	assert_eq(UnitFactory.protagonist_actions(arranged, balance).map(func(action: ActionDefinition) -> StringName: return action.id),
		[&"inspect", &"kindle", &"sword_strike"], "in arranged order; an ungranted id executes nothing")
	var bogus := PartyLoadout.from_ids(registry, {"weapon": "pilgrims_edge", "actions": ["crush"]})
	assert_eq(UnitFactory.protagonist_actions(bogus, balance).size(), 7, "nothing valid: every granted action, never none")
	var setup := BattleSetup.from_encounter(arranged, registry.encounters[&"fen_patrol"], Database.library,
		registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	var engine := BattleEngine.new(setup)
	var hero := engine.get_state().protagonist()
	assert_eq(hero.actions.map(func(action: ActionDefinition) -> StringName: return action.id), [&"inspect", &"kindle", &"sword_strike"])
	var offered := ActionRules.options_for(engine.ctx, hero).filter(func(option: ActionOption) -> bool: return option.item_slot < 0)
	assert_eq(offered.size(), 3, "the battle offers exactly the arranged actions")
	var companion := engine.get_state().party(false).filter(func(unit: BattleUnit) -> bool: return unit.is_companion)
	assert_eq(companion[0].actions, UnitFactory.companion_actions(registry.companions[&"mara"], balance),
		"the companion is not arranged")
	assert_eq(engine.get_state().potion_slots.size(), arranged.potions.size(), "supplies stay in their own slots")


func test_readout_shows_positions_locks_candidates_and_passives() -> void:
	var registry := Database.registry
	var progress := _progress()
	var readout := CombatRules.readout(progress, registry, Database.library)
	assert_true(readout.available())
	assert_eq([readout.capacity, readout.positions_total, readout.action_limit], [6, 8, 8])
	assert_eq(readout.positions.size(), 8)
	for index in 8:
		var entry := readout.position(index)
		assert_eq(entry.locked, index >= 6)
		if index >= 6:
			assert_eq([entry.reason, entry.reason_text, entry.action_id], [CombatResult.Reason.LOCKED_POSITION,
				WorldCopy.COMBAT_LOCKED_POSITION, &""])
		else:
			assert_eq(entry.action_id, readout.arranged[index])
	assert_eq(readout.unarranged, _ids([&"kindle"]))
	assert_eq(readout.actions.map(func(entry: Dictionary) -> StringName: return entry.id), SWORD.slice(0, 5))
	assert_eq(readout.magic.map(func(entry: Dictionary) -> StringName: return entry.id), [&"spark", &"kindle"])
	var kindle := readout.candidate(&"kindle")
	assert_eq([kindle.arranged, kindle.position, kindle.selectable, kindle.reason_text],
		[false, -1, true, WorldCopy.COMBAT_UNARRANGED])
	assert_true((kindle.facts as PackedStringArray).has(WorldCopy.COMBAT_UNARRANGED), "not hidden: it says why")
	var strike := readout.candidate(&"sword_strike")
	assert_eq([strike.arranged, strike.position, strike.source], [true, 0, "Pilgrim's Edge"])
	assert_eq(readout.candidate(&"inspect").source, WorldCopy.COMBAT_SOURCE_COMMON)
	assert_eq(readout.candidate(&"spark").source, "The Hollow")
	var passives := readout.skills.filter(func(entry: Dictionary) -> bool: return entry.get("passive", false))
	assert_eq(passives.map(func(entry: Dictionary) -> StringName: return entry.id),
		[&"pilgrims_patience", &"steadfast", &"litany", &"bell_crow"],
		"weapon and garb traits, the active resonance and the familiar: what the battle applies")
	for entry in passives:
		assert_eq([entry.selectable, entry.reason, entry.reason_text], [false, CombatResult.Reason.PASSIVE_SKILL,
			WorldCopy.COMBAT_PASSIVE])
	assert_true(readout.skills.any(func(entry: Dictionary) -> bool:
		return entry.id == &"litany" and String(entry.category) == "Resonance · Litany"),
		"the authored Choir synergy of Pilgrim's Edge and Pilgrim's Coat")
	assert_eq(readout.companion.name, "Mara")
	assert_eq((readout.companion.actions as PackedStringArray).size(),
		UnitFactory.companion_actions(registry.companions[&"mara"], registry.balance).size())
	# Readouts are copies.
	var before := JSON.stringify(progress.to_dict())
	readout.positions.clear()
	readout.candidate(&"sword_strike").name = "changed"
	assert_eq(JSON.stringify(progress.to_dict()), before)
	progress.world.pending_entry = EncounterEntry.new()
	var pending := CombatRules.readout(progress, registry, Database.library)
	assert_eq(pending.reason, CombatResult.Reason.ENCOUNTER_PENDING)
	assert_false(pending.candidate(&"sword_strike").selectable)
