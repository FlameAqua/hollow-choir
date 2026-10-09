extends TestCase
## Fifth playtest (Adrian, 9 October 2026): Pause opens at once while choosing (recipient review
## included) and during playback, and freezes the battle in place: playback waits, announcements,
## floating text, the stage and recipient keys. Resume continues at once. While a command or reaction
## window is open, from its preparation beat to its result, every pause request (key, Start, toolbar
## button, a host's Setup) is ignored, not queued: pausing must never help timing. The reviewed action
## keeps its selected frame. Fixture: fen patrol, seed 3 (Mara plans first).

var _tree: SceneTree


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func after_each() -> void:
	Engine.time_scale = 1.0
	for action in [InputBindings.COMMAND, InputBindings.CONFIRM] + ReactionReadout.KEYS.values():
		Input.action_release(action)
	AudioManager.silence()


func _battle() -> BattleScene:
	var fixture: TestCase = load("res://tests/ui/test_v02_ui.gd").new()
	fixture._tree = _tree
	return await fixture._battle()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _until(condition: Callable, limit_ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return condition.call()


func _press(code: String) -> void:
	var event := InputBindings.event_from_code(code)
	event.pressed = true
	_tree.root.push_input(event, true)
	event.pressed = false
	_tree.root.push_input(event, true)


func _start_button() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_START
		event.pressed = pressed
		_tree.root.push_input(event, true)


func _targeted(scene: BattleScene, skip: Button = null) -> Button:
	for button in scene._menu._buttons:
		var option: ActionOption = button.get_meta(&"option")
		if button != skip and option.legal and option.action.needs_target_choice() and option.action.targets_enemies():
			return button
	return null


func _frame(button: Button) -> Texture2D:
	return (button.get_theme_stylebox("normal") as StyleBoxTexture).texture


func _wait_ms(ms: int, scene: BattleScene = null) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		_keep_focus(scene)
		await _tree.process_frame


## Rendered runs share the desktop: a real focus change freezes the preparation beat and any open
## command or reaction clock by design (they wait for the player to return). Fixtures that need time
## to pass simulate that return.
func _keep_focus(scene: BattleScene) -> void:
	if not is_instance_valid(scene):
		return
	if not scene._window_focused:
		scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for child in scene._timed_host.get_children() + scene._overlay.get_children():
		if (child is CommandWidget or child is ReactionWidget) and child._focus_lost:
			child._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


## Waits for a timed window to resolve, with the player present.
func _resolved(scene: BattleScene, widget: Control) -> bool:
	return await _until(func() -> bool:
		_keep_focus(scene)
		return not is_instance_valid(widget) or widget.is_done())


## Lets the real presenter reach a live (prepared, running) reaction window.
func _live_reaction(scene: BattleScene) -> ReactionWidget:
	scene._executor = null
	scene.launch.autoplay = true
	Engine.time_scale = 20
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
			button.pressed.emit()
			break
	var widget: ReactionWidget
	var deadline := Time.get_ticks_msec() + 8000
	while widget == null and Time.get_ticks_msec() < deadline:
		_keep_focus(scene)
		for child in scene._timed_host.get_children():
			if child is CommandWidget and not child.is_preparing() and not child.is_done():
				child._finish(Enums.ExecutionGrade.GOOD)
		for child in scene._overlay.get_children():
			if child is ReactionWidget and not child.is_queued_for_deletion() and not child.is_preparing() and not child.is_done():
				widget = child
		await _tree.process_frame
	Engine.time_scale = 1
	if widget != null:
		widget._focus_lost = false
		widget.clock.resume()
	else:
		var request := scene.engine.get_request()
		assert_true(false, "no live reaction within 8 s: request %s, preparing %s, timed %s, frozen %s, focused %s" % [
			BattleRequest.Kind.find_key(request.kind) if request != null else "none", scene._preparing,
			scene._timed_active, scene.is_frozen(), scene._window_focused])
	return widget


## Lets the real presenter reach a command window still in its preparation beat.
func _preparing_command(scene: BattleScene) -> CommandWidget:
	scene._executor = null
	scene.launch.autoplay = true
	Engine.time_scale = 20
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
			button.pressed.emit()
			break
	var widget: CommandWidget
	var deadline := Time.get_ticks_msec() + 8000
	while widget == null and Time.get_ticks_msec() < deadline:
		_keep_focus(scene)
		for child in scene._timed_host.get_children():
			if child is CommandWidget and not child.is_queued_for_deletion() and child.is_preparing():
				widget = child
		await _tree.process_frame
	Engine.time_scale = 1
	return widget


## Every pause path while a timed window is open. Each must be ignored; they are checked one at a
## time, so a path that opened Pause cannot be hidden by the next one toggling it closed.
func _assert_pause_ignored(scene: BattleScene, phase: String) -> void:
	_press("key:Escape")
	await _frames(1)
	assert_false(scene.is_paused(), "the Pause key is ignored " + phase)
	_start_button()
	await _frames(1)
	assert_false(scene.is_paused(), "controller Start is ignored " + phase)
	scene._pause_button.pressed.emit()
	assert_false(scene.is_paused(), "the toolbar Pause is ignored " + phase)
	assert_false(scene.pause_for_host(), "a host's Setup is refused " + phase)
	assert_false(scene.is_paused() or scene.is_frozen())
	for node: Node in [scene._events, scene._overlay, scene._timed_host, scene._battlefield]:
		assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT, "%s keeps running %s" % [node.name, phase])


