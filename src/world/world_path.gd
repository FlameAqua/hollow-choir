class_name WorldPath
extends Resource
## An authored walking link between landmarks. The discovered map draws a link once it has been
## walked (or, for a gated link, once its gate is open). Points are tile centres.

@export var id: StringName = &""
@export var points: PackedVector2Array = PackedVector2Array()
@export var width_tiles: int = 4
## A WorldState flag that must be set before the link is walkable / drawable (empty = none).
@export var requires_flag: StringName = &""


## Shortest distance in pixels from [param position] to this path's centre line.
func distance_to(position: Vector2, tile_size: int) -> float:
	var best := INF
	for index in range(points.size() - 1):
		var a := (points[index] + Vector2(0.5, 0.5)) * tile_size
		var b := (points[index + 1] + Vector2(0.5, 0.5)) * tile_size
		best = minf(best, position.distance_to(Geometry2D.get_closest_point_to_segment(position, a, b)))
	return best
