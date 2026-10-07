class_name StatusInstance
extends RefCounted
## A status on a unit. [member remaining] counts turns (TURNS mode) or charges (CHARGES mode).

var status: Enums.StatusId = Enums.StatusId.NONE
var definition: StatusDefinition
var stacks: int = 1
var remaining: int = 1
## Bearer turns elapsed (CHARGES-mode hard expiry).
var turns_active: int = 0
var source_uid: int = -1
var trait_instances: Array[TraitInstance] = []


func deactivate() -> void:
	for trait_instance in trait_instances:
		trait_instance.active = false
