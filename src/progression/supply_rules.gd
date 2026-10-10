class_name SupplyRules
extends RefCounted
## Playtest revision: finite supplies. A campaign save holds a stock of doses per potion
## (ProgressState.consumables). Four things are kept apart:
## - the recipe (data; brewing is open to every save at the Stillroom, subject to its mastery gate),
## - the stock (saved doses; brewing adds a recipe's yield, a saved victory removes what it used),
## - the prepared choice (which potion a supply position holds; it survives an empty stock),
## - the allowance (what one battle starts with: min(per-encounter cap, held), captured by the
##   encounter entry and identical on every retry of it).
## Pure: callers pass the progress and the registry; WorldSession owns every write. Practice, the Lab
## and static loadouts never read the stock: they keep the potions' authored charges.

## The one-time migration that introduces the stock to a save (ProgressState.migrations).
const MIGRATION := &"supplies.finite_stock.v1"
## Supply positions shown; capacity() of them are usable and the rest are locked.
const POSITIONS := 4


## Usable supply positions: the engine's two potion slots until authored progression exists.
## Derived, never saved; a redesign of the screen never changes it.
static func capacity() -> int:
	return mini(PartyLoadout.MAX_POTION_SLOTS, POSITIONS)


static func _icon_path(potion: PotionDefinition) -> String:
	return potion.icon.resource_path if potion != null and potion.icon != null else ""


# --- Brewing ---------------------------------------------------------------------------------------

## Would brewing [param recipe_id] be accepted (the station and encounter checks are the caller's)?
## In order: the recipe, that it brews a potion, its mastery gate, the whole price, and that the
## yield fits under PotionDefinition.MAX_STOCK. Nothing is clipped: an overflowing brew is rejected.
static func brew_check(progress: ProgressState, registry: DefinitionRegistry, recipe_id: StringName) -> CraftingResult.Reason:
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	if recipe == null:
		return CraftingResult.Reason.UNKNOWN_RECIPE
	if recipe.kind != RecipeDefinition.Kind.POTION or recipe.potion == null:
		return CraftingResult.Reason.NOT_BREWABLE
	if not CraftingRules.mastery_met(progress, recipe):
		return CraftingResult.Reason.MASTERY_REQUIRED
	if not CraftingRules.affordable(progress, recipe):
		return CraftingResult.Reason.INSUFFICIENT_MATERIALS
	if progress.supply_count(recipe.potion.id) + recipe.yield_count > PotionDefinition.MAX_STOCK:
		return CraftingResult.Reason.STOCK_OVERFLOW
	return CraftingResult.Reason.OK


## Brews [param recipe] on a commit candidate (already checked): spends the whole price and adds
## the yield to the stock. It prepares nothing. Returns {"spent": [...], "produced": [{id, name,
## icon_path, count, total}]}.
static func brew(progress: ProgressState, recipe: RecipeDefinition) -> Dictionary:
	var spent := CraftingRules.spend(progress, recipe)
	var potion := recipe.potion
	var total := progress.supply_count(potion.id) + recipe.yield_count
	progress.set_supply(potion.id, total)
	var produced: Array[Dictionary] = [{"id": potion.id, "name": potion.display_name, "icon_path": _icon_path(potion),
		"count": recipe.yield_count, "total": total}]
	return {"spent": spent, "produced": produced}


# --- Allowance and settlement ----------------------------------------------------------------------

## The doses the next encounter starts with for each saved potion id of [param progress], in the
## saved order (one whole number per id, 0 for an unknown potion): min(per-encounter cap, held).
## An entry captures this once; a retry rebuilds the battle from the captured numbers, never from
## the live stock.
static func allowance(progress: ProgressState, registry: DefinitionRegistry) -> Array[int]:
	var result: Array[int] = []
	for potion_id in progress.loadout_potions:
		var potion: PotionDefinition = registry.potions.get(potion_id)
		result.append(mini(potion.charges, progress.supply_count(potion_id)) if potion != null else 0)
	return result


