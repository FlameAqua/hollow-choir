class_name BattleScene
extends Control
## Combat presenter. Drives a BattleEngine and renders it; owns no rules.
##
## The engine pauses only at its three input points, each answered here:
##   ACTION_SELECT -> ActionPicker (or the party autopilot)
##   ACTION_COMMAND -> a CommandWidget (or the execution simulator)
##   REACTION -> ReactionWidget (or the execution simulator)
## Everything else arrives as BattleEvents, played back by BattleEventPlayer.
##
## Standalone: SceneRouter hands a BattleLaunch payload. Embedded: the CombatSandbox sets
## [member embedded] before adding the scene and calls start(), restarting by replacing the node.

signal finished(result: BattleResult)
signal restart_requested
signal setup_requested

const TOP_HEIGHT := 60.0
const BOTTOM_HEIGHT := 236.0

## Set by a host (the sandbox) before the node enters the tree.
var embedded := false
var launch: BattleLaunch
var engine: BattleEngine

var _battlefield: Battlefield
var _timeline: TimelineBar
var _toolbar: HBoxContainer
var _party_box: VBoxContainer
var _party_cards: Dictionary[int, PartyCard] = {}
var _menu: ActionMenu
var _menu_placeholder: Label
var _info: PreviewPanel
var _side: SidePanel
var _log: BattleLogPanel
var _overlay: Control
var _banner: Banner
var _modal: Control
var _result_panel: ResultPanel
var _pause_panel: PanelContainer
var _pause_resume: Button
var _events: BattleEventPlayer
var _picker: ActionPicker
var _autopilot: PartyAutopilot
var _executor: ExecutionSimulator
var _hover_uid := -1
var _advanced := false
var _idle_text := ""
var _result: BattleResult


func _ready() -> void:
	_build()
	EventBus.settings_changed.connect(_apply_settings)
	if embedded:
		return
	var payload := SceneRouter.take_payload()
	start(payload as BattleLaunch if payload is BattleLaunch else _default_launch())


## Begins the battle described by [param p_launch]. Call once per instance.
func start(p_launch: BattleLaunch) -> void:
	launch = p_launch
	engine = BattleEngine.new(launch.setup)
	var battle_seed := launch.setup.seed
	_autopilot = PartyAutopilot.new(PartyAutopilot.Policy.SMART, battle_seed + 1)
	_executor = null
	if launch.simulated_execution >= 0:
		var skill := Database.registry.skill(launch.simulated_execution as Enums.SimulatedExecution)
		if skill != null:
			_executor = ExecutionSimulator.new(skill, battle_seed + 2)
	_battlefield.setup(engine, Settings.data.reduce_flashing)
	_timeline.engine = engine
	_side.engine = engine
	_events.setup(engine)
	_events.show_ai_reasons = launch.show_ai_reasoning
	_picker.setup(engine, _menu, _battlefield, _info)
	_build_party_cards()
	_apply_settings()
	_idle_text = _make_idle_text()
	_info.show_text(_idle_text)
	_log.clear_lines()
	_run()


