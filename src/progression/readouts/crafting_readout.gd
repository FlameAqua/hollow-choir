class_name CraftingReadout
extends RefCounted
## The Forge and Stillroom services (V0.5B; separate stations since the V0.5 UI pass): whether the
## open station's commands are accepted now, held materials, every recipe, each fitting-capable
## weapon and the two potion slots. Each entry's own reason says whether this station may act on it
## (WRONG_STATION for the other service's work). Plain data from CraftingRules; widgets never derive
## rules from it.

## The open station's landmark id, or &"" when no station interaction is open.
var station_id: StringName = &""
## The open station's service (LandmarkDefinition.Service; NONE without a station).
var service: LandmarkDefinition.Service = LandmarkDefinition.Service.NONE
## OK when the open station's own commands would be accepted now (NO_STATION / ENCOUNTER_PENDING
## otherwise). Potion slots use the field availability instead (see PotionSlotReadout).
var reason: CraftingResult.Reason = CraftingResult.Reason.OK
var reason_text: String = ""
## Held approved materials, as InventoryReadout lists them.
var materials: Array[Dictionary] = []
## Playtest revision: the public ingredient catalog (every listed material, zero counts included,
## in stable order): [{id, name, description, icon_path, count, held}]. The same list Inventory and
## Loadout publish.
var ingredients: Array[Dictionary] = []
## Forge recipes first, then Stillroom, each by id.
var recipes: Array[RecipeReadout] = []
## One per weapon a fitting kit serves (Pilgrim's Edge in V0.5B), whether or not the kit is owned.
var fittings: Array[FittingReadout] = []
## The usable supply positions (SupplyRules.capacity), in order.
var potion_slots: Array[PotionSlotReadout] = []
## Playtest revision: every shown supply position (SUPPLY_POSITIONS), locked ones included.
var supplies: Array[PotionSlotReadout] = []
## Every campaign potion the save holds or has prepared: [{id, name, description, icon_path, held,
## cap, usable, prepared_slot (-1 = not prepared), recipe_id}].
var stock: Array[Dictionary] = []
var action_limit: int = PartyLoadout.MAX_ACTIONS
## Actions the next encounter's loadout gives the Hollow and the companion (potions live in
## Supplies and use no action slot).
var protagonist_actions: int = 0
var companion_actions: int = 0
## V0.5 UI display concepts (Director): the Forge shows FITTING_SOCKETS sockets around a weapon and
## the Stillroom POTION_POSITIONS potion positions. Only one fitting per kit-served weapon and
## potion_slots.size() potions are usable; the other positions are locked with locked_reason_text.
## No modification category, potion charge or unlock reward is implied by a locked position.
const FITTING_SOCKETS := CraftingRules.SOCKETS
const POTION_POSITIONS := SupplyRules.POSITIONS
const SUPPLY_POSITIONS := SupplyRules.POSITIONS
var fitting_capacity: int = 1
var potion_capacity: int = PartyLoadout.MAX_POTION_SLOTS
var locked_reason_text: String = WorldCopy.COMBAT_LOCKED_POSITION


func available() -> bool:
	return reason == CraftingResult.Reason.OK


func recipe(recipe_id: StringName) -> RecipeReadout:
	for entry in recipes:
		if entry.id == recipe_id:
			return entry
	return null


func fitting(weapon_id: StringName) -> FittingReadout:
	for entry in fittings:
		if entry.weapon_id == weapon_id:
			return entry
	return null


func potion_slot(slot_index: int) -> PotionSlotReadout:
	for entry in potion_slots:
		if entry.index == slot_index:
			return entry
	return null


## Any shown supply position, locked ones included.
func supply(slot_index: int) -> PotionSlotReadout:
	for entry in supplies:
		if entry.index == slot_index:
			return entry
	return null


## The stock entry of [param potion_id], or {} when the save neither holds nor has prepared it.
func stock_of(potion_id: StringName) -> Dictionary:
	for entry in stock:
		if entry.id == potion_id:
			return entry
	return {}


func material_count(material_id: StringName) -> int:
	for entry in materials:
		if entry.id == material_id:
			return int(entry.count)
	return 0


func plain_text() -> String:
	var lines := PackedStringArray()
	for entry in recipes:
		lines.append(entry.plain_text())
	for entry in fittings:
		lines.append("%s fitting: %s%s" % [entry.weapon_name, entry.installed_name if not entry.installed_name.is_empty()
			else "none", "" if entry.capacity else " (%s)" % entry.capacity_reason_text])
	for entry in potion_slots:
		lines.append("Potion slot %d: %s" % [entry.index + 1, entry.potion_name if not entry.potion_name.is_empty() else "empty"])
	return "\n".join(lines)
