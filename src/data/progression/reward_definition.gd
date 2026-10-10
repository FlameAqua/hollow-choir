class_name RewardDefinition
extends Resource
## One stable campaign reward (V0.5A salvage). [member id] is the persistent claim id: a save
## receives the reward exactly once, inside the same WorldSession write that commits its source
## accomplishment, and Reset journey keeps the claim. Eligibility is this id, never an encounter
## token (a reset gives the same site a new token). Quantities are provisional slice data that the
## Director may tune here; no code names them.

enum Source {
	## The first committed victory at an ENCOUNTER landmark ([member source_id] = landmark id).
	SITE_VICTORY = 0,
	## The deliberate world action that sets a world flag ([member source_id] = a
	## WorldDefinition flag, e.g. wayside_bell_restored set by ringing the bell).
	WORLD_FLAG = 1,
	## V0.5C: gathering a node ([member source_id] = its GATHERING landmark id). Once per save.
	GATHERED = 2,
	## V0.5C: finding a revealed secret ([member source_id] = its SECRET landmark id).
	SECRET_FOUND = 3,
	## V0.5C: solving a rune puzzle ([member source_id] = the puzzle id).
	PUZZLE_SOLVED = 4,
}

## Claim ids are lowercase words joined by dots ("first_footsteps.patrol").
const MAX_ID_LENGTH := 64

static var _id_pattern: RegEx

@export var id: StringName = &""
## Public label shown with the reward ("Patrol salvage"). Never an encounter or species name.
@export var display_name: String = ""
@export var source: Source = Source.SITE_VICTORY
@export var source_id: StringName = &""
@export var items: Array[RewardItem] = []
## Permanent equipment bag expansion, unlocked by this saved claim. Ingredients use no slots.
@export_range(0, 50, 5) var equipment_slots: int = 0


static func is_valid_id(value: String) -> bool:
	if _id_pattern == null:
		_id_pattern = RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)*$")
	return value.length() <= MAX_ID_LENGTH and _id_pattern.search(value) != null


## Self-contained checks. Registry references, sources and totals: RewardRules.validate_catalog().
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not is_valid_id(id):
		problems.append("reward id '%s' must be lowercase dotted words (a-z, 0-9, _), at most %d characters" % [
			id, MAX_ID_LENGTH])
	if display_name.is_empty():
		problems.append("reward %s needs a public display_name" % id)
	if not Source.values().has(source):
		problems.append("reward %s has an unknown source kind %d" % [id, source])
	if source_id == &"":
		problems.append("reward %s needs a source_id" % id)
	if equipment_slots < 0 or equipment_slots > 50 or equipment_slots % 5 != 0:
		problems.append("reward %s: equipment_slots must be 0-50 in rows of five" % id)
	if items.is_empty() and equipment_slots == 0:
		problems.append("reward %s grants nothing" % id)
	var seen := {}
	for item in items:
		if item == null:
			problems.append("reward %s has a null item" % id)
			continue
		problems.append_array(item.validate(id))
		var key := "%d:%s" % [item.kind, item.item_id()]
		if item.item_id() != &"" and seen.has(key):
			problems.append("reward %s lists %s twice" % [id, item.item_id()])
		seen[key] = true
	return problems
