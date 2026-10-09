extends TestCase
## Third playtest: choosing another action or item while a recipient is under review. Real mouse
## clicks and keys go through the viewport. Replacing the pending action rebuilds its recipients
## and preview; nothing is spent until one deliberate submission; unavailable rows, hovering,
## Details and the pending action itself never replace the choice; Back still returns to the list.
## Fixture: fen patrol, seed 3. Mara plans first (2 Focus): Spear Flurry/Inspect (enemy), Condemn
## (needs 3 Focus), Intercept (2 Focus, Hollow only), Guard (self), Mending Draught (ally item) and
## Fen Water Flask (enemy item).

const HOLLOW := 0
const MARA := 1

var _tree: SceneTree
var _tooltip_mode: int
var _device: int


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_tooltip_mode = Settings.data.advanced_tooltips
	_device = InputBindings.active_device


func after_each() -> void:
	Settings.data.advanced_tooltips = _tooltip_mode as GameSettings.TooltipMode
	InputBindings.active_device = _device as InputBindings.Device
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
	assert_eq(scene._picker.acting_unit().uid, MARA, "the fixture plans Mara first")
	return scene


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _button(scene: BattleScene, action_id: StringName) -> Button:
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == action_id:
			return button
	return null


func _option(scene: BattleScene, action_id: StringName) -> ActionOption:
	return _button(scene, action_id).get_meta(&"option")


func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(2, 0)
	_tree.root.push_input(motion, true)


## A real left click on [param button], scrolled into its list first.
func _click(button: Button) -> void:
	var scroll := button.get_parent().get_parent() as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(button)
		await _frames(2)
	var at := button.get_global_rect().get_center()
	_move(at)
	await _frames(1)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		_tree.root.push_input(click, true)
	await _frames(3)


func _key(code: String) -> void:
	var event := InputBindings.event_from_code(code)
	for pressed in [true, false]:
		event.pressed = pressed
		_tree.root.push_input(event, true)
	await _frames(3)


func _actions_logged(scene: BattleScene) -> Array:
	return scene.engine.input_log.filter(func(entry: Dictionary) -> bool: return entry.kind == "action")


func _highlighted(scene: BattleScene) -> Array[int]:
	var uids: Array[int] = []
	for uid: int in scene._battlefield.views:
		if (scene._battlefield.views[uid] as UnitView).highlighted:
			uids.append(uid)
	return uids


func test_another_enemy_action_replaces_the_pending_one_and_keeps_the_recipient() -> void:
	var scene := await _battle()
	var focus := scene.engine.get_unit(MARA).focus
	await _click(_button(scene, &"spear_flurry"))
	assert_true(scene._picker.is_targeting(), "Spear Flurry opens recipient review")
	await _key("key:Right")
	var reviewed := scene._picker.reviewed_target_uid()
	assert_true(scene.engine.get_unit(reviewed).is_enemy())
	await _click(_button(scene, &"inspect"))
	assert_true(scene._picker.is_targeting(), "an enemy action opens its own review")
	assert_eq(scene._picker._option, _option(scene, &"inspect"), "Inspect replaced Spear Flurry")
	assert_eq(scene._picker.reviewed_target_uid(), reviewed, "the reviewed enemy is still legal and stays")
	assert_eq(scene._info._readout.action, _option(scene, &"inspect").action, "the preview describes the replacement")
	assert_eq(_highlighted(scene), [reviewed] as Array[int], "only the reviewed recipient is marked")
	assert_null(scene.get_viewport().gui_get_focus_owner(), "review keeps the keys, not the clicked row")
	assert_eq(_actions_logged(scene).size(), 0, "nothing was submitted while switching")
	assert_eq(scene.engine.get_unit(MARA).focus, focus, "nothing was spent while switching")
	await _key("key:Enter")
	await _key("key:Enter")
	var logged := _actions_logged(scene)
	assert_eq(logged.size(), 1, "one confirmation submits once")
	assert_eq(StringName(logged[0].action), &"inspect")
	assert_eq(int(logged[0].target), reviewed)
	assert_false(scene._target_prompt.visible)
	scene.queue_free()


func test_enemy_item_ally_and_self_transitions_rebuild_recipients() -> void:
	var scene := await _battle()
	var potions := scene.engine.get_state().potion_slots
	var charges := [potions[0].charges, potions[1].charges]
	await _click(_button(scene, &"spear_flurry"))
	assert_eq(scene._target_prompt.text, "Pick an enemy")
	# Enemy action → ally item: recipients become the party, starting with Mara herself.
	await _click(_button(scene, &"use_mending_draught"))
	assert_true(scene._picker.is_targeting())
	assert_eq(scene._target_prompt.text, "Pick an ally")
	assert_eq(scene._picker._targets.size(), 2)
	assert_eq(scene._picker.reviewed_target_uid(), MARA)
	assert_eq(_highlighted(scene), [MARA] as Array[int], "no stale enemy marker")
	# Ally → one-recipient ally action: Mara is not a legal Intercept recipient, so Hollow is.
	await _click(_button(scene, &"intercept"))
	assert_eq(scene._picker._targets, [HOLLOW] as Array[int])
	assert_eq(scene._picker.reviewed_target_uid(), HOLLOW, "the recipient follows the replacement's eligibility")
	assert_true(scene._picker.is_targeting(), "a single legal recipient is still reviewed explicitly")
	# Ally → enemy item: the previous ally is not a recipient; the first enemy is.
	await _click(_button(scene, &"use_fen_water_flask"))
	assert_eq(scene._target_prompt.text, "Pick an enemy")
	assert_true(scene.engine.get_unit(scene._picker.reviewed_target_uid()).is_enemy())
	assert_eq(_actions_logged(scene).size(), 0)
	assert_eq([potions[0].charges, potions[1].charges], charges, "no item charge is spent by reviewing items")
	assert_eq(scene.engine.get_unit(MARA).focus, 2, "Intercept's Focus was never spent")
	# A replacement without a recipient follows its usual confirmation: choosing it submits it.
	await _click(_button(scene, &"guard"))
	assert_false(scene._picker.is_active(), "Guard needs no recipient and submits as from the menu")
	var logged := _actions_logged(scene)
	assert_eq(logged.size(), 1)
	assert_eq(StringName(logged[0].action), &"guard")
	assert_eq([potions[0].charges, potions[1].charges], charges, "switching away from items spends nothing")
	assert_false(scene._target_prompt.visible)
	assert_eq(_highlighted(scene), [] as Array[int])
	scene.queue_free()


func test_unavailable_rows_hover_details_and_the_same_action_keep_the_choice() -> void:
	var scene := await _battle()
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.HOLD
	await _click(_button(scene, &"spear_flurry"))
	await _key("key:Right")
	var pending := scene._picker._option
	var reviewed := scene._picker.reviewed_target_uid()
	assert_false(_option(scene, &"condemn").legal, "Condemn needs 3 Focus")
	await _click(_button(scene, &"condemn"))
	assert_true(scene._picker.is_targeting(), "an unavailable row does not end the review")
	assert_eq(scene._picker._option, pending)
	assert_eq(scene._picker.reviewed_target_uid(), reviewed)
	assert_null(scene.get_viewport().gui_get_focus_owner(), "the refused row does not keep focus")
	await _click(_button(scene, &"spear_flurry"))
	assert_true(scene._picker.is_targeting(), "choosing the pending action again keeps reviewing it")
	assert_eq(scene._picker.reviewed_target_uid(), reviewed, "... on the same recipient")
	_move(_button(scene, &"guard").get_global_rect().get_center())
	await _frames(10)
	assert_eq(scene._picker._option, pending, "hovering another action only inspects it")
	Input.action_press(InputBindings.INFO)
	await _frames(4)
	assert_true(scene._inspector.expanded)
	assert_eq(scene._picker._option, pending, "Details never replaces the selected action")
	assert_eq(scene._picker.reviewed_target_uid(), reviewed)
	Input.action_release(InputBindings.INFO)
	await _frames(2)
	assert_eq(_actions_logged(scene).size(), 0)
	await _key("key:Escape")
	assert_false(scene._picker.is_targeting(), "Back leaves recipient review")
	assert_true(scene._picker.is_active(), "... for the action list")
	assert_eq(scene.get_viewport().gui_get_focus_owner(), _button(scene, &"spear_flurry"), "Back returns to the pending action")
	assert_eq(_actions_logged(scene).size(), 0, "canceled review spends nothing")
	scene.queue_free()


