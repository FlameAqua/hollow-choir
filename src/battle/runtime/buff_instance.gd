class_name BuffInstance
extends RefCounted
## A temporary trait on a unit (stance, empowerment, mark, debuff).

var definition: BuffDefinition
var remaining: int = 1
var source_uid: int = -1
## Null when the buff has no rules of its own (pure marker).
var trait_instance: TraitInstance


func deactivate() -> void:
	if trait_instance != null:
		trait_instance.active = false
