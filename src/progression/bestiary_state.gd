class_name BestiaryState
extends RefCounted
## Research points per enemy species. Levels derive from ResearchConfig thresholds, so tuning the
## thresholds never invalidates a save.

## enemy id -> research points
var points: Dictionary[StringName, int] = {}
## enemy id -> ResearchSource values ever earned (for the Observatory's "how you learned this").
var sources: Dictionary[StringName, PackedInt32Array] = {}


func add(enemy_id: StringName, source: Enums.ResearchSource, amount: int) -> void:
	points[enemy_id] = points.get(enemy_id, 0) + maxi(0, amount)
	var known: PackedInt32Array = sources.get(enemy_id, PackedInt32Array())
	if not known.has(source):
		known.append(source)
		sources[enemy_id] = known


func points_for(enemy_id: StringName) -> int:
	return points.get(enemy_id, 0)


func level(enemy_id: StringName, config: ResearchConfig) -> Enums.ResearchLevel:
	return config.level_for_points(points_for(enemy_id))


## enemy id -> ResearchLevel, ready to hand to a BattleSetup.
func levels(config: ResearchConfig) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for enemy_id: StringName in points:
		result[enemy_id] = config.level_for_points(points[enemy_id])
	return result


func to_dict() -> Dictionary:
	var source_data := {}
	for enemy_id: StringName in sources:
		source_data[String(enemy_id)] = Array(sources[enemy_id])
	var point_data := {}
	for enemy_id: StringName in points:
		point_data[String(enemy_id)] = points[enemy_id]
	return {"points": point_data, "sources": source_data}


static func from_dict(data: Dictionary) -> BestiaryState:
	var state := BestiaryState.new()
	var point_data: Dictionary = data.get("points", {})
	for key: String in point_data:
		state.points[StringName(key)] = int(point_data[key])
	var source_data: Dictionary = data.get("sources", {})
	for key: String in source_data:
		var list := PackedInt32Array()
		for value in source_data[key]:
			list.append(int(value))
		state.sources[StringName(key)] = list
	return state
