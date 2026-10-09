extends TestCase
## V0.4 world host through the real scenes: feet collision, bounded portals that cannot bounce,
## modal/held-input gates, deliberate encounter cards, one battle per entry, exact retry, failed
## writes, far-side latch, home consequence, paused-world return paths and filtered map readouts.

const FORBIDDEN := ["fen_patrol", "rot_grove", "Fen Patrol", "Rot Grove", "Bogshell", "Thornhound", "Fen Wisp",
	"Rotcap", "Sporecaller", "affinit", "weakness", "resist"]

var kit: WorldKit
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	for action in InputBindings.WORLD_ACTIONS + [InputBindings.CONFIRM, InputBindings.CANCEL]:
		Input.action_release(action)
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start(area_id: StringName = &"", anchor: StringName = &"") -> void:
	if area_id != &"":
		GameState.progress.world.area = area_id
		GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _frames(count: int) -> void:
	for frame in count:
		await tree.physics_frame


func _until(condition: Callable, limit_ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return condition.call()


## Walks until [param done] returns true or [param limit] physics frames pass.
func _walk_until(direction: Vector2, done: Callable, limit: int = 400) -> bool:
	host.scripted_move = direction
	for frame in limit:
		await tree.physics_frame
		if done.call():
			host.scripted_move = Vector2.ZERO
			return true
	host.scripted_move = Vector2.ZERO
	return false


func _texts(node: Node) -> PackedStringArray:
	var texts := PackedStringArray([String(node.name)])
	if node is Control:
		texts.append((node as Control).tooltip_text)
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	elif node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		texts.append_array(_texts(child))
	return texts


func _assert_no_leaks(node: Node, where: String) -> void:
	var joined := " ".join(_texts(node))
	for word in FORBIDDEN:
		assert_false(joined.contains(word), "%s leaks '%s'" % [where, word])


func test_starts_at_the_square_with_a_filtered_hud() -> void:
	await _start()
	assert_eq(host.area_def.id, &"gloamstead")
	assert_eq(host.player.position, host.area.anchor(&"town_bell"))
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.readout().area_name, "Gloamstead")
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_FIND)
	assert_eq(host.readout().interaction, "", "nothing in reach at the bell")
	assert_false(host.area.collision_layer_node().visible, "graybox collision hidden in play")
	assert_eq(host.hud.theme, tree.root.theme, "canvas-layer UI uses the fixed game theme")
	var camera := host.player.camera()
	assert_eq(camera.zoom, Vector2(2, 2))
	assert_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], [0, 0, 80 * 32, 56 * 32])


func test_feet_collide_with_water_and_fence_and_walk_follows_displacement() -> void:
	await _start()
	host.player.place(Vector2(32.5, 4.5) * 32)
	await _walk_until(Vector2.UP, func() -> bool: return false, 90)
	assert_gte(host.player.position.y, 2 * 32.0, "the water ring stops the feet")
	host.player.place(Vector2(64.5, 10.5) * 32)
	host.scripted_move = Vector2.RIGHT
	await _frames(90)
	assert_lt(host.player.position.x, 66 * 32.0, "the reed fence is solid away from the gate")
	assert_false(host.player.moving, "pushing into a wall is not walking")
	assert_eq(host.player.animation_name(), &"idle_east")
	host.scripted_move = Vector2(-1, 1)
	await _frames(10)
	assert_true(host.player.moving)
	assert_eq(String(host.player.animation_name()).begins_with("walk_"), true)
	var before := host.player.position
	await _frames(30)
	host.scripted_move = Vector2.ZERO
	var travelled := host.player.position - before
	assert_almost_eq(travelled.length() / (30.0 / Engine.physics_ticks_per_second), WorldPlayer.SPEED, 4.0,
		"diagonals are normalized")


