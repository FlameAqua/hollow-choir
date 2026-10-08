extends TestCase
## Presenter and widget tests (headless). Whole battles run through the real BattleScene with the
## autopilot and simulated execution at an accelerated Engine.time_scale. Widgets get their input
## injected at a chosen moment by setting their clock, which checks the input -> grade wiring
## without waiting in real time (the grading maths itself is covered by test_commands).

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const TIME_SCALE := 25.0
const MAX_WAIT_MS := 60000

var _tree: SceneTree
var _registry: DefinitionRegistry


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_registry = Database.registry
	Engine.time_scale = TIME_SCALE


func after_each() -> void:
	Engine.time_scale = 1.0


# --- Whole battles -------------------------------------------------------------------------------

func test_autoplayed_battle_plays_to_the_end() -> void:
	var scene := _start_battle(&"fen_patrol", &"starter_sword", true, Enums.SimulatedExecution.GOOD)
	var result := await _wait_for_result(scene)
	assert_not_null(result, "battle finished within the time limit")
	if result != null:
		assert_ne(result.outcome, Enums.BattleOutcome.NONE)
		assert_gt(scene._events.history.size(), 20, "events were played back")
		assert_true(scene._result_panel.visible, "result panel shown")
	scene.queue_free()


func test_boss_battle_with_phases_and_channels_plays_to_the_end() -> void:
	var scene := _start_battle(&"mirebell_cantor", &"starter_hammer", true, Enums.SimulatedExecution.MIXED)
	var result := await _wait_for_result(scene)
	assert_not_null(result, "boss battle finished within the time limit")
	if result != null:
		var types := {}
		for event: BattleEvent in scene._events.history:
			types[event.type] = true
		assert_true(types.has(BattleEvent.Type.CHANNEL_STARTED) or types.has(BattleEvent.Type.PHASE_CHANGED),
			"boss mechanics were presented")
	scene.queue_free()


func test_keyboard_confirm_submits_the_focused_action() -> void:
	var scene := _start_battle(&"toy_training", &"toy_solo", false, Enums.SimulatedExecution.GOOD)
	assert_true(await _wait_until(func() -> bool: return scene._picker.is_active()), "player turn reached")
	await _frames(3)
	_push_action(&"ui_accept")
	assert_true(await _wait_until(func() -> bool: return scene._picker.is_targeting()), "one legal enemy still requires target review")
	assert_true(_first_action(scene.engine).is_empty(), "selecting an attack alone does not commit it")
	_push_action(InputBindings.CONFIRM)
	assert_true(await _wait_until(func() -> bool: return not _first_action(scene.engine).is_empty()), "an action was submitted")
	var entry := _first_action(scene.engine)
	if not entry.is_empty():
		var hero := scene.engine.get_state().protagonist()
		assert_eq(StringName(entry.action), hero.weapon.basic_attack.id, "first entry is the basic attack")
	scene.queue_free()


func test_target_selection_moves_with_direction_keys() -> void:
	var scene := _start_battle(&"thornhound_pack", &"toy_solo", false, Enums.SimulatedExecution.GOOD)
	assert_true(await _wait_until(func() -> bool: return scene._picker.is_active()), "player turn reached")
	await _frames(3)
	_push_action(&"ui_accept")
	assert_true(await _wait_until(func() -> bool: return scene._picker.is_targeting()), "single-target attack asks for a target")
	var targets: Array[int] = scene._picker._targets.duplicate()
	var start_index: int = scene._picker._target_index
	_push_action(InputBindings.RIGHT)
	_push_action(InputBindings.CONFIRM)
	assert_true(await _wait_until(func() -> bool: return not _first_action(scene.engine).is_empty()), "an action was submitted")
	var entry := _first_action(scene.engine)
	if not entry.is_empty():
		assert_eq(int(entry.target), targets[wrapi(start_index + 1, 0, targets.size())], "Right moved the cursor to the next enemy")
	scene.queue_free()


# --- Widgets -------------------------------------------------------------------------------------

func test_timing_widget_grades_a_press_on_the_sweet_spot_perfect() -> void:
	var spec := _command_spec(Enums.ActionCommandType.TIMING)
	var widget := TimingWidget.new()
	_tree.root.add_child(widget)
	widget.begin(spec, "Test")
	widget.clock.set_elapsed(spec.target_time_ms())
	widget._input(_action_event(InputBindings.COMMAND, true))
	var grade: Enums.ExecutionGrade = await widget.finished
	assert_eq(grade, Enums.ExecutionGrade.PERFECT)
	widget.queue_free()


