class_name AreaDefinition
extends Resource
## One connected walkable area (V0.4: Gloamstead, Briarfen Reedway). The scene owns geometry
## (tiles, collision, markers); this definition owns stable IDs, public text and map links.

@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var size_tiles: Vector2i = Vector2i(40, 30)
## Fallback safe anchor for this area (an invalid saved anchor recovers to the world default).
@export var default_anchor: StringName = &""
## Safe anchors that are not landmarks (encounter approaches, the portal arrival points).
@export var extra_anchors: Array[StringName] = []
@export var landmarks: Array[LandmarkDefinition] = []
@export var paths: Array[WorldPath] = []
## Optional presentation music cue. Empty = intentional silence (no approved exploration cue yet).
@export var music_cue: StringName = &""


func landmark(landmark_id: StringName) -> LandmarkDefinition:
	for entry in landmarks:
		if entry.id == landmark_id:
			return entry
	return null


func path(path_id: StringName) -> WorldPath:
	for entry in paths:
		if entry.id == path_id:
			return entry
	return null


## Every named safe anchor in this area.
func anchors() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in landmarks:
		if entry.safe_anchor:
			result.append(entry.id)
	for anchor in extra_anchors:
		if not result.has(anchor):
			result.append(anchor)
	return result


func pixel_size(tile_size: int) -> Vector2:
	return Vector2(size_tiles * tile_size)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("area without id or name")
	if not ResourceLoader.exists(scene_path):
		problems.append("%s: scene %s missing" % [id, scene_path])
	if not anchors().has(default_anchor):
		problems.append("%s: default anchor %s is not a safe anchor" % [id, default_anchor])
	var seen := {}
	for entry in landmarks:
		problems.append_array(entry.validate(id))
		if seen.has(entry.id):
			problems.append("%s: duplicate landmark %s" % [id, entry.id])
		seen[entry.id] = true
	for entry in paths:
		if entry.points.size() < 2:
			problems.append("%s: path %s needs two points" % [id, entry.id])
	return problems
