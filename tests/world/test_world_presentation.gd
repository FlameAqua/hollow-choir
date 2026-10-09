extends TestCase
## Director integration regressions: route choice, input focus, chart selection, fixed actions and
## integer art/camera positions without quantizing physical movement. These are automated fixtures.

var kit: WorldKit
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start(area_id: StringName = &"gloamstead", anchor: StringName = &"town_bell") -> void:
	GameState.progress.world.area = area_id
	GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _layout() -> void:
	for frame in 4:
		await tree.process_frame


func _assert_frame_and_actions() -> void:
	var canvas := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var frame := host.modal.get_node("Frame") as Control
	assert_true(canvas.encloses(frame.get_global_rect()), "%s frame stays on the fixed canvas" % host.modal.kind)
	for button in host.modal.buttons:
		assert_true(frame.get_global_rect().encloses(button.get_global_rect()), "%s action stays inside its frame" % button.name)
		assert_gte(button.size.y, 40, "actions keep a legible hit target")
		assert_false((host.modal.find_child("ContentScroll", true, false) as Node).is_ancestor_of(button),
			"closing actions do not scroll away")


func test_modal_actions_stay_on_canvas_and_focus_cannot_escape_to_hud() -> void:
	await _start()
	host.open_menu()
	await _layout()
	_assert_frame_and_actions()
	for button in host.modal.buttons:
		for neighbour in [button.focus_neighbor_top, button.focus_neighbor_bottom,
				button.focus_neighbor_left, button.focus_neighbor_right, button.focus_next, button.focus_previous]:
			assert_true(host.modal.is_ancestor_of(button.get_node(neighbour)), "focus stays in the paused menu")
	host.open_dialogue(WorldDefinition.load_default().find_landmark(&"bellkeeper")[1])
	await _layout()
	_assert_frame_and_actions()
	assert_eq(host.modal.get_node("Frame").position.y, 424.0, "dialogue leaves the speaker visible above it")


func test_all_bench_weapons_keep_their_details_and_close_action_reachable() -> void:
	await _start()
	host.open_bench(WorldDefinition.load_default().find_landmark(&"preparation_bench")[1])
	for weapon in WorldRules.bench_weapons(GameState.progress):
		var button := host.modal.find_child("Weapon_" + String(weapon.id), true, false) as Button
		button.grab_focus()
		button.pressed.emit()
		await _layout()
		_assert_frame_and_actions()
		var details := host.modal.find_child("WeaponDetails", true, false) as WorldWeaponDetails
		var scroll := host.modal.find_child("WeaponScroll", true, false) as ScrollContainer
		assert_lte(details.get_global_rect().size.x, scroll.get_global_rect().size.x, "structured weapon facts fit the content column")
		assert_true(details.text.contains(weapon.description), "shared weapon description remains available")
		for action in weapon.techniques:
			assert_true(details.text.contains(action.description), "every owned weapon action remains available")
		assert_eq(GameState.progress.loadout_weapon, weapon.id)
		assert_true(button.button_pressed and button.icon != null, "equipped is an icon badge and selected state")


func test_full_map_selection_updates_description_without_travel_or_saving() -> void:
	await _start(&"briarfen_reedway", &"reedway_entry")
	for landmark in host.area_def.landmarks:
		GameState.progress.world.discover(landmark.id)
	host.open_map()
	await _layout()
	_assert_frame_and_actions()
	var before := GameState.progress.to_dict()
	var writes := kit.writer.writes.size()
	var at := host.player.position
	var readout := host.map_readout()
	for index in readout.landmarks.size():
		var button := host.modal.find_child("Place%d" % index, true, false) as Button
		button.pressed.emit()
		assert_eq((host.modal.find_child("PlaceDescription", true, false) as Label).text,
			String(readout.landmarks[index].description), "mouse/confirm selection updates the description")
		assert_eq((host.modal.find_child("MapView", true, false) as WorldMapView).selected, index)
	var last := host.modal.find_child("Place%d" % (readout.landmarks.size() - 1), true, false) as Button
	last.grab_focus()
	await _layout()
	var scroll := host.modal.find_child("PlacesScroll", true, false) as ScrollContainer
	assert_gt(scroll.scroll_vertical, 0, "focus scrolls the last discovered place into view")
	assert_true(scroll.get_global_rect().encloses(last.get_global_rect()), "last place is fully reachable")
	assert_eq(host.player.position, at)
	assert_eq(kit.writer.writes.size(), writes)
	assert_eq(GameState.progress.to_dict(), before)


