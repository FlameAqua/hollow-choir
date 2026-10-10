class_name PotionSlotReadout
extends RefCounted
## One of the two campaign potion slots at the preparation station (V0.5B): what is prepared and
## every campaign potion with the result prepare_potion() would return now. Recipes unlock
## selection, never a bottle count: charges are the potion's authored per-encounter doses.

## Playtest revision (finite supplies): what the position is doing.
enum State {
	## Usable and nothing is prepared.
	EMPTY = 0,
	## A potion is prepared and the save holds at least one dose.
	PREPARED = 1,
	## A potion is prepared but the save holds none: the choice is kept and the next battle starts
	## with zero doses until it is brewed again or replaced.
	DEPLETED = 2,
	## Shown but beyond the usable supply positions (SupplyRules.capacity): accepts nothing.
	LOCKED = 3,
}

var index: int = 0
var locked := false
var state: State = State.EMPTY
## OK when prepare_potion() on this position would be considered now; ENCOUNTER_PENDING during an
## encounter; INVALID_POTION_SLOT for a locked position. reason_text is its public wording.
var reason: CraftingResult.Reason = CraftingResult.Reason.OK
var reason_text: String = ""
## The prepared potion's public facts ("" / 0 when empty or locked): held doses in the save, the
## most doses one encounter may use from this position (cap) and what the next battle starts with
## (usable = min(cap, held)).
var icon_path: String = ""
var description: String = ""
var held: int = 0
var cap: int = 0
var usable: int = 0
## The inspector payload for this position, whatever its state: {title, category, description,
## icon_path, facts: PackedStringArray, details: PackedStringArray}. Never a generic hint for an
## occupied position.
var inspection: Dictionary = {}
## The prepared potion (&"" / "" when the slot is empty or holds unapproved content).
var potion_id: StringName = &""
var potion_name: String = ""
## [{id: StringName, name: String, description: String, charges: int,
##   source: String ("Starter" / "Stillroom recipe"), recipe_id: StringName (&"" for starters),
##   unlocked: bool, selected: bool (in this slot), selectable: bool (prepare_potion would be
##   accepted now; re-choosing the prepared potion is an accepted no-op),
##   reason: CraftingResult.Reason (OK when selectable), reason_text: String,
##   icon_path: String, held: int, cap: int, usable: int}]
## Starters first in their starter order, then recipe potions by recipe id. unlocked = held > 0.
var options: Array[Dictionary] = []
## The entries of options the save holds at least one dose of, plus the one prepared here: the
## candidate list a supply popup shows (owned and eligible choices only).
var choices: Array[Dictionary] = []


func option(potion: StringName) -> Dictionary:
	for entry in options:
		if entry.id == potion:
			return entry
	return {}
