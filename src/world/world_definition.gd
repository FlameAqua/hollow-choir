class_name WorldDefinition
extends Resource
## The authored V0.4 journey: areas, paired portals and the closed set of world flags. Saved
## world IDs are validated against this; anything else is dropped rather than invented.

const PATH := "res://data/world/first_footsteps.tres"
const FLAG_BELL := &"wayside_bell_restored"
const FLAG_LATCH := &"return_latch_open"

@export var tile_size: int = 32
@export var start_area: StringName = &"gloamstead"
@export var start_anchor: StringName = &"town_bell"
@export var areas: Array[AreaDefinition] = []
@export var portals: Array[PortalDefinition] = []
@export var flags: Array[StringName] = [FLAG_BELL, FLAG_LATCH]
## V0.5C exploration vocabulary placed in these areas (rules and persistence: ExplorationRules).
@export var gathering: Array[GatheringDefinition] = []
@export var secrets: Array[SecretDefinition] = []
@export var puzzles: Array[RuneSequenceDefinition] = []

static var _cached: WorldDefinition


static func load_default() -> WorldDefinition:
	if _cached == null:
		_cached = load(PATH) as WorldDefinition
	return _cached


func area(area_id: StringName) -> AreaDefinition:
	for entry in areas:
		if entry.id == area_id:
			return entry
	return null


func portal_from(area_id: StringName, landmark_id: StringName) -> PortalDefinition:
	for entry in portals:
		if entry.from_area == area_id and entry.from_landmark == landmark_id:
			return entry
	return null


## The area and landmark owning an encounter site ID, or [] if unknown.
func find_landmark(landmark_id: StringName) -> Array:
	for entry in areas:
		var found := entry.landmark(landmark_id)
		if found != null:
			return [entry, found]
	return []


func encounter_sites() -> Array[LandmarkDefinition]:
	var result: Array[LandmarkDefinition] = []
	for entry in areas:
		for landmark in entry.landmarks:
			if landmark.kind == LandmarkDefinition.Kind.ENCOUNTER:
				result.append(landmark)
	return result


func is_anchor(area_id: StringName, anchor_id: StringName) -> bool:
	var entry := area(area_id)
	return entry != null and entry.anchors().has(anchor_id)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not is_anchor(start_area, start_anchor):
		problems.append("world start %s/%s is not a safe anchor" % [start_area, start_anchor])
	var ids := {}
	for entry in areas:
		problems.append_array(entry.validate())
		for landmark in entry.landmarks:
			if ids.has(landmark.id):
				problems.append("landmark id %s is used in two areas" % landmark.id)
			ids[landmark.id] = true
	for portal in portals:
		var from := area(portal.from_area)
		if from == null or from.landmark(portal.from_landmark) == null:
			problems.append("portal from unknown %s/%s" % [portal.from_area, portal.from_landmark])
		if not is_anchor(portal.to_area, portal.arrival_anchor):
			problems.append("portal arrives at unknown anchor %s/%s" % [portal.to_area, portal.arrival_anchor])
		if portal_from(portal.to_area, portal.arrival_anchor) == null:
			problems.append("portal %s/%s has no return pair" % [portal.from_area, portal.from_landmark])
	problems.append_array(ExplorationRules.validate(self))
	return problems
