class_name WorldState
extends RefCounted
## The optional `world` section of a save (V0.4). Additive to save version 1: an older save has no
## section and starts at the default square with its research/mastery/loadout untouched. Holds only
## IDs, two independent flags and plain data; never nodes or mutable resources.

var area: StringName = &""
var anchor: StringName = &""
var discovered: Array[StringName] = []
var links: Array[StringName] = []
var cleared: Array[StringName] = []
var wayside_bell_restored := false
var return_latch_open := false
## The captured encounter saved before launch, or null.
var pending_entry: EncounterEntry
## Completion token of the last committed victory (a repeat is a no-op).
var last_applied_token: String = ""
## Monotonic counter for completion tokens.
var entry_serial: int = 0
## V0.5C exploration (ExplorationRules). Gathered GATHERING landmark ids: Reset journey keeps them
## (a node yields once per save). Found SECRET landmark ids, solved puzzle ids and each unsolved
## puzzle's current rune input (rune landmark ids in strike order) are journey state.
var gathered: Array[StringName] = []
var found: Array[StringName] = []
var solved: Array[StringName] = []
var rune_input: Dictionary[StringName, Array] = {}


static func fresh(definition: WorldDefinition) -> WorldState:
	var state := WorldState.new()
	state.area = definition.start_area
	state.anchor = definition.start_anchor
	return state


func flag(flag_id: StringName) -> bool:
	match flag_id:
		WorldDefinition.FLAG_BELL:
			return wayside_bell_restored
		WorldDefinition.FLAG_LATCH:
			return return_latch_open
	return false


func is_cleared(site_id: StringName) -> bool:
	return cleared.has(site_id)


func is_gathered(landmark_id: StringName) -> bool:
	return gathered.has(landmark_id)


func is_found(landmark_id: StringName) -> bool:
	return found.has(landmark_id)


func is_solved(puzzle_id: StringName) -> bool:
	return solved.has(puzzle_id)


