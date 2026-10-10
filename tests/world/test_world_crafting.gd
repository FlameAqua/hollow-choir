extends TestCase
## V0.5B Forge and Stillroom through the production WorldSession. V0.5 UI: Forge work needs the open
## anvil context and Stillroom work the open Stillroom context (each rejects the other service);
## potion preparation is a field choice; nothing changes during a pending encounter; rejections are
## typed and publish nothing; failed writes change nothing and a retry publishes once; ownership and
## fittings survive Reset journey and reload; older saves reconcile; the fitting reaches the next
## immutable entry and real battles (Merciful Grip, Hollow Echo); potion preparation reaches battle.
## Playtest revision: each fitting is crafted on its own (the older kit is grandfathered and stays
## refundable, stack cap included) and potion recipes are brewed into finite stock. The supply
## lifecycle itself is covered by test_world_supplies.gd and the new commands' details by
## test_world_revision_session.gd.

const BENCH := &"preparation_bench"
const STILLROOM := &"stillroom_table"
const KIT := &"forge.first_fitting"
const CRAFT_GRIP := &"forge.merciful_grip"
const CRAFT_ECHO := &"forge.hollow_echo"
const SALVE := &"stillroom.clotting_salve"
const TINCTURE := &"stillroom.focus_tincture"
const GRIP := &"fitting.merciful_grip"
const ECHO := &"fitting.hollow_echo"
const EDGE := &"pilgrims_edge"
const FITTING_SOURCE := "Pilgrim's Edge fitting"
## Species and encounter names: station readouts carry item facts only.
const FORBIDDEN := ["fen_patrol", "rot_grove", "Fen Patrol", "Rot Grove", "Bogshell", "Thornhound", "Fen Wisp",
	"Rotcap", "Sporecaller", "affinit", "weakness", "resist"]

var kit: WorldKit
var published: Array[CraftingResult] = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	published.clear()
	EventBus.crafting_completed.connect(_on_crafted)


func after_each() -> void:
	EventBus.crafting_completed.disconnect(_on_crafted)
	kit.restore()


func _on_crafted(result: CraftingResult) -> void:
	published.append(result)


## The live progress as canonical JSON (numbers and key order as on disk).
static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


## Test setup: the live save holds [param iron] Bog Iron, [param salt] Storm Salt and [param mastery]
## mastery points on Pilgrim's Edge.
static func _fund(iron: int, salt: int, mastery: int = 1) -> void:
	var progress := GameState.progress
	progress.materials.clear()
	if iron > 0:
		progress.materials[&"bog_iron"] = iron
	if salt > 0:
		progress.materials[&"storm_salt"] = salt
	progress.weapon_mastery.clear()
	if mastery > 0:
		progress.weapon_mastery[EDGE] = mastery


func _station(rng_seed: int = 7, station: StringName = BENCH) -> WorldSession:
	var session := kit.session(rng_seed)
	session.open()
	assert_eq(session.enter_station(station), OK)
	return session


## Closes any open station and opens [param station] (as walking from one to the other does).
func _at(session: WorldSession, station: StringName) -> void:
	session.leave_station()
	assert_eq(session.enter_station(station), OK)


static func _win(session: WorldSession, site_id: StringName) -> void:
	var entry := session.begin_entry(site_id, site_id)
	session.commit_victory(entry, WorldKit.victory(site_id))


## Reloads the live save from the last successful write (as Continue would).
func _reload() -> void:
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))


func test_station_services_gate_station_work_and_supplies_are_field_choices() -> void:
	var session := kit.session()
	session.open()
	_fund(2, 1)
	var before := _snapshot()
	var forge_work: Array[Callable] = [
		func() -> Error: return session.craft_fitting(GRIP),
		func() -> Error: return session.refund(KIT),
		func() -> Error: return session.fit(EDGE, GRIP),
		func() -> Error: return session.remove_fitting(EDGE)]
	var stillroom_work: Array[Callable] = [
		func() -> Error: return session.brew(TINCTURE),
		func() -> Error: return session.brew(SALVE)]
	# No station open: no station work. A saved anchor beside a station is not the station.
	GameState.progress.world.area = &"gloamstead"
	GameState.progress.world.anchor = &"town_bell"
	for command in forge_work + stillroom_work:
		assert_eq(command.call(), ERR_UNAVAILABLE)
		assert_eq(session.last_crafting.reason, CraftingResult.Reason.NO_STATION)
		assert_eq(session.last_crafting.text(), WorldCopy.CRAFT_NO_STATION)
	var readout := session.crafting()
	assert_eq([readout.reason, readout.service], [CraftingResult.Reason.NO_STATION, LandmarkDefinition.Service.NONE])
	for recipe in readout.recipes:
		assert_eq([recipe.can_purchase, recipe.purchase_reason], [false, CraftingResult.Reason.NO_STATION])
	# A forged context (a landmark id the session never opened) authorizes nothing.
	session._station = BENCH
	assert_eq(session.craft_fitting(GRIP), ERR_UNAVAILABLE)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NO_STATION)
	session.leave_station()
	assert_eq(session.enter_station(&"bellkeeper"), ERR_INVALID_PARAMETER, "only a station landmark opens a service")
	assert_eq(kit.writer.writes.size(), 0)
	assert_eq(_snapshot(), before, "nothing changed")
	assert_true(published.is_empty())
	# The anvil rejects Stillroom work and the Stillroom rejects Forge work: typed, unwritten.
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.service(), LandmarkDefinition.Service.FORGE)
	for command in stillroom_work:
		assert_eq(command.call(), ERR_UNAVAILABLE)
		assert_eq(session.last_crafting.reason, CraftingResult.Reason.WRONG_STATION)
		assert_eq(session.last_crafting.text(), WorldCopy.CRAFT_WRONG_STATION_STILLROOM)
	var at_forge := session.crafting()
	assert_eq([at_forge.service, at_forge.reason], [LandmarkDefinition.Service.FORGE, CraftingResult.Reason.OK])
	assert_eq(at_forge.recipe(TINCTURE).purchase_reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(at_forge.recipe(CRAFT_GRIP).purchase_reason, CraftingResult.Reason.OK)
	_at(session, STILLROOM)
	assert_eq(session.service(), LandmarkDefinition.Service.STILLROOM)
	for command in forge_work:
		assert_eq(command.call(), ERR_UNAVAILABLE)
		assert_eq(session.last_crafting.reason, CraftingResult.Reason.WRONG_STATION)
		assert_eq(session.last_crafting.text(), WorldCopy.CRAFT_WRONG_STATION_FORGE)
	var at_stillroom := session.crafting()
	assert_eq(at_stillroom.recipe(CRAFT_GRIP).purchase_reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(at_stillroom.fitting(EDGE).option(GRIP).reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(at_stillroom.fitting(EDGE).option(GRIP).craft_reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(at_stillroom.recipe(TINCTURE).purchase_reason, CraftingResult.Reason.OK)
	assert_eq(kit.writer.writes.size(), 0)
	assert_eq(_snapshot(), before)
	assert_true(published.is_empty())
	assert_eq(session.brew(TINCTURE), OK)
	session.leave_station()
	assert_eq(session.brew(SALVE), ERR_UNAVAILABLE, "the context ends with the interaction")
	# Prepared supplies are a field choice: no station is needed or consulted.
	assert_eq(session.prepare_potion(1, &"focus_tincture"), OK)
	assert_eq(session.crafting().potion_slot(1).option(&"fen_water_flask").reason, CraftingResult.Reason.OK)
	# A pending encounter blocks station work and supply choices, even with a stale context.
	assert_eq(session.enter_station(BENCH), OK)
	assert_not_null(session.begin_entry(&"reedway_patrol", &"reedway_patrol"))
	assert_eq(session.station(), &"", "starting an encounter ends the station interaction")
	assert_eq(session.enter_station(BENCH), ERR_UNAVAILABLE)
	session._station = BENCH
	session._service = LandmarkDefinition.Service.FORGE
	var pending := _snapshot()
	var during: Array[Callable] = forge_work.duplicate()
	during.append(func() -> Error: return session.prepare_potion(1, &"fen_water_flask"))
	for command in during:
		assert_eq(command.call(), ERR_UNAVAILABLE)
		assert_eq(session.last_crafting.reason, CraftingResult.Reason.ENCOUNTER_PENDING)
	assert_eq(session.crafting().reason, CraftingResult.Reason.ENCOUNTER_PENDING)
	assert_eq(_snapshot(), pending)
	assert_eq(published.size(), 2, "only the brew and the supply choice were published")


func test_rejections_are_typed_change_nothing_and_publish_nothing() -> void:
	var session := _station()
	_fund(0, 0, 0)
	var before := _snapshot()
	# [station opened for the command, command, reason]: Forge work at the anvil, Stillroom work at
	# the Stillroom, supply choices anywhere.
	var cases := [
		[BENCH, func() -> Error: return session.purchase(&"forge.unknown"), CraftingResult.Reason.UNKNOWN_RECIPE],
		[BENCH, func() -> Error: return session.purchase(KIT), CraftingResult.Reason.RECIPE_RETIRED],
		[BENCH, func() -> Error: return session.craft_fitting(GRIP), CraftingResult.Reason.MASTERY_REQUIRED],
		[BENCH, func() -> Error: return session.craft_fitting(&"fitting.unknown"), CraftingResult.Reason.UNKNOWN_FITTING],
		[STILLROOM, func() -> Error: return session.brew(SALVE), CraftingResult.Reason.INSUFFICIENT_MATERIALS],
		[STILLROOM, func() -> Error: return session.brew(TINCTURE), CraftingResult.Reason.INSUFFICIENT_MATERIALS],
		[STILLROOM, func() -> Error: return session.brew(&"stillroom.unknown"), CraftingResult.Reason.UNKNOWN_RECIPE],
		[BENCH, func() -> Error: return session.refund(KIT), CraftingResult.Reason.RECIPE_NOT_OWNED],
		[STILLROOM, func() -> Error: return session.refund(SALVE), CraftingResult.Reason.NOT_REFUNDABLE],
		[STILLROOM, func() -> Error: return session.refund(&"stillroom.unknown"), CraftingResult.Reason.UNKNOWN_RECIPE],
		[BENCH, func() -> Error: return session.fit(EDGE, GRIP), CraftingResult.Reason.FITTING_NOT_OWNED],
		[BENCH, func() -> Error: return session.fit(EDGE, &"fitting.unknown"), CraftingResult.Reason.UNKNOWN_FITTING],
		[BENCH, func() -> Error: return session.fit(&"reedbow", GRIP), CraftingResult.Reason.WRONG_WEAPON],
		[BENCH, func() -> Error: return session.fit(&"merciful_iron", GRIP), CraftingResult.Reason.WRONG_WEAPON],
		[BENCH, func() -> Error: return session.fit(&"no_such_weapon", GRIP), CraftingResult.Reason.WRONG_WEAPON],
		[BENCH, func() -> Error: return session.fit(EDGE, GRIP, 1), CraftingResult.Reason.LOCKED_SOCKET],
		[BENCH, func() -> Error: return session.fit(EDGE, GRIP, 3), CraftingResult.Reason.INVALID_SOCKET],
		[BENCH, func() -> Error: return session.prepare_potion(0, &"clotting_salve"), CraftingResult.Reason.NO_STOCK],
		[STILLROOM, func() -> Error: return session.prepare_potion(1, &"focus_tincture"), CraftingResult.Reason.NO_STOCK],
		[BENCH, func() -> Error: return session.prepare_potion(0, &"elixir_of_ages"), CraftingResult.Reason.UNKNOWN_POTION],
		[BENCH, func() -> Error: return session.prepare_potion(0, &""), CraftingResult.Reason.UNKNOWN_POTION],
		[BENCH, func() -> Error: return session.prepare_potion(2, &"mending_draught"), CraftingResult.Reason.INVALID_POTION_SLOT],
		[BENCH, func() -> Error: return session.prepare_potion(-1, &"mending_draught"), CraftingResult.Reason.INVALID_POTION_SLOT],
		[BENCH, func() -> Error: return session.prepare_potion(1, &"mending_draught"), CraftingResult.Reason.DUPLICATE_POTION],
	]
	for case: Array in cases:
		_at(session, case[0])
		assert_eq((case[1] as Callable).call(), ERR_INVALID_PARAMETER, "reason %d" % case[2])
		var result := session.last_crafting
		assert_eq(result.reason, case[2])
		assert_false(result.ok() or result.changed)
		assert_true(result.spent.is_empty() and result.refunded.is_empty() and result.produced.is_empty())
		assert_false(result.text().is_empty(), "a public reason")
		assert_eq(result.operation(), &"", "a rejection names no operation")
	assert_true(session.last_crafting.text().contains("other slot"))
	session.craft_fitting(GRIP)
	assert_eq(session.last_crafting.text(),
		"Needs 1 weapon mastery point with Pilgrim's Edge, Mire Maul or Reedbow. Use one of them in a battle that records progress.",
		"the exact reason a zero-weapon-use win leaves the fitting uncraftable")
	assert_eq(kit.writer.writes.size(), 0, "nothing written")
	assert_eq(_snapshot(), before, "nothing changed")
	assert_true(published.is_empty(), "nothing published")
	# A second craft is a typed already-owned rejection and never spends again.
	_fund(2, 0)
	_at(session, BENCH)
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(GameState.progress.material_count(&"bog_iron"), 0)
	GameState.progress.materials[&"bog_iron"] = 3
	var owned := _snapshot()
	assert_eq(session.craft_fitting(GRIP), ERR_ALREADY_EXISTS)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.ALREADY_OWNED)
	assert_eq(_snapshot(), owned)
	assert_eq(kit.writer.writes.size(), 1)
	assert_eq(published.size(), 1)
	# An owned fitting cannot be fitted to a weapon the save does not own.
	GameState.progress.owned_equipment.erase(EDGE)
	assert_eq(session.fit(EDGE, GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.WEAPON_NOT_OWNED)


func test_duplicate_traits_are_rejected_without_removing_anything() -> void:
	var session := _station()
	_fund(4, 0)
	GameState.progress.owned_equipment.append(&"hollow_reliquary")
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(session.craft_fitting(ECHO), OK)
	assert_eq(session.equip(Enums.EquipSlot.RELIC, &"hollow_reliquary"), OK)
	var before := _snapshot()
	assert_eq(session.fit(EDGE, ECHO), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.DUPLICATE_TRAIT)
	assert_eq(session.last_crafting.text(), WorldCopy.CRAFT_DUPLICATE_TRAIT)
	assert_eq(_snapshot(), before, "the relic stays equipped, nothing is fitted")
	var option := session.crafting().fitting(EDGE).option(ECHO)
	assert_eq([option.selectable, option.reason, option.owned], [false, CraftingResult.Reason.DUPLICATE_TRAIT, true])
	assert_eq(session.fit(EDGE, GRIP), OK, "the other choice is fine")
	# Without the relic, Hollow Echo fits; equipping the relic again is then rejected.
	assert_eq(session.unequip(Enums.EquipSlot.RELIC), OK)
	assert_eq(session.fit(EDGE, ECHO), OK)
	assert_eq(session.last_crafting.previous_id, GRIP, "a free swap")
	var fitted := _snapshot()
	assert_eq(session.equip(Enums.EquipSlot.RELIC, &"hollow_reliquary"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_preparation.reason, PreparationResult.Reason.DUPLICATE_TRAIT)
	assert_eq(session.last_preparation.text(), WorldCopy.PREP_DUPLICATE_TRAIT)
	assert_eq(session.preparation().slot(Enums.EquipSlot.RELIC).option(&"hollow_reliquary").reason,
		PreparationResult.Reason.DUPLICATE_TRAIT)
	assert_eq(_snapshot(), fitted)
	# With another weapon equipped the fitting is inactive: the relic fits, and the sword then
	# cannot be re-equipped until one source goes. Nothing is ever doubled or silently dropped.
	assert_eq(session.choose_weapon(&"mire_maul"), OK)
	assert_eq(session.equip(Enums.EquipSlot.RELIC, &"hollow_reliquary"), OK)
	var relic := _snapshot()
	assert_eq(session.choose_weapon(EDGE), ERR_INVALID_PARAMETER)
	assert_eq(session.last_preparation.reason, PreparationResult.Reason.DUPLICATE_TRAIT)
	assert_eq(_snapshot(), relic)
	assert_eq(session.remove_fitting(EDGE), OK)
	assert_eq(session.choose_weapon(EDGE), OK)


func test_an_over_limit_loadout_rejects_station_commands_whole() -> void:
	var registry := DefinitionRegistry.load_default()
	var charm := ArmorDefinition.new()
	charm.id = &"test_chorus_charm"
	charm.display_name = "Chorus Charm"
	charm.slot = Enums.EquipSlot.CHARM
	charm.granted_actions.assign([registry.actions[&"hammer_blow"], registry.actions[&"shockwave"]])
	registry.armor[charm.id] = charm
	var session := _station()
	session.registry = registry
	_fund(2, 1)
	assert_eq(session.craft_fitting(GRIP), OK)
	_at(session, STILLROOM)
	assert_eq(session.brew(TINCTURE), OK)
	_at(session, BENCH)
	# An edited save whose gear grants more than the eight-action ceiling: no station change may
	# produce such a loadout, and nothing is truncated. (Battle uses the arranged six regardless.)
	GameState.progress.owned_equipment.append(charm.id)
	GameState.progress.loadout_charm = charm.id
	assert_eq(session.preparation().granted_actions, 9)
	assert_eq(session.crafting().protagonist_actions, CombatRules.STARTING_CAPACITY)
	var before := _snapshot()
	assert_eq(session.fit(EDGE, GRIP), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.ACTION_LIMIT)
	assert_true(session.last_crafting.text().contains(str(PartyLoadout.MAX_ACTIONS)))
	assert_eq(session.prepare_potion(1, &"focus_tincture"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.ACTION_LIMIT)
	assert_eq(_snapshot(), before)
	# Potions use the Supplies slots, not the action grid: with a legal grid they always fit.
	GameState.progress.loadout_charm = &""
	assert_eq(session.prepare_potion(1, &"focus_tincture"), OK)
	assert_eq(session.fit(EDGE, GRIP), OK)
	assert_eq(session.preparation().granted_actions, 7, "a fitting adds a trait, never an action")
	assert_eq(session.crafting().protagonist_actions, CombatRules.STARTING_CAPACITY)


func test_failed_writes_change_nothing_and_a_retry_publishes_once() -> void:
	var session := _station()
	_fund(2, 1)
	var stations: Array[StringName] = [BENCH, BENCH, STILLROOM, STILLROOM, BENCH]
	var steps: Array[Callable] = [
		func() -> Error: return session.craft_fitting(GRIP),
		func() -> Error: return session.fit(EDGE, GRIP),
		func() -> Error: return session.brew(TINCTURE),
		func() -> Error: return session.prepare_potion(1, &"focus_tincture"),
		func() -> Error: return session.remove_fitting(EDGE)]
	for index in steps.size():
		var step := steps[index]
		_at(session, stations[index])
		var before := _snapshot()
		var count := published.size()
		kit.writer.fail = true
		assert_eq(step.call(), ERR_FILE_CANT_WRITE)
		var failed := session.last_crafting
		assert_eq(failed.reason, CraftingResult.Reason.WRITE_FAILED)
		assert_false(failed.changed)
		assert_true(failed.spent.is_empty() and failed.refunded.is_empty() and failed.produced.is_empty()
			and failed.cleared_fitting == &"", "no receipt for a write that did not happen")
		assert_eq(_snapshot(), before, "the live save is unchanged")
		assert_eq(published.size(), count, "nothing published")
		assert_eq(session.station(), stations[index], "still at the station, so Retry can repeat the command")
		kit.writer.fail = false
		assert_eq(step.call(), OK, "Retry repeats the exact command")
		assert_eq(published.size(), count + 1, "and publishes once")
		assert_true(published.back() == session.last_crafting)
	assert_eq(kit.writer.writes.size(), steps.size(), "one successful write per command")
	assert_eq(published.map(func(result: CraftingResult) -> StringName: return result.operation()),
		[&"craft", &"fit", &"brew", &"prepare", &"remove"])
	assert_eq([GameState.progress.material_count(&"bog_iron"), GameState.progress.material_count(&"storm_salt"),
		GameState.progress.supply_count(&"focus_tincture")], [0, 0, 2], "each price was paid exactly once")


func test_an_older_kits_refund_conserves_materials_and_clears_its_fitting() -> void:
	# A save that bought the kit before the revision (it can no longer be bought).
	var session := _station()
	_fund(0, 0, 3)
	GameState.progress.add_recipe(KIT)
	var mastery := GameState.progress.weapon_mastery.duplicate()
	var owned := GameState.progress.owned_equipment.duplicate()
	# Fitting, swapping and removing cost nothing and never grant materials.
	for choice in [GRIP, ECHO, &"", GRIP]:
		assert_eq(session.fit(EDGE, choice), OK)
		assert_eq(GameState.progress.material_count(&"bog_iron"), 0)
	var writes := kit.writer.writes.size()
	var count := published.size()
	assert_eq(session.fit(EDGE, GRIP), OK)
	assert_false(session.last_crafting.changed, "re-choosing the installed fitting is a no-op")
	assert_eq(session.remove_fitting(&"mire_maul"), ERR_INVALID_PARAMETER, "the hammer takes no fitting")
	assert_eq(session.purchase(KIT), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.RECIPE_RETIRED, "an owned kit cannot be bought again either")
	assert_eq(kit.writer.writes.size(), writes, "no-ops and rejections write nothing")
	assert_eq(published.size(), count, "and publish nothing")
	assert_eq(session.refund(KIT), OK)
	var progress := GameState.progress
	assert_eq(progress.material_count(&"bog_iron"), 2, "exactly the price back")
	assert_false(progress.has_recipe(KIT))
	assert_false(progress.weapon_fittings.has(EDGE), "the fitting went with the kit")
	assert_eq(kit.writer.writes.size(), writes + 1, "in one write")
	assert_eq([progress.weapon_mastery, progress.owned_equipment, progress.loadout_weapon], [mastery, owned, EDGE],
		"mastery, the sword and owned equipment are untouched")
	assert_eq(session.refund(KIT), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.RECIPE_NOT_OWNED, "never a second credit")
	assert_eq(progress.material_count(&"bog_iron"), 2)
	assert_eq(session.purchase(KIT), ERR_INVALID_PARAMETER, "and never a rebuy: no refund loop exists")
	assert_true(session.crafting().fitting(EDGE).installed_id == &"")
	# A refund that cannot fit under the stack cap is rejected whole, never saturated away.
	GameState.progress.add_recipe(KIT)
	assert_eq(session.fit(EDGE, GRIP), OK)
	GameState.progress.materials[&"bog_iron"] = MaterialDefinition.MAX_COUNT - 1
	var capped := _snapshot()
	assert_false(session.crafting().recipe(KIT).can_refund)
	assert_false(session.crafting().fitting(EDGE).legacy_kit.can_refund)
	assert_eq(session.refund(KIT), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.REFUND_OVERFLOW)
	assert_true(session.last_crafting.text().contains(str(MaterialDefinition.MAX_COUNT)))
	assert_eq(_snapshot(), capped, "kit, fitting and materials unchanged")
	GameState.progress.materials[&"bog_iron"] = MaterialDefinition.MAX_COUNT - 2
	assert_eq(session.refund(KIT), OK)
	assert_eq(GameState.progress.material_count(&"bog_iron"), MaterialDefinition.MAX_COUNT)


func test_the_real_route_funds_choices_and_ownership_survives_reset_and_reload() -> void:
	var session := kit.session()
	session.open()
	_win(session, &"bell_guard")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.crafting().recipe(CRAFT_GRIP).mastery_current, GameState.progress.weapon_mastery[EDGE],
		"the guard victory's recorded weapon uses")
	# Guard salvage alone (2 Bog Iron, 1 Storm Salt): one fitting and a Tincture batch, no more.
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(session.craft_fitting(ECHO), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	_at(session, STILLROOM)
	assert_eq(session.brew(TINCTURE), OK)
	assert_eq(session.brew(SALVE), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	session.leave_station()
	_win(session, &"reedway_patrol")
	assert_eq(session.enter_station(STILLROOM), OK)
	assert_eq(session.brew(SALVE), OK)
	_at(session, BENCH)
	assert_eq(session.fit(EDGE, GRIP), OK)
	assert_eq(session.prepare_potion(0, &"clotting_salve"), OK)
	assert_eq(session.prepare_potion(1, &"focus_tincture"), OK)
	var progress := GameState.progress
	assert_eq(progress.crafting_recipes, [CRAFT_GRIP] as Array[StringName], "a brew is not an unlock; a crafted fitting is")
	assert_eq([progress.material_count(&"bog_iron"), progress.material_count(&"storm_salt")], [1, 0])
	assert_eq(progress.loadout_potions, [&"clotting_salve", &"focus_tincture"] as Array[StringName])
	var stock := progress.consumables.duplicate()
	assert_eq(stock, {&"mending_draught": 4, &"fen_water_flask": 4, &"clotting_salve": 2, &"focus_tincture": 2}
		as Dictionary[StringName, int])
	session.leave_station()
	var claims := progress.reward_claims.duplicate()
	assert_eq(session.reset_journey(), OK)
	for state: ProgressState in [GameState.progress, ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))]:
		assert_eq(state.crafting_recipes, [CRAFT_GRIP] as Array[StringName], "ownership persists")
		assert_eq(state.weapon_fittings.get(EDGE), GRIP, "and the installed fitting")
		assert_eq(state.loadout_potions, [&"clotting_salve", &"focus_tincture"] as Array[StringName])
		assert_eq(state.consumables, stock, "the stock is neither refilled nor lost")
		assert_eq(state.reward_claims, claims, "claims too")
		assert_eq(state.material_count(&"bog_iron"), 1)
		assert_true(state.world.cleared.is_empty(), "the journey itself reset")
	_reload()
	var reloaded := kit.session()
	reloaded.open()
	assert_eq(reloaded.reconcile(), OK)
	assert_true(reloaded.last_repairs.is_empty(), "nothing to repair after a reload")
	assert_true(reloaded.last_migrations.is_empty(), "and nothing to migrate")
	assert_eq(PreparationRules.battle_ids(GameState.progress, Database.registry).modifications, ["fitting.merciful_grip"])
	GameState.new_game()
	assert_empty(GameState.progress.crafting_recipes, "New Game owns no fitting")
	assert_true(GameState.progress.weapon_fittings.is_empty())


func test_older_saves_reconcile_potions_and_keep_unknown_ids_inert() -> void:
	var data := ProgressState.new().to_dict()
	data.erase("crafting")
	data.erase("rewards")
	data.erase("migrations")
	data.inventory.erase("consumables")
	data.inventory.materials = {"bog_iron": 2}
	data.loadout.potions = ["mending_draught", "clotting_salve"]
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate({"save_version": 1, "data": data}))
	var session := kit.session()
	session.open()
	assert_eq(session.reconcile(), OK)
	var progress := GameState.progress
	assert_eq(progress.loadout_potions, [&"mending_draught", &"clotting_salve"] as Array[StringName],
		"a valid old loadout is kept")
	assert_false(progress.has_recipe(SALVE), "a recipe is no longer an unlock")
	assert_eq(progress.supply_count(&"clotting_salve"), 2, "its prepared potion is grandfathered as one batch of stock")
	assert_eq(progress.material_count(&"bog_iron"), 2, "with no retroactive charge")
	assert_empty(session.last_repairs, "a kept loadout needs no repair")
	assert_eq(session.last_migrations.size(), 4, "three grants and the marker")
	var writes := kit.writer.writes.size()
	assert_eq(writes, 1)
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes, "migrated once")
	# Unknown potion ids become a free starter; extra entries beyond the two slots are removed.
	for case: Array in [
			[["elixir_of_ages", "fen_water_flask"], [&"mending_draught", &"fen_water_flask"]],
			[["fen_water_flask", "mending_draught", "clotting_salve"], [&"fen_water_flask", &"mending_draught"]],
			[["elixir", "tonic"], [&"mending_draught", &"fen_water_flask"]],
			[["mending_draught", "fen_water_flask", "elixir"], [&"mending_draught", &"fen_water_flask"]]]:
		GameState.progress = ProgressState.new()
		GameState.progress.loadout_potions.assign(case[0].map(func(id: String) -> StringName: return StringName(id)))
		var repairing := kit.session()
		repairing.open()
		assert_eq(repairing.reconcile(), OK)
		assert_eq(GameState.progress.loadout_potions, case[1] as Array[StringName], "%s" % [case[0]])
		assert_false(GameState.progress.has_recipe(SALVE))
		assert_eq(GameState.progress.supply_count(&"clotting_salve"), 0, "a removed entry grants nothing")
		assert_eq([GameState.progress.supply_count(&"mending_draught"), GameState.progress.supply_count(&"fen_water_flask")],
			[4, 4], "the repaired save still gets its starter batch")
	# Unknown recipe and fitting ids stay in the save, inert, and survive a round trip.
	GameState.progress = ProgressState.new()
	GameState.progress.add_recipe(&"forge.future_kit")
	GameState.progress.weapon_fittings[EDGE] = &"fitting.future"
	var inert := kit.session()
	inert.open()
	assert_eq(inert.reconcile(), OK)
	assert_true(inert.last_repairs.is_empty())
	assert_eq(PreparationRules.battle_ids(GameState.progress, Database.registry).modifications, [])
	assert_eq(inert.enter_station(BENCH), OK)
	assert_eq(inert.crafting().fitting(EDGE).installed_id, &"", "an unknown fitting is not shown")
	var round_trip := ProgressState.from_dict(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())))
	assert_true(round_trip.has_recipe(&"forge.future_kit") and round_trip.weapon_fittings[EDGE] == &"fitting.future")
	# An edited save carrying a fitting's trait twice: the fitting goes, the relic stays.
	GameState.progress = ProgressState.new()
	GameState.progress.add_recipe(KIT)
	GameState.progress.weapon_mastery[EDGE] = 1
	GameState.progress.owned_equipment.append(&"hollow_reliquary")
	GameState.progress.loadout_relic = &"hollow_reliquary"
	GameState.progress.weapon_fittings[EDGE] = ECHO
	var doubled := kit.session()
	doubled.open()
	assert_eq(doubled.reconcile(), OK)
	assert_false(GameState.progress.weapon_fittings.has(EDGE))
	assert_eq(GameState.progress.loadout_relic, &"hollow_reliquary")
	assert_true(GameState.progress.has_recipe(KIT), "the kit stays (refundable as usual)")
	assert_eq(doubled.last_repairs.size(), 1)


func test_the_fitting_reaches_the_next_entry_and_a_retry_never_changes() -> void:
	var session := _station()
	_fund(2, 0)
	# An entry captured before the purchase keeps no fitting.
	session.leave_station()
	var early := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(early.to_dict().loadout.modifications, [])
	assert_eq(session.return_home(early), OK)
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(session.fit(EDGE, GRIP), OK)
	assert_eq(EncounterEntry.from_dict(early.to_dict()).build_setup(Database.registry, Database.library).loadout.modifications,
		[] as Array[ModificationDefinition], "an earlier capture never reads live fittings")
	session.leave_station()
	# Reload, then the next entry captures the resolved fitting id.
	_reload()
	var journey := kit.session(11)
	journey.open()
	var entry := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(entry.to_dict().loadout.modifications, ["fitting.merciful_grip"])
	var setup := entry.build_setup(Database.registry, Database.library)
	assert_eq(setup.loadout.modifications, [Database.registry.modifications[GRIP]] as Array[ModificationDefinition])
	var hero := BattleEngine.new(setup).get_state().protagonist()
	var sources := {}
	for instance in hero.traits:
		sources[instance.trait_def.id] = instance.source_name
	assert_eq(sources.get(&"merciful_grip"), FITTING_SOURCE)
	assert_eq(sources.get(&"pilgrims_patience"), "Pilgrim's Edge", "the base trait stays")
	# While the entry is pending nothing at the station can change it, and even a live edit does
	# not reach a retry.
	assert_eq(journey.enter_station(BENCH), ERR_UNAVAILABLE)
	GameState.progress.weapon_fittings.clear()
	GameState.progress.remove_recipe(CRAFT_GRIP)
	var retry := EncounterEntry.from_dict(GameState.progress.world.pending_entry.to_dict()).build_setup(Database.registry,
		Database.library)
	assert_eq(retry.loadout.modifications, [Database.registry.modifications[GRIP]] as Array[ModificationDefinition])
	assert_eq(WorldKit.fingerprint(retry), WorldKit.fingerprint(entry.build_setup(Database.registry, Database.library)))
	# Another weapon equipped: the fitting stays installed but inert. (Reloading turns the
	# interrupted entry back into an available encounter.)
	_reload()
	var other := kit.session(11)
	other.open()
	assert_null(other.world().pending_entry)
	assert_eq(other.enter_station(BENCH), OK)
	assert_eq(other.choose_weapon(&"reedbow"), OK)
	other.leave_station()
	var bow_entry := other.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(bow_entry.to_dict().loadout.modifications, [])
	# Removing the fitting restores the base sword for the next entry, with no material change.
	assert_eq(other.return_home(bow_entry), OK)
	assert_eq(other.enter_station(BENCH), OK)
	assert_eq(other.choose_weapon(EDGE), OK)
	var iron := GameState.progress.material_count(&"bog_iron")
	assert_eq(other.remove_fitting(EDGE), OK)
	assert_eq(GameState.progress.material_count(&"bog_iron"), iron)
	other.leave_station()
	var base := other.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(base.to_dict().loadout.modifications, [])
	var base_traits := BattleEngine.new(base.build_setup(Database.registry, Database.library)).get_state().protagonist().traits.map(
		func(instance: TraitInstance) -> StringName: return instance.trait_def.id)
	assert_true(base_traits.has(&"pilgrims_patience") and not base_traits.has(&"merciful_grip"), "the base sword again")


## The patrol entry's captured setup with [param modifications] in place of its fittings.
func _patrol_setup(modifications: Array) -> BattleSetup:
	var session := kit.session(5)
	session.open()
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var data := entry.to_dict()
	data.loadout.modifications = modifications
	session.return_home(entry)
	return EncounterEntry.from_dict(data).build_setup(Database.registry, Database.library)


func test_merciful_grip_changes_windows_and_heals_on_a_successful_parry() -> void:
	var plain := _patrol_setup([])
	var grip := _patrol_setup(["fitting.merciful_grip"])
	var plain_engine := BattleEngine.new(plain)
	var grip_engine := BattleEngine.new(grip)
	var plain_hero := plain_engine.get_state().protagonist()
	var grip_hero := grip_engine.get_state().protagonist()
	var stats := [[Enums.ModifierStat.GOOD_WINDOW, 1.6], [Enums.ModifierStat.PERFECT_WINDOW, 1.5]]
	for entry: Array in stats:
		var without := ModifierQuery.apply(plain_engine.ctx, entry[0], 100.0, plain_hero, null)
		var with_fitting := ModifierQuery.apply(grip_engine.ctx, entry[0], 100.0, grip_hero, null)
		assert_almost_eq(with_fitting / without, entry[1], 0.0001, "window x%.1f" % entry[1])
	assert_almost_eq(DamageCalculator.grade_multiplier(plain_engine.ctx, plain_hero, Enums.ExecutionGrade.PERFECT), 1.15, 0.0001)
	assert_almost_eq(DamageCalculator.grade_multiplier(grip_engine.ctx, grip_hero, Enums.ExecutionGrade.PERFECT), 1.07, 0.0001)
	# A real battle: every successful Hollow Parry restores 8 HP through the fitting.
	var with_report := _parry_battle(grip)
	var without_report := _parry_battle(plain)
	assert_gte(with_report.parries, 1, "the Hollow parried at least once")
	assert_eq(with_report.fitting_triggers, with_report.parries, "one fitting trigger per successful Parry")
	assert_eq(with_report.fitting_heals, with_report.parries)
	for amount: float in with_report.heal_amounts:
		assert_almost_eq(amount, 8.0, 0.001, "Merciful Grip restores 8 HP")
	assert_eq(without_report.fitting_triggers, 0, "no fitting, no trigger")


func test_hollow_echo_exposes_the_attacker_on_a_successful_parry() -> void:
	var echo := _parry_battle(_patrol_setup(["fitting.hollow_echo"]))
	var plain := _parry_battle(_patrol_setup([]))
	assert_gte(echo.parries, 1)
	assert_eq(echo.fitting_triggers, echo.parries)
	assert_eq(echo.exposed_attackers, echo.attackers, "each parried attacker's weak point is exposed")
	assert_eq(plain.fitting_triggers, 0)
	assert_true(plain.exposed_attackers.is_empty(), "a Parry alone exposes nothing")


## Plays [param setup]: everyone takes their Guard action; each enemy attack on the Hollow that
## allows a Parry is Parried successfully, up to [param wanted] times. Reports the fitting's
## triggers and what followed each Parry.
func _parry_battle(setup: BattleSetup, wanted: int = 2) -> Dictionary:
	var driver := BattleDriver.new(setup)
	var hero := driver.hero()
	hero.hp = hero.max_hp - 40
	var report := {"parries": 0, "fitting_triggers": 0, "fitting_heals": 0, "heal_amounts": [], "attackers": [],
		"exposed_attackers": []}
	var marks: Array[int] = []
	for step in 800:
		var request := driver.next_request()
		if request == null:
			break
		if request is ReactionRequest:
			var reaction := request as ReactionRequest
			if report.parries < wanted and reaction.target_uids.has(hero.uid) and reaction.spec.is_allowed(Enums.ReactionType.PARRY):
				marks.append(driver.events.size())
				report.attackers.append(reaction.attacker_uid)
				report.parries += 1
				driver.engine.submit_reaction(ReactionResult.make(Enums.ReactionType.PARRY, true))
			else:
				driver.engine.submit_reaction(ReactionResult.none())
		elif request is CommandRequest:
			driver.engine.submit_command_result(Enums.ExecutionGrade.GOOD)
		elif request is ActionSelectRequest:
			if report.parries >= wanted:
				break
			var select := request as ActionSelectRequest
			var guard := select.legal_options().filter(func(legal: ActionOption) -> bool:
				return legal.action.category == Enums.ActionCategory.GUARD)
			var option: ActionOption = guard[0] if not guard.is_empty() else select.legal_options()[0]
			assert_eq(driver.act(option.action.id), OK)
	for index in marks.size():
		var end := marks[index + 1] if index + 1 < marks.size() else driver.events.size()
		var window := driver.events.slice(marks[index], end)
		for position in window.size():
			var event: BattleEvent = window[position]
			if event.type == BattleEvent.Type.TRIGGER_ACTIVATED and event.text == FITTING_SOURCE and event.subject == hero.uid:
				report.fitting_triggers += 1
				for later: BattleEvent in window.slice(position + 1):
					if later.type == BattleEvent.Type.HEAL and later.subject == hero.uid:
						report.fitting_heals += 1
						report.heal_amounts.append(later.amount)
						break
			if event.type == BattleEvent.Type.WEAK_POINT_EXPOSED and event.subject == report.attackers[index]:
				report.exposed_attackers.append(event.subject)
	return report


func test_potion_preparation_reaches_battle_with_unchanged_capacities() -> void:
	var session := _station()
	_fund(1, 1)
	var slot := session.crafting().potion_slot(1)
	assert_eq([slot.potion_id, slot.option(&"focus_tincture").selectable, slot.option(&"focus_tincture").reason],
		[&"fen_water_flask", false, CraftingResult.Reason.NO_STOCK])
	assert_eq(slot.option(&"focus_tincture").recipe_id, TINCTURE, "an unstocked choice names the recipe that brews it")
	_at(session, STILLROOM)
	assert_eq(session.brew(TINCTURE), OK)
	session.leave_station()
	assert_eq(session.crafting().potion_slot(1).option(&"focus_tincture").reason, CraftingResult.Reason.OK)
	assert_eq(session.prepare_potion(1, &"focus_tincture"), OK)
	assert_eq(session.last_crafting.previous_id, &"fen_water_flask")
	var writes := kit.writer.writes.size()
	assert_eq(session.prepare_potion(1, &"focus_tincture"), OK)
	assert_false(session.last_crafting.changed, "re-choosing is a no-op")
	assert_eq(kit.writer.writes.size(), writes, "that writes nothing")
	assert_eq(session.prepare_potion(0, &"focus_tincture"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.DUPLICATE_POTION)
	assert_eq(session.prepare_potion(0, &"fen_water_flask"), OK, "the starters stay choices while they are stocked")
	assert_eq(session.prepare_potion(0, &"mending_draught"), OK)
	session.leave_station()
	_reload()
	var journey := kit.session(13)
	journey.open()
	var entry := journey.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(entry.to_dict().loadout.potions, ["mending_draught", "focus_tincture"])
	assert_eq(entry.to_dict().loadout.potion_charges, [2, 1], "the captured allowance: each cap, with stock to spare")
	var setup := entry.build_setup(Database.registry, Database.library)
	var driver := BattleDriver.new(setup)
	var slots := driver.engine.get_state().potion_slots
	assert_eq(slots.size(), PartyLoadout.MAX_POTION_SLOTS)
	for state: PotionSlotState in slots:
		assert_eq(state.charges, state.potion.charges, "%s starts at its per-encounter cap" % state.potion.display_name)
	assert_eq(slots[1].potion, Database.registry.potions[&"focus_tincture"])
	# Use it in the real battle: +4 Focus to an ally, one charge spent.
	var request := driver.to_player_turn()
	while request != null and request.unit_uid != driver.hero().uid:
		var guard := request.legal_options().filter(func(option: ActionOption) -> bool:
			return option.action.category == Enums.ActionCategory.GUARD)
		assert_eq(driver.act(guard[0].action.id), OK)
		request = driver.to_player_turn()
	assert_not_null(request)
	driver.hero().focus = 0
	var focus_before := driver.hero().focus
	var mark := driver.events.size()
	assert_eq(driver.act(&"use_focus_tincture", driver.hero().uid), OK)
	driver.next_request()
	assert_eq(slots[1].charges, slots[1].potion.charges - 1)
	assert_true(driver.events.slice(mark).any(func(event: BattleEvent) -> bool:
		return event.type == BattleEvent.Type.ITEM_USED and event.text == "Focus Tincture"))
	assert_gt(driver.hero().focus, focus_before, "the authored +4 Focus")
	# Practice and the Lab still audition every authored potion, unlocked or not.
	var practice := PartyLoadout.from_ids(Database.registry, {"weapon": "pilgrims_edge",
		"potions": ["clotting_salve", "focus_tincture"]})
	assert_eq(practice.potions.size(), 2)


func test_readouts_are_typed_copies_without_creature_facts() -> void:
	var session := kit.session()
	session.open()
	_win(session, &"bell_guard")
	assert_eq(session.enter_station(BENCH), OK)
	var readout := session.crafting()
	assert_true(readout.available())
	assert_eq(readout.station_id, BENCH)
	assert_eq(readout.recipes.map(func(recipe: RecipeReadout) -> StringName: return recipe.id),
		[KIT, CRAFT_ECHO, CRAFT_GRIP, SALVE, &"stillroom.fen_water_flask", TINCTURE, &"stillroom.mending_draught"],
		"Forge first, then Stillroom, each by id")
	assert_eq(readout.material_count(&"bog_iron"), 2)
	var craft := readout.recipe(CRAFT_GRIP)
	assert_eq([craft.station_label, craft.kind, craft.refundable, craft.owned, craft.can_purchase, craft.retired, craft.repeatable],
		["Forge", RecipeDefinition.Kind.FITTING, false, false, true, false, false])
	assert_eq(craft.fittings.map(func(entry: Dictionary) -> String: return entry.trait.name), ["Merciful Grip"])
	var forge := readout.recipe(KIT)
	assert_eq([forge.station_label, forge.name, forge.refundable, forge.owned, forge.can_purchase, forge.retired,
		forge.purchase_reason], ["Forge", "Fitting kit", true, false, false, true, CraftingResult.Reason.RECIPE_RETIRED])
	assert_eq(forge.costs.map(func(cost: Dictionary) -> Array: return [cost.id, cost.count, cost.held, cost.enough]),
		[[&"bog_iron", 2, 2, true]])
	assert_eq([forge.mastery_required, forge.mastery_met], [1, true])
	assert_gte(forge.mastery_current, 1)
	assert_eq(forge.mastery_weapons, PackedStringArray(["Pilgrim's Edge", "Mire Maul", "Reedbow"]))
	assert_eq(forge.refund.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]), [[&"bog_iron", 2, 4]])
	assert_eq([forge.can_refund, forge.refund_reason], [false, CraftingResult.Reason.RECIPE_NOT_OWNED])
	assert_eq([forge.weapon_id, forge.weapon_name], [EDGE, "Pilgrim's Edge"])
	assert_eq(forge.fittings.map(func(entry: Dictionary) -> String: return entry.trait.name), ["Merciful Grip", "Hollow Echo"])
	var salve := readout.recipe(SALVE)
	assert_eq([salve.station_label, salve.base_name, salve.reagents, salve.catalyst, salve.refundable, salve.mastery_required],
		["Stillroom", "Prepared salve", PackedStringArray(["Bog Iron"]), "", false, 0])
	assert_eq([salve.potion_id, salve.potion_charges], [&"clotting_salve", Database.registry.potions[&"clotting_salve"].charges])
	assert_eq([salve.yield_count, salve.repeatable, salve.potion_held, salve.potion_total_after, salve.can_brew, salve.brew_reason],
		[2, true, 0, 2, false, CraftingResult.Reason.WRONG_STATION], "brew facts; the anvil is the wrong station")
	assert_eq(readout.recipe(TINCTURE).reagents, PackedStringArray(["Storm Salt"]))
	assert_eq(readout.recipe(TINCTURE).base_name, "Clear tincture stock")
	var fitting := readout.fitting(EDGE)
	assert_eq([fitting.weapon_equipped, fitting.kit_owned, fitting.capacity, fitting.capacity_reason, fitting.socket_capacity],
		[true, false, true, CraftingResult.Reason.OK, 1])
	assert_eq(fitting.base_traits.map(func(entry: Dictionary) -> String: return entry.name), ["Pilgrim's Patience"])
	var authored: TraitDefinition = Database.registry.weapons[&"merciful_iron"].traits[0]
	var option := fitting.option(GRIP)
	assert_eq([option.trait.name, option.trait.description, option.trait.details, option.source],
		[authored.display_name, authored.description, authored.details, "Merciful Iron"])
	assert_eq([option.selectable, option.reason, option.actions], [false, CraftingResult.Reason.FITTING_NOT_OWNED, 7])
	assert_eq([option.owned, option.action, option.can_craft, option.recipe_id], [false, &"craft", true, CRAFT_GRIP])
	assert_eq(readout.potion_slots.map(func(entry: PotionSlotReadout) -> StringName: return entry.potion_id),
		[&"mending_draught", &"fen_water_flask"])
	assert_eq(readout.potion_slot(0).options.map(func(entry: Dictionary) -> String: return entry.source),
		["Starter", "Starter", "Stillroom recipe", "Stillroom recipe"])
	# After crafting and fitting, the readout says what reaches the next encounter.
	assert_eq(session.craft_fitting(ECHO), OK)
	assert_eq(session.fit(EDGE, ECHO), OK)
	fitting = session.crafting().fitting(EDGE)
	assert_eq([fitting.capacity, fitting.installed_id, fitting.installed_name, fitting.active, fitting.can_remove],
		[true, ECHO, "Hollow Echo", true, true])
	assert_eq([fitting.option(ECHO).action, fitting.option(GRIP).action], [&"remove", &"craft"])
	assert_eq(session.crafting().recipe(KIT).can_refund, false, "nothing to refund without an older kit")
	var texts := PackedStringArray([session.crafting().plain_text()])
	for recipe in session.crafting().recipes:
		texts.append(JSON.stringify(recipe.costs) + JSON.stringify(recipe.fittings) + recipe.description + recipe.base_description)
	for entry in fitting.options:
		texts.append(JSON.stringify(entry))
	for text in texts:
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "no creature or encounter facts: %s" % word)
	# Readouts are copies: changing them changes neither the save nor the definitions.
	var before := _snapshot()
	var copy := session.crafting()
	copy.recipes[0].costs[0].count = 0
	copy.fitting(EDGE).options[0].trait.description = "changed"
	copy.potion_slots.clear()
	assert_eq(_snapshot(), before)
	assert_ne(authored.description, "changed")
	# At the anvil, Stillroom purchases name their own station.
	assert_eq(session.crafting().recipe(SALVE).purchase_reason, CraftingResult.Reason.WRONG_STATION)
	assert_eq(session.crafting().recipe(SALVE).purchase_reason_text, WorldCopy.CRAFT_WRONG_STATION_STILLROOM)
	# Away from every station, station work reports why it is unavailable; supplies stay field choices.
	session.leave_station()
	var away := session.crafting()
	for recipe in away.recipes:
		assert_eq(recipe.purchase_reason, CraftingResult.Reason.NO_STATION)
	for entry in away.potion_slot(0).options:
		assert_ne(entry.reason, CraftingResult.Reason.NO_STATION)
	assert_eq(away.potion_slot(0).option(&"fen_water_flask").reason, CraftingResult.Reason.DUPLICATE_POTION)
	assert_false(away.fitting(EDGE).can_remove)


func test_other_saves_and_shared_resources_are_unaffected() -> void:
	var registry := Database.registry
	var edge: WeaponDefinition = registry.weapons[EDGE]
	var grip_trait: TraitDefinition = registry.weapons[&"merciful_iron"].traits[0]
	var echo_trait: TraitDefinition = registry.armor[&"hollow_reliquary"].traits[0]
	var shared_before := [edge.traits.size(), edge.socket_count, grip_trait.modifiers.size(), grip_trait.triggers.size(),
		echo_trait.triggers.size(), registry.defaults.starter_loadout.potions.size(),
		registry.defaults.starter_loadout.modifications.size()]
	var session := _station()
	_fund(2, 1)
	assert_eq(session.craft_fitting(GRIP), OK)
	assert_eq(session.fit(EDGE, GRIP), OK)
	session.leave_station()
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	WorldKit.fingerprint(entry.build_setup(registry, Database.library))
	assert_eq([edge.traits.size(), edge.socket_count, grip_trait.modifiers.size(), grip_trait.triggers.size(),
		echo_trait.triggers.size(), registry.defaults.starter_loadout.potions.size(),
		registry.defaults.starter_loadout.modifications.size()], shared_before, "no shared Resource changed")
	assert_false(GameState.progress.owned_equipment.has(&"merciful_iron"), "the fitting never grants Merciful Iron")
	assert_false(GameState.progress.owned_equipment.has(&"hollow_reliquary"))
	# Another save sees none of it.
	var mine := GameState.progress
	GameState.new_game()
	assert_empty(GameState.progress.crafting_recipes)
	assert_eq(PreparationRules.battle_ids(GameState.progress, registry).modifications, [])
	assert_true(PreparationRules.campaign_loadout(GameState.progress, registry).modifications.is_empty())
	assert_true(mine.has_recipe(CRAFT_GRIP) and mine.weapon_fittings[EDGE] == GRIP, "and the first save keeps its own")
	# The character menu reads the same campaign loadout, fitting passive included.
	GameState.progress = mine
	var skills := CharacterReadout.build(mine, registry).skills
	assert_true(skills.any(func(skill: Dictionary) -> bool:
		return skill.id == &"merciful_grip" and String(skill.category).contains(FITTING_SOURCE)))
