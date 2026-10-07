class_name FocusRules
extends RefCounted
## Focus gain/spend. Gains are scaled by FOCUS_GAIN modifiers and capped at max Focus.


static func gain(ctx: BattleContext, unit: BattleUnit, amount: int, reason: String) -> int:
	if unit == null or not unit.is_alive() or amount <= 0:
		return 0
	var scaled := roundi(ModifierQuery.apply(ctx, Enums.ModifierStat.FOCUS_GAIN, amount, unit))
	var cap := Stats.max_focus(ctx, unit)
	var new_total := clampi(unit.focus + scaled, 0, cap)
	var delta := new_total - unit.focus
	if delta <= 0:
		return 0
	unit.focus = new_total
	_emit(ctx, unit, delta, reason)
	return delta


static func spend(ctx: BattleContext, unit: BattleUnit, amount: int, reason: String = "Spent") -> void:
	if amount <= 0:
		return
	unit.focus = maxi(0, unit.focus - amount)
	_emit(ctx, unit, -amount, reason)


static func lose(ctx: BattleContext, unit: BattleUnit, amount: int, reason: String) -> int:
	if unit == null or amount <= 0 or unit.focus <= 0:
		return 0
	var lost := mini(amount, unit.focus)
	unit.focus -= lost
	_emit(ctx, unit, -lost, reason)
	return lost


static func _emit(ctx: BattleContext, unit: BattleUnit, delta: int, reason: String) -> void:
	var event := BattleEvent.new(BattleEvent.Type.FOCUS_CHANGED, unit.uid)
	event.amount = delta
	event.amount2 = unit.focus
	event.text = reason
	ctx.emit(event)
