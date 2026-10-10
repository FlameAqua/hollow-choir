class_name CombatReadout
extends RefCounted
## The Hollow's combat arrangement for the live save (V0.5 UI): every shown position with its lock
## or action, every granted action as a candidate (arranged or not, so nothing is hidden), passive
## skills as inspection facts and the companion's fixed actions. Plain data from CombatRules;
## widgets never derive eligibility from it.

## OK when arrangement commands would run now (ENCOUNTER_PENDING otherwise).
var reason: CombatResult.Reason = CombatResult.Reason.OK
var reason_text: String = ""
## Usable positions now (CombatRules.capacity) and positions shown (CombatRules.POSITIONS).
var capacity: int = CombatRules.STARTING_CAPACITY
var positions_total: int = CombatRules.POSITIONS
## The engine's per-member action ceiling (PartyLoadout.MAX_ACTIONS); independent of capacity.
var action_limit: int = PartyLoadout.MAX_ACTIONS
## [{index: int, locked: bool, reason: CombatResult.Reason (LOCKED_POSITION when locked),
##   reason_text: String, action_id: StringName (&"" when empty or locked)}], one per shown position.
var positions: Array[Dictionary] = []
## The arranged action ids in position (battle) order.
var arranged: Array[StringName] = []
## Granted actions that hold no position (they are not available in battle until placed).
var unarranged: Array[StringName] = []
## Candidates by filter. Each entry: {id, name, description, details: String, category: String,
##   category_id: int (Enums.ActionCategory), action_id: StringName, focus_cost: int, timing: String,
##   source: String (what grants it), facts: PackedStringArray, extra: PackedStringArray,
##   arranged: bool, position: int (-1 when unarranged), selectable: bool (a PUT would be
##   accepted now), reason: CombatResult.Reason, reason_text: String}.
## actions = every category except Magic; magic = Magic.
var actions: Array[Dictionary] = []
var magic: Array[Dictionary] = []
## Passive skills and mastery facts: {id, name, description, category, icon_id or icon_path, facts,
##   extra, passive: true, selectable: false, reason: PASSIVE_SKILL, reason_text}. Never arranged.
var skills: Array[Dictionary] = []
## The companion's fixed actions (not arranged): {name: String, actions: PackedStringArray}.
var companion: Dictionary = {}


func available() -> bool:
	return reason == CombatResult.Reason.OK


func position(index: int) -> Dictionary:
	return positions[index] if index >= 0 and index < positions.size() else {}


## The candidate entry for [param action_id] (Actions or Magic), or {}.
func candidate(action_id: StringName) -> Dictionary:
	for entry in actions + magic:
		if entry.id == action_id:
			return entry
	return {}
