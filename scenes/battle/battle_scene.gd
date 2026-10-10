class_name BattleScene
extends Control
## Combat presenter (M1.1). Drives a BattleEngine and renders it; owns no rules.
##
## Regions follow BattleLayout: icon header/conditions · portrait timeline · full-size stage with
## compact intents and allied familiar · actions/preview/supplies dock · context help. One dock serves all
## three of the engine's input points:
##   ACTION_SELECT  -> ActionPicker in the dock (or the party autopilot)
##   ACTION_COMMAND -> a CommandWidget in the dock's centre (or the execution simulator)
##   REACTION       -> ReactionWidget: rings on the stage, meter and cards in the dock (or simulator)
## Everything else arrives as BattleEvents, played back by BattleEventPlayer.
##
## Pausing (Adrian, 9 October 2026; supersedes M1.1 F2's queued pause): Pause opens at once while
## choosing (recipient review included) and during playback, and freezes the battle in place
## (playback and its waits, announcements, floating text, the stage), so nothing runs unseen under
## an overlay; Resume continues at once. Pause requests (the Pause key, the toolbar button, a host's
## Setup) are ignored while a command or reaction window is open, from its preparation beat to its
## result: pausing must never help timing. Settings layout changes still wait for the window's end.
##
## Standalone: SceneRouter hands a BattleLaunch payload. Embedded: the CombatSandbox sets
## [member embedded] before adding the scene and calls start(), restarting by replacing the node.

signal finished(result: BattleResult)
signal restart_requested
signal setup_requested
## The battle thawed (no pause or host page holds it any more).
signal _resumed

## A real-time breathing beat before manual input. It never spends a command/reaction window.
const PREPARATION_MS := 400.0

## Set by a host (the sandbox) before the node enters the tree.
var embedded := false
## Result-screen button labels (hosts may override before start()).
var retry_text := "Retry same setup"
var change_text := "Change setup"
## World host (V0.4): the host commits the result itself and shows its own outcome card, so this
## scene emits [signal finished] without recording, showing the result panel or claiming progress.
var host_result := false
## Embedded pause-menu label for leaving the battle (the host handles setup_requested).
var leave_text := "Back to setup"
## Show real art (sprites, backdrop, portrait). Tests turn it off to compare outcomes.
var use_art := true
var launch: BattleLaunch
var engine: BattleEngine
var layout: BattleLayout

var _header_title: Label
var _header_round: Label
var _toolbar: HBoxContainer
var _log_button: Button
var _pause_button: Button
var _timeline: TimelineBar
var _battlefield: Battlefield
var _rail: IntentRail
var _ribbon: ConditionRibbon
var _menu: ActionMenu
var _idle: PanelContainer
var _idle_label: Label
var _info: PreviewPanel
var _supplies: PanelContainer
var _inspector: HoverInspector
var _familiar: FamiliarCard
var _timed_host: Control
var _help: Label
var _target_prompt: Label
var _log: BattleLogPanel
var _overlay: Control
var _banner: Banner
var _modal: Control
var _result_panel: ResultPanel
var _pause_panel: PanelContainer
var _pause_resume: Button
var _pause_leave: Button
var _combat_help: WorldModal
var _settings_screen: SettingsScreen
var _events: BattleEventPlayer
var _picker: ActionPicker
var _autopilot: PartyAutopilot
var _executor: ExecutionSimulator
var _details := false
var _timed_active := false
var _preparing := false
var _preparation_tween: Tween
var _window_focused := true
## Frozen in place: Pause (or its Settings/Help) or a host page.
var _frozen := false
## The outcome was handed over (result panel or host): Pause no longer opens.
var _concluded := false
## A standalone retreat is fading out; its frozen battle never resumes.
var _leaving := false
var _host_paused := false
var _layout_dirty := false
var _help_text := ""
var _result: BattleResult


func _ready() -> void:
	_build()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.input_device_changed.connect(_on_device_changed)
	resized.connect(_request_layout)
	if embedded:
		return
	var payload := SceneRouter.take_payload()
	start(payload as BattleLaunch if payload is BattleLaunch else _default_launch())


## Begins the battle described by [param p_launch]. Call once per instance.
func start(p_launch: BattleLaunch) -> void:
	launch = p_launch
	AudioManager.request_music(AudioManager.battle_music(launch.setup))
	engine = BattleEngine.new(launch.setup)
	var battle_seed := launch.setup.seed
	# Encounter + seed (+ the recorded input log) replay the battle exactly (BattleReplay).
	SessionLog.event("battle", "start %s, %d enemies, seed %d, %s" % [launch.setup.label, launch.setup.enemies.size(),
		battle_seed, launch.setup.difficulty.display_name if launch.setup.difficulty != null else "default difficulty"])
	_autopilot = PartyAutopilot.new(PartyAutopilot.Policy.SMART, battle_seed + 1)
	_executor = null
	if launch.simulated_execution >= 0:
		var skill := Database.registry.skill(launch.simulated_execution as Enums.SimulatedExecution)
		if skill != null:
			_executor = ExecutionSimulator.new(skill, battle_seed + 2)
	_events.setup(engine)
	_events.show_ai_reasons = launch.show_ai_reasoning
	_battlefield.use_art = use_art
	_battlefield.backdrop = Database.registry.defaults.battle_backdrop if use_art else null
	_battlefield.reduce_motion = Settings.data.reduce_motion
	_battlefield.setup(engine, _events.ledger, Settings.data.reduce_flashing)
	_rail.battlefield = _battlefield
	_rail.setup(engine.get_state().enemies(false))
	for view: UnitView in _battlefield.views.values():
		# The card and its change key come from the same filtered, ledger-driven readout.
		view.detail_provider = func(uid: int) -> String:
			var readout := _unit_readout(uid)
			return readout.plain_text() if readout != null else ""
		view.readout_provider = _unit_readout
	_timeline.engine = engine
	_timeline.ledger = _events.ledger
	_timeline.rail = _rail
	_timeline.use_art = use_art
	_ribbon.engine = engine
	_ribbon.ledger = _events.ledger
	# Playtest revision: the card reports the familiar passive this battle really applies.
	_familiar.setup(engine.get_state().familiar, _events.ledger, use_art, engine.get_state().familiar_trait)
	_picker.setup(engine, _menu, _battlefield, _info)
	_header_title.text = launch.setup.label if not launch.setup.label.is_empty() else "Battle"
	_apply_settings()
	_apply_layout()
	_events.refresh_rail()
	_ribbon.refresh()
	_log.clear_lines()
	_set_idle("Battle begins…")
	_run()


## Adds a button to the header toolbar (hosts add Restart / Setup there).
func add_toolbar_button(text: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.icon = CombatIcons.texture("restart" if text.to_lower().contains("restart") else "setup")
	button.expand_icon = true
	button.custom_minimum_size = Vector2(44, 40)
	UICraft.style_tool_button(button)
	button.tooltip_text = text + " · " + tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	_toolbar.add_child(button)
	_toolbar.move_child(button, 0)
	return button


func is_running() -> bool:
	return engine != null and not engine.is_finished()


## True while a command or reaction widget owns the clock.
func is_timed_input_active() -> bool:
	return _timed_active


func is_paused() -> bool:
	return _pause_panel.visible or is_instance_valid(_settings_screen) or is_instance_valid(_combat_help) or _host_paused


## Paused or covered by a host page: nothing in the battle moves.
func is_frozen() -> bool:
	return _frozen


# --- Battle loop ---------------------------------------------------------------------------------

func _run() -> void:
	await _intro()
	while not engine.is_finished():
		engine.advance()
		await _events.play(engine.drain_events())
		await _safe_point()
		var request := engine.get_request()
		if request == null:
			continue
		match request.kind:
			BattleRequest.Kind.ACTION_SELECT:
				await _answer_select(request as ActionSelectRequest)
			BattleRequest.Kind.ACTION_COMMAND:
				await _answer_command(request as CommandRequest)
			BattleRequest.Kind.REACTION:
				await _answer_reaction(request as ReactionRequest)
	await _events.play(engine.drain_events())
	await _finish_battle()


func _intro() -> void:
	var setup := engine.ctx.setup
	var lines := PackedStringArray()
	match setup.advantage:
		Enums.Advantage.PARTY_AMBUSH:
			lines.append("Ambush! The enemy starts off balance.")
		Enums.Advantage.ENEMY_AMBUSH:
			lines.append("Ambushed! The enemy moves first.")
	# Each condition is explained once by CONDITION_ADDED, then docks to its header icon.
	await _banner.announce(setup.label if not setup.label.is_empty() else "Battle", "\n".join(lines),
		(1.1 if lines.is_empty() else 1.8) / _events.speed, _events.speed)


## Between steps: apply deferred layout. A frozen battle starts no new request (menu, command or
## reaction window) until it thaws.
func _safe_point() -> void:
	if _layout_dirty:
		_layout_dirty = false
		_apply_layout()
	while _frozen:
		await _resumed


func _answer_select(request: ActionSelectRequest) -> void:
	var actor := engine.get_unit(request.unit_uid)
	var choice: ActionChoice
	if launch.autoplay:
		_set_idle("%s chooses… (autopilot)" % actor.display_name)
		choice = _autopilot.choose(engine, request)
		await _events.wait(0.25)
	else:
		_show_planning(true)
		_battlefield.set_active(request.unit_uid)
		choice = await _picker.choose(request)
		_show_planning(false)
	if choice == null or engine.submit_action(choice) != OK:
		push_warning("BattleScene: choice rejected; asking again")
	_set_idle("%s: %s" % [actor.display_name, BattleKnowledge.action_label(engine, actor, choice.action)] if choice != null else "")


func _answer_command(request: CommandRequest) -> void:
	var actor := request.unit_uid
	var grade: Enums.ExecutionGrade
	if _executor != null:
		_events.windup(actor, 0.25)
		await _events.wait(0.35)
		grade = _executor.grade_command(request.spec, launch.setup.assist)
	else:
		_begin_timed()
		var widget := make_command_widget(request.spec.type)
		_timed_host.add_child(widget)
		widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		widget.begin(request.spec, _command_title(request), true)
		_set_help(widget.instruction())
		await _prepare_timed()
		_events.windup(actor, 0.25)
		widget.start_timing()
		grade = await widget.finished
		widget.queue_free()
		_end_timed()
		_events.widget_grade = grade
	engine.submit_command_result(grade)


static func make_command_widget(type: Enums.ActionCommandType) -> CommandWidget:
	match type:
		Enums.ActionCommandType.HOLD_RELEASE:
			return HoldReleaseWidget.new()
		Enums.ActionCommandType.RHYTHM:
			return RhythmWidget.new()
		Enums.ActionCommandType.OPTIONAL_AIM:
			return AimWidget.new()
	return TimingWidget.new()


func _command_title(request: CommandRequest) -> String:
	var actor := engine.get_unit(request.unit_uid)
	var preview := engine.preview(request.choice)
	var label := BattleKnowledge.action_label(engine, actor, request.choice.action).to_upper()
	var target := engine.get_unit(preview.target_uid)
	if request.choice.action.is_area():
		return "%s → ALL" % label
	return "%s → %s" % [label, target.display_name.to_upper()] if target != null and target != actor else label


func _answer_reaction(request: ReactionRequest) -> void:
	var windup_seconds := request.spec.windup_ms / 1000.0
	var result: ReactionResult
	_battlefield.set_highlights(request.target_uids)
	if _executor != null:
		_events.windup(request.attacker_uid, windup_seconds)
		await _events.wait(windup_seconds)
		result = _executor.react(launch.setup.library.balance, request)
	else:
		_begin_timed()
		var readout := ReactionReadout.build(engine, request)
		var widget := ReactionWidget.new()
		widget.reduce_motion = Settings.data.reduce_motion
		widget.z_index = 60 # Input feedback must stay above residual battlefield floating text.
		_overlay.add_child(widget)
		widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var to_local := _overlay.get_global_transform().affine_inverse()
		var points: Array[Vector2] = []
		for uid in request.target_uids:
			points.append(to_local * _battlefield.body_point(uid))
		var dock := Rect2(to_local * _timed_host.global_position, _timed_host.size)
		widget.started.connect(func() -> void: _events.windup(request.attacker_uid, windup_seconds, false))
		widget.begin(request.spec, readout, points, dock, true)
		_set_help(_reaction_help(request.spec))
		await _prepare_timed()
		widget.start_timing()
		result = await widget.finished
		widget.queue_free()
		_end_timed()
	_battlefield.set_highlight(-1)
	engine.submit_reaction(result)


func _reaction_help(spec: ReactionSpec) -> String:
	var parts := PackedStringArray()
	for reaction: Enums.ReactionType in ReactionReadout.REACTIONS:
		var name := EnumText.reaction(reaction)
		var key := InputBindings.prompt(ReactionReadout.KEYS[reaction])
		parts.append("%s %s%s" % [key, name, "" if spec.is_allowed(reaction) else " ×"])
	var rule := "First allowed press locks"
	if spec.pause_before:
		rule = "%s Begin · %s" % [InputBindings.prompt(InputBindings.CONFIRM), rule]
	return " · ".join(parts) + "\n" + rule


## The actual input widget is already visible, with its clock at zero and input inactive.
## Its start_timing() relatches held keys after this scene-bound, real-time preview beat.
func _prepare_timed() -> void:
	_preparing = true
	_preparation_tween = create_tween().set_ignore_time_scale(true)
	_preparation_tween.tween_interval(PREPARATION_MS / 1000.0)
	if not _window_focused:
		_preparation_tween.pause()
	# Bound to this scene: restarting mid-preparation drops the wait with the old battle.
	await _preparation_tween.finished
	_preparing = false

func _begin_timed() -> void:
	_timed_active = true
	_inspector.enabled = false
	_inspector.clear()
	_supplies.visible = false
	_menu.visible = false
	_info.visible = false
	_idle.visible = false


func _end_timed() -> void:
	_inspector.enabled = true
	_timed_active = false
	_set_idle("")


func _finish_battle() -> void:
	_picker.cancel()
	_battlefield.set_active(-1)
	_result = engine.build_result()
	var outcome := engine.get_outcome()
	SessionLog.event("battle", "%s after %d rounds, %d inputs" % [EnumText.outcome(outcome), _result.rounds,
		_result.input_log.size()])
	AudioManager.play(AudioManager.Cue.VICTORY if outcome == Enums.BattleOutcome.VICTORY else AudioManager.Cue.DEFEAT)
	if host_result:
		await _banner.announce(EnumText.outcome(outcome), "", 0.9 / _events.speed, _events.speed)
		_conclude()
		finished.emit(_result)
		return
	var levels_before := {}
	for enemy_id: StringName in _result.research:
		levels_before[enemy_id] = GameState.research_level(enemy_id)
	if launch.record_progress:
		GameState.record_battle(_result)
	await _banner.announce(EnumText.outcome(outcome), "", 0.9 / _events.speed, _events.speed)
	var color := UITheme.HEART if outcome == Enums.BattleOutcome.VICTORY else UITheme.THREAT
	var primary := retry_text if embedded else "Retry"
	var secondary := change_text if embedded else "Continue"
	_conclude()
	_modal.visible = true
	_result_panel.show_result(EnumText.outcome(outcome), color, _cause_text(), _details_text(levels_before), primary, secondary)
	_set_help("%s Select" % InputBindings.prompt(InputBindings.CONFIRM))
	finished.emit(_result)


## The outcome now belongs to the result panel or the host: no later pause, and the log cannot keep
## reading wheel or Page keys underneath the next card.
func _conclude() -> void:
	_concluded = true
	_log.hide()


## What decided the battle, in plain facts from the log (no recommendation).
func _cause_text() -> String:
	var lines := PackedStringArray()
	match engine.get_outcome():
		Enums.BattleOutcome.VICTORY:
			lines.append("Every enemy fell in %d rounds." % engine.get_state().round)
		Enums.BattleOutcome.TIMEOUT:
			lines.append("The battle passed the %d-round limit." % engine.ctx.balance.max_rounds)
		_:
			var recap := BattleLogFormatter.defeat_recap(_events.history, engine)
			lines.append(recap if not recap.is_empty() else "The party fell.")
	if not launch.record_progress:
		lines.append("[color=%s]%s: progress not recorded.[/color]" % [UITheme.hex(UITheme.TEXT_DIM),
			"Practice" if embedded else "This battle"])
	return "\n".join(lines)


func _details_text(levels_before: Dictionary) -> String:
	var metrics := BattleMetrics.new()
	metrics.consume(engine, _events.history)
	metrics.finalize(engine)
	var lines := PackedStringArray()
	lines.append("%d rounds · seed %d · %s · %s" % [metrics.rounds, _result.seed, launch.setup.difficulty.display_name,
		launch.setup.assist.display_name])
	lines.append("Damage dealt %d · taken %d · healed %d" % [metrics.damage_dealt, metrics.damage_taken, metrics.healing_done])
	lines.append("Breaks %d · Interrupts %d · Weakness hits %d · Potions %d" % [metrics.stagger_breaks, metrics.interrupts,
		metrics.weakness_hits, metrics.potions_used])
	lines.append("Commands: Perfect %d · Good %d · Miss %d" % [metrics.grades.get(Enums.ExecutionGrade.PERFECT, 0),
		metrics.grades.get(Enums.ExecutionGrade.GOOD, 0), metrics.grades.get(Enums.ExecutionGrade.MISS, 0)])
	var reactions := PackedStringArray()
	for reaction: Enums.ReactionType in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		var counts: Vector2i = metrics.reactions.get(reaction, Vector2i.ZERO)
		if counts.x > 0:
			reactions.append("%s %d/%d" % [EnumText.reaction(reaction), counts.y, counts.x])
	var unanswered: Vector2i = metrics.reactions.get(Enums.ReactionType.NONE, Vector2i.ZERO)
	if unanswered.x > 0:
		reactions.append("no reaction %d" % unanswered.x)
	if not reactions.is_empty():
		lines.append("Reactions: " + " · ".join(reactions))
	if launch.record_progress:
		for enemy_id: StringName in _result.research:
			var enemy: EnemyDefinition = Database.registry.enemies.get(enemy_id)
			var before: int = levels_before.get(enemy_id, 0)
			var after := GameState.research_level(enemy_id)
			var gained := " → %s" % EnumText.research_level(after) if after > before else ""
			lines.append("Bestiary: %s (%s)%s" % [enemy.display_name if enemy != null else String(enemy_id),
				EnumText.research_level(before as Enums.ResearchLevel), gained])
	return "\n".join(lines)


# --- Input, Details and pause ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if is_instance_valid(_settings_screen):
		return
	if event.is_action(InputBindings.INFO) and not event.is_echo():
		match Settings.data.advanced_tooltips:
			GameSettings.TooltipMode.TOGGLE:
				if event.is_pressed():
					_set_details(not _details)
			GameSettings.TooltipMode.ALWAYS:
				_set_details(true)
			_:
				_set_details(event.is_pressed())
	elif event.is_action_pressed(InputBindings.LOG, false):
		get_viewport().set_input_as_handled()
		# Never reopen the log underneath Pause, Help or the result card (Pause → Battle log does).
		if not _modal.visible:
			_log.toggle()

func _process(_delta: float) -> void:
	# Only the move region reveals its already-public recipients, independently of action selection.
	var recipients: Array[int] = []
	if engine != null and _menu.visible and not _modal.visible and not _log.visible:
		var hovered := get_viewport().gui_get_hovered_control() as IntentSlot
		if hovered != null:
			var intent: IntentReadout = hovered.get_meta(&"inspection_intent").call(_inspector._local_point(hovered))
			if intent != null:
				recipients = intent.target_uids
	_battlefield.set_intent_targets(recipients)
	# A release can be swallowed by an OS shortcut or focus change. Hold mode follows the actual
	# action state every frame; Toggle and Always retain their explicitly selected behavior.
	if Settings.data.advanced_tooltips == GameSettings.TooltipMode.HOLD and _details != Input.is_action_pressed(InputBindings.INFO):
		_set_details(Input.is_action_pressed(InputBindings.INFO))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_window_focused = false
		if _preparing:
			_preparation_tween.pause()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_window_focused = true
		if _preparing:
			_preparation_tween.play()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _inspector != null and Settings.data.advanced_tooltips == GameSettings.TooltipMode.HOLD:
		_set_details(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputBindings.MENU, false) and not \
			(_pause_panel.visible and event.is_action_pressed(InputBindings.CANCEL, false)):
		return
	get_viewport().set_input_as_handled()
	request_pause()


## Toggles Pause. It opens at once while choosing (recipient review stays exactly as it was
## underneath; nothing is spent or submitted) and during playback, until the outcome is handed over.
## While a command or reaction window is open the request is ignored, not queued (no timing aid).
func request_pause() -> void:
	if is_instance_valid(_settings_screen) or is_instance_valid(_combat_help) or _leaving:
		return
	if _pause_panel.visible:
		_close_pause()
	elif engine != null and not _modal.visible and not _host_paused and not _concluded and not _timed_active:
		_open_pause()


## A host (the sandbox) wants to cover this battle with its own screen. A covered battle must be
## frozen: no clock, input or inspection may run under another screen. Like Pause, this is refused
## (false) while a command or reaction window is open. Otherwise a target under review returns to its
## action first (nothing is spent) and the host may cover at once (cover_for_host).
func pause_for_host() -> bool:
	if _timed_active:
		return false
	if _picker.is_targeting():
		_picker.back_to_menu()
	return true


func _set_details(on: bool) -> void:
	var value := on or Settings.data.advanced_tooltips == GameSettings.TooltipMode.ALWAYS
	if value == _details:
		return
	_details = value
	_inspector.expanded = value
	_picker.details = value
	_refresh_help()


func _open_pause() -> void:
	_set_frozen(true)
	_log.hide()
	AudioManager.play(AudioManager.Cue.UI_CANCEL)
	get_viewport().gui_release_focus()
	# Once the engine has decided the battle, leaving could only discard the decided outcome.
	_pause_leave.disabled = engine.is_finished()
	_modal.visible = true
	_pause_panel.visible = true
	_pause_panel.reset_size()
	_pause_panel.position = ((_modal.size - _pause_panel.size) * 0.5).round()
	_pause_resume.grab_focus()
	_refresh_help()


func _close_pause() -> void:
	if _leaving:
		return
	_pause_panel.visible = false
	_modal.visible = false
	if _picker.is_active() and not _picker.is_targeting():
		_menu.refocus()
	_refresh_help()
	_resume_battle()


## Embedded: open the host's setup over the frozen battle (closing it resumes the battle).
## Standalone: the frozen battle fades out without resuming.
func _retreat() -> void:
	if _pause_leave.disabled:
		return
	if embedded:
		setup_requested.emit()
	else:
		_leaving = true
		get_viewport().gui_release_focus()
		SceneRouter.goto(launch.return_scene if not launch.return_scene.is_empty() else SceneRouter.MAIN_MENU)


## Freezes or thaws everything that moves on its own: event playback and its waits, announcements
## and floating text (tweens bound to these nodes, D-014), the stage and familiar animation and
## recipient-review keys. No command or reaction window is ever open here (Pause ignores them).
func _set_frozen(on: bool) -> void:
	if on == _frozen:
		return
	_frozen = on
	for node: Node in [_events, _overlay, _timed_host, _battlefield, _familiar, _picker]:
		node.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if not on:
		_resumed.emit()


## Thaws once nothing covers the battle any more.
func _resume_battle() -> void:
	if _frozen and not is_paused():
		_set_frozen(false)


## Gives keyboard focus back to the battle (the host's setup drawer closed).
func refocus() -> void:
	if _pause_panel.visible:
		_pause_resume.grab_focus()
	elif _result_panel.visible:
		_result_panel.focus_primary()
	elif _picker.is_active() and not _picker.is_targeting():
		_menu.refocus()


## A click gives the log keyboard focus for scrolling; closing it hands focus back to planning, so
## keyboard and controller navigation never strands on a hidden panel.
func _on_log_visibility() -> void:
	if _log.visible or not is_inside_tree():
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or _log.is_ancestor_of(owner):
		refocus.call_deferred()


## The sandbox owns the visible page. Suspend and hide this subtree without a second pause overlay:
## frozen floating text or a late banner (raised z layers) must not draw over the host page.
func cover_for_host() -> void:
	_host_paused = true
	_set_frozen(true)
	_modal.visible = false
	_pause_panel.visible = false
	_inspector.clear()
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false


func resume_from_host() -> void:
	if not _host_paused:
		return
	_host_paused = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_modal.visible = _result_panel.visible
	refocus()
	_resume_battle()


func _on_result_primary() -> void:
	if embedded:
		restart_requested.emit()
		return
	# Retry: same fight, next seed.
	var retry := BattleLaunch.make(launch.setup, launch.return_scene)
	retry.setup.seed += 1
	retry.record_progress = launch.record_progress
	retry.autoplay = launch.autoplay
	retry.simulated_execution = launch.simulated_execution
	retry.show_ai_reasoning = launch.show_ai_reasoning
	SceneRouter.goto(SceneRouter.BATTLE, retry)


func _on_result_secondary() -> void:
	if embedded:
		setup_requested.emit()
	else:
		SceneRouter.goto(launch.return_scene if not launch.return_scene.is_empty() else SceneRouter.MAIN_MENU)


func _on_unit_hovered(uid: int) -> void:
	_picker.hover(uid)


## Opened directly (F6 in the editor): the practice fight with the saved loadout and current settings.
func _default_launch() -> BattleLaunch:
	var encounter := Database.registry.defaults.practice_encounter
	var setup := BattleSetup.from_encounter(GameState.build_loadout(), encounter, Database.library,
		Settings.difficulty_profile(), Settings.assist_profile(), randi() % 100000)
	setup.research_levels = GameState.research_levels()
	var default_launch := BattleLaunch.make(setup, SceneRouter.MAIN_MENU)
	default_launch.record_progress = false
	return default_launch


# --- HUD refresh ---------------------------------------------------------------------------------

func _refresh_hud() -> void:
	_timeline.refresh()
	_header_round.text = "Round: %d" % maxi(1, _timeline.round_number)
	_header_round.tooltip_text = "Round %d" % maxi(1, _timeline.round_number)
	_familiar.refresh()
	if _ribbon_dirty():
		_ribbon.refresh()


## The displayed conditions changed (a replacement keeps the count, so compare identities).
func _ribbon_dirty() -> bool:
	var ids := PackedStringArray()
	for definition in _events.ledger.conditions:
		ids.append(String(definition.id))
	var shown := ",".join(ids)
	if shown != _ribbon.get_meta(&"shown", "?"):
		_ribbon.set_meta(&"shown", shown)
		return true
	return false


func _set_idle(text: String) -> void:
	_idle_label.text = text
	_idle.visible = not _timed_active and not _picker.is_active()
	if not _picker.is_active() and not _timed_active:
		_refresh_help()


func _show_planning(on: bool) -> void:
	_menu.visible = on
	_supplies.visible = on
	_info.visible = false
	_idle.visible = not on and not _timed_active


func _set_help(text: String) -> void:
	_help_text = text
	_refresh_help()


## Context help: only the current state's keys, on the active device (M1.1 layout contract).
func _refresh_help() -> void:
	var text := _help_text
	if not _picker.is_active() and not _timed_active and not _modal.visible:
		text = "%s Log · %s Pause" % [InputBindings.prompt(InputBindings.LOG), InputBindings.prompt(InputBindings.MENU)]
	_help.text = text.replace("\n", " · ")
	_help.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_target_prompt.text = _picker.target_prompt()
	_target_prompt.visible = not _target_prompt.text.is_empty() and not _modal.visible


func _on_device_changed() -> void:
	_refresh_toolbar_tooltips()
	_ribbon.refresh()
	if _picker.is_active():
		_picker.render()
		_set_help(_picker.help_text())
	_refresh_help()


## Bound keys follow the active device; the shared inspector shows these as cards.
func _refresh_toolbar_tooltips() -> void:
	_log_button.tooltip_text = "%s Battle log" % InputBindings.prompt(InputBindings.LOG)
	_pause_button.tooltip_text = "%s Pause\nFreezes the battle while choosing or watching. Ignored during timed inputs." % InputBindings.prompt(InputBindings.MENU)


func _on_settings_changed() -> void:
	_apply_settings()
	if _timed_active:
		_layout_dirty = true
	else:
		_apply_layout()


func _apply_settings() -> void:
	_events.speed = clampf(Settings.data.combat_speed, 0.5, 2.0)
	_events.show_numbers = Settings.data.show_damage_numbers
	_events.reduce_motion = Settings.data.reduce_motion
	_battlefield.screen_shake = Settings.data.screen_shake
	_battlefield.reduce_motion = Settings.data.reduce_motion
	for view: UnitView in _battlefield.views.values():
		view.reduce_flashing = Settings.data.reduce_flashing
		view.reduce_motion = Settings.data.reduce_motion
	_set_details(Input.is_action_pressed(InputBindings.INFO) if Settings.data.advanced_tooltips == GameSettings.TooltipMode.HOLD else _details)


# --- Layout --------------------------------------------------------------------------------------

func _request_layout() -> void:
	if _timed_active:
		_layout_dirty = true
	else:
		_apply_layout()


func _apply_layout() -> void:
	if _timeline == null:
		return
	layout = BattleLayout.compute(size, UITheme.text_scale())
	if _inspector != null:
		_inspector._position_card()
		_inspector.size = layout.preview.size
	_place(_header_title.get_parent_control(), layout.header)
	_place(_timeline, layout.timeline)
	_place(_battlefield, layout.stage)
	# The turn-order strip's center stays above inspection; recipient guidance cannot be covered
	# by the very card the player is reading while choosing that recipient.
	var prompt_height := minf(UITheme.control_height(), layout.timeline.size.y)
	_place(_target_prompt, Rect2(Vector2(layout.timeline.get_center().x - 220, layout.timeline.get_center().y - prompt_height * 0.5), Vector2(440, prompt_height)))
	_place(_help, layout.help)
	_place(_header_round, Rect2(layout.help.end.x - 110, layout.help.position.y, 110, layout.help.size.y))
	_help.size.x -= 120
	_place(_timed_host, layout.timed)
	_rail.arrange(layout.stage)
	_place(_menu, layout.actions)
	_place(_info, layout.preview)
	_place(_supplies, layout.supplies)
	_place(_idle, Rect2(layout.actions.position, Vector2(layout.preview.end.x - layout.actions.position.x, layout.actions.size.y)))
	var log_width := minf(460, layout.stage.size.x * 0.45)
	_place(_log, Rect2(layout.stage.end.x - log_width, layout.stage.position.y, log_width, layout.stage.size.y))
	_place_dynamic.call_deferred()

func _place_dynamic() -> void:
	if _battlefield == null or layout == null:
		return
	_battlefield.layout_units()
	_rail.place_slots()
	if engine != null and engine.get_state().familiar != null:
		var party := engine.get_state().party(false)
		var companion := _battlefield.view(party[party.size() - 1].uid)
		var pet_size := _familiar.stage_size()
		var at := companion.position + Vector2(-pet_size.x - 6, companion.size.y - companion.plate_height() - pet_size.y + 4)
		at.x = maxf(0, at.x)
		_place(_familiar, Rect2(_battlefield.position + at, pet_size))

## Stage inspection: presented (ledger) state, the displayed intent, and planning-time knowledge.
func _unit_readout(uid: int) -> UnitReadout:
	var unit := engine.get_unit(uid)
	if unit == null:
		return null
	var slot := _rail.slot(uid)
	return UnitReadout.build(engine, unit, _events.ledger.unit(uid), slot.readout if slot != null else null, _picker.is_active())


static func _place(node: Control, rect: Rect2) -> void:
	if node == null:
		return
	node.position = rect.position.round()
	node.size = rect.size.round()
	node.custom_minimum_size = Vector2.ZERO


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = UICraft.texture("peat")
	background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.modulate = Color(.52, .62, .59)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 14)
	add_child(header)
	_header_title = UITheme.label("Battle", UITheme.TEXT, UITheme.body_size())
	_header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_title.clip_text = true
	_header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_title.size_flags_vertical = Control.SIZE_FILL
	header.add_child(_header_title)
	_header_round = UITheme.label("Round 1", UITheme.TEXT_DIM, 11)
	_header_round.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_round.size_flags_vertical = Control.SIZE_FILL
	_header_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_round.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header_round)
	var toolbelt := PanelContainer.new()
	toolbelt.name = "Toolbelt"
	toolbelt.add_theme_stylebox_override("panel", UICraft.panel("tooltip", 10, 3))
	header.add_child(toolbelt)
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	toolbelt.add_child(_toolbar)
	_log_button = Button.new()
	_log_button.icon = CombatIcons.texture("log")
	_log_button.expand_icon = true
	_log_button.custom_minimum_size = Vector2(40, 40)
	_log_button.focus_mode = Control.FOCUS_ALL
	UICraft.style_tool_button(_log_button)
	_log_button.pressed.connect(func() -> void: _log.toggle())
	_toolbar.add_child(_log_button)
	_pause_button = Button.new()
	_pause_button.icon = CombatIcons.texture("pause")
	_pause_button.expand_icon = true
	_pause_button.custom_minimum_size = Vector2(40, 40)
	_pause_button.focus_mode = Control.FOCUS_ALL
	UICraft.style_tool_button(_pause_button)
	_pause_button.pressed.connect(request_pause)
	_toolbar.add_child(_pause_button)
	_refresh_toolbar_tooltips()

	_timeline = TimelineBar.new()
	_timeline.name = "Timeline"
	add_child(_timeline)

	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_battlefield.unit_hovered.connect(_on_unit_hovered)
	_battlefield.unit_clicked.connect(func(uid: int) -> void: _picker.click(uid))

	_rail = IntentRail.new()
	_rail.name = "IntentRail"
	add_child(_rail)
	_rail.slot_hovered.connect(_on_unit_hovered)
	_rail.slot_clicked.connect(func(uid: int) -> void: _picker.click(uid))
	_target_prompt = UITheme.label("", UITheme.ACCENT, UITheme.secondary_size())
	_target_prompt.name = "TargetPrompt"
	_target_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_prompt.add_theme_stylebox_override("normal", UICraft.panel("tooltip", 12, 6))
	_target_prompt.visible = false
	add_child(_target_prompt)

	_ribbon = ConditionRibbon.new()
	_ribbon.name = "ConditionRibbon"
	header.add_child(_ribbon)
	header.move_child(_ribbon, 1)
	var divider := TextureRect.new()
	divider.texture = UICraft.texture("slider_track")
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.custom_minimum_size = Vector2(16, 3)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(divider)
	header.move_child(divider, 2)

	_supplies = PanelContainer.new()
	_supplies.name = "Supplies"
	_supplies.z_index = 12
	_supplies.add_theme_stylebox_override("panel", UICraft.panel("bag", 10, 12))
	_supplies.visible = false
	add_child(_supplies)
	_menu = ActionMenu.new()
	_menu.name = "ActionMenu"
	_menu.visible = false
	add_child(_menu)
	_menu.setup_supplies(_supplies)
	_info = PreviewPanel.new()
	_info.name = "Preview"
	_info.summary_scale = InspectionContent.CONTENT_SCALE
	_info.set_meta(&"inspection_readout", func(_point: Vector2) -> ActionReadout: return _info._readout)
	_info.visible = false
	add_child(_info)
	_idle = PanelContainer.new()
	_idle.name = "Idle"
	_idle.add_theme_stylebox_override("panel", UICraft.panel("cloth", 14, 10))
	add_child(_idle)
	_idle_label = UITheme.label("", UITheme.TEXT_DIM, UITheme.body_size(), true)
	_idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_idle.add_child(_idle_label)
	_familiar = FamiliarCard.new()
	_familiar.name = "Familiar"
	add_child(_familiar)
	_timed_host = Control.new()
	_timed_host.name = "TimedInput"
	_timed_host.z_index = 60
	_timed_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timed_host)

	_help = UITheme.label("", UITheme.TEXT_DIM, UITheme.secondary_size())
	_help.name = "Help"
	_help.add_theme_font_size_override("font_size", 11)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The fixed game footer has two authored lines. Wrapping at an initial zero width can leave
	# a stale oversized minimum height; the canonical canvas already fits the complete prompts.
	_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	_help.clip_text = false
	_help.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	add_child(_help)

	_log = BattleLogPanel.new()
	_log.name = "Log"
	_log.visible = false
	add_child(_log)
	_log.visibility_changed.connect(_on_log_visibility)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner = Banner.new()
	_banner.name = "Banner"
	_banner.ribbon = _ribbon
	_overlay.add_child(_banner)

	_modal = Control.new()
	_modal.name = "Modal"
	_modal.z_index = 100
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dimmer)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_panel = ResultPanel.new()
	_result_panel.name = "Result"
	_modal.add_child(_result_panel)
	_result_panel.primary_pressed.connect(_on_result_primary)
	_result_panel.secondary_pressed.connect(_on_result_secondary)
	_build_pause_panel()

	_events = BattleEventPlayer.new()
	_events.name = "EventPlayer"
	_events.battlefield = _battlefield
	_events.timeline = _timeline
	_events.rail = _rail
	_events.overlay = _overlay
	_events.banner = _banner
	add_child(_events)
	_events.log_line.connect(func(line: String) -> void: _log.append(line))
	_events.hud_changed.connect(_refresh_hud)
	_events.familiar_triggered.connect(func() -> void: _familiar.pulse(Settings.data.reduce_motion))

	_inspector = HoverInspector.new()
	_inspector.name = "HoverInspector"
	_inspector.docked = true
	_inspector.fallback_source = func() -> Control: return _info
	_inspector.suppressed = func() -> bool: return _modal.visible or _banner.visible or _timed_active or not _menu.visible
	_inspector.bounds_provider = func() -> Rect2: return layout.preview if layout != null else Rect2(660, 490, 596, 186)
	_inspector.keyboard_source = func() -> Control:
		var uid := _picker.reviewed_target_uid()
		return _battlefield.view(uid) if uid >= 0 else null
	add_child(_inspector)
	# One wheel rule for the dock lists and the card, independent of input callback order.
	_menu.wheel_claimed = _inspector.claims_wheel
	_banner.visibility_changed.connect(func() -> void:
		if _banner.visible:
			_inspector.clear())
	# The shared inspector replaces the native delayed tooltip within this battle.
	apply_battle_theme()
	_picker = ActionPicker.new()
	_picker.name = "ActionPicker"
	add_child(_picker)
	_picker.help_changed.connect(_set_help)
	_picker.keyboard_navigation.connect(_inspector.follow_keyboard)
	# Target facts remain in the dock. Context cards appear only on hover or explicit navigation.


