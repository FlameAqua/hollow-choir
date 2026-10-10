class_name BattleEngine
extends RefCounted
## Deterministic battle state machine (DECISION_LOG D-002).
##
## The engine runs synchronously until it needs input, then exposes exactly one BattleRequest:
##   PLAYER_SELECT   -> ActionSelectRequest  -> submit_action()
##   ACTION_COMMAND  -> CommandRequest       -> submit_command_result()
##   REACTION_WINDOW -> ReactionRequest      -> submit_reaction()
## Everything that happens is recorded as BattleEvents; presentation, metrics and logs consume
## them with drain_events(). Same setup + same inputs = same battle.
##
##   var engine := BattleEngine.new(setup)
##   while not engine.is_finished():
##       engine.advance()
##       var request := engine.get_request()
##       ...answer it...
##       for event in engine.drain_events(): ...

const MAX_STEPS_PER_ADVANCE := 20000

var ctx: BattleContext
var input_log: Array[Dictionary] = []
var _request: BattleRequest
var _choice: ActionChoice
var _grade: Enums.ExecutionGrade = Enums.ExecutionGrade.GOOD
var _reactions: Dictionary[int, ReactionResult] = {}
var _pending_target_uids: Array[int] = []
var _pending_enemy_action: EnemyActionDefinition
var _skipping: bool = false
var _weapon_uses: Dictionary[StringName, int] = {}
var _weapon_perfects: Dictionary[StringName, int] = {}
var _item_uses: Dictionary[StringName, int] = {}


func _init(setup: BattleSetup) -> void:
	for problem in setup.validate():
		push_error("BattleSetup: %s" % problem)
	ctx = BattleContext.new(setup)
	UnitFactory.populate(ctx)


# --- Queries -------------------------------------------------------------------------------------

func get_state() -> BattleState:
	return ctx.state


func get_phase() -> Enums.BattlePhase:
	return ctx.state.phase


func get_request() -> BattleRequest:
	return _request


func is_finished() -> bool:
	return ctx.state.is_finished()


func get_outcome() -> Enums.BattleOutcome:
	return ctx.state.outcome


func get_unit(uid: int) -> BattleUnit:
	return ctx.unit(uid)


## Returns and clears the events produced since the last call.
func drain_events() -> Array[BattleEvent]:
	var drained := ctx.events
	ctx.events = []
	return drained


func options_for(uid: int) -> Array[ActionOption]:
	var unit := ctx.unit(uid)
	if unit == null:
		return [] as Array[ActionOption]
	return ActionRules.options_for(ctx, unit)


func preview(choice: ActionChoice) -> ActionPreview:
	var actor := ctx.unit(choice.unit_uid)
	var target := ctx.unit(choice.target_uid)
	if target == null and not choice.action.needs_target_choice():
		var targets := ActionRules.valid_targets(ctx, actor, choice.action)
		target = targets[0] if not targets.is_empty() else null
	return PreviewRules.preview_action(ctx, actor, choice.action, target)


func preview_intent(enemy_uid: int) -> IntentPreview:
	var enemy := ctx.unit(enemy_uid)
	return PreviewRules.preview_intent(ctx, enemy) if enemy != null else null


func forecast_next_round() -> Array[int]:
	return TurnOrder.forecast_next_round(ctx)


func build_result() -> BattleResult:
	var result := BattleResult.new()
	result.outcome = ctx.state.outcome
	result.rounds = ctx.state.round
	result.seed = ctx.setup.seed
	for key: String in ctx.research_awarded.keys():
		var parts := key.split(":")
		var enemy_id := StringName(parts[0])
		var sources: PackedInt32Array = result.research.get(enemy_id, PackedInt32Array())
		sources.append(int(parts[1]))
		result.research[enemy_id] = sources
	result.weapon_uses = _weapon_uses.duplicate()
	result.weapon_perfects = _weapon_perfects.duplicate()
	result.item_uses = _item_uses.duplicate()
	for unit in ctx.state.units:
		if unit.is_enemy() and not unit.is_alive():
			result.defeated_enemies.append(unit.definition.id)
	result.input_log = input_log.duplicate(true)
	return result


# --- Driving -------------------------------------------------------------------------------------

## Runs the state machine until input is needed or the battle ends.
func advance() -> void:
	var steps := 0
	while _request == null and not is_finished():
		steps += 1
		if steps > MAX_STEPS_PER_ADVANCE:
			push_error("BattleEngine: runaway state machine at phase %s" % Enums.BattlePhase.keys()[ctx.state.phase])
			_end(Enums.BattleOutcome.TIMEOUT)
			return
		_step()


func submit_action(choice: ActionChoice) -> Error:
	if _request == null or _request.kind != BattleRequest.Kind.ACTION_SELECT:
		return ERR_UNAVAILABLE
	if choice == null or choice.unit_uid != _request.unit_uid:
		return ERR_INVALID_PARAMETER
	var reason := ActionRules.validate_choice(ctx, choice)
	if not reason.is_empty():
		push_warning("BattleEngine: rejected action (%s)" % reason)
		return ERR_INVALID_PARAMETER
	input_log.append({"kind": "action", "unit": choice.unit_uid, "action": String(choice.action.id),
		"target": choice.target_uid, "slot": choice.item_slot})
	_choice = choice
	var actor := ctx.unit(choice.unit_uid)
	if choice.action.command_type() != Enums.ActionCommandType.NONE:
		var request := CommandRequest.new()
		request.unit_uid = choice.unit_uid
		request.choice = choice
		request.spec = CommandRules.build_spec(ctx, actor, choice.action)
		_request = request
		ctx.state.phase = Enums.BattlePhase.ACTION_COMMAND
	else:
		_grade = Enums.ExecutionGrade.GOOD
		_request = null
		ctx.state.phase = Enums.BattlePhase.ACTION_RESOLVE
	return OK


func submit_command_result(grade: Enums.ExecutionGrade) -> Error:
	if _request == null or _request.kind != BattleRequest.Kind.ACTION_COMMAND:
		return ERR_UNAVAILABLE
	input_log.append({"kind": "command", "grade": int(grade)})
	_grade = CommandRules.apply_floor(ctx, grade)
	var event := BattleEvent.new(BattleEvent.Type.COMMAND_RESULT, _choice.unit_uid)
	event.grade = _grade
	event.action = _choice.action
	ctx.emit(event)
	_request = null
	ctx.state.phase = Enums.BattlePhase.ACTION_RESOLVE
	return OK


func submit_reaction(result: ReactionResult) -> Error:
	if _request == null or _request.kind != BattleRequest.Kind.REACTION:
		return ERR_UNAVAILABLE
	var request := _request as ReactionRequest
	var submitted := result if result != null else ReactionResult.none()
	input_log.append({"kind": "reaction", "type": int(submitted.type), "success": submitted.success})
	var normalized := ReactionRules.normalize(submitted, request.spec)
	_reactions.clear()
	for uid in request.target_uids:
		_reactions[uid] = normalized
	_request = null
	ctx.state.phase = Enums.BattlePhase.REACTION_RESOLVE
	return OK


# --- State machine -------------------------------------------------------------------------------

func _step() -> void:
	match ctx.state.phase:
		Enums.BattlePhase.BATTLE_START:
			_battle_start()
		Enums.BattlePhase.ROUND_START:
			_round_start()
		Enums.BattlePhase.ENEMY_DECIDE:
			_enemy_decide()
		Enums.BattlePhase.ENEMY_TELEGRAPH:
			_enemy_telegraph()
		Enums.BattlePhase.UNIT_START:
			_unit_start()
		Enums.BattlePhase.ACTION_RESOLVE:
			_action_resolve()
		Enums.BattlePhase.REACTION_RESOLVE:
			_reaction_resolve()
		Enums.BattlePhase.UNIT_END:
			_unit_end()
		Enums.BattlePhase.ROUND_END:
			_round_end()
		_:
			push_error("BattleEngine: waiting for input at %s but no request is pending" % Enums.BattlePhase.keys()[ctx.state.phase])
			_end(Enums.BattleOutcome.TIMEOUT)


func _battle_start() -> void:
	ctx.emit(BattleEvent.new(BattleEvent.Type.BATTLE_STARTED))
	UnitFactory.add_conditions(ctx)
	for enemy in ctx.state.enemies():
		ResearchRules.award(ctx, enemy, Enums.ResearchSource.ENCOUNTER)
	if ctx.state.advantage == Enums.Advantage.PARTY_AMBUSH:
		for enemy in ctx.state.enemies():
			StaggerRules.apply_stagger(ctx, enemy, enemy.max_stagger * ctx.balance.ambush_stagger_fraction, null)
	for enemy in ctx.state.enemies():
		PhaseRules.check(ctx, enemy)
	TriggerDispatcher.dispatch(ctx, RuleContext.make(Enums.TriggerType.BATTLE_START))
	ctx.state.phase = Enums.BattlePhase.ROUND_START


func _round_start() -> void:
	if _check_end():
		return
	ctx.state.round += 1
	if ctx.state.round > ctx.balance.max_rounds:
		_end(Enums.BattleOutcome.TIMEOUT)
		return
	for trait_instance in TriggerDispatcher.all_trait_instances(ctx):
		trait_instance.reset_round()
	ctx.state.turn_order = TurnOrder.compute(ctx)
	ctx.state.turn_index = -1
	var started := BattleEvent.new(BattleEvent.Type.ROUND_STARTED)
	started.amount = ctx.state.round
	ctx.emit(started)
	var order := BattleEvent.new(BattleEvent.Type.TURN_ORDER)
	order.uids = ctx.state.turn_order.duplicate()
	ctx.emit(order)
	TriggerDispatcher.dispatch(ctx, RuleContext.make(Enums.TriggerType.ROUND_START))
	if _check_end():
		return
	ctx.state.phase = Enums.BattlePhase.ENEMY_DECIDE


func _enemy_decide() -> void:
	for uid in ctx.state.turn_order:
		var enemy := ctx.unit(uid)
		if not enemy.is_enemy() or not enemy.is_alive():
			continue
		if enemy.intent != null and enemy.intent.channeling:
			continue # A channel keeps its declared target and countdown.
		if enemy.is_broken():
			enemy.intent = null
			continue
		EnemyAI.decide(ctx, enemy)
	ctx.state.phase = Enums.BattlePhase.ENEMY_TELEGRAPH


func _enemy_telegraph() -> void:
	for uid in ctx.state.turn_order:
		var enemy := ctx.unit(uid)
		if not enemy.is_enemy() or not enemy.is_alive() or enemy.intent == null:
			continue
		var event := BattleEvent.new(BattleEvent.Type.INTENT_DECLARED, enemy.uid)
		event.uids = enemy.intent.target_uids.duplicate()
		event.action = enemy.intent.action
		event.amount = enemy.intent.turns_until_release()
		ctx.emit(event)
	_advance_to_next_unit()


func _advance_to_next_unit() -> void:
	var order := ctx.state.turn_order
	ctx.state.turn_index += 1
	while ctx.state.turn_index < order.size() and not ctx.unit(order[ctx.state.turn_index]).is_alive():
		ctx.state.turn_index += 1
	if ctx.state.turn_index >= order.size():
		ctx.state.phase = Enums.BattlePhase.ROUND_END
	else:
		ctx.state.phase = Enums.BattlePhase.UNIT_START


func _unit_start() -> void:
	var unit := ctx.state.current_unit()
	if unit == null or not unit.is_alive():
		_advance_to_next_unit()
		return
	_skipping = false
	unit.damaged_since_turn = false
	ctx.emit(BattleEvent.new(BattleEvent.Type.TURN_STARTED, unit.uid))
	InterceptRules.release(ctx, unit)
	BuffRules.tick(ctx, unit, Enums.BuffExpiry.OWNER_TURN_START)
	TriggerDispatcher.dispatch(ctx, RuleContext.make(Enums.TriggerType.TURN_START, unit))
	StatusRules.tick(ctx, unit, Enums.TickTiming.TURN_START)
	if _check_end():
		return
	if not unit.is_alive():
		ctx.state.phase = Enums.BattlePhase.UNIT_END
		return
	if unit.is_broken():
		_skipping = true
		ctx.emit(BattleEvent.new(BattleEvent.Type.TURN_SKIPPED, unit.uid))
		ctx.state.phase = Enums.BattlePhase.UNIT_END
		return
	if unit.is_enemy():
		FocusRules.gain(ctx, unit, ctx.balance.enemy_focus_per_turn, "Gathers strength")
		_enemy_activation(unit)
	else:
		_request_action(unit)


func _request_action(unit: BattleUnit) -> void:
	var request := ActionSelectRequest.new()
	request.unit_uid = unit.uid
	request.options = ActionRules.options_for(ctx, unit)
	if request.legal_options().is_empty():
		ctx.note("%s has nothing to do." % unit.display_name)
		ctx.state.phase = Enums.BattlePhase.UNIT_END
		return
	_request = request
	ctx.state.phase = Enums.BattlePhase.PLAYER_SELECT


func _enemy_activation(unit: BattleUnit) -> void:
	var intent := unit.intent
	if intent == null:
		ctx.note("%s hesitates." % unit.display_name)
		ctx.state.phase = Enums.BattlePhase.UNIT_END
		return
	var action := intent.action
	if intent.is_channel():
		if not intent.channeling:
			intent.channeling = true
			intent.channel_remaining = intent.channel_total
			var started := BattleEvent.new(BattleEvent.Type.CHANNEL_STARTED, unit.uid)
			started.action = action
			started.amount = intent.channel_remaining
			started.uids = intent.target_uids.duplicate()
			ctx.emit(started)
			ctx.state.phase = Enums.BattlePhase.UNIT_END
			return
		intent.channel_remaining -= 1
		if intent.channel_remaining > 0:
			var continued := BattleEvent.new(BattleEvent.Type.CHANNEL_CONTINUED, unit.uid)
			continued.action = action
			continued.amount = intent.channel_remaining
			ctx.emit(continued)
			ctx.state.phase = Enums.BattlePhase.UNIT_END
			return
	var targets := IntentRules.final_targets(ctx, unit)
	if targets.is_empty() and action.target_rule != Enums.TargetRule.NONE:
		ctx.note("%s's %s finds no target." % [unit.display_name, action.display_name])
		unit.intent = null
		ctx.state.phase = Enums.BattlePhase.UNIT_END
		return
	_pending_target_uids.clear()
	for target in targets:
		_pending_target_uids.append(target.uid)
	_pending_enemy_action = action
	# Only party targets that can react share the reaction; a Broken one is hit without one.
	var party_targets := IntentRules.reacting_targets(action, targets)
	if not party_targets.is_empty():
		var request := ReactionRequest.new()
		request.unit_uid = party_targets[0].uid
		request.attacker_uid = unit.uid
		for target in party_targets:
			request.target_uids.append(target.uid)
		request.action = action
		request.spec = ReactionRules.build_spec(ctx, unit, party_targets, action)
		_request = request
		ctx.state.phase = Enums.BattlePhase.REACTION_WINDOW
		return
	_reactions.clear()
	_reaction_resolve()


func _reaction_resolve() -> void:
	var unit := ctx.state.current_unit()
	var targets: Array[BattleUnit] = []
	for uid in _pending_target_uids:
		var target := ctx.unit(uid)
		if target != null and target.is_alive():
			targets.append(target)
	if unit != null and unit.is_alive() and _pending_enemy_action != null:
		ActionResolver.resolve(ctx, unit, _pending_enemy_action, targets, Enums.ExecutionGrade.GOOD, _reactions)
		if unit.intent != null and unit.intent.action == _pending_enemy_action:
			unit.intent = null
	_pending_enemy_action = null
	_pending_target_uids.clear()
	_reactions.clear()
	ctx.state.phase = Enums.BattlePhase.UNIT_END
	_check_end()


func _action_resolve() -> void:
	var actor := ctx.unit(_choice.unit_uid)
	var targets := ActionRules.targets_for_choice(ctx, actor, _choice.action, _choice.target_uid)
	# Cover works both ways: a warded enemy's interceptor takes the party's single-target attacks
	# (not Inspect or other non-damaging actions).
	if _choice.action.deals_damage():
		targets = InterceptRules.redirect(ctx, _choice.action, targets)
	var used_potion: PotionDefinition = null
	if _choice.item_slot >= 0 and _choice.item_slot < ctx.state.potion_slots.size():
		used_potion = ctx.state.potion_slots[_choice.item_slot].potion
	ActionResolver.resolve(ctx, actor, _choice.action, targets, _grade, {}, _choice.item_slot)
	_tally_weapon_use(actor, _choice.action, _grade)
	# The dose is spent when the action resolves (ActionResolver pays it), whatever happens next.
	if used_potion != null:
		_item_uses[used_potion.id] = _item_uses.get(used_potion.id, 0) + 1
	_choice = null
	ctx.state.phase = Enums.BattlePhase.UNIT_END
	_check_end()


func _unit_end() -> void:
	var unit := ctx.state.current_unit()
	if unit != null and unit.is_alive():
		var ended := BattleEvent.new(BattleEvent.Type.TURN_ENDED, unit.uid)
		ended.amount = unit.status_mask()
		StatusRules.on_turn_end(ctx, unit)
		BuffRules.tick(ctx, unit, Enums.BuffExpiry.OWNER_TURN_END)
		_tick_cooldowns(unit)
		StaggerRules.on_turn_end(ctx, unit)
		if _skipping:
			StaggerRules.on_skipped_turn_end(ctx, unit)
		TriggerDispatcher.dispatch(ctx, RuleContext.make(Enums.TriggerType.TURN_END, unit))
		ctx.emit(ended)
	_skipping = false
	if _check_end():
		return
	_advance_to_next_unit()


func _round_end() -> void:
	BuffRules.on_round_end(ctx)
	TriggerDispatcher.dispatch(ctx, RuleContext.make(Enums.TriggerType.ROUND_END))
	var ended := BattleEvent.new(BattleEvent.Type.ROUND_ENDED)
	ended.amount = ctx.state.round
	ctx.emit(ended)
	if _check_end():
		return
	ctx.state.phase = Enums.BattlePhase.ROUND_START


func _tick_cooldowns(unit: BattleUnit) -> void:
	for action_id: StringName in unit.cooldowns.keys():
		unit.cooldowns[action_id] -= 1
		if unit.cooldowns[action_id] <= 0:
			unit.cooldowns.erase(action_id)


func _tally_weapon_use(actor: BattleUnit, action: ActionDefinition, grade: Enums.ExecutionGrade) -> void:
	if actor == null or actor.weapon == null:
		return
	var weapon := actor.weapon
	if action != weapon.basic_attack and not weapon.techniques.has(action) and action != weapon.guard_action:
		return
	_weapon_uses[weapon.id] = _weapon_uses.get(weapon.id, 0) + 1
	if grade == Enums.ExecutionGrade.PERFECT:
		_weapon_perfects[weapon.id] = _weapon_perfects.get(weapon.id, 0) + 1


func _check_end() -> bool:
	if ctx.state.is_finished():
		return true
	var party_alive := false
	var enemies_alive := false
	for unit in ctx.state.units:
		if unit.is_alive():
			if unit.side == Enums.Side.PLAYER:
				party_alive = true
			else:
				enemies_alive = true
	if not enemies_alive:
		_end(Enums.BattleOutcome.VICTORY)
		return true
	if not party_alive:
		_end(Enums.BattleOutcome.DEFEAT)
		return true
	return false


func _end(outcome: Enums.BattleOutcome) -> void:
	ctx.state.outcome = outcome
	ctx.state.phase = Enums.BattlePhase.VICTORY if outcome == Enums.BattleOutcome.VICTORY \
		else Enums.BattlePhase.DEFEAT
	_request = null
	var event := BattleEvent.new(BattleEvent.Type.BATTLE_ENDED)
	event.amount = outcome
	ctx.emit(event)
