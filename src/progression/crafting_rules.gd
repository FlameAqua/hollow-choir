class_name CraftingRules
extends RefCounted
## V0.5B home stations: the Forge's fittings and the Stillroom's potion recipes. Checks and changes,
## fitting ownership and compatibility, duplicate-trait checks, compatibility repair, the station
## readouts and the catalog checks. Pure: callers pass the progress and the registry they act on;
## WorldSession owns the station context (and its service, V0.5 UI) and every write. Practice, the
## Lab and static fixtures never read these: they keep auditioning every authored weapon and potion
## through PartyLoadout.from_ids().
##
## Playtest revision: each fitting is crafted on its own (RecipeDefinition.Kind.FITTING) and then
## fitted or removed for free; a save that bought the old kit keeps every fitting the kit offered.
## Potion recipes are brewed repeatedly into a finite stock (SupplyRules); a recipe is no longer an
## unlock, and a supply position needs a held dose to be prepared.

const SOURCE_STARTER := "Starter"
const SOURCE_RECIPE := "Stillroom recipe"
## How a fitting is owned (FittingReadout option.owned_source).
const OWNED_CRAFTED := &"crafted"
const OWNED_LEGACY_KIT := &"legacy_kit"
## Sockets shown around a fitting-capable weapon, and how many of them accept a fitting today. The
## rest are locked; no rule unlocks them yet (a future authored unlock goes in socket_capacity()).
const SOCKETS := 3
const SOCKET_CAPACITY := 1


# --- Station, recipes and mastery ----------------------------------------------------------------

## Would a station command for [param required] work run now, with [param service] the open
## station's service (V0.5 UI)? Only an open context of exactly that service authorizes it, and never
## during an encounter. Standing near a station, a saved anchor or the other station's context never
## does: brewing needs the Stillroom; crafting, fitting and kit refunds the Forge anvil.
static func availability(progress: ProgressState, service: LandmarkDefinition.Service,
		required: LandmarkDefinition.Service) -> CraftingResult.Reason:
	if service == LandmarkDefinition.Service.NONE:
		return CraftingResult.Reason.NO_STATION
	if progress.world.pending_entry != null:
		return CraftingResult.Reason.ENCOUNTER_PENDING
	if service != required:
		return CraftingResult.Reason.WRONG_STATION
	return CraftingResult.Reason.OK


## The station service that authorizes work on a recipe of [param station].
static func service_for(station: RecipeDefinition.Station) -> LandmarkDefinition.Service:
	if station == RecipeDefinition.Station.STILLROOM:
		return LandmarkDefinition.Service.STILLROOM
	return LandmarkDefinition.Service.FORGE


## Prepared supplies are a field choice (V0.5 UI, with equipment): rejected only during an encounter.
static func field_availability(progress: ProgressState) -> CraftingResult.Reason:
	if PreparationRules.availability(progress) == PreparationResult.Reason.ENCOUNTER_PENDING:
		return CraftingResult.Reason.ENCOUNTER_PENDING
	return CraftingResult.Reason.OK


## Approved recipes in display order: Forge first, then Stillroom, each by id.
static func recipes(registry: DefinitionRegistry) -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	for station: int in RecipeDefinition.Station.values():
		for id in registry.sorted_ids(registry.recipes):
			var recipe: RecipeDefinition = registry.recipes[id]
			if recipe.station == station:
				result.append(recipe)
	return result


## The best saved mastery among [param recipe]'s listed weapons that the save owns.
static func mastery(progress: ProgressState, recipe: RecipeDefinition) -> int:
	var best := 0
	for weapon in recipe.mastery_weapons:
		if weapon != null and progress.owned_equipment.has(weapon.id):
			best = maxi(best, progress.weapon_mastery.get(weapon.id, 0))
	return best


static func mastery_met(progress: ProgressState, recipe: RecipeDefinition) -> bool:
	return recipe.mastery_points <= 0 or mastery(progress, recipe) >= recipe.mastery_points


static func affordable(progress: ProgressState, recipe: RecipeDefinition) -> bool:
	for cost in recipe.costs:
		if cost == null or cost.material == null or progress.material_count(cost.material.id) < cost.count:
			return false
	return true


# --- Fittings: catalog, ownership and capacity -----------------------------------------------------

## The legacy fitting kit serving [param weapon_id] (owned or not), or null.
static func kit_for(registry: DefinitionRegistry, weapon_id: StringName) -> RecipeDefinition:
	for recipe in recipes(registry):
		if recipe.kind == RecipeDefinition.Kind.FITTING_KIT and recipe.weapon != null and recipe.weapon.id == weapon_id:
			return recipe
	return null


## The recipe that crafts [param fitting_id] (Kind.FITTING), or null.
static func fitting_recipe(registry: DefinitionRegistry, fitting_id: StringName) -> RecipeDefinition:
	for recipe in recipes(registry):
		if recipe.kind == RecipeDefinition.Kind.FITTING and recipe.fittings.size() == 1 \
				and recipe.fittings[0] != null and recipe.fittings[0].id == fitting_id:
			return recipe
	return null


## The approved fittings [param weapon_id] can hold, in a stable order: craftable ones by recipe id,
## then any a legacy kit offered that has no craft recipe. Empty = not a fitting-capable weapon.
static func weapon_fittings(registry: DefinitionRegistry, weapon_id: StringName) -> Array[ModificationDefinition]:
	var result: Array[ModificationDefinition] = []
	for recipe in recipes(registry):
		if recipe.kind == RecipeDefinition.Kind.FITTING and recipe.weapon != null and recipe.weapon.id == weapon_id:
			for fitting in recipe.fittings:
				if fitting != null and not result.has(fitting):
					result.append(fitting)
	var kit := kit_for(registry, weapon_id)
	if kit != null:
		for fitting in kit.fittings:
			if fitting != null and not result.has(fitting):
				result.append(fitting)
	return result


