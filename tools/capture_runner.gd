extends Node
## Runtime half of tools/capture_battle.gd (loaded after the autoloads exist, like the test suites,
## so it can use the game's classes directly). See that file for usage.
##
## Capture fixtures, not gameplay evidence: to hold one moment for a screenshot this harness pauses
## presentation tweens, freezes or back-dates widget clocks, answers intervening requests through
## their own widgets and supplies synthetic pointer and window-focus input. It never changes timing
## specifications, rules, art, settings files or saves.

const BATTLE := "res://scenes/battle/battle_scene.tscn"
const SANDBOX := "res://scenes/sandbox/combat_sandbox.tscn"
const SETTINGS := "res://scenes/main/settings_screen.tscn"
const TIMEOUT_MS := 90000
const QA_USER_DATA := preload("res://tools/qa_user_data.gd")

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _process(_delta: float) -> void:
	# A hidden capture window has no OS focus, so the preparation beat would wait for it forever.
	var scene := _battle()
	if scene != null and scene._preparing and not scene._window_focused:
		scene._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)


func _run() -> void:
	if not QA_USER_DATA.check():
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var dims := String(_args.get("size", "1280x720")).split("x")
	var window_size := Vector2i(int(dims[0]), int(dims[1]))
	if not GameSettings.RESOLUTIONS.has(window_size):
		push_error("Capture size must be a supported game resolution preset")
		get_tree().quit(1)
		return
	Settings.data.window_resolution = window_size
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.HOLD
	if _args.has("reduced"):
		Settings.data.reduce_motion = true
		Settings.data.reduce_flashing = true
		Settings.data.screen_shake = false
	Settings.apply()
	await _frames(3)
	var state: String = _args.get("state", "planning")
	match state:
		"practice", "practice-dropdown", "lab":
			await _capture_sandbox(state)
		"title":
			var menu := load(SceneRouter.MAIN_MENU).instantiate() as MainMenu
			get_tree().root.add_child(menu)
			await _frames(10)
			print("TITLE panel=", menu._menu_panel.get_global_rect(), " minimum=", menu._menu_panel.get_combined_minimum_size(), " column=", menu._column.get_combined_minimum_size())
			_save()
		"settings":
			await _capture_settings()
		"field-guide", "field-guide-empty", "weapon-practice":
			await _capture_field_guide(state)
		"audio-lab":
			await _capture_audio_lab()
		"setup", "resumed":
			await _capture_setup(state == "resumed")
		"opening", "opening-condition":
			await _capture_opening(state == "opening-condition")
		_:
			await _capture_battle(state)
	# Release every cue voice and music deck before shutdown so the audio server drops their playbacks.
	AudioManager.silence()
	await _frames(3)
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


# --- Pages ---------------------------------------------------------------------------------------

func _capture_audio_lab() -> void:
	var lab: AudioLab = load(SceneRouter.AUDIO_LAB).instantiate()
	get_tree().root.add_child(lab)
	await _frames(10)
	for index in lab._playlists.size():
		if lab._playlists[index].cue_id == &"briarfen_battle":
			lab._cues.select(index)
			lab._cues.item_selected.emit(index)
	for index in lab._tracks.size():
		if lab._tracks[index].id == &"briarfen_battle_v01_intense":
			lab._versions.select(index)
			lab._versions.item_selected.emit(index)
	await _frames(10)
	AudioManager.music.seek(45.0)
	if _args.has("preview-ending"):
		lab._preview_ending()
	lab._scroll.scroll_vertical = 0
	if _args.has("audio-controls"):
		lab._scroll.ensure_control_visible(lab._position)
	await _frames(3)
	_save()

func _capture_field_guide(state: String) -> void:
	GameState.resume_session()
	GameState.progress = ProgressState.new()
	if state != "field-guide-empty":
		GameState.progress.bestiary.add(&"thornhound", Enums.ResearchSource.INSPECT, 18)
		GameState.progress.bestiary.add(&"bogshell", Enums.ResearchSource.ENCOUNTER, 1)
		GameState.progress.weapon_mastery[&"pilgrims_edge"] = 12
	var guide: FieldGuide = load(SceneRouter.FIELD_GUIDE).instantiate()
	get_tree().root.add_child(guide)
	await _frames(10)
	if state == "weapon-practice":
		guide._tabs.current_tab = 1
	elif state == "field-guide":
		guide._choices.select(1)
		guide._select(1)
	await _frames(8)
	_save()

func _capture_sandbox(state: String) -> void:
	var sandbox: CombatSandbox = load(SANDBOX).instantiate()
	get_tree().root.add_child(sandbox)
	await _frames(4)
	sandbox.show_view(CombatSandbox.View.LAB if state == "lab" else CombatSandbox.View.PRACTICE)
	await _frames(6)
	if state == "practice-dropdown":
		sandbox._practice_encounter.show_popup()
		await _frames(6)
	_save()


func _capture_settings() -> void:
	var screen: SettingsScreen = load(SETTINGS).instantiate()
	get_tree().root.add_child(screen)
	screen._tabs.current_tab = int(_args.get("tab", "1"))
	await _frames(12)
	_save()


## Setup exclusively covers a paused battle; "resumed" closes it again and shows the live battle.
func _capture_setup(resumed: bool) -> void:
	var sandbox: CombatSandbox = load(SANDBOX).instantiate()
	get_tree().root.add_child(sandbox)
	await _frames(4)
	Engine.time_scale = 8.0
	sandbox._launch(_make_launch("planning"), "Retry same setup", "Change setup")
	var scene := sandbox._battle
	await _wait_input(scene, "planning")
	Engine.time_scale = 1.0
	await _frames(12)
	sandbox._toggle_setup()
	await _frames(8)
	if resumed:
		sandbox._show_setup(false)
		await _frames(8)
	print("SETUP visible %s · battle paused %s · battle input %s · pause box %s · picker active %s" % [sandbox._setup.visible,
		scene.is_paused(), scene.process_mode != Node.PROCESS_MODE_DISABLED, scene._pause_panel.visible, scene._picker.is_active()])
	_save()


## The opening encounter banner (or its Flooded Ground condition card), held fully faded in, with
## the pointer deliberately over an ally: no inspection card may cover the announcement.
func _capture_opening(condition: bool) -> void:
	var registry := Database.registry
	var encounter: EncounterDefinition = registry.encounters[&"toy_training"].duplicate()
	encounter.conditions.append(registry.conditions[&"flooded_ground"])
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_bow"], encounter, Database.library,
		registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	setup.label = "Custom"
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	var scene: BattleScene = load(BATTLE).instantiate()
	scene.embedded = true
	get_tree().root.add_child(scene)
	scene.start(launch)
	await _until(func() -> bool: return scene._banner.visible and scene._banner.modulate.a > 0.98)
	if condition:
		await _until(func() -> bool: return scene._banner._title.text == "Flooded Ground" and scene._banner.modulate.a > 0.98)
	scene._banner._tween.pause()
	_move(scene._battlefield.body_point(scene.engine.get_state().party()[0].uid))
	await _frames(10)
	print("OPENING panel %s · title %s · inspector visible %s" % [scene._banner._panel.get_global_rect(),
		scene._banner._title.text, scene._inspector.visible])
	_save()


# --- Battle states -------------------------------------------------------------------------------

func _capture_battle(state: String) -> void:
	var scene: BattleScene = load(BATTLE).instantiate()
	scene.embedded = true
	scene.use_art = not _args.has("no-art")
	get_tree().root.add_child(scene)
	scene.add_toolbar_button("Setup", "", func() -> void: pass)
	scene.add_toolbar_button("Restart", "", func() -> void: pass)
	Engine.time_scale = 8.0
	scene.start(_make_launch(state))
	match state:
		"planning", "details", "target", "log", "reaction-help":
			await _wait_input(scene, "planning")
			# Capture-only navigation to a requested actor: consume Guard through real requests.
			if _args.has("actor"):
				for turn in 8:
					if scene._picker.acting_unit().definition.id == StringName(_args.actor):
						break
					_choose(scene, "guard")
					await _frames(3)
					await _wait_input(scene, "planning")
			Engine.time_scale = 1.0
			await _frames(20)
			if state == "details":
				scene._set_details(true)
			elif state == "target":
				_choose(scene, String(_args.get("action", "")))
				if _args.has("then"):
					# Third playtest: choose another action while the first recipient is under review.
					await _frames(6)
					_choose(scene, String(_args.then))
			await _frames(12)
			if state == "log":
				for i in 50:
					scene._log.append("Round %d · The Bell Crow keeps watch." % (i + 1))
				scene._log.show()
				await _frames(4)
				var point := scene._log._scroll.get_global_rect().get_center()
				var wheel := InputEventMouseButton.new()
				wheel.position = point
				wheel.pressed = true
				wheel.button_index = MOUSE_BUTTON_WHEEL_UP
				get_viewport().push_input(wheel, true)
				await _frames(3)
				print("LOG history offset ", scene._log._scroll.scroll_vertical)
			elif state == "reaction-help":
				scene._open_pause()
				scene._open_combat_help()
				await _frames(8)
			if _args.has("inspect-action"):
				await _inspect_action(scene, StringName(_args["inspect-action"]))
			elif _args.has("hover"):
				await _hover(scene, String(_args.hover))
			elif state == "target":
				print("TARGET %s · reviewing %d · inspector visible %s" % [scene._target_prompt.text,
					scene._picker.reviewed_target_uid(), scene._inspector.visible])
		"prepare-command", "prepare-reaction":
			await _wait_input(scene, "planning")
			await _hold_preparation(scene, state == "prepare-reaction")
		"command":
			await _wait_input(scene, "command")
			Engine.time_scale = 1.0
			for child in scene._timed_host.get_children():
				if child is CommandWidget:
					child._focus_lost = false
					child.clock.resume()
					child.clock.set_elapsed(child.spec.target_time_ms() - 25)
					child.set_process(false)
					child.queue_redraw()
			await _frames(3)
		"reaction", "pause-before":
			await _wait_input(scene, "reaction")
			Engine.time_scale = 1.0
			var widget := _reaction(scene)
			if widget != null and state == "reaction":
				widget.clock.set_elapsed(widget.impact_ms() - 30)
				widget.set_process(false)
				widget._refresh_cards()
				widget.queue_redraw()
				widget._meter_space.queue_redraw()
			await _frames(3)
		"result":
			await _until(func() -> bool: return scene._result_panel.visible)
			Engine.time_scale = 1.0
			await _frames(10)
		"condition-card", "condition-flight":
			await _wait_input(scene, "planning")
			Engine.time_scale = 1.0
			await _hold_condition_card(scene, state == "condition-flight")
	if _args.has("dwell"):
		await get_tree().create_timer(float(_args.dwell)).timeout
	if _args.has("broken"):
		# Presentation-only fixture for the status placement, never a fabricated combat result.
		var uid := scene.engine.get_state().enemies()[0].uid
		scene._events.ledger.unit(uid).broken = true
		scene._rail.slot(uid).show_state(IntentSlot.State.BROKEN)
		scene._battlefield.view(uid).queue_redraw()
		scene._timeline.queue_redraw()
		await _frames(3)
	_save()


