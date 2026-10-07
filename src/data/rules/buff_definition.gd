class_name BuffDefinition
extends Resource
## A temporary trait placed on a unit: stances, empowerments, marks and debuffs.
##
## Granted by EffectType.GRANT_BUFF. Re-granting an active buff refreshes it (no stacking).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Short color-independent label for the HUD.
@export var glyph: String = ""
@export var is_debuff: bool = false
## Marks the unit as guarding (AI sees this; HUD shows a shield).
@export var is_guard_stance: bool = false
@export var expiry: Enums.BuffExpiry = Enums.BuffExpiry.OWNER_TURN_START
## Number of expiry events before removal (NEXT_ACTION: number of qualifying actions).
@export var duration: int = 1
## NEXT_ACTION buffs are consumed only by an owner action passing all of these.
@export var consume_conditions: Array[ConditionDefinition] = []
## Rules active while the buff lasts.
@export var trait_def: TraitDefinition


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("buff without id")
	if duration < 1:
		problems.append("buff %s duration must be >= 1" % id)
	if trait_def != null:
		problems.append_array(trait_def.validate())
	for condition in consume_conditions:
		if condition == null:
			problems.append("null consume condition in buff %s" % id)
		else:
			problems.append_array(condition.validate())
	return problems