func test_bench_opens_on_equipped_item_without_scrolling_the_weapon_list() -> void:
	GameState.progress.loadout_weapon = &"reedbow"
	await _start()
	host.open_bench(WorldKit.site(&"preparation_bench"))
	await _layout()
	var equipped := host.modal.find_child("Weapon_reedbow", true, false) as Button
	assert_eq(tree.root.gui_get_focus_owner(), equipped)
	var frame := (host.modal.get_node("Frame") as Control).get_global_rect()
	var scroll := host.modal.find_child("WeaponScroll", true, false) as ScrollContainer
	assert_eq(scroll.scroll_vertical, 0, "weapon identity is visible when the bench opens")
	for weapon in WorldRules.bench_weapons(GameState.progress):
		var choice := host.modal.find_child("Weapon_" + String(weapon.id), true, false) as Button
		assert_true(frame.encloses(choice.get_global_rect()), "every weapon choice stays visible")
		assert_false(scroll.is_ancestor_of(choice), "scrolling details cannot hide weapon choices")
		assert_lte(choice.size.y, 64, "item icons cannot inflate the choice rows")
	assert_true(equipped.button_pressed)
	_assert_frame_and_actions()


func test_dialogue_first_confirm_reveals_before_advancing_or_saving() -> void:
	await _start()
	host.open_dialogue(WorldKit.site(&"bellkeeper"))
	var dialogue := host.modal._dialogue
	assert_eq(dialogue.visible_characters, 0)
	host.modal._process(0.1)
	assert_gt(dialogue.visible_characters, 0, "text appears gradually")
	assert_lt(dialogue.visible_characters, dialogue.get_total_character_count())
	host.modal.buttons[0].pressed.emit()
	assert_eq(dialogue.visible_characters, dialogue.get_total_character_count(), "first press reveals the whole line")
	assert_not_null(host.modal, "first press keeps the conversation open")
	assert_eq(kit.writer.writes.size(), 0, "revealing text cannot complete an interaction")
	host.modal.buttons[0].pressed.emit()
	assert_null(host.modal, "second press advances the conversation")
	assert_eq(kit.writer.writes.size(), 1)


func test_material_footsteps_follow_actual_distance_and_stop_at_solid_water() -> void:
	await _start()
	var steps: Array[Vector2] = []
	host.player.footstep.connect(func(at: Vector2) -> void: steps.append(at))
	host.player.place(Vector2(32.5, 4.5) * 32)
	for frame in 90:
		host.player.step(Vector2.UP, 1.0 / 60.0)
	assert_gt(steps.size(), 0, "travel produces footsteps")
	assert_false(host.player.moving, "solid water stops the feet")
	var stopped_count := steps.size()
	for frame in 60:
		host.player.step(Vector2.UP, 1.0 / 60.0)
	assert_eq(steps.size(), stopped_count, "holding movement against a wall stays quiet")
	var heard: Array[StringName] = []
	for layer: TileMapLayer in [host.area.get_node("GroundDetail"), host.area.get_node("Ground")]:
		for cell in layer.get_used_cells():
			var at := layer.map_to_local(cell)
			var material := host.area.surface_at(at)
			if heard.has(material):
				continue
			var cue := AudioManager.Cue.STEP_WOOD if material == &"wood" else AudioManager.Cue.STEP_STONE if material == &"stone" else AudioManager.Cue.STEP_PEAT
			var voice := AudioManager._next
			host._play_footstep(at)
			assert_eq(AudioManager._players[voice].stream, AudioManager._streams[cue], "authored surface selects its material sound")
			heard.append(material)
	assert_has(heard, &"peat")
	assert_has(heard, &"stone")
	assert_has(heard, &"wood")


