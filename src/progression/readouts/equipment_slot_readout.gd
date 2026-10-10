class_name EquipmentSlotReadout
extends RefCounted
## One equipment slot at the preparation station (V0.5A): what is equipped and every owned,
## approved item that fits it, with the result the command would return. Public item facts only.

var slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON
var label: String = ""
## Playtest revision (unified Loadout): the stable source id of this slot (&"weapon", &"garb",
## &"charm", &"relic"), the equipped item's icon, and the actions this source authors, at most
## strip_cells of them (action facts: see LoadoutReadout). Further actions are in LoadoutReadout.core.
var source_id: StringName = &""
var icon_path: String = ""
var strip_cells: int = 3
var actions: Array[Dictionary] = []
## Armor slots can be emptied (WorldSession.unequip); the weapon slot cannot.
var optional := false
var equipped_id: StringName = &""
## The equipped item's public name ("" when the slot is empty or holds unapproved content).
var equipped_name: String = ""
## True when unequip(slot) would be accepted now.
var can_remove := false
## [{id: StringName, name: String, description: String, details: String, category: String,
##   rarity: String, equipped: bool, selectable: bool (equip would be accepted now),
##   reason: PreparationResult.Reason (OK when selectable), reason_text: String,
##   actions: int (every action the Hollow's gear would grant with this item equipped),
##   combat: {removed: [{id, name, position}], added: [...], kept: [...]} (how equipping it would
##     change the combat arrangement; removed and added are empty when nothing changes),
##   traits: [{name, description}], grants: [{name, description}] (actions the item brings),
##   resonance: PackedStringArray}]
var options: Array[Dictionary] = []


func option(item_id: StringName) -> Dictionary:
	for entry in options:
		if entry.id == item_id:
			return entry
	return {}
