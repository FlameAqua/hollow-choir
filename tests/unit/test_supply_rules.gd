extends TestCase
## Playtest revision, finite supplies (pure rules): brewing spends the price and adds a finite yield
## or is rejected whole; the allowance is min(per-encounter cap, held); a battle starts with exactly
## its captured allowance and the engine counts the doses it used; settlement removes used doses
## once, never past the allowance or below zero; the one-time migration grants a bounded stock and
## never runs again; saved stock is parsed without trusting it; supply positions publish real facts.

const MENDING := &"stillroom.mending_draught"
const FLASK := &"stillroom.fen_water_flask"
const SALVE := &"stillroom.clotting_salve"
const TINCTURE := &"stillroom.focus_tincture"
const KIT := &"forge.first_fitting"

var registry: DefinitionRegistry


func before_each() -> void:
	if registry == null:
		registry = DefinitionRegistry.load_default()


static func _canonical(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true)


## A campaign save of this build: starter supplies granted and the migration marked.
func _fresh() -> ProgressState:
	var progress := ProgressState.new()
	SupplyRules.migrate(progress, registry)
	return progress


func _battle(ids: Dictionary) -> BattleDriver:
	var setup := BattleSetup.from_encounter(PartyLoadout.from_ids(registry, ids), registry.encounters[&"toy_training"],
		Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER),
		registry.assist(Enums.ExecutionAssist.STANDARD), 11)
	return BattleDriver.new(setup)


func test_a_brew_spends_its_price_and_adds_a_finite_yield_or_changes_nothing() -> void:
	var progress := _fresh()
	assert_eq([progress.supply_count(&"mending_draught"), progress.supply_count(&"clotting_salve")], [4, 0])
	# Checks in order: recipe, a potion recipe, mastery, materials, overflow.
	assert_eq(SupplyRules.brew_check(progress, registry, &"stillroom.nothing"), CraftingResult.Reason.UNKNOWN_RECIPE)
	assert_eq(SupplyRules.brew_check(progress, registry, KIT), CraftingResult.Reason.NOT_BREWABLE)
	assert_eq(SupplyRules.brew_check(progress, registry, &"forge.merciful_grip"), CraftingResult.Reason.NOT_BREWABLE)
	assert_eq(SupplyRules.brew_check(progress, registry, SALVE), CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	progress.materials[&"bog_iron"] = 3
	assert_eq(SupplyRules.brew_check(progress, registry, SALVE), CraftingResult.Reason.OK)
	assert_eq(SupplyRules.brew_check(progress, registry, TINCTURE), CraftingResult.Reason.INSUFFICIENT_MATERIALS,
		"Bog Iron never pays a Storm Salt price")
	# One brew: the whole price, the authored yield, nothing prepared.
	var potions_before := progress.loadout_potions.duplicate()
	var outcome := SupplyRules.brew(progress, registry.recipes[SALVE])
	assert_eq([progress.material_count(&"bog_iron"), progress.supply_count(&"clotting_salve")], [2, 2])
	assert_eq([(outcome.spent as Array).size(), outcome.spent[0].id, outcome.spent[0].count, outcome.spent[0].total],
		[1, &"bog_iron", 1, 2])
	assert_eq(outcome.produced, [{"id": &"clotting_salve", "name": "Clotting Salve", "icon_path": "", "count": 2, "total": 2}] as Array[Dictionary])
	assert_eq(progress.loadout_potions, potions_before, "brewing never prepares a position")
	assert_false(progress.has_recipe(SALVE), "a brew is not an unlock")
	# Repeatable: each brew pays again and stacks.
	SupplyRules.brew(progress, registry.recipes[SALVE])
	SupplyRules.brew(progress, registry.recipes[MENDING])
	assert_eq([progress.material_count(&"bog_iron"), progress.supply_count(&"clotting_salve"),
		progress.supply_count(&"mending_draught")], [0, 4, 6])
	assert_false(progress.materials.has(&"bog_iron"), "a spent stack leaves no zero entry")
	assert_eq(SupplyRules.brew_check(progress, registry, SALVE), CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	# Overflow rejects the whole brew: nothing is clipped and nothing is spent.
	progress.materials[&"bog_iron"] = 5
	progress.set_supply(&"clotting_salve", PotionDefinition.MAX_STOCK - 1)
	assert_eq(SupplyRules.brew_check(progress, registry, SALVE), CraftingResult.Reason.STOCK_OVERFLOW)
	progress.set_supply(&"clotting_salve", PotionDefinition.MAX_STOCK - 2)
	assert_eq(SupplyRules.brew_check(progress, registry, SALVE), CraftingResult.Reason.OK, "exactly to the ceiling is fine")
	SupplyRules.brew(progress, registry.recipes[SALVE])
	assert_eq(progress.supply_count(&"clotting_salve"), PotionDefinition.MAX_STOCK)
	# A mastery-gated recipe is checked before its price (the gate is existing recipe data).
	# (A shallow duplicate shares its arrays with the shipped recipe: give the fixture its own.)
	var gated: RecipeDefinition = registry.recipes[SALVE].duplicate()
	gated.mastery_points = 2
	var gate_weapons: Array[WeaponDefinition] = [registry.weapons[&"reedbow"]]
	gated.mastery_weapons = gate_weapons
	assert_empty(registry.recipes[SALVE].mastery_weapons, "the shipped recipe is untouched")
	var custom := DefinitionRegistry.load_default()
	custom.recipes = custom.recipes.duplicate()
	custom.recipes[SALVE] = gated
	var poor := _fresh()
	assert_eq(SupplyRules.brew_check(poor, custom, SALVE), CraftingResult.Reason.MASTERY_REQUIRED)
	poor.weapon_mastery[&"reedbow"] = 2
	assert_eq(SupplyRules.brew_check(poor, custom, SALVE), CraftingResult.Reason.INSUFFICIENT_MATERIALS)


func test_the_allowance_is_the_cap_or_the_held_stock_whichever_is_smaller() -> void:
	var progress := _fresh()
	assert_eq(progress.loadout_potions, [&"mending_draught", &"fen_water_flask"] as Array[StringName])
	assert_eq(SupplyRules.allowance(progress, registry), [2, 2] as Array[int], "cap 2 of 4 held")
	progress.set_supply(&"mending_draught", 1)
	progress.set_supply(&"fen_water_flask", 0)
	assert_eq(SupplyRules.allowance(progress, registry), [1, 0] as Array[int], "never refilled above the stock")
	progress.set_supply(&"mending_draught", 99)
	assert_eq(SupplyRules.allowance(progress, registry), [2, 0] as Array[int], "never above the per-encounter cap")
	progress.loadout_potions = [&"focus_tincture", &"no_such_potion"]
	progress.set_supply(&"focus_tincture", 5)
	assert_eq(SupplyRules.allowance(progress, registry), [1, 0] as Array[int], "one number per saved id; unknown ids carry none")
	# The captured ids carry it, in the saved order, for the encounter entry.
	var ids := PreparationRules.battle_ids(progress, registry)
	assert_eq([ids.potions, ids.potion_charges], [["focus_tincture", "no_such_potion"], [1, 0]])
	# Stock uses no equipment bag cell and no action position.
	assert_eq(PreparationRules.inventory(progress, registry).equipment_capacity, 10)
	assert_eq(PreparationRules.action_counts(PreparationRules.battle_ids(_fresh(), registry), registry).protagonist, 6)


func test_a_battle_starts_with_its_allowance_and_counts_the_doses_it_used() -> void:
	var progress := _fresh()
	progress.set_supply(&"mending_draught", 1)
	var ids := PreparationRules.battle_ids(progress, registry)
	assert_eq(ids.potion_charges, [1, 2])
	var driver := _battle(ids)
	var request := driver.to_player_turn()
	var slots := driver.engine.get_state().potion_slots
	assert_eq([slots.size(), slots[0].potion.id, slots[0].charges, slots[1].potion.id, slots[1].charges],
		[2, &"mending_draught", 1, &"fen_water_flask", 2], "the captured allowance, not the authored charges")
	# The one Mending Draught can be used once; then that slot is empty for this battle.
	assert_eq(driver.act(&"use_mending_draught", driver.hero().uid), OK)
	request = driver.to_player_turn()
	assert_eq(driver.engine.get_state().potion_slots[0].charges, 0)
	var empty := request.options.filter(func(option: ActionOption) -> bool: return option.action.id == &"use_mending_draught")
	assert_eq([empty.size(), empty[0].legal, empty[0].reason], [1, false, "Empty"])
	assert_eq(driver.act(&"use_fen_water_flask"), OK)
	driver.to_player_turn()
	var result := driver.engine.build_result()
	assert_eq(result.item_uses, {&"mending_draught": 1, &"fen_water_flask": 1} as Dictionary[StringName, int],
		"counted by the engine as each item action resolves")
	assert_eq(driver.count_of(BattleEvent.Type.ITEM_USED), 2)
	# A loadout without a captured allowance (Practice, the Lab, static loadouts, older entries)
	# keeps the potions' authored charges and never reads the stock.
	var static_ids := progress.loadout_ids()
	assert_false(static_ids.has("potion_charges"))
	var practice := _battle(static_ids)
	practice.to_player_turn()
	assert_eq(practice.engine.get_state().potion_slots[0].charges, 2, "authored charges, whatever the save holds")
	for loadout: PartyLoadout in registry.defaults.practice_loadouts:
		assert_empty(loadout.potion_charges, "%s: Practice never carries campaign stock" % loadout.id)
		for index in loadout.potions.size():
			assert_eq(loadout.charges_for(index), loadout.potions[index].charges)
	# A zero allowance is a real, empty slot (the prepared choice survives an empty stock).
	progress.set_supply(&"mending_draught", 0)
	var dry := _battle(PreparationRules.battle_ids(progress, registry))
	dry.to_player_turn()
	assert_eq([dry.engine.get_state().potion_slots[0].potion.id, dry.engine.get_state().potion_slots[0].charges],
		[&"mending_draught", 0])
	# An allowance above the cap (an edited entry) is clamped to the cap.
	var edited := PreparationRules.battle_ids(_fresh(), registry)
	edited.potion_charges = [50, -3]
	var loadout := PartyLoadout.from_ids(registry, edited)
	assert_eq([loadout.charges_for(0), loadout.charges_for(1)], [2, 0])


func test_settlement_removes_used_doses_once_within_the_allowance() -> void:
	var progress := _fresh()
	var captured := PreparationRules.battle_ids(progress, registry)
	# Two Mending Draughts and one Flask used: exactly that leaves the stock.
	var consumed := SupplyRules.settle(progress, registry, captured, {&"mending_draught": 2, &"fen_water_flask": 1})
	assert_eq([progress.supply_count(&"mending_draught"), progress.supply_count(&"fen_water_flask")], [2, 3])
	assert_eq(consumed.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]),
		[[&"fen_water_flask", 1, 3], [&"mending_draught", 2, 2]], "by potion id")
	# Nothing used: nothing settles.
	assert_empty(SupplyRules.settle(progress, registry, captured, {}))
	# A claimed use beyond the captured allowance is capped by it; beyond the stock, by the stock.
	var greedy := _fresh()
	SupplyRules.settle(greedy, registry, PreparationRules.battle_ids(greedy, registry), {&"mending_draught": 9})
	assert_eq(greedy.supply_count(&"mending_draught"), 2, "never more than the two the entry allowed")
	var thin := _fresh()
	var thin_ids := PreparationRules.battle_ids(thin, registry)
	thin.set_supply(&"mending_draught", 1)
	SupplyRules.settle(thin, registry, thin_ids, {&"mending_draught": 2})
	assert_eq(thin.supply_count(&"mending_draught"), 0, "never below zero")
	assert_false(thin.consumables.has(&"mending_draught"), "an emptied stock leaves no zero entry")
	# A potion that was not prepared in the entry settles nothing, whatever the result claims.
	var other := _fresh()
	other.set_supply(&"focus_tincture", 3)
	assert_empty(SupplyRules.settle(other, registry, PreparationRules.battle_ids(other, registry), {&"focus_tincture": 1}))
	assert_eq(other.supply_count(&"focus_tincture"), 3)
	# An entry captured before the revision has no allowance: it never settles.
	var legacy := _fresh()
	assert_empty(SupplyRules.settle(legacy, registry, legacy.loadout_ids(), {&"mending_draught": 2}))
	assert_eq(legacy.supply_count(&"mending_draught"), 4)
	for broken: Variant in [{"potions": ["mending_draught"], "potion_charges": [2, 2]}, {"potions": "x", "potion_charges": 3}]:
		assert_empty(SupplyRules.settle(legacy, registry, broken, {&"mending_draught": 1}), "a malformed allowance settles nothing")


