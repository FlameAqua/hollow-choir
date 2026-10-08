extends TestCase
## Boundaries found in the 8 October M1.1 engineering review: what is shown during playback comes
## from the PresentationLedger (D-013), pinned target details never cover the candidate targets, a
## host screen only covers a paused battle, timing cues invite only presses that would be read, and
## art fallbacks never raise errors. See docs/reports/M1_1_ENGINEERING_REVIEW_2026_10_08.md.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const SANDBOX_SCENE := "res://scenes/sandbox/combat_sandbox.tscn"
const MAX_WAIT_MS := 30000
const IDLE := &"idle"

var _tree: SceneTree


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func after_each() -> void:
	Engine.time_scale = 1.0


# --- Displayed state ---------------------------------------------------------------------------

func test_ledger_conditions_and_forecast_change_only_with_presented_events() -> void:
	var engine := _started_engine()
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var flooded: BattlefieldConditionDefinition = Database.registry.conditions[&"flooded_ground"]
	var fog: BattlefieldConditionDefinition = Database.registry.conditions[&"spore_fog"]
	assert_eq(ledger.conditions.size(), 1)
	assert_true(ledger.conditions.has(flooded), "snapshot holds the active condition")
	var removed := _event(BattleEvent.Type.CONDITION_REMOVED)
	removed.text = flooded.display_name
	var added := _event(BattleEvent.Type.CONDITION_ADDED)
	added.text = fog.display_name
	ledger.begin_batch([removed, added] as Array[BattleEvent])
	ledger.apply(removed, 0, engine)
	assert_false(ledger.conditions.has(flooded), "removed on its own event")
	ledger.apply(added, 1, engine)
	assert_true(ledger.conditions.has(fog), "a condition the engine no longer holds still resolves by name")
	ledger.snapshot(engine)
	assert_eq(ledger.displayed_forecast(), engine.forecast_next_round(), "stable point: the engine's forecast")
	var enemy := engine.get_state().enemies()[0]
	ledger.apply(_event(BattleEvent.Type.UNIT_DEFEATED, enemy.uid), 0, engine)
	assert_false(ledger.displayed_forecast().has(enemy.uid), "a unit shown defeated leaves the forecast")
	var round_started := _event(BattleEvent.Type.ROUND_STARTED)
	round_started.amount = ledger.round + 1
	ledger.apply(round_started, 1, engine)
	assert_empty(ledger.displayed_forecast(), "once a round starts, the old forecast describes the current round")


func test_timeline_and_condition_ribbon_draw_displayed_not_resolved_state() -> void:
	var engine := _started_engine()
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var enemies := engine.get_state().enemies()
	var rail := IntentRail.new()
	rail.setup(enemies)
	var timeline := TimelineBar.new()
	timeline.engine = engine
	timeline.ledger = ledger
	timeline.rail = rail
	for unit in engine.get_state().units:
		timeline.order.append(unit.uid)
	# The engine has already resolved the batch; the screen has not played it yet.
	enemies[0].hp = 0
	enemies[1].broken_turns_left = 1
	assert_has(timeline._upcoming(), enemies[0].uid, "no portrait leaves before its defeat plays")
	assert_false(timeline._broken(enemies[1]), "no Broken mark before BROKEN plays")
	ledger.unit(enemies[0].uid).alive = false
	ledger.unit(enemies[1].uid).broken = true
	assert_not_has(timeline._upcoming(), enemies[0].uid)
	assert_true(timeline._broken(enemies[1]))
	var channel := IntentReadout.new()
	channel.is_channel = true
	assert_false(timeline._channel(enemies[2]), "hourglass only for a channel the rail shows")
	rail.show_intent(enemies[2].uid, channel)
	assert_true(timeline._channel(enemies[2]))
	var ribbon := ConditionRibbon.new()
	ribbon.engine = engine
	ribbon.ledger = ledger
	ribbon.refresh()
	assert_true(ribbon.visible)
	assert_true(ribbon.plain_text().contains("Flooded Ground"))
	ledger.conditions.clear()
	ribbon.refresh()
	assert_false(ribbon.visible, "no header icon for a condition that has not been announced")
	timeline.free()
	rail.free()
	ribbon.free()


