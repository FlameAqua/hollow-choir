class_name BattlefieldConditionDefinition
extends Resource
## An environment rule. Usually one MAJOR and optionally one MINOR per battle.
##
## [member description] is always shown in the condition panel: the player should never wonder
## why a mechanic changed. Behaviour is entirely in [member traits] (owner = none).

@export var id: StringName = &""
@export var display_name: String = ""
@export var severity: Enums.ConditionSeverity = Enums.ConditionSeverity.MAJOR
## One-line consequence for the battle's condition ribbon ("Evading makes you Wet."). Optional:
## the ribbon falls back to [member description].
@export var summary: String = ""
@export_multiline var description: String = ""
@export_multiline var details: String = ""
@export var glyph: String = ""
@export var tint: Color = Color(0.4, 0.6, 0.9, 0.25)
@export var traits: Array[TraitDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("battlefield condition without id")
	if description.is_empty():
		problems.append("battlefield condition %s must explain its effect" % id)
	for trait_def in traits:
		if trait_def == null:
			problems.append("null trait in condition %s" % id)
			continue
		for trigger in trait_def.triggers:
			if trigger != null and trigger.relation != Enums.TriggerRelation.ANY:
				problems.append("condition %s trigger must use relation ANY (no owner)" % id)
		problems.append_array(trait_def.validate())
	return problems
