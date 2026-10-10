extends Node
## Runtime half of tools/capture_world.gd (loaded once the autoloads exist). See that file.

const QA_USER_DATA := preload("res://tools/qa_user_data.gd")

var _args := {}
var _host: WorldHost
var _writes := 0


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
	if state.begins_with("forge") or state.begins_with("stillroom"):
		GameState.progress.materials[&"bog_iron"] = 5
		GameState.progress.materials[&"storm_salt"] = 1
		if state != "forge-locked":
			GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
	if state.begins_with("explore-"):
		world.area = &"briarfen_reedway"
		world.anchor = &"listening_stones"
	if state in ["revision-countdown", "revision-cancelled", "revision-quest"]:
		world.area = &"briarfen_reedway"
		world.anchor = &"reedway_fork"
		if state == "revision-quest": world.cleared.append(&"bell_guard")
	match state:
		"town-restored":
			world.cleared.append_array([&"bell_guard"])
			world.wayside_bell_restored = true
			world.return_latch_open = true
		"catch-up":
			world.cleared.append_array([&"reedway_patrol", &"bell_guard"])
			world.wayside_bell_restored = true
		"charm-reward":
			world.area = &"briarfen_reedway"
			world.anchor = &"wayside_bell"
			world.cleared.append(&"bell_guard")
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
	# Fixture-only inventory. Production rewards are exercised by charm-reward, catch-up and victory.
	if state in ["bench-charm", "inventory", "encounter-claimed"]:
		GameState.progress.owned_equipment.append(&"storm_salt_charm")
		GameState.progress.materials[&"bog_iron"] = 4
		GameState.progress.materials[&"storm_salt"] = 1
		GameState.progress.reward_claims.assign([&"first_footsteps.guard", &"first_footsteps.patrol", &"first_footsteps.restoration"])
	# Other captures predate catch-up feedback and should keep showing their requested scene.
	if state != "catch-up":
		RewardRules.grant(GameState.progress, RewardRules.catch_up(GameState.progress, Database.registry))
	# Graybox evidence: the painted Collision layer plus every footprint/barrier shape.
	get_tree().debug_collisions_hint = state == "collision"
	_host = WorldHost.new()
	_host.pause_on_focus_loss = false
	_host.show_collision = state == "collision"
	_host.session = WorldSession.new(WorldDefinition.load_default(), func(_candidate: ProgressState) -> Error:
		_writes += 1
		return OK, 11)
	get_tree().root.add_child(_host)
	await _frames(4)
	var area := _host.area
	match state:
		"revision-countdown", "revision-cancelled":
			# Real host/rules/HUD, with a held capture clock. Placement is a fixture, not traversal evidence.
			_host.set_physics_process(false)
			_host.player.place(area.point(&"reedway_patrol") + Vector2(0, -48), &"south")
			var before := _writes
			_host._tick_countdown(0, false)
			_host._tick_countdown(1.2, false)
			if state == "revision-cancelled":
				_host.player.place(area.point(&"reedway_patrol") + Vector2(0, -400), &"north")
				_host._tick_countdown(0, false)
			print("Host countdown: active=%s remaining=%.2f state=%d new writes=%d" % [_host.encounter_countdown().active, _host.encounter_countdown().remaining, _host.countdown.state, _writes - before])
		"revision-journal": _host.open_journal()
		"revision-quest":
			_host.player.place(area.point(&"wayside_bell") + Vector2(0, 48), &"north")
			_host.session.restore_bell(&"briarfen_reedway")
		"revision-save-manual", "revision-save-auto":
			if state == "revision-save-manual": _host.session.save()
			else: _host.session.equip(Enums.EquipSlot.WEAPON, &"reedbow")
			_host.notices._process(.35)
			_host.notices.set_process(false)
		"town":
			_host.player.place(area.anchor(&"town_bell") + Vector2(-120, -40), &"west")
		"forge", "forge-locked", "forge-fitted", "forge-refund", "forge-receipt", "stillroom", "stillroom-potion", "stillroom-locked":
			# Each service opens only from its own station landmark (V0.5 UI typed services).
			var station := WorldDefinition.load_default().find_landmark(
				&"stillroom_table" if state.begins_with("stillroom") else &"preparation_bench")[1] as LandmarkDefinition
			_host.session.enter_station(station.id)
			# Fixtures: a crafted fitting (forge-fitted), an older save's grandfathered kit (forge-refund),
			# the price and mastery of a first craft (forge-receipt) and brewed stock (stillroom-potion).
			if state == "forge-fitted":
				GameState.progress.add_recipe(&"forge.merciful_grip")
			if state == "forge-refund":
				GameState.progress.add_recipe(&"forge.first_fitting")
			if state in ["forge-fitted", "forge-refund"]:
				_host.session.fit(&"pilgrims_edge", &"fitting.merciful_grip")
			if state == "forge-receipt":
				GameState.progress.materials[&"bog_iron"] = 2
				GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
			if state == "stillroom-potion":
				GameState.progress.set_supply(&"focus_tincture", 2)
				_host.session.prepare_potion(1, &"focus_tincture")
			_host.open_crafting(station, &"fitting:fitting.merciful_grip" if state in ["forge-fitted", "forge-receipt"] else &"")
			if state == "forge-receipt":
				(_host.modal.find_child("CraftFitting", true, false) as Button).pressed.emit()
		"explore-clue":
			_host.player.place(Vector2(2672, 1328), &"north")
			_host.open_dialogue(WorldDefinition.load_default().find_landmark(&"listening_stones")[1])
		"explore-runes", "explore-progress", "explore-mistake", "explore-solved", "explore-niche", "explore-searched", "explore-reward", "explore-iron", "explore-gathered":
			_host.player.place(Vector2(2672, 1328), &"north")
			if state in ["explore-iron", "explore-gathered"]:
				_host.player.place(area.point(&"iron_seam") + Vector2(-30, 30), &"northeast")
				if state == "explore-gathered":
					_host.session.gather(&"briarfen_reedway", &"iron_seam")
			elif state != "explore-runes":
				_host.strike(WorldDefinition.load_default().find_landmark(&"rhythm_stone_low")[1])
				if state == "explore-mistake":
					_host.strike(WorldDefinition.load_default().find_landmark(&"rhythm_stone_mid")[1])
				elif state != "explore-progress":
					_host.strike(WorldDefinition.load_default().find_landmark(&"rhythm_stone_high")[1])
					_host.strike(WorldDefinition.load_default().find_landmark(&"rhythm_stone_mid")[1])
					if state != "explore-solved":
						_host._close_modal()
					if state == "explore-searched":
						_host.session.find_secret(&"briarfen_reedway", &"drowned_niche")
					elif state == "explore-niche":
						_host.open_dialogue(WorldDefinition.load_default().find_landmark(&"drowned_niche")[1])
					elif state == "explore-reward":
						_host.open_dialogue(WorldDefinition.load_default().find_landmark(&"drowned_niche")[1])
						_host.modal.chosen.emit(WorldRules.ACT_SEARCH)
			area.apply_state(_host.session.world())
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
		"bench-charm", "bench-empty":
			_host.player.place(area.point(&"preparation_bench") + Vector2(0, 30), &"north")
			_host.open_bench(WorldDefinition.load_default().find_landmark(&"preparation_bench")[1],
				Enums.EquipSlot.CHARM if state == "bench-charm" else Enums.EquipSlot.RELIC)
			if state == "bench-charm":
				(_host.modal.find_child("Item_storm_salt_charm", true, false) as Button).pressed.emit()
		"inventory", "inventory-start", "character-equipment", "character-combat", "character-actions", "character-magic", "character-skills":
			_host.open_inventory()
			if state.begins_with("character-"):
				(_host.modal.find_child("Character", true, false) as WorldCharacterView).select_tab(StringName(state.trim_prefix("character-")))
		"notices":
			_host.notices.push_notice("Game Saved", "", JourneyUI.icon("save"), &"save")
			_host.notices.push_notice("Bog Iron", "+1", preload("res://assets/art/global/ui/materials/bog_iron_v01.svg"))
			_host.notices.push_notice("Fenrunner Leathers", "+1", preload("res://assets/art/global/ui/items/fenrunner_leathers_v01.svg"))
			_host.notices._process(.35) # Settle the presentation tween for the capture.
		"station-forge", "station-stillroom":
			_host.player.place(area.point(&"preparation_bench" if state == "station-forge" else &"stillroom_table") + Vector2(0, 50), &"north")
		"encounter-claimed":
			_host.load_area(&"briarfen_reedway", &"reedway_patrol")
			_host.open_encounter_card(WorldDefinition.load_default().find_landmark(&"reedway_patrol")[1])
		"charm-reward":
			_host.open_dialogue(WorldDefinition.load_default().find_landmark(&"wayside_bell")[1])
			_host.modal.chosen.emit(WorldRules.ACT_RING)
		"catch-up":
			pass # The real world-entry reconciliation has opened the notice.
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
			_host._confirm_reset()
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
	if state in ["revision-quest", "victory"]:
		# Hold the settled notice, rather than capturing its intentional entrance slide off-canvas.
		_host.notices._process(.35)
		_host.notices.set_process(false)
		await _frames(2)
	if _args.has("revealed") and _host.modal != null:
		_host.modal.reveal_dialogue()
		for frame in 60:
			_host.modal._process(1.0 / 60.0)
		await _frames(3)
	if _args.has("inspect") and _host.modal != null:
		var source := _host.modal.find_child(String(_args.inspect), true, false) as Control
		if source != null:
			source.grab_focus()
			var inspector := _host.modal.find_child("CharacterInspector", true, false) as HoverInspector
			if inspector != null:
				inspector.follow_keyboard()
			await _frames(6)
	if _args.has("details"):
		Input.action_press(InputBindings.INFO)
		await _frames(4)
	if _args.has("help") and _host.modal != null:
		(_host.modal.find_child("Help", true, false) as Button).pressed.emit()
		await _frames(4)
	if _args.has("scroll-end") and _host.modal != null:
		var scroll := _host.modal.find_child("EquipmentScroll" if _host.modal.kind == &"bench" else (
			"CraftingDetailsScroll" if _host.modal.kind == &"crafting" else "ContentScroll"), true, false) as ScrollContainer
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(3)
	_save()
	Input.action_release(InputBindings.INFO)
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
