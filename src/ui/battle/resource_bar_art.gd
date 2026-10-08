class_name ResourceBarArt
extends RefCounted
## Shared stepped iron/brass tracks, with beveled fills. Decoration never counts as remaining HP.
const TRACK = preload("res://assets/art/global/ui/frames/choir_v01/styles/bar_track.tres")
const SLIM_TRACK = preload("res://assets/art/global/ui/frames/choir_v01/styles/bar_track_slim.tres")
const ALLY = preload("res://assets/art/global/ui/frames/choir_v01/styles/hp_ally.tres")
const ENEMY = preload("res://assets/art/global/ui/frames/choir_v01/styles/hp_enemy.tres")
const BREAK = preload("res://assets/art/global/ui/frames/choir_v01/styles/resource_stagger.tres")

static func fill_rect(track: Rect2, ratio: float, slim: bool = false) -> Rect2:
	var inner := track.grow_individual(-2, -1 if slim else -2, -2, -1 if slim else -2)
	inner.size.x = maxf(0, inner.size.x) * clampf(ratio, 0, 1)
	return inner

static func paint(canvas: CanvasItem, rect: Rect2, ratio: float, enemy: bool, slim: bool = false) -> void:
	canvas.draw_style_box(SLIM_TRACK if slim else TRACK, rect)
	var fill := fill_rect(rect, ratio, slim)
	if fill.size.x > 0:
		canvas.draw_style_box(BREAK if slim else ENEMY if enemy else ALLY, fill)