func test_portals_round_trip_without_bouncing() -> void:
	await _start()
	host.player.place(Vector2(64.5, 25.5) * 32)
	var crossed := await _walk_until(Vector2.RIGHT, func() -> bool: return host.area_def.id == &"briarfen_reedway")
	assert_true(crossed, "the reed gate leads to the Reedway")
	assert_eq(host.player.position, host.area.anchor(&"reedway_entry"))
	assert_eq(String(kit.writer.last().world.area), "briarfen_reedway", "area arrival is a safe boundary")
	await _frames(20)
	assert_eq(host.area_def.id, &"briarfen_reedway", "arriving never triggers the return portal")
	assert_true(GameState.progress.world.is_discovered(&"reedway_entry"))
	var back := await _walk_until(Vector2.DOWN, func() -> bool: return host.area_def.id == &"gloamstead")
	assert_true(back, "the entry leads home")
	assert_eq(host.player.position, host.area.anchor(&"reed_gate"))
	await _frames(20)
	assert_eq(host.area_def.id, &"gloamstead")


func test_a_trigger_under_the_feet_must_be_left_before_it_fires() -> void:
	await _start()
	var trigger := host.area.portals()[0]
	host.player.place(trigger.position)
	host._portals_armed = false
	await _frames(10)
	assert_eq(host.area_def.id, &"gloamstead", "standing in an unarmed trigger does nothing")
	await _walk_until(Vector2.LEFT, func() -> bool: return host.area.portal_at(host.player.position) == &"")
	await _frames(2)
	var crossed := await _walk_until(Vector2.RIGHT, func() -> bool: return host.area_def.id != &"gloamstead")
	assert_true(crossed, "re-entering after leaving fires once")


func test_modals_freeze_movement_and_held_input_needs_release() -> void:
	await _start()
	host.open_map()
	assert_eq(host.mode, WorldHost.Mode.MODAL)
	var before := host.player.position
	host.scripted_move = Vector2.RIGHT
	await _frames(20)
	assert_eq(host.player.position, before, "map pauses movement")
	host.scripted_move = Vector2.INF
	Input.action_press(InputBindings.WORLD_RIGHT)
	Input.action_press(InputBindings.WORLD_INTERACT)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_true(host.is_blocked(InputBindings.WORLD_INTERACT), "the closing press cannot interact")
	assert_eq(host.move_vector(), Vector2.ZERO, "held movement waits for release")
	await _frames(5)
	assert_eq(host.player.position, before)
	Input.action_release(InputBindings.WORLD_RIGHT)
	Input.action_release(InputBindings.WORLD_INTERACT)
	await _frames(2)
	assert_false(host.is_blocked(InputBindings.WORLD_INTERACT))
	Input.action_press(InputBindings.WORLD_RIGHT)
	await _frames(1)
	assert_eq(host.move_vector(), Vector2.RIGHT, "a fresh press moves again")


func test_focus_loss_pauses_into_the_world_menu() -> void:
	await _start()
	host._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(host.mode, WorldHost.Mode.MODAL)
	assert_eq(host.modal.kind, &"menu")


func test_encounter_card_cancel_costs_nothing_and_engage_launches_once() -> void:
	await _start(&"briarfen_reedway", &"reedway_patrol")
	var opened := await _walk_until(Vector2.UP, func() -> bool: return host.modal != null)
	assert_true(opened, "reaching the group shows the card")
	assert_eq(host.modal.kind, &"encounter")
	assert_not_null(host.modal.button(WorldRules.ACT_ENGAGE))
	_assert_no_leaks(host.modal, "encounter card")
	var writes := kit.writer.writes.size()
	var cancel := InputEventAction.new()
	cancel.action = InputBindings.CANCEL
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await tree.process_frame
	await tree.process_frame
	assert_null(host.modal, "Cancel closes the card")
	assert_null(host.battle, "Cancel never launches")
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(kit.writer.writes.size(), writes)
	await _frames(10)
	assert_null(host.modal, "the card does not reopen while still in reach")
	assert_eq(host.readout().interaction, "Approach the patrol")
	host.interact()
	assert_eq(host.modal.kind, &"encounter", "Confirm reopens it deliberately")
	host.modal.chosen.emit(WorldRules.ACT_ENGAGE)
	assert_not_null(host.battle)
	assert_eq(host.mode, WorldHost.Mode.BATTLE)
	assert_eq(kit.writer.writes.size(), writes + 1, "entry saved before launch")
	var battle := host.battle
	host.engage(WorldKit.site(&"reedway_patrol"))
	assert_eq(host.battle, battle, "a second engage cannot launch another battle")
	assert_eq(kit.writer.writes.size(), writes + 1)
	assert_false(battle.launch.record_progress, "the battle never records on its own")
	assert_true(battle.host_result)
	assert_eq(battle.theme.default_font, tree.root.theme.default_font, "embedded battle keeps the font and suppresses duplicate tooltips")
	# Pause → Leave battle: back at the approach, encounter available, nothing awarded.
	battle.setup_requested.emit()
	await tree.process_frame
	assert_null(host.battle)
	assert_eq(host.player.position, host.area.anchor(&"reedway_patrol"))
	assert_null(GameState.progress.world.pending_entry)
	assert_false(GameState.progress.world.is_cleared(&"reedway_patrol"))
	assert_eq(GameState.progress.battles_won + GameState.progress.battles_lost, 0)


