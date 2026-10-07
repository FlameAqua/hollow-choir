class_name ModifierDefinition
extends Resource
## A continuous change to a number while its trait is active.
##
## Result of a query = (base + sum of ADD values) * product of MULTIPLY values, considering only
## modifiers whose conditions pass for the query (see ModifierQuery).

@export var stat: Enums.ModifierStat = Enums.ModifierStat.DAMAGE_DEALT
@export var operation: Enums.ModifierOp = Enums.ModifierOp.MULTIPLY
## For MULTIPLY: 1.2 = +20%. For ADD: flat amount in the stat's own units.
@export var value: float = 1.0
## All must pass (evaluated with the query's actor/target, e.g. attacker/defender).
@export var conditions: Array[ConditionDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if operation == Enums.ModifierOp.MULTIPLY and value < 0.0:
		problems.append("negative MULTIPLY modifier")
	for condition in conditions:
		if condition == null:
			problems.append("null condition in modifier")
		else:
			problems.append_array(condition.validate())
	return problems
