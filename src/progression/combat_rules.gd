class_name CombatRules
extends RefCounted
## V0.5 UI combat arrangement: which of the Hollow's granted actions hold the unlocked combat
## positions, in battle order. POSITIONS (the engine's PartyLoadout.MAX_ACTIONS grid) are shown; the
## first capacity() are usable and the rest stay locked until authored progression unlocks them.
## Capacity is derived, never a saved counter, and is separate from the engine's action ceiling.
##
## Candidates are the actions the campaign gear grants (UnitFactory.granted_actions): Actions (every
## category but Magic) in grid order, then Magic. A save that never arranged anything uses the
## default: the first capacity() candidates. Passive skills (traits) are inspection facts and never
## hold a position. The companion's actions are not arranged.
##
## Pure: the caller passes the progress, the registry and (for readouts) the combat library;
## WorldSession owns availability and every write.

const STARTING_CAPACITY := 6
const POSITIONS := PartyLoadout.MAX_ACTIONS


## Usable combat positions for [param progress]: STARTING_CAPACITY until authored progression
## exists (Director: default six, two locked). Never above POSITIONS.
static func capacity(_progress: ProgressState, _registry: DefinitionRegistry) -> int:
	return mini(STARTING_CAPACITY, POSITIONS)


## Arrangement commands run outside a pending or active encounter (its captured entry is final).
static func availability(progress: ProgressState) -> CombatResult.Reason:
	if progress.world.pending_entry != null:
		return CombatResult.Reason.ENCOUNTER_PENDING
	return CombatResult.Reason.OK


## The Hollow's granted actions for the saved gear, in candidate order (Actions, then Magic).
static func candidates(progress: ProgressState, registry: DefinitionRegistry) -> Array[ActionDefinition]:
	var loadout := PartyLoadout.from_ids(registry, progress.loadout_ids())
	var granted := UnitFactory.granted_actions(loadout, registry.balance)
	var result: Array[ActionDefinition] = []
	for action in granted:
		if action.category != Enums.ActionCategory.MAGIC:
			result.append(action)
	for action in granted:
		if action.category == Enums.ActionCategory.MAGIC:
			result.append(action)
	return result


static func ids_of(actions: Array[ActionDefinition]) -> Array[StringName]:
	var result: Array[StringName] = []
	for action in actions:
		result.append(action.id)
	return result


## The effective arrangement of [param saved] over [param candidate_ids] (candidate order) within
## [param slots] positions. Empty [param saved] = the default (the first [param slots] candidates).
## Otherwise each saved position keeps its action while the gear grants it; a duplicate or an
## ungranted id frees its position. Freed positions, then any further unlocked positions, take
## unarranged actions in order: saved ones beyond [param slots] first (an older, larger arrangement),
## then the remaining candidates. Deterministic; never a duplicate, an ungranted action or more
## than [param slots] actions.
static func resolve(saved: Array[StringName], candidate_ids: Array[StringName], slots: int) -> Array[StringName]:
	if saved.is_empty():
		return candidate_ids.slice(0, maxi(slots, 0))
	var positions: Array[StringName] = []
	var used := {}
	var spare: Array[StringName] = []
	for id in saved:
		var valid := candidate_ids.has(id) and not used.has(id)
		if valid:
			used[id] = true
		if positions.size() < slots:
			positions.append(id if valid else &"")
		elif valid:
			spare.append(id)
	for id in candidate_ids:
		if not used.has(id):
			spare.append(id)
	for index in positions.size():
		if positions[index] == &"" and not spare.is_empty():
			positions[index] = spare.pop_front()
	while positions.size() < slots and not spare.is_empty():
		positions.append(spare.pop_front())
	var result: Array[StringName] = []
	for id in positions:
		if id != &"":
			result.append(id)
	return result


## The arrangement the next encounter captures for [param progress] (ids in battle order).
static func arrangement(progress: ProgressState, registry: DefinitionRegistry) -> Array[StringName]:
	return resolve(progress.combat_actions, ids_of(candidates(progress, registry)), capacity(progress, registry))


## id -> display name for the actions [param progress]'s gear grants (for change reports).
static func names(progress: ProgressState, registry: DefinitionRegistry) -> Dictionary:
	var result := {}
	for action in candidates(progress, registry):
		result[action.id] = action.display_name
	return result