func test_victory_commits_once_and_the_group_stays_gone() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	host.engage(WorldKit.site(&"bell_guard"))
	var entry := GameState.progress.world.pending_entry
	assert_not_null(entry)
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_null(host.battle)
	assert_eq(host.modal.kind, &"victory")
	assert_true(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_false((host.area.get_node("DepthSorted/GuardGroup") as Node2D).visible, "the group is absent")
	assert_eq(host.player.position, host.area.anchor(&"bell_guard"))
	assert_eq(GameState.progress.battles_won, 1)
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_eq(GameState.progress.battles_won, 1, "a repeated result cannot award twice")
	host.modal.chosen.emit(&"continue")
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_RESTORE)
	# Reload: the clear survives and the group stays absent.
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	host.queue_free()
	host = null
	await tree.process_frame
	await _start()
	assert_false((host.area.get_node("DepthSorted/GuardGroup") as Node2D).visible)


func test_failed_victory_write_offers_retry_and_publishes_nothing() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	host.engage(WorldKit.site(&"bell_guard"))
	var entry := GameState.progress.world.pending_entry
	kit.writer.fail = true
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(host.modal.cancel_id, &"", "the failure cannot be dismissed into play")
	assert_false(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_eq(GameState.progress.battles_won, 0)
	assert_ne(host.mode, WorldHost.Mode.EXPLORE, "no walking on with an unsaved result")
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.modal.kind, &"victory")
	assert_true(GameState.progress.world.is_cleared(&"bell_guard"))


func test_defeat_retry_reuses_the_entry_and_return_goes_home() -> void:
	await _start(&"briarfen_reedway", &"reedway_patrol")
	host.engage(WorldKit.site(&"reedway_patrol"))
	var entry := GameState.progress.world.pending_entry
	var first_seed := host.battle.launch.setup.seed
	var defeat := BattleResult.new()
	defeat.outcome = Enums.BattleOutcome.DEFEAT
	defeat.weapon_uses[&"pilgrims_edge"] = 6
	host._on_battle_finished(entry, defeat)
	assert_eq(host.modal.kind, &"defeat")
	assert_true(GameState.progress.weapon_mastery.is_empty(), "defeat records no practice")
	var writes := kit.writer.writes.size()
	host.modal.chosen.emit(&"retry")
	assert_not_null(host.battle)
	assert_eq(host.battle.launch.setup.seed, first_seed, "retry uses the captured seed")
	assert_eq(GameState.progress.world.pending_entry.token(), entry.token(), "same entry")
	assert_eq(kit.writer.writes.size(), writes, "retry writes nothing")
	host._on_battle_finished(entry, defeat)
	host.modal.chosen.emit(&"home")
	await tree.process_frame
	assert_null(host.battle)
	assert_eq(host.area_def.id, &"gloamstead")
	assert_eq(host.player.position, host.area.anchor(&"town_bell"))
	assert_null(GameState.progress.world.pending_entry)


