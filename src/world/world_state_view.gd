class_name WorldStateView
extends Node2D
## Shows its children (and enables their collision) only while one explicit typed condition holds:
## a world flag, or an encounter site's cleared state. Art never changes save truth; this node only
## follows it. Position it at its content's foot so depth sorting stays correct.

enum Source { FLAG, CLEARED }

@export var source: Source = Source.FLAG
## FLAG: a WorldDefinition flag. CLEARED: an encounter landmark ID.
@export var key: StringName = &""
## Visible while the condition equals this value.
@export var show_when: bool = true


func matches(world: WorldState) -> bool:
	var value := world.flag(key) if source == Source.FLAG else world.is_cleared(key)
	return value == show_when


func apply(world: WorldState) -> void:
	var active := matches(world)
	visible = active
	for shape in find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).set_deferred("disabled", not active)
	for light in find_children("*", "PointLight2D", true, false):
		(light as PointLight2D).enabled = active