func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "Pause"
	_pause_panel.visible = false
	_pause_panel.add_theme_stylebox_override("panel", UICraft.panel("cloth", 20, 14))
	_modal.add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(box)
	var title := UITheme.label("Paused", UITheme.ACCENT, UITheme.font_size(1.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_pause_resume = Button.new()
	_pause_resume.text = "Resume"
	_pause_resume.pressed.connect(_close_pause)
	box.add_child(_pause_resume)
	var log_button := Button.new()
	log_button.text = "Battle log"
	log_button.pressed.connect(func() -> void:
		_log.toggle()
		_close_pause())
	box.add_child(log_button)
	var leave := Button.new()
	_pause_leave = leave
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_open_settings)
	box.add_child(settings_button)
	var reaction_help := Button.new()
	reaction_help.text = "Reaction help"
	reaction_help.pressed.connect(_open_combat_help)
	box.add_child(reaction_help)
	leave.text = leave_text if embedded else "Retreat to menu"
	leave.pressed.connect(_retreat)
	box.add_child(leave)
	var buttons: Array[Button] = [_pause_resume, log_button, settings_button, reaction_help, leave]
	for index in buttons.size():
		var button := buttons[index]
		button.custom_minimum_size = Vector2(0, UITheme.control_height())
		button.focus_neighbor_top = button.get_path_to(buttons[wrapi(index - 1, 0, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[wrapi(index + 1, 0, buttons.size())])
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


## CanvasLayer hosts must preserve this local theme when applying the game theme.
func apply_battle_theme() -> void:
	theme = UITheme.build()
	theme.set_color("font_color", "TooltipLabel", Color.TRANSPARENT)
	theme.set_color("font_shadow_color", "TooltipLabel", Color.TRANSPARENT)
	theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())


func _open_combat_help() -> void:
	if is_instance_valid(_combat_help):
		return
	var balance := engine.ctx.balance
	var paragraphs := PackedStringArray([
		"Press a reaction key as the moving ring reaches the inner ring and the marker reaches Impact. The first allowed press locks your choice. Release any held reaction key before the next window. Unavailable reactions do nothing.",
		"%s Brace — A successful brace reduces damage. Status effects can still land. Its wider timing window makes it the safer response." % InputBindings.prompt(InputBindings.BRACE),
		"%s Evade — A successful evade avoids the hit and its status effects. A failed attempt takes %d%% extra damage. Check battlefield conditions: evading on flooded ground makes you Wet." % [InputBindings.prompt(InputBindings.EVADE), roundi((balance.evade_fail_multiplier - 1) * 100)],
		"%s Parry — The narrowest window. Success avoids the hit, staggers the attacker and grants %d Focus. A failed attempt takes %d%% extra damage. Some attacks cannot be parried." % [InputBindings.prompt(InputBindings.PARRY), balance.parry_focus, roundi((balance.parry_fail_multiplier - 1) * 100)],
		"Hover an enemy's intended move before it acts to check the permitted reactions and battlefield effects. Settings offers reaction assists and a pause before each window."
	])
	_combat_help = WorldModal.make(&"help", "Defensive reactions", paragraphs, [WorldDialogueReadout.action(&"back", "Back")])
	_combat_help.cancel_id = &"back"
	_pause_panel.hide()
	_modal.add_child(_combat_help)
	_combat_help.chosen.connect(func(_id: StringName) -> void:
		_combat_help.queue_free()
		_combat_help = null
		_pause_panel.show()
		_pause_resume.grab_focus())


func _open_settings() -> void:
	if is_instance_valid(_settings_screen):
		return
	var screen := load(SceneRouter.SETTINGS).instantiate() as SettingsScreen
	_settings_screen = screen
	screen.embedded = true
	screen.theme = UITheme.build()
	_pause_panel.hide()
	_modal.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.closed.connect(func() -> void:
		_settings_screen = null
		screen.queue_free()
		_pause_panel.show()
		_pause_resume.grab_focus())