## Settles one concluded, accepted attempt on a commit candidate: removes the doses the battle
## actually used ([param uses]: potion id -> count, from BattleResult.item_uses) from the stock,
## never more than the attempt's captured allowance ([param loadout]: the entry's loadout ids) and
## never below zero. An entry captured without an allowance (before this revision) settles nothing.
## Returns the consumed lines [{id, name, icon_path, count, total}] in potion-id order.
static func settle(progress: ProgressState, registry: DefinitionRegistry, loadout: Dictionary,
		uses: Dictionary) -> Array[Dictionary]:
	var consumed: Array[Dictionary] = []
	var charges: Variant = loadout.get("potion_charges")
	var potion_ids: Variant = loadout.get("potions")
	if typeof(charges) != TYPE_ARRAY or typeof(potion_ids) != TYPE_ARRAY or (charges as Array).size() != (potion_ids as Array).size():
		return consumed
	var allowed: Dictionary[StringName, int] = {}
	for index in (potion_ids as Array).size():
		var potion_id := StringName(str(potion_ids[index]))
		allowed[potion_id] = allowed.get(potion_id, 0) + maxi(0, ProgressState.number(charges[index], 0))
	var used_ids: Array[StringName] = []
	for key: Variant in uses:
		used_ids.append(StringName(str(key)))
	used_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for potion_id in used_ids:
		var held := progress.supply_count(potion_id)
		var count := mini(mini(maxi(0, int(uses[potion_id])), allowed.get(potion_id, 0)), held)
		if count <= 0:
			continue
		progress.set_supply(potion_id, held - count)
		var potion: PotionDefinition = registry.potions.get(potion_id)
		consumed.append({"id": potion_id, "name": potion.display_name if potion != null else String(potion_id),
			"icon_path": _icon_path(potion), "count": count, "total": held - count})
	return consumed


# --- One-time migration ----------------------------------------------------------------------------

