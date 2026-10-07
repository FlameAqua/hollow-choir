class_name RuleContext
extends RefCounted
## The facts about "what is happening" that conditions, modifiers and triggers inspect.
## Every event has an ACTOR role and/or a TARGET role (see Enums.TriggerType docs).

var trigger: Enums.TriggerType = Enums.TriggerType.ACTION_RESOLVED
var actor: BattleUnit
var target: BattleUnit
var action: ActionDefinition
var grade: Enums.ExecutionGrade = Enums.ExecutionGrade.GOOD
var reaction: Enums.ReactionType = Enums.ReactionType.NONE
var reaction_success: bool = false
var status: Enums.StatusId = Enums.StatusId.NONE
var damage_type: Enums.DamageType = Enums.DamageType.NONE
var amount: float = 0.0
var stagger_amount: float = 0.0
var overheal: float = 0.0
var is_weakness: bool = false
var from_chain: bool = false
var item: PotionDefinition
## Trigger recursion depth (chains are bounded by BalanceConfig.max_trigger_depth).
var depth: int = 0


static func make(p_trigger: Enums.TriggerType, p_actor: BattleUnit = null, p_target: BattleUnit = null,
		p_action: ActionDefinition = null) -> RuleContext:
	var rc := RuleContext.new()
	rc.trigger = p_trigger
	rc.actor = p_actor
	rc.target = p_target
	rc.action = p_action
	return rc


func duplicate_with(p_trigger: Enums.TriggerType) -> RuleContext:
	var rc := RuleContext.new()
	rc.trigger = p_trigger
	rc.actor = actor
	rc.target = target
	rc.action = action
	rc.grade = grade
	rc.reaction = reaction
	rc.reaction_success = reaction_success
	rc.status = status
	rc.damage_type = damage_type
	rc.amount = amount
	rc.stagger_amount = stagger_amount
	rc.overheal = overheal
	rc.is_weakness = is_weakness
	rc.from_chain = from_chain
	rc.item = item
	rc.depth = depth
	return rc
