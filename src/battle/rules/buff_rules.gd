class_name BuffRules
extends RefCounted
## Temporary traits: stances, empowerments, marks. Re-granting refreshes instead of stacking.


static func grant(ctx: BattleContext, unit: BattleUnit, definition: BuffDefinition, source: BattleUnit) -> void:
	if unit == null or not unit.is_alive() or definition == null:
		return
	var existing := unit.get_buff(definition)
	if existing != null:
		existing.remaining = definition.duration
	else:
		var instance := BuffInstance.new()
		instance.definition = definition
		instance.remaining = definition.duration
		instance.source_uid = ctx.uid_of(source)
		if definition.trait_def != null:
			instance.trait_instance = TraitInstance.new(definition.trait_def, unit.uid, definition.display_name)
		unit.buffs.append(instance)
	var event := BattleEvent.new(BattleEvent.Type.BUFF_APPLIED, unit.uid, ctx.uid_of(source))
	event.text = definition.display_name
	if existing != null:
		event.flags |= BattleEvent.FLAG_REFRESHED
	ctx.emit(event)


static func remove(ctx: BattleContext, unit: BattleUnit, definition: BuffDefinition, reason: String = "") -> void:
	var instance := unit.get_buff(definition)
	if instance != null:
		_expire(ctx, unit, instance, reason)


## Counts down buffs whose expiry matches [param expiry].
static func tick(ctx: BattleContext, unit: BattleUnit, expiry: Enums.BuffExpiry) -> void:
	for instance: BuffInstance in unit.buffs.duplicate():
		if instance.definition.expiry != expiry:
			continue
		instance.remaining -= 1
		if instance.remaining <= 0:
			_expire(ctx, unit, instance, "expired")


static func on_round_end(ctx: BattleContext) -> void:
	for unit in ctx.state.living_units():
		tick(ctx, unit, Enums.BuffExpiry.ROUND_END)


## NEXT_ACTION buffs are spent by the owner's next action that passes their consume conditions.
static func consume_on_action(ctx: BattleContext, unit: BattleUnit, action: ActionDefinition,
		grade: Enums.ExecutionGrade) -> void:
	var rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, unit, null, action)
	rc.grade = grade
	for instance: BuffInstance in unit.buffs.duplicate():
		if instance.definition.expiry != Enums.BuffExpiry.NEXT_ACTION:
			continue
		if not ConditionEvaluator.all_pass(ctx, instance.definition.consume_conditions, rc, unit):
			continue
		instance.remaining -= 1
		if instance.remaining <= 0:
			_expire(ctx, unit, instance, "spent")


static func _expire(ctx: BattleContext, unit: BattleUnit, instance: BuffInstance, reason: String) -> void:
	instance.deactivate()
	unit.buffs.erase(instance)
	var event := BattleEvent.new(BattleEvent.Type.BUFF_EXPIRED, unit.uid)
	event.text = instance.definition.display_name
	event.text2 = reason
	ctx.emit(event)