func test_latch_opens_only_from_the_far_side() -> void:
	await _start(&"briarfen_reedway", &"reedway_entry")
	host.player.place(Vector2(65.5, 66.0) * 32)
	await _frames(2)
	assert_eq(host.readout().interaction, "Examine the gate")
	host.interact()
	assert_eq(host.modal.kind, &"dialogue")
	assert_null(host.modal.button(WorldRules.ACT_OPEN_LATCH), "no opening from the near side")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	var blocked := await _walk_until(Vector2.UP, func() -> bool: return host.player.position.y < 63 * 32.0, 120)
	assert_false(blocked, "the closed gate is solid")
	host.player.place(host.area.anchor(&"return_latch"))
	await _frames(2)
	assert_eq(host.readout().interaction, WorldCopy.ACTION_OPEN_LATCH)
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_OPEN_LATCH)
	assert_true(GameState.progress.world.return_latch_open)
	assert_false(GameState.progress.world.wayside_bell_restored, "independent of the bell")
	assert_eq(String(kit.writer.last().world.anchor), "return_latch")
	await _frames(2)
	var through := await _walk_until(Vector2.DOWN, func() -> bool: return host.player.position.y > 65 * 32.0, 200)
	assert_true(through, "the open gate is walkable")
	assert_true(GameState.progress.world.links.has(&"short_return"), "the shortcut is charted at once")


func test_ringing_the_bell_changes_home() -> void:
	GameState.progress.world.cleared.append(&"bell_guard")
	await _start(&"briarfen_reedway", &"wayside_bell")
	assert_eq(host.readout().interaction, "Examine the wayside bell")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_RING)
	assert_true(GameState.progress.world.wayside_bell_restored)
	assert_true(" ".join(_texts(host.modal)).contains(WorldCopy.BELL_RESTORED))
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_RETURN)
	host.load_area(&"gloamstead", &"town_bell")
	assert_true((host.area.get_node("DepthSorted/TownBell/Answering") as Node2D).visible)
	assert_false((host.area.get_node("DepthSorted/TownBell/Quiet") as Node2D).visible)
	assert_true((host.area.get_node("DepthSorted/SquareLamp/Lit") as Node2D).visible)
	assert_true((host.area.get_node("DepthSorted/SquareLamp/Lit/LampLight") as PointLight2D).enabled)
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_DONE)
	host.player.place(host.area.point(&"bellkeeper") + Vector2(0, 30))
	await _frames(2)
	host.interact()
	assert_eq(host.modal.kind, &"dialogue")
	assert_true(" ".join(_texts(host.modal)).contains(WorldCopy.BELLKEEPER_AFTER[0]))


func test_bench_choice_feeds_the_next_entry() -> void:
	await _start()
	host.player.place(host.area.point(&"preparation_bench") + Vector2(0, 28))
	await _frames(2)
	assert_eq(host.readout().interaction, "Use the preparation bench")
	host.interact()
	assert_eq(host.modal.kind, &"bench")
	var reedbow := host.modal.find_child("Weapon_reedbow", true, false) as Button
	assert_not_null(reedbow)
	assert_null(host.modal.find_child("Weapon_thunderhead", true, false), "only owned starter weapons")
	reedbow.pressed.emit()
	assert_eq(GameState.progress.loadout_weapon, &"reedbow")
	assert_true(reedbow.button_pressed and reedbow.icon != null)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	var entry := host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(entry.build_setup(Database.registry, Database.library).loadout.weapon.id, &"reedbow")


func test_menu_screens_return_to_the_paused_world() -> void:
	await _start()
	var position := host.player.position
	host.open_menu()
	host.modal.chosen.emit(&"field_guide")
	await tree.process_frame
	var guide := host.find_child("FieldGuide", true, false)
	assert_true(guide is FieldGuide, "Field Guide opens over the world")
	assert_eq(host.mode, WorldHost.Mode.MODAL)
	guide.closed.emit()
	await tree.process_frame
	assert_eq(host.modal.kind, &"menu", "Back returns to the paused world menu")
	host.modal.chosen.emit(&"settings")
	await tree.process_frame
	var settings := host.find_child("SettingsScreen", true, false)
	assert_true(settings is SettingsScreen)
	settings.closed.emit()
	await tree.process_frame
	assert_eq(host.modal.kind, &"menu")
	host.modal.chosen.emit(&"save")
	assert_eq(host.modal.kind, &"menu")
	assert_eq(String(kit.writer.last().world.anchor), "town_bell", "explicit save keeps the safe anchor")
	host.modal.chosen.emit(&"resume")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.player.position, position)
	assert_eq(host.area_def.id, &"gloamstead")