## Introduces the finite stock to [param progress] exactly once (WorldSession.reconcile, and at New
## Journey creation): every potion with authored starter stock gains it, and each other potion the
## save had access to under the old model (its Stillroom recipe was owned, or it was prepared) gains
## one brew's yield. The marker is recorded in the same change, so a save whose stock later runs to
## zero is never granted again. Returns one line per grant plus the marker line; empty when the
## migration was already applied.
static func migrate(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	var lines := PackedStringArray()
	if progress.has_migration(MIGRATION):
		return lines
	var grants: Dictionary[StringName, int] = {}
	for id in registry.sorted_ids(registry.potions):
		var potion: PotionDefinition = registry.potions[id]
		if potion.starter_stock > 0:
			grants[id] = potion.starter_stock
			continue
		var recipe := CraftingRules.potion_recipe(registry, id)
		if recipe != null and (progress.has_recipe(recipe.id) or progress.loadout_potions.has(id)):
			grants[id] = recipe.yield_count
	for id in registry.sorted_ids(registry.potions):
		if not grants.has(id):
			continue
		var held := progress.supply_count(id)
		var total := mini(held + grants[id], PotionDefinition.MAX_STOCK)
		progress.set_supply(id, total)
		lines.append("supplies are finite now: %s starts with %d doses" % [id, total])
	progress.add_migration(MIGRATION)
	lines.append("supply stock introduced (%s)" % MIGRATION)
	return lines


# --- Readouts --------------------------------------------------------------------------------------

## Every shown supply position: capacity() usable ones, then locked ones. [param available]: the
## field availability of prepare_potion().
static func slot_readouts(progress: ProgressState, registry: DefinitionRegistry,
		available: CraftingResult.Reason) -> Array[PotionSlotReadout]:
	var result: Array[PotionSlotReadout] = []
	for index in POSITIONS:
		result.append(slot_readout(progress, registry, index, available))
	return result


## One supply position for the live save.
static func slot_readout(progress: ProgressState, registry: DefinitionRegistry, slot_index: int,
		available: CraftingResult.Reason) -> PotionSlotReadout:
	var result := PotionSlotReadout.new()
	result.index = slot_index
	if slot_index >= capacity():
		result.locked = true
		result.state = PotionSlotReadout.State.LOCKED
		result.reason = CraftingResult.Reason.INVALID_POTION_SLOT
		result.reason_text = WorldCopy.SUPPLY_LOCKED_POSITION
		result.inspection = {"title": WorldCopy.SUPPLY_LOCKED_TITLE, "category": "Supplies",
			"description": result.reason_text, "icon_path": "", "facts": PackedStringArray(), "details": PackedStringArray()}
		return result
	result.reason = available
	result.reason_text = CraftingRules.reason_text(available)
	var current: StringName = progress.loadout_potions[slot_index] if slot_index < progress.loadout_potions.size() else &""
	var prepared: PotionDefinition = registry.potions.get(current)
	if prepared != null:
		result.potion_id = prepared.id
		result.potion_name = prepared.display_name
		result.description = prepared.description
		result.icon_path = _icon_path(prepared)
		result.held = progress.supply_count(prepared.id)
		result.cap = prepared.charges
		result.usable = mini(result.cap, result.held)
		result.state = PotionSlotReadout.State.PREPARED if result.held > 0 else PotionSlotReadout.State.DEPLETED
		result.inspection = inspection(prepared, result.held)
	else:
		result.state = PotionSlotReadout.State.EMPTY
		result.inspection = {"title": WorldCopy.SUPPLY_EMPTY_TITLE, "category": "Supplies",
			"description": WorldCopy.SUPPLY_EMPTY_TEXT, "icon_path": "",
			"facts": PackedStringArray(), "details": PackedStringArray()}
	for potion in CraftingRules.campaign_potions(registry):
		var reason := available
		if reason == CraftingResult.Reason.OK:
			reason = CraftingRules.potion_check(progress, registry, slot_index, potion.id)
		var recipe := CraftingRules.potion_recipe(registry, potion.id)
		var held := progress.supply_count(potion.id)
		var entry := {"id": potion.id, "name": potion.display_name, "description": potion.description,
			"icon_path": _icon_path(potion), "charges": potion.charges, "cap": potion.charges, "held": held,
			"usable": mini(potion.charges, held),
			"source": CraftingRules.SOURCE_STARTER if potion.starter_stock > 0 else CraftingRules.SOURCE_RECIPE,
			"recipe_id": recipe.id if recipe != null else &"",
			"unlocked": held > 0, "selected": current == potion.id,
			"selectable": reason == CraftingResult.Reason.OK, "reason": reason,
			"reason_text": CraftingRules.reason_text(reason, recipe)}
		result.options.append(entry)
		# The popup list: what the save actually holds, plus whatever this position already holds.
		if held > 0 or current == potion.id:
			result.choices.append(entry)
	return result


## The inspection payload of a prepared potion: its real effect text, held doses and the doses one
## encounter may use. Plain data for the shared inspector.
static func inspection(potion: PotionDefinition, held: int) -> Dictionary:
	var usable := mini(potion.charges, held)
	var facts := PackedStringArray([
		WorldCopy.SUPPLY_FACT_HELD % held,
		WorldCopy.SUPPLY_FACT_USABLE % [usable, potion.charges]])
	var details := PackedStringArray()
	if potion.action != null and not potion.action.details.is_empty():
		details.append(potion.action.details)
	if held <= 0:
		details.append(WorldCopy.CRAFT_NO_STOCK)
	return {"title": potion.display_name, "category": "Supply", "description": potion.description,
		"icon_path": _icon_path(potion), "facts": facts, "details": details}


## Every campaign potion the save holds or has prepared, in campaign order: [{id, name, description,
## icon_path, held, cap, usable, prepared_slot (-1 = not prepared), recipe_id}]. The Stillroom's
## "Unprepared" list is the entries with prepared_slot == -1.
static func stock(progress: ProgressState, registry: DefinitionRegistry) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for potion in CraftingRules.campaign_potions(registry):
		var held := progress.supply_count(potion.id)
		var prepared_slot := progress.loadout_potions.find(potion.id)
		if prepared_slot >= capacity():
			prepared_slot = -1
		if held <= 0 and prepared_slot < 0:
			continue
		var recipe := CraftingRules.potion_recipe(registry, potion.id)
		result.append({"id": potion.id, "name": potion.display_name, "description": potion.description,
			"icon_path": _icon_path(potion), "held": held, "cap": potion.charges,
			"usable": mini(potion.charges, held), "prepared_slot": prepared_slot,
			"recipe_id": recipe.id if recipe != null else &""})
	return result
