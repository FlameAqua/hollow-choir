class_name ReactionRules
extends RefCounted
## Defensive reactions: Brace (large window, safe), Evade (medium, moderate failure penalty),
## Parry (small, avoids damage + Stagger, higher failure penalty).


static func build_spec(ctx: BattleContext, attacker: BattleUnit, defenders: Array[BattleUnit],
		action: EnemyActionDefinition) -> ReactionSpec:
	var spec := ReactionSpec.new()
	for reaction in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		if action.allows_reaction(reaction):
			spec.allowed.append(reaction)
	var primary: BattleUnit = defenders[0] if not defenders.is_empty() else null
	var scale := action.reaction_window_scale * ctx.assist.window_scale
	var rc := RuleContext.make(Enums.TriggerType.REACTION, attacker, primary, action)
	var balance := ctx.balance
	spec.brace_window_ms = _window(ctx, Enums.ModifierStat.BRACE_WINDOW, balance.brace_window_ms, primary, rc) * scale
	spec.evade_window_ms = _window(ctx, Enums.ModifierStat.EVADE_WINDOW, balance.evade_window_ms, primary, rc) * scale
	spec.parry_window_ms = _window(ctx, Enums.ModifierStat.PARRY_WINDOW, balance.parry_window_ms, primary, rc) * scale
	spec.windup_ms = action.windup_ms * ctx.assist.time_scale
	spec.auto_brace = ctx.assist.auto_brace
	spec.pause_before = ctx.assist.pause_before_reaction
	spec.break_unreacted = StaggerRules.party_break_amount(balance, action, null)
	spec.break_brace = StaggerRules.party_break_amount(balance, action, ReactionResult.make(Enums.ReactionType.BRACE, true))
	spec.break_evade = StaggerRules.party_break_amount(balance, action, ReactionResult.make(Enums.ReactionType.EVADE, true))
	spec.break_parry_cost = StaggerRules.party_break_amount(balance, action, ReactionResult.make(Enums.ReactionType.PARRY, true))
	for defender in defenders:
		if defender != null and defender.has_break_meter() and not defender.is_broken():
			spec.break_remaining = defender.stagger if spec.break_remaining <= 0.0 else minf(spec.break_remaining, defender.stagger)
	return spec


static func _window(ctx: BattleContext, stat: Enums.ModifierStat, base: float, unit: BattleUnit,
		rc: RuleContext) -> float:
	if unit == null:
		return base
	return maxf(1.0, ModifierQuery.apply(ctx, stat, base, unit, rc))


## Success test for a press [param offset_ms] away from impact (negative = early).
static func is_success(spec: ReactionSpec, reaction: Enums.ReactionType, offset_ms: float) -> bool:
	if not spec.is_allowed(reaction):
		return false
	return absf(offset_ms) <= spec.window_for(reaction) * 0.5


## Applies the locked-choice and assist rules (DECISION_LOG D-008):
## a disallowed reaction counts as no reaction; no input + auto-Brace = a successful Brace.
static func normalize(result: ReactionResult, spec: ReactionSpec) -> ReactionResult:
	var normalized := ReactionResult.make(result.type, result.success)
	normalized.automatic = result.automatic
	if normalized.type != Enums.ReactionType.NONE and not spec.is_allowed(normalized.type):
		normalized = ReactionResult.none()
	if normalized.type == Enums.ReactionType.NONE and spec.auto_brace and spec.is_allowed(Enums.ReactionType.BRACE):
		normalized = ReactionResult.make(Enums.ReactionType.BRACE, true)
		normalized.automatic = true
	return normalized


static func damage_multiplier(ctx: BattleContext, defender: BattleUnit, result: ReactionResult,
		rc: RuleContext = null) -> float:
	var balance := ctx.balance
	match result.type:
		Enums.ReactionType.BRACE:
			if not result.success:
				return 1.0
			var reduction := 1.0 - balance.brace_damage_multiplier
			reduction = ModifierQuery.apply(ctx, Enums.ModifierStat.BRACE_REDUCTION, reduction, defender, rc)
			return clampf(1.0 - reduction, 0.0, 1.0)
		Enums.ReactionType.EVADE:
			return balance.evade_success_multiplier if result.success else balance.evade_fail_multiplier
		Enums.ReactionType.PARRY:
			return balance.parry_success_multiplier if result.success else balance.parry_fail_multiplier
	return 1.0


## Successful Evades and Parries also stop the attack's statuses and other on-hit effects.
static func blocks_effects(result: ReactionResult) -> bool:
	return result.success and result.type in [Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]