func test_map_lists_only_discovered_places_and_never_travels() -> void:
	await _start(&"briarfen_reedway", &"reedway_entry")
	host.open_map()
	var labels := host.map_readout().landmarks.map(func(entry: Dictionary) -> String: return entry.label)
	assert_eq(labels, ["Gloamstead gate"])
	_assert_no_leaks(host.modal, "fresh map")
	var place := host.modal.find_child("Place0", true, false) as Button
	place.pressed.emit()
	assert_eq(host.player.position, host.area.anchor(&"reedway_entry"), "selection never travels")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	GameState.progress.world.discover(&"reedway_patrol")
	GameState.progress.world.discover(&"bell_guard")
	host.open_map()
	_assert_no_leaks(host.modal, "map with encounter sites")
	assert_false(host.map_readout().landmarks.any(func(entry: Dictionary) -> bool: return entry.label == "Listening stones"))


func test_title_offers_continue_journey_without_a_new_game_overwrite() -> void:
	var menu: MainMenu = load(SceneRouter.MAIN_MENU).instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	assert_eq(menu._first_button.text, "Continue journey")
	await tree.process_frame
	await tree.process_frame
	assert_lte(menu._menu_panel.get_global_rect().end.y, 720.0, "title options fit the fixed canvas")
	var texts := " ".join(_texts(menu))
	assert_false(texts.contains("New game"), "no overwrite control")
	assert_true(texts.contains("Combat Sandbox"), "the Sandbox stays available")
	menu.queue_free()
	await tree.process_frame


func test_bench_choice_survives_a_failed_save_and_retry() -> void:
	await _start()
	host.player.place(host.area.point(&"preparation_bench") + Vector2(0, 28))
	await _frames(2)
	host.interact()
	kit.writer.fail = true
	(host.modal.find_child("Weapon_reedbow", true, false) as Button).pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.loadout_weapon, &"pilgrims_edge", "nothing published by the failed write")
	# The failure card replaced the bench; let it be freed before the player retries.
	await tree.process_frame
	await tree.process_frame
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	await tree.process_frame
	assert_eq(GameState.progress.loadout_weapon, &"reedbow", "the retried choice is saved and published")
	assert_not_null(host.modal, "the player is never left in a modal mode without a modal")
	if host.modal == null:
		return
	assert_eq(host.modal.kind, &"bench", "the bench returns showing the saved choice")
	var reedbow := host.modal.find_child("Weapon_reedbow", true, false) as Button
	assert_true(reedbow != null and reedbow.button_pressed and reedbow.icon != null)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)


func test_reduce_motion_from_paused_settings_reaches_world_idles_at_once() -> void:
	var reduce := Settings.data.reduce_motion
	Settings.data.reduce_motion = false
	await _start()
	var idles: Array[AnimatedSprite2D] = []
	for sprite in host.area.find_children("*", "AnimatedSprite2D", true, false):
		if not host.player.is_ancestor_of(sprite):
			idles.append(sprite as AnimatedSprite2D)
	assert_false(idles.is_empty(), "the square has idling figures")
	assert_true(idles.all(func(sprite: AnimatedSprite2D) -> bool: return sprite.is_playing()))
	Settings.data.reduce_motion = true
	EventBus.settings_changed.emit()
	assert_true(idles.all(func(sprite: AnimatedSprite2D) -> bool: return not sprite.is_playing() and sprite.frame == 0),
		"Reduce Motion holds every idle without waiting for another area")
	Settings.data.reduce_motion = false
	EventBus.settings_changed.emit()
	assert_true(idles.all(func(sprite: AnimatedSprite2D) -> bool: return sprite.is_playing()))
	Settings.data.reduce_motion = reduce


func test_victory_return_rearms_triggers_from_the_engagement_spot() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	var site := WorldKit.site(&"bell_guard")
	var spot := host.area.point(&"bell_guard") + Vector2(0, site.interact_radius - 6.0)
	host.player.place(spot, &"north")
	host.engage(site)
	host._on_battle_finished(GameState.progress.world.pending_entry, WorldKit.victory(&"bell_guard"))
	host.modal.chosen.emit(&"continue")
	assert_eq(host.player.position, spot, "victory returns to the engagement spot")
	assert_false(host._armed_sites[&"bell_guard"], "triggers are armed from the feet, not from the approach anchor")
	assert_true(host._portals_armed)
	assert_eq(String(kit.writer.last().world.anchor), "bell_guard", "the save still resumes at the safe anchor")