func test_the_migration_grants_a_bounded_stock_exactly_once() -> void:
	# A save from before the revision: both Stillroom recipes owned, starters prepared.
	var old := ProgressState.new()
	old.add_recipe(SALVE)
	old.add_recipe(TINCTURE)
	old.add_recipe(KIT)
	var data := JSON.parse_string(JSON.stringify(old.to_dict())) as Dictionary
	data.erase("migrations")
	(data.inventory as Dictionary).erase("consumables")
	var loaded := ProgressState.from_dict(data)
	assert_empty(loaded.consumables)
	assert_false(loaded.has_migration(SupplyRules.MIGRATION))
	var lines := SupplyRules.migrate(loaded, registry)
	assert_eq(loaded.consumables, {&"mending_draught": 4, &"fen_water_flask": 4, &"clotting_salve": 2, &"focus_tincture": 2}
		as Dictionary[StringName, int], "starters get their starter batch; each owned recipe one brew's yield")
	assert_eq(loaded.migrations, [SupplyRules.MIGRATION] as Array[StringName])
	assert_eq(lines.size(), 5, "one line per grant and the marker")
	assert_true(loaded.has_recipe(SALVE), "legacy recipe ids stay in the save, inert")
	# Used down to nothing, saved and loaded again: never granted a second time.
	loaded.consumables.clear()
	var reloaded := ProgressState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	assert_empty(SupplyRules.migrate(reloaded, registry), "the durable marker, not the stock, decides")
	assert_empty(reloaded.consumables, "a legitimately exhausted stock stays exhausted")
	# A potion that was only prepared (grandfathered without its recipe) still gets one batch.
	var prepared := ProgressState.new()
	prepared.loadout_potions = [&"clotting_salve", &"mending_draught"]
	SupplyRules.migrate(prepared, registry)
	assert_eq(prepared.consumables, {&"mending_draught": 4, &"fen_water_flask": 4, &"clotting_salve": 2}
		as Dictionary[StringName, int], "a starter that is prepared gets its starter batch only, never an extra brew")
	# A save that owned nothing extra gets the starters only.
	var plain := ProgressState.new()
	SupplyRules.migrate(plain, registry)
	assert_eq(plain.consumables, {&"mending_draught": 4, &"fen_water_flask": 4} as Dictionary[StringName, int])
	# A new journey is created with the same starter batch and the marker already set.
	var journey := JourneyRules.fresh_progress(WorldDefinition.load_default(), &"mire_maul", Enums.TacticalDifficulty.STORY, registry)
	assert_eq(journey.consumables, plain.consumables)
	assert_true(journey.has_migration(SupplyRules.MIGRATION))
	assert_empty(SupplyRules.migrate(journey, registry), "world entry grants nothing more")
	# Existing stock (an edited save) is topped up, never past the ceiling.
	var rich := ProgressState.new()
	rich.consumables[&"mending_draught"] = 97
	SupplyRules.migrate(rich, registry)
	assert_eq(rich.supply_count(&"mending_draught"), PotionDefinition.MAX_STOCK)


