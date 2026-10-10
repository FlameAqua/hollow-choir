class_name PreparationResult
extends RefCounted
## Outcome of one campaign preparation command (V0.5A): WorldSession.equip(), unequip() and
## choose_weapon() record it in WorldSession.last_preparation. A rejected, failed or no-op command
## changed nothing: no loadout, ownership, arrangement or save write.

enum Reason {
	OK = 0,
	## Legacy (V0.5A): equipment needed an open station. Since the V0.5 UI pass equipment is a
	## field command and this reason is never returned; the value stays for saved logs and tools.
	NO_STATION = 1,
	## A world encounter entry is pending or in battle; equipment cannot change in the field.
	ENCOUNTER_PENDING = 2,
	## The id is not approved weapon or armor content.
	UNKNOWN_ITEM = 3,
	## Approved content the save does not own (Practice and the Lab may still audition it).
	NOT_OWNED = 4,
	## The item belongs to another slot.
	WRONG_SLOT = 5,
	## The weapon slot cannot be emptied.
	REQUIRED_SLOT = 6,
	## The new loadout would give a party member more than PartyLoadout.MAX_ACTIONS actions. The
	## whole loadout is rejected: nothing is truncated or hidden.
	ACTION_LIMIT = 7,
	## Valid, but the save write failed (see error); the live state is unchanged. Retry is safe.
	WRITE_FAILED = 8,
	## V0.5B: the new loadout would carry a fitting's trait twice (e.g. a Hollow Reliquary while a
	## Hollow Echo fitting is active). Nothing is doubled or removed; remove one source first.
	DUPLICATE_TRAIT = 9,
}

var reason: Reason = Reason.OK
## OK; ERR_UNAVAILABLE (NO_STATION, ENCOUNTER_PENDING); ERR_INVALID_PARAMETER (item rejections);
## the writer's error for WRITE_FAILED.
var error: Error = OK
var slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON
## The requested item (&"" = empty the slot).
var item_id: StringName = &""
## What the slot held before the command.
var previous_id: StringName = &""
## True when a successful command changed the slot (re-choosing the equipped item is a no-op that
## writes nothing).
var changed := false
## V0.5 UI: how the same write reconciled the combat arrangement with the new gear:
## [{id: StringName, name: String, position: int}] by position (empty when nothing moved).
var actions_removed: Array[Dictionary] = []
var actions_added: Array[Dictionary] = []
## Playtest revision: the actions that kept their position through the change, and the whole
## arrangement before and after it (battle order). Presentation highlights from these facts; the
## prose in summary() is only for the older card.
var actions_kept: Array[Dictionary] = []
var arrangement_before: Array[StringName] = []
var arrangement_after: Array[StringName] = []


static func make(p_slot: Enums.EquipSlot, p_item_id: StringName, p_previous_id: StringName) -> PreparationResult:
	var result := PreparationResult.new()
	result.slot = p_slot
	result.item_id = p_item_id
	result.previous_id = p_previous_id
	return result


func ok() -> bool:
	return reason == Reason.OK


## The stable name of what a changed command did, for feedback (sound) routing: &"equip" or
## &"unequip". &"" when nothing changed.
func operation() -> StringName:
	if not ok() or not changed:
		return &""
	return &"unequip" if item_id == &"" else &"equip"


## The outcome line for a card (V0.5 UI): the rejection, the no-op, or the save with every combat
## arrangement change the same write made ("Crush replaces Strike in combat position 1.").
func summary() -> String:
	if not ok():
		return text()
	if not changed:
		return WorldCopy.PREP_UNCHANGED
	var lines := PackedStringArray([WorldCopy.PREP_SAVED])
	lines.append_array(arrangement_lines())
	return " ".join(lines)


## One sentence per combat position the equipment change affected, by position.
func arrangement_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var joined := {}
	for entry in actions_added:
		joined[int(entry.position)] = entry
	for entry in actions_removed:
		var position := int(entry.position)
		if joined.has(position):
			lines.append(WorldCopy.COMBAT_REPLACED % [joined[position].name, entry.name, position + 1])
			joined.erase(position)
		else:
			lines.append(WorldCopy.COMBAT_LEFT % [entry.name, position + 1])
	var rest := joined.keys()
	rest.sort()
	for position: int in rest:
		lines.append(WorldCopy.COMBAT_JOINED % [joined[position].name, position + 1])
	return lines


## Default public wording for the reason (WorldCopy; presentation may restyle it).
func text() -> String:
	return reason_text(reason)


static func reason_text(value: Reason) -> String:
	match value:
		Reason.NO_STATION:
			return WorldCopy.PREP_NO_STATION
		Reason.ENCOUNTER_PENDING:
			return WorldCopy.PREP_ENCOUNTER_PENDING
		Reason.UNKNOWN_ITEM:
			return WorldCopy.PREP_UNKNOWN_ITEM
		Reason.NOT_OWNED:
			return WorldCopy.PREP_NOT_OWNED
		Reason.WRONG_SLOT:
			return WorldCopy.PREP_WRONG_SLOT
		Reason.REQUIRED_SLOT:
			return WorldCopy.PREP_REQUIRED_SLOT
		Reason.ACTION_LIMIT:
			return WorldCopy.PREP_ACTION_LIMIT % PartyLoadout.MAX_ACTIONS
		Reason.DUPLICATE_TRAIT:
			return WorldCopy.PREP_DUPLICATE_TRAIT
		Reason.WRITE_FAILED:
			return WorldCopy.SAVE_FAILED_TITLE
	return ""


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.NO_STATION, Reason.ENCOUNTER_PENDING:
			return ERR_UNAVAILABLE
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER
