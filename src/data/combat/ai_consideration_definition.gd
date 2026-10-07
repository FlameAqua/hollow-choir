@tool
class_name AIConsiderationDefinition
extends Resource
## One utility-AI factor. When the test holds, the action/target score is multiplied by
## [member weight]; otherwise by [member else_weight].
##
## [member min_difficulty] gates the factor: the same data makes Tactician enemies smarter
## instead of inflated (GDD "Harder AI should feel smarter, not merely inflated").

const K := Enums.ConsiderationType

const FIELDS_BY_TYPE := {
	K.SELF_HP_BELOW: ["threshold"],
	K.TARGET_HP_BELOW: ["threshold"],
	K.ANY_ALLY_HP_BELOW: ["threshold"],
	K.TARGET_HAS_STATUS: ["status"],
	K.TARGET_LACKS_STATUS: ["status"],
	K.SELF_HAS_STATUS: ["status"],
	K.TARGET_IS_GUARDING: [],
	K.TARGET_HIGH_FOCUS: ["threshold"],
	K.BATTLEFIELD_HAS: ["battlefield_condition"],
	K.ALLY_ROLE_PRESENT: ["role"],
	K.TARGET_ROLE_IS: ["role"],
	K.ALLY_SYNERGY_FOLLOWUP: [],
	K.TARGET_ALREADY_TARGETED: [],
	K.CAN_KILL_TARGET: [],
	K.CHANNEL_AT_RISK: [],
	K.PARTY_THREAT_HIGH: ["threshold"],
	K.TARGET_IS_CHANNELING: [],
	K.RECENTLY_USED: [],
	K.ROUND_AT_LEAST: ["threshold"],
	K.TARGET_WAS_DAMAGED: [],
	K.SELF_IS_PROTECTED: [],
	K.PARTY_COUNTERS_THIS: ["threshold"],
}

@export var type: Enums.ConsiderationType = Enums.ConsiderationType.TARGET_HP_BELOW:
	set(value):
		type = value
		notify_property_list_changed()
@export var min_difficulty: Enums.TacticalDifficulty = Enums.TacticalDifficulty.STORY
@export var weight: float = 1.5
@export var else_weight: float = 1.0
## HP fraction, Focus amount or round number depending on [member type].
@export var threshold: float = 0.5
@export var status: Enums.StatusId = Enums.StatusId.NONE
@export var role: Enums.EnemyRole = Enums.EnemyRole.MENDICANT
@export var battlefield_condition: BattlefieldConditionDefinition
## Role defaults only: restrict to these intent categories (empty = all actions).
@export var applies_to: Array[Enums.IntentCategory] = []
## Short explanation shown in the intent's "why" line, e.g. "Ally badly hurt".
@export var reason: String = ""


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	var optional := ["threshold", "status", "role", "battlefield_condition"]
	if prop_name in optional and not (prop_name in FIELDS_BY_TYPE.get(type, [])):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func applies_to_category(category: Enums.IntentCategory) -> bool:
	return applies_to.is_empty() or applies_to.has(category)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var fields: Array = FIELDS_BY_TYPE.get(type, [])
	if "status" in fields and status == Enums.StatusId.NONE:
		problems.append("consideration %s needs a status" % K.keys()[type])
	if "battlefield_condition" in fields and battlefield_condition == null:
		problems.append("consideration BATTLEFIELD_HAS needs a battlefield_condition")
	if weight < 0.0 or else_weight < 0.0:
		problems.append("consideration weights must be >= 0")
	return problems