## Whole battle: at every HUD refresh during playback, the timeline matches the events played so far.
func test_timeline_never_runs_ahead_of_playback_in_a_whole_battle() -> void:
	Engine.time_scale = 30.0
	var scene := _battle(_setup(&"rot_grove", 1), true, Enums.SimulatedExecution.MIXED)
	var mismatches: Array[String] = []
	scene._events.hud_changed.connect(func() -> void:
		var ledger := scene._events.ledger
		var timeline := scene._timeline
		var upcoming := timeline._upcoming()
		for uid in timeline.order:
			var display := ledger.unit(uid)
			var unit := scene.engine.get_unit(uid)
			if display == null or timeline.acted.has(uid):
				continue
			if display.alive != upcoming.has(uid) or timeline._broken(unit) != display.broken:
				mismatches.append("%s after %d events" % [unit.display_name, scene._events.history.size()])
		for uid in timeline._forecast():
			if not ledger.unit(uid).alive:
				mismatches.append("forecast keeps %d" % uid))
	assert_true(await _until(func() -> bool: return not scene.is_running()), "battle finished")
	assert_eq(mismatches, [] as Array[String], "timeline state comes from the PresentationLedger")
	scene.queue_free()


## INSPECTED plays inside a batch the engine has already resolved: it re-reads only the inspected
## intent still on screen, and round starts / declarations follow presented life, not resolved life.
func test_rail_never_shows_resolved_turns_defeats_or_intents_early() -> void:
	Engine.time_scale = 20.0
	var scene := _battle(_setup(&"fen_patrol"), false, Enums.SimulatedExecution.GOOD)
	assert_true(await _until(func() -> bool: return scene._picker.is_active()))
	Engine.time_scale = 1.0
	var engine := scene.engine
	var rail := scene._rail
	var studied: BattleUnit = null
	var others: Array[BattleUnit] = []
	for unit in engine.get_state().enemies():
		if studied == null and rail.slot(unit.uid).state == IntentSlot.State.PLANNED:
			studied = unit
		else:
			others.append(unit)
	assert_not_null(studied, "an intent is on screen")
	assert_eq(others.size(), 2)
	var before := rail.slot(studied.uid).readout
	var states: Array[IntentSlot.State] = []
	var readouts: Array[IntentReadout] = []
	for unit in others:
		states.append(rail.slot(unit.uid).state)
		readouts.append(rail.slot(unit.uid).readout)
	assert_false(before.named, "an unknown species shows its category, not the move")
	# Resolved ahead of the screen: one enemy has since fallen, another has acted.
	others[0].hp = 0
	others[1].intent = null
	studied.inspected = true
	var inspected := _event(BattleEvent.Type.INSPECTED, studied.uid)
	await _present(scene, inspected)
	var reread := rail.slot(studied.uid).readout
	assert_ne(reread, before, "the inspected intent is re-read")
	assert_true(reread.named, "with what Inspect revealed")
	assert_eq(reread.action, before.action)
	for index in others.size():
		assert_eq(rail.slot(others[index].uid).state, states[index], "no Defeated / Acted before its event plays")
		assert_eq(rail.slot(others[index].uid).readout, readouts[index])
	# Once the engine has moved to a later round, the live intent is not the one on screen.
	engine.get_state().round += 1
	await _present(scene, inspected)
	assert_eq(rail.slot(studied.uid).readout, reread, "a later round's intent never shows early")
	var round_started := _event(BattleEvent.Type.ROUND_STARTED)
	round_started.amount = scene._events.ledger.round + 1
	await _present(scene, round_started)
	assert_eq(rail.slot(others[0].uid).state, IntentSlot.State.WAITING, "a unit shown alive waits for its new intent")
	var declared := _event(BattleEvent.Type.INTENT_DECLARED, others[0].uid)
	declared.action = others[0].enemy_def().actions[0]
	declared.uids = [engine.get_state().protagonist().uid] as Array[int]
	await _present(scene, declared)
	assert_eq(rail.slot(others[0].uid).state, IntentSlot.State.PLANNED, "its declaration plays before its defeat")
	await _present(scene, _event(BattleEvent.Type.UNIT_DEFEATED, others[0].uid))
	assert_eq(rail.slot(others[0].uid).state, IntentSlot.State.DEFEATED)
	scene.queue_free()


# --- Inspection and covering screens -----------------------------------------------------------

