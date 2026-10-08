extends Node
## Runtime half of tools/capture_battle.gd (loaded after the autoloads exist, like the test suites,
## so it can use the game's classes directly). See that file for usage.

const BATTLE := "res://scenes/battle/battle_scene.tscn"
const SANDBOX := "res://scenes/sandbox/combat_sandbox.tscn"
const TIMEOUT_MS := 90000

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var dims := String(_args.get("size", "1280x720")).split("x")
	var window_size := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(window_size)
	get_tree().root.size = window_size
	Settings.data.text_scale = float(_args.get("scale", "1.0"))
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.HOLD
	if _args.has("reduced"):
		Settings.data.reduce_motion = true
		Settings.data.reduce_flashing = true
		Settings.data.screen_shake = false
	Settings.apply()
	await _frames(3)
	var state: String = _args.get("state", "planning")
	if state in ["practice", "lab"]:
		await _capture_sandbox(state)
	else:
		await _capture_battle(state)
	get_tree().quit()


func _capture_sandbox(state: String) -> void:
	var sandbox: CombatSandbox = load(SANDBOX).instantiate()
	get_tree().root.add_child(sandbox)
	await _frames(4)
	sandbox.show_view(CombatSandbox.View.LAB if state == "lab" else CombatSandbox.View.PRACTICE)
	await _frames(6)
	_save()


func _capture_battle(state: String) -> void:
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
	var scene: BattleScene = load(BATTLE).instantiate()
	scene.embedded = true
	scene.use_art = not _args.has("no-art")
	get_tree().root.add_child(scene)
	scene.add_toolbar_button("Setup", "", func() -> void: pass)
	scene.add_toolbar_button("Restart", "", func() -> void: pass)
	if state == "result":
		Engine.time_scale = 8.0
	scene.start(launch)
	match state:
		"planning", "details", "target":
			await _wait_input(scene, "planning")
			await _frames(20)
			if state == "details":
				scene._set_details(true)
			elif state == "target":
				var first := scene._menu._buttons[0]
				first.pressed.emit()
			await _frames(12)
		"command":
			await _wait_input(scene, "command")
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
	_save()


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
				# Hidden capture windows may have no OS focus. Explicit synthetic
				# input is part of this harness, never the interactive game path.
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


func _reaction(scene: BattleScene) -> ReactionWidget:
	for child in scene._overlay.get_children():
		if child is ReactionWidget:
			return child
	return null


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


func _seconds(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame
