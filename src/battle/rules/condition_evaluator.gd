class_name ConditionEvaluator
extends RefCounted
## Evaluates ConditionDefinitions against a RuleContext. Pure: never mutates battle state.


static func all_pass(ctx: BattleContext, conditions: Array[ConditionDefinition], rc: RuleContext,
		owner: BattleUnit) -> bool:
	for condition in conditions:
		if condition != null and not evaluate(ctx, condition, rc, owner):
			return false
	return true


static func evaluate(ctx: BattleContext, condition: ConditionDefinition, rc: RuleContext,
		owner: BattleUnit) -> bool:
	return _evaluate_raw(ctx, condition, rc, owner) != condition.negate


static func _unit_for(condition: ConditionDefinition, rc: RuleContext, owner: BattleUnit) -> BattleUnit:
	match condition.on:
		Enums.ConditionOn.OWNER:
			return owner
		Enums.ConditionOn.ACTOR:
			return rc.actor
		Enums.ConditionOn.TARGET:
			return rc.target
	return null


static func _evaluate_raw(ctx: BattleContext, condition: ConditionDefinition, rc: RuleContext,
		owner: BattleUnit) -> bool:
	var C := Enums.ConditionType
	match condition.type:
		C.ALWAYS:
			return true
		C.GRADE_AT_LEAST:
			return int(rc.grade) >= int(condition.grade)
		C.GRADE_IS:
			return rc.grade == condition.grade
		C.REACTION_SUCCEEDED:
			return rc.reaction == condition.reaction and rc.reaction_success
		C.REACTION_ATTEMPTED:
			return rc.reaction == condition.reaction
		C.REACTION_FAILED:
			return rc.reaction == condition.reaction and not rc.reaction_success
		C.HAS_STATUS:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.has_status(condition.status)
		C.EVENT_STATUS_IS:
			return rc.status == condition.status
		C.ACTION_CATEGORY_IS:
			return rc.action != null and rc.action.category == condition.category
		C.ACTION_HAS_TAG:
			return rc.action != null and rc.action.has_tag(condition.tag)
		C.WEAPON_FAMILY_IS:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.weapon_family == condition.family
		C.DAMAGE_TYPE_IS:
			return rc.damage_type == condition.damage_type
		C.IS_WEAKNESS_HIT:
			return rc.is_weakness
		C.HP_BELOW:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.hp_fraction() < condition.threshold
		C.HP_ABOVE:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.hp_fraction() > condition.threshold
		C.IS_BROKEN:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.is_broken()
		C.WEAK_POINT_EXPOSED:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.is_weak_point_exposed()
		C.IS_CHANNELING:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.is_channeling()
		C.BATTLEFIELD_HAS:
			return ctx.state.has_condition(condition.battlefield_condition)
		C.FROM_CHAIN:
			return rc.from_chain
		C.HAS_BUFF:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.has_buff(condition.buff)
		C.ROUND_AT_LEAST:
			return ctx.state.round >= condition.round_number
		C.IS_OWNER:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit == owner
		C.SIDE_IS:
			var unit := _unit_for(condition, rc, owner)
			return unit != null and unit.side == condition.side
	push_warning("ConditionEvaluator: unhandled condition type %d" % condition.type)
	return false
