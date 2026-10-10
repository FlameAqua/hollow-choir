extends TestCase
## V0.5B Forge/Stillroom data and pure rules: the authored catalog matches the Director's
## specification, the fittings resolve to the existing authored traits (by reference), the catalog
## checks reject broken data and the saved `crafting` section is parsed without trusting it.
## Playtest revision: each fitting is crafted on its own and owned for good, an older kit
## grandfathers its fittings and stays refundable, and every recipe alone is reachable on the route.

const KIT := &"forge.first_fitting"
const CRAFT_GRIP := &"forge.merciful_grip"
const CRAFT_ECHO := &"forge.hollow_echo"
const SALVE := &"stillroom.clotting_salve"
const TINCTURE := &"stillroom.focus_tincture"
const MENDING := &"stillroom.mending_draught"
const FLASK := &"stillroom.fen_water_flask"
const GRIP := &"fitting.merciful_grip"
const ECHO := &"fitting.hollow_echo"

var registry: DefinitionRegistry


func before_each() -> void:
	if registry == null:
		registry = DefinitionRegistry.load_default()


static func _canonical(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true)


func _costs(recipe_id: StringName) -> Dictionary:
	var result := {}
	for cost in registry.recipes[recipe_id].costs:
		result[cost.material.id] = cost.count
	return result


func test_the_catalog_is_the_specified_introductory_economy() -> void:
	assert_eq(registry.sorted_ids(registry.recipes), [KIT, CRAFT_ECHO, CRAFT_GRIP, SALVE, FLASK, TINCTURE, MENDING] as Array[StringName])
	# Each fitting is its own Forge recipe at the old kit's price and mastery gate.
	for pair: Array in [[CRAFT_GRIP, GRIP], [CRAFT_ECHO, ECHO]]:
		var craft: RecipeDefinition = registry.recipes[pair[0]]
		assert_eq([craft.station, craft.kind, craft.refundable, craft.mastery_points],
			[RecipeDefinition.Station.FORGE, RecipeDefinition.Kind.FITTING, false, 1], String(pair[0]))
		assert_eq(_costs(pair[0]), {&"bog_iron": 2}, "%s: the old kit price, per fitting" % pair[0])
		assert_eq(craft.weapon, registry.weapons[&"pilgrims_edge"])
		assert_eq(craft.fittings.map(func(fitting: ModificationDefinition) -> StringName: return fitting.id), [pair[1]])
		assert_eq(craft.mastery_weapons.map(func(weapon: WeaponDefinition) -> StringName: return weapon.id),
			[&"pilgrims_edge", &"mire_maul", &"reedbow"])
		assert_eq(CraftingRules.fitting_recipe(registry, pair[1]), craft)
	assert_eq(CraftingRules.weapon_fittings(registry, &"pilgrims_edge").map(
		func(fitting: ModificationDefinition) -> StringName: return fitting.id), [ECHO, GRIP], "craft recipes by id")
	assert_eq(CraftingRules.fitting_weapons(registry).map(func(weapon: WeaponDefinition) -> StringName: return weapon.id),
		[&"pilgrims_edge"])
	# The legacy kit stays as data for the saves that bought it.
	var kit: RecipeDefinition = registry.recipes[KIT]
	assert_eq([kit.station, kit.kind, kit.refundable], [RecipeDefinition.Station.FORGE, RecipeDefinition.Kind.FITTING_KIT, true])
	assert_eq(_costs(KIT), {&"bog_iron": 2})
	assert_eq(kit.mastery_points, 1, "one recorded weapon use, not a Perfect or a repeat expedition")
	assert_eq(kit.mastery_weapons.map(func(weapon: WeaponDefinition) -> StringName: return weapon.id),
		[&"pilgrims_edge", &"mire_maul", &"reedbow"], "any owned starter weapon")
	assert_eq(kit.weapon, registry.weapons[&"pilgrims_edge"])
	assert_eq(kit.fittings.map(func(fitting: ModificationDefinition) -> StringName: return fitting.id), [GRIP, ECHO])
	var salve: RecipeDefinition = registry.recipes[SALVE]
	assert_eq([salve.station, salve.kind, salve.refundable, salve.mastery_points],
		[RecipeDefinition.Station.STILLROOM, RecipeDefinition.Kind.POTION, false, 0])
	assert_eq(_costs(SALVE), {&"bog_iron": 1})
	assert_eq(salve.potion, registry.potions[&"clotting_salve"])
	var tincture: RecipeDefinition = registry.recipes[TINCTURE]
	assert_eq([tincture.station, tincture.kind, tincture.refundable, tincture.mastery_points],
		[RecipeDefinition.Station.STILLROOM, RecipeDefinition.Kind.POTION, false, 0])
	assert_eq(_costs(TINCTURE), {&"storm_salt": 1})
	assert_eq(tincture.potion, registry.potions[&"focus_tincture"])
	# The starter potions can be brewed again from the route's existing ingredients.
	assert_eq(_costs(MENDING), {&"bog_iron": 1})
	assert_eq(_costs(FLASK), {&"bog_iron": 1})
	assert_eq([registry.recipes[MENDING].potion, registry.recipes[FLASK].potion],
		[registry.potions[&"mending_draught"], registry.potions[&"fen_water_flask"]])
	for recipe_id: StringName in [SALVE, TINCTURE, MENDING, FLASK]:
		var recipe: RecipeDefinition = registry.recipes[recipe_id]
		assert_false(recipe.base_name.is_empty(), "%s names its public Base" % recipe.id)
		assert_eq([recipe.kind, recipe.yield_count, recipe.refundable], [RecipeDefinition.Kind.POTION, 2, false],
			"%s: one brew makes two doses" % recipe.id)
	# The route's finite budget (economy tuning stays open): every recipe alone is affordable from
	# it, though not all of them together any more (brewing is repeatable).
	var budget := {}
	for reward: RewardDefinition in registry.rewards.values():
		for item in reward.items:
			if item.kind == RewardItem.Kind.MATERIAL:
				budget[item.material.id] = budget.get(item.material.id, 0) + item.count
	assert_eq(budget, {&"bog_iron": 5, &"storm_salt": 1}, "V0.5C adds one spare iron seam")
	for recipe: RecipeDefinition in registry.recipes.values():
		for cost in recipe.costs:
			assert_lte(cost.count, budget.get(cost.material.id, 0), "%s is reachable on the route" % recipe.id)
	# Starter stock is authored on the starter loadout's potions only.
	assert_eq([registry.potions[&"mending_draught"].starter_stock, registry.potions[&"fen_water_flask"].starter_stock,
		registry.potions[&"clotting_salve"].starter_stock, registry.potions[&"focus_tincture"].starter_stock], [4, 4, 0, 0])
	assert_eq(CraftingRules.starter_potions(registry).map(func(potion: PotionDefinition) -> StringName: return potion.id),
		[&"mending_draught", &"fen_water_flask"])
	assert_eq(CraftingRules.campaign_potions(registry).map(func(potion: PotionDefinition) -> StringName: return potion.id),
		[&"mending_draught", &"fen_water_flask", &"clotting_salve", &"focus_tincture"])


