class_name ActionResolver
extends RefCounted
## Resolves any action for either side, in a fixed order:
##   costs → for each target: reaction, hit (damage, Stagger, weakness), on-hit effects
##   → once-only effects → strenuous (Bleed) → execution-grade Focus → buff consumption
##   → ACTION_RESOLVED / ITEM_USED triggers.
## A missed command never cancels the action: it only scales it (GDD).


## [param reactions]: defender uid -> ReactionResult (enemy actions against the party).
static func resolve(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition,
		targets: Array[BattleUnit], grade: Enums.ExecutionGrade,
		reactions: Dictionary[int, ReactionResult] = {}, item_slot: int = -1) -> void:
	_pay_costs(ctx, actor, action, item_slot)
	var started := BattleEvent.new(BattleEvent.Type.ACTION_STARTED, actor.uid)
	for target in targets:
		started.uids.append(target.uid)
	started.action = action
	started.grade = grade
	ctx.emit(started)

	var enemy_action := action as EnemyActionDefinition
	if actor.is_enemy() and enemy_action != null and enemy_action.rare:
		ResearchRules.award(ctx, actor, Enums.ResearchSource.RARE_ABILITY)
	if action.category == Enums.ActionCategory.INSPECT:
		for target in targets:
			_inspect(ctx, actor, target)

	var primary: BattleUnit = targets[0] if not targets.is_empty() else null
	var base_rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, actor, primary, action)
	base_rc.grade = grade
	var grade_mult := DamageCalculator.grade_multiplier(ctx, actor, grade, base_rc)
	var weakness_rewarded := false
	var parry_rewarded := false

	for target in targets:
		if ctx.is_decided():
			break
		if not target.is_alive():
			continue
		var reaction: ReactionResult = reactions.get(target.uid)
		var reaction_mult := 1.0
		var blocked := false
		if reaction != null:
			var reaction_rc := RuleContext.make(Enums.TriggerType.REACTION, actor, target, action)
			reaction_mult = ReactionRules.damage_multiplier(ctx, target, reaction, reaction_rc)
			blocked = ReactionRules.blocks_effects(reaction)
			parry_rewarded = _process_reaction(ctx, actor, target, action, reaction, parry_rewarded)
		if ctx.is_decided():
			break
		if action.deals_damage() and target.is_alive():
			weakness_rewarded = _hit(ctx, actor, target, action, grade, reaction_mult, blocked, weakness_rewarded)
		if blocked or not target.is_alive() or ctx.is_decided():
			continue
		var target_rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, actor, target, action)
		target_rc.grade = grade
		for effect in action.effects:
			if effect != null and is_per_target(effect):
				EffectResolver.resolve(ctx, effect, actor, target_rc, grade_mult, 0, action.display_name)

	if not ctx.is_decided() and actor.is_alive():
		for effect in action.effects:
			if effect != null and not is_per_target(effect):
				EffectResolver.resolve(ctx, effect, actor, base_rc, grade_mult, 0, action.display_name)
	if ctx.is_decided():
		return
	if actor.is_alive() and action.has_tag(Enums.ActionTag.STRENUOUS):
		StatusRules.on_strenuous_action(ctx, actor)
	if actor.side == Enums.Side.PLAYER and actor.is_alive():
		_grade_focus(ctx, actor, action, grade)
	BuffRules.consume_on_action(ctx, actor, action, grade)
	TriggerDispatcher.dispatch(ctx, base_rc)
	if item_slot >= 0 and not ctx.is_decided():
		var potion := ctx.state.potion_slots[item_slot].potion
		var used := BattleEvent.new(BattleEvent.Type.ITEM_USED, actor.uid, ctx.uid_of(primary))
		used.text = potion.display_name
		used.amount = item_slot
		ctx.emit(used)
		var item_rc := RuleContext.make(Enums.TriggerType.ITEM_USED, actor, primary, action)
		item_rc.item = potion
		TriggerDispatcher.dispatch(ctx, item_rc)


## Effects aimed at the action's target(s) resolve once per target; the rest resolve once.
static func is_per_target(effect: EffectDefinition) -> bool:
	return effect.target in [Enums.EffectTarget.TARGET, Enums.EffectTarget.TARGET_ALLIES_OTHER]


static func _pay_costs(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition, item_slot: int) -> void:
	if action.focus_cost > 0:
		FocusRules.spend(ctx, actor, action.focus_cost, action.display_name)
	if action.cooldown > 0:
		# +1 because cooldowns count down at the end of every activation, including this one.
		actor.cooldowns[action.id] = action.cooldown + 1
	if actor.is_enemy():
		actor.action_uses[action.id] = actor.uses_of(action) + 1
		actor.last_action_id = action.id
	if item_slot >= 0 and item_slot < ctx.state.potion_slots.size():
		ctx.state.potion_slots[item_slot].charges -= 1


