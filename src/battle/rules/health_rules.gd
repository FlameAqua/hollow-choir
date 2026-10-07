class_name HealthRules
extends RefCounted
## Applies damage and healing, and handles defeat.


## Applies already-calculated damage. [param rc] describes the hit for DAMAGE_TAKEN triggers.
static func apply_damage(ctx: BattleContext, target: BattleUnit, amount: int, source: BattleUnit,
		damage_type: Enums.DamageType, action: ActionDefinition, flags: int = 0,
		rc: RuleContext = null) -> int:
	if target == null or not target.is_alive() or amount <= 0:
		return 0
	target.hp = maxi(0, target.hp - amount)
	target.damaged_since_turn = true
	var event := BattleEvent.new(BattleEvent.Type.DAMAGE, target.uid, ctx.uid_of(source))
	event.amount = amount
	event.damage_type = damage_type
	event.flags = flags
	event.action = action
	ctx.emit(event)
	if not target.is_alive():
		defeat(ctx, target, source, action, rc.depth if rc != null else 0)
		return amount
	var taken_rc := rc.duplicate_with(Enums.TriggerType.DAMAGE_TAKEN) if rc != null \
		else RuleContext.make(Enums.TriggerType.DAMAGE_TAKEN, source, target, action)
	taken_rc.actor = source
	taken_rc.target = target
	taken_rc.amount = amount
	taken_rc.damage_type = damage_type
	TriggerDispatcher.dispatch(ctx, taken_rc)
	if target.is_alive():
		PhaseRules.check(ctx, target)
	return amount


static func heal(ctx: BattleContext, target: BattleUnit, amount: float, healer: BattleUnit,
		depth: int = 0) -> int:
	if target == null or not target.is_alive():
		return 0
	var value := roundi(amount)
	if value <= 0:
		return 0
	var healed := mini(value, target.max_hp - target.hp)
	var overheal := value - healed
	target.hp += healed
	var event := BattleEvent.new(BattleEvent.Type.HEAL, target.uid, ctx.uid_of(healer))
	event.amount = healed
	event.amount2 = overheal
	ctx.emit(event)
	var rc := RuleContext.make(Enums.TriggerType.HEALED, healer, target)
	rc.amount = healed
	rc.overheal = overheal
	rc.depth = depth
	TriggerDispatcher.dispatch(ctx, rc)
	return healed


static func defeat(ctx: BattleContext, target: BattleUnit, killer: BattleUnit,
		action: ActionDefinition, depth: int = 0) -> void:
	target.hp = 0
	var event := BattleEvent.new(BattleEvent.Type.UNIT_DEFEATED, target.uid, ctx.uid_of(killer))
	event.action = action
	ctx.emit(event)
	for status in target.statuses:
		status.deactivate()
	target.statuses.clear()
	for buff in target.buffs:
		buff.deactivate()
	target.buffs.clear()
	target.intent = null
	target.broken_turns_left = 0
	InterceptRules.clear_links(ctx, target)
	var rc := RuleContext.make(Enums.TriggerType.UNIT_DEFEATED, killer, target, action)
	rc.depth = depth
	TriggerDispatcher.dispatch(ctx, rc)
	if target.is_enemy():
		ResearchRules.award(ctx, target, Enums.ResearchSource.DEFEAT)
