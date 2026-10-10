class_name PreviewRules
extends RefCounted
## Builds previews from the same pure calculators used for resolution. Never touches the RNG
## and never mutates state, so previews can be requested at any time.

const GRADES: Array[Enums.ExecutionGrade] = [
	Enums.ExecutionGrade.MISS, Enums.ExecutionGrade.GOOD, Enums.ExecutionGrade.PERFECT]


static func preview_action(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition,
		target: BattleUnit) -> ActionPreview:
	var preview := ActionPreview.new()
	preview.action = action
	preview.actor_uid = actor.uid
	# Mirrors BattleEngine: attacks on a covered unit hit its interceptor.
	var final_target := InterceptRules.final_target(ctx, action, target) if action.deals_damage() else target
	if final_target != target:
		preview.redirected_from = ctx.uid_of(target)
		target = final_target
	preview.target_uid = ctx.uid_of(target)
	preview.focus_cost = action.focus_cost
	preview.statuses = action.applied_statuses()
	preview.deals_damage = action.deals_damage() and target != null
	preview.damage_type = DamageCalculator.resolve_damage_type(actor, action)
	if action.is_area():
		preview.area_targets = ActionRules.valid_targets(ctx, actor, action).size()
	for grade in GRADES:
		if preview.deals_damage:
			var calc := DamageCalculator.calculate_hit(ctx, actor, target, action, grade, 1.0,
				grade == Enums.ExecutionGrade.GOOD)
			preview.damage_min[grade] = calc.minimum
			preview.damage_max[grade] = calc.maximum
			preview.stagger[grade] = calc.stagger
			if grade == Enums.ExecutionGrade.GOOD:
				preview.is_weakness = calc.is_weakness
				preview.is_resisted = calc.is_resisted
				preview.hits_weak_point = calc.hits_weak_point
				preview.breakdown = calc.breakdown
		preview.heal[grade] = _heal_estimate(ctx, actor, action, target, grade)
		preview.focus_gain[grade] = _focus_estimate(ctx, actor, action, grade, preview.is_weakness)
	if target != null:
		preview.target_broken = target.is_broken()
		preview.affinity_known = affinity_known(ctx, target, preview.damage_type)
		if target.is_enemy() and not target.is_broken():
			preview.would_break = preview.stagger[Enums.ExecutionGrade.GOOD] >= target.stagger
		preview.would_kill = preview.deals_damage and preview.damage_min[Enums.ExecutionGrade.GOOD] >= target.hp
	return preview


static func affinity_known(ctx: BattleContext, target: BattleUnit, damage_type: Enums.DamageType) -> bool:
	if not target.is_enemy():
		return true
	if target.revealed_affinities.has(damage_type):
		return true
	return ResearchRules.affinities_known(ResearchRules.detail_level(ctx, target))


static func _heal_estimate(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition,
		target: BattleUnit, grade: Enums.ExecutionGrade) -> int:
	var total := 0.0
	var rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, actor, target, action)
	rc.grade = grade
	var grade_mult := DamageCalculator.grade_multiplier(ctx, actor, grade, rc)
	for effect in action.effects:
		if effect == null or effect.type != Enums.EffectType.HEAL:
			continue
		var recipient := target if effect.target == Enums.EffectTarget.TARGET else actor
		if recipient == null:
			continue
		var amount := EffectResolver.scaled_amount(ctx, effect, actor, recipient, rc) * grade_mult
		total += DamageCalculator.calculate_heal(ctx, actor, recipient, amount)
	return roundi(total)


static func _focus_estimate(ctx: BattleContext, _actor: BattleUnit, action: ActionDefinition,
		grade: Enums.ExecutionGrade, is_weakness: bool) -> int:
	var balance := ctx.balance
	var amount := 0
	if action.command_type() != Enums.ActionCommandType.NONE:
		if action.generates_focus:
			if grade == Enums.ExecutionGrade.PERFECT:
				amount += balance.focus_on_perfect
			elif grade == Enums.ExecutionGrade.GOOD:
				amount += balance.focus_on_good
		elif grade == Enums.ExecutionGrade.PERFECT:
			amount += balance.focus_on_perfect_other
	if is_weakness:
		amount += balance.weakness_focus
	for effect in action.effects:
		if effect != null and effect.type == Enums.EffectType.GAIN_FOCUS and effect.target == Enums.EffectTarget.OWNER \
				and effect.conditions.is_empty() and effect.scaling == Enums.AmountScaling.FLAT:
			amount += roundi(effect.amount)
	return amount