func test_pause_ignores_a_world_reaction_then_leave_battle_frees_the_battle() -> void:
	await _start(&"briarfen_reedway", &"reedway_patrol")
	host.engage(WorldKit.site(&"reedway_patrol"))
	var battle := host.battle
	assert_not_null(battle)
	# Let the real presenter (autopilot planning, manual timing widgets) reach a running reaction
	# window, then try to pause inside it.
	battle.launch.autoplay = true
	Engine.time_scale = 20
	var widget: ReactionWidget
	var deadline := Time.get_ticks_msec() + 12000
	while widget == null and Time.get_ticks_msec() < deadline:
		# A real desktop focus change would hold the preparation beat; simulate the player returning.
		if not battle._window_focused:
			battle._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		for child in battle._timed_host.get_children():
			if child is CommandWidget and not child.is_preparing() and not child.is_done():
				child._finish(Enums.ExecutionGrade.GOOD)
		for child in battle._overlay.get_children():
			if child is ReactionWidget and not child.is_preparing() and not child.is_done():
				widget = child
		await tree.process_frame
	Engine.time_scale = 1
	assert_not_null(widget, "a live reaction window opened in the world battle")
	if widget == null:
		return
	widget._focus_lost = false
	widget.clock.resume()
	battle.request_pause()
	assert_false(battle.is_paused() or battle.is_frozen(), "Pause is ignored during the world battle's reaction window")
	assert_true(await _until(func() -> bool:
		# A real desktop focus change freezes the window by design; simulate the player returning.
		if is_instance_valid(widget) and widget._focus_lost:
			widget._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		return not is_instance_valid(widget) or widget.is_done()), "the window resolves")
	# Once the window has closed, Pause opens at the next request and Leave battle frees the battle.
	assert_true(await _until(func() -> bool:
		if not battle._timed_active and not battle.is_paused():
			battle.request_pause()
		return battle.is_paused()), "Pause opens after the window")
	assert_true(battle.is_frozen())
	assert_false(battle._pause_leave.disabled)
	battle._pause_leave.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	assert_null(host.battle, "Leave battle frees the paused battle")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.player.position, host.area.anchor(&"reedway_patrol"))
	assert_null(GameState.progress.world.pending_entry, "no attempt is recorded")
	assert_false(GameState.progress.world.is_cleared(&"reedway_patrol"))
	await tree.process_frame


func test_area_battle_and_return_music_follow_typed_cues_without_menu_restarts() -> void:
	await _start()
	var music := AudioManager.music
	var town := music.library.find(&"gloamstead_town")
	assert_eq(music.cue_id, &"gloamstead_town", "Gloamstead requests its own cue")
	assert_true(town.tracks.has(music.current_track), "one of the Gloamstead versions plays")
	var playing := music.current_track
	host.open_menu()
	host.modal.chosen.emit(&"resume")
	await tree.process_frame
	assert_eq(music.current_track, playing, "opening and closing the paused menu keeps the same song")
	assert_eq(music.transition_reason, &"cue")
	host.load_area(&"briarfen_reedway", &"reedway_patrol")
	assert_eq(music.cue_id, &"briarfen_exploration")
	assert_true(music.library.find(&"briarfen_exploration").tracks.has(music.current_track), "a Reedway exploration version plays")
	host.engage(WorldKit.site(&"reedway_patrol"))
	var battle := host.battle
	assert_eq(music.cue_id, AudioManager.battle_music(battle.launch.setup), "the battle requests its typed battle cue")
	var battle_track := music.current_track
	await tree.process_frame
	battle.request_pause()
	battle._close_pause()
	assert_eq(music.current_track, battle_track, "pausing a battle never restarts its music")
	battle.setup_requested.emit()
	await tree.process_frame
	assert_null(host.battle)
	assert_eq(music.cue_id, &"briarfen_exploration", "leaving returns to the area's cue")
	assert_true(music.library.find(&"briarfen_exploration").tracks.has(music.current_track))
