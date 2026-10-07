class_name ProtagonistDefinition
extends CombatantDefinition
## The Hollow. Weapon actions come from the equipped weapon; magic and other innate actions here.

## Innate Magic/Techniques available regardless of weapon (e.g. elemental arts).
@export var innate_actions: Array[ActionDefinition] = []


func validate() -> PackedStringArray:
	var problems := super.validate()
	for action in innate_actions:
		if action == null:
			problems.append("protagonist %s has a null innate action" % id)
	return problems
