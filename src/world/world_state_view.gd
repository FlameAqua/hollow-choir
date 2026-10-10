class_name WorldStateView
extends Node2D
## Shows its children (and enables their collision) only while one explicit typed condition holds:
## a world flag, or an encounter site's cleared state. Art never changes save truth; this node only
## follows it. Position it at its content's foot so depth sorting stays correct.
##
## V0.5C appends the exploration states: a gathered node, a found secret, a solved puzzle and a rune
## lit in its puzzle's current attempt. Puzzle truth stays in WorldState; this only shows it.

enum Source { FLAG, CLEARED, GATHERED, FOUND, SOLVED, RUNE_LIT }

@export var source: Source = Source.FLAG
## FLAG: a WorldDefinition flag. CLEARED: an encounter landmark ID. GATHERED: a GATHERING landmark
## ID. FOUND: a SECRET landmark ID. SOLVED: a puzzle ID. RUNE_LIT: a RUNE landmark ID.
@export var key: StringName = &""
## Visible while the condition equals this value.
@export var show_when: bool = true


func matches(world: WorldState) -> bool:
	var value := false
	match source:
		Source.FLAG:
			value = world.flag(key)
		Source.CLEARED:
			value = world.is_cleared(key)
		Source.GATHERED:
			value = world.is_gathered(key)
		Source.FOUND:
			value = world.is_found(key)
		Source.SOLVED:
			value = world.is_solved(key)
		Source.RUNE_LIT:
			value = world.is_rune_lit(key)
	return value == show_when


func apply(world: WorldState) -> void:
	var active := matches(world)
	visible = active
	for shape in find_children("*", "CollisionShape2D", true, false):
		(shape as CollisionShape2D).set_deferred("disabled", not active)
	for light in find_children("*", "PointLight2D", true, false):
		(light as PointLight2D).enabled = active