func test_target_review_does_not_pin_a_popup_over_controls() -> void:
	Engine.time_scale = 20.0
	var scene := _battle(_setup(&"fen_patrol"), false, Enums.SimulatedExecution.GOOD)
	assert_true(await _until(func() -> bool: return scene._picker.is_active()))
	Engine.time_scale = 1.0
	# Long ally details make the pinned card tall enough to reach the party's bodies.
	for unit in scene.engine.get_state().party():
		for status in [Enums.StatusId.BURN, Enums.StatusId.BLEED, Enums.StatusId.SHOCK]:
			StatusRules.apply_status(scene.engine.ctx, unit, status, 1, 2, null)
		for buff_id in [&"guarding", &"riposte_stance"]:
			BuffRules.grant(scene.engine.ctx, unit, Database.registry.buffs[buff_id], unit)
	scene.engine.drain_events()
	scene._events.ledger.snapshot(scene.engine)
	var potion := _button(scene, func(option: ActionOption) -> bool:
		return option.item_slot >= 0 and option.action.target_rule == Enums.TargetRule.SINGLE_ALLY)
	assert_not_null(potion, "starter loadout carries an ally-targeted potion")
	potion.pressed.emit()
	await _frames(3)
	assert_true(scene._picker.is_targeting())
	assert_true(scene._inspector.pinned_text.is_empty(), "target facts stay in the dock instead of pinning a popup")
	assert_false(scene._inspector.visible, "target review alone opens no hover card")
	var other := -1
	for uid in scene._picker._targets:
		if uid != scene._picker._targets[scene._picker._target_index]:
			other = uid
	_click(scene._battlefield.body_point(other))
	await _frames(2)
	assert_false(scene._picker.is_targeting(), "a click on the other ally selects it")
	assert_eq(int(scene.engine.input_log[-1].target), other)
	scene.queue_free()


func test_host_setup_covers_only_a_paused_battle() -> void:
	var sandbox: CombatSandbox = load(SANDBOX_SCENE).instantiate()
	_tree.root.add_child(sandbox)
	sandbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sandbox.size = Vector2(1280, 720)
	await _frames(2)
	# During a live reaction: the pause (and the page) wait for the next safe point.
	Engine.time_scale = 20.0
	var battle := _sandbox_battle(sandbox, true)
	assert_true(await _until(func() -> bool: return _reaction(battle) != null), "a reaction window opened")
	Engine.time_scale = 1.0
	var widget := _reaction(battle)
	widget._focus_lost = false
	widget.clock.resume()
	sandbox._toggle_setup()
	assert_false(sandbox._setup.visible, "the setup page never covers a running clock")
	assert_true(battle.is_pause_pending())
	assert_true(await _until(func() -> bool: return sandbox._setup.visible), "it opens at the next safe point")
	assert_true(not is_instance_valid(widget) or widget.is_done(), "the reaction resolved on screen first")
	assert_true(battle.is_paused(), "and the covered battle is paused")
	assert_false(battle._modal.visible, "Setup owns the only visible overlay")
	assert_false(battle._pause_panel.visible, "no stranded pause box over Setup")
	sandbox._show_setup(false)
	assert_false(battle.is_paused(), "closing Setup resumes directly")
	# During target review: back to the same action (nothing spent), paused, no pinned card.
	Engine.time_scale = 20.0
	battle = _sandbox_battle(sandbox, false)
	assert_true(await _until(func() -> bool: return battle._picker.is_active()))
	Engine.time_scale = 1.0
	_button(battle, func(option: ActionOption) -> bool:
		return option.legal and option.action.targets_enemies() and option.target_uids.size() > 1).pressed.emit()
	await _frames(2)
	assert_true(battle._picker.is_targeting())
	var logged := battle.engine.input_log.size()
	sandbox._toggle_setup()
	await _frames(2)
	assert_true(sandbox._setup.visible)
	assert_true(battle.is_paused())
	assert_eq(battle.process_mode, Node.PROCESS_MODE_DISABLED, "covered battle cannot receive keyboard or mouse actions")
	assert_true(battle._picker.is_active() and not battle._picker.is_targeting(), "target review returned to the menu")
	assert_eq(battle.engine.input_log.size(), logged, "nothing was submitted")
	assert_false(battle._inspector.visible, "no battle details over the setup page")
	sandbox.queue_free()


func test_inspector_reads_only_its_own_battle() -> void:
	var battle := Control.new()
	var outside := Button.new()
	outside.tooltip_text = "Host control"
	_tree.root.add_child(battle)
	_tree.root.add_child(outside)
	var inspector := HoverInspector.new()
	battle.add_child(inspector)
	var inside := Button.new()
	inside.tooltip_text = "Battle control"
	battle.add_child(inside)
	inspector.pinned_text = "Pinned target"
	inspector._pointer = false
	inside.grab_focus()
	inspector._process(0.2)
	assert_eq(inspector.shown_text(), "Battle control")
	outside.grab_focus()
	inspector._process(0.2)
	inspector._process(0.2)
	assert_false(inspector.visible, "a host control's tooltip or the pinned card never shows over another screen")
	battle.queue_free()
	outside.queue_free()