static func preview_intent(ctx: BattleContext, enemy: BattleUnit) -> IntentPreview:
	var intent := enemy.intent
	if intent == null or intent.action == null:
		return null
	var action := intent.action
	var preview := IntentPreview.new()
	preview.enemy_uid = enemy.uid
	preview.action = action
	preview.detail_level = ResearchRules.detail_level(ctx, enemy)
	preview.turns_until_release = intent.turns_until_release()
	preview.channeling = intent.channeling
	preview.statuses = action.applied_statuses()
	preview.reasons = intent.reasons
	for reaction in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		if action.allows_reaction(reaction):
			preview.allowed.append(reaction)
	var targets: Array[BattleUnit] = []
	if action.is_area():
		targets = ActionRules.valid_targets(ctx, enemy, action)
	else:
		for uid in intent.target_uids:
			var candidate := ctx.unit(uid)
			if candidate != null and candidate.is_alive():
				targets.append(candidate)
	for target in targets:
		var final_target := InterceptRules.final_target(ctx, action, target)
		if final_target != target:
			preview.covered_by = final_target.uid
		preview.target_uids.append(final_target.uid)
		if final_target.side != enemy.side and final_target.has_break_meter() and not final_target.is_broken():
			var unreacted_break := StaggerRules.party_break_amount(ctx.balance, action, null)
			if unreacted_break > 0.0:
				preview.break_unreacted[final_target.uid] = unreacted_break
				preview.break_braced[final_target.uid] = StaggerRules.party_break_amount(ctx.balance, action,
					ReactionResult.make(Enums.ReactionType.BRACE, true))
			if action.allows_reaction(Enums.ReactionType.PARRY):
				preview.break_parry_cost = StaggerRules.party_break_amount(ctx.balance, action,
					ReactionResult.make(Enums.ReactionType.PARRY, true))
		if not action.deals_damage() or final_target.side == enemy.side:
			continue
		preview.unreacted[final_target.uid] = _range(ctx, enemy, final_target, action, 1.0)
		var brace := ReactionResult.make(Enums.ReactionType.BRACE, true)
		preview.braced[final_target.uid] = _range(ctx, enemy, final_target, action,
			ReactionRules.damage_multiplier(ctx, final_target, brace))
		preview.evade_failed[final_target.uid] = _range(ctx, enemy, final_target, action, ctx.balance.evade_fail_multiplier)
		preview.parry_failed[final_target.uid] = _range(ctx, enemy, final_target, action, ctx.balance.parry_fail_multiplier)
		var fraction := float(preview.unreacted[final_target.uid].y) / float(maxi(1, final_target.max_hp))
		preview.threat = maxi(preview.threat, _threat_for(fraction)) as IntentPreview.Threat
	return preview


static func _range(ctx: BattleContext, attacker: BattleUnit, defender: BattleUnit,
		action: ActionDefinition, reaction_mult: float) -> Vector2i:
	var calc := DamageCalculator.calculate_hit(ctx, attacker, defender, action, Enums.ExecutionGrade.GOOD, reaction_mult)
	return Vector2i(calc.minimum, calc.maximum)


static func _threat_for(fraction: float) -> IntentPreview.Threat:
	if fraction <= 0.0:
		return IntentPreview.Threat.NONE
	if fraction < 0.12:
		return IntentPreview.Threat.LIGHT
	if fraction < 0.25:
		return IntentPreview.Threat.MODERATE
	if fraction < 0.45:
		return IntentPreview.Threat.HEAVY
	return IntentPreview.Threat.SEVERE
