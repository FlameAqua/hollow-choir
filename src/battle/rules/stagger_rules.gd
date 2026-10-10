class_name StaggerRules
extends RefCounted
## The Break (Stagger) meter, Broken, recovery and weak-point exposure.
##
## Enemies: at 0 Stagger an enemy is Broken: an interruptible channel is cancelled, its next
## activation is lost, it takes extra damage until it recovers, its weak point (if any) is exposed,
## the breaker gains Focus and STAGGER_BREAK triggers fire. Its cap may grow on recovery.
##
## Party (playtest revision): each controlled party member has its own meter
## (BalanceConfig.party_max_break). It falls only through apply_party_break(), once per resolved
## enemy action and target: the hit's Break scaled by the reaction outcome, or the cost of a
## successful Parry. At 0 that member is Broken: it loses its next activation, cannot react
## meanwhile, then recovers with the same full meter. None of the enemy consequences above apply to
## it: no weak point, no growing cap, no Focus for the breaker, no extra damage, no STAGGER_BREAK
## trigger. Authored Stagger (hits, STAGGER_DAMAGE / RESTORE_STAGGER effects, Parry rewards, ambush)
## still reaches enemies only.


# --- Per-side policy -----------------------------------------------------------------------------

## Activations [param unit] loses when Broken.
static func break_turns(ctx: BattleContext, unit: BattleUnit) -> int:
	if unit.is_enemy():
		return maxi(1, unit.enemy_def().break_turns)
	return maxi(1, ctx.balance.party_break_turns)


## Does a Broken [param unit] take BalanceConfig.broken_damage_taken_multiplier? Enemies only.
static func vulnerable_when_broken(unit: BattleUnit) -> bool:
	return unit != null and unit.is_enemy()


# --- Enemy Stagger -------------------------------------------------------------------------------

## [param already_modified]: hits arrive fully modified from DamageCalculator; raw effect
## Stagger still needs the target's STAGGER_TAKEN modifiers (Shock, Condemn…). Enemies only.
static func apply_stagger(ctx: BattleContext, target: BattleUnit, amount: float, source: BattleUnit,
		already_modified: bool = true, depth: int = 0) -> float:
	if target == null or not target.is_enemy() or not target.is_alive() or target.is_broken():
		return 0.0
	var final := amount
	if not already_modified:
		var rc := RuleContext.make(Enums.TriggerType.HIT_LANDED, source, target)
		final = ModifierQuery.apply(ctx, Enums.ModifierStat.STAGGER_TAKEN, amount, target, rc)
	if final <= 0.0:
		return 0.0
	return _reduce(ctx, target, final, source, 0, depth)


# --- Party Break ---------------------------------------------------------------------------------

## Break one resolved enemy [param action] removes from one party target, given that target's
## [param reaction] (null = none). Pure: previews, the reaction spec and resolution share it.
## - A successful Parry: BalanceConfig.party_break_parry_cost, whatever the action.
## - Otherwise only a damaging action deals Break: its own party_break (or party_break_hit),
##   × the Brace or Evade multiplier on a success, × the failed multiplier on a failed attempt.
static func party_break_amount(balance: BalanceConfig, action: ActionDefinition, reaction: ReactionResult) -> float:
	var reacted := reaction != null and reaction.type != Enums.ReactionType.NONE
	if reacted and reaction.success and reaction.type == Enums.ReactionType.PARRY:
		return maxf(0.0, balance.party_break_parry_cost)
	if action == null or not action.deals_damage():
		return 0.0
	var amount := balance.party_break_hit
	var enemy_action := action as EnemyActionDefinition
	if enemy_action != null and enemy_action.party_break >= 0.0:
		amount = enemy_action.party_break
	if reacted:
		if not reaction.success:
			amount *= balance.party_break_failed_multiplier
		elif reaction.type == Enums.ReactionType.BRACE:
			amount *= balance.party_break_brace_multiplier
		elif reaction.type == Enums.ReactionType.EVADE:
			amount *= balance.party_break_evade_multiplier
	return maxf(0.0, amount)


## Applies one resolved enemy action's Break to party [param defender] (call once per defender,
## after its hit resolved). Nothing for an enemy, a unit without a meter, a defeated unit or one that
## is already Broken. A Parry's cost is flagged FLAG_REACTION_COST. Returns the Break removed.
static func apply_party_break(ctx: BattleContext, defender: BattleUnit, attacker: BattleUnit,
		action: ActionDefinition, reaction: ReactionResult) -> float:
	if defender == null or defender.is_enemy() or not defender.has_break_meter() or not defender.is_alive() \
			or defender.is_broken():
		return 0.0
	var amount := party_break_amount(ctx.balance, action, reaction)
	if amount <= 0.0:
		return 0.0
	var parried := reaction != null and reaction.success and reaction.type == Enums.ReactionType.PARRY
	return _reduce(ctx, defender, amount, attacker, BattleEvent.FLAG_REACTION_COST if parried else 0, 0)


# --- Meter, Broken and recovery (both sides) ------------------------------------------------------