func test_saved_stock_and_markers_are_parsed_without_trusting_them() -> void:
	var data := ProgressState.new().to_dict()
	data.inventory.consumables = {"mending_draught": 3, "fen_water_flask": 0, "clotting_salve": -2, "focus_tincture": 2.5,
		"future_tonic": 7, "": 4, "big": 5000, "text": "many", "flag": true, "nan": NAN, "whole_float": 6.0}
	data.migrations = [SupplyRules.MIGRATION, 4, null, "", "future.migration", String(SupplyRules.MIGRATION)]
	var state := ProgressState.from_dict(data)
	assert_eq(state.consumables, {&"mending_draught": 3, &"future_tonic": 7, &"big": PotionDefinition.MAX_STOCK,
		&"whole_float": 6} as Dictionary[StringName, int],
		"whole numbers of at least 1, capped; unknown ids kept and inert")
	assert_eq(state.migrations, [&"future.migration", SupplyRules.MIGRATION] as Array[StringName], "strings, unique, sorted")
	var round_trip := ProgressState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(_canonical(round_trip.to_dict()), _canonical(state.to_dict()), "sanitized data round-trips through JSON")
	for wrong: Variant in [5, "many", ["mending_draught"], null]:
		var broken := ProgressState.new().to_dict()
		broken.inventory.consumables = wrong
		broken.migrations = wrong if typeof(wrong) != TYPE_ARRAY else {"supplies.finite_stock.v1": true}
		var parsed := ProgressState.from_dict(broken)
		assert_empty(parsed.consumables)
		assert_empty(parsed.migrations, "only a list of ids is a migration list")
	# An unknown potion id is never shown, prepared or used.
	assert_empty(SupplyRules.stock(state, registry).filter(func(entry: Dictionary) -> bool: return entry.id == &"future_tonic"))
	assert_eq(CraftingRules.potion_check(state, registry, 0, &"future_tonic"), CraftingResult.Reason.UNKNOWN_POTION)
	# The selected familiar passive is a plain id as well.
	var passive := ProgressState.new().to_dict()
	passive.loadout.familiar_passive = 7
	assert_eq(ProgressState.from_dict(passive).loadout_familiar_passive, &"")


