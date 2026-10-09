extends Node
## Runtime half of tools/capture_world.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")

var _args := {}
var _host: WorldHost


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	if not QA_USER_DATA.check():
		get_tree().quit(1)
		return
	var dims := String(_args.get("size", "1280x720")).split("x")
	var window_size := Vector2i(int(dims[0]), int(dims[1]))
	if not GameSettings.RESOLUTIONS.has(window_size):
		push_error("Capture size must be a supported game resolution preset")
		get_tree().quit(1)
		return
	Settings.data.window_resolution = window_size
	Settings.apply()
	var state: String = _args.get("state", "town")
	GameState._session_resumed = true
	GameState.new_game()
	if state == "bench-hammer":
		GameState.progress.loadout_weapon = &"mire_maul"
	elif state == "bench-bow":
		GameState.progress.loadout_weapon = &"reedbow"
	var world := GameState.progress.world
	match state:
		"town-restored":
			world.cleared.append_array([&"bell_guard"])
			world.wayside_bell_restored = true
			world.return_latch_open = true
		"route", "encounter", "latch", "patrol", "guard", "guard-approach", "victory", "defeat", "save-failed":
			world.area = &"briarfen_reedway"
			world.anchor = &"reedway_fork" if state != "latch" else &"return_latch"
		"map", "map-full", "map-restored":
			world.area = &"briarfen_reedway"
			world.anchor = &"bell_guard"
			for id in [&"reedway_entry", &"reedway_fork", &"reedway_patrol", &"bell_guard", &"wayside_bell"]:
				world.discover(id)
			for id in [&"entry_fork", &"main_approach", &"bell_steps"]:
				world.add_link(id)
			world.cleared.append(&"reedway_patrol")
			if state != "map":
				for landmark in WorldDefinition.load_default().area(&"briarfen_reedway").landmarks:
					world.discover(landmark.id)
				for path in WorldDefinition.load_default().area(&"briarfen_reedway").paths:
					world.add_link(path.id)
			if state == "map-restored":
				world.cleared.append(&"bell_guard")
				world.wayside_bell_restored = true
				world.return_latch_open = true
	# Graybox evidence: the painted Collision layer plus every footprint/barrier shape.
	get_tree().debug_collisions_hint = state == "collision"
	_host = WorldHost.new()
	_host.pause_on_focus_loss = false
	_host.show_collision = state == "collision"
	_host.session = WorldSession.new(WorldDefinition.load_default(), func(_candidate: ProgressState) -> Error: return OK, 11)
	get_tree().root.add_child(_host)
	await _frames(4)
	var area := _host.area
	match state:
		"town":
			_host.player.place(area.anchor(&"town_bell") + Vector2(-120, -40), &"west")
		"collision", "gate":
			_host.player.place(area.anchor(&"reed_gate") + Vector2(-40, 0), &"east")
		"facades":
			_host.player.place(Vector2(700, 640), &"west")
		"town-restored":
			_host.player.place(area.anchor(&"town_bell") + Vector2(-120, -40), &"west")
		"dialogue":
			_host.player.place(area.point(&"bellkeeper") + Vector2(0, 34), &"north")
			await _frames(2)
			_host.interact()
			if _args.has("revealed"):
				_host.modal.reveal_dialogue()
				for i in 60:
					_host.modal._process(1.0 / 60.0)
		"bench", "bench-hammer", "bench-bow":
			_host.player.place(area.point(&"preparation_bench") + Vector2(0, 30), &"north")
			await _frames(2)
			_host.interact()
			if state != "bench":
				WorldModal.focus_later(_host.modal.find_child("Weapon_" + String(GameState.progress.loadout_weapon), true, false) as Button)
		"route":
			_host.player.place(area.anchor(&"reedway_fork") + Vector2(0, -96), &"north")
		"patrol":
			_host.player.place(area.point(&"reedway_patrol") + Vector2(0, 110), &"north")
		"encounter":
			_host.player.place(area.anchor(&"reedway_patrol"), &"north")
			await _frames(2)
			_host.open_encounter_card(WorldDefinition.load_default().find_landmark(&"reedway_patrol")[1])
		"guard-approach":
			_host.player.place(Vector2(1936, 816), &"north")
		"guard":
			_host.player.place(area.anchor(&"bell_guard"), &"north")
			_host.open_encounter_card(WorldDefinition.load_default().find_landmark(&"bell_guard")[1])
		"map", "map-full", "map-restored":
			_host.open_map()
			if state != "map":
				WorldModal.focus_later(_host.modal.find_child("Place5", true, false) as Button)
		"menu":
			_host.open_menu()
		"reset":
			_host.open_menu()
			_host.modal.button(&"reset").pressed.emit()
		"latch":
			_host.player.place(area.anchor(&"return_latch"), &"south")
		"battle":
			_host.load_area(&"briarfen_reedway", &"reedway_patrol")
			_host.engage(WorldDefinition.load_default().find_landmark(&"reedway_patrol")[1])
			# Capture fixture only: answer any enemy-first reaction to reach manual planning.
			_host.battle._executor = ExecutionSimulator.new(Database.registry.skill(Enums.SimulatedExecution.GOOD), 11)
			for frame in 1800:
				await get_tree().process_frame
				if _host.battle._picker.is_active():
					break
		"victory", "defeat", "save-failed":
			# Outcome UI fixture over the world: capture a real entry without launching an async
			# presenter and then interrupting it with a fabricated result during its opening banner.
			var entry := _host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
			var result := BattleResult.new()
			result.outcome = Enums.BattleOutcome.DEFEAT if state == "defeat" else Enums.BattleOutcome.VICTORY
			if state != "defeat":
				result.research[&"thornhound"] = PackedInt32Array([Enums.ResearchSource.ENCOUNTER])
				result.weapon_uses[GameState.progress.loadout_weapon] = 3
			if state == "save-failed":
				_host.session.writer = func(_candidate: ProgressState) -> Error: return ERR_FILE_CANT_WRITE
			_host._on_battle_finished(entry, result)
	await _frames(12)
	_save()
	# Resolve synthetic outcomes in memory before teardown, releasing retained retry/result closures.
	if state == "save-failed":
		_host.session.writer = func(_candidate: ProgressState) -> Error: return OK
		_host.modal.chosen.emit(&"retry")
	elif state == "defeat":
		_host.modal.chosen.emit(&"home")
	# Dispose the live battle/result connections before exiting a synthetic outcome fixture.
	_host._dismiss_modal()
	_host._close_battle()
	_host.queue_free()
	# Release every cue voice and music deck so the audio server drops their playbacks before exit.
	AudioManager.silence()
	await _frames(3)
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func _save() -> void:
	var out: String = _args.get("out", "user://world_capture.png")
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := get_tree().root.get_texture().get_image()
	var err := image.save_png(path)
	print("%s %s (%dx%d)" % ["saved" if err == OK else "FAILED", path, image.get_width(), image.get_height()])


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame
