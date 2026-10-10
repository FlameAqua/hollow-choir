extends TestCase
## V0.5 UI New Journey rules (JourneyRules): approved presets and difficulties, typed request
## validation that never guesses a slot, explicit replacement of occupied slots, failed writes and
## the complete fresh journey each preset starts. Pure: an in-memory writer, no save file.

const PRESETS := [&"pilgrims_edge", &"mire_maul", &"reedbow"]

var writes: Array[Dictionary] = []
var failing := false


func before_each() -> void:
	writes.clear()
	failing = false


func _write(slot: int, progress: ProgressState) -> Error:
	if failing:
		return ERR_FILE_CANT_WRITE
	writes.append({"slot": slot, "data": progress.to_dict()})
	return OK


static func _slots(states: Array) -> Array[SaveSlotSummary]:
	var result: Array[SaveSlotSummary] = []
	for index in states.size():
		var entry := SaveSlotSummary.new()
		entry.slot = index
		entry.state = states[index]
		result.append(entry)
	return result


func _create(options: Dictionary, states: Array = [0, 0, 0]) -> JourneyResult:
	return JourneyRules.create(options, Database.registry, WorldDefinition.load_default(), _slots(states), _write)


func test_setup_publishes_presets_difficulties_and_slots() -> void:
	var registry := Database.registry
	var setup := JourneyRules.setup(registry, _slots([1, 0, 2]), Enums.TacticalDifficulty.TACTICIAN)
	assert_eq(setup.difficulties.map(func(entry: Dictionary) -> int: return entry.id), [0, 1, 2])
	for entry in setup.difficulties:
		var profile := registry.difficulty(entry.id)
		assert_eq([entry.name, entry.description], [profile.display_name, profile.description], "authored profile text")
	assert_eq(setup.default_difficulty, Enums.TacticalDifficulty.TACTICIAN, "the player's current Settings tier")
	assert_eq(setup.presets.map(func(entry: Dictionary) -> StringName: return entry.id), PRESETS)
	assert_eq(setup.default_preset, &"pilgrims_edge", "the starter loadout's weapon")
	for entry in setup.presets:
		var weapon: WeaponDefinition = registry.weapons[entry.id]
		assert_eq([entry.name, entry.description, entry.icon_path], [weapon.display_name, weapon.description,
			weapon.icon.resource_path], "approved public facts and icon")
		assert_true((entry.facts as PackedStringArray).size() >= 4, "its actions and trait")
		assert_true(" ".join(entry.details).contains("Mara"), "the rest of the fresh loadout")
	assert_eq(setup.preset(&"reedbow").category, "Bow · Pierce")
	assert_eq(setup.suggested_slot, 1, "the first empty slot")
	assert_false(setup.all_full())
	assert_true(JourneyRules.setup(registry, _slots([1, 2, 3]), 1).all_full())
	assert_eq(JourneyRules.setup(registry, _slots([0, 0, 0]), 9).default_difficulty, Enums.TacticalDifficulty.ADVENTURER,
		"an unknown tier falls back to Adventurer")


func test_every_preset_and_difficulty_starts_a_complete_fresh_journey() -> void:
	var registry := Database.registry
	var fresh := ProgressState.new()
	for preset in PRESETS:
		for tier in Enums.TacticalDifficulty.values():
			writes.clear()
			var result := _create({"difficulty": tier, "preset_id": preset, "slot": 2})
			assert_true(result.ok(), "%s on %d" % [preset, tier])
			assert_eq([result.slot, result.difficulty, result.preset_id, result.changed, result.replaced],
				[2, tier, preset, true, false])
			assert_eq(writes.size(), 1)
			assert_eq(writes[0].slot, 2, "the chosen slot")
			var progress := result.progress
			assert_eq([progress.loadout_weapon, progress.difficulty, progress.starter_preset], [preset, tier, preset])
			assert_eq([progress.world.area, progress.world.anchor], [&"gloamstead", &"town_bell"], "the journey start")
			assert_eq(progress.owned_equipment, fresh.owned_equipment, "nothing beyond a fresh campaign is owned")
			assert_eq(progress.loadout_potions, fresh.loadout_potions)
			assert_eq([progress.loadout_garb, progress.loadout_companion, progress.loadout_familiar],
				[&"pilgrims_coat", &"mara", &"bell_crow"])
			assert_true(progress.crafting_recipes.is_empty() and progress.reward_claims.is_empty() and progress.materials.is_empty())
			assert_true(progress.combat_actions.is_empty(), "the default arrangement derives from the gear")
			var probe := ProgressState.from_dict(progress.to_dict())
			assert_true(PreparationRules.repair_loadout(probe, registry).is_empty(), "a complete, valid starter loadout")
			var restored := ProgressState.from_dict(JSON.parse_string(JSON.stringify(writes[0].data)))
			assert_eq([restored.difficulty, restored.starter_preset, restored.loadout_weapon], [tier, preset, preset],
				"what was written round-trips")
	assert_true(JourneyRules.validate_catalog(registry).is_empty())


