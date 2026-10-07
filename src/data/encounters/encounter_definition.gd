class_name EncounterDefinition
extends Resource
## A designed fight: enemies + battlefield conditions + optional pre-combat advantage.
## Used by the CombatSandbox, the simulator and (later) visible overworld enemy groups.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Sandbox grouping label ("Toy", "Briarfen", "Elite", "Boss"…).
@export var group: String = ""
@export var enemies: Array[EnemyDefinition] = []
## At most one MAJOR and one MINOR condition.
@export var conditions: Array[BattlefieldConditionDefinition] = []
@export var advantage: Enums.Advantage = Enums.Advantage.NONE


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("encounter needs id and display_name")
	if enemies.is_empty() or enemies.size() > 4:
		problems.append("encounter %s must have 1..4 enemies" % id)
	var majors := 0
	var minors := 0
	for enemy in enemies:
		if enemy == null:
			problems.append("encounter %s has a null enemy" % id)
	for condition in conditions:
		if condition == null:
			problems.append("encounter %s has a null condition" % id)
			continue
		if condition.severity == Enums.ConditionSeverity.MAJOR:
			majors += 1
		else:
			minors += 1
	if majors > 1 or minors > 1:
		problems.append("encounter %s exceeds 1 major + 1 minor condition" % id)
	return problems