## UI-04: an empty supply slot and an unaffordable action stay focusable, explain why, and do nothing.
func test_empty_supplies_and_unaffordable_actions_explain_and_stay_unusable() -> void:
	Engine.time_scale = 20.0
	var scene := _battle(_setup(&"fen_patrol"), false, Enums.SimulatedExecution.GOOD)
	scene.engine.get_state().potion_slots[0].charges = 0
	assert_true(await _until(func() -> bool: return scene._picker.is_active()))
	Engine.time_scale = 1.0
	var logged := scene.engine.input_log.size()
	var empty := _button(scene, func(option: ActionOption) -> bool: return option.item_slot == 0)
	var costly := _button(scene, func(option: ActionOption) -> bool:
		return option.item_slot < 0 and option.action.focus_cost > scene._picker.acting_unit().focus)
	assert_not_null(empty)
	assert_not_null(costly, "the opening turn has an action it cannot afford yet")
	for button in [empty, costly]:
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "unusable options remain focusable to explain themselves")
	assert_true(empty.tooltip_text.contains("Empty"))
	assert_true(costly.tooltip_text.contains("Needs %d Focus" % costly.get_meta(&"option").action.focus_cost))
	costly.grab_focus()
	await _frames(1)
	assert_true(scene._info.get_text().contains("Unavailable"), "the preview states the reason")
	for button in [empty, costly]:
		button.pressed.emit()
		await _frames(1)
		assert_true(scene._picker.is_active() and not scene._picker.is_targeting(), "still choosing")
	assert_eq(scene.engine.input_log.size(), logged, "nothing reached the engine")
	assert_eq(scene.engine.get_state().potion_slots[0].charges, 0)
	scene.queue_free()


# --- Timing cues and fallbacks -----------------------------------------------------------------

func test_reaction_cue_invites_only_presses_that_are_read() -> void:
	var spec := ReactionSpec.new()
	spec.allowed = [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE] as Array[Enums.ReactionType]
	var widget := ReactionWidget.new()
	_tree.root.add_child(widget)
	widget.size = Vector2(1280, 720)
	widget.begin(spec, ReactionReadout.for_spec(spec, "Tester", "Test Swing"), [Vector2(100, 100)] as Array[Vector2],
		Rect2(300, 500, 704, 180))
	widget.set_process(false)
	widget.clock.set_elapsed(widget.impact_ms())
	widget.clock.freeze()
	widget._focus_lost = true
	widget._refresh_cards()
	assert_true(widget.window_open(Enums.ReactionType.BRACE), "the grader's window is open at impact")
	assert_false(widget.invites_press(Enums.ReactionType.BRACE), "presses are ignored while frozen")
	assert_ne(widget._card_status[0].text, "NOW")
	widget._focus_lost = false
	widget._refresh_cards()
	assert_ne(widget._card_status[0].text, "NOW", "still frozen until held keys are released")
	widget.clock.resume()
	widget.clock.set_elapsed(widget.impact_ms())
	widget._refresh_cards()
	assert_eq(widget._card_status[0].text, "NOW")
	assert_eq(widget._card_status[1].text, "NOW")
	widget._input(_action(InputBindings.PARRY))
	widget._refresh_cards()
	assert_eq(widget._card_status[2].text, "Unavailable", "an inert press stays noted across the per-frame refresh")
	assert_eq(widget.chosen(), Enums.ReactionType.NONE, "and neither locks nor fails the reaction")
	widget.queue_free()


func test_portraits_fall_back_without_an_idle_frame() -> void:
	var engine := BattleEngine.new(_setup(&"fen_patrol"))
	var unit := engine.get_state().enemies()[0]
	var definition := unit.definition.duplicate() as CombatantDefinition
	definition.sprite_frames = SpriteFrames.new()
	unit.definition = definition
	var canvas := Control.new()
	var drawn: Array[bool] = [false]
	canvas.draw.connect(func() -> void:
		CombatIcons.portrait(canvas, unit, Rect2(0, 0, 32, 32))
		drawn[0] = true)
	_tree.root.add_child(canvas)
	canvas.queue_redraw()
	await _frames(2)
	assert_true(drawn[0], "drawn with the placeholder colour and no engine error")
	canvas.queue_free()