func test_idle_breathing_respects_reduce_motion_and_diagonal_frames_exist() -> void:
	await _start()
	var reduced := Settings.data.reduce_motion
	Settings.data.reduce_motion = false
	host.player.place(host.player.position, &"southwest")
	var sprite := host.player._sprite
	assert_eq(sprite.sprite_frames.get_frame_count(&"idle_southwest"), 2, "standing pose has authored breathing frames")
	sprite.frame = 0
	await tree.create_timer(.8).timeout
	assert_eq(sprite.frame, 1, "authored idle advances without deforming pixel rows")
	assert_eq(host.player._visual.scale, Vector2.ONE, "pixel art keeps an integer native scale")
	Settings.data.reduce_motion = true
	host.player.stop()
	assert_false(sprite.is_playing(), "reduce motion holds the standing pose")
	assert_eq(sprite.frame, 0)
	assert_eq(host.player._visual.scale, Vector2.ONE)
	Settings.data.reduce_motion = reduced
	for facing in [&"northwest", &"northeast", &"southwest", &"southeast"]:
		host.player.place(host.player.position, facing)
		assert_true(host.player._sprite.sprite_frames.has_animation(host.player.animation_name()), "diagonal idle has its own art")
		assert_gt(host.player._sprite.sprite_frames.get_frame_count(StringName("walk_" + String(facing))), 1, "diagonal walking has a cycle")


func test_guard_leaves_the_outside_loop_and_far_side_route_uninterrupted() -> void:
	await _start(&"briarfen_reedway", &"reedway_fork")
	# Walk the actual feet body along the authored outside loop and far-side path. No teleports
	# between waypoints, no opened latch and no cleared encounters. This does not replace human play.
	for tile in [Vector2(10.5, 54.5), Vector2(10.5, 22.5), Vector2(38.5, 13.5), Vector2(60.5, 25.5),
			Vector2(68.5, 35.5), Vector2(65.5, 50.5), Vector2(65.5, 61.5)]:
		var reached := _walk(tile * 32.0)
		assert_true(reached, "outside route reaches %s without an encounter card (feet %s)" % [tile, host.player.position])
		if not reached:
			return
	assert_null(host.modal)
	assert_false(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_false(GameState.progress.world.wayside_bell_restored)
	assert_eq(host.readout().interaction, WorldCopy.ACTION_OPEN_LATCH)
	assert_false(GameState.progress.world.return_latch_open)


func _walk(to: Vector2) -> bool:
	for step in 1400:
		if host.player.position.distance_to(to) < 3.0:
			host.player.stop()
			return true
		if host.mode != WorldHost.Mode.EXPLORE:
			return false
		host.player.step(host.player.position.direction_to(to), 1.0 / 60.0)
		host._after_move()
	return false


func test_guard_card_still_opens_on_the_bell_steps() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	host.player.place(Vector2(1936, 816))
	host._after_move()
	assert_null(host.modal, "junction itself stays free")
	_walk(host.area.point(&"bell_guard"))
	assert_not_null(host.modal, "stepping toward the guard still presents a deliberate encounter")
	if host.modal == null:
		return
	assert_eq(host.modal.kind, &"encounter")
	assert_not_null(host.modal.button(WorldRules.ACT_ENGAGE))
	assert_null(host.battle, "approach never launches battle on its own")
	assert_eq(kit.writer.writes.size(), 0, "the card alone records nothing")


func test_pixel_alignment_preserves_continuous_physics_and_camera_framing() -> void:
	await _start()
	var at := Vector2(1000.25, 1060.7)
	host.player.place(at)
	assert_eq(host.player.position, at, "physical feet retain their subpixel position")
	assert_eq(host.player._visual.global_position, at.round())
	assert_eq(host.player.camera().global_position, at.round())
	assert_eq(host.player.camera().offset, Vector2(0, -24))
	assert_eq(host.player.camera().zoom, Vector2(2, 2))


func test_restored_home_chart_uses_the_same_flag_as_the_visible_bell() -> void:
	await _start()
	GameState.progress.world.wayside_bell_restored = true
	host.area.apply_state(GameState.progress.world)
	var home := host.map_readout().landmarks.filter(func(place: Dictionary) -> bool: return place.label == "Bell square")
	assert_eq(home.size(), 1)
	assert_eq(home[0].description, WorldCopy.MAP_HOME_RESTORED)
	assert_true((host.area.get_node("DepthSorted/TownBell/Answering") as Node2D).visible)
	assert_false((host.area.get_node("DepthSorted/TownBell/Quiet") as Node2D).visible)