## Adds a button to the top-right toolbar (hosts add Restart / Setup there).
func add_toolbar_button(text: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_toolbar.add_child(button)
	_toolbar.move_child(button, 0)
	_update_timeline_margin.call_deferred()
	return button


func is_running() -> bool:
	return engine != null and not engine.is_finished()


# --- Battle loop ---------------------------------------------------------------------------------

func _run() -> void:
	await _intro()
	while not engine.is_finished():
		engine.advance()
		await _events.play(engine.drain_events())
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
	for condition in setup.conditions:
		lines.append("%s: %s" % [condition.display_name, condition.description])
	await _banner.announce(setup.label if not setup.label.is_empty() else "Battle", "\n".join(lines),
		(1.1 if lines.is_empty() else 1.8) / _events.speed)


func _answer_select(request: ActionSelectRequest) -> void:
	var unit := engine.get_unit(request.unit_uid)
	_menu_placeholder.text = ""
	var choice: ActionChoice
	if launch.autoplay:
		choice = _autopilot.choose(engine, request)
		await _events.wait(0.25)
	else:
		choice = await _picker.choose(request)
	_refresh_info()
	if choice == null or engine.submit_action(choice) != OK:
		push_warning("BattleScene: choice rejected; asking again")


func _answer_command(request: CommandRequest) -> void:
	var actor := request.unit_uid
	var grade: Enums.ExecutionGrade
	_events.windup(actor, 0.25)
	if _executor != null:
		await _events.wait(0.35)
		grade = _executor.grade_command(request.spec, launch.setup.assist)
	else:
		var widget := _make_command_widget(request.spec.type)
		_overlay.add_child(widget)
		# Over the menu/info area so the battlefield (and the target) stay visible.
		var area := Rect2(_menu.get_parent_control().get_global_rect().position, Vector2.ZERO).expand(_info.get_global_rect().end)
		widget.global_position = area.get_center() - widget.size * 0.5
		widget.begin(request.spec, request.choice.action.display_name)
		grade = await widget.finished
		widget.queue_free()
		_events.widget_grade = grade
	engine.submit_command_result(grade)


static func _make_command_widget(type: Enums.ActionCommandType) -> CommandWidget:
	match type:
		Enums.ActionCommandType.HOLD_RELEASE:
			return HoldReleaseWidget.new()
		Enums.ActionCommandType.RHYTHM:
			return RhythmWidget.new()
		Enums.ActionCommandType.OPTIONAL_AIM:
			return AimWidget.new()
	return TimingWidget.new()


func _answer_reaction(request: ReactionRequest) -> void:
	var attacker := engine.get_unit(request.attacker_uid)
	var windup_seconds := request.spec.windup_ms / 1000.0
	var result: ReactionResult
	if _executor != null:
		_events.windup(request.attacker_uid, windup_seconds)
		await _events.wait(windup_seconds)
		result = _executor.react(launch.setup.library.balance, request)
	else:
		var widget := ReactionWidget.new()
		_overlay.add_child(widget)
		widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var points: Array[Vector2] = []
		var to_local := widget.get_global_transform().affine_inverse()
		for uid in request.target_uids:
			points.append(to_local * _battlefield.body_point(uid))
		widget.started.connect(func() -> void: _events.windup(request.attacker_uid, windup_seconds, false))
		widget.begin(request.spec, request.action, points, attacker.display_name if attacker else "?")
		result = await widget.finished
		widget.queue_free()
	engine.submit_reaction(result)


func _finish_battle() -> void:
	_picker.cancel()
	_battlefield.set_active(-1)
	_result = engine.build_result()
	var outcome := engine.get_outcome()
	AudioManager.play(AudioManager.Cue.VICTORY if outcome == Enums.BattleOutcome.VICTORY else AudioManager.Cue.DEFEAT)
	var levels_before := {}
	for enemy_id: StringName in _result.research:
		levels_before[enemy_id] = GameState.research_level(enemy_id)
	if launch.record_progress:
		GameState.record_battle(_result)
	await _banner.announce(EnumText.outcome(outcome), "", 0.9 / _events.speed)
	var color := UITheme.BLOOM if outcome == Enums.BattleOutcome.VICTORY else UITheme.DANGER
	var primary := "Restart" if embedded else "Retry"
	var secondary := "Change setup" if embedded else "Continue"
	_modal.visible = true
	_result_panel.show_result(EnumText.outcome(outcome), color, _result_text(levels_before), primary, secondary)
	finished.emit(_result)


func _result_text(levels_before: Dictionary) -> String:
	var metrics := BattleMetrics.new()
	metrics.consume(engine, _events.history)
	metrics.finalize(engine)
	var lines := PackedStringArray()
	lines.append("[center]%d rounds · seed %d · %s · %s[/center]" % [metrics.rounds, _result.seed,
		launch.setup.difficulty.display_name, launch.setup.assist.display_name])
	lines.append("Damage dealt [b]%d[/b] · taken [b]%d[/b] · healed %d" % [metrics.damage_dealt, metrics.damage_taken, metrics.healing_done])
	lines.append("Breaks %d · Interrupts %d · Weakness hits %d · Potions %d" % [metrics.stagger_breaks, metrics.interrupts,
		metrics.weakness_hits, metrics.potions_used])
	lines.append("Commands: [color=#d8b45a]Perfect %d[/color] · Good %d · Miss %d" % [
		metrics.grades.get(Enums.ExecutionGrade.PERFECT, 0), metrics.grades.get(Enums.ExecutionGrade.GOOD, 0),
		metrics.grades.get(Enums.ExecutionGrade.MISS, 0)])
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
	for enemy_id: StringName in _result.research:
		var enemy: EnemyDefinition = Database.registry.enemies.get(enemy_id)
		var enemy_name := enemy.display_name if enemy != null else String(enemy_id)
		if launch.record_progress:
			var before: int = levels_before.get(enemy_id, 0)
			var after := GameState.research_level(enemy_id)
			var gained := " [color=#c9a3ff]→ %s![/color]" % EnumText.research_level(after) if after > before else ""
			lines.append("Bestiary: %s (%s)%s" % [enemy_name, EnumText.research_level(before as Enums.ResearchLevel), gained])
	if engine.get_outcome() != Enums.BattleOutcome.VICTORY:
		var recap := BattleLogFormatter.defeat_recap(_events.history, engine)
		if not recap.is_empty():
			lines.append("")
			lines.append("[color=#d65a43]%s[/color]" % recap)
	if not launch.record_progress:
		lines.append("[color=#5f5c55]Sandbox: progress not recorded.[/color]")
	return "\n".join(lines)


# --- Input and info panel ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action(InputBindings.INFO) and not event.is_echo():
		_set_advanced(event.is_pressed())
	elif event.is_action_pressed(InputBindings.LOG, false):
		get_viewport().set_input_as_handled()
		_log.toggle()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputBindings.MENU, false) and not \
			(_pause_panel.visible and event.is_action_pressed(InputBindings.CANCEL, false)):
		return
	get_viewport().set_input_as_handled()
	if _pause_panel.visible:
		_close_pause()
	elif _picker.is_active() and not _picker.is_targeting():
		_open_pause()


