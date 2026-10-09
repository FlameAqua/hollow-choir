extends TestCase
## Second/third playtest dock checks with real pointer motion and wheel events: one shared dock
## follows the pointer from a potion to an enemy, its intent and the empty stage without keeping a
## stale payload; recipient markers follow only the hovered move; the wheel scrolls an overflowing
## card both ways from its source, while short cards leave the lists their own wheel.

var _tree: SceneTree


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func after_each() -> void:
	Input.action_release(InputBindings.INFO)
	Engine.time_scale = 1.0


func _battle() -> BattleScene:
	Engine.time_scale = 20
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"fen_patrol"],
		Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	var scene: BattleScene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	scene.start(launch)
	var deadline := Time.get_ticks_msec() + 6000
	while not scene._picker.is_active() and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	Engine.time_scale = 1
	await _frames(4)
	return scene


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(2, 0)
	_tree.root.push_input(motion, true)


func _wheel(point: Vector2, button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		_tree.root.push_input(event, true)
	await _frames(3)


## Waits (real time) until the dock shows [param source]; replacing a subject settles briefly.
func _inspecting(scene: BattleScene, source: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while scene._inspector._source != source and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return scene._inspector._source == source


func _draught(scene: BattleScene) -> Button:
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"use_mending_draught":
			return button
	return null


func test_potion_enemy_intent_and_empty_stage_never_leave_a_stale_payload() -> void:
	var scene := await _battle()
	var draught := _draught(scene)
	_move(draught.get_global_rect().get_center())
	assert_true(await _inspecting(scene, draught))
	await _frames(3)
	var payload := scene._inspector._payload as ActionReadout
	assert_true(payload != null and payload.action.id == &"use_mending_draught", "the dock describes the hovered potion")
	assert_eq(payload.item_charges, scene.engine.get_state().potion_slots[0].charges)
	var enemy := scene.engine.get_state().enemies()[0]
	_move(scene._battlefield.body_point(enemy.uid))
	assert_true(await _inspecting(scene, scene._battlefield.view(enemy.uid)))
	await _frames(3)
	assert_true(scene._inspector._payload is UnitReadout, "the enemy replaces the potion")
	assert_false(scene._inspector._card.visible, "no potion card remains beside the enemy")
	var slot := scene._rail.slot(enemy.uid)
	var move := slot.get_global_transform_with_canvas() * Vector2(47, 15)
	_move(move)
	assert_true(await _inspecting(scene, slot))
	await _frames(3)
	var intent := scene._inspector._payload as IntentReadout
	assert_not_null(intent, "hovering the move inspects the intent")
	var marked: Array[int] = []
	for uid: int in scene._battlefield.views:
		if (scene._battlefield.views[uid] as UnitView).intent_targeted:
			marked.append(uid)
	marked.sort()
	var recipients := intent.target_uids.duplicate()
	recipients.sort()
	assert_eq(marked, recipients, "the move's public recipients are marked, nothing else")
	assert_false(scene._picker.is_targeting(), "inspecting an intent selects nothing")
	_move(Vector2(640, 150))
	await _tree.create_timer(0.3).timeout
	await _frames(2)
	assert_eq(scene._inspector.shown_text(), "", "the empty stage leaves the dock empty")
	assert_null(scene._inspector._payload, "no stale potion or intent payload")
	assert_false(scene._inspector._card.visible or scene._inspector._unit_card.visible)
	for uid: int in scene._battlefield.views:
		assert_false((scene._battlefield.views[uid] as UnitView).intent_targeted, "markers clear with the hover")
	scene.queue_free()


func test_wheel_scrolls_an_overflowing_card_both_ways_and_short_cards_leave_the_lists() -> void:
	var scene := await _battle()
	var draught := _draught(scene)
	var point := draught.get_global_rect().get_center()
	_move(point)
	assert_true(await _inspecting(scene, draught))
	await _frames(3)
	var scroll := scene._inspector._scroll
	var short := scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1
	if short:
		assert_false(scene._inspector.claims_wheel(draught), "a short card leaves the supply list its wheel")
	# Alt expands the analysis; the wheel then moves the card down and back up from its source.
	Input.action_press(InputBindings.INFO)
	await _frames(5)
	assert_true(scene._inspector.expanded)
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y, "expanded analysis overflows the dock")
	var list := scene._menu._supply_scroll.scroll_vertical
	await _wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
	var down := scroll.scroll_vertical
	assert_gt(down, 0, "wheel down over the potion scrolls its card")
	assert_eq(scene._menu._supply_scroll.scroll_vertical, list, "one wheel event moves one pane")
	await _wheel(point, MOUSE_BUTTON_WHEEL_UP)
	assert_lt(scroll.scroll_vertical, down, "wheel up over the potion scrolls back")
	var inside := scene._inspector.get_global_rect().get_center()
	await _wheel(inside, MOUSE_BUTTON_WHEEL_DOWN)
	assert_gt(scroll.scroll_vertical, 0, "the wheel inside the dock scrolls it too")
	assert_eq(scene._inspector._source, draught, "scrolling inside the dock keeps the potion as its subject")
	Input.action_release(InputBindings.INFO)
	await _frames(4)
	assert_false(scene._inspector.expanded)
	scene.queue_free()
