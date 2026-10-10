class_name DamageCalculator
extends RefCounted
## Pure damage/stagger/heal math. Identical numbers feed previews, resolution and simulation.
##
## Hit damage =
##   (action power + weapon power * multiplier)
##   * (1 + Force/100) * grade multiplier
##   * weakness 1.3 / resistance 0.7 * weak point * broken 1.5
##   * DAMAGE_DEALT(attacker) * DAMAGE_TAKEN(defender)
##   * 100 / (100 + Guard)            (skipped for PURE)
##   * reaction multiplier            (Brace 0.6, Evade 0 / 1.15, Parry 0 / 1.3)
##   * variance roll (+/- 5%)


static func resolve_damage_type(attacker: BattleUnit, action: ActionDefinition) -> Enums.DamageType:
	if action.damage_type != Enums.DamageType.NONE:
		return action.damage_type
	if action.uses_weapon_power and attacker != null:
		return attacker.weapon_damage_type
	return Enums.DamageType.NONE


static func base_power(attacker: BattleUnit, action: ActionDefinition) -> float:
	var power := action.power
	if action.uses_weapon_power and attacker != null:
		power += attacker.weapon_power * action.weapon_power_multiplier
	return power


static func base_stagger(attacker: BattleUnit, action: ActionDefinition) -> float:
	var amount := action.stagger
	if action.uses_weapon_stagger and attacker != null:
		amount += attacker.weapon_stagger * action.weapon_stagger_multiplier
	return amount


static func grade_multiplier(ctx: BattleContext, unit: BattleUnit, grade: Enums.ExecutionGrade,
		rc: RuleContext = null) -> float:
	var base := ctx.balance.grade_multiplier(grade)
	if unit == null:
		return base
	match grade:
		Enums.ExecutionGrade.PERFECT:
			return ModifierQuery.apply(ctx, Enums.ModifierStat.PERFECT_MULTIPLIER, base, unit, rc)
		Enums.ExecutionGrade.MISS:
			return ModifierQuery.apply(ctx, Enums.ModifierStat.MISS_MULTIPLIER, base, unit, rc)
	return base


static func calculate_hit(ctx: BattleContext, attacker: BattleUnit, defender: BattleUnit,
		action: ActionDefinition, grade: Enums.ExecutionGrade, reaction_multiplier: float = 1.0,
		want_breakdown: bool = false) -> HitCalculation:
	var calc := HitCalculation.new()
	var balance := ctx.balance
	calc.damage_type = resolve_damage_type(attacker, action)
	var rc := RuleContext.make(Enums.TriggerType.HIT_LANDED, attacker, defender, action)
	rc.grade = grade
	rc.damage_type = calc.damage_type

	var raw := base_power(attacker, action)
	_line(calc, want_breakdown, "Base power: %.1f" % raw)

	var force_mult := Stats.force_multiplier(ctx, attacker)
	raw *= force_mult
	_line(calc, want_breakdown, "Force %d: x%.2f" % [roundi(Stats.force(ctx, attacker)), force_mult])

	var grade_mult := grade_multiplier(ctx, attacker, grade, rc)
	raw *= grade_mult
	_line(calc, want_breakdown, "%s timing: x%.2f" % [EnumText.grade(grade), grade_mult])

	if defender.is_enemy() and calc.damage_type != Enums.DamageType.PURE:
		var enemy := defender.enemy_def()
		if enemy.is_weak_to(calc.damage_type):
			calc.is_weakness = true
			raw *= balance.weakness_multiplier
			_line(calc, want_breakdown, "Weak to %s: x%.2f" % [EnumText.damage_type(calc.damage_type), balance.weakness_multiplier])
		elif enemy.resists(calc.damage_type):
			calc.is_resisted = true
			raw *= balance.resistance_multiplier
			_line(calc, want_breakdown, "Resists %s: x%.2f" % [EnumText.damage_type(calc.damage_type), balance.resistance_multiplier])
	rc.is_weakness = calc.is_weakness

	if defender.is_weak_point_exposed():
		calc.hits_weak_point = true
		var weak_point := balance.weak_point_damage_multiplier
		if action.has_tag(Enums.ActionTag.PRECISION):
			weak_point *= balance.weak_point_precision_multiplier
		weak_point = ModifierQuery.apply(ctx, Enums.ModifierStat.WEAK_POINT_MULTIPLIER, weak_point, attacker, rc)
		raw *= weak_point
		_line(calc, want_breakdown, "Weak point exposed: x%.2f" % weak_point)

	# Broken vulnerability is an enemy consequence; a Broken party member takes normal damage.
	if defender.is_broken() and StaggerRules.vulnerable_when_broken(defender):
		calc.broken_bonus = true
		raw *= balance.broken_damage_taken_multiplier
		_line(calc, want_breakdown, "Target Broken: x%.2f" % balance.broken_damage_taken_multiplier)

	var dealt := ModifierQuery.apply(ctx, Enums.ModifierStat.DAMAGE_DEALT, 1.0, attacker, rc)
	if not is_equal_approx(dealt, 1.0):
		raw *= dealt
		_line(calc, want_breakdown, "Your effects: x%.2f" % dealt)
	var taken := ModifierQuery.apply(ctx, Enums.ModifierStat.DAMAGE_TAKEN, 1.0, defender, rc)
	if not is_equal_approx(taken, 1.0):
		raw *= taken
		_line(calc, want_breakdown, "Target effects: x%.2f" % taken)

	if calc.damage_type != Enums.DamageType.PURE:
		var guard_mult := Stats.guard_multiplier(ctx, defender)
		raw *= guard_mult
		_line(calc, want_breakdown, "Guard %d: x%.2f" % [roundi(Stats.guard(ctx, defender)), guard_mult])

	if not is_equal_approx(reaction_multiplier, 1.0):
		raw *= reaction_multiplier
		_line(calc, want_breakdown, "Reaction: x%.2f" % reaction_multiplier)

	calc.negated = reaction_multiplier <= 0.0
	calc.expected = raw
	calc.minimum = _finalize(ctx, raw * (1.0 - balance.damage_variance), calc.negated)
	calc.maximum = _finalize(ctx, raw * (1.0 + balance.damage_variance), calc.negated)
	calc.stagger = calculate_stagger(ctx, attacker, defender, action, grade, calc, rc)
	if want_breakdown and calc.stagger > 0.0:
		_line(calc, true, "Stagger: %.1f" % calc.stagger)
	return calc