## After a gear change on [param progress] (a commit candidate whose arrangement before the change
## was [param before], with [param before_names]): keeps each action the new gear still grants in its
## position, fills freed positions (see resolve) and saves the result explicitly, so the persisted
## arrangement is always valid. Returns {"removed": [{id, name, position}], "added": [...],
## "kept": [...], "before": Array[StringName], "after": Array[StringName]}, by position.
static func reconcile(progress: ProgressState, registry: DefinitionRegistry, before: Array[StringName],
		before_names: Dictionary) -> Dictionary:
	var after := resolve(before, ids_of(candidates(progress, registry)), capacity(progress, registry))
	progress.combat_actions = after
	var result := changes(before, after, before_names, names(progress, registry))
	result["before"] = before.duplicate()
	result["after"] = after.duplicate()
	return result


## The positions whose action differs between [param before] and [param after], and (playtest
## revision) the actions that are in both, at their position afterwards: structured facts for
## highlights, so no view has to parse a sentence.
static func changes(before: Array[StringName], after: Array[StringName], before_names: Dictionary,
		after_names: Dictionary) -> Dictionary:
	var removed: Array[Dictionary] = []
	var added: Array[Dictionary] = []
	var kept: Array[Dictionary] = []
	for index in after.size():
		if before.has(after[index]):
			kept.append({"id": after[index], "name": String(after_names.get(after[index], after[index])),
				"position": index})
	for index in before.size():
		if not after.has(before[index]):
			removed.append({"id": before[index], "name": String(before_names.get(before[index], before[index])),
				"position": index})
	for index in after.size():
		if not before.has(after[index]):
			added.append({"id": after[index], "name": String(after_names.get(after[index], after[index])),
				"position": index})
	return {"removed": removed, "added": added, "kept": kept}