## Weapons that can hold a fitting, in id order.
static func fitting_weapons(registry: DefinitionRegistry) -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	for id in registry.sorted_ids(registry.weapons):
		if not weapon_fittings(registry, id).is_empty():
			result.append(registry.weapons[id])
	return result


## How this save owns [param fitting_id] for [param weapon_id]: OWNED_CRAFTED (its recipe is in the
## save), OWNED_LEGACY_KIT (an owned older kit offered it; grandfathered, never charged again) or
## &"" (not owned).
static func fitting_owned_source(progress: ProgressState, registry: DefinitionRegistry, weapon_id: StringName,
		fitting_id: StringName) -> StringName:
	var recipe := fitting_recipe(registry, fitting_id)
	if recipe != null and recipe.weapon != null and recipe.weapon.id == weapon_id and progress.has_recipe(recipe.id):
		return OWNED_CRAFTED
	var kit := kit_for(registry, weapon_id)
	if kit != null and progress.has_recipe(kit.id):
		for fitting in kit.fittings:
			if fitting != null and fitting.id == fitting_id:
				return OWNED_LEGACY_KIT
	return &""


static func fitting_owned(progress: ProgressState, registry: DefinitionRegistry, weapon_id: StringName,
		fitting_id: StringName) -> bool:
	return fitting_owned_source(progress, registry, weapon_id, fitting_id) != &""


## Usable sockets of [param weapon_id]: SOCKET_CAPACITY for a fitting-capable weapon, else 0.
## Derived, never saved; the seam for a future authored unlock.
static func socket_capacity(registry: DefinitionRegistry, weapon_id: StringName) -> int:
	return mini(SOCKET_CAPACITY, SOCKETS) if not weapon_fittings(registry, weapon_id).is_empty() else 0


## Can [param weapon_id] hold a fitting at all? OK, or WRONG_WEAPON when nothing is offered for it.
## Ownership is per fitting (fit_check); the mastery gate is paid when a fitting is crafted.
static func capacity(_progress: ProgressState, registry: DefinitionRegistry, weapon_id: StringName) -> CraftingResult.Reason:
	if socket_capacity(registry, weapon_id) <= 0:
		return CraftingResult.Reason.WRONG_WEAPON
	return CraftingResult.Reason.OK


static func socket_check(registry: DefinitionRegistry, weapon_id: StringName, socket: int) -> CraftingResult.Reason:
	if socket < 0 or socket >= SOCKETS:
		return CraftingResult.Reason.INVALID_SOCKET
	if socket >= socket_capacity(registry, weapon_id):
		return CraftingResult.Reason.LOCKED_SOCKET
	return CraftingResult.Reason.OK


## The fitting that takes effect on [param weapon_id] when it is equipped, given [param fittings]
## (weapon id -> fitting id): the installed id, if the weapon offers it and the save owns it.
## Unknown, unoffered or unowned saved ids stay inert. At most one today.
static func active_modifications(progress: ProgressState, registry: DefinitionRegistry, weapon_id: StringName,
		fittings: Dictionary) -> Array[ModificationDefinition]:
	var result: Array[ModificationDefinition] = []
	var installed := StringName(fittings.get(weapon_id, &""))
	if installed == &"":
		return result
	var registered: ModificationDefinition = registry.modifications.get(installed)
	if registered != null and weapon_fittings(registry, weapon_id).has(registered) \
			and fitting_owned(progress, registry, weapon_id, installed) and registered.resolved_trait() != null:
		result.append(registered)
	return result


## The trait id a modification in loadout [param ids] would duplicate (from the weapon, equipped
## armor or another modification), or &"" when none. Only duplicates involving a modification are
## reported; nothing is doubled, dropped or replaced here.
static func duplicate_trait(ids: Dictionary, registry: DefinitionRegistry) -> StringName:
	var loadout := PartyLoadout.from_ids(registry, ids)
	var seen := {}
	var items: Array[Resource] = [loadout.weapon]
	items.append_array(loadout.equipped_armor())
	for item in items:
		for trait_def: TraitDefinition in item.get("traits"):
			if trait_def != null and trait_def.id != &"":
				seen[trait_def.id] = true
	for modification in loadout.modifications:
		var trait_def := modification.resolved_trait()
		if trait_def == null or trait_def.id == &"":
			continue
		if seen.has(trait_def.id):
			return trait_def.id
		seen[trait_def.id] = true
	return &""


# --- Potions -------------------------------------------------------------------------------------

## The campaign's starter potions (the starter loadout's), in order.
static func starter_potions(registry: DefinitionRegistry) -> Array[PotionDefinition]:
	var result: Array[PotionDefinition] = []
	if registry.defaults != null and registry.defaults.starter_loadout != null:
		for potion in registry.defaults.starter_loadout.potions:
			if potion != null and not result.has(potion):
				result.append(potion)
	return result


## The Stillroom recipe that brews [param potion_id], or null.
static func potion_recipe(registry: DefinitionRegistry, potion_id: StringName) -> RecipeDefinition:
	for recipe in recipes(registry):
		if recipe.kind == RecipeDefinition.Kind.POTION and recipe.potion != null and recipe.potion.id == potion_id:
			return recipe
	return null


## Campaign potions in display order: the starters, then each recipe's potion by recipe id.
static func campaign_potions(registry: DefinitionRegistry) -> Array[PotionDefinition]:
	var result := starter_potions(registry)
	for recipe in recipes(registry):
		if recipe.kind == RecipeDefinition.Kind.POTION and recipe.potion != null and not result.has(recipe.potion):
			result.append(recipe.potion)
	return result


## Kept for older callers: the save holds at least one dose of [param potion_id] (playtest revision:
## a recipe is no longer an unlock).
static func potion_unlocked(progress: ProgressState, _registry: DefinitionRegistry, potion_id: StringName) -> bool:
	return progress.supply_count(potion_id) > 0


## A copy of loadout [param ids] with potion slot [param slot_index] set to [param potion_id]
## (appended when the saved list is shorter than that slot).
static func with_potion(ids: Dictionary, slot_index: int, potion_id: StringName) -> Dictionary:
	var result := ids.duplicate(true)
	var potions: Array = result.get("potions", []) if typeof(result.get("potions")) == TYPE_ARRAY else []
	if slot_index < potions.size():
		potions[slot_index] = String(potion_id)
	else:
		potions.append(String(potion_id))
	result["potions"] = potions
	return result


# --- Command checks (pure; nothing changes) -------------------------------------------------------

## Legacy entry point (older callers and the overlap): the check of whatever purchase() now does for
## this recipe's kind. A potion recipe is brewed, a fitting recipe crafted, and an older fitting kit
## can no longer be bought.
static func purchase_check(progress: ProgressState, registry: DefinitionRegistry, recipe_id: StringName) -> CraftingResult.Reason:
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	if recipe == null:
		return CraftingResult.Reason.UNKNOWN_RECIPE
	match recipe.kind:
		RecipeDefinition.Kind.POTION:
			return SupplyRules.brew_check(progress, registry, recipe_id)
		RecipeDefinition.Kind.FITTING:
			return craft_check(progress, registry, recipe.fittings[0].id if recipe.fittings.size() == 1 \
				and recipe.fittings[0] != null else &"")
	return CraftingResult.Reason.RECIPE_RETIRED


## Crafting [param fitting_id]: an approved fitting with a craft recipe, for a weapon the save owns,
## not owned yet (crafted or through an older kit), with the recipe's mastery met and its whole
## price held.
static func craft_check(progress: ProgressState, registry: DefinitionRegistry, fitting_id: StringName) -> CraftingResult.Reason:
	if not registry.modifications.has(fitting_id):
		return CraftingResult.Reason.UNKNOWN_FITTING
	var recipe := fitting_recipe(registry, fitting_id)
	if recipe == null or recipe.weapon == null:
		return CraftingResult.Reason.UNKNOWN_RECIPE
	if not progress.owned_equipment.has(recipe.weapon.id):
		return CraftingResult.Reason.WEAPON_NOT_OWNED
	if fitting_owned(progress, registry, recipe.weapon.id, fitting_id):
		return CraftingResult.Reason.ALREADY_OWNED
	if not mastery_met(progress, recipe):
		return CraftingResult.Reason.MASTERY_REQUIRED
	if not affordable(progress, recipe):
		return CraftingResult.Reason.INSUFFICIENT_MATERIALS
	return CraftingResult.Reason.OK


## A refund returns the complete price or nothing: a cost that would push a stack past
## MaterialDefinition.MAX_COUNT rejects the whole refund instead of saturating it away. Only an
## owned legacy kit is refundable.
static func refund_check(progress: ProgressState, registry: DefinitionRegistry, recipe_id: StringName) -> CraftingResult.Reason:
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	if recipe == null:
		return CraftingResult.Reason.UNKNOWN_RECIPE
	if not recipe.refundable:
		return CraftingResult.Reason.NOT_REFUNDABLE
	if not progress.has_recipe(recipe_id):
		return CraftingResult.Reason.RECIPE_NOT_OWNED
	for cost in recipe.costs:
		if cost != null and cost.material != null and \
				progress.material_count(cost.material.id) + cost.count > MaterialDefinition.MAX_COUNT:
			return CraftingResult.Reason.REFUND_OVERFLOW
	return CraftingResult.Reason.OK


## Checks fitting [param modification_id] into [param socket] of [param weapon_id] (&"" removes it).
## The duplicate-trait and action checks use the loadout the command would produce for the next
## encounter.
static func fit_check(progress: ProgressState, registry: DefinitionRegistry, weapon_id: StringName,
		modification_id: StringName, socket: int = 0) -> CraftingResult.Reason:
	if not registry.weapons.has(weapon_id) or weapon_fittings(registry, weapon_id).is_empty():
		return CraftingResult.Reason.WRONG_WEAPON
	var socket_reason := socket_check(registry, weapon_id, socket)
	if socket_reason != CraftingResult.Reason.OK:
		return socket_reason
	if not progress.owned_equipment.has(weapon_id):
		return CraftingResult.Reason.WEAPON_NOT_OWNED
	if modification_id == &"":
		return CraftingResult.Reason.OK
	var modification: ModificationDefinition = registry.modifications.get(modification_id)
	if modification == null:
		return CraftingResult.Reason.UNKNOWN_FITTING
	if not weapon_fittings(registry, weapon_id).has(modification):
		return CraftingResult.Reason.WRONG_WEAPON
	if not fitting_owned(progress, registry, weapon_id, modification_id):
		return CraftingResult.Reason.FITTING_NOT_OWNED
	var fittings := progress.weapon_fittings.duplicate()
	fittings[weapon_id] = modification_id
	var ids := PreparationRules.campaign_ids(progress, registry, progress.loadout_ids(), fittings)
	if duplicate_trait(ids, registry) != &"":
		return CraftingResult.Reason.DUPLICATE_TRAIT
	if not PreparationRules.fits(ids, registry):
		return CraftingResult.Reason.ACTION_LIMIT
	return CraftingResult.Reason.OK


