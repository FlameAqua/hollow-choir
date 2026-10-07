@tool
class_name ConditionDefinition
extends Resource
## One boolean test, evaluated by ConditionEvaluator against a RuleContext.
##
## Used by triggered effects, conditional modifiers, effect gates and enemy action legality.
## Only the fields relevant to [member type] are shown in the inspector.

const C := Enums.ConditionType

## Which fields each condition type uses (drives inspector visibility and validation).
const FIELDS_BY_TYPE := {
	C.ALWAYS: [],
	C.GRADE_AT_LEAST: ["grade"],
	C.GRADE_IS: ["grade"],
	C.REACTION_SUCCEEDED: ["reaction"],
	C.REACTION_ATTEMPTED: ["reaction"],
	C.REACTION_FAILED: ["reaction"],
	C.HAS_STATUS: ["on", "status"],
	C.EVENT_STATUS_IS: ["status"],
	C.ACTION_CATEGORY_IS: ["category"],
	C.ACTION_HAS_TAG: ["tag"],
	C.WEAPON_FAMILY_IS: ["on", "family"],
	C.DAMAGE_TYPE_IS: ["damage_type"],
	C.IS_WEAKNESS_HIT: [],
	C.HP_BELOW: ["on", "threshold"],
	C.HP_ABOVE: ["on", "threshold"],
	C.IS_BROKEN: ["on"],
	C.WEAK_POINT_EXPOSED: ["on"],
	C.IS_CHANNELING: ["on"],
	C.BATTLEFIELD_HAS: ["battlefield_condition"],
	C.FROM_CHAIN: [],
	C.HAS_BUFF: ["on", "buff"],
	C.ROUND_AT_LEAST: ["round_number"],
	C.IS_OWNER: ["on"],
	C.SIDE_IS: ["on", "side"],
}
const ALWAYS_VISIBLE := ["type", "negate"]

@export var type: Enums.ConditionType = Enums.ConditionType.ALWAYS:
	set(value):
		type = value
		notify_property_list_changed()
## Invert the result of the test.
@export var negate: bool = false
## Which unit a unit-based test inspects (trait owner, event actor or event target).
@export var on: Enums.ConditionOn = Enums.ConditionOn.TARGET
@export var grade: Enums.ExecutionGrade = Enums.ExecutionGrade.PERFECT
@export var reaction: Enums.ReactionType = Enums.ReactionType.PARRY
@export var status: Enums.StatusId = Enums.StatusId.NONE
@export var category: Enums.ActionCategory = Enums.ActionCategory.ATTACK
@export var tag: Enums.ActionTag = Enums.ActionTag.STRENUOUS
@export var family: Enums.WeaponFamily = Enums.WeaponFamily.NONE
@export var damage_type: Enums.DamageType = Enums.DamageType.NONE
## HP fraction for HP_BELOW / HP_ABOVE.
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5
@export var round_number: int = 1
@export var side: Enums.Side = Enums.Side.PLAYER
@export var battlefield_condition: BattlefieldConditionDefinition
@export var buff: BuffDefinition


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


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var fields: Array = FIELDS_BY_TYPE.get(type, [])
	if "status" in fields and status == Enums.StatusId.NONE:
		problems.append("condition %s needs a status" % Enums.ConditionType.keys()[type])
	if "battlefield_condition" in fields and battlefield_condition == null:
		problems.append("BATTLEFIELD_HAS needs a battlefield_condition")
	if "buff" in fields and buff == null:
		problems.append("HAS_BUFF needs a buff")
	return problems
