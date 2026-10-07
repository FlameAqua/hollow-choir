class_name FamiliarDefinition
extends Resource
## A familiar never takes a turn: it reacts to triggers (GDD: on_perfect_parry, on_potion_used,
## on_status_applied, on_enemy_staggered, on_weakpoint_exposed…). Its trait is owned by the
## protagonist, so trigger relations are relative to the protagonist's side.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## The play style this familiar is meant to encourage (shown at the Menagerie and in tooltips).
@export_multiline var playstyle: String = ""
@export var trait_def: TraitDefinition
@export var shape: Enums.VisualShape = Enums.VisualShape.FLYER
@export var color: Color = Color(0.6, 0.6, 0.7)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("familiar needs id and display_name")
	if trait_def == null or trait_def.triggers.is_empty():
		problems.append("familiar %s needs a trait with at least one trigger" % id)
	elif trait_def != null:
		problems.append_array(trait_def.validate())
	return problems
