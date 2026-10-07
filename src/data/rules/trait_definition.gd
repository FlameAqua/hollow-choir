class_name TraitDefinition
extends Resource
## A named package of rules: continuous modifiers plus triggered effects.
##
## The single building block for weapon identities, equipment properties, resonance synergies,
## companion passives, familiars, status behaviour, battlefield conditions and species mechanics
## (DECISION_LOG D-004).

@export var id: StringName = &""
@export var display_name: String = ""
## Simple tooltip text (immediate layer).
@export_multiline var description: String = ""
## Analysis-layer text shown while holding the info key. Optional.
@export_multiline var details: String = ""
@export var modifiers: Array[ModifierDefinition] = []
@export var triggers: Array[TriggeredEffectDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("trait %s has no display_name" % id)
	for modifier in modifiers:
		if modifier == null:
			problems.append("null modifier in trait %s" % id)
		else:
			problems.append_array(modifier.validate())
	for trigger in triggers:
		if trigger == null:
			problems.append("null trigger in trait %s" % id)
		else:
			problems.append_array(trigger.validate())
	return problems
