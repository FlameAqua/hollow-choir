class_name StatusRules
extends RefCounted
## Applying, ticking, extending and removing the six statuses.
##
## Interactions come from StatusDefinition data: blocked_by (Burn on a Wet target is doused and
## the Wet consumed), removes_on_apply (Wet washes Burn away), status traits (Shock + Wet conduct).


static func apply_status(ctx: BattleContext, target: BattleUnit, status: Enums.StatusId,
		stacks: int, duration: int, source: BattleUnit, from_chain: bool = false,
		depth: int = 0) -> bool:
	if target == null or not target.is_alive() or status == Enums.StatusId.NONE:
		return false
	var definition := ctx.library.status_def(status)
	if definition == null:
		push_warning("StatusRules: no StatusDefinition for %s" % EnumText.status(status))
		return false
	if target.is_enemy() and target.enemy_def().status_immunities.has(status):
		_emit_blocked(ctx, target, status, "%s is immune" % target.display_name)
		return false
	for blocker in definition.blocked_by:
		if target.has_status(blocker):
			remove_status(ctx, target, blocker, "consumed", depth)
			_emit_blocked(ctx, target, status, "%s doused by %s" % [EnumText.status(status), EnumText.status(blocker)])
			return false
	for removed in definition.removes_on_apply:
		if target.has_status(removed):
			remove_status(ctx, target, removed, "%s washed away by %s" % [EnumText.status(removed), EnumText.status(status)], depth)

	var rc := RuleContext.make(Enums.TriggerType.STATUS_APPLIED, source, target)
	rc.status = status
	rc.from_chain = from_chain
	rc.depth = depth
	var final_duration := float(duration if duration > 0 else definition.default_duration)
	if source != null:
		final_duration = ModifierQuery.apply(ctx, Enums.ModifierStat.STATUS_DURATION_DEALT, final_duration, source, rc, false)
	final_duration = ModifierQuery.apply(ctx, Enums.ModifierStat.STATUS_DURATION_TAKEN, final_duration, target, rc, true)
	var turns := clampi(roundi(final_duration), 1, definition.max_duration)

	var instance := target.get_status(status)
	var refreshed := instance != null
	if refreshed:
		instance.stacks = mini(definition.max_stacks, instance.stacks + maxi(1, stacks))
		if definition.duration_mode == Enums.DurationMode.CHARGES:
			instance.remaining = mini(definition.max_duration, instance.remaining + turns)
			instance.turns_active = 0
		else:
			instance.remaining = maxi(instance.remaining, turns)
	else:
		instance = StatusInstance.new()
		instance.status = status
		instance.definition = definition
		instance.stacks = clampi(stacks, 1, definition.max_stacks)
		instance.remaining = turns
		instance.source_uid = ctx.uid_of(source)
		for trait_def in definition.traits:
			if trait_def != null:
				instance.trait_instances.append(TraitInstance.new(trait_def, target.uid, definition.display_name))
		target.statuses.append(instance)

	var event := BattleEvent.new(BattleEvent.Type.STATUS_APPLIED, target.uid, ctx.uid_of(source))
	event.status = status
	event.amount = instance.stacks
	event.amount2 = instance.remaining
	if from_chain:
		event.flags |= BattleEvent.FLAG_CHAIN
	if refreshed:
		event.flags |= BattleEvent.FLAG_REFRESHED
	ctx.emit(event)
	TriggerDispatcher.dispatch(ctx, rc)
	return true


static func remove_status(ctx: BattleContext, target: BattleUnit, status: Enums.StatusId,
		reason: String, depth: int = 0) -> bool:
	var instance := target.get_status(status)
	if instance == null:
		return false
	instance.deactivate()
	target.statuses.erase(instance)
	var event := BattleEvent.new(BattleEvent.Type.STATUS_REMOVED, target.uid)
	event.status = status
	event.text = reason
	ctx.emit(event)
	var rc := RuleContext.make(Enums.TriggerType.STATUS_REMOVED, null, target)
	rc.status = status
	rc.depth = depth
	TriggerDispatcher.dispatch(ctx, rc)
	return true