func test_pause_opens_during_recipient_review_and_returns_to_the_same_review() -> void:
	var scene := await _battle()
	var button := _targeted(scene)
	button.pressed.emit()
	await _frames(2)
	assert_true(scene._picker.is_targeting())
	var reviewed := scene._picker.reviewed_target_uid()
	var logged := scene.engine.input_log.size()
	var focus := scene._picker.acting_unit().focus
	scene._pause_button.pressed.emit()
	await _frames(2)
	assert_true(scene.is_paused(), "the toolbar Pause opens during recipient review")
	assert_true(scene.is_frozen())
	assert_true(scene._picker.is_targeting(), "the review waits underneath")
	assert_false(scene._target_prompt.visible, "recipient guidance hides under the pause card")
	for code in ["key:Right", "key:Left", "key:Right"]:
		_press(code)
	await _frames(2)
	assert_eq(scene._picker.reviewed_target_uid(), reviewed, "recipient keys do nothing under Pause")
	_start_button()
	await _frames(2)
	assert_false(scene.is_paused(), "controller Start resumes")
	assert_false(scene.is_frozen(), "Resume continues at once")
	assert_true(scene._picker.is_targeting(), "back in the same review")
	assert_eq(scene._picker.reviewed_target_uid(), reviewed)
	assert_true(scene._target_prompt.visible)
	assert_null(_tree.root.gui_get_focus_owner(), "recipient keys still belong to the review, not a menu row")
	assert_eq(scene._menu.pending_button(), button)
	_start_button()
	await _frames(2)
	assert_true(scene.is_paused(), "Start pauses recipient review too")
	_start_button()
	await _frames(2)
	_press("key:Escape")
	await _frames(2)
	assert_false(scene.is_paused(), "Escape (shared Back/Pause key) stays Back while reviewing")
	assert_false(scene._picker.is_targeting())
	assert_eq(scene.engine.input_log.size(), logged, "pausing never submits")
	assert_eq(scene._picker.acting_unit().focus, focus, "and never spends Focus")
	scene.queue_free()
	await _frames(2)