static func _reduce(ctx: BattleContext, target: BattleUnit, amount: float, source: BattleUnit, flags: int,
		depth: int) -> float:
	target.stagger = maxf(0.0, target.stagger - amount)
	var event := BattleEvent.new(BattleEvent.Type.STAGGER_DAMAGE, target.uid, ctx.uid_of(source))
	event.amount = amount
	event.amount2 = target.stagger
	event.flags = flags
	ctx.emit(event)
	if target.stagger <= 0.0:
		break_unit(ctx, target, source, depth)
	return amount


static func break_unit(ctx: BattleContext, target: BattleUnit, breaker: BattleUnit, depth: int = 0) -> void:
	target.broken_turns_left = break_turns(ctx, target)
	target.break_count += 1
	if not target.is_enemy():
		# A party member: the lost activation is the whole consequence.
		ctx.emit(BattleEvent.new(BattleEvent.Type.BROKEN, target.uid, ctx.uid_of(breaker)))
		return
	var definition := target.enemy_def()
	var interrupted := false
	if target.intent != null:
		if target.intent.channeling and not target.intent.action.interruptible:
			pass # Uninterruptible channels survive the break; the lost activation just delays them.
		else:
			if target.intent.channeling:
				interrupted = true
				var cancel := BattleEvent.new(BattleEvent.Type.CHANNEL_INTERRUPTED, target.uid, ctx.uid_of(breaker))
				cancel.action = target.intent.action
				ctx.emit(cancel)
			target.intent = null
	var event := BattleEvent.new(BattleEvent.Type.BROKEN, target.uid, ctx.uid_of(breaker))
	if interrupted:
		event.flags |= BattleEvent.FLAG_INTERRUPTED
	ctx.emit(event)
	if breaker != null and breaker.side != target.side:
		var focus := ctx.balance.break_focus + (ctx.balance.interrupt_focus if interrupted else 0)
		FocusRules.gain(ctx, breaker, focus, "Interrupt" if interrupted else "Break")
	if definition.has_weak_point and definition.expose_weak_point_on_break:
		var was_exposed := target.is_weak_point_exposed()
		target.weak_point_from_break = true
		if not was_exposed:
			_emit_exposed(ctx, target, breaker, depth)
	var rc := RuleContext.make(Enums.TriggerType.STAGGER_BREAK, breaker, target)
	rc.depth = depth
	TriggerDispatcher.dispatch(ctx, rc)


## Called at the end of an activation the unit lost to being Broken.
static func on_skipped_turn_end(ctx: BattleContext, unit: BattleUnit) -> void:
	unit.broken_turns_left -= 1
	if unit.broken_turns_left <= 0:
		recover(ctx, unit)


static func recover(ctx: BattleContext, unit: BattleUnit) -> void:
	unit.broken_turns_left = 0
	# Only an enemy's cap grows (bosses resist stun-locks); a party member's stays as it was.
	if unit.is_enemy():
		unit.max_stagger *= maxf(1.0, unit.enemy_def().stagger_growth_on_break)
	unit.stagger = unit.max_stagger
	if unit.weak_point_from_break:
		unit.weak_point_from_break = false
		if not unit.is_weak_point_exposed():
			ctx.emit(BattleEvent.new(BattleEvent.Type.WEAK_POINT_CLOSED, unit.uid))
	ctx.emit(BattleEvent.new(BattleEvent.Type.RECOVERED, unit.uid))


## Opens a weak point for [param turns] of the target's activations.
static func expose_weak_point(ctx: BattleContext, target: BattleUnit, turns: int, cause: BattleUnit,
		depth: int = 0) -> void:
	if target == null or not target.is_enemy() or not target.is_alive():
		return
	var was_exposed := target.is_weak_point_exposed()
	target.weak_point_turns = maxi(target.weak_point_turns, maxi(1, turns))
	if not was_exposed:
		_emit_exposed(ctx, target, cause, depth)


static func on_turn_end(ctx: BattleContext, unit: BattleUnit) -> void:
	if unit.weak_point_turns <= 0:
		return
	unit.weak_point_turns -= 1
	if not unit.is_weak_point_exposed():
		ctx.emit(BattleEvent.new(BattleEvent.Type.WEAK_POINT_CLOSED, unit.uid))


static func restore(ctx: BattleContext, target: BattleUnit, amount: float) -> void:
	if target == null or not target.is_enemy() or target.is_broken() or amount <= 0.0:
		return
	var before := target.stagger
	target.stagger = minf(target.max_stagger, target.stagger + amount)
	if target.stagger > before:
		var event := BattleEvent.new(BattleEvent.Type.STAGGER_DAMAGE, target.uid)
		event.amount = before - target.stagger
		event.amount2 = target.stagger
		ctx.emit(event)


static func _emit_exposed(ctx: BattleContext, target: BattleUnit, cause: BattleUnit, depth: int) -> void:
	ctx.emit(BattleEvent.new(BattleEvent.Type.WEAK_POINT_EXPOSED, target.uid, ctx.uid_of(cause)))
	var rc := RuleContext.make(Enums.TriggerType.WEAKPOINT_EXPOSED, cause, target)
	rc.depth = depth
	TriggerDispatcher.dispatch(ctx, rc)
