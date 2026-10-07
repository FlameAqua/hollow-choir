class_name TriggeredEffectDefinition
extends Resource
## "When <trigger> happens to a unit related to my owner, and <conditions>, do <effects>."
##
## Familiars, weapon identities, equipment rules, statuses and battlefield conditions all use this.
## [member watch] picks the event role (actor or target) whose relation to the trait owner is
## checked against [member relation]. Battlefield traits have no owner: use relation ANY.

@export var trigger: Enums.TriggerType = Enums.TriggerType.HIT_LANDED
@export var watch: Enums.TriggerWatch = Enums.TriggerWatch.ACTOR
@export var relation: Enums.TriggerRelation = Enums.TriggerRelation.OWNER
@export var conditions: Array[ConditionDefinition] = []
@export var effects: Array[EffectDefinition] = []
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## 0 = unlimited.
@export var max_per_round: int = 0
## 0 = unlimited.
@export var max_per_battle: int = 0
## Show the owning trait's name when this fires (audiovisual feedback for every mechanic).
@export var announce: bool = true


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if effects.is_empty():
		problems.append("trigger %s has no effects" % Enums.TriggerType.keys()[trigger])
	for condition in conditions:
		if condition == null:
			problems.append("null condition in trigger")
		else:
			problems.append_array(condition.validate())
	for effect in effects:
		if effect == null:
			problems.append("null effect in trigger")
		else:
			problems.append_array(effect.validate())
	return problems