## Compatibility repair (WorldSession.reconcile, after the equipment repair): an explicit saved
## arrangement that is not exactly its own resolution (an id the gear no longer grants, a duplicate,
## more actions than the capacity) is rewritten to it. A never-arranged save keeps the derived
## default and needs nothing. Returns one line per repair; empty when nothing changed.
static func repair(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	if progress.combat_actions.is_empty():
		return PackedStringArray()
	var resolved := arrangement(progress, registry)
	if resolved == progress.combat_actions:
		return PackedStringArray()
	var saved: Array[StringName] = progress.combat_actions.duplicate()
	progress.combat_actions = resolved
	var dropped := PackedStringArray()
	for id in saved:
		if not resolved.has(id) and not dropped.has(String(id)):
			dropped.append(String(id))
	return PackedStringArray(["combat arrangement [%s] is not valid for the equipped gear and %d positions; it is [%s] now%s" % [
		_list(saved), capacity(progress, registry), _list(resolved),
		" (not in a position: %s)" % ", ".join(dropped) if not dropped.is_empty() else ""]])


static func _list(ids: Array[StringName]) -> String:
	var parts := PackedStringArray()
	for id in ids:
		parts.append(String(id))
	return ", ".join(parts)


# --- Command checks and changes -------------------------------------------------------------------

## The passive skill ids [param progress]'s campaign loadout applies (gear and fitting traits,
## active resonances, the familiar's trait).
static func passive_ids(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in CharacterReadout.build(progress, registry, library).skills:
		if entry.get("passive", false) and not result.has(entry.id):
			result.append(entry.id)
	return result


## Would putting [param action_id] at [param position] be accepted (the action check only)?
static func action_check(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary,
		action_id: StringName) -> CombatResult.Reason:
	if ids_of(candidates(progress, registry)).has(action_id):
		return CombatResult.Reason.OK
	if registry.actions.has(action_id):
		return CombatResult.Reason.NOT_GRANTED
	if passive_ids(progress, registry, library).has(action_id):
		return CombatResult.Reason.PASSIVE_SKILL
	return CombatResult.Reason.UNKNOWN_ACTION


static func position_check(progress: ProgressState, registry: DefinitionRegistry, position: int) -> CombatResult.Reason:
	if position < 0 or position >= POSITIONS:
		return CombatResult.Reason.INVALID_POSITION
	if position >= capacity(progress, registry):
		return CombatResult.Reason.LOCKED_POSITION
	return CombatResult.Reason.OK


## PUT: [param action_id] into unlocked [param position]. An unarranged action replaces the action
## there (which leaves the arrangement) or fills an empty position (taking the next free one, since
## arranged positions are contiguous); an arranged action swaps with the position's action.
static func put_check(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary,
		position: int, action_id: StringName) -> CombatResult.Reason:
	var reason := position_check(progress, registry, position)
	if reason == CombatResult.Reason.OK:
		reason = action_check(progress, registry, library, action_id)
	return reason


static func put(current: Array[StringName], position: int, action_id: StringName) -> Array[StringName]:
	var after: Array[StringName] = current.duplicate()
	var from := after.find(action_id)
	if from == position:
		return after
	if from >= 0:
		if position < after.size():
			after[from] = after[position]
			after[position] = action_id
		else:
			after.remove_at(from)
			after.append(action_id)
	elif position < after.size():
		after[position] = action_id
	else:
		after.append(action_id)
	return after


## SWAP: both positions must be unlocked and hold an action.
static func swap_check(progress: ProgressState, registry: DefinitionRegistry, first: int, second: int) -> CombatResult.Reason:
	for position in [first, second]:
		var reason := position_check(progress, registry, position)
		if reason != CombatResult.Reason.OK:
			return reason
	var current := arrangement(progress, registry)
	if first >= current.size() or second >= current.size():
		return CombatResult.Reason.EMPTY_POSITION
	return CombatResult.Reason.OK


static func swap(current: Array[StringName], first: int, second: int) -> Array[StringName]:
	var after: Array[StringName] = current.duplicate()
	var held: StringName = after[first]
	after[first] = after[second]
	after[second] = held
	return after


## MOVE (reorder): an arranged [param action_id] to arranged [param position]; the actions between
## shift by one. Unarranged actions are placed with PUT.
static func move_check(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary,
		action_id: StringName, position: int) -> CombatResult.Reason:
	var reason := position_check(progress, registry, position)
	if reason == CombatResult.Reason.OK:
		reason = action_check(progress, registry, library, action_id)
	if reason != CombatResult.Reason.OK:
		return reason
	var current := arrangement(progress, registry)
	if not current.has(action_id) or position >= current.size():
		return CombatResult.Reason.EMPTY_POSITION
	return CombatResult.Reason.OK


static func move(current: Array[StringName], action_id: StringName, position: int) -> Array[StringName]:
	var after: Array[StringName] = current.duplicate()
	after.erase(action_id)
	after.insert(position, action_id)
	return after


# --- Readout -------------------------------------------------------------------------------------

## The combat readout for [param progress]. [param library]: resonance passives (Database.library).
static func readout(progress: ProgressState, registry: DefinitionRegistry, library: CombatLibrary) -> CombatReadout:
	var result := CombatReadout.new()
	result.reason = availability(progress)
	result.reason_text = CombatResult.reason_text_for(result.reason)
	result.capacity = capacity(progress, registry)
	result.arranged = arrangement(progress, registry)
	var character := CharacterReadout.build(progress, registry, library)
	for index in POSITIONS:
		var locked := index >= result.capacity
		result.positions.append({"index": index, "locked": locked,
			"reason": CombatResult.Reason.LOCKED_POSITION if locked else CombatResult.Reason.OK,
			"reason_text": WorldCopy.COMBAT_LOCKED_POSITION if locked else "",
			"action_id": result.arranged[index] if index < result.arranged.size() else &""})
	for entry in character.actions + character.magic:
		var candidate: Dictionary = entry.duplicate(true)
		candidate.position = result.arranged.find(entry.id)
		candidate.arranged = candidate.position >= 0
		candidate.reason = result.reason
		candidate.selectable = result.reason == CombatResult.Reason.OK
		candidate.reason_text = result.reason_text if not candidate.selectable else (
			WorldCopy.COMBAT_ARRANGED % (candidate.position + 1) if candidate.arranged else WorldCopy.COMBAT_UNARRANGED)
		var facts: PackedStringArray = candidate.facts
		facts.append(candidate.reason_text)
		candidate.facts = facts
		if candidate.category_id == Enums.ActionCategory.MAGIC:
			result.magic.append(candidate)
		else:
			result.actions.append(candidate)
		if not candidate.arranged:
			result.unarranged.append(entry.id)
	for entry in character.skills:
		var skill: Dictionary = entry.duplicate(true)
		skill.selectable = false
		skill.reason = CombatResult.Reason.PASSIVE_SKILL
		skill.reason_text = WorldCopy.COMBAT_PASSIVE if skill.get("passive", false) else ""
		result.skills.append(skill)
	var loadout := PartyLoadout.from_ids(registry, progress.loadout_ids())
	if loadout.companion != null:
		var companion_actions := PackedStringArray()
		for action in UnitFactory.companion_actions(loadout.companion, registry.balance):
			companion_actions.append(action.display_name)
		result.companion = {"name": loadout.companion.display_name, "actions": companion_actions}
	return result