func test_timing_widget_grades_an_early_press_miss() -> void:
	var spec := _command_spec(Enums.ActionCommandType.TIMING)
	var widget := TimingWidget.new()
	_tree.root.add_child(widget)
	widget.begin(spec, "Test")
	widget._input(_action_event(InputBindings.COMMAND, true))
	var grade: Enums.ExecutionGrade = await widget.finished
	assert_eq(grade, Enums.ExecutionGrade.MISS)
	widget.queue_free()


func test_hold_widget_grades_a_release_at_the_target_perfect() -> void:
	var spec := _command_spec(Enums.ActionCommandType.HOLD_RELEASE)
	var widget := HoldReleaseWidget.new()
	_tree.root.add_child(widget)
	widget.begin(spec, "Test")
	widget._input(_action_event(InputBindings.COMMAND, true))
	widget.clock.advance(spec.target_time_ms())
	widget._input(_action_event(InputBindings.COMMAND, false))
	var grade: Enums.ExecutionGrade = await widget.finished
	assert_eq(grade, Enums.ExecutionGrade.PERFECT)
	widget.queue_free()


func test_rhythm_widget_grades_on_beat_presses_perfect() -> void:
	var spec := _command_spec(Enums.ActionCommandType.RHYTHM)
	var widget := RhythmWidget.new()
	_tree.root.add_child(widget)
	widget.begin(spec, "Test")
	for beat in spec.beat_count:
		widget.clock.set_elapsed(spec.beat_time_ms(beat))
		widget._input(_action_event(InputBindings.COMMAND, true))
	var grade: Enums.ExecutionGrade = await widget.finished
	assert_eq(grade, Enums.ExecutionGrade.PERFECT)
	widget.queue_free()


func test_reaction_widget_locks_the_first_allowed_key_and_grades_it() -> void:
	var widget := _reaction_widget([Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY])
	widget.clock.set_elapsed(widget.impact_ms())
	widget._input(_action_event(InputBindings.PARRY, true))
	widget._input(_action_event(InputBindings.BRACE, true))
	var result: ReactionResult = await widget.finished
	assert_eq(result.type, Enums.ReactionType.PARRY, "first key locks the choice")
	assert_true(result.success, "pressed on impact")
	widget.queue_free()


func test_reaction_widget_ignores_struck_through_reactions() -> void:
	var widget := _reaction_widget([Enums.ReactionType.BRACE])
	widget.clock.set_elapsed(widget.impact_ms())
	widget._input(_action_event(InputBindings.PARRY, true))
	widget._input(_action_event(InputBindings.BRACE, true))
	var result: ReactionResult = await widget.finished
	assert_eq(result.type, Enums.ReactionType.BRACE, "disallowed Parry did not lock the choice")
	assert_true(result.success)
	widget.queue_free()


func test_reaction_widget_without_input_reports_no_reaction() -> void:
	var widget := _reaction_widget([Enums.ReactionType.BRACE, Enums.ReactionType.EVADE])
	widget.clock.set_elapsed(widget.impact_ms() + 2000.0)
	var result: ReactionResult = await widget.finished
	assert_eq(result.type, Enums.ReactionType.NONE)
	widget.queue_free()


# --- Text helpers --------------------------------------------------------------------------------

func test_log_formatter_and_recap_cover_a_lost_battle() -> void:
	var history: Array[BattleEvent] = []
	var engine := _play_headless(&"mirebell_cantor", &"toy_solo", Enums.SimulatedExecution.MISS, 3, history)
	for event in history:
		BattleLogFormatter.line(event, engine) # Must not error for any event type.
	assert_eq(engine.get_outcome(), Enums.BattleOutcome.DEFEAT, "solo MISS player loses to the boss")
	var recap := BattleLogFormatter.defeat_recap(history, engine)
	assert_true(recap.begins_with("The Hollow fell to "), "recap: %s" % recap)
	assert_false(recap.contains("unknown causes"), "recap names the blow: %s" % recap)


func test_unit_details_reveal_affinities_only_with_knowledge() -> void:
	var setup := _setup(&"fen_patrol", &"starter_sword", 5)
	var engine := BattleEngine.new(setup)
	var wisp: BattleUnit = null
	for unit in engine.get_state().enemies():
		if unit.definition.id == &"fen_wisp":
			wisp = unit
	assert_not_null(wisp)
	var weakness := EnumText.damage_type(wisp.enemy_def().weaknesses[0])
	var unknown := UnitDetails.describe(engine, wisp)
	assert_false(unknown.contains("Weak: %s" % weakness), "weakness hidden while unknown")
	assert_true(unknown.contains("Unknown: "), "says what is still unknown")
	wisp.research_level = Enums.ResearchLevel.STUDIED
	var studied := UnitDetails.describe(engine, wisp)
	assert_true(studied.contains("Weak: %s" % weakness), "weakness shown once studied")
	assert_false(studied.contains("Unknown: "))