## Returns the updated "weakness already rewarded this action" flag.
static func _hit(ctx: BattleContext, actor: BattleUnit, target: BattleUnit, action: ActionDefinition,
		grade: Enums.ExecutionGrade, reaction_mult: float, blocked: bool, weakness_rewarded: bool) -> bool:
	var calc := DamageCalculator.calculate_hit(ctx, actor, target, action, grade, reaction_mult)
	var damage := calc.roll(ctx)
	var flags := 0
	if calc.is_weakness:
		flags |= BattleEvent.FLAG_WEAKNESS
	if calc.is_resisted:
		flags |= BattleEvent.FLAG_RESISTED
	if calc.hits_weak_point:
		flags |= BattleEvent.FLAG_WEAK_POINT
	if calc.broken_bonus:
		flags |= BattleEvent.FLAG_BROKEN_BONUS
	if (calc.is_weakness or calc.is_resisted) and not target.revealed_affinities.has(calc.damage_type):
		target.revealed_affinities.append(calc.damage_type)
	var rc := RuleContext.make(Enums.TriggerType.HIT_LANDED, actor, target, action)
	rc.grade = grade
	rc.damage_type = calc.damage_type
	rc.is_weakness = calc.is_weakness
	rc.amount = damage
	if damage > 0:
		HealthRules.apply_damage(ctx, target, damage, actor, calc.damage_type, action, flags, rc)
	if blocked or ctx.is_decided():
		return weakness_rewarded
	if calc.stagger > 0.0 and target.is_alive():
		rc.stagger_amount = StaggerRules.apply_stagger(ctx, target, calc.stagger, actor, true)
	if calc.is_weakness and not weakness_rewarded:
		weakness_rewarded = true
		FocusRules.gain(ctx, actor, ctx.balance.weakness_focus, "Weakness")
		ResearchRules.award(ctx, target, Enums.ResearchSource.WEAKNESS)
	TriggerDispatcher.dispatch(ctx, rc)
	return weakness_rewarded


## Returns the updated "parry already rewarded this action" flag (AoE: one parry reward).
static func _process_reaction(ctx: BattleContext, attacker: BattleUnit, defender: BattleUnit,
		action: ActionDefinition, reaction: ReactionResult, parry_rewarded: bool) -> bool:
	var event := BattleEvent.new(BattleEvent.Type.REACTION_RESULT, defender.uid, attacker.uid)
	event.reaction = reaction.type
	event.success = reaction.success
	event.action = action
	if reaction.automatic:
		event.flags |= BattleEvent.FLAG_AUTO
	ctx.emit(event)
	var rc := RuleContext.make(Enums.TriggerType.REACTION, attacker, defender, action)
	rc.reaction = reaction.type
	rc.reaction_success = reaction.success
	if reaction.type == Enums.ReactionType.PARRY and reaction.success and not parry_rewarded:
		parry_rewarded = true
		var stagger := ModifierQuery.apply(ctx, Enums.ModifierStat.PARRY_STAGGER, ctx.balance.parry_stagger, defender, rc)
		StaggerRules.apply_stagger(ctx, attacker, stagger, defender, false)
		FocusRules.gain(ctx, defender, ctx.balance.parry_focus, "Parry")
		var enemy_action := action as EnemyActionDefinition
		if enemy_action != null and enemy_action.signature:
			ResearchRules.award(ctx, attacker, Enums.ResearchSource.SIGNATURE_PARRY)
	TriggerDispatcher.dispatch(ctx, rc)
	return parry_rewarded


static func _inspect(ctx: BattleContext, actor: BattleUnit, target: BattleUnit) -> void:
	if not target.is_enemy():
		return
	target.inspected = true
	ctx.emit(BattleEvent.new(BattleEvent.Type.INSPECTED, target.uid, actor.uid))
	ResearchRules.award(ctx, target, Enums.ResearchSource.INSPECT)


static func _grade_focus(ctx: BattleContext, actor: BattleUnit, action: ActionDefinition,
		grade: Enums.ExecutionGrade) -> void:
	if action.command_type() == Enums.ActionCommandType.NONE:
		return
	var balance := ctx.balance
	var amount := 0
	if action.generates_focus:
		if grade == Enums.ExecutionGrade.PERFECT:
			amount = balance.focus_on_perfect
		elif grade == Enums.ExecutionGrade.GOOD:
			amount = balance.focus_on_good
	elif grade == Enums.ExecutionGrade.PERFECT:
		amount = balance.focus_on_perfect_other
	if amount > 0:
		FocusRules.gain(ctx, actor, amount, "%s timing" % EnumText.grade(grade))
