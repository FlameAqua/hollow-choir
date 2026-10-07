class_name PartyAutopilot
extends RefCounted
## Chooses party actions for simulations and the sandbox "autoplay" mode.
##
## SMART is a transparent heuristic (not an optimal solver): it values damage, kills, Stagger
## (more when a channel can be interrupted), healing when hurt, Focus, sensible statuses,
## guarding against heavy telegraphed hits and inspecting unknown enemies once.
## BASIC_ONLY and RANDOM exist to measure how much the extra options actually matter.

enum Policy { SMART = 0, BASIC_ONLY = 1, RANDOM = 2 }

const FOCUS_VALUE := 3.0
const STAGGER_VALUE := 0.35
const BREAK_BONUS := 14.0
const INTERRUPT_BONUS := 30.0
const KILL_BONUS := 12.0
const HEAL_VALUE := 1.1

var policy: Policy = Policy.SMART
var rng := RandomNumberGenerator.new()


func _init(p_policy: Policy = Policy.SMART, seed: int = 1) -> void:
	policy = p_policy
	rng.seed = seed


func choose(engine: BattleEngine, request: ActionSelectRequest) -> ActionChoice:
	var legal := request.legal_options()
	if legal.is_empty():
		return null
	match policy:
		Policy.BASIC_ONLY:
			return _basic(engine, request, legal)
		Policy.RANDOM:
			var option: ActionOption = legal[rng.randi_range(0, legal.size() - 1)]
			var target := -1
			if not option.target_uids.is_empty():
				target = option.target_uids[rng.randi_range(0, option.target_uids.size() - 1)]
			return ActionChoice.from_option(request.unit_uid, option, target)
	return _smart(engine, request, legal)


func _basic(engine: BattleEngine, request: ActionSelectRequest, legal: Array[ActionOption]) -> ActionChoice:
	var actor := engine.get_unit(request.unit_uid)
	var basic: ActionOption = null
	for option in legal:
		if option.action.category == Enums.ActionCategory.ATTACK and option.action.generates_focus:
			basic = option
			break
	if basic == null:
		basic = legal[0]
	return ActionChoice.from_option(actor.uid, basic, _weakest_target(engine, basic.target_uids))


func _smart(engine: BattleEngine, request: ActionSelectRequest, legal: Array[ActionOption]) -> ActionChoice:
	var actor := engine.get_unit(request.unit_uid)
	var incoming := _incoming_damage(engine, actor)
	var best: ActionChoice = null
	var best_value := -INF
	for option in legal:
		var targets: Array[int] = option.target_uids
		if not option.action.needs_target_choice():
			targets = [-1]
		for target_uid in targets:
			var choice := ActionChoice.from_option(actor.uid, option, target_uid)
			var value := _value(engine, actor, option, choice, incoming)
			if value > best_value:
				best_value = value
				best = choice
	return best


func _value(engine: BattleEngine, actor: BattleUnit, option: ActionOption, choice: ActionChoice,
		incoming: float) -> float:
	var action := option.action
	var value := 0.0
	var state := engine.get_state()
	match action.category:
		Enums.ActionCategory.GUARD:
			value += incoming * 0.45
		Enums.ActionCategory.INSPECT:
			var target := engine.get_unit(choice.target_uid)
			if target != null and not target.inspected and target.research_level < Enums.ResearchLevel.STUDIED \
					and state.round <= 1:
				value += 9.0
	var targets: Array[BattleUnit] = []
	if action.needs_target_choice():
		targets.append(engine.get_unit(choice.target_uid))
	else:
		targets = ActionRules.valid_targets(engine.ctx, actor, action)
	for target in targets:
		if target == null:
			continue
		var preview := PreviewRules.preview_action(engine.ctx, actor, action, target)
		value += _target_value(engine, actor, action, target, preview)
	var any_preview := PreviewRules.preview_action(engine.ctx, actor, action, targets[0] if not targets.is_empty() else null)
	value += any_preview.focus_gain[Enums.ExecutionGrade.GOOD] * FOCUS_VALUE
	value -= action.focus_cost * FOCUS_VALUE * 0.8
	if option.item_slot >= 0:
		value -= 4.0 # Potions are scarce: only worth it when clearly useful.
	return value


func _target_value(engine: BattleEngine, actor: BattleUnit, action: ActionDefinition, target: BattleUnit,
		preview: ActionPreview) -> float:
	var value := 0.0
	var good := Enums.ExecutionGrade.GOOD
	if preview.deals_damage and target.side != actor.side:
		var expected := (preview.damage_min[good] + preview.damage_max[good]) * 0.5
		value += minf(expected, target.hp)
		if preview.would_kill:
			value += KILL_BONUS
		if target.is_enemy() and not target.is_broken():
			value += preview.stagger[good] * STAGGER_VALUE
			if preview.would_break:
				value += BREAK_BONUS
				if target.is_channeling():
					value += INTERRUPT_BONUS
			elif target.is_channeling():
				value += preview.stagger[good] * STAGGER_VALUE * 2.0
	if preview.heal[good] > 0 and target.side == actor.side:
		var missing := target.max_hp - target.hp
		if target.hp_fraction() < 0.6:
			value += minf(preview.heal[good], missing) * HEAL_VALUE
		else:
			value -= 6.0
	for status in preview.statuses:
		value += _status_value(engine, actor, target, status)
	value += _effect_value(engine, actor, action, target)
	return value


## Values effects that a damage preview cannot see: weak-point exposure, debuffs, Intercept.
func _effect_value(engine: BattleEngine, actor: BattleUnit, action: ActionDefinition, target: BattleUnit) -> float:
	var value := 0.0
	for effect in action.effects:
		if effect == null or effect.target != Enums.EffectTarget.TARGET:
			continue
		match effect.type:
			Enums.EffectType.EXPOSE_WEAK_POINT:
				if target.is_enemy() and not target.is_weak_point_exposed():
					value += 14.0 if _party_has_precision(engine) else 6.0
			Enums.EffectType.GRANT_BUFF:
				if effect.buff != null and effect.buff.is_debuff and target.side != actor.side:
					value += 6.0
					if target.is_channeling() or target.stagger < target.max_stagger * 0.5:
						value += 10.0
			Enums.EffectType.INTERCEPT:
				if target.side == actor.side and target != actor:
					var threatened := _incoming_damage(engine, target)
					value += threatened * 0.6 - 4.0
	return value


func _party_has_precision(engine: BattleEngine) -> bool:
	for member in engine.get_state().party():
		for action in member.actions:
			if action.has_tag(Enums.ActionTag.PRECISION) and action.category == Enums.ActionCategory.TECHNIQUE:
				return true
	return false


func _status_value(engine: BattleEngine, actor: BattleUnit, target: BattleUnit, status: Enums.StatusId) -> float:
	if target.side == actor.side:
		return 0.0
	var already := target.has_status(status)
	match status:
		Enums.StatusId.BURN:
			return 0.0 if target.has_status(Enums.StatusId.WET) else (3.0 if already else 8.0)
		Enums.StatusId.WET:
			return 2.0 if already else 5.0
		Enums.StatusId.SHOCK:
			return 12.0 if target.has_status(Enums.StatusId.WET) else (2.0 if already else 6.0)
		Enums.StatusId.BLEED:
			return 3.0 if already else 7.0
	return 2.0


## Expected damage the actor faces from intents still to resolve (worst case, unreacted).
func _incoming_damage(engine: BattleEngine, actor: BattleUnit) -> float:
	var total := 0.0
	for enemy in engine.get_state().enemies():
		var preview := engine.preview_intent(enemy.uid)
		if preview == null or preview.turns_until_release > 1:
			continue
		if preview.unreacted.has(actor.uid):
			total += preview.unreacted[actor.uid].y
	return total


func _weakest_target(engine: BattleEngine, target_uids: Array[int]) -> int:
	var best := -1
	var best_hp := INF
	for uid in target_uids:
		var unit := engine.get_unit(uid)
		if unit != null and unit.hp < best_hp:
			best_hp = unit.hp
			best = uid
	return best