func test_preparing_needs_a_held_dose_and_keeps_a_depleted_choice() -> void:
	var progress := _fresh()
	# Held potions can be prepared; a potion with no dose cannot be newly prepared.
	assert_eq(CraftingRules.potion_check(progress, registry, 0, &"clotting_salve"), CraftingResult.Reason.NO_STOCK)
	progress.set_supply(&"clotting_salve", 1)
	assert_eq(CraftingRules.potion_check(progress, registry, 0, &"clotting_salve"), CraftingResult.Reason.OK)
	assert_eq(CraftingRules.potion_check(progress, registry, 0, &"fen_water_flask"), CraftingResult.Reason.DUPLICATE_POTION,
		"the duplicate rule is unchanged")
	assert_eq(CraftingRules.potion_check(progress, registry, 2, &"clotting_salve"), CraftingResult.Reason.INVALID_POTION_SLOT,
		"positions 2 and 3 are shown but locked")
	assert_eq(CraftingRules.potion_check(progress, registry, -1, &"clotting_salve"), CraftingResult.Reason.INVALID_POTION_SLOT)
	assert_eq(CraftingRules.potion_check(progress, registry, 0, &"no_such_potion"), CraftingResult.Reason.UNKNOWN_POTION)
	# The prepared choice stays valid at zero doses (re-choosing it is the accepted no-op).
	progress.set_supply(&"mending_draught", 0)
	assert_eq(CraftingRules.potion_check(progress, registry, 0, &"mending_draught"), CraftingResult.Reason.OK)
	assert_eq(progress.loadout_potions[0], &"mending_draught")
	assert_empty(CraftingRules.repair(progress, registry), "a depleted prepared potion is not a repair")
	# Positions: four shown, two usable, with real facts for each state.
	var slots := SupplyRules.slot_readouts(progress, registry, CraftingResult.Reason.OK)
	assert_eq([slots.size(), SupplyRules.POSITIONS, SupplyRules.capacity()], [4, 4, 2])
	assert_eq(slots.map(func(slot: PotionSlotReadout) -> int: return slot.state), [PotionSlotReadout.State.DEPLETED,
		PotionSlotReadout.State.PREPARED, PotionSlotReadout.State.LOCKED, PotionSlotReadout.State.LOCKED])
	assert_eq(slots.map(func(slot: PotionSlotReadout) -> bool: return slot.locked), [false, false, true, true])
	var flask := slots[1]
	assert_eq([flask.potion_id, flask.held, flask.cap, flask.usable], [&"fen_water_flask", 4, 2, 2])
	assert_eq([flask.inspection.title, flask.inspection.description],
		["Fen Water Flask", registry.potions[&"fen_water_flask"].description], "the item's own effect text, not a hint")
	# The facts carry the real numbers in WorldCopy's wording.
	var held_line := WorldCopy.SUPPLY_FACT_HELD
	var usable_line := WorldCopy.SUPPLY_FACT_USABLE
	assert_eq(Array(flask.inspection.facts), [held_line % 4, usable_line % [2, 2]])
	var depleted := slots[0]
	assert_eq([depleted.potion_id, depleted.held, depleted.usable], [&"mending_draught", 0, 0])
	assert_eq(Array(depleted.inspection.facts), [held_line % 0, usable_line % [0, 2]])
	assert_eq([slots[2].potion_id, slots[2].reason, slots[2].options.size()], [&"", CraftingResult.Reason.INVALID_POTION_SLOT, 0])
	assert_false(String(slots[2].inspection.title).is_empty())
	# The popup list: only what the save holds, plus what the position already holds.
	assert_eq(depleted.choices.map(func(entry: Dictionary) -> StringName: return entry.id),
		[&"mending_draught", &"fen_water_flask", &"clotting_salve"] as Array, "held or prepared here; no Focus Tincture")
	assert_eq(depleted.options.size(), 4, "the complete list stays available")
	var salve: Dictionary = depleted.option(&"clotting_salve")
	assert_eq([salve.held, salve.cap, salve.usable, salve.selectable, salve.recipe_id], [1, 1, 1, true, SALVE])
	var tincture: Dictionary = depleted.option(&"focus_tincture")
	assert_eq([tincture.held, tincture.selectable, tincture.reason], [0, false, CraftingResult.Reason.NO_STOCK])
	# During an encounter nothing is selectable, and the readout says why.
	var held_back := SupplyRules.slot_readout(progress, registry, 1, CraftingResult.Reason.ENCOUNTER_PENDING)
	assert_eq(held_back.reason, CraftingResult.Reason.ENCOUNTER_PENDING)
	assert_true(held_back.options.all(func(entry: Dictionary) -> bool: return not entry.selectable))
	# The stock list: held or prepared potions, with the position that holds each.
	assert_eq(SupplyRules.stock(progress, registry).map(func(entry: Dictionary) -> Array: return [entry.id, entry.held, entry.prepared_slot]),
		[[&"mending_draught", 0, 0], [&"fen_water_flask", 4, 1], [&"clotting_salve", 1, -1]])