## STAGE-03/04 fallbacks: art off and idle art without a defeated frame both draw a corpse in the
## same lane; Broken and an exposed weak point draw together. The harness fails on any engine error.
func test_corpse_and_state_fallbacks_draw_in_the_same_lane() -> void:
	var canvas := Control.new()
	_tree.root.add_child(canvas)
	var drawn := 0
	for enemy_id: StringName in Database.registry.enemies:
		var setup := _setup(&"fen_patrol")
		setup.enemies = [Database.registry.enemies[enemy_id]]
		var engine := BattleEngine.new(setup)
		var unit := engine.get_state().enemies()[0]
		var original: SpriteFrames = unit.definition.sprite_frames
		var idle_only := SpriteFrames.new()
		idle_only.add_animation(IDLE)
		idle_only.add_frame(IDLE, original.get_frame_texture(IDLE, 0))
		for key in original.get_meta_list():
			idle_only.set_meta(key, original.get_meta(key))
		var definition := unit.definition.duplicate() as CombatantDefinition
		definition.sprite_frames = idle_only
		for variant in ["art off", "no dead frame"]:
			if variant == "no dead frame":
				unit.definition = definition
			var ledger := PresentationLedger.new()
			ledger.snapshot(engine)
			var view := UnitView.new()
			view.use_sprites = variant != "art off"
			view.setup(unit, ledger, 1)
			canvas.add_child(view)
			var lane := view.size
			ledger.unit(unit.uid).broken = true
			ledger.unit(unit.uid).weak_point = true
			view.queue_redraw()
			await _frames(1)
			ledger.unit(unit.uid).alive = false
			view.queue_redraw()
			await _frames(1)
			assert_eq(view.presentation_animation(), UnitView.DEAD, "%s %s" % [enemy_id, variant])
			assert_eq(view.size, lane, "%s corpse keeps its lane (%s)" % [enemy_id, variant])
			view.queue_free()
			drawn += 1
	assert_eq(drawn, Database.registry.enemies.size() * 2)
	canvas.queue_free()


func test_preview_heal_glyph_marks_only_rows_that_heal() -> void:
	var driver := BattleDriver.new(_setup(&"fen_patrol"))
	var request := driver.to_player_turn()
	var checked := 0
	for option in request.options:
		var action_icon := CombatIcons.mapping("player_actions", option.action.id, "action_item")
		for row in ActionReadout.build(driver.engine, request.unit_uid, option).targets:
			if option.action.id == &"guard":
				assert_eq(PreviewPanel.row_icon(row, action_icon), "action_guard", "Guard shows its own symbol, not a heal")
				checked += 1
			elif option.item_slot >= 0 and option.action.id == &"use_mending_draught":
				assert_eq(PreviewPanel.row_icon(row, action_icon), "action_heal")
				checked += 1
	assert_gte(checked, 2)


# --- Helpers -----------------------------------------------------------------------------------

func _setup(encounter_id: StringName, battle_seed: int = 3) -> BattleSetup:
	var registry := Database.registry
	return BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[encounter_id], Database.library,
		registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), battle_seed)


## Fen Patrol at its first player turn: Flooded Ground is active, nobody has fallen.
func _started_engine() -> BattleEngine:
	var driver := BattleDriver.new(_setup(&"fen_patrol"))
	driver.to_player_turn()
	return driver.engine


func _battle(setup: BattleSetup, autoplay: bool, execution: Enums.SimulatedExecution) -> BattleScene:
	var scene: BattleScene = load(BATTLE_SCENE).instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.autoplay = autoplay
	launch.simulated_execution = execution
	scene.start(launch)
	return scene


func _sandbox_battle(sandbox: CombatSandbox, autoplay: bool) -> BattleScene:
	var launch := BattleLaunch.make(_setup(&"fen_patrol"), "")
	launch.record_progress = false
	launch.autoplay = autoplay
	sandbox._running_view = CombatSandbox.View.PRACTICE
	sandbox._launch(launch, "Retry", "Change")
	return sandbox._battle


func _reaction(scene: BattleScene) -> ReactionWidget:
	for child in scene._overlay.get_children():
		if child is ReactionWidget and not child.is_queued_for_deletion():
			return child
	return null


func _button(scene: BattleScene, wanted: Callable) -> Button:
	for button in scene._menu._buttons:
		if wanted.call(button.get_meta(&"option")):
			return button
	return null


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		_tree.root.push_input(click, true)


func _event(type: BattleEvent.Type, subject: int = -1) -> BattleEvent:
	var event := BattleEvent.new(type, subject)
	return event


## Plays one event the way BattleEventPlayer.play does, without the batch-end reconcile.
func _present(scene: BattleScene, event: BattleEvent) -> void:
	scene._events.ledger.apply(event, 0, scene.engine)
	await scene._events._play_one(event)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > MAX_WAIT_MS:
			return false
		await _tree.process_frame
	return true
