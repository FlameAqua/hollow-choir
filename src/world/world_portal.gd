@tool
class_name WorldPortal
extends Node2D
## A portal trigger rectangle centred on this node; the node name is the portal landmark ID. It is
## not a wall. Arrival anchors must lie outside every trigger (validated by the world tests).

@export var size: Vector2 = Vector2(96, 96):
	set(value):
		size = value
		queue_redraw()


func trigger_rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size * 0.5, size), Color(1.0, 0.8, 0.3, 0.35))
		draw_rect(Rect2(-size * 0.5, size), Color(1.0, 0.8, 0.3), false, 1.0)