func _make_launch(state: String) -> BattleLaunch:
	var registry := Database.registry
	var encounter: EncounterDefinition = registry.encounters.get(StringName(_args.get("encounter", "fen_patrol")))
	if _args.has("enemies"):
		encounter = EncounterDefinition.new()
		encounter.id = &"capture"
		encounter.display_name = "Capture"
		for id in String(_args.enemies).split(","):
			encounter.enemies.append(registry.enemies[StringName(id)])
		if _args.has("condition"):
			encounter.conditions.append(registry.conditions[StringName(_args.condition)])
	var assist := registry.assist(Enums.ExecutionAssist.get(String(_args.get("assist", "STANDARD")).to_upper()))
	var setup := BattleSetup.from_encounter(registry.loadouts[StringName(_args.get("loadout", "starter_sword"))], encounter,
		Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), Settings.data.resolve_assist(assist),
		int(_args.get("seed", "3")))
	var knowledge: int = Enums.ResearchLevel.get(String(_args.get("knowledge", "UNKNOWN")).to_upper())
	for enemy in encounter.enemies:
		setup.research_levels[enemy.id] = knowledge
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.autoplay = state in ["command", "reaction", "pause-before", "result"]
	launch.simulated_execution = Enums.SimulatedExecution.GOOD if state == "result" else -1
	return launch


## Presses [param id]'s button (or the first legal targeted action) to open recipient review.
func _choose(scene: BattleScene, id: String) -> void:
	for button in scene._menu._buttons:
		var option: ActionOption = button.get_meta(&"option")
		if option.legal and (option.action.id == StringName(id) if not id.is_empty() else option.action.needs_target_choice()):
			button.pressed.emit()
			return
	push_error("Capture: no legal action to review a target with: " + id)


## Commits an action, then holds the actual command meter or reaction ring/cards inside the 400 ms
## preparation beat (the scene's preparation tween is paused for the capture only).
func _hold_preparation(scene: BattleScene, reaction: bool) -> void:
	scene._executor = null
	scene.launch.autoplay = reaction
	Engine.time_scale = 8.0
	for button in scene._menu._buttons:
		var option: ActionOption = button.get_meta(&"option")
		if option.legal and ((reaction and option.action.id == &"guard") or (not reaction and option.action.deals_damage())):
			button.pressed.emit()
			if scene._picker.is_targeting():
				scene._picker.click(scene._picker.reviewed_target_uid())
			break
	var wanted := BattleRequest.Kind.REACTION if reaction else BattleRequest.Kind.ACTION_COMMAND
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		var request := scene.engine.get_request()
		if scene._preparing and request != null and request.kind == wanted:
			scene._preparation_tween.pause()
			Engine.time_scale = 1.0
			await _frames(4)
			var widget: Variant = _reaction(scene) if reaction else scene._timed_host.get_child(0)
			print("PREPARATION %s · widget preparing %s · elapsed %.1f ms · idle panel %s" % ["reaction" if reaction else "command",
				widget.is_preparing(), widget.elapsed_ms(), scene._idle.visible])
			return
		for child in scene._timed_host.get_children():
			if child is CommandWidget and not child.is_preparing() and not child.is_done():
				child._finish(Enums.ExecutionGrade.GOOD)
		await get_tree().process_frame
	push_error("Capture did not reach preparation: " + ("reaction" if reaction else "command"))


func _hold_condition_card(scene: BattleScene, flight: bool) -> void:
	var definition: BattlefieldConditionDefinition = Database.registry.conditions[StringName(_args.get("condition", "flooded_ground"))]
	scene._banner.announce_condition(definition, 1.0, _args.has("reduced"))
	if flight:
		await _until(func() -> bool: return scene._banner.flying)
		await get_tree().create_timer(0.18).timeout
	else:
		await get_tree().create_timer(0.3).timeout
	scene._banner._tween.pause()
	print("CONDITION %s · flying %s · scale %s" % [definition.display_name, scene._banner.flying, scene._banner.scale])


# --- Inspection ----------------------------------------------------------------------------------

## Hovers an action or supply button through real pointer input (optionally Alt-expanded).
func _inspect_action(scene: BattleScene, id: StringName) -> void:
	for button in scene._menu._buttons:
		var option: ActionOption = button.get_meta(&"option")
		if option.action.id != id:
			continue
		if scene._menu._supply_scroll.is_ancestor_of(button):
			scene._menu._supply_scroll.ensure_control_visible(button)
		await _frames(3)
		_move(button.get_global_rect().get_center())
		await _frames(12)
		await _expand(scene)
		print("INSPECT %s · card visible %s · expanded %s" % [id, scene._inspector._card.visible, scene._inspector.expanded])
		return
	push_error("Capture: no action button for " + String(id))


## Hovers the first enemy body, its move icon, the first action or the Supplies column.
func _hover(scene: BattleScene, what: String) -> void:
	var enemy := scene.engine.get_state().enemies()[0]
	var point := scene._battlefield.body_point(enemy.uid)
	match what:
		"intent":
			point = scene._rail.slot(enemy.uid).global_position + Vector2(41, 15)
		"action":
			point = scene._menu._buttons[0].get_global_rect().get_center()
		"supply":
			point = scene._supplies.get_global_rect().get_center()
	_move(point)
	await _frames(12)
	await _expand(scene)
	print("HOVER %s · inspector %s visible %s · dock %s" % [what, scene._inspector.get_global_rect(), scene._inspector.visible,
		scene._info.get_global_rect()])


func _expand(scene: BattleScene) -> void:
	if _args.has("expanded"):
		Input.action_press(InputBindings.INFO)
		scene._set_details(true)
		await _frames(12)


# --- Helpers -------------------------------------------------------------------------------------

## Answer intervening input through its widget so any encounter can reach the
## requested review state. The selected widget itself stays interactive/unanswered.
func _wait_input(scene: BattleScene, wanted: String) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < TIMEOUT_MS:
		if wanted == "planning" and scene._picker.is_active():
			return
		var reaction := _reaction(scene)
		if reaction != null and not reaction.is_preparing():
			if wanted == "reaction":
				return
			if not reaction.is_done():
				reaction._focus_lost = false
				reaction.clock.resume()
				if reaction.is_waiting_for_start():
					reaction._start()
				reaction.clock.set_elapsed(reaction.impact_ms())
				for type in ReactionReadout.REACTIONS:
					if reaction.spec.is_allowed(type):
						var event := InputEventAction.new()
						event.action = ReactionReadout.KEYS[type]
						event.pressed = true
						reaction._input(event)
						break
		for child in scene._timed_host.get_children():
			if child is CommandWidget and not child.is_preparing():
				if wanted == "command":
					return
				if not child.is_done():
					child._finish(Enums.ExecutionGrade.GOOD)
		await get_tree().process_frame
	push_error("Capture did not reach requested input: " + wanted)


func _battle() -> BattleScene:
	for child in get_tree().root.get_children():
		if child is BattleScene:
			return child
		if child is CombatSandbox and child._battle != null:
			return child._battle
	return null


func _reaction(scene: BattleScene) -> ReactionWidget:
	for child in scene._overlay.get_children():
		if child is ReactionWidget:
			return child
	return null


func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2.ONE
	get_tree().root.push_input(motion, true)


func _save() -> void:
	var out: String = _args.get("out", "user://capture.png")
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := get_tree().root.get_texture().get_image()
	var err := image.save_png(path)
	print("%s %s (%dx%d)" % ["saved" if err == OK else "FAILED", path, image.get_width(), image.get_height()])


func _until(condition: Callable) -> void:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
