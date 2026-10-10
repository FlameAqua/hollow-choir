extends TestCase
## V0.5 follow-up through the real WorldHost: sprinting (faster, spends and refills stamina, frozen by
## modals, exhausted until released, reset by an area load, the meter under the feet), the Loadout /
## Inventory / Journal / Field Guide shortcuts (open, switch, close, ignored by stations and menus,
## never a write) and the Reed gate's posts sorting at their own bases.

const WALK_FRAME := WorldPlayer.SPEED / 60.0

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


func _start() -> void:
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _frames(count: int) -> void:
	for frame in count:
		await tree.physics_frame


## Moves right for [param count] physics frames; returns the distance travelled.
func _travel(count: int, sprint: bool) -> float:
	host.scripted_move = Vector2.RIGHT
	host.scripted_sprint = sprint
	var start := host.player.position.x
	await _frames(count)
	return host.player.position.x - start


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	host._unhandled_input(event)
	await tree.process_frame


# --- Sprint ------------------------------------------------------------------------------------------

func test_sprint_is_faster_spends_stamina_and_shows_the_meter() -> void:
	await _start()
	host.player.collision_mask = 0
	assert_eq(InputBindings.DEFAULTS[InputBindings.WORLD_SPRINT], ["key:Shift", "joy:7"])
	var walked := await _travel(30, false)
	assert_almost_eq(walked, 30.0 * WALK_FRAME, 0.5, "walking speed")
	assert_eq(host.player.stamina.value, 1.0, "walking never spends stamina")
	assert_eq(host.player._meter.visible_amount(), 0.0, "a full meter stays hidden")
	var sprinted := await _travel(30, true)
	assert_almost_eq(sprinted / walked, WorldPlayer.SPRINT_MULTIPLIER, 0.03, "sprinting is faster")
	assert_almost_eq(host.player.stamina.value, 1.0 - 0.5 / Stamina.DRAIN_SECONDS, 0.02, "half a second spent")
	assert_true(host.player.stamina.sprinting)
	assert_gt(host.player._meter.visible_amount(), 0.0, "the meter shows under the feet")
	assert_eq(host.player._sprite.speed_scale, WorldPlayer.SPRINT_ANIMATION, "the walk cycle quickens")
	# A modal freezes it: nothing spent or refilled while the map is open.
	var held := host.player.stamina.value
	host.open_map()
	await _frames(30)
	assert_eq(host.player.stamina.value, held)
	assert_eq(host.player._sprite.speed_scale, 1.0)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	# Walking again refills in proportion: half a second used, half a second to refill.
	await _travel(15, false)
	assert_lt(host.player.stamina.value, 1.0)
	await _travel(20, false)
	assert_eq(host.player.stamina.value, 1.0)


func test_an_empty_meter_walks_until_the_input_is_released() -> void:
	await _start()
	host.player.collision_mask = 0
	host.player.stamina.value = 0.05
	await _travel(20, true)
	assert_true(host.player.stamina.exhausted, "a quarter second of sprint empties it")
	# Still held: walking pace, every frame, while the meter refills.
	for frame in 10:
		var before := host.player.position.x
		await _frames(1)
		assert_almost_eq(host.player.position.x - before, WALK_FRAME, 0.05, "frame %d walks" % frame)
	assert_false(host.player.stamina.sprinting)
	# Released for a frame, then pressed again: sprinting resumes.
	await _travel(1, false)
	var resumed := await _travel(3, true)
	assert_almost_eq(resumed, 3.0 * WALK_FRAME * WorldPlayer.SPRINT_MULTIPLIER, 0.3)
	# Arriving anywhere (an area load, a return from battle) starts with a full, hidden meter.
	host.load_area(&"gloamstead", &"town_bell")
	assert_eq([host.player.stamina.value, host.player.stamina.exhausted], [1.0, false])
	assert_eq(host.player._meter.visible_amount(), 0.0)


func test_sprinting_into_a_fence_spends_nothing() -> void:
	await _start()
	host.player.place(Vector2(60.5, 10.5) * 32)
	host.scripted_move = Vector2.RIGHT
	host.scripted_sprint = true
	var reached := false
	for frame in 120:
		await _frames(1)
		if not host.player.moving:
			reached = true
			break
	assert_true(reached, "sprinting reaches the reed fence")
	var at_contact := host.player.stamina.value
	assert_lt(at_contact, 1.0, "the sprint there spent stamina")
	await _frames(30)
	assert_false(host.player.moving)
	assert_almost_eq(host.player.stamina.value, minf(1.0, at_contact + 0.5 / Stamina.RECOVER_SECONDS), 0.02,
		"pressing on spends nothing; the meter refills")
	assert_false(host.player.stamina.sprinting)


func test_the_bound_sprint_input_is_read_through_the_held_gate() -> void:
	# A sprint key already held when exploration resumes reads as released until pressed again.
	Input.action_press(InputBindings.WORLD_SPRINT)
	await _start()
	assert_true(host.is_blocked(InputBindings.WORLD_SPRINT))
	assert_false(host.sprint_held())
	Input.action_release(InputBindings.WORLD_SPRINT)
	await _frames(2)
	Input.action_press(InputBindings.WORLD_SPRINT)
	await _frames(1)
	assert_true(host.sprint_held())


# --- Shortcuts ---------------------------------------------------------------------------------------

func test_shortcuts_open_switch_and_close_their_views_without_writing() -> void:
	await _start()
	var writes := kit.writer.writes.size()
	assert_eq([InputBindings.DEFAULTS[InputBindings.WORLD_LOADOUT], InputBindings.DEFAULTS[InputBindings.WORLD_INVENTORY],
		InputBindings.DEFAULTS[InputBindings.WORLD_JOURNAL], InputBindings.DEFAULTS[InputBindings.WORLD_FIELD_GUIDE]],
		[["key:L"], ["key:I"], ["key:J"], ["key:F"]])
	assert_eq(host.shortcut_view(), &"")
	await _press(InputBindings.WORLD_LOADOUT)
	assert_eq(host.shortcut_view(), &"loadout")
	assert_not_null(host.modal.find_child("Loadout", true, false))
	var card := host.modal
	await _press(InputBindings.WORLD_INVENTORY)
	assert_eq(host.modal, card, "Inventory is the same card's other tab")
	assert_eq(host.shortcut_view(), &"inventory")
	assert_not_null(host.modal.find_child("EquipmentSlots", true, false))
	await _press(InputBindings.WORLD_INVENTORY)
	assert_null(host.modal, "pressed again it closes")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	await _press(InputBindings.WORLD_JOURNAL)
	assert_eq(host.modal.kind, &"journal")
	await _press(InputBindings.WORLD_JOURNAL)
	assert_null(host.modal)
	# From the map straight to the Loadout, and closed from there.
	await _press(InputBindings.WORLD_MAP)
	assert_eq(host.shortcut_view(), &"map")
	await _press(InputBindings.WORLD_LOADOUT)
	assert_eq(host.shortcut_view(), &"loadout")
	await _press(InputBindings.WORLD_LOADOUT)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	# The Field Guide: opened over the world and closed by the same key.
	await _press(InputBindings.WORLD_FIELD_GUIDE)
	assert_eq(host.shortcut_view(), &"field_guide")
	assert_true(host._screen is FieldGuide)
	await _press(InputBindings.WORLD_FIELD_GUIDE)
	await tree.process_frame
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_null(host._screen)
	# Opened from the Character card, the guide closed by its key returns to that card.
	host.open_character_menu()
	(host.modal.find_child("FieldGuide", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(host.shortcut_view(), &"field_guide")
	await _press(InputBindings.WORLD_FIELD_GUIDE)
	await tree.process_frame
	assert_eq(host.modal.kind, &"character")
	host._close_modal()
	assert_eq(kit.writer.writes.size(), writes, "opening and closing views never writes")


func test_shortcuts_leave_menus_stations_and_cards_alone() -> void:
	await _start()
	host.open_menu()
	for action: StringName in WorldHost.SHORTCUTS:
		await _press(action)
		assert_eq(host.modal.kind, &"menu", "%s is ignored by the paused menu" % action)
	host._close_modal()
	host.open_crafting(WorldKit.site(&"preparation_bench"))
	for action: StringName in WorldHost.SHORTCUTS:
		await _press(action)
		assert_eq(host.modal.kind, &"crafting", "%s is ignored at a station" % action)
	# The station's own Character card keeps the station context: no shortcut takes it over.
	host.modal.chosen.emit(&"preparation")
	assert_eq(host.modal.kind, &"character")
	assert_eq(host.shortcut_view(), &"other")
	await _press(InputBindings.WORLD_INVENTORY)
	assert_eq(host.modal.kind, &"character")
	assert_eq(host.session.station(), &"preparation_bench")
	# A real key press goes through the modal first: the map's own toggle closes it exactly once.
	host._close_modal()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await tree.process_frame
	assert_eq(host.shortcut_view(), &"map")
	Input.parse_input_event(key)
	await tree.process_frame
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	key.pressed = false
	Input.parse_input_event(key)


# --- Depth sorting -----------------------------------------------------------------------------------

func test_each_reed_gate_post_sorts_at_its_own_base() -> void:
	var area := (load("res://scenes/world/areas/gloamstead.tscn") as PackedScene).instantiate() as Node2D
	tree.root.add_child(area)
	var gate := area.get_node("DepthSorted/ReedGate") as Node2D
	assert_true(gate.y_sort_enabled, "the posts take part in the world's sorting one by one")
	assert_eq(gate.get_child_count(), 2)
	for post: Sprite2D in gate.get_children():
		var art := post.global_transform * post.get_rect()
		assert_almost_eq(post.global_position.y, art.end.y - 4.0, 0.5,
			"%s sorts where it meets the ground, so Hollow in front of it is drawn in front" % post.name)
	area.queue_free()
