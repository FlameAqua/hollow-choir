class_name EnemyAI
extends RefCounted
## Utility-scored enemy decisions (GDD "Enemy intelligence").
##
##   score = base_priority
##         * product of considerations (need, target, synergy, environment…)
##           — each gated by its min_difficulty, so higher tiers *think* more, not hit harder
##         * Story-mode courtesy (avoid stacking lethal attacks on one target)
##         * (1 +/- difficulty noise)
##
## Considerations come from the action plus the defaults of every role the action expresses.
## The AI only uses visible state and expected values: it never reads future inputs or rolls.


static func decide(ctx: BattleContext, enemy: BattleUnit) -> void:
	if enemy.forced_next_action != null:
		var forced := enemy.forced_next_action
		enemy.forced_next_action = null
		var forced_targets := _default_targets(ctx, enemy, forced)
		_declare(ctx, enemy, forced, forced_targets, 0.0, PackedStringArray(["Phase opening move"]))
		return
	var best: AICandidate = null
	for candidate in evaluate(ctx, enemy):
		if best == null or candidate.score > best.score:
			best = candidate
	if best == null:
		enemy.intent = null
		return
	_declare(ctx, enemy, best.action, best.targets, best.score, best.reason_lines())


## All legal (action, targets) options with noisy scores, in deterministic order.
static func evaluate(ctx: BattleContext, enemy: BattleUnit, with_noise: bool = true) -> Array[AICandidate]:
	var result: Array[AICandidate] = []
	for action in enemy.enemy_actions:
		if action == null or not is_legal(ctx, enemy, action):
			continue
		for targets in _target_options(ctx, enemy, action):
			var candidate := score(ctx, enemy, action, targets)
			if with_noise:
				var variance := ctx.difficulty.score_variance
				if variance > 0.0:
					candidate.score *= 1.0 + ctx.rng.randf_range(-variance, variance)
			result.append(candidate)
	return result


static func is_legal(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> bool:
	if enemy.focus < action.focus_cost:
		return false
	if enemy.cooldown_left(action) > 0:
		return false
	if action.max_uses > 0 and enemy.uses_of(action) >= action.max_uses:
		return false
	var rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, enemy, null, action)
	if not ConditionEvaluator.all_pass(ctx, action.use_conditions, rc, enemy):
		return false
	if action.target_rule != Enums.TargetRule.NONE and ActionRules.valid_targets(ctx, enemy, action).is_empty():
		return false
	return true