func test_fittings_reuse_the_authored_traits_by_reference() -> void:
	var grip: ModificationDefinition = registry.modifications[GRIP]
	var echo: ModificationDefinition = registry.modifications[ECHO]
	var merciful_iron: WeaponDefinition = registry.weapons[&"merciful_iron"]
	var reliquary: ArmorDefinition = registry.armor[&"hollow_reliquary"]
	assert_true(grip.resolved_trait() == merciful_iron.traits[0], "the same Merciful Grip resource, not a copy")
	assert_true(echo.resolved_trait() == reliquary.traits[0], "the same Hollow Echo resource, not a copy")
	assert_eq([grip.display_name, echo.display_name], ["Merciful Grip", "Hollow Echo"])
	# Exact authored behavior (DATA: merciful_iron.tres, hollow_reliquary.tres).
	var modifiers := {}
	for modifier in grip.resolved_trait().modifiers:
		modifiers[modifier.stat] = [modifier.operation, modifier.value]
	assert_eq(modifiers[Enums.ModifierStat.GOOD_WINDOW], [Enums.ModifierOp.MULTIPLY, 1.6])
	assert_eq(modifiers[Enums.ModifierStat.PERFECT_WINDOW], [Enums.ModifierOp.MULTIPLY, 1.5])
	assert_eq(modifiers[Enums.ModifierStat.PERFECT_MULTIPLIER][0], Enums.ModifierOp.ADD)
	assert_almost_eq(registry.balance.grade_multiplier(Enums.ExecutionGrade.PERFECT) + modifiers[Enums.ModifierStat.PERFECT_MULTIPLIER][1],
		1.07, 0.0001, "1.07 instead of 1.15")
	var heal: TriggeredEffectDefinition = grip.resolved_trait().triggers[0]
	assert_eq([heal.trigger, heal.watch, heal.conditions[0].type, heal.conditions[0].reaction],
		[Enums.TriggerType.REACTION, Enums.TriggerWatch.TARGET, Enums.ConditionType.REACTION_SUCCEEDED, Enums.ReactionType.PARRY])
	assert_eq([heal.effects[0].type, heal.effects[0].target, heal.effects[0].amount], [Enums.EffectType.HEAL, Enums.EffectTarget.OWNER, 8.0])
	var expose: TriggeredEffectDefinition = echo.resolved_trait().triggers[0]
	assert_eq([expose.trigger, expose.conditions[0].type], [Enums.TriggerType.REACTION, Enums.ConditionType.REACTION_SUCCEEDED])
	assert_eq([expose.effects[0].type, expose.effects[0].target, expose.effects[0].duration],
		[Enums.EffectType.EXPOSE_WEAK_POINT, Enums.EffectTarget.ACTOR, 1])
	# Neither Pilgrim's Edge nor any other weapon gained sockets or traits.
	var edge: WeaponDefinition = registry.weapons[&"pilgrims_edge"]
	assert_eq([edge.socket_count, edge.traits.size(), edge.traits[0].id], [0, 1, &"pilgrims_patience"])


func test_catalog_checks_reject_broken_crafting_data() -> void:
	assert_empty(CraftingRules.validate_catalog(registry), "the shipped catalog is clean")
	var broken := DefinitionRegistry.load_default()
	# An unregistered copy of a material, a fitting that resolves nothing and has no craft recipe, a
	# refundable potion recipe, a second recipe for one potion, a yield of zero and a price above the
	# route budget.
	var stray_iron: MaterialDefinition = broken.materials[&"bog_iron"].duplicate()
	var cost := MaterialCost.new()
	cost.material = stray_iron
	cost.count = 1
	var greedy := RecipeDefinition.new()
	greedy.id = &"stillroom.second_draught"
	greedy.yield_count = 0
	greedy.display_name = "Mending Draught recipe"
	greedy.description = "Test."
	greedy.station = RecipeDefinition.Station.STILLROOM
	greedy.kind = RecipeDefinition.Kind.POTION
	greedy.refundable = true
	greedy.base_name = "Test base"
	greedy.potion = broken.potions[&"mending_draught"]
	var salt := MaterialCost.new()
	salt.material = broken.materials[&"storm_salt"]
	salt.count = 5
	greedy.costs.assign([cost, salt])
	broken.recipes[greedy.id] = greedy
	var ghost := ModificationDefinition.new()
	ghost.id = &"fitting.ghost"
	ghost.display_name = "Ghost"
	ghost.description = "Test."
	ghost.trait_source = broken.weapons[&"merciful_iron"]
	ghost.trait_id = &"no_such_trait"
	broken.modifications[ghost.id] = ghost
	var problems := "\n".join(broken.validate())
	for expected in ["material bog_iron is not a registered", "cannot be refundable", "potion mending_draught has two recipes",
			"costs 5 storm_salt, above the 1", "yield_count 0 is outside", "fitting.ghost: Merciful Iron has no trait 'no_such_trait'",
			"fitting fitting.ghost has no craft recipe"]:
		assert_true(problems.contains(expected), "reports: %s" % expected)
	# A fitting recipe is permanent, at the Forge, for exactly one fitting.
	var loose := RecipeDefinition.new()
	loose.id = &"forge.loose"
	loose.display_name = "Loose"
	loose.description = "Test."
	loose.kind = RecipeDefinition.Kind.FITTING
	loose.station = RecipeDefinition.Station.STILLROOM
	loose.refundable = true
	var loose_text := "\n".join(loose.validate())
	for expected in ["belongs to the Forge", "needs a weapon", "crafts exactly one fitting", "cannot be refundable"]:
		assert_true(loose_text.contains(expected), "reports: %s" % expected)
	# Self-contained recipe checks.
	var empty := RecipeDefinition.new()
	empty.id = &"Bad Id"
	var text := "\n".join(empty.validate())
	for expected in ["must be lowercase dotted words", "needs a public display_name", "costs nothing", "needs a weapon",
			"needs its fitting choices"]:
		assert_true(text.contains(expected), "reports: %s" % expected)


