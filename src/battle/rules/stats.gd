class_name Stats
extends RefCounted
## Live stat values = base stat + modifiers from traits, buffs, statuses and the battlefield.


static func force(ctx: BattleContext, unit: BattleUnit) -> float:
	return maxf(0.0, ModifierQuery.apply(ctx, Enums.ModifierStat.FORCE, unit.base_force, unit))


static func guard(ctx: BattleContext, unit: BattleUnit) -> float:
	return maxf(0.0, ModifierQuery.apply(ctx, Enums.ModifierStat.GUARD, unit.base_guard, unit))


static func tempo(ctx: BattleContext, unit: BattleUnit) -> float:
	return ModifierQuery.apply(ctx, Enums.ModifierStat.TEMPO, unit.base_tempo, unit)


static func max_focus(ctx: BattleContext, unit: BattleUnit) -> int:
	return maxi(0, roundi(ModifierQuery.apply(ctx, Enums.ModifierStat.MAX_FOCUS, unit.max_focus, unit)))


## Damage multiplier from Force: raw = power * (1 + Force / 100).
static func force_multiplier(ctx: BattleContext, unit: BattleUnit) -> float:
	return 1.0 + force(ctx, unit) / 100.0


## Mitigation from Guard: final = raw * C / (C + Guard).
static func guard_multiplier(ctx: BattleContext, unit: BattleUnit) -> float:
	var constant := ctx.balance.guard_constant
	return constant / (constant + guard(ctx, unit))