## Preparing [param potion_id] in supply position [param slot_index]: a usable position, an
## approved potion, at least one held dose and not already in another position. Re-choosing what
## the position already holds is always accepted (the command then writes nothing), even at zero
## doses.
static func potion_check(progress: ProgressState, registry: DefinitionRegistry, slot_index: int,
		potion_id: StringName) -> CraftingResult.Reason:
	if slot_index < 0 or slot_index >= SupplyRules.capacity():
		return CraftingResult.Reason.INVALID_POTION_SLOT
	if not registry.potions.has(potion_id):
		return CraftingResult.Reason.UNKNOWN_POTION
	if slot_index < progress.loadout_potions.size() and progress.loadout_potions[slot_index] == potion_id:
		return CraftingResult.Reason.OK
	for index in progress.loadout_potions.size():
		if index != slot_index and progress.loadout_potions[index] == potion_id:
			return CraftingResult.Reason.DUPLICATE_POTION
	if progress.supply_count(potion_id) <= 0:
		return CraftingResult.Reason.NO_STOCK
	var ids := PreparationRules.campaign_ids(progress, registry,
		with_potion(progress.loadout_ids(), slot_index, potion_id), progress.weapon_fittings)
	if not PreparationRules.fits(ids, registry):
		return CraftingResult.Reason.ACTION_LIMIT
	return CraftingResult.Reason.OK


# --- Changes (applied to a WorldSession candidate after a passing check) --------------------------

## Spends [param recipe]'s whole price. Returns the spent receipt lines.
static func spend(progress: ProgressState, recipe: RecipeDefinition) -> Array[Dictionary]:
	var spent: Array[Dictionary] = []
	for cost in recipe.costs:
		var held := progress.material_count(cost.material.id)
		var left := held - cost.count
		if left > 0:
			progress.materials[cost.material.id] = left
		else:
			progress.materials.erase(cost.material.id)
		spent.append(_receipt_line(cost, maxi(left, 0)))
	return spent


## Crafts the fitting of [param recipe] (Kind.FITTING): spends the price and records ownership.
static func craft(progress: ProgressState, recipe: RecipeDefinition) -> Array[Dictionary]:
	var spent := spend(progress, recipe)
	progress.add_recipe(recipe.id)
	return spent


## Returns the complete price and clears the legacy kit's ownership. With the kit gone, an installed
## fitting the save no longer owns (it was the kit's) is cleared in the same write; one the player
## crafted separately stays. Mastery, the weapon and owned equipment are untouched. Returns
## {"refunded": Array[Dictionary], "cleared": StringName (the removed fitting id or &"")}.
static func refund(progress: ProgressState, recipe: RecipeDefinition, registry: DefinitionRegistry = null) -> Dictionary:
	var refunded: Array[Dictionary] = []
	for cost in recipe.costs:
		var total := progress.material_count(cost.material.id) + cost.count
		progress.materials[cost.material.id] = total
		refunded.append(_receipt_line(cost, total))
	progress.remove_recipe(recipe.id)
	var cleared: StringName = &""
	if recipe.kind == RecipeDefinition.Kind.FITTING_KIT and recipe.weapon != null:
		var installed: StringName = progress.weapon_fittings.get(recipe.weapon.id, &"")
		if installed != &"" and (registry == null or not fitting_owned(progress, registry, recipe.weapon.id, installed)):
			cleared = installed
			progress.weapon_fittings.erase(recipe.weapon.id)
	return {"refunded": refunded, "cleared": cleared}


## Installs [param modification_id] on [param weapon_id] (&"" removes the fitting).
static func set_fitting(progress: ProgressState, weapon_id: StringName, modification_id: StringName) -> void:
	if modification_id == &"":
		progress.weapon_fittings.erase(weapon_id)
	else:
		progress.weapon_fittings[weapon_id] = modification_id


static func set_potion(progress: ProgressState, slot_index: int, potion_id: StringName) -> void:
	if slot_index < progress.loadout_potions.size():
		progress.loadout_potions[slot_index] = potion_id
	else:
		progress.loadout_potions.append(potion_id)


static func _receipt_line(cost: MaterialCost, total: int) -> Dictionary:
	return {"id": cost.material.id, "name": cost.material.display_name,
		"icon_path": cost.material.icon.resource_path if cost.material.icon != null else "",
		"count": cost.count, "total": total}


# --- Compatibility repair (WorldSession.reconcile, never a deserializer) -------------------------

