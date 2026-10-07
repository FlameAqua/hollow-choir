class_name TriggerDispatcher
extends RefCounted
## Delivers a battle moment (RuleContext) to every active trait, in deterministic order:
## battlefield conditions first, then units by id (persistent traits, buffs, statuses).
## Recursion is bounded by BalanceConfig.max_trigger_depth so chains always terminate.


static func dispatch(ctx: BattleContext, rc: RuleContext) -> void:
	if ctx.is_decided():
		return
	if rc.depth > ctx.balance.max_trigger_depth:
		ctx.note("Trigger chain stopped at depth %d" % rc.depth)
		return
	for trait_instance in all_trait_instances(ctx):
		if not trait_instance.active or trait_instance.trait_def == null:
			continue
		var owner := ctx.unit(trait_instance.owner_uid)
		if trait_instance.owner_uid >= 0 and (owner == null or not owner.is_alive()):
			continue
		var triggers := trait_instance.trait_def.triggers
		for index in triggers.size():
			var trigger := triggers[index]
			if trigger == null or trigger.trigger != rc.trigger:
				continue
			if not relation_ok(trigger, rc, owner):
				continue
			if not trait_instance.can_fire(index, trigger):
				continue
			if not ConditionEvaluator.all_pass(ctx, trigger.conditions, rc, owner):
				continue
			if not ctx.roll_chance(trigger.chance):
				continue
			trait_instance.record_fire(index)
			if trigger.announce:
				var event := BattleEvent.new(BattleEvent.Type.TRIGGER_ACTIVATED, ctx.uid_of(owner))
				event.text = trait_instance.source_name
				ctx.emit(event)
			for effect in trigger.effects:
				if effect != null:
					EffectResolver.resolve(ctx, effect, owner, rc, 1.0, rc.depth + 1, trait_instance.source_name)
			if not trait_instance.active:
				break


static func relation_ok(trigger: TriggeredEffectDefinition, rc: RuleContext, owner: BattleUnit) -> bool:
	if trigger.relation == Enums.TriggerRelation.ANY or trigger.watch == Enums.TriggerWatch.NONE:
		return true
	if owner == null:
		return false
	var watched := rc.actor if trigger.watch == Enums.TriggerWatch.ACTOR else rc.target
	if watched == null:
		return false
	match trigger.relation:
		Enums.TriggerRelation.OWNER:
			return watched == owner
		Enums.TriggerRelation.OWNER_ALLY:
			return watched.side == owner.side
		Enums.TriggerRelation.OWNER_ALLY_OTHER:
			return watched.side == owner.side and watched != owner
		Enums.TriggerRelation.OWNER_ENEMY:
			return watched.side != owner.side
	return false


## Every trait instance in the battle, in dispatch order (also used to reset round counters).
static func all_trait_instances(ctx: BattleContext) -> Array[TraitInstance]:
	var result: Array[TraitInstance] = []
	for active in ctx.state.conditions:
		result.append_array(active.trait_instances)
	for unit in ctx.state.units:
		result.append_array(unit.traits)
		for buff in unit.buffs:
			if buff.trait_instance != null:
				result.append(buff.trait_instance)
		for status in unit.statuses:
			result.append_array(status.trait_instances)
	return result