static func calculate_stagger(ctx: BattleContext, attacker: BattleUnit, defender: BattleUnit,
		action: ActionDefinition, grade: Enums.ExecutionGrade, calc: HitCalculation,
		rc: RuleContext) -> float:
	if not defender.is_enemy() or defender.is_broken():
		return 0.0
	var amount := base_stagger(attacker, action)
	if amount <= 0.0:
		return 0.0
	var balance := ctx.balance
	amount *= grade_multiplier(ctx, attacker, grade, rc)
	if calc.is_weakness:
		amount *= balance.weakness_stagger_multiplier
	if calc.hits_weak_point:
		amount *= balance.weak_point_stagger_multiplier
	if action.has_tag(Enums.ActionTag.INTERRUPT) and defender.is_channeling():
		amount *= balance.interrupt_stagger_multiplier
	amount = ModifierQuery.apply(ctx, Enums.ModifierStat.STAGGER_DEALT, amount, attacker, rc)
	amount = ModifierQuery.apply(ctx, Enums.ModifierStat.STAGGER_TAKEN, amount, defender, rc)
	return maxf(0.0, amount)


## Damage from an effect (statuses, triggers): affinities, Broken, DAMAGE_TAKEN and Guard apply;
## no Force, grade or variance, so effect damage is fully predictable.
static func calculate_effect_damage(ctx: BattleContext, source: BattleUnit, recipient: BattleUnit,
		amount: float, damage_type: Enums.DamageType) -> HitCalculation:
	var calc := HitCalculation.new()
	calc.damage_type = damage_type
	var rc := RuleContext.make(Enums.TriggerType.DAMAGE_TAKEN, source, recipient)
	rc.damage_type = damage_type
	var raw := amount
	if recipient.is_enemy() and damage_type != Enums.DamageType.PURE:
		var enemy := recipient.enemy_def()
		if enemy.is_weak_to(damage_type):
			calc.is_weakness = true
			raw *= ctx.balance.weakness_multiplier
		elif enemy.resists(damage_type):
			calc.is_resisted = true
			raw *= ctx.balance.resistance_multiplier
	if recipient.is_broken() and StaggerRules.vulnerable_when_broken(recipient):
		raw *= ctx.balance.broken_damage_taken_multiplier
	raw = ModifierQuery.apply(ctx, Enums.ModifierStat.DAMAGE_TAKEN, raw, recipient, rc)
	if damage_type != Enums.DamageType.PURE:
		raw *= Stats.guard_multiplier(ctx, recipient)
	calc.expected = raw
	calc.minimum = _finalize(ctx, raw, false)
	calc.maximum = calc.minimum
	return calc


static func calculate_heal(ctx: BattleContext, healer: BattleUnit, recipient: BattleUnit,
		amount: float) -> float:
	var rc := RuleContext.make(Enums.TriggerType.HEALED, healer, recipient)
	var value := amount
	if healer != null:
		value = ModifierQuery.apply(ctx, Enums.ModifierStat.HEALING_DEALT, value, healer, rc, false)
	value = ModifierQuery.apply(ctx, Enums.ModifierStat.HEALING_TAKEN, value, recipient, rc)
	return maxf(0.0, value)


static func _finalize(ctx: BattleContext, value: float, negated: bool) -> int:
	if negated:
		return 0
	return maxi(ctx.balance.minimum_damage, roundi(value))


static func _line(calc: HitCalculation, enabled: bool, text: String) -> void:
	if enabled:
		calc.breakdown.append(text)
