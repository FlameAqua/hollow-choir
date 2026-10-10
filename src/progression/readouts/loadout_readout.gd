class_name LoadoutReadout
extends RefCounted
## The unified Loadout for the live save (playtest revision): gear with the actions each source
## authors, the supplemental Core/stance group, the familiar and its passive, the supply positions,
## the eight combat positions, active passives, mastery facts and the ingredient catalog. Plain data
## from LoadoutRules; a view never derives eligibility, ownership, locks or source attribution.
##
## Action fact (gear[].actions and core): {id: StringName, name, description, details: String,
##   category: String, category_id: int (Enums.ActionCategory), focus_cost: int, timing: String,
##   source_id: StringName (&"weapon", &"garb", &"charm", &"relic" or &"core"),
##   origin: StringName (&"basic", &"technique", &"stance", &"innate", &"granted", &"inspect"),
##   origin_name: String (the item, the Hollow, or the shared-action label),
##   arranged: bool, position: int (-1 when unplaced), selectable: bool (a PUT would be accepted
##   now), reason: CombatResult.Reason, reason_text: String}.
## Every action the gear grants appears exactly once across the gear strips and core.

## OK when field commands (equipment, supplies, familiar, arrangement) would run now;
## ENCOUNTER_PENDING during a pending or active encounter.
var reason: PreparationResult.Reason = PreparationResult.Reason.OK
var reason_text: String = ""
## Weapon, garb, charm, relic, in that order (EquipmentSlotReadout with source_id, icon_path and
## the source's action strip).
var gear: Array[EquipmentSlotReadout] = []
## The supplemental Core/stance group: the weapon's stance, the Hollow's innate actions, Inspect,
## then any action a gear strip had no cell for. Not limited to three.
var core: Array[Dictionary] = []
var familiar: FamiliarReadout
## Every shown supply position (SupplyRules.POSITIONS), locked ones included.
var supplies: Array[PotionSlotReadout] = []
var supply_capacity: int = SupplyRules.capacity()
## [{index: int, locked: bool, reason: CombatResult.Reason (LOCKED_POSITION when locked),
##   reason_text: String, action_id: StringName (&"" when empty or locked),
##   source_id: StringName (&"" when empty)}], one per shown position.
var positions: Array[Dictionary] = []
## Usable and shown combat positions (CombatRules.capacity / POSITIONS).
var capacity: int = CombatRules.STARTING_CAPACITY
var positions_total: int = CombatRules.POSITIONS
## The arranged action ids in battle order, and granted actions holding no position.
var arranged: Array[StringName] = []
var unarranged: Array[StringName] = []
## Active passives the next battle applies: [{id: StringName, name, description, details: String,
##   kind: StringName (&"gear", &"fitting", &"resonance", &"familiar"),
##   source_id: StringName (the gear source, &"resonance" or &"familiar"), source_name: String}].
## Never placed in a combat position.
var passives: Array[Dictionary] = []
## Weapon mastery facts, one per owned weapon: [{id, name, icon_path, points: int}]. Mastery is a
## record of use: it is neither a passive nor selectable.
var mastery: Array[Dictionary] = []
## The public ingredient catalog (see InventoryReadout.ingredients).
var ingredients: Array[Dictionary] = []
## Usable and drawn bag cells (see InventoryReadout).
var equipment_capacity: int = PreparationRules.STARTING_EQUIPMENT_CAPACITY
var equipment_cells: int = InventoryReadout.EQUIPMENT_CELLS


func available() -> bool:
	return reason == PreparationResult.Reason.OK


func gear_slot(slot: Enums.EquipSlot) -> EquipmentSlotReadout:
	for entry in gear:
		if entry.slot == slot:
			return entry
	return null


## Every action fact, gear strips first (in gear order), then core.
func all_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in gear:
		result.append_array(entry.actions)
	result.append_array(core)
	return result


## The action fact for [param action_id], or {}.
func action(action_id: StringName) -> Dictionary:
	for entry in all_actions():
		if entry.id == action_id:
			return entry
	return {}


func supply(index: int) -> PotionSlotReadout:
	for entry in supplies:
		if entry.index == index:
			return entry
	return null
