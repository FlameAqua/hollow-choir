@tool
class_name EffectDefinition
extends Resource
## One thing that happens: damage, healing, Focus, Stagger, statuses, buffs, battlefield changes…
##
## Interpreted by EffectResolver. Effects on an action resolve top to bottom after the action's hit;
## each effect's [member conditions] are checked at the moment it resolves.
## Within an action, DAMAGE / HEAL / STAGGER_DAMAGE amounts scale with the execution grade.

const E := Enums.EffectType

const FIELDS_BY_TYPE := {
	E.DAMAGE: ["target", "amount", "scaling", "damage_type"],
	E.HEAL: ["target", "amount", "scaling"],
	E.GAIN_FOCUS: ["target", "amount", "scaling"],
	E.LOSE_FOCUS: ["target", "amount", "scaling"],
	E.STAGGER_DAMAGE: ["target", "amount", "scaling"],
	E.APPLY_STATUS: ["target", "amount", "status", "duration"],
	E.REMOVE_STATUS: ["target", "status"],
	E.EXTEND_STATUS: ["target", "amount", "status"],
	E.GRANT_BUFF: ["target", "buff"],
	E.EXPOSE_WEAK_POINT: ["target", "duration"],
	E.DELAY_TURN: ["target"],
	E.INTERCEPT: ["target"],
	E.CHAIN_STATUS: ["target", "amount", "status", "duration", "filter_status"],
	E.CLEANSE: ["target"],
	E.RESTORE_STAGGER: ["target", "amount", "scaling"],
	E.ADD_CONDITION: ["battlefield_condition"],
	E.REMOVE_CONDITION: ["battlefield_condition"],
	E.REMOVE_BUFF: ["target", "buff"],
}
const ALWAYS_VISIBLE := ["type", "conditions", "chance"]

@export var type: Enums.EffectType = Enums.EffectType.DAMAGE:
	set(value):
		type = value
		notify_property_list_changed()
## Who receives the effect. In an action: OWNER/ACTOR = the user, TARGET = each target.
@export var target: Enums.EffectTarget = Enums.EffectTarget.TARGET
## Damage/heal/Focus/Stagger amount, status stacks (APPLY/CHAIN) or extension (EXTEND).
@export var amount: float = 0.0
@export var scaling: Enums.AmountScaling = Enums.AmountScaling.FLAT
@export var damage_type: Enums.DamageType = Enums.DamageType.PURE
@export var status: Enums.StatusId = Enums.StatusId.NONE
## Status turns (0 = status default) or weak-point exposure rounds.
@export var duration: int = 0
## CHAIN_STATUS only spreads to units that currently have this status.
@export var filter_status: Enums.StatusId = Enums.StatusId.NONE
@export var buff: BuffDefinition
@export var battlefield_condition: BattlefieldConditionDefinition
## All must pass for this effect to resolve.
@export var conditions: Array[ConditionDefinition] = []
## Deterministic chance (battle RNG).
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	if prop_name in ALWAYS_VISIBLE or not _is_field(prop_name):
		return
	if not (prop_name in FIELDS_BY_TYPE.get(type, [])):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _is_field(prop_name: String) -> bool:
	for fields: Array in FIELDS_BY_TYPE.values():
		if prop_name in fields:
			return true
	return false


## True for effects whose amount scales with the execution grade inside an action.
func is_grade_scaled() -> bool:
	return type in [E.DAMAGE, E.HEAL, E.STAGGER_DAMAGE]


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var fields: Array = FIELDS_BY_TYPE.get(type, [])
	var label: String = Enums.EffectType.keys()[type]
	if "status" in fields and status == Enums.StatusId.NONE:
		problems.append("effect %s needs a status" % label)
	if "buff" in fields and buff == null:
		problems.append("effect %s needs a buff" % label)
	if "battlefield_condition" in fields and battlefield_condition == null:
		problems.append("effect %s needs a battlefield_condition" % label)
	if type == E.CHAIN_STATUS and filter_status == Enums.StatusId.NONE:
		problems.append("CHAIN_STATUS needs a filter_status")
	if type == E.APPLY_STATUS and amount < 1.0:
		problems.append("APPLY_STATUS amount is the stack count and must be >= 1")
	for condition in conditions:
		if condition == null:
			problems.append("null condition in effect %s" % label)
		else:
			problems.append_array(condition.validate())
	return problems