static func extend_status(ctx: BattleContext, target: BattleUnit, status: Enums.StatusId,
		amount: int) -> bool:
	var instance := target.get_status(status)
	if instance == null or amount <= 0:
		return false
	var before := instance.remaining
	instance.remaining = mini(instance.definition.max_duration, instance.remaining + amount)
	if instance.remaining == before:
		return false
	var event := BattleEvent.new(BattleEvent.Type.STATUS_EXTENDED, target.uid)
	event.status = status
	event.amount = instance.remaining - before
	event.amount2 = instance.remaining
	ctx.emit(event)
	return true


static func cleanse(ctx: BattleContext, target: BattleUnit, negative_only: bool = true) -> int:
	var removed := 0
	for instance: StatusInstance in target.statuses.duplicate():
		if negative_only and not instance.definition.is_negative:
			continue
		if remove_status(ctx, target, instance.status, "cleansed"):
			removed += 1
	return removed


## Damage-over-time for statuses that tick when the bearer's activation starts (Burn).
static func tick(ctx: BattleContext, unit: BattleUnit, timing: Enums.TickTiming) -> void:
	for instance: StatusInstance in unit.statuses.duplicate():
		if not unit.is_alive():
			return
		var definition := instance.definition
		if definition.tick_timing != timing or definition.tick_damage_per_stack <= 0.0:
			continue
		var damage := roundi(definition.tick_damage_per_stack * instance.stacks)
		_status_damage(ctx, unit, instance, damage)


## Bleed: hurts the bearer whenever it performs a STRENUOUS action, spending a charge.
static func on_strenuous_action(ctx: BattleContext, unit: BattleUnit) -> void:
	for instance: StatusInstance in unit.statuses.duplicate():
		if not unit.is_alive():
			return
		var definition := instance.definition
		if definition.strenuous_damage_per_stack <= 0.0:
			continue
		var damage := roundi(definition.strenuous_damage_per_stack * instance.stacks)
		_status_damage(ctx, unit, instance, damage)
		if definition.duration_mode == Enums.DurationMode.CHARGES and unit.is_alive():
			instance.remaining -= 1
			if instance.remaining <= 0:
				remove_status(ctx, unit, instance.status, "ran its course")


## Durations count down at the end of the bearer's activation.
static func on_turn_end(ctx: BattleContext, unit: BattleUnit) -> void:
	for instance: StatusInstance in unit.statuses.duplicate():
		instance.turns_active += 1
		var definition := instance.definition
		if definition.duration_mode == Enums.DurationMode.TURNS:
			instance.remaining -= 1
			if instance.remaining <= 0:
				remove_status(ctx, unit, instance.status, "expired")
		elif definition.expiry_turns > 0 and instance.turns_active >= definition.expiry_turns:
			remove_status(ctx, unit, instance.status, "expired")


static func _status_damage(ctx: BattleContext, unit: BattleUnit, instance: StatusInstance,
		damage: int) -> void:
	if damage <= 0:
		return
	var source := ctx.unit(instance.source_uid)
	var rc := RuleContext.make(Enums.TriggerType.DAMAGE_TAKEN, source, unit)
	rc.status = instance.status
	rc.damage_type = Enums.DamageType.PURE
	HealthRules.apply_damage(ctx, unit, damage, source, Enums.DamageType.PURE, null,
		BattleEvent.FLAG_STATUS_TICK, rc)


static func _emit_blocked(ctx: BattleContext, target: BattleUnit, status: Enums.StatusId,
		reason: String) -> void:
	var event := BattleEvent.new(BattleEvent.Type.STATUS_BLOCKED, target.uid)
	event.status = status
	event.text = reason
	ctx.emit(event)