func test_reviewed_action_keeps_its_selected_frame() -> void:
	var scene := await _battle()
	var selected := UICraft.texture("selected")
	var button := _targeted(scene)
	var original := _frame(button)
	assert_ne(original, selected)
	button.grab_focus()
	await _frames(2)
	_press("key:Enter")
	await _frames(4)
	assert_true(scene._picker.is_targeting())
	assert_null(_tree.root.gui_get_focus_owner(), "keyboard focus moves to the recipient keys")
	assert_eq(scene._menu.pending_button(), button)
	assert_eq(_frame(button), selected, "the reviewed action keeps its selected frame")
	for other in scene._menu._buttons:
		if other != button:
			assert_ne(_frame(other), selected, "only the reviewed action is marked")
	var replacement := _targeted(scene, button)
	assert_not_null(replacement)
	replacement.pressed.emit()
	await _frames(2)
	assert_eq(scene._menu.pending_button(), replacement, "replacing the action moves the frame")
	assert_eq(_frame(button), original, "the replaced action shows its own frame again")
	assert_eq(_frame(replacement), selected)
	_press("key:Escape")
	await _frames(3)
	assert_false(scene._picker.is_targeting())
	assert_null(scene._menu.pending_button(), "Back clears the mark")
	assert_eq(_tree.root.gui_get_focus_owner(), replacement, "and the row itself has focus again")
	replacement.pressed.emit()
	await _frames(2)
	scene._picker.click(scene._picker.reviewed_target_uid())
	await _frames(2)
	assert_null(scene._menu.pending_button(), "committing clears the mark")
	scene.queue_free()
	await _frames(2)


func test_pause_is_ignored_during_a_live_reaction() -> void:
	var scene := await _battle()
	var widget := await _live_reaction(scene)
	assert_not_null(widget, "a live reaction window opened")
	if widget == null:
		scene.queue_free()
		return
	var started := widget.elapsed_ms()
	await _assert_pause_ignored(scene, "during a reaction")
	await _wait_ms(40, scene)
	assert_true(widget.is_done() or widget.elapsed_ms() > started, "the reaction clock never stops for it")
	if not widget.is_done():
		var reaction: Enums.ReactionType = widget.spec.allowed[0]
		var key: StringName = ReactionReadout.KEYS[reaction]
		Input.action_press(key)
		var press := InputEventAction.new()
		press.action = key
		press.pressed = true
		_tree.root.push_input(press, true)
		await _frames(2)
		Input.action_release(key)
		assert_eq(widget.chosen(), reaction, "reaction keys still work after the ignored requests")
	assert_true(await _resolved(scene, widget), "the window resolves normally")
	await _frames(10)
	assert_false(scene.is_paused(), "an ignored request is not queued for later")
	scene.queue_free()
	await _frames(2)


func test_pause_is_ignored_through_a_command_window() -> void:
	var scene := await _battle()
	var widget := await _preparing_command(scene)
	assert_not_null(widget, "a command window is in its preparation beat")
	if widget == null:
		scene.queue_free()
		return
	await _assert_pause_ignored(scene, "during the preparation beat")
	assert_true(await _until(func() -> bool:
		_keep_focus(scene)
		return not is_instance_valid(widget) or not widget.is_preparing()), "the beat runs on")
	if not is_instance_valid(widget):
		scene.queue_free()
		return
	widget._focus_lost = false
	widget.clock.resume()
	var started := widget.elapsed_ms()
	await _assert_pause_ignored(scene, "while the command clock runs")
	await _wait_ms(40, scene)
	assert_true(widget.is_done() or widget.elapsed_ms() > started, "the command clock never stops for it")
	if not widget.is_done():
		widget._finish(Enums.ExecutionGrade.GOOD)
	await _frames(10)
	assert_false(scene.is_paused(), "an ignored request is not queued for later")
	scene.queue_free()
	await _frames(2)


func test_pause_freezes_playback_announcements_and_floating_text() -> void:
	var scene := await _battle()
	scene.launch.autoplay = true
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
			button.pressed.emit()
			break
	assert_true(await _until(func() -> bool: return scene._banner.visible and scene._banner._tween != null and scene._banner._tween.is_valid()), "a turn announcement plays")
	scene.request_pause()
	assert_true(scene.is_paused(), "Pause opens during playback, not after it")
	var elapsed := scene._banner._tween.get_total_elapsed_time()
	var feedback := FloatingText.spawn(scene._overlay, Vector2(400, 300), "Frozen", UITheme.TEXT)
	var at := feedback.position
	await _frames(20)
	assert_eq(scene._banner._tween.get_total_elapsed_time(), elapsed, "the announcement holds its place")
	assert_eq(feedback.position, at, "floating text holds its place")
	assert_true(scene._banner.visible)
	scene._close_pause()
	assert_false(scene.is_frozen(), "Resume continues at once")
	await _frames(4)
	assert_true(not scene._banner._tween.is_valid() or scene._banner._tween.get_total_elapsed_time() > elapsed, "the announcement continues")
	assert_ne(feedback.position, at)
	scene.queue_free()
	await _frames(2)