## Repairs the saved potion slots and fitting after PreparationRules has repaired the equipment.
## - An unknown potion id is replaced by the first starter not already prepared (or removed when
##   none is left); entries beyond the usable supply positions are removed. A prepared approved
##   potion always stays prepared, with or without stock (SupplyRules.migrate grants an older
##   save's bounded stock afterwards).
## - A fitting whose trait the equipped gear already supplies is removed (never the gear).
## Unknown recipe and fitting ids stay in the save, inert. Returns one line per repair.
static func repair(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	var repairs := _repair_potions(progress, registry)
	var duplicate := duplicate_trait(PreparationRules.battle_ids(progress, registry), registry)
	if duplicate != &"":
		var weapon_id := progress.loadout_weapon
		var removed: StringName = progress.weapon_fittings.get(weapon_id, &"")
		progress.weapon_fittings.erase(weapon_id)
		repairs.append("the %s fitting on %s duplicated trait %s from other equipment; the fitting was removed" % [
			removed, weapon_id, duplicate])
	return repairs


static func _repair_potions(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	var repairs := PackedStringArray()
	var slots: Array = []
	var unknown: Array[StringName] = []
	for potion_id in progress.loadout_potions:
		if slots.size() >= SupplyRules.capacity():
			repairs.append("potion '%s' is beyond the %d potion slots; it was removed" % [potion_id,
				SupplyRules.capacity()])
			continue
		if not registry.potions.has(potion_id):
			slots.append(null)
			unknown.append(potion_id)
			continue
		if slots.has(potion_id):
			repairs.append("potion %s was prepared twice; the second position is empty now" % potion_id)
			continue
		slots.append(potion_id)
	var next_unknown := 0
	for index in slots.size():
		if slots[index] != null:
			continue
		var replacement: StringName = &""
		for potion in starter_potions(registry):
			if not slots.has(potion.id):
				replacement = potion.id
				break
		var old_id := unknown[next_unknown]
		next_unknown += 1
		if replacement != &"":
			slots[index] = replacement
			repairs.append("potion '%s' is not approved content; %s is prepared instead" % [old_id, replacement])
		else:
			repairs.append("potion '%s' is not approved content; the slot is empty now" % old_id)
	if not repairs.is_empty():
		var kept: Array[StringName] = []
		for entry in slots:
			if entry != null:
				kept.append(entry)
		progress.loadout_potions = kept
	return repairs


# --- Readouts ------------------------------------------------------------------------------------

## The station readout for [param station_id] offering [param service] (&"" / NONE = no station
## interaction open). Each recipe and fitting carries the availability of its own service here;
## supply positions carry the field availability.
static func readout(progress: ProgressState, registry: DefinitionRegistry, station_id: StringName,
		service: LandmarkDefinition.Service = LandmarkDefinition.Service.NONE) -> CraftingReadout:
	var result := CraftingReadout.new()
	result.station_id = station_id
	result.service = service
	result.reason = availability(progress, service, service)
	result.reason_text = reason_text(result.reason)
	result.materials = PreparationRules.held_materials(progress, registry)
	result.ingredients = PreparationRules.ingredient_catalog(progress, registry)
	for recipe in recipes(registry):
		var available := availability(progress, service, service_for(recipe.station))
		result.recipes.append(recipe_readout(progress, registry, recipe, available))
	var forge := availability(progress, service, LandmarkDefinition.Service.FORGE)
	for weapon in fitting_weapons(registry):
		result.fittings.append(fitting_readout(progress, registry, weapon, forge))
	result.supplies = SupplyRules.slot_readouts(progress, registry, field_availability(progress))
	for entry in result.supplies:
		if not entry.locked:
			result.potion_slots.append(entry)
	result.stock = SupplyRules.stock(progress, registry)
	result.potion_capacity = SupplyRules.capacity()
	result.fitting_capacity = SOCKET_CAPACITY
	result.locked_reason_text = WorldCopy.COMBAT_LOCKED_POSITION
	var counts := PreparationRules.action_counts(PreparationRules.battle_ids(progress, registry), registry)
	result.protagonist_actions = counts.protagonist
	result.companion_actions = counts.companion
	return result


## Material price lines against the held materials: [{id, name, icon_path, count, held, enough}].
static func cost_lines(progress: ProgressState, recipe: RecipeDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cost in recipe.costs:
		if cost == null or cost.material == null:
			continue
		var held := progress.material_count(cost.material.id)
		result.append({"id": cost.material.id, "name": cost.material.display_name,
			"icon_path": cost.material.icon.resource_path if cost.material.icon != null else "",
			"count": cost.count, "held": held, "enough": held >= cost.count})
	return result


## One recipe for the live save; [param available] is the availability of its service here.
static func recipe_readout(progress: ProgressState, registry: DefinitionRegistry, recipe: RecipeDefinition,
		available: CraftingResult.Reason) -> RecipeReadout:
	var result := RecipeReadout.new()
	result.id = recipe.id
	result.station = recipe.station
	result.station_label = EnumText.station(recipe.station)
	result.kind = recipe.kind
	result.name = recipe.display_name
	result.description = recipe.description
	result.costs = cost_lines(progress, recipe)
	for cost in result.costs:
		if recipe.kind == RecipeDefinition.Kind.POTION:
			result.reagents.append(cost.name)
		if recipe.refundable:
			result.refund.append({"id": cost.id, "name": cost.name, "icon_path": cost.icon_path,
				"count": cost.count, "held": cost.held, "total": int(cost.held) + int(cost.count)})
	result.base_name = recipe.base_name
	result.base_description = recipe.base_description
	result.mastery_required = recipe.mastery_points
	result.mastery_current = mastery(progress, recipe)
	result.mastery_met = mastery_met(progress, recipe)
	for weapon in recipe.mastery_weapons:
		if weapon != null:
			result.mastery_weapons.append(weapon.display_name)
	result.owned = progress.has_recipe(recipe.id)
	result.refundable = recipe.refundable
	result.retired = recipe.kind == RecipeDefinition.Kind.FITTING_KIT
	result.repeatable = recipe.kind == RecipeDefinition.Kind.POTION
	result.purchase_reason = available
	if available == CraftingResult.Reason.OK:
		result.purchase_reason = purchase_check(progress, registry, recipe.id)
	result.can_purchase = result.purchase_reason == CraftingResult.Reason.OK
	result.purchase_reason_text = reason_text(result.purchase_reason, recipe)
	result.refund_reason = available
	if available == CraftingResult.Reason.OK:
		result.refund_reason = refund_check(progress, registry, recipe.id)
	result.can_refund = result.refund_reason == CraftingResult.Reason.OK
	result.refund_reason_text = reason_text(result.refund_reason, recipe)
	if recipe.kind != RecipeDefinition.Kind.POTION and recipe.weapon != null:
		result.weapon_id = recipe.weapon.id
		result.weapon_name = recipe.weapon.display_name
		for fitting in recipe.fittings:
			if fitting != null:
				result.fittings.append(_fitting_facts(fitting))
		if recipe.kind == RecipeDefinition.Kind.FITTING and recipe.fittings.size() == 1 and recipe.fittings[0] != null:
			result.owned = fitting_owned(progress, registry, recipe.weapon.id, recipe.fittings[0].id)
	elif recipe.kind == RecipeDefinition.Kind.POTION and recipe.potion != null:
		var potion := recipe.potion
		result.potion_id = potion.id
		result.potion_name = potion.display_name
		result.potion_description = potion.description
		result.potion_charges = potion.charges
		result.potion_icon_path = potion.icon.resource_path if potion.icon != null else ""
		result.yield_count = recipe.yield_count
		result.potion_held = progress.supply_count(potion.id)
		result.potion_cap = potion.charges
		result.potion_total_after = result.potion_held + recipe.yield_count
		result.brew_reason = result.purchase_reason
		result.can_brew = result.can_purchase
		result.brew_reason_text = result.purchase_reason_text
	return result


## One fitting-capable weapon for the live save; [param available] is the Forge's availability here.
static func fitting_readout(progress: ProgressState, registry: DefinitionRegistry, weapon: WeaponDefinition,
		available: CraftingResult.Reason) -> FittingReadout:
	var result := FittingReadout.new()
	result.weapon_id = weapon.id
	result.weapon_name = weapon.display_name
	result.weapon_icon_path = weapon.icon.resource_path if weapon.icon != null else ""
	result.weapon_equipped = progress.loadout_weapon == weapon.id
	var kit := kit_for(registry, weapon.id)
	result.kit_id = kit.id if kit != null else &""
	result.kit_owned = kit != null and progress.has_recipe(kit.id)
	result.capacity_reason = capacity(progress, registry, weapon.id)
	result.capacity = result.capacity_reason == CraftingResult.Reason.OK
	result.capacity_reason_text = reason_text(result.capacity_reason)
	result.socket_capacity = socket_capacity(registry, weapon.id)
	var offered := weapon_fittings(registry, weapon.id)
	var saved: StringName = progress.weapon_fittings.get(weapon.id, &"")
	var installed: ModificationDefinition = registry.modifications.get(saved)
	if installed != null and offered.has(installed):
		result.installed_id = installed.id
		result.installed_name = installed.display_name
	result.active = result.weapon_equipped and \
		not active_modifications(progress, registry, weapon.id, progress.weapon_fittings).is_empty()
	result.can_remove = saved != &"" and available == CraftingResult.Reason.OK and \
		fit_check(progress, registry, weapon.id, &"") == CraftingResult.Reason.OK
	for index in SOCKETS:
		var locked := index >= result.socket_capacity
		result.sockets.append({"index": index, "locked": locked,
			"reason": CraftingResult.Reason.LOCKED_SOCKET if locked else CraftingResult.Reason.OK,
			"reason_text": reason_text(CraftingResult.Reason.LOCKED_SOCKET) if locked else "",
			"fitting_id": result.installed_id if index == 0 else &"",
			"fitting_name": result.installed_name if index == 0 else ""})
	for trait_def in weapon.traits:
		if trait_def != null:
			result.base_traits.append({"name": trait_def.display_name, "description": trait_def.description})
	for fitting in offered:
		result.options.append(_fitting_option(progress, registry, weapon, fitting, saved, available))
	if kit != null:
		var refund_reason := available
		if refund_reason == CraftingResult.Reason.OK:
			refund_reason = refund_check(progress, registry, kit.id)
		var refund_lines: Array[Dictionary] = []
		for cost in cost_lines(progress, kit):
			refund_lines.append({"id": cost.id, "name": cost.name, "icon_path": cost.icon_path, "count": cost.count,
				"held": cost.held, "total": int(cost.held) + int(cost.count)})
		result.legacy_kit = {"id": kit.id, "name": kit.display_name, "owned": result.kit_owned,
			"can_refund": refund_reason == CraftingResult.Reason.OK, "refund_reason": refund_reason,
			"refund_reason_text": reason_text(refund_reason, kit), "refund": refund_lines}
	return result


static func _fitting_option(progress: ProgressState, registry: DefinitionRegistry, weapon: WeaponDefinition,
		fitting: ModificationDefinition, saved: StringName, available: CraftingResult.Reason) -> Dictionary:
	var entry := _fitting_facts(fitting)
	var fit_reason := available
	if fit_reason == CraftingResult.Reason.OK:
		fit_reason = fit_check(progress, registry, weapon.id, fitting.id)
	var recipe := fitting_recipe(registry, fitting.id)
	var craft_reason := available
	if craft_reason == CraftingResult.Reason.OK:
		craft_reason = craft_check(progress, registry, fitting.id)
	var owned_source := fitting_owned_source(progress, registry, weapon.id, fitting.id)
	var fittings := progress.weapon_fittings.duplicate()
	fittings[weapon.id] = fitting.id
	var ids := PreparationRules.campaign_ids(progress, registry,
		PreparationRules.with_item(progress.loadout_ids(), Enums.EquipSlot.WEAPON, weapon.id), fittings)
	var is_installed := saved == fitting.id
	var can_fit := fit_reason == CraftingResult.Reason.OK
	var can_craft := craft_reason == CraftingResult.Reason.OK
	var can_remove := is_installed and available == CraftingResult.Reason.OK and \
		fit_check(progress, registry, weapon.id, &"") == CraftingResult.Reason.OK
	# The one primary command the option offers now: Remove what is installed, Fit what is owned,
	# Craft what is not (the reason fields say why a shown command is disabled).
	var action := &"none"
	if is_installed:
		action = &"remove"
	elif owned_source != &"":
		action = &"fit"
	elif recipe != null:
		action = &"craft"
	entry.merge({"installed": is_installed, "selectable": can_fit, "reason": fit_reason,
		"reason_text": reason_text(fit_reason, recipe),
		"actions": int(PreparationRules.action_counts(ids, registry).protagonist),
		"owned": owned_source != &"", "owned_source": owned_source,
		"recipe_id": recipe.id if recipe != null else &"",
		"costs": cost_lines(progress, recipe) if recipe != null else [] as Array[Dictionary],
		"mastery_required": recipe.mastery_points if recipe != null else 0,
		"mastery_current": mastery(progress, recipe) if recipe != null else 0,
		"mastery_met": recipe == null or mastery_met(progress, recipe),
		"can_craft": can_craft, "craft_reason": craft_reason, "craft_reason_text": reason_text(craft_reason, recipe),
		"can_fit": can_fit, "can_remove": can_remove, "action": action})
	return entry


static func _fitting_facts(fitting: ModificationDefinition) -> Dictionary:
	var trait_def := fitting.resolved_trait()
	var facts := {"id": trait_def.id, "name": trait_def.display_name, "description": trait_def.description,
		"details": trait_def.details} if trait_def != null else {}
	return {"id": fitting.id, "name": fitting.display_name, "description": fitting.description,
		"source": fitting.source_name(), "trait": facts}


## Public wording for [param reason]; [param recipe] fills mastery and refund facts when given.
static func reason_text(reason: CraftingResult.Reason, recipe: RecipeDefinition = null) -> String:
	match reason:
		CraftingResult.Reason.NO_STATION:
			return WorldCopy.CRAFT_NO_STATION
		CraftingResult.Reason.WRONG_STATION:
			if recipe != null and recipe.station == RecipeDefinition.Station.STILLROOM:
				return WorldCopy.CRAFT_WRONG_STATION_STILLROOM
			return WorldCopy.CRAFT_WRONG_STATION_FORGE
		CraftingResult.Reason.ENCOUNTER_PENDING:
			return WorldCopy.CRAFT_ENCOUNTER_PENDING
		CraftingResult.Reason.UNKNOWN_RECIPE:
			return WorldCopy.CRAFT_UNKNOWN_RECIPE
		CraftingResult.Reason.ALREADY_OWNED:
			return WorldCopy.CRAFT_FITTING_OWNED
		CraftingResult.Reason.RECIPE_NOT_OWNED:
			return WorldCopy.CRAFT_RECIPE_NOT_OWNED
		CraftingResult.Reason.INSUFFICIENT_MATERIALS:
			return WorldCopy.CRAFT_INSUFFICIENT
		CraftingResult.Reason.MASTERY_REQUIRED:
			if recipe == null:
				return WorldCopy.CRAFT_MASTERY_REQUIRED % [0, ""]
			var names := PackedStringArray()
			for weapon in recipe.mastery_weapons:
				if weapon != null:
					names.append(weapon.display_name)
			return WorldCopy.CRAFT_MASTERY_REQUIRED % [recipe.mastery_points, _either(names)]
		CraftingResult.Reason.NOT_REFUNDABLE:
			return WorldCopy.CRAFT_NOT_REFUNDABLE_NOW
		CraftingResult.Reason.REFUND_OVERFLOW:
			return WorldCopy.CRAFT_REFUND_OVERFLOW % MaterialDefinition.MAX_COUNT
		CraftingResult.Reason.UNKNOWN_FITTING:
			return WorldCopy.CRAFT_UNKNOWN_FITTING
		CraftingResult.Reason.WRONG_WEAPON:
			return WorldCopy.CRAFT_WRONG_WEAPON
		CraftingResult.Reason.WEAPON_NOT_OWNED:
			return WorldCopy.CRAFT_WEAPON_NOT_OWNED
		CraftingResult.Reason.NO_FITTING_CAPACITY:
			return WorldCopy.CRAFT_NO_CAPACITY
		CraftingResult.Reason.DUPLICATE_TRAIT:
			return WorldCopy.CRAFT_DUPLICATE_TRAIT
		CraftingResult.Reason.ACTION_LIMIT:
			return WorldCopy.PREP_ACTION_LIMIT % PartyLoadout.MAX_ACTIONS
		CraftingResult.Reason.UNKNOWN_POTION:
			return WorldCopy.CRAFT_UNKNOWN_POTION
		CraftingResult.Reason.POTION_LOCKED:
			return WorldCopy.CRAFT_POTION_LOCKED
		CraftingResult.Reason.DUPLICATE_POTION:
			return WorldCopy.CRAFT_DUPLICATE_POTION
		CraftingResult.Reason.INVALID_POTION_SLOT:
			return WorldCopy.CRAFT_INVALID_POTION_SLOT % SupplyRules.capacity()
		CraftingResult.Reason.WRITE_FAILED:
			return WorldCopy.SAVE_FAILED_TITLE
		CraftingResult.Reason.STOCK_OVERFLOW:
			return WorldCopy.CRAFT_STOCK_OVERFLOW % PotionDefinition.MAX_STOCK
		CraftingResult.Reason.NO_STOCK:
			return WorldCopy.CRAFT_NO_STOCK
		CraftingResult.Reason.RECIPE_RETIRED:
			return WorldCopy.CRAFT_RECIPE_RETIRED
		CraftingResult.Reason.FITTING_NOT_OWNED:
			return WorldCopy.CRAFT_FITTING_NOT_OWNED
		CraftingResult.Reason.INVALID_SOCKET:
			return WorldCopy.CRAFT_INVALID_SOCKET
		CraftingResult.Reason.LOCKED_SOCKET:
			return WorldCopy.CRAFT_LOCKED_SOCKET
		CraftingResult.Reason.NOT_BREWABLE:
			return WorldCopy.CRAFT_NOT_BREWABLE
	return ""


## "A", "A or B", "A, B or C".
static func _either(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


# --- Catalog -------------------------------------------------------------------------------------

## Cross-definition checks for DefinitionRegistry.validate(): every recipe and fitting names
## registered definitions; one legacy kit per weapon, one craft recipe per fitting and one brew
## recipe per potion; every fitting is craftable; a craft recipe's weapon agrees with the legacy kit
## that offered the same fitting; and the reachability invariant: each recipe alone costs no more of
## each material than the authored rewards grant in total, so every recipe can be afforded at least
## once on the authored route (playtest revision: brewing is repeatable, so the old "all recipes
## together" budget no longer applies).
static func validate_catalog(registry: DefinitionRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var kit_weapons := {}
	var recipe_potions := {}
	var crafted := {}
	var budget: Dictionary[StringName, int] = {}
	for reward: RewardDefinition in registry.rewards.values():
		for item in reward.items:
			if item != null and item.kind == RewardItem.Kind.MATERIAL and item.material != null:
				budget[item.material.id] = budget.get(item.material.id, 0) + maxi(item.count, 0)
	for recipe in recipes(registry):
		for cost in recipe.costs:
			if cost == null or cost.material == null:
				continue
			if registry.materials.get(cost.material.id) != cost.material:
				problems.append("recipe %s: material %s is not a registered data/ definition" % [recipe.id, cost.material.id])
			if recipe.kind != RecipeDefinition.Kind.FITTING_KIT and cost.count > budget.get(cost.material.id, 0):
				problems.append("recipe %s costs %d %s, above the %d the authored rewards grant" % [
					recipe.id, cost.count, cost.material.id, budget.get(cost.material.id, 0)])
		for weapon in recipe.mastery_weapons:
			if weapon != null and registry.weapons.get(weapon.id) != weapon:
				problems.append("recipe %s: mastery weapon %s is not a registered data/ definition" % [recipe.id, weapon.id])
		if recipe.kind != RecipeDefinition.Kind.POTION and recipe.weapon != null:
			if registry.weapons.get(recipe.weapon.id) != recipe.weapon:
				problems.append("recipe %s: weapon %s is not a registered data/ definition" % [recipe.id, recipe.weapon.id])
			if recipe.kind == RecipeDefinition.Kind.FITTING_KIT:
				if kit_weapons.has(recipe.weapon.id):
					problems.append("weapon %s has two fitting kits (%s, %s)" % [recipe.weapon.id, kit_weapons[recipe.weapon.id], recipe.id])
				kit_weapons[recipe.weapon.id] = recipe.id
			for fitting in recipe.fittings:
				if fitting == null:
					continue
				if registry.modifications.get(fitting.id) != fitting:
					problems.append("recipe %s: fitting %s is not a registered data/ definition" % [recipe.id, fitting.id])
				if recipe.kind == RecipeDefinition.Kind.FITTING:
					if crafted.has(fitting.id):
						problems.append("fitting %s has two craft recipes (%s, %s)" % [fitting.id, crafted[fitting.id], recipe.id])
					crafted[fitting.id] = recipe.id
		elif recipe.kind == RecipeDefinition.Kind.POTION and recipe.potion != null:
			if registry.potions.get(recipe.potion.id) != recipe.potion:
				problems.append("recipe %s: potion %s is not a registered data/ definition" % [recipe.id, recipe.potion.id])
			if recipe_potions.has(recipe.potion.id):
				problems.append("potion %s has two recipes (%s, %s)" % [recipe.potion.id, recipe_potions[recipe.potion.id], recipe.id])
			recipe_potions[recipe.potion.id] = recipe.id
	for recipe in recipes(registry):
		if recipe.kind != RecipeDefinition.Kind.FITTING_KIT or recipe.weapon == null:
			continue
		for fitting in recipe.fittings:
			var craft_recipe := fitting_recipe(registry, fitting.id) if fitting != null else null
			if craft_recipe != null and craft_recipe.weapon != recipe.weapon:
				problems.append("fitting %s is crafted for %s but the legacy kit %s offered it for %s" % [
					fitting.id, craft_recipe.weapon.id if craft_recipe.weapon != null else &"", recipe.id, recipe.weapon.id])
	for id in registry.sorted_ids(registry.modifications):
		var fitting: ModificationDefinition = registry.modifications[id]
		var source: Resource = fitting.trait_source
		if source != null and registry.weapons.get(StringName(source.get("id"))) != source and \
				registry.armor.get(StringName(source.get("id"))) != source:
			problems.append("fitting %s: its trait source is not a registered data/ definition" % id)
		if not crafted.has(id):
			problems.append("fitting %s has no craft recipe" % id)
	for id in registry.sorted_ids(registry.potions):
		var potion: PotionDefinition = registry.potions[id]
		if potion.starter_stock > 0 and not starter_potions(registry).has(potion):
			problems.append("potion %s has starter stock but is not in the starter loadout" % id)
	for potion in campaign_potions(registry):
		if not recipe_potions.has(potion.id):
			problems.append("campaign potion %s has no brew recipe" % potion.id)
	return problems
