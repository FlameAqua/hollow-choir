class_name IntentRules
extends RefCounted
## Turns a declared intent into final targets at execution time. A dead target is replaced by
## the action's target rule (announced); the declared action itself never silently changes.


static func final_targets(ctx: BattleContext, enemy: BattleUnit) -> Array[BattleUnit]:
	var intent := enemy.intent
	var action := intent.action
	var targets: Array[BattleUnit] = []
	match action.target_rule:
		Enums.TargetRule.NONE:
			pass
		Enums.TargetRule.SELF:
			targets.append(enemy)
		Enums.TargetRule.ALL_ENEMIES, Enums.TargetRule.ALL_ALLIES:
			targets = ActionRules.valid_targets(ctx, enemy, action)
		_:
			var valid := ActionRules.valid_targets(ctx, enemy, action)
			for uid in intent.target_uids:
				var candidate := ctx.unit(uid)
				if candidate != null and valid.has(candidate):
					targets.append(candidate)
			if targets.is_empty():
				var replacement := EnemyAI.choose_target(ctx, enemy, action)
				if replacement != null:
					targets.append(replacement)
					intent.target_uids = [replacement.uid]
					intent.retargeted = true
					var event := BattleEvent.new(BattleEvent.Type.INTENT_CHANGED, enemy.uid)
					event.uids = intent.target_uids.duplicate()
					event.action = action
					event.text = "retargeted"
					ctx.emit(event)
	if action.targets_enemies():
		targets = InterceptRules.redirect(ctx, action, targets)
	return targets


## Does this declared action call for a real-time reaction from the party?
static func needs_reaction(action: EnemyActionDefinition, targets: Array[BattleUnit]) -> bool:
	if not action.is_reactable() or not action.targets_enemies():
		return false
	for target in targets:
		if target.side == Enums.Side.PLAYER:
			return true
	return false
