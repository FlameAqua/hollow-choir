class_name StaggerRules
extends RefCounted
## Stagger meter, Break, recovery and weak-point exposure (enemies only).
##
## At 0 Stagger an enemy is Broken: an interruptible channel is cancelled, its next activation
## is lost, it takes extra damage until it recovers, and its weak point (if any) is exposed.


## [param already_modified]: hits arrive fully modified from DamageCalculator; raw effect
## Stagger still needs the target's STAGGER_TAKEN modifiers (Shock, Condemn…).
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
	target.stagger = maxf(0.0, target.stagger - final)
	var event := BattleEvent.new(BattleEvent.Type.STAGGER_DAMAGE, target.uid, ctx.uid_of(source))
	event.amount = final
	event.amount2 = target.stagger
	ctx.emit(event)
	if target.stagger <= 0.0:
		break_unit(ctx, target, source, depth)
	return final


static func break_unit(ctx: BattleContext, target: BattleUnit, breaker: BattleUnit, depth: int = 0) -> void:
	var definition := target.enemy_def()
	target.broken_turns_left = maxi(1, definition.break_turns)
	target.break_count += 1
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
	var definition := unit.enemy_def()
	unit.broken_turns_left = 0
	unit.max_stagger *= maxf(1.0, definition.stagger_growth_on_break)
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