## The current attempt at [param puzzle_id] (a copy; empty when none or solved).
func rune_input_of(puzzle_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in rune_input.get(puzzle_id, []):
		result.append(StringName(value))
	return result


## Is [param rune_id] part of a puzzle's current attempt? (Scene views: WorldStateView RUNE_LIT.)
func is_rune_lit(rune_id: StringName) -> bool:
	for puzzle_id: StringName in rune_input:
		if rune_input[puzzle_id].has(rune_id):
			return true
	return false


func is_discovered(landmark_id: StringName) -> bool:
	return discovered.has(landmark_id)


func discover(landmark_id: StringName) -> bool:
	if discovered.has(landmark_id):
		return false
	discovered.append(landmark_id)
	return true


func add_link(path_id: StringName) -> bool:
	if links.has(path_id):
		return false
	links.append(path_id)
	return true


func to_dict() -> Dictionary:
	return {
		"area": String(area),
		"anchor": String(anchor),
		"discovered": _strings(discovered),
		"links": _strings(links),
		"cleared": _strings(cleared),
		"flags": {
			String(WorldDefinition.FLAG_BELL): wayside_bell_restored,
			String(WorldDefinition.FLAG_LATCH): return_latch_open,
		},
		"pending_entry": pending_entry.to_dict() if pending_entry != null else null,
		"last_applied_token": last_applied_token,
		"entry_serial": entry_serial,
		"gathered": _strings(gathered),
		"found": _strings(found),
		"solved": _strings(solved),
		"rune_input": _input_strings(),
	}


func _input_strings() -> Dictionary:
	var result := {}
	for puzzle_id: StringName in rune_input:
		var runes := []
		for rune_id in rune_input[puzzle_id]:
			runes.append(String(rune_id))
		result[String(puzzle_id)] = runes
	return result


## Reads a saved section without trusting it: wrong types become defaults. Call sanitize() before use.
static func from_dict(data: Variant) -> WorldState:
	var state := WorldState.new()
	if typeof(data) != TYPE_DICTIONARY:
		return state
	state.area = StringName(str(data.get("area", "")))
	state.anchor = StringName(str(data.get("anchor", "")))
	state.discovered = _ids(data.get("discovered", []))
	state.links = _ids(data.get("links", []))
	state.cleared = _ids(data.get("cleared", []))
	var flags: Variant = data.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		state.wayside_bell_restored = _bool(flags.get(String(WorldDefinition.FLAG_BELL)))
		state.return_latch_open = _bool(flags.get(String(WorldDefinition.FLAG_LATCH)))
	var pending: Variant = data.get("pending_entry")
	if typeof(pending) == TYPE_DICTIONARY:
		state.pending_entry = EncounterEntry.from_dict(pending)
	state.last_applied_token = str(data.get("last_applied_token", ""))
	state.entry_serial = maxi(0, ProgressState.number(data.get("entry_serial"), 0))
	state.gathered = _ids(data.get("gathered", []))
	state.found = _ids(data.get("found", []))
	state.solved = _ids(data.get("solved", []))
	var input: Variant = data.get("rune_input", {})
	if typeof(input) == TYPE_DICTIONARY:
		for key: Variant in input:
			if (typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME) and typeof(input[key]) == TYPE_ARRAY:
				state.rune_input[StringName(key)] = Array(_ids(input[key]))
	return state


## Drops IDs outside the approved content and recovers an invalid area/anchor to the world start,
## keeping every valid piece of progress. Returns the problems found (empty when clean).
func sanitize(definition: WorldDefinition) -> PackedStringArray:
	var problems := PackedStringArray()
	if not definition.is_anchor(area, anchor):
		if area != &"" or anchor != &"":
			problems.append("unknown anchor %s/%s; resuming at the square" % [area, anchor])
		area = definition.start_area
		anchor = definition.start_anchor
	var landmark_ids := {}
	var path_ids := {}
	var site_ids := {}
	for entry in definition.areas:
		for landmark in entry.landmarks:
			landmark_ids[landmark.id] = true
			if landmark.kind == LandmarkDefinition.Kind.ENCOUNTER:
				site_ids[landmark.id] = true
		for path in entry.paths:
			path_ids[path.id] = true
	problems.append_array(_keep_known(discovered, landmark_ids, "landmark"))
	problems.append_array(_keep_known(links, path_ids, "link"))
	problems.append_array(_keep_known(cleared, site_ids, "encounter site"))
	problems.append_array(_sanitize_exploration(definition))
	if pending_entry != null:
		var located := definition.find_landmark(pending_entry.site_id())
		if located.is_empty() or (located[1] as LandmarkDefinition).kind != LandmarkDefinition.Kind.ENCOUNTER \
				or not definition.is_anchor(pending_entry.area_id(), pending_entry.approach_anchor()):
			problems.append("pending encounter %s is not approved content; dropped" % pending_entry.site_id())
			pending_entry = null
	return problems


## V0.5C: keeps only approved gathering nodes, secrets and puzzles, and each unsolved puzzle's
## input that is a valid partial attempt of its own runes (shorter than its solution).
func _sanitize_exploration(definition: WorldDefinition) -> PackedStringArray:
	var problems := PackedStringArray()
	var nodes := {}
	for entry in definition.gathering:
		if entry != null:
			nodes[entry.landmark] = true
	var secret_ids := {}
	for entry in definition.secrets:
		if entry != null:
			secret_ids[entry.landmark] = true
	var puzzle_ids := {}
	for entry in definition.puzzles:
		if entry != null:
			puzzle_ids[entry.id] = true
	problems.append_array(_keep_known(gathered, nodes, "gathering node"))
	problems.append_array(_keep_known(found, secret_ids, "secret"))
	problems.append_array(_keep_known(solved, puzzle_ids, "puzzle"))
	for puzzle_id: StringName in rune_input.keys():
		var entry := ExplorationRules.puzzle(definition, puzzle_id)
		var input := rune_input_of(puzzle_id)
		var valid := entry != null and not solved.has(puzzle_id) and input.size() < entry.solution.size() 			and input.all(func(rune_id: StringName) -> bool: return entry.runes.has(rune_id))
		if not valid:
			if entry == null or not input.is_empty():
				problems.append("rune input for %s dropped" % puzzle_id)
			rune_input.erase(puzzle_id)
		elif input.is_empty():
			rune_input.erase(puzzle_id)
	return problems


static func _keep_known(ids: Array[StringName], known: Dictionary, what: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for index in range(ids.size() - 1, -1, -1):
		if not known.has(ids[index]):
			problems.append("unknown %s %s dropped" % [what, ids[index]])
			ids.remove_at(index)
	var unique: Array[StringName] = []
	for id in ids:
		if not unique.has(id):
			unique.append(id)
	ids.assign(unique)
	return problems


## Only a real boolean true counts; strings, numbers or nulls never become unlocks.
static func _bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value


static func _strings(ids: Array[StringName]) -> Array:
	var result := []
	for id in ids:
		result.append(String(id))
	return result


static func _ids(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
			result.append(StringName(value))
	return result