func _set_advanced(held: bool) -> void:
	var value := held or Settings.data.advanced_tooltips == GameSettings.TooltipMode.ALWAYS
	if value == _advanced:
		return
	_advanced = value
	_picker.advanced = value
	_refresh_info()


func _on_unit_hovered(uid: int) -> void:
	if _picker.is_targeting():
		if uid >= 0:
			_picker.hover(uid)
		return
	_hover_uid = uid
	_refresh_info()


func _refresh_info() -> void:
	if engine == null:
		return
	var hovered := engine.get_unit(_hover_uid)
	if hovered != null:
		_info.show_text(UnitInfo.describe(hovered, engine, _advanced, launch.show_ai_reasoning))
	elif _picker.is_active():
		_picker.render()
	else:
		_info.show_text(_idle_text)


func _make_idle_text() -> String:
	return ("[color=#9b978b]Hover a unit or an intent for details. Hold %s for the full analysis. %s shows the " +
		"battle log.\nReactions: %s Brace · %s Evade · %s Parry. Action commands: %s.[/color]") % [
		InputBindings.key_label(InputBindings.INFO), InputBindings.key_label(InputBindings.LOG),
		InputBindings.key_label(InputBindings.BRACE), InputBindings.key_label(InputBindings.EVADE),
		InputBindings.key_label(InputBindings.PARRY), InputBindings.key_label(InputBindings.COMMAND)]


func _refresh_hud() -> void:
	_timeline.refresh()
	if not _picker.is_active():
		var actor := engine.get_unit(_timeline.acting_uid)
		_menu_placeholder.text = "%s acts…" % actor.display_name if actor != null else ""
	_side.familiar_fired_round = _events.familiar_fired_round
	_side.refresh()
	for uid: int in _party_cards:
		var card := _party_cards[uid]
		card.active = _timeline.acting_uid == uid
		card.refresh()
	if _hover_uid >= 0:
		_refresh_info()


func _apply_settings() -> void:
	_events.speed = clampf(Settings.data.combat_speed, 0.5, 2.0)
	_events.show_numbers = Settings.data.show_damage_numbers
	_battlefield.screen_shake = Settings.data.screen_shake
	for view: UnitView in _battlefield.views.values():
		view.reduce_flashing = Settings.data.reduce_flashing
	_set_advanced(Input.is_action_pressed(InputBindings.INFO))


# --- Pause / result actions ----------------------------------------------------------------------

func _open_pause() -> void:
	AudioManager.play(AudioManager.Cue.UI_CANCEL)
	get_viewport().gui_release_focus()
	_modal.visible = true
	_pause_panel.visible = true
	_pause_panel.reset_size()
	_pause_panel.position = (_modal.size - _pause_panel.size) * 0.5
	_pause_resume.grab_focus()


func _close_pause() -> void:
	_pause_panel.visible = false
	_modal.visible = false
	if _picker.is_active():
		_menu.refocus()


func _retreat() -> void:
	if embedded:
		setup_requested.emit()
	else:
		SceneRouter.goto(launch.return_scene if not launch.return_scene.is_empty() else SceneRouter.MAIN_MENU)


func _on_result_primary() -> void:
	if embedded:
		restart_requested.emit()
		return
	# Retry: same fight, next seed.
	var retry := BattleLaunch.make(launch.setup, launch.return_scene)
	retry.setup.seed += 1
	retry.record_progress = launch.record_progress
	SceneRouter.goto(SceneRouter.BATTLE, retry)


func _on_result_secondary() -> void:
	if embedded:
		setup_requested.emit()
	else:
		SceneRouter.goto(launch.return_scene if not launch.return_scene.is_empty() else SceneRouter.MAIN_MENU)


