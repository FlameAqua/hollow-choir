extends TestCase
## Playtest revision, the unified Loadout readout (pure rules): every granted action is attributed
## to exactly one truthful source (three cells per gear strip, the rest in Core), capacities and locks
## are the backend's (six of eight positions, two of four supplies, 10 or 15 of 20 bag cells), the
## ingredient catalog lists every approved material including zero, and passives, mastery and the
## familiar's passive are separate facts.

var registry: DefinitionRegistry


func before_each() -> void:
	if registry == null:
		registry = DefinitionRegistry.load_default()


func _fresh() -> ProgressState:
	var progress := ProgressState.new()
	SupplyRules.migrate(progress, registry)
	return progress


static func _ids(entries: Array) -> Array:
	return entries.map(func(entry: Dictionary) -> StringName: return entry.id)


static func _action_ids(actions: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for action: ActionDefinition in actions:
		ids.append(action.id)
	return ids


func test_every_granted_action_has_one_truthful_source() -> void:
	for weapon_id: StringName in [&"pilgrims_edge", &"mire_maul", &"reedbow"]:
		var progress := _fresh()
		progress.loadout_weapon = weapon_id
		var readout := LoadoutRules.readout(progress, registry, Database.library)
		var weapon: WeaponDefinition = registry.weapons[weapon_id]
		var gear := readout.gear_slot(Enums.EquipSlot.WEAPON)
		assert_eq([gear.source_id, gear.equipped_id, gear.strip_cells], [LoadoutRules.SOURCE_WEAPON, weapon_id, 3])
		# The weapon strip: its basic attack and techniques, nothing else, never more than three.
		var expected := [weapon.basic_attack.id]
		for technique in weapon.techniques:
			expected.append(technique.id)
		assert_eq(_ids(gear.actions), expected.slice(0, 3), "%s strip" % weapon_id)
		assert_eq(gear.actions.map(func(entry: Dictionary) -> StringName: return entry.origin).slice(0, 1), [LoadoutRules.ORIGIN_BASIC])
		assert_true(gear.actions.all(func(entry: Dictionary) -> bool:
			return entry.source_id == LoadoutRules.SOURCE_WEAPON and entry.origin_name == weapon.display_name))
		# The stance is not truncated away: it is in Core with the weapon as its origin.
		var stance: Dictionary = readout.action(weapon.guard_action.id)
		assert_eq([stance.source_id, stance.origin, stance.origin_name],
			[LoadoutRules.SOURCE_CORE, LoadoutRules.ORIGIN_STANCE, weapon.display_name], "%s stance" % weapon_id)
		# Innate magic belongs to the Hollow, never to an empty relic; Inspect is the shared action.
		for spell: StringName in [&"spark", &"kindle"]:
			var fact: Dictionary = readout.action(spell)
			assert_eq([fact.source_id, fact.origin, fact.origin_name],
				[LoadoutRules.SOURCE_CORE, LoadoutRules.ORIGIN_INNATE, "The Hollow"], String(spell))
		var inspect: Dictionary = readout.action(&"inspect")
		assert_eq([inspect.source_id, inspect.origin], [LoadoutRules.SOURCE_CORE, LoadoutRules.ORIGIN_INSPECT])
		assert_eq(_ids(readout.core), [weapon.guard_action.id, &"spark", &"kindle", &"inspect"], "%s core" % weapon_id)
		for slot: Enums.EquipSlot in [Enums.EquipSlot.GARB, Enums.EquipSlot.CHARM, Enums.EquipSlot.RELIC]:
			assert_empty(readout.gear_slot(slot).actions, "current armor grants no action; none is invented")
		# Exactly the granted actions, each once.
		var granted := UnitFactory.granted_actions(PartyLoadout.from_ids(registry, progress.loadout_ids()), registry.balance)
		var listed := _ids(readout.all_actions())
		assert_eq(listed.size(), granted.size())
		for action in granted:
			assert_eq(listed.count(action.id), 1, "%s is listed exactly once" % action.id)
		assert_eq(granted.size(), 7, "the existing seven actions are all still there")


func test_overflow_and_granted_actions_are_attributed_not_dropped() -> void:
	# A fixture weapon with three techniques and a charm that grants an action. A shallow
	# Resource.duplicate() shares its arrays with the shipped definition, so each fixture gets a new
	# array: writing into the duplicate's own array would change the real sword and charm for every
	# later test.
	var custom := DefinitionRegistry.load_default()
	custom.weapons = custom.weapons.duplicate()
	custom.armor = custom.armor.duplicate()
	var shipped_techniques: Array[StringName] = _action_ids(registry.weapons[&"pilgrims_edge"].techniques)
	var shipped_grants: Array[StringName] = _action_ids(registry.armor[&"storm_salt_charm"].granted_actions)
	var blade: WeaponDefinition = custom.weapons[&"pilgrims_edge"].duplicate()
	blade.id = &"test_blade"
	blade.display_name = "Test Blade"
	var techniques: Array[ActionDefinition] = [registry.actions[&"lunge"], registry.actions[&"arc_cleave"],
		registry.actions[&"earthsplitter"]]
	blade.techniques = techniques
	custom.weapons[blade.id] = blade
	var charm: ArmorDefinition = custom.armor[&"storm_salt_charm"].duplicate()
	charm.id = &"test_charm"
	charm.display_name = "Test Charm"
	var grants: Array[ActionDefinition] = [registry.actions[&"shockwave"]]
	charm.granted_actions = grants
	custom.armor[charm.id] = charm
	assert_eq(_action_ids(registry.weapons[&"pilgrims_edge"].techniques), shipped_techniques, "the shipped sword is untouched")
	assert_eq(_action_ids(registry.armor[&"storm_salt_charm"].granted_actions), shipped_grants, "and the shipped charm")
	var progress := _fresh()
	progress.owned_equipment.append_array([&"test_blade", &"test_charm"])
	progress.loadout_weapon = &"test_blade"
	progress.loadout_charm = &"test_charm"
	var loadout := PartyLoadout.from_ids(custom, progress.loadout_ids())
	var sources := LoadoutRules.sources(loadout, custom.balance)
	var weapon_strip: Array = sources[LoadoutRules.SOURCE_WEAPON]
	assert_eq(weapon_strip.map(func(entry: Dictionary) -> StringName: return (entry.action as ActionDefinition).id),
		[&"sword_strike", &"lunge", &"arc_cleave"], "three cells")
	assert_eq((sources[LoadoutRules.SOURCE_CHARM] as Array).map(func(entry: Dictionary) -> StringName: return (entry.action as ActionDefinition).id),
		[&"shockwave"])
	var core: Array = sources[LoadoutRules.SOURCE_CORE]
	var overflow := core.filter(func(entry: Dictionary) -> bool: return (entry.action as ActionDefinition).id == &"earthsplitter")
	assert_eq(overflow.size(), 1, "the fourth weapon action is listed in Core, not dropped")
	assert_eq([overflow[0].origin, overflow[0].origin_name], [LoadoutRules.ORIGIN_TECHNIQUE, "Test Blade"], "with its true origin")
	var owners := LoadoutRules.source_ids(loadout, custom.balance)
	assert_eq([owners[&"earthsplitter"], owners[&"shockwave"], owners[&"sword_strike"], owners[&"spark"]],
		[LoadoutRules.SOURCE_CORE, LoadoutRules.SOURCE_CHARM, LoadoutRules.SOURCE_WEAPON, LoadoutRules.SOURCE_CORE])
	assert_eq(owners.size(), UnitFactory.granted_actions(loadout, custom.balance).size(), "every granted action, once")


func test_positions_supplies_and_bag_report_the_backends_capacities() -> void:
	var progress := _fresh()
	var readout := LoadoutRules.readout(progress, registry, Database.library)
	assert_true(readout.available())
	# Eight positions shown, six usable, two locked; the arrangement is the saved one.
	assert_eq([readout.positions.size(), readout.capacity, readout.positions_total], [8, 6, 8])
	assert_eq(readout.positions.map(func(position: Dictionary) -> bool: return position.locked),
		[false, false, false, false, false, false, true, true])
	assert_eq(readout.arranged, CombatRules.arrangement(progress, registry))
	assert_eq(readout.positions.slice(0, 6).map(func(position: Dictionary) -> StringName: return position.action_id), Array(readout.arranged))
	assert_eq(readout.positions.slice(0, 6).map(func(position: Dictionary) -> StringName: return position.source_id),
		[LoadoutRules.SOURCE_WEAPON, LoadoutRules.SOURCE_WEAPON, LoadoutRules.SOURCE_WEAPON, LoadoutRules.SOURCE_CORE,
		LoadoutRules.SOURCE_CORE, LoadoutRules.SOURCE_CORE], "each position names its action's source")
	for locked: Dictionary in readout.positions.slice(6):
		assert_eq([locked.action_id, locked.source_id, locked.reason], [&"", &"", CombatResult.Reason.LOCKED_POSITION])
		assert_false(String(locked.reason_text).is_empty())
	assert_eq(readout.unarranged, [&"kindle"] as Array[StringName], "the one action outside the six")
	var kindle: Dictionary = readout.action(&"kindle")
	assert_eq([kindle.arranged, kindle.position, kindle.selectable], [false, -1, true])
	var strike: Dictionary = readout.action(&"sword_strike")
	assert_eq([strike.arranged, strike.position], [true, 0])
	# Four supply positions, two usable; no capacity was unlocked by the redesign.
	assert_eq([readout.supplies.size(), readout.supply_capacity], [4, 2])
	assert_eq(readout.supplies.map(func(slot: PotionSlotReadout) -> bool: return slot.locked), [false, false, true, true])
	assert_eq([readout.supply(0).potion_id, readout.supply(0).held, readout.supply(0).usable], [&"mending_draught", 4, 2])
	# Twenty bag cells drawn, ten usable; fifteen only after the existing bell reward.
	assert_eq([readout.equipment_cells, readout.equipment_capacity], [20, 10])
	progress.add_claim(&"first_footsteps.restoration")
	var inventory := PreparationRules.inventory(progress, registry)
	assert_eq([inventory.equipment_cells, inventory.equipment_capacity, InventoryReadout.EQUIPMENT_CELLS], [20, 15, 20])
	assert_false(inventory.cells_locked_text.is_empty())
	# During an encounter nothing is selectable, and the readout says why.
	var site: LandmarkDefinition = WorldDefinition.load_default().find_landmark(&"reedway_patrol")[1]
	progress.world.pending_entry = EncounterEntry.capture("t#1", &"briarfen_reedway", site, &"reedway_patrol", 5, progress,
		GameSettings.new(), registry.research)
	var held := LoadoutRules.readout(progress, registry, Database.library)
	assert_eq([held.available(), held.reason], [false, PreparationResult.Reason.ENCOUNTER_PENDING])
	assert_true(held.all_actions().all(func(entry: Dictionary) -> bool: return not entry.selectable))
	assert_false(held.familiar.available())


func test_ingredients_list_every_approved_material_including_zero() -> void:
	var progress := _fresh()
	var catalog := PreparationRules.ingredient_catalog(progress, registry)
	assert_eq(catalog.map(func(entry: Dictionary) -> Array: return [entry.id, entry.count, entry.held]),
		[[&"bog_iron", 0, false], [&"storm_salt", 0, false]], "every listed material, zero included, in a stable order")
	for entry in catalog:
		assert_false(String(entry.name).is_empty() or String(entry.description).is_empty() or String(entry.icon_path).is_empty())
	assert_empty(PreparationRules.held_materials(progress, registry), "the held-only list is unchanged")
	progress.materials = {&"storm_salt": 2, &"moon_dust": 9}
	catalog = PreparationRules.ingredient_catalog(progress, registry)
	assert_eq(catalog.map(func(entry: Dictionary) -> Array: return [entry.id, entry.count, entry.held]),
		[[&"bog_iron", 0, false], [&"storm_salt", 2, true]], "an unknown saved id is never shown")
	# The same list on every readout that shows ingredients.
	assert_eq(PreparationRules.inventory(progress, registry).ingredients, catalog)
	assert_eq(CraftingRules.readout(progress, registry, &"").ingredients, catalog)
	assert_eq(LoadoutRules.readout(progress, registry, Database.library).ingredients, catalog)
	# Catalog visibility and order are authored, separate from ownership.
	var custom := DefinitionRegistry.load_default()
	custom.materials = custom.materials.duplicate()
	var hidden: MaterialDefinition = custom.materials[&"bog_iron"].duplicate()
	hidden.listed = false
	custom.materials[&"bog_iron"] = hidden
	var first: MaterialDefinition = custom.materials[&"storm_salt"].duplicate()
	first.id = &"ash_resin"
	first.display_name = "Ash Resin"
	first.sort_order = 5
	custom.materials[&"ash_resin"] = first
	progress.materials[&"bog_iron"] = 3
	assert_eq(_ids(PreparationRules.ingredient_catalog(progress, custom)), [&"storm_salt", &"ash_resin"],
		"an unlisted material stays out even when held; sort_order before id")
	assert_eq(progress.material_count(&"bog_iron"), 3, "and is still counted for spending")


func test_passives_mastery_and_the_familiar_passive_are_distinct_facts() -> void:
	var progress := _fresh()
	progress.weapon_mastery[&"pilgrims_edge"] = 4
	var readout := LoadoutRules.readout(progress, registry, Database.library)
	var kinds := {}
	for passive in readout.passives:
		kinds[passive.kind] = kinds.get(passive.kind, 0) + 1
		assert_false(String(passive.name).is_empty())
		assert_false(String(passive.source_name).is_empty())
	assert_eq(kinds, {&"gear": 2, &"resonance": 1, &"familiar": 1}, "Pilgrim's Edge, Pilgrim's Coat, Litany and the Bell Crow")
	var familiar_passive: Dictionary = readout.passives.filter(func(entry: Dictionary) -> bool: return entry.kind == &"familiar")[0]
	assert_eq([familiar_passive.id, familiar_passive.source_id, familiar_passive.source_name],
		[readout.familiar.passive_id, LoadoutRules.SOURCE_FAMILIAR, "Bell Crow"])
	# Mastery is a record of use: listed apart, never a passive and never selectable.
	assert_eq(readout.mastery.map(func(entry: Dictionary) -> Array: return [entry.id, entry.points]),
		[[&"pilgrims_edge", 4], [&"mire_maul", 0], [&"reedbow", 0]])
	assert_true(readout.passives.all(func(entry: Dictionary) -> bool: return not registry.weapons.has(entry.id)))
	# Passives are never actions: none can be placed in a combat position.
	for passive in readout.passives:
		assert_eq(readout.action(passive.id), {}, "%s is not an action" % passive.id)
		assert_eq(CombatRules.put_check(progress, registry, Database.library, 0, passive.id), CombatResult.Reason.PASSIVE_SKILL)
	# A crafted, fitted fitting is a passive of the weapon source.
	progress.add_recipe(&"forge.hollow_echo")
	progress.weapon_fittings[&"pilgrims_edge"] = &"fitting.hollow_echo"
	var fitted := LoadoutRules.readout(progress, registry, Database.library)
	var fitting := fitted.passives.filter(func(entry: Dictionary) -> bool: return entry.kind == &"fitting")
	assert_eq(fitting.map(func(entry: Dictionary) -> Array: return [entry.id, entry.source_id]), [[&"hollow_echo", LoadoutRules.SOURCE_WEAPON]])
