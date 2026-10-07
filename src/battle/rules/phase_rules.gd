class_name PhaseRules
extends RefCounted
## Elite/boss phases: entered once each, in order, when HP falls to the phase threshold.
## Already-declared intents are honoured (a phase never silently swaps a telegraphed attack).


static func check(ctx: BattleContext, unit: BattleUnit) -> void:
	if not unit.is_enemy() or not unit.is_alive():
		return
	var phases := unit.enemy_def().phases
	while unit.phase_index + 1 < phases.size():
		var next := phases[unit.phase_index + 1]
		if next == null or unit.hp_fraction() > next.hp_threshold:
			return
		unit.phase_index += 1
		_enter(ctx, unit, next)


static func _enter(ctx: BattleContext, unit: BattleUnit, phase: BossPhaseDefinition) -> void:
	if not phase.actions.is_empty():
		unit.enemy_actions.assign(phase.actions)
	var event := BattleEvent.new(BattleEvent.Type.PHASE_CHANGED, unit.uid)
	event.text = phase.display_name
	event.text2 = phase.announce_text
	ctx.emit(event)
	for condition in phase.remove_conditions:
		BattlefieldRules.remove(ctx, condition)
	for condition in phase.add_conditions:
		BattlefieldRules.add(ctx, condition)
	var rc := RuleContext.make(Enums.TriggerType.ACTION_RESOLVED, unit, unit)
	for effect in phase.on_enter_effects:
		if effect != null:
			EffectResolver.resolve(ctx, effect, unit, rc, 1.0, 0, phase.display_name)
	if phase.opening_action != null:
		unit.forced_next_action = phase.opening_action
