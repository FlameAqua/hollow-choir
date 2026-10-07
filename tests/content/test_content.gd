extends TestCase
## Validates every authored definition in res://data and checks the vertical-slice scope from the
## GDD. Fails the build on any invalid or dangling content.

var registry: DefinitionRegistry


func before_each() -> void:
	if registry == null:
		registry = DefinitionRegistry.load_default()


func test_all_definitions_validate() -> void:
	var problems := registry.validate()
	for problem in problems:
		fail(problem)
	assert_empty(problems)


func test_vertical_slice_scope() -> void:
	var families := {}
	for weapon: WeaponDefinition in registry.weapons.values():
		families[weapon.family] = true
	assert_eq(families.size(), 3, "Sword, Hammer, Bow only")
	for family in [Enums.WeaponFamily.SWORD, Enums.WeaponFamily.HAMMER, Enums.WeaponFamily.BOW]:
		assert_true(families.has(family), "has %s" % EnumText.family(family))
	var roles := {}
	var elites := 0
	var bosses := 0
	for enemy: EnemyDefinition in registry.enemies.values():
		match enemy.tier:
			Enums.EnemyTier.ELITE:
				elites += 1
			Enums.EnemyTier.BOSS:
				bosses += 1
			_:
				if enemy.id != &"straw_penitent":
					roles[enemy.role] = true
	assert_eq(roles.size(), 6, "six normal archetypes covering all six roles")
	assert_eq(elites, 1, "one elite")
	assert_eq(bosses, 1, "one boss")
	assert_eq(registry.companions.size(), 1, "one companion")
	assert_eq(registry.familiars.size(), 2, "two familiars")
	assert_eq(registry.conditions.size(), 2, "two battlefield conditions")
	assert_eq(registry.statuses.size(), 4, "Burn, Wet, Shock, Bleed")
	assert_lte(registry.potions.size(), 6, "six potion recipes maximum")


func test_every_enemy_action_is_readable() -> void:
	for enemy: EnemyDefinition in registry.enemies.values():
		var actions: Array = enemy.actions.duplicate()
		for phase in enemy.phases:
			actions.append_array(phase.actions)
		for action: EnemyActionDefinition in actions:
			assert_false(action.telegraph_text.is_empty(), "%s.%s has a telegraph" % [enemy.id, action.id])
			if action.deals_damage() and action.targets_enemies():
				assert_true(action.is_reactable() or action.telegraph_text.contains("cannot"),
					"%s.%s: unreactable attacks must say so" % [enemy.id, action.id])
			if not action.can_parry and action.deals_damage() and action.targets_enemies():
				assert_true(action.telegraph_text.to_lower().contains("parr") or action.telegraph_text.to_lower().contains("evaded"),
					"%s.%s: say in the telegraph that it cannot be Parried" % [enemy.id, action.id])


func test_boss_tests_the_required_systems() -> void:
	var boss: EnemyDefinition = registry.enemies[&"mirebell_cantor"]
	assert_gte(boss.phases.size(), 3, "phased boss")
	var adds_condition := false
	var has_channel := false
	var has_opening := false
	var applies_status := false
	for phase in boss.phases:
		if not phase.add_conditions.is_empty():
			adds_condition = true
		for action in phase.actions:
			if action.channel_turns > 0 and action.interruptible:
				has_channel = true
			if action.has_tag(Enums.ActionTag.OPENING) and action.can_parry:
				has_opening = true
			if not action.applied_statuses().is_empty():
				applies_status = true
	assert_true(adds_condition, "environment changes")
	assert_true(has_channel, "a channel the player must Stagger")
	assert_true(has_opening, "a high-risk parry opportunity")
	assert_true(applies_status, "a status interaction")
	assert_true(boss.has_weak_point, "weak point for the bow")


func test_rarity_is_not_raw_power() -> void:
	for weapon: WeaponDefinition in registry.weapons.values():
		for other: WeaponDefinition in registry.weapons.values():
			if weapon.family == other.family and int(other.rarity) > int(weapon.rarity):
				assert_lte(other.base_power, weapon.base_power * 1.05,
					"%s (%s) should not out-muscle %s" % [other.id, EnumText.rarity(other.rarity), weapon.id])


func test_loadouts_build_valid_battles() -> void:
	var library := registry.make_library()
	for loadout: PartyLoadout in registry.loadouts.values():
		for encounter: EncounterDefinition in registry.encounters.values():
			var setup := BattleSetup.from_encounter(loadout, encounter, library,
				registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD))
			assert_empty(setup.validate(), "%s vs %s" % [loadout.id, encounter.id])


func test_every_encounter_finishes_under_simulation() -> void:
	var library := registry.make_library()
	var loadout: PartyLoadout = registry.loadouts[&"starter_sword"]
	for encounter: EncounterDefinition in registry.encounters.values():
		for tier in Enums.TacticalDifficulty.values():
			var setup := BattleSetup.from_encounter(loadout, encounter, library, registry.difficulty(tier),
				registry.assist(Enums.ExecutionAssist.STANDARD), 11)
			var metrics := SimulationRunner.run_battle(setup, registry.skill(Enums.SimulatedExecution.MIXED))
			assert_ne(metrics.outcome, Enums.BattleOutcome.NONE, "%s (%s) finishes" % [encounter.id, EnumText.difficulty(tier)])
			assert_ne(metrics.outcome, Enums.BattleOutcome.TIMEOUT, "%s (%s) does not time out" % [encounter.id, EnumText.difficulty(tier)])


func test_random_policy_fuzz_never_breaks_the_engine() -> void:
	var library := registry.make_library()
	for loadout: PartyLoadout in registry.loadouts.values():
		var encounter: EncounterDefinition = registry.encounters[&"briarfen_gauntlet"]
		var setup := BattleSetup.from_encounter(loadout, encounter, library,
			registry.difficulty(Enums.TacticalDifficulty.TACTICIAN), registry.assist(Enums.ExecutionAssist.STANDARD), 5)
		var metrics := SimulationRunner.run_battle(setup, registry.skill(Enums.SimulatedExecution.MIXED),
			PartyAutopilot.Policy.RANDOM)
		assert_ne(metrics.outcome, Enums.BattleOutcome.NONE, "%s random play finishes" % loadout.id)
