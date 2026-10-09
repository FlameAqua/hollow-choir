@tool
class_name WorldPoint
extends Node2D
## The runtime position of one landmark (interaction point, discovery centre, map marker). Its node
## name is the landmark ID. Move it in the editor; the definition keeps the ID and rules.

@export var radius: float = 48.0:
	set(value):
		radius = value
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.8), 1.0)
		draw_circle(Vector2.ZERO, 3.0, Color(0.4, 0.9, 1.0))
