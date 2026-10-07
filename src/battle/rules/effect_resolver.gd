class_name EffectResolver
extends RefCounted
## Interprets EffectDefinitions. The single place where data-described effects become state
## changes (DECISION_LOG D-004). Adding a new EffectType means adding one branch here + a test.


## [param owner]: trait owner, or the acting unit for action effects (may be null for battlefield).
## [param grade_multiplier]: execution grade scaling for DAMAGE / HEAL / STAGGER inside actions.
static func resolve(ctx: BattleContext, effect: EffectDefinition, owner: BattleUnit, rc: RuleContext,
		grade_multiplier: float = 1.0, depth: int = -1, label: String = "") -> void:
	if ctx.is_decided():
		return
	var child_depth := depth if depth >= 0 else rc.depth
	if not ConditionEvaluator.all_pass(ctx, effect.conditions, rc, owner):
		return
	if not ctx.roll_chance(effect.chance):
		return
	var E := Enums.EffectType
	match effect.type:
		E.ADD_CONDITION:
			BattlefieldRules.add(ctx, effect.battlefield_condition)
			return
		E.REMOVE_CONDITION:
			BattlefieldRules.remove(ctx, effect.battlefield_condition)
			return
	for recipient in recipients_for(ctx, effect.target, owner, rc):
		if recipient == null or not recipient.is_alive():
			continue
		var amount := scaled_amount(ctx, effect, owner, recipient, rc)
		if effect.is_grade_scaled():
			amount *= grade_multiplier
		match effect.type:
			E.DAMAGE:
				var calc := DamageCalculator.calculate_effect_damage(ctx, owner, recipient, amount, effect.damage_type)
				var damage_rc := RuleContext.make(Enums.TriggerType.DAMAGE_TAKEN, owner, recipient, rc.action)
				damage_rc.damage_type = effect.damage_type
				damage_rc.depth = child_depth
				var flags := BattleEvent.FLAG_EFFECT
				if calc.is_weakness:
					flags |= BattleEvent.FLAG_WEAKNESS
				HealthRules.apply_damage(ctx, recipient, calc.minimum, owner, effect.damage_type, rc.action, flags, damage_rc)
			E.HEAL:
				HealthRules.heal(ctx, recipient, DamageCalculator.calculate_heal(ctx, owner, recipient, amount), owner, child_depth)
			E.GAIN_FOCUS:
				FocusRules.gain(ctx, recipient, roundi(amount), _source_label(label, owner, rc))
			E.LOSE_FOCUS:
				FocusRules.lose(ctx, recipient, roundi(amount), _source_label(label, owner, rc))
			E.STAGGER_DAMAGE:
				StaggerRules.apply_stagger(ctx, recipient, amount, owner, false, child_depth)
			E.APPLY_STATUS:
				var stacks := maxi(1, roundi(amount))
				if owner != null:
					var status_rc := RuleContext.make(Enums.TriggerType.STATUS_APPLIED, owner, recipient)
					status_rc.status = effect.status
					stacks = maxi(1, roundi(ModifierQuery.apply(ctx, Enums.ModifierStat.STATUS_STACKS_DEALT, stacks, owner, status_rc, false)))
				StatusRules.apply_status(ctx, recipient, effect.status, stacks, effect.duration, owner, false, child_depth)
			E.REMOVE_STATUS:
				StatusRules.remove_status(ctx, recipient, effect.status, "removed", child_depth)
			E.EXTEND_STATUS:
				StatusRules.extend_status(ctx, recipient, effect.status, maxi(1, roundi(amount)))
			E.GRANT_BUFF:
				BuffRules.grant(ctx, recipient, effect.buff, owner)
			E.REMOVE_BUFF:
				BuffRules.remove(ctx, recipient, effect.buff, "removed")
			E.EXPOSE_WEAK_POINT:
				StaggerRules.expose_weak_point(ctx, recipient, maxi(1, effect.duration), owner, child_depth)
			E.DELAY_TURN:
				TurnOrder.delay(ctx, recipient)
			E.INTERCEPT:
				InterceptRules.cover(ctx, owner, recipient)
			E.CHAIN_STATUS:
				if recipient.has_status(effect.filter_status):
					StatusRules.apply_status(ctx, recipient, effect.status, maxi(1, roundi(amount)), effect.duration, owner, true, child_depth)
			E.CLEANSE:
				StatusRules.cleanse(ctx, recipient)
			E.RESTORE_STAGGER:
				StaggerRules.restore(ctx, recipient, amount)
			_:
				push_warning("EffectResolver: unhandled effect type %d" % effect.type)


static func recipients_for(ctx: BattleContext, kind: Enums.EffectTarget, owner: BattleUnit,
		rc: RuleContext) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	match kind:
		Enums.EffectTarget.OWNER:
			if owner != null:
				result.append(owner)
		Enums.EffectTarget.ACTOR:
			if rc.actor != null:
				result.append(rc.actor)
		Enums.EffectTarget.TARGET:
			if rc.target != null:
				result.append(rc.target)
		Enums.EffectTarget.OWNER_ALLIES:
			if owner != null:
				result = ctx.allies_of(owner, true)
		Enums.EffectTarget.OWNER_ALLIES_OTHER:
			if owner != null:
				result = ctx.allies_of(owner, false)
		Enums.EffectTarget.OWNER_ENEMIES:
			if owner != null:
				result = ctx.opponents_of(owner)
		Enums.EffectTarget.TARGET_ALLIES_OTHER:
			if rc.target != null:
				result = ctx.allies_of(rc.target, false)
		Enums.EffectTarget.ALL:
			result = ctx.state.living_units()
	return result


static func scaled_amount(ctx: BattleContext, effect: EffectDefinition, owner: BattleUnit,
		recipient: BattleUnit, rc: RuleContext) -> float:
	match effect.scaling:
		Enums.AmountScaling.EVENT_AMOUNT:
			return effect.amount * rc.amount
		Enums.AmountScaling.EVENT_STAGGER:
			return effect.amount * rc.stagger_amount
		Enums.AmountScaling.EVENT_OVERHEAL:
			return effect.amount * rc.overheal
		Enums.AmountScaling.RECIPIENT_MAX_HP:
			return effect.amount * recipient.max_hp
		Enums.AmountScaling.OWNER_FORCE:
			return effect.amount * (Stats.force_multiplier(ctx, owner) if owner != null else 1.0)
		Enums.AmountScaling.RECIPIENT_STACKS:
			return effect.amount * recipient.status_stacks(effect.status)
	return effect.amount


static func _source_label(label: String, owner: BattleUnit, rc: RuleContext) -> String:
	if not label.is_empty():
		return label
	if rc.action != null:
		return rc.action.display_name
	return owner.display_name if owner != null else "Battlefield"