## Best single target for [param action] (used for retargeting and forced moves). No noise.
static func choose_target(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> BattleUnit:
	var best: AICandidate = null
	for targets in _target_options(ctx, enemy, action):
		var candidate := score(ctx, enemy, action, targets)
		if best == null or candidate.score > best.score:
			best = candidate
	if best == null or best.targets.is_empty():
		return null
	return best.targets[0]


static func score(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition,
		targets: Array[BattleUnit]) -> AICandidate:
	var candidate := AICandidate.new()
	candidate.action = action
	candidate.targets = targets
	var value := action.base_priority
	var tier := int(ctx.difficulty.difficulty)
	var primary: BattleUnit = targets[0] if not targets.is_empty() else null
	for consideration in considerations_for(ctx, enemy, action):
		if int(consideration.min_difficulty) > tier:
			continue
		var holds := _holds(ctx, enemy, action, targets, primary, consideration)
		var multiplier := consideration.weight if holds else consideration.else_weight
		value *= multiplier
		if holds:
			candidate.add_factor(consideration.reason, multiplier)
	if tier >= int(Enums.TacticalDifficulty.ADVENTURER) and primary != null and action.deals_damage() \
			and action.needs_target_choice() and primary.side != enemy.side:
		var softness := _softness(ctx, enemy, action, primary)
		value *= pow(softness, 1.0 if tier >= int(Enums.TacticalDifficulty.TACTICIAN) else 0.5)
	if ctx.difficulty.avoid_lethal_combinations and primary != null and action.deals_damage() \
			and primary.side != enemy.side:
		var planned := planned_damage_on(ctx, primary, enemy)
		if planned > 0.0 and planned + expected_damage(ctx, enemy, action, primary) >= primary.hp:
			value *= ctx.difficulty.lethal_combination_weight
			candidate.add_factor("Holding back (Story)", ctx.difficulty.lethal_combination_weight)
	candidate.score = maxf(0.0, value)
	return candidate


## Action considerations + default considerations of each role the action expresses.
static func considerations_for(ctx: BattleContext, enemy: BattleUnit,
		action: EnemyActionDefinition) -> Array[AIConsiderationDefinition]:
	var result: Array[AIConsiderationDefinition] = []
	for consideration in action.considerations:
		if consideration != null:
			result.append(consideration)
	var roles: Array[Enums.EnemyRole] = action.role_tags.duplicate()
	if roles.is_empty():
		roles.append(enemy.enemy_def().role)
	for role in roles:
		var role_def := ctx.library.role_def(role)
		if role_def == null:
			continue
		for consideration in role_def.default_considerations:
			if consideration != null and consideration.applies_to_category(action.intent_category):
				result.append(consideration)
	return result


static func _holds(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition,
		targets: Array[BattleUnit], primary: BattleUnit, consideration: AIConsiderationDefinition) -> bool:
	var K := Enums.ConsiderationType
	match consideration.type:
		K.SELF_HP_BELOW:
			return enemy.hp_fraction() < consideration.threshold
		K.TARGET_HP_BELOW:
			return primary != null and primary.hp_fraction() < consideration.threshold
		K.ANY_ALLY_HP_BELOW:
			for ally in ctx.allies_of(enemy, false):
				if ally.hp_fraction() < consideration.threshold:
					return true
			return false
		K.TARGET_HAS_STATUS:
			return primary != null and primary.has_status(consideration.status)
		K.TARGET_LACKS_STATUS:
			for target in targets:
				if not target.has_status(consideration.status):
					return true
			return false
		K.SELF_HAS_STATUS:
			return enemy.has_status(consideration.status)
		K.TARGET_IS_GUARDING:
			return primary != null and primary.is_guarding()
		K.TARGET_HIGH_FOCUS:
			return primary != null and primary.focus >= consideration.threshold
		K.BATTLEFIELD_HAS:
			return ctx.state.has_condition(consideration.battlefield_condition)
		K.ALLY_ROLE_PRESENT:
			for ally in ctx.allies_of(enemy, false):
				if ally.is_enemy() and ally.enemy_def().role == consideration.role:
					return true
			return false
		K.TARGET_ROLE_IS:
			return primary != null and primary.is_enemy() and primary.enemy_def().role == consideration.role
		K.ALLY_SYNERGY_FOLLOWUP:
			return _ally_can_follow_up(ctx, enemy, action)
		K.TARGET_ALREADY_TARGETED:
			return primary != null and planned_damage_on(ctx, primary, enemy) > 0.0
		K.CAN_KILL_TARGET:
			return primary != null and primary.side != enemy.side \
				and expected_damage(ctx, enemy, action, primary) >= primary.hp
		K.CHANNEL_AT_RISK:
			return action.channel_turns > 0 and party_can_break(ctx, enemy, action)
		K.PARTY_THREAT_HIGH:
			for member in ctx.state.party():
				if member.focus >= consideration.threshold:
					return true
			return false
		K.TARGET_IS_CHANNELING:
			return primary != null and primary.is_channeling()
		K.RECENTLY_USED:
			return enemy.last_action_id == action.id
		K.ROUND_AT_LEAST:
			return ctx.state.round >= roundi(consideration.threshold)
		K.TARGET_WAS_DAMAGED:
			return primary != null and primary.damaged_since_turn
		K.SELF_IS_PROTECTED:
			return enemy.intercepted_by >= 0
		K.PARTY_COUNTERS_THIS:
			var seen := ctx.state.party_reaction_successes
			for reaction in [Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
				if action.allows_reaction(reaction) and seen.get(reaction, 0) >= roundi(consideration.threshold):
					return true
			return false
	return false


## Expected damage on [param target] relative to the softest valid target (1.0 = softest).
## Adventurer+ enemies prefer targets that are unguarded, low-Guard or vulnerable to the hit.
static func _softness(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition,
		target: BattleUnit) -> float:
	var best := 0.0
	for candidate in ActionRules.valid_targets(ctx, enemy, action):
		best = maxf(best, expected_damage(ctx, enemy, action, candidate))
	if best <= 0.0:
		return 1.0
	return clampf(expected_damage(ctx, enemy, action, target) / best, 0.05, 1.0)


## Expected (mean, unreacted, GOOD) damage — never peeks at RNG rolls.
static func expected_damage(ctx: BattleContext, enemy: BattleUnit, action: ActionDefinition,
		target: BattleUnit) -> float:
	if not action.deals_damage():
		return 0.0
	return DamageCalculator.calculate_hit(ctx, enemy, target, action, Enums.ExecutionGrade.GOOD).expected


## Damage other enemies already declared against [param target] this round.
static func planned_damage_on(ctx: BattleContext, target: BattleUnit, exclude: BattleUnit) -> float:
	var total := 0.0
	for ally in ctx.state.enemies():
		if ally == exclude or ally.intent == null or ally.intent.declared_round != ctx.state.round:
			continue
		var intent := ally.intent
		if intent.is_channel() and intent.turns_until_release() > 0:
			continue
		if intent.action.is_area() or intent.target_uids.has(target.uid):
			total += expected_damage(ctx, ally, intent.action, target)
	return total


## Combo setup: does an ally acting after me this round have a legal payoff for my setup?
static func _ally_can_follow_up(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> bool:
	if action.synergy_setup.is_empty():
		return false
	var order := ctx.state.turn_order
	var my_position := order.find(enemy.uid)
	for ally in ctx.allies_of(enemy, false):
		if not ally.is_enemy() or ally.is_broken():
			continue
		if my_position == -1 or order.find(ally.uid) <= my_position:
			continue
		for ally_action in ally.enemy_actions:
			if ally_action == null or not is_legal(ctx, ally, ally_action):
				continue
			for tag in action.synergy_setup:
				if ally_action.synergy_payoff.has(tag):
					return true
	return false


## One-action lookahead: can the party probably break my Stagger before this channel releases?
## Uses each party unit's best legal Stagger at GOOD timing, once per activation it gets before
## release: one per channel turn, plus one if it acts before me this round.
static func party_can_break(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> bool:
	var channel_total := action.channel_turns + ctx.difficulty.channel_extra_turns
	var order := ctx.state.turn_order
	var enemy_position := order.find(enemy.uid)
	var total := 0.0
	for member in ctx.state.party():
		var member_position := order.find(member.uid)
		var activations := channel_total
		if member_position != -1 and enemy_position != -1 and member_position < enemy_position:
			activations += 1
		var best := 0.0
		for party_action in member.actions:
			if party_action == null or not party_action.deals_damage():
				continue
			if not ActionRules.illegal_reason(ctx, member, party_action).is_empty():
				continue
			var calc := DamageCalculator.calculate_hit(ctx, member, enemy, party_action, Enums.ExecutionGrade.GOOD)
			var stagger := calc.stagger
			if party_action.has_tag(Enums.ActionTag.INTERRUPT):
				stagger *= ctx.balance.interrupt_stagger_multiplier
			best = maxf(best, stagger)
		total += best * activations
	return total >= enemy.stagger


static func _target_options(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> Array[Array]:
	var options: Array[Array] = []
	match action.target_rule:
		Enums.TargetRule.NONE:
			options.append([] as Array[BattleUnit])
		Enums.TargetRule.SELF:
			options.append([enemy] as Array[BattleUnit])
		Enums.TargetRule.ALL_ENEMIES, Enums.TargetRule.ALL_ALLIES:
			options.append(ActionRules.valid_targets(ctx, enemy, action))
		_:
			for target in ActionRules.valid_targets(ctx, enemy, action):
				options.append([target] as Array[BattleUnit])
	return options


static func _default_targets(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition) -> Array[BattleUnit]:
	if action.needs_target_choice():
		var target := choose_target(ctx, enemy, action)
		var result: Array[BattleUnit] = []
		if target != null:
			result.append(target)
		return result
	return ActionRules.valid_targets(ctx, enemy, action)


static func _declare(ctx: BattleContext, enemy: BattleUnit, action: EnemyActionDefinition,
		targets: Array[BattleUnit], score_value: float, reasons: PackedStringArray) -> void:
	var intent := EnemyIntent.new()
	intent.action = action
	for target in targets:
		intent.target_uids.append(target.uid)
	intent.declared_round = ctx.state.round
	intent.channel_total = action.channel_turns
	if action.channel_turns > 0:
		intent.channel_total += ctx.difficulty.channel_extra_turns
	intent.score = score_value
	intent.reasons = reasons
	enemy.intent = intent
