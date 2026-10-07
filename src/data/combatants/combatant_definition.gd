class_name CombatantDefinition
extends Resource
## Shared stat block for anything that takes part in battle.
##
## Stats follow the GDD's short list: Heart (max_hp), Force, Guard, Tempo, Focus (capacity).
## Damage = raw * 100 / (100 + Guard); raw = power * (1 + Force / 100).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
## Heart.
@export var max_hp: int = 100
## Attack potency: +1% damage per point.
@export var force: int = 10
## Mitigation: damage * 100 / (100 + guard).
@export var guard: int = 10
## Initiative: higher acts earlier in the round.
@export var tempo: int = 10
## Focus capacity.
@export var max_focus: int = 10
## Focus at battle start (-1 = BalanceConfig default for the unit's side).
@export var starting_focus: int = -1
## Species mechanics / passives (owner = this unit).
@export var traits: Array[TraitDefinition] = []

@export_group("Visual")
@export var shape: Enums.VisualShape = Enums.VisualShape.HUMANOID
@export var color: Color = Color(0.7, 0.7, 0.75)
## Optional real art; placeholder silhouettes are drawn when absent.
@export var sprite_frames: SpriteFrames
@export var visual_scale: float = 1.0


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("combatant without id")
	if display_name.is_empty():
		problems.append("combatant %s has no display_name" % id)
	if max_hp <= 0:
		problems.append("combatant %s needs max_hp > 0" % id)
	if max_focus < 0 or guard < 0:
		problems.append("combatant %s has negative stats" % id)
	for trait_def in traits:
		if trait_def == null:
			problems.append("combatant %s has a null trait" % id)
		else:
			problems.append_array(trait_def.validate())
	return problems
