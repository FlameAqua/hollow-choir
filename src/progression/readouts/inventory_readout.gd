class_name InventoryReadout
extends RefCounted
## What the save holds (V0.5A): salvage materials with a positive count and owned equipment, both
## limited to approved content. Plain data; changing it changes nothing else. Unknown ids kept in
## an older save stay in the save but never appear here.

## [{id: StringName, name: String, description: String, icon_path: String, count: int}], by id.
var materials: Array[Dictionary] = []
## Owned PreparationRules option facts (name, icon_path, description, details, rarity, traits,
## grants, resonance, equipped...) plus slot, slot_label and saved weapon mastery. Ordered by slot,
## then as PreparationRules orders that slot's choices. These remain plain-data copies.
var equipment: Array[Dictionary] = []
## Starting ten slots plus approved, claimed progression rewards. Never derived by a widget.
var equipment_capacity: int = 10
## Playtest revision: bag cells drawn (four rows of five). Cells at or beyond equipment_capacity are
## locked; drawing them grants nothing.
const EQUIPMENT_CELLS := 20
var equipment_cells: int = EQUIPMENT_CELLS
var cells_locked_text: String = ""
## The public ingredient catalog: every listed approved material in stable order, zero counts
## included: [{id, name, description, icon_path, count: int, held: bool}].
var ingredients: Array[Dictionary] = []


func count(material_id: StringName) -> int:
	for entry in materials:
		if entry.id == material_id:
			return int(entry.count)
	return 0


func owns(item_id: StringName) -> bool:
	return equipment.any(func(entry: Dictionary) -> bool: return entry.id == item_id)


func plain_text() -> String:
	var lines := PackedStringArray()
	for entry in materials:
		lines.append("%s ×%d" % [entry.name, entry.count])
	for entry in equipment:
		lines.append("%s · %s%s" % [entry.name, entry.slot_label, " (equipped)" if entry.equipped else ""])
	return "\n".join(lines)