func test_requests_are_typed_and_never_guess() -> void:
	var cases := [
		[{"preset_id": "reedbow", "slot": 0}, JourneyResult.Reason.UNKNOWN_DIFFICULTY],
		[{"difficulty": 3, "preset_id": "reedbow", "slot": 0}, JourneyResult.Reason.UNKNOWN_DIFFICULTY],
		[{"difficulty": -1, "preset_id": "reedbow", "slot": 0}, JourneyResult.Reason.UNKNOWN_DIFFICULTY],
		[{"difficulty": "2", "preset_id": "reedbow", "slot": 0}, JourneyResult.Reason.UNKNOWN_DIFFICULTY],
		[{"difficulty": 1.5, "preset_id": "reedbow", "slot": 0}, JourneyResult.Reason.UNKNOWN_DIFFICULTY],
		[{"difficulty": 1, "slot": 0}, JourneyResult.Reason.UNKNOWN_PRESET],
		[{"difficulty": 1, "preset_id": "thunderhead", "slot": 0}, JourneyResult.Reason.UNKNOWN_PRESET],
		[{"difficulty": 1, "preset_id": "storm_salt_charm", "slot": 0}, JourneyResult.Reason.UNKNOWN_PRESET],
		[{"difficulty": 1, "preset_id": 7, "slot": 0}, JourneyResult.Reason.UNKNOWN_PRESET],
		[{"difficulty": 1, "preset_id": "reedbow"}, JourneyResult.Reason.NO_SLOT],
		[{"difficulty": 1, "preset_id": "reedbow", "slot": "1"}, JourneyResult.Reason.NO_SLOT],
		[{"difficulty": 1, "preset_id": "reedbow", "slot": 3}, JourneyResult.Reason.INVALID_SLOT],
		[{"difficulty": 1, "preset_id": "reedbow", "slot": -2}, JourneyResult.Reason.INVALID_SLOT],
	]
	for case: Array in cases:
		var result := _create(case[0])
		assert_eq(result.reason, case[1], JSON.stringify(case[0]))
		assert_eq(result.error, ERR_INVALID_PARAMETER)
		assert_false(result.changed or result.ok())
		assert_null(result.progress)
		assert_false(result.text().is_empty(), "a public reason")
	assert_true(writes.is_empty(), "no rejected request reaches the writer")
	assert_true(_create({"difficulty": 1.0, "preset_id": &"reedbow", "slot": 0.0}).ok(), "JSON-style whole numbers")


func test_occupied_slots_need_an_explicit_replacement() -> void:
	var states := [SaveSlotSummary.State.READY, SaveSlotSummary.State.UNREADABLE, SaveSlotSummary.State.UNSUPPORTED]
	for slot in 3:
		for replace: Variant in [null, false, "yes", 1]:
			var options := {"difficulty": 1, "preset_id": "pilgrims_edge", "slot": slot}
			if replace != null:
				options.replace = replace
			var result := _create(options, states)
			assert_eq(result.reason, JourneyResult.Reason.SLOT_OCCUPIED, "slot %d, replace %s" % [slot, replace])
			assert_eq(result.error, ERR_ALREADY_EXISTS)
			assert_eq(result.text(), WorldCopy.JOURNEY_SLOT_OCCUPIED % (slot + 1))
	assert_true(writes.is_empty(), "an occupied slot (even an unreadable one) is never written without confirmation")
	var replaced := _create({"difficulty": 0, "preset_id": "mire_maul", "slot": 1, "replace": true}, states)
	assert_true(replaced.ok())
	assert_true(replaced.replaced)
	assert_eq(writes.size(), 1)
	var free := _create({"difficulty": 0, "preset_id": "mire_maul", "slot": 0, "replace": true}, [0, 1, 1])
	assert_true(free.ok() and not free.replaced, "a confirmation on a free slot replaces nothing")


func test_a_failed_write_adopts_nothing_and_the_same_request_can_retry() -> void:
	failing = true
	var options := {"difficulty": 2, "preset_id": "reedbow", "slot": 0}
	var failed := _create(options)
	assert_eq([failed.reason, failed.error, failed.changed], [JourneyResult.Reason.WRITE_FAILED, ERR_FILE_CANT_WRITE, false])
	assert_null(failed.progress)
	assert_eq(failed.text(), WorldCopy.JOURNEY_WRITE_FAILED)
	failing = false
	var retry := _create(options)
	assert_true(retry.ok())
	assert_eq(writes.size(), 1, "one successful write")


func test_the_catalog_rejects_presets_a_fresh_campaign_cannot_start() -> void:
	var registry := DefinitionRegistry.load_default()
	assert_true(JourneyRules.validate_catalog(registry).is_empty())
	# The loaded defaults are the cached Resource every registry shares: edit a private copy only.
	var defaults: GameDefaults = registry.defaults.duplicate()
	defaults.journey_presets = registry.defaults.journey_presets.duplicate()
	registry.defaults = defaults
	registry.defaults.journey_presets.append(registry.weapons[&"thunderhead"])
	var problems := JourneyRules.validate_catalog(registry)
	assert_eq(problems.size(), 1)
	assert_true(problems[0].contains("thunderhead") and problems[0].contains("fresh campaign"))
	registry.defaults.journey_presets.clear()
	assert_true(JourneyRules.validate_catalog(registry)[0].contains("at least one"))