func test_code_labels_are_readable() -> void:
	assert_eq(InputBindings.code_label("key:Space"), "Space")
	assert_eq(InputBindings.code_label("joy:0"), "Pad A")
	assert_eq(InputBindings.code_label("joy:9"), "Pad LB")
	assert_eq(InputBindings.code_label("mouse:1"), "Mouse 1")


# --- Helpers -------------------------------------------------------------------------------------

func _setup(encounter_id: StringName, loadout_id: StringName, battle_seed: int) -> BattleSetup:
	return BattleSetup.from_encounter(_registry.loadouts[loadout_id], _registry.encounters[encounter_id], Database.library,
		_registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), _registry.assist(Enums.ExecutionAssist.STANDARD), battle_seed)


func _start_battle(encounter_id: StringName, loadout_id: StringName, autoplay: bool,
		execution: Enums.SimulatedExecution) -> BattleScene:
	var scene: BattleScene = load(BATTLE_SCENE).instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	var launch := BattleLaunch.make(_setup(encounter_id, loadout_id, 11), "")
	launch.autoplay = autoplay
	launch.simulated_execution = execution
	launch.record_progress = false
	scene.start(launch)
	return scene


func _wait_for_result(scene: BattleScene) -> BattleResult:
	var results: Array[BattleResult] = []
	scene.finished.connect(func(result: BattleResult) -> void: results.append(result))
	await _wait_until(func() -> bool: return not results.is_empty())
	return results[0] if not results.is_empty() else null


## The first player action in the engine's input log (reactions may come first).
static func _first_action(engine: BattleEngine) -> Dictionary:
	for entry in engine.input_log:
		if entry.kind == "action":
			return entry
	return {}


func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > MAX_WAIT_MS:
			return false
		await _tree.process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _push_action(action: StringName) -> void:
	_tree.root.push_input(_action_event(action, true))
	_tree.root.push_input(_action_event(action, false))


func _action_event(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _command_spec(type: Enums.ActionCommandType) -> CommandSpec:
	var spec := CommandSpec.new()
	spec.type = type
	spec.duration_ms = 1000.0
	spec.target_position = 0.75
	spec.good_window_ms = 300.0
	spec.perfect_window_ms = 100.0
	spec.beat_count = 3
	spec.beat_interval_ms = 420.0
	spec.lead_in_ms = 450.0
	return spec


func _reaction_widget(allowed: Array[Enums.ReactionType]) -> ReactionWidget:
	var spec := ReactionSpec.new()
	spec.allowed = allowed
	spec.windup_ms = 900.0
	var action := EnemyActionDefinition.new()
	action.display_name = "Test Swing"
	var widget := ReactionWidget.new()
	_tree.root.add_child(widget)
	widget.size = Vector2(1280, 720)
	var points: Array[Vector2] = [Vector2(100, 100)]
	widget.begin(spec, ReactionReadout.for_spec(spec, "Tester", action.display_name), points, Rect2(300, 500, 704, 180))
	return widget


## Runs a battle without presentation, collecting every event into [param history].
func _play_headless(encounter_id: StringName, loadout_id: StringName, execution: Enums.SimulatedExecution,
		battle_seed: int, history: Array[BattleEvent]) -> BattleEngine:
	var setup := _setup(encounter_id, loadout_id, battle_seed)
	var engine := BattleEngine.new(setup)
	var autopilot := PartyAutopilot.new(PartyAutopilot.Policy.SMART, battle_seed)
	var executor := ExecutionSimulator.new(_registry.skill(execution), battle_seed)
	var guard := 0
	while not engine.is_finished() and guard < 5000:
		guard += 1
		engine.advance()
		history.append_array(engine.drain_events())
		var request := engine.get_request()
		if request is ActionSelectRequest:
			engine.submit_action(autopilot.choose(engine, request))
		elif request is CommandRequest:
			engine.submit_command_result(executor.grade_command(request.spec, setup.assist))
		elif request is ReactionRequest:
			engine.submit_reaction(executor.react(setup.library.balance, request))
	history.append_array(engine.drain_events())
	return engine