func test_back_route_is_explained_for_each_device_and_follows_the_replacement() -> void:
	var scene := await _battle()
	await _click(_button(scene, &"spear_flurry"))
	await _click(_button(scene, &"use_fen_water_flask"))
	assert_true(scene._help.text.contains("%s Back to actions" % InputBindings.prompt(InputBindings.CANCEL)))
	assert_true(scene._help.text.contains("Click an action to switch"), "pointer users learn they can switch directly")
	InputBindings.active_device = InputBindings.Device.GAMEPAD
	scene._on_device_changed()
	assert_true(scene._help.text.contains("Back to actions"))
	assert_false(scene._help.text.contains("Click"), "controller help names only its own route")
	InputBindings.active_device = InputBindings.Device.KEYBOARD
	await _key("key:Escape")
	assert_eq(scene.get_viewport().gui_get_focus_owner(), _button(scene, &"use_fen_water_flask"), "Back focuses the replacement")
	# Keyboard path: Back, move to another action, confirm it into its own review.
	scene._menu.focus_option(_option(scene, &"spear_flurry"))
	await _frames(2)
	await _key("key:Enter")
	assert_true(scene._picker.is_targeting())
	assert_eq(scene._picker._option, _option(scene, &"spear_flurry"))
	await _key("key:Enter")
	var logged := _actions_logged(scene)
	assert_eq(logged.size(), 1)
	assert_eq(StringName(logged[0].action), &"spear_flurry")
	scene.queue_free()


func test_a_remembered_recipient_that_is_no_longer_legal_is_not_reused() -> void:
	var scene := await _battle()
	var spear := _option(scene, &"spear_flurry")
	var gone := spear.target_uids[0]
	scene._picker._last_enemy_target = gone
	# A later request lists only living recipients (the remembered one fell in between).
	spear.target_uids.erase(gone)
	await _click(_button(scene, &"spear_flurry"))
	assert_true(scene._picker.is_targeting())
	assert_ne(scene._picker.reviewed_target_uid(), gone, "a fallen recipient is never reviewed")
	assert_true(spear.target_uids.has(scene._picker.reviewed_target_uid()))
	await _click(_button(scene, &"inspect"))
	assert_true(_option(scene, &"inspect").target_uids.has(scene._picker.reviewed_target_uid()))
	scene.queue_free()


func test_closing_the_log_returns_keyboard_focus_to_planning() -> void:
	var scene := await _battle()
	await _key("key:Tab")
	assert_true(scene._log.visible)
	var at := scene._log.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		_tree.root.push_input(click, true)
	await _frames(3)
	assert_true(scene._log.is_ancestor_of(scene.get_viewport().gui_get_focus_owner()), "a click lets the log scroll by keys")
	await _key("key:Tab")
	assert_false(scene._log.visible)
	assert_true(scene._menu.is_ancestor_of(scene.get_viewport().gui_get_focus_owner()), "closing the log hands focus back")
	await _key("key:Enter")
	assert_true(scene._picker.is_targeting(), "keyboard planning continues without the mouse")
	scene.queue_free()
