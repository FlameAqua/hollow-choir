class_name ActiveCondition
extends RefCounted
## A battlefield condition in play, with its trait instances (owner = none).

var definition: BattlefieldConditionDefinition
var trait_instances: Array[TraitInstance] = []


func deactivate() -> void:
	for trait_instance in trait_instances:
		trait_instance.active = false
