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
	}


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
	state.entry_serial = maxi(0, int(data.get("entry_serial", 0)))
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
	if pending_entry != null:
		var found := definition.find_landmark(pending_entry.site_id())
		if found.is_empty() or (found[1] as LandmarkDefinition).kind != LandmarkDefinition.Kind.ENCOUNTER \
				or not definition.is_anchor(pending_entry.area_id(), pending_entry.approach_anchor()):
			problems.append("pending encounter %s is not approved content; dropped" % pending_entry.site_id())
			pending_entry = null
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