## Opened directly (F6 in the editor): the toy fight with the saved loadout and current settings.
func _default_launch() -> BattleLaunch:
	var encounter := Database.registry.defaults.practice_encounter
	var setup := BattleSetup.from_encounter(GameState.build_loadout(), encounter, Database.library,
		Settings.difficulty_profile(), Settings.assist_profile(), randi() % 100000)
	setup.research_levels = GameState.research_levels()
	var default_launch := BattleLaunch.make(setup, SceneRouter.MAIN_MENU)
	default_launch.record_progress = false
	return default_launch


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battlefield.offset_top = TOP_HEIGHT
	_battlefield.offset_bottom = -BOTTOM_HEIGHT
	_battlefield.unit_hovered.connect(_on_unit_hovered)
	_battlefield.unit_clicked.connect(func(uid: int) -> void: _picker.click(uid))

	_timeline = TimelineBar.new()
	_timeline.name = "Timeline"
	add_child(_timeline)
	_timeline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timeline.offset_bottom = TOP_HEIGHT

	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	add_child(_toolbar)
	_toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toolbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toolbar.offset_top = 14.0
	_toolbar.offset_right = -10.0
	_toolbar.resized.connect(_update_timeline_margin)
	var log_button := Button.new()
	log_button.text = "Log [%s]" % InputBindings.key_label(InputBindings.LOG)
	log_button.focus_mode = Control.FOCUS_NONE
	log_button.pressed.connect(func() -> void: _log.toggle())
	_toolbar.add_child(log_button)
	var menu_button := Button.new()
	menu_button.text = "Menu"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.tooltip_text = "Pause (available while choosing an action)"
	menu_button.pressed.connect(func() -> void:
		if _picker.is_active() and not _picker.is_targeting():
			_open_pause())
	_toolbar.add_child(menu_button)

	var bottom := PanelContainer.new()
	bottom.name = "Hud"
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bottom.add_child(row)
	_party_box = VBoxContainer.new()
	_party_box.custom_minimum_size = Vector2(290, 0)
	row.add_child(_party_box)
	var menu_holder := Control.new()
	menu_holder.custom_minimum_size = Vector2(285, 0)
	row.add_child(menu_holder)
	_menu_placeholder = Label.new()
	_menu_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_placeholder.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	menu_holder.add_child(_menu_placeholder)
	_menu = ActionMenu.new()
	_menu.name = "ActionMenu"
	menu_holder.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	_info = PreviewPanel.new()
	_info.name = "Info"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info)
	_side = SidePanel.new()
	_side.name = "SidePanel"
	_side.custom_minimum_size = Vector2(320, 0)
	row.add_child(_side)

	_log = BattleLogPanel.new()
	_log.name = "Log"
	add_child(_log)
	_log.anchor_left = 1.0
	_log.anchor_right = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_left = -440.0
	_log.offset_right = -8.0
	_log.offset_top = TOP_HEIGHT + 8.0
	_log.offset_bottom = -BOTTOM_HEIGHT - 8.0
	_log.visible = false

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner = Banner.new()
	_banner.name = "Banner"
	_overlay.add_child(_banner)

	_modal = Control.new()
	_modal.name = "Modal"
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
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
	_events.overlay = _overlay
	_events.banner = _banner
	add_child(_events)
	_events.log_line.connect(func(line: String) -> void: _log.append(line))
	_events.hud_changed.connect(_refresh_hud)

	_picker = ActionPicker.new()
	_picker.name = "ActionPicker"
	add_child(_picker)


func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "Pause"
	_pause_panel.visible = false
	_modal.add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.add_theme_font_size_override("font_size", UITheme.font_size(1.4))
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
	leave.text = "Back to setup" if embedded else "Retreat to menu"
	leave.pressed.connect(func() -> void:
		_close_pause()
		_retreat())
	box.add_child(leave)
	var buttons: Array[Button] = [_pause_resume, log_button, leave]
	for index in buttons.size():
		var button := buttons[index]
		button.custom_minimum_size = Vector2(0, 34)
		button.focus_neighbor_top = button.get_path_to(buttons[wrapi(index - 1, 0, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[wrapi(index + 1, 0, buttons.size())])
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


func _build_party_cards() -> void:
	for child in _party_box.get_children():
		child.queue_free()
	_party_cards.clear()
	for unit in engine.get_state().party(false):
		var card := PartyCard.new()
		card.unit = unit
		card.mouse_entered.connect(func() -> void: _on_unit_hovered(unit.uid))
		card.mouse_exited.connect(func() -> void: _on_unit_hovered(-1))
		_party_box.add_child(card)
		_party_cards[unit.uid] = card


func _update_timeline_margin() -> void:
	if _timeline != null and _toolbar != null:
		_timeline.reserved_right = _toolbar.size.x + 16.0
		_timeline.refresh()
