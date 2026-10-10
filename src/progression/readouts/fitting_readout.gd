class_name FittingReadout
extends RefCounted
## One weapon's fitting at the preparation station (V0.5B): whether it has fitting capacity, what
## is installed, whether that fitting reaches the next encounter, and every approved choice with
## the result fit() would return now. Plain data; changing it changes nothing.

var weapon_id: StringName = &""
var weapon_name: String = ""
var weapon_icon_path: String = ""
## The weapon is the equipped one, so an installed fitting applies to the next encounter.
var weapon_equipped := false
## The legacy fitting kit recipe for this weapon (&"" when none) and whether this save holds it.
var kit_id: StringName = &""
var kit_owned := false
## The weapon can hold a fitting at all (playtest revision: no longer tied to the kit; ownership is
## per option). capacity_reason is OK, or WRONG_WEAPON when nothing is offered for it.
var capacity := false
var capacity_reason: CraftingResult.Reason = CraftingResult.Reason.OK
var capacity_reason_text: String = ""
## Playtest revision: the sockets shown (CraftingRules.SOCKETS) and how many accept a fitting.
## [{index: int, locked: bool, reason: CraftingResult.Reason (LOCKED_SOCKET when locked),
##   reason_text: String, fitting_id: StringName, fitting_name: String}]
var sockets: Array[Dictionary] = []
var socket_capacity: int = 1
## An older fitting kit for this weapon ({} when none was ever authored): {id, name, owned: bool,
## can_refund: bool, refund_reason: CraftingResult.Reason, refund_reason_text: String,
## refund: [{id, name, icon_path, count, held, total}]}. An owned kit grandfathers every fitting it
## offered; refunding it is a deliberate Forge command and never happens on load.
var legacy_kit: Dictionary = {}
## The installed approved fitting (&"" / "" when none or when the saved id is not approved).
var installed_id: StringName = &""
var installed_name: String = ""
## The installed fitting's trait is part of the next encounter (installed, capacity, equipped).
var active := false
## remove_fitting(weapon_id) would change something and be accepted now.
var can_remove := false
## The weapon's own traits, which a fitting never replaces: [{name, description}].
var base_traits: Array[Dictionary] = []
## [{id: StringName, name: String, description: String, source: String (the item that authors the
##   reused trait), trait: {id, name, description, details}, installed: bool,
##   selectable: bool (fit would be accepted now; re-choosing the installed fitting is an accepted
##   no-op), reason: CraftingResult.Reason (OK when selectable), reason_text: String,
##   actions: int (the Hollow's actions with this weapon equipped and this fitting),
##   owned: bool, owned_source: StringName (&"crafted", &"legacy_kit" or &""),
##   recipe_id: StringName, costs: [{id, name, icon_path, count, held, enough}],
##   mastery_required: int, mastery_current: int, mastery_met: bool,
##   can_craft: bool, craft_reason: CraftingResult.Reason, craft_reason_text: String,
##   can_fit: bool (= selectable), can_remove: bool,
##   action: StringName (&"remove" when installed, &"fit" when owned, &"craft" when not owned,
##     &"none" when it cannot be crafted at all: the one primary command to show)}]
var options: Array[Dictionary] = []


func option(modification_id: StringName) -> Dictionary:
	for entry in options:
		if entry.id == modification_id:
			return entry
	return {}
