class_name InterceptRules
extends RefCounted
## Cover mechanics: an interceptor takes single-target attacks aimed at the unit it protects,
## until the interceptor's next activation starts.


static func cover(ctx: BattleContext, interceptor: BattleUnit, protected_unit: BattleUnit) -> void:
	if interceptor == null or protected_unit == null or interceptor == protected_unit:
		return
	release(ctx, interceptor, false)
	interceptor.intercepting_for = protected_unit.uid
	protected_unit.intercepted_by = interceptor.uid
	ctx.emit(BattleEvent.new(BattleEvent.Type.COVER_STARTED, interceptor.uid, protected_unit.uid))


## Ends the interceptor's cover (at its next turn start, or when it falls).
static func release(ctx: BattleContext, interceptor: BattleUnit, announce: bool = true) -> void:
	if interceptor.intercepting_for < 0:
		return
	var protected_unit := ctx.unit(interceptor.intercepting_for)
	if protected_unit != null and protected_unit.intercepted_by == interceptor.uid:
		protected_unit.intercepted_by = -1
	if announce:
		ctx.emit(BattleEvent.new(BattleEvent.Type.COVER_ENDED, interceptor.uid, interceptor.intercepting_for))
	interceptor.intercepting_for = -1


static func clear_links(ctx: BattleContext, unit: BattleUnit) -> void:
	release(ctx, unit)
	if unit.intercepted_by >= 0:
		var cover_unit := ctx.unit(unit.intercepted_by)
		if cover_unit != null:
			cover_unit.intercepting_for = -1
		unit.intercepted_by = -1


## Redirects single-target attacks to living interceptors. Returns the final target list.
## Applies to either side: enemy intents (IntentRules) and party actions (BattleEngine).
static func redirect(ctx: BattleContext, action: ActionDefinition, targets: Array[BattleUnit]) -> Array[BattleUnit]:
	if action.target_rule != Enums.TargetRule.SINGLE_ENEMY:
		return targets
	var result: Array[BattleUnit] = []
	for target in targets:
		var final := final_target(ctx, action, target)
		if final != target:
			ctx.emit(BattleEvent.new(BattleEvent.Type.INTERCEPTED, final.uid, target.uid))
		if not result.has(final):
			result.append(final)
	return result


## The unit a single-target attack aimed at [param target] would actually hit. Pure: no events,
## no state change, so previews can call it at any time.
static func final_target(ctx: BattleContext, action: ActionDefinition, target: BattleUnit) -> BattleUnit:
	if target == null or action == null or action.target_rule != Enums.TargetRule.SINGLE_ENEMY \
			or target.intercepted_by < 0:
		return target
	var cover_unit := ctx.unit(target.intercepted_by)
	if cover_unit != null and cover_unit.is_alive() and not cover_unit.is_broken():
		return cover_unit
	return target
