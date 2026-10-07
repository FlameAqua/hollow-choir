class_name ModifierQuery
extends RefCounted
## Collects ModifierDefinitions from a unit's traits, buffs and statuses (plus battlefield
## conditions) and folds them into a value: (base + sum(ADD)) * product(MULTIPLY).
## Pure: used identically by previews, live resolution and the simulator.


static func apply(ctx: BattleContext, stat: Enums.ModifierStat, base: float, unit: BattleUnit,
		rc: RuleContext = null, include_battlefield: bool = true) -> float:
	var added := 0.0
	var multiplied := 1.0
	var query_rc := rc if rc != null else RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, unit)
	for trait_instance in trait_instances_of(ctx, unit, include_battlefield):
		if not trait_instance.active or trait_instance.trait_def == null:
			continue
		var owner := ctx.unit(trait_instance.owner_uid)
		for modifier in trait_instance.trait_def.modifiers:
			if modifier == null or modifier.stat != stat:
				continue
			if not ConditionEvaluator.all_pass(ctx, modifier.conditions, query_rc, owner):
				continue
			if modifier.operation == Enums.ModifierOp.ADD:
				added += modifier.value
			else:
				multiplied *= modifier.value
	return (base + added) * multiplied


## Every trait instance whose modifiers apply to [param unit], in deterministic order.
static func trait_instances_of(ctx: BattleContext, unit: BattleUnit,
		include_battlefield: bool = true) -> Array[TraitInstance]:
	var result: Array[TraitInstance] = []
	if include_battlefield:
		for active in ctx.state.conditions:
			result.append_array(active.trait_instances)
	if unit != null:
		result.append_array(unit.traits)
		for buff in unit.buffs:
			if buff.trait_instance != null:
				result.append(buff.trait_instance)
		for status in unit.statuses:
			result.append_array(status.trait_instances)
	return result