func test_log_key_cannot_reopen_the_log_under_pause() -> void:
	var scene := await _battle()
	scene.request_pause()
	_press("key:Tab")
	await _frames(2)
	assert_false(scene._log.visible, "Tab cannot reopen the log underneath Pause")
	scene._open_combat_help()
	_press("key:Tab")
	await _frames(2)
	assert_false(scene._log.visible, "nor underneath Reaction help")
	scene._combat_help.chosen.emit(&"back")
	await _frames(2)
	scene._close_pause()
	_press("key:Tab")
	await _frames(2)
	assert_true(scene._log.visible, "Tab still opens the log while playing")
	scene.request_pause()
	assert_false(scene._log.visible)
	scene.queue_free()
	await _frames(2)


## An autoplayed training battle that is decided within seconds.
func _deciding_battle(host_result: bool) -> BattleScene:
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"toy_training"],
		Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	var scene: BattleScene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	scene.embedded = not host_result
	scene.host_result = host_result
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.autoplay = true
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	scene.start(launch)
	return scene


func test_pause_after_the_outcome_is_decided_cannot_discard_it() -> void:
	Engine.time_scale = 20
	var scene := _deciding_battle(false)
	var left := [0]
	scene.setup_requested.connect(func() -> void: left[0] += 1)
	assert_true(await _until(func() -> bool: return scene.engine.is_finished()), "the battle is decided")
	Engine.time_scale = 1
	assert_false(scene._concluded, "its final playback is still on screen")
	scene.request_pause()
	assert_true(scene.is_paused(), "the last playback can still be paused")
	assert_true(scene._pause_leave.disabled, "but leaving cannot discard the decided outcome")
	scene._retreat()
	assert_eq(left[0], 0)
	scene._close_pause()
	assert_true(await _until(func() -> bool: return scene._result_panel.visible), "the result arrives after Resume")
	scene.request_pause()
	assert_false(scene._pause_panel.visible, "no pause over the result card")
	scene.queue_free()
	await _frames(2)


## World host (host_result): the host shows its own outcome card over the finished battle (defeat
## keeps it underneath), so the battle's Pause key must not open a pause box or freeze it again.
func test_a_host_owned_outcome_cannot_be_paused() -> void:
	Engine.time_scale = 20
	var scene := _deciding_battle(true)
	var finished := [0]
	scene.finished.connect(func(_result: BattleResult) -> void: finished[0] += 1)
	assert_true(await _until(func() -> bool: return finished[0] > 0), "the host received the outcome")
	Engine.time_scale = 1
	assert_false(scene._result_panel.visible, "the host, not the battle, shows the outcome")
	_press("key:Escape")
	await _frames(2)
	assert_false(scene.is_paused(), "the Pause key opens no pause box over the host's outcome card")
	assert_false(scene.is_frozen())
	scene.request_pause()
	assert_false(scene.is_paused(), "nor does the Pause button")
	assert_false(scene._log.visible)
	scene.queue_free()
	await _frames(2)


## Defensive contract: a frozen battle opens no new request (menu, command or reaction window).
func test_a_frozen_battle_opens_no_new_request() -> void:
	var scene := await _battle()
	scene.request_pause()
	var reached := [false]
	var probe := func() -> void:
		await scene._safe_point()
		reached[0] = true
	probe.call()
	await _frames(3)
	assert_false(reached[0], "the safe point holds while frozen")
	scene._close_pause()
	await _frames(1)
	assert_true(reached[0], "and releases on thaw")
	scene.queue_free()
	await _frames(2)