func test_a_fitting_takes_effect_only_when_it_is_owned() -> void:
	var progress := ProgressState.new()
	var craft: RecipeDefinition = registry.recipes[CRAFT_GRIP]
	assert_eq(CraftingRules.mastery(progress, craft), 0)
	# One usable socket of three for the one fitting-capable weapon; nothing else takes a fitting.
	assert_eq(CraftingRules.capacity(progress, registry, &"pilgrims_edge"), CraftingResult.Reason.OK)
	assert_eq(CraftingRules.capacity(progress, registry, &"mire_maul"), CraftingResult.Reason.WRONG_WEAPON,
		"only Pilgrim's Edge takes a fitting")
	assert_eq([CraftingRules.SOCKETS, CraftingRules.socket_capacity(registry, &"pilgrims_edge"),
		CraftingRules.socket_capacity(registry, &"mire_maul")], [3, 1, 0])
	assert_eq([CraftingRules.socket_check(registry, &"pilgrims_edge", 0), CraftingRules.socket_check(registry, &"pilgrims_edge", 1),
		CraftingRules.socket_check(registry, &"pilgrims_edge", 2), CraftingRules.socket_check(registry, &"pilgrims_edge", 3),
		CraftingRules.socket_check(registry, &"pilgrims_edge", -1)],
		[CraftingResult.Reason.OK, CraftingResult.Reason.LOCKED_SOCKET, CraftingResult.Reason.LOCKED_SOCKET,
		CraftingResult.Reason.INVALID_SOCKET, CraftingResult.Reason.INVALID_SOCKET])
	progress.weapon_fittings[&"pilgrims_edge"] = GRIP
	assert_empty(CraftingRules.active_modifications(progress, registry, &"pilgrims_edge", progress.weapon_fittings),
		"an installed id the save does not own stays inert")
	assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", GRIP), CraftingResult.Reason.FITTING_NOT_OWNED)
	assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", GRIP, 1), CraftingResult.Reason.LOCKED_SOCKET)
	assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", GRIP, 7), CraftingResult.Reason.INVALID_SOCKET)
	# Crafting needs the mastery gate and the whole price; ownership is per fitting.
	assert_eq(CraftingRules.craft_check(progress, registry, GRIP), CraftingResult.Reason.MASTERY_REQUIRED)
	progress.weapon_mastery[&"reedbow"] = 1
	assert_eq(CraftingRules.craft_check(progress, registry, GRIP), CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	progress.materials[&"bog_iron"] = 3
	assert_eq(CraftingRules.craft_check(progress, registry, GRIP), CraftingResult.Reason.OK)
	assert_eq(CraftingRules.craft_check(progress, registry, &"fitting.unknown"), CraftingResult.Reason.UNKNOWN_FITTING)
	var spent := CraftingRules.craft(progress, craft)
	assert_eq([spent.size(), spent[0].count, spent[0].total, progress.material_count(&"bog_iron")], [1, 2, 1, 1])
	assert_eq(progress.crafting_recipes, [CRAFT_GRIP] as Array[StringName])
	assert_eq([CraftingRules.fitting_owned_source(progress, registry, &"pilgrims_edge", GRIP),
		CraftingRules.fitting_owned_source(progress, registry, &"pilgrims_edge", ECHO)], [CraftingRules.OWNED_CRAFTED, &""])
	assert_eq(CraftingRules.craft_check(progress, registry, GRIP), CraftingResult.Reason.ALREADY_OWNED, "never charged twice")
	assert_eq(CraftingRules.craft_check(progress, registry, ECHO), CraftingResult.Reason.INSUFFICIENT_MATERIALS,
		"the other fitting has its own price")
	assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", GRIP), CraftingResult.Reason.OK)
	assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", ECHO), CraftingResult.Reason.FITTING_NOT_OWNED)
	assert_eq(CraftingRules.active_modifications(progress, registry, &"pilgrims_edge", progress.weapon_fittings),
		[registry.modifications[GRIP]] as Array[ModificationDefinition])
	# A crafted fitting cannot be crafted for a weapon the save does not own.
	var stripped := ProgressState.new()
	stripped.owned_equipment.erase(&"pilgrims_edge")
	stripped.weapon_mastery[&"reedbow"] = 1
	stripped.materials[&"bog_iron"] = 2
	assert_eq(CraftingRules.craft_check(stripped, registry, GRIP), CraftingResult.Reason.WEAPON_NOT_OWNED)
	# Mastery on an unlisted weapon, or on a listed weapon the save does not own, does not count.
	progress.weapon_mastery.clear()
	progress.weapon_mastery[&"merciful_iron"] = 9
	assert_false(CraftingRules.mastery_met(progress, craft))
	progress.weapon_mastery[&"reedbow"] = 3
	progress.owned_equipment.erase(&"reedbow")
	assert_false(CraftingRules.mastery_met(progress, craft))
	# Unknown, unoffered or wrong-weapon fitting ids are inert.
	progress.owned_equipment.append(&"reedbow")
	progress.add_recipe(CRAFT_ECHO)
	for saved in [&"fitting.unknown", &"merciful_grip"]:
		progress.weapon_fittings[&"pilgrims_edge"] = saved
		assert_empty(CraftingRules.active_modifications(progress, registry, &"pilgrims_edge", progress.weapon_fittings))
	progress.weapon_fittings[&"pilgrims_edge"] = ECHO
	assert_empty(CraftingRules.active_modifications(progress, registry, &"mire_maul", {&"mire_maul": ECHO}))
	# A registered fitting the weapon's kit does not offer stays inert too.
	var extra := DefinitionRegistry.load_default()
	var stray := ModificationDefinition.new()
	stray.id = &"fitting.stray"
	stray.display_name = "Stray"
	stray.description = "Test."
	stray.trait_source = extra.armor[&"storm_salt_charm"]
	stray.trait_id = &"grounding"
	extra.modifications[stray.id] = stray
	assert_empty(CraftingRules.active_modifications(progress, extra, &"pilgrims_edge", {&"pilgrims_edge": stray.id}),
		"only the fittings offered for the weapon take effect")
	assert_eq(CraftingRules.fit_check(progress, extra, &"pilgrims_edge", stray.id), CraftingResult.Reason.WRONG_WEAPON)
	# The campaign ids carry only the equipped weapon's active fitting.
	assert_eq(PreparationRules.battle_ids(progress, registry).modifications, ["fitting.hollow_echo"])
	progress.loadout_weapon = &"mire_maul"
	assert_eq(PreparationRules.battle_ids(progress, registry).modifications, [])


func test_an_older_kit_grandfathers_its_fittings_and_keeps_its_refund() -> void:
	# A save from before the revision: the kit bought for 2 Bog Iron, Merciful Grip installed.
	var progress := ProgressState.new()
	progress.add_recipe(KIT)
	progress.weapon_mastery[&"pilgrims_edge"] = 1
	progress.weapon_fittings[&"pilgrims_edge"] = GRIP
	progress.materials[&"bog_iron"] = 1
	# Both fittings the kit offered are owned through it, never charged again, and the installed
	# one still takes effect: nothing is lost or refunded by loading.
	for fitting_id: StringName in [GRIP, ECHO]:
		assert_eq(CraftingRules.fitting_owned_source(progress, registry, &"pilgrims_edge", fitting_id),
			CraftingRules.OWNED_LEGACY_KIT, String(fitting_id))
		assert_eq(CraftingRules.craft_check(progress, registry, fitting_id), CraftingResult.Reason.ALREADY_OWNED)
		assert_eq(CraftingRules.fit_check(progress, registry, &"pilgrims_edge", fitting_id), CraftingResult.Reason.OK)
	assert_eq(CraftingRules.active_modifications(progress, registry, &"pilgrims_edge", progress.weapon_fittings),
		[registry.modifications[GRIP]] as Array[ModificationDefinition])
	assert_eq(PreparationRules.battle_ids(progress, registry).modifications, ["fitting.merciful_grip"])
	# The kit can no longer be bought, by anyone.
	assert_eq(CraftingRules.purchase_check(ProgressState.new(), registry, KIT), CraftingResult.Reason.RECIPE_RETIRED)
	assert_eq(CraftingRules.purchase_check(progress, registry, KIT), CraftingResult.Reason.RECIPE_RETIRED)
	# The owner's refund right is unchanged: exactly the price, once; the kit, the fittings it
	# granted and the installed fitting go together.
	assert_eq(CraftingRules.refund_check(progress, registry, KIT), CraftingResult.Reason.OK)
	var refund := CraftingRules.refund(progress, registry.recipes[KIT], registry)
	assert_eq([progress.material_count(&"bog_iron"), (refund.refunded as Array)[0].count, refund.cleared], [3, 2, GRIP])
	assert_false(progress.has_recipe(KIT))
	assert_false(progress.weapon_fittings.has(&"pilgrims_edge"))
	assert_eq(CraftingRules.refund_check(progress, registry, KIT), CraftingResult.Reason.RECIPE_NOT_OWNED, "never twice")
	for fitting_id: StringName in [GRIP, ECHO]:
		assert_false(CraftingRules.fitting_owned(progress, registry, &"pilgrims_edge", fitting_id), String(fitting_id))
	# The refunded materials can then craft one fitting at the new price.
	assert_eq(CraftingRules.craft_check(progress, registry, ECHO), CraftingResult.Reason.OK)
	# A fitting crafted on its own survives the kit's refund, installed or not.
	var mixed := ProgressState.new()
	mixed.add_recipe(KIT)
	mixed.add_recipe(CRAFT_ECHO)
	mixed.weapon_fittings[&"pilgrims_edge"] = ECHO
	var kept := CraftingRules.refund(mixed, registry.recipes[KIT], registry)
	assert_eq([kept.cleared, mixed.weapon_fittings.get(&"pilgrims_edge"), mixed.crafting_recipes],
		[&"", ECHO, [CRAFT_ECHO] as Array[StringName]])
	assert_true(CraftingRules.fitting_owned(mixed, registry, &"pilgrims_edge", ECHO))
	assert_false(CraftingRules.fitting_owned(mixed, registry, &"pilgrims_edge", GRIP), "the kit's other fitting went with it")
	# Craft recipes and potion recipes are never refundable.
	for recipe_id: StringName in [CRAFT_GRIP, SALVE, MENDING]:
		assert_eq(CraftingRules.refund_check(mixed, registry, recipe_id), CraftingResult.Reason.NOT_REFUNDABLE, String(recipe_id))


func test_every_recipe_is_reachable_on_the_finite_route() -> void:
	# The whole route (5 Bog Iron, 1 Storm Salt) with the mastery gate met: any one recipe is
	# affordable, both fittings together fit, and the materials simply run out after that. Nothing
	# refills them.
	var progress := ProgressState.new()
	progress.weapon_mastery[&"pilgrims_edge"] = 1
	progress.materials = {&"bog_iron": 5, &"storm_salt": 1}
	for recipe_id: StringName in [CRAFT_GRIP, CRAFT_ECHO, SALVE, TINCTURE, MENDING, FLASK]:
		assert_eq(CraftingRules.purchase_check(progress, registry, recipe_id), CraftingResult.Reason.OK, String(recipe_id))
	CraftingRules.craft(progress, registry.recipes[CRAFT_GRIP])
	CraftingRules.craft(progress, registry.recipes[CRAFT_ECHO])
	assert_eq(progress.material_count(&"bog_iron"), 1, "both fittings cost 4 of the route's 5")
	SupplyRules.brew(progress, registry.recipes[MENDING])
	assert_eq(progress.material_count(&"bog_iron"), 0)
	for recipe_id: StringName in [SALVE, MENDING, FLASK]:
		assert_eq(CraftingRules.purchase_check(progress, registry, recipe_id), CraftingResult.Reason.INSUFFICIENT_MATERIALS,
			"%s: the route's iron is spent" % recipe_id)
	assert_eq(CraftingRules.purchase_check(progress, registry, TINCTURE), CraftingResult.Reason.OK, "the one Storm Salt remains")
	assert_eq(progress.materials.keys(), [&"storm_salt"], "a spent stack leaves no zero entry")


func test_duplicate_traits_are_found_only_when_a_fitting_doubles_one() -> void:
	var progress := ProgressState.new()
	progress.add_recipe(CRAFT_ECHO)
	progress.add_recipe(CRAFT_GRIP)
	progress.weapon_mastery[&"pilgrims_edge"] = 1
	progress.owned_equipment.append(&"hollow_reliquary")
	progress.loadout_relic = &"hollow_reliquary"
	progress.weapon_fittings[&"pilgrims_edge"] = ECHO
	assert_eq(CraftingRules.duplicate_trait(PreparationRules.battle_ids(progress, registry), registry), &"hollow_echo")
	progress.weapon_fittings[&"pilgrims_edge"] = GRIP
	assert_eq(CraftingRules.duplicate_trait(PreparationRules.battle_ids(progress, registry), registry), &"")
	progress.weapon_fittings[&"pilgrims_edge"] = ECHO
	progress.loadout_weapon = &"mire_maul"
	assert_eq(CraftingRules.duplicate_trait(PreparationRules.battle_ids(progress, registry), registry), &"",
		"an inactive fitting duplicates nothing")
	# Every shipped weapon and armor combination without a fitting reports nothing.
	for weapon_id: StringName in registry.weapons:
		for armor_id: StringName in registry.armor:
			var ids := ProgressState.new().loadout_ids()
			ids.weapon = String(weapon_id)
			ids[PreparationRules._KEYS[registry.armor[armor_id].slot]] = String(armor_id)
			assert_eq(CraftingRules.duplicate_trait(ids, registry), &"", "%s + %s" % [weapon_id, armor_id])


func test_saved_crafting_data_is_parsed_without_trusting_it() -> void:
	var data := ProgressState.new().to_dict()
	data.crafting = {"recipes": [3, null, "", KIT, String(KIT), "forge.future_kit", {"a": 1}],
		"fittings": {"pilgrims_edge": GRIP, "reedbow": 5, "": "x", "mire_maul": "", "future_blade": "fitting.future"}}
	var state := ProgressState.from_dict(data)
	assert_eq(state.crafting_recipes, [KIT, &"forge.future_kit"] as Array[StringName],
		"strings only, unique, sorted; unknown ids kept and inert")
	assert_eq(state.weapon_fittings.size(), 2, "string ids only")
	assert_eq([state.weapon_fittings[&"pilgrims_edge"], state.weapon_fittings[&"future_blade"]], [GRIP, &"fitting.future"])
	var round_trip := ProgressState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(_canonical(round_trip.to_dict()), _canonical(state.to_dict()), "sanitized data round-trips through JSON")
	for wrong: Variant in [5, "kit", [KIT], null]:
		var broken := ProgressState.from_dict({"crafting": wrong})
		assert_empty(broken.crafting_recipes)
		assert_true(broken.weapon_fittings.is_empty())
	var odd := ProgressState.from_dict({"crafting": {"recipes": {"forge.first_fitting": true}, "fittings": ["x"]}})
	assert_empty(odd.crafting_recipes, "a dictionary is not a recipe list")
	assert_true(odd.weapon_fittings.is_empty())
	# Older saves have no section: nothing is unlocked; New Game starts empty too.
	var older := ProgressState.new().to_dict()
	older.erase("crafting")
	assert_empty(ProgressState.from_dict(older).crafting_recipes)
	assert_empty(ProgressState.new().crafting_recipes)
	assert_eq(ProgressState.new().to_dict().crafting, {"recipes": [], "fittings": {}})
