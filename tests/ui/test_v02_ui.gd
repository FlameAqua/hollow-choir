extends TestCase
## Reproduce reported interaction failures through real viewport input and scroll containers.
var _tree: SceneTree
var _theme: Theme
var _tooltip_mode: int

func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_theme = _tree.root.theme
	_tooltip_mode = Settings.data.advanced_tooltips

func after_each() -> void:
	_tree.root.theme = _theme
	Settings.data.advanced_tooltips = _tooltip_mode as GameSettings.TooltipMode
	Input.action_release(InputBindings.INFO)
	Input.action_release(InputBindings.COMMAND)
	for key in ReactionReadout.KEYS.values():
		Input.action_release(key)
	Engine.time_scale = 1.0
	InputBindings.install(Settings.data.bindings)

func test_modifiers_do_not_replace_pointer_details_and_alt_uses_one_card() -> void:
	var scene := await _battle()
	var enemy := scene.engine.get_state().enemies()[0]
	_move(scene._battlefield.body_point(enemy.uid))
	await _frames(8)
	var original := scene._inspector.shown_text()
	assert_true(original.contains(enemy.display_name))
	for key in [KEY_SHIFT, KEY_CTRL, KEY_ALT]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await _frames(6)
		assert_true(scene._inspector.follows_pointer(), "modifier keeps the pointer source")
		if key == KEY_ALT:
			assert_true(scene._inspector.expanded, "Alt expands the current inspector")
			assert_eq(_stage_panels(scene), [scene._inspector], "Alt never stacks a second details window over the stage")
		assert_true(scene._inspector.shown_text().contains(enemy.display_name), "modifier cannot replace enemy with keyboard-focused action")
		event.pressed = false
		Input.parse_input_event(event)
		await _frames(3)
		assert_false(scene._inspector.expanded, "releasing Alt collapses the structured card")
	assert_false(scene._inspector.get_global_rect().intersects(scene._supplies.get_global_rect()))
	var before := scene.engine.input_log.size()
	var space := InputBindings.event_from_code("key:Space")
	space.pressed = true
	_tree.root.push_input(space, true)
	space.pressed = false
	_tree.root.push_input(space, true)
	await _frames(2)
	assert_false(scene._picker.is_targeting(), "Space cannot activate the focused menu action")
	assert_eq(scene.engine.input_log.size(), before)
	var confirm := InputBindings.event_from_code("key:Enter")
	confirm.pressed = true
	_tree.root.push_input(confirm, true)
	confirm.pressed = false
	_tree.root.push_input(confirm, true)
	await _frames(10)
	assert_true(scene._picker.is_targeting(), "deliberate Enter enters target review")
	assert_true(scene._inspector.visible, "keyboard target inspection survives removal of pinned popups")
	assert_true(scene._inspector.shown_text().contains(scene.engine.get_unit(scene._picker._targets[scene._picker._target_index]).display_name))
	_move(scene._battlefield.body_point(enemy.uid))
	await _frames(5)
	var right := InputBindings.event_from_code("key:Right")
	right.pressed = true
	_tree.root.push_input(right, true)
	right.pressed = false
	_tree.root.push_input(right, true)
	await _frames(10)
	assert_false(scene._inspector.follows_pointer(), "consumed target navigation switches inspection from mouse to keyboard")
	assert_true(scene._inspector.shown_text().contains(scene.engine.get_unit(scene._picker.reviewed_target_uid()).display_name))
	scene._picker.back_to_menu()
	scene.cover_for_host()
	scene.resume_from_host()
	_move(scene._battlefield.body_point(enemy.uid))
	await _frames(10)
	assert_true(scene._inspector.visible, "the same subject can reopen after Setup clears it")
	scene.queue_free()

func test_closing_setup_after_battle_restores_results() -> void:
	Engine.time_scale = 30
	var sandbox: CombatSandbox = load("res://scenes/sandbox/combat_sandbox.tscn").instantiate()
	_tree.root.add_child(sandbox)
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"toy_training"], Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	var launch := BattleLaunch.make(setup, "")
	launch.autoplay = true
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	launch.record_progress = false
	sandbox._launch(launch, "Retry", "Setup")
	var deadline := Time.get_ticks_msec() + 6000
	while not sandbox._battle._result_panel.visible and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	assert_true(sandbox._battle._result_panel.visible, "battle reached its real result screen")
	sandbox._toggle_setup()
	assert_true(sandbox._setup.visible)
	assert_false(sandbox._battle._modal.visible, "results cannot overlay Setup")
	sandbox._show_setup(false)
	assert_true(sandbox._battle._modal.visible, "returning restores the result layer")
	assert_false(sandbox._battle._pause_panel.visible)
	sandbox.queue_free()

func test_timeline_click_does_not_capture_subsequent_hover() -> void:
	var scene := await _battle()
	_move(scene._timeline.get_global_rect().get_center())
	await _frames(6)
	var click := InputEventMouseButton.new()
	click.position = scene._timeline.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_tree.root.push_input(click, true)
	click.pressed = false
	_tree.root.push_input(click, true)
	var enemy := scene.engine.get_state().enemies()[0]
	_move(scene._battlefield.body_point(enemy.uid))
	await _frames(10)
	assert_true(scene._inspector.shown_text().contains(enemy.display_name), "timeline focus never overrides pointer inspection")
	_move(scene._menu._buttons[0].get_global_rect().get_center())
	await _frames(10)
	assert_true(scene._inspector._card.visible, "action uses the same structured card")
	scene.queue_free()

func test_long_inspection_scrolls_from_source_and_inside_card() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	_tree.root.add_child(host)
	var icon := Button.new()
	icon.position = Vector2(40, 500)
	icon.size = Vector2(120, 45)
	icon.tooltip_text = "Long rule\n" + "A condition with a readable explanation.\n".repeat(50)
	host.add_child(icon)
	var inspector := HoverInspector.new()
	inspector.bounds_provider = func() -> Rect2: return Rect2(24, 120, 1232, 310)
	host.add_child(inspector)
	_move(icon.get_global_rect().get_center())
	await _frames(12)
	assert_true(inspector.visible)
	assert_gt(inspector._scroll.get_v_scroll_bar().max_value, inspector._scroll.size.y, "actual overflow exists")
	_wheel(icon.get_global_rect().get_center())
	await _frames(3)
	assert_gt(inspector._scroll.scroll_vertical, 0, "wheel over inspected source scrolls its card")
	var before := inspector._scroll.scroll_vertical
	_move(inspector.get_global_rect().get_center())
	await _frames(3)
	_wheel(inspector.get_global_rect().get_center())
	await _frames(3)
	assert_gt(inspector._scroll.scroll_vertical, before, "wheel also works within the card")
	assert_true(inspector.visible, "entering the card preserves it for scrollbar interaction")
	host.queue_free()

func test_practice_footer_and_scrolling_fit_supported_resolutions_and_text_sizes() -> void:
	for scale in [1.0, 1.5, 2.0]:
		_tree.root.theme = UITheme.build(scale)
		for resolution in GameSettings.RESOLUTIONS:
			var sandbox: CombatSandbox = load("res://scenes/sandbox/combat_sandbox.tscn").instantiate()
			_tree.root.add_child(sandbox)
			sandbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
			sandbox.size = Vector2(resolution)
			sandbox.show_view(CombatSandbox.View.PRACTICE)
			await _frames(5)
			var footer := sandbox._hide_button.get_parent_control()
			assert_lte(footer.get_global_rect().end.y, sandbox.size.y, "footer stays on screen")
			assert_lte(footer.get_global_rect().end.x, sandbox.size.x, "footer fits horizontally")
			var scroll := sandbox._practice_page.get_parent_control() as ScrollContainer
			assert_not_null(scroll, "practice content has a bounded scroll area")
			assert_gte(sandbox._practice_encounter.global_position.y, scroll.global_position.y, "Practice opens at the encounter selector, never partway down")
			assert_lte(sandbox._practice_encounter.get_global_rect().end.y, scroll.get_global_rect().end.y, "initial selector is fully visible")
			assert_lte(scroll.get_global_rect().end.y, footer.global_position.y, "scroll never pushes footer off-screen")
			sandbox.show_view(CombatSandbox.View.LAB)
			await _frames(3)
			assert_false(scroll.visible, "Lab never inherits an empty practice scroll area")
			sandbox.queue_free()
			await _frames(1)

func test_health_break_and_move_card_reactions_have_individual_explanations() -> void:
	var scene := await _battle()
	await _frames(5)
	var enemy := scene.engine.get_state().enemies()[0]
	var view := scene._battlefield.view(enemy.uid)
	assert_gte(view._regions.size(), 2)
	assert_true(view._get_tooltip((view._regions[0].rect as Rect2).get_center()).contains("Health"))
	assert_true(view._get_tooltip((view._regions[1].rect as Rect2).get_center()).contains("Break remaining"))
	var slot := scene._rail.slot(enemy.uid)
	var found := 0
	for region in slot._regions:
		if str(region.text).contains("against this move"):
			found += 1
			assert_eq(slot._get_tooltip((region.rect as Rect2).get_center()), region.text)
	assert_eq(found, 0, "the stage does not repeat reaction icons from the move card")
	_move(slot.global_position + Vector2(41, 15))
	await _frames(10)
	assert_not_null(scene._inspector._card._intent_readout, "enemy move uses the shared structured card")
	assert_eq(scene._inspector._card._intent_readout, slot.readout, "card reads the displayed intent, never resolves a future one")
	assert_false(scene._inspector.get_global_rect().intersects(scene._menu.get_global_rect()))
	assert_lt(scene._inspector.position.x, scene.size.x / 2, "enemy inspection stays opposite the enemy source")
	var card := scene._inspector._card
	var reactions := 0
	for region in card._regions:
		if str(region.text).begins_with("Brace") or str(region.text).begins_with("Evade") or str(region.text).begins_with("Parry"):
			reactions += 1
	assert_eq(reactions, 3, "move inspection retains each reaction's own legality explanation")
	assert_false(PreviewPanel.threat_label(slot.readout).contains("!"))
	assert_true(PreviewPanel.threat_label(slot.readout).contains("threat"))
	assert_lte((card._regions[0].rect as Rect2).end.x, card._summary.size.x, "named threat fits the right corner")
	var threat := (card._regions[0].rect as Rect2).get_center()
	_move(card._summary.get_global_transform_with_canvas() * threat)
	await _frames(5)
	assert_true(scene._inspector._hint.text.contains("Threat"), "a field inside a card explains itself without a second popup")
	assert_eq(scene._inspector._card._intent_readout, slot.readout, "field hover retains its parent move")
	scene.queue_free()

func test_action_list_owns_wheel_over_buttons_and_plain_fields_have_no_false_alt_hint() -> void:
	var scene := await _battle()
	# Exercise a constrained dock with the actual buttons, independent of current loadout count.
	scene._menu.size.y = 120
	await _frames(4)
	var scroll := scene._menu._action_scroll
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y, "real action list overflows")
	scroll.scroll_vertical = 0
	_move(scene._menu._buttons[0].get_global_rect().get_center())
	await _frames(8)
	_wheel(scene._menu._buttons[0].get_global_rect().get_center())
	await _frames(4)
	assert_gt(scroll.scroll_vertical, 0, "hovering a button still scrolls its action list")
	var enemy := scene.engine.get_state().enemies()[0]
	var view := scene._battlefield.view(enemy.uid)
	_move(view.global_position + (view._regions[0].rect as Rect2).get_center())
	await _frames(10)
	assert_false(scene._inspector._hint.text.contains("Alt"), "a simple health field advertises no nonexistent expansion")
	assert_false(scene._inspector._hint.text.contains("Wheel"))
	scene.queue_free()

func test_expanded_action_details_own_wheel_over_the_action_source() -> void:
	var scene := await _battle()
	scene._menu.size.y = 120
	var actor := scene._picker.acting_unit()
	scene._menu.preview_provider = func(option: ActionOption) -> ActionReadout:
		var readout := ActionReadout.build(scene.engine, actor.uid, option)
		readout.details += "\n" + "A long rule explanation for scrolling.\n".repeat(35)
		return readout
	await _frames(4)
	var source := scene._menu._buttons[0]
	var point := source.get_global_rect().get_center()
	_move(point)
	await _frames(8)
	Input.action_press(InputBindings.INFO)
	await _frames(5)
	assert_true(scene._inspector.expanded)
	var detail_scroll := scene._inspector._scroll
	var list_scroll := scene._menu._action_scroll
	assert_gt(detail_scroll.get_v_scroll_bar().max_value, detail_scroll.size.y)
	assert_gt(list_scroll.get_v_scroll_bar().max_value, list_scroll.size.y)
	list_scroll.scroll_vertical = 0
	detail_scroll.scroll_vertical = 0
	_wheel(point)
	await _frames(3)
	assert_gt(detail_scroll.scroll_vertical, 0, "Alt details scroll while the pointer stays on the action")
	assert_eq(list_scroll.scroll_vertical, 0, "the same wheel event cannot move both views")
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	_tree.root.push_input(up, true)
	await _frames(3)
	assert_eq(detail_scroll.scroll_vertical, 0, "expanded details scroll back up from the source")
	Input.action_release(InputBindings.INFO)
	await _frames(4)
	_wheel(point)
	await _frames(3)
	assert_gt(list_scroll.scroll_vertical, 0, "releasing Alt restores normal list scrolling")
	scene.queue_free()

func test_wheel_ownership_ignores_handler_order_and_covers_supplies_and_enemy_sources() -> void:
	var scene := await _battle()
	# Put the inspector before the menu, so the menu's input callback now runs first. The one
	# shared wheel rule must still decide; this ordering previously sent the wheel to the list.
	scene.move_child(scene._inspector, scene._menu.get_index())
	scene._menu.size.y = 120
	scene._supplies.size.y = 64
	var actor := scene._picker.acting_unit()
	scene._menu.preview_provider = func(option: ActionOption) -> ActionReadout:
		var readout := ActionReadout.build(scene.engine, actor.uid, option)
		readout.details += "\n" + "A long rule explanation for scrolling.\n".repeat(35)
		return readout
	await _frames(4)
	var details := scene._inspector._scroll
	for list: ScrollContainer in [scene._menu._action_scroll, scene._menu._supply_scroll]:
		var source: Button
		for button in scene._menu._buttons:
			if list.is_ancestor_of(button):
				source = button
				break
		assert_not_null(source)
		assert_gt(list.get_v_scroll_bar().max_value, list.size.y, "the constrained list overflows")
		# A point over the button that is inside the list's visible (clipped) area.
		var point := Vector2(source.get_global_rect().get_center().x, list.get_global_rect().position.y + minf(10, list.size.y * 0.5))
		list.scroll_vertical = 0
		_move(point)
		assert_true(await _inspecting(scene, source), "the card adopts the hovered source")
		Input.action_press(InputBindings.INFO)
		await _frames(5)
		assert_true(scene._inspector.expanded)
		details.scroll_vertical = 0
		_wheel(point)
		await _frames(3)
		assert_gt(details.scroll_vertical, 0, "expanded details own the wheel over their source")
		assert_eq(list.scroll_vertical, 0, "one wheel event moves one pane")
		Input.action_release(InputBindings.INFO)
		await _frames(4)
		_wheel(point)
		await _frames(3)
		assert_gt(list.scroll_vertical, 0, "collapsed inspection: the hovered list scrolls")
		list.scroll_vertical = 0
	# An enemy body is not inside a list: its card scrolls from the source.
	var enemy := scene.engine.get_state().enemies()[0]
	scene._inspector.bounds_provider = func() -> Rect2: return Rect2(24, 140, 1232, 110)
	_move(scene._battlefield.body_point(enemy.uid))
	assert_true(await _inspecting(scene, scene._battlefield.view(enemy.uid)), "the card adopts the enemy source")
	Input.action_press(InputBindings.INFO)
	await _frames(6)
	assert_true(scene._inspector._unit_card.visible)
	assert_gt(details.get_v_scroll_bar().max_value, details.size.y, "expanded enemy analysis overflows the constrained card")
	details.scroll_vertical = 0
	_wheel(scene._battlefield.body_point(enemy.uid))
	await _frames(3)
	assert_gt(details.scroll_vertical, 0, "wheel over the enemy source scrolls its card")
	Input.action_release(InputBindings.INFO)
	scene.queue_free()

func test_single_ally_intercept_requires_explicit_target_and_cancel_spends_nothing() -> void:
	var scene := await _battle()
	Engine.time_scale = 20
	if scene._picker.acting_unit().definition.id != &"mara":
		for button in scene._menu._buttons:
			if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
				button.pressed.emit()
				break
	var deadline := Time.get_ticks_msec() + 6000
	while (not scene._picker.is_active() or scene._picker.acting_unit().definition.id != &"mara") and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	Engine.time_scale = 1
	assert_eq(scene._picker.acting_unit().definition.id, &"mara")
	var intercept: Button
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"intercept":
			intercept = button
	assert_not_null(intercept)
	var option: ActionOption = intercept.get_meta(&"option")
	assert_eq(option.target_uids.size(), 1)
	var log_size := scene.engine.input_log.size()
	var focus := scene._picker.acting_unit().focus
	intercept.pressed.emit()
	await _frames(3)
	assert_true(scene._picker.is_targeting(), "one legal ally does not auto-commit")
	assert_eq(scene.engine.input_log.size(), log_size)
	assert_eq(scene._target_prompt.text, "Pick an ally")
	assert_true(scene._target_prompt.visible)
	assert_false(scene._target_prompt.get_global_rect().intersects(scene._inspector.get_global_rect()), "recipient guidance stays above contextual inspection")
	scene._picker.back_to_menu()
	assert_eq(scene.engine.input_log.size(), log_size, "cancel spends no action")
	assert_eq(scene._picker.acting_unit().focus, focus, "cancel spends no Focus")
	intercept.pressed.emit()
	var target := option.target_uids[0]
	var at := scene._battlefield.body_point(target)
	_move(at)
	var click := InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_tree.root.push_input(click, true)
	click.pressed = false
	_tree.root.push_input(click, true)
	await _frames(4)
	assert_false(scene._picker.is_targeting())
	assert_gt(scene.engine.input_log.size(), log_size)
	var submitted := scene.engine.input_log.filter(func(entry: Dictionary) -> bool: return entry.kind == "action" and entry.action == "intercept")
	assert_eq(submitted.size(), 1, "target click submits Intercept exactly once")
	assert_eq(int(submitted[0].target), target)
	assert_false(scene._target_prompt.visible, "guidance clears after committing")
	scene.queue_free()

func test_structured_unit_readout_uses_presented_values_and_gates_affinities() -> void:
	var scene := await _battle()
	var enemy := scene.engine.get_state().enemies()[0]
	var display := scene._events.ledger.unit(enemy.uid)
	var previous_hp := display.hp
	enemy.hp = 1 # Engine resolved ahead; the visible card must not disclose it.
	var r := scene._unit_readout(enemy.uid)
	assert_eq(r.hp, roundi(previous_hp))
	assert_eq(r.intent, scene._rail.slot(enemy.uid).readout)
	for affinity in r.affinities:
		assert_eq(affinity.category, "Unknown")
	enemy.inspected = true
	r = scene._unit_readout(enemy.uid)
	assert_false(r.affinities.any(func(entry: Dictionary) -> bool: return entry.category == "Unknown"))
	assert_true(r.affinities.any(func(entry: Dictionary) -> bool: return entry.category in ["Normal damage", "Weakness", "Resistance"]))
	var playback := UnitReadout.build(scene.engine, enemy, display, r.intent, false)
	assert_true(playback.affinities.is_empty(), "new knowledge cannot leak ahead of playback")
	assert_true(playback.knowledge.is_empty())
	_move(scene._battlefield.body_point(enemy.uid))
	await _frames(8)
	var alt := InputBindings.event_from_code("key:Alt")
	alt.pressed = true
	Input.parse_input_event(alt)
	await _frames(5)
	assert_true(scene._inspector._unit_card.visible)
	assert_eq(scene._inspector._content.body.scale, Vector2.ONE * InspectionContent.CONTENT_SCALE)
	assert_eq(scene._inspector._text.get_theme_font_size("normal_font_size"), UITheme.secondary_size(), "native font raster size is retained")
	_move(scene._inspector.get_global_rect().get_center())
	await _frames(3)
	alt.pressed = false
	Input.parse_input_event(alt)
	await _frames(5)
	assert_false(scene._inspector.expanded, "releasing over the card itself also collapses it")
	scene.queue_free()

func test_confirm_mirror_has_no_unrequested_builtin_accept_keys() -> void:
	InputBindings.install()
	var space := InputBindings.event_from_code("key:Space")
	space.pressed = true
	assert_false(space.is_action(InputBindings.CONFIRM))
	assert_false(space.is_action(&"ui_accept"), "Godot's native Space default must also be removed")
	assert_true(space.is_action(InputBindings.COMMAND), "Space remains the timing command")
	InputBindings.install({InputBindings.CONFIRM: ["key:K", "joy:0"]})
	var enter := InputBindings.event_from_code("key:Enter")
	enter.pressed = true
	assert_false(enter.is_action(&"ui_accept"), "rebinding must remove the old native Enter default")
	var rebound := InputBindings.event_from_code("key:K")
	rebound.pressed = true
	assert_true(rebound.is_action(&"ui_accept"))

func test_resolution_setting_round_trip_and_safe_fallback() -> void:
	var settings := GameSettings.new()
	settings.window_resolution = Vector2i(1920, 1080)
	var config := ConfigFile.new()
	settings.write_to(config)
	var restored := GameSettings.new()
	restored.read_from(config)
	assert_eq(restored.window_resolution, Vector2i(1920, 1080))
	config.set_value("display", "window_resolution", Vector2i(-1, 0))
	restored.read_from(config)
	assert_eq(restored.window_resolution, Vector2i(1280, 720))
	restored.read_from(ConfigFile.new())
	assert_eq(restored.window_resolution, Vector2i(1280, 720))

func test_details_toggle_and_always_modes_keep_their_selected_behavior() -> void:
	var scene := await _battle()
	var alt := InputBindings.event_from_code("key:Alt")
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.TOGGLE
	alt.pressed = true
	Input.parse_input_event(alt)
	await _frames(2)
	alt.pressed = false
	Input.parse_input_event(alt)
	await _frames(4)
	assert_true(scene._inspector.expanded, "Toggle remains expanded after release")
	alt.pressed = true
	Input.parse_input_event(alt)
	await _frames(2)
	alt.pressed = false
	Input.parse_input_event(alt)
	await _frames(4)
	assert_false(scene._inspector.expanded, "a second toggle collapses it")
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.ALWAYS
	scene._set_details(false)
	await _frames(4)
	assert_true(scene._inspector.expanded, "Always is not overridden by Hold polling")
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.HOLD
	await _frames(4)
	assert_false(scene._inspector.expanded, "Hold follows released state after a mode change")
	scene.queue_free()

func test_support_cards_restore_authored_rules_without_empty_outcomes() -> void:
	var scene := await _battle()
	var actor := scene.engine.get_state().party()[0]
	var companion := scene.engine.get_state().party()[1]
	for id in [&"guard", &"intercept", &"focus_tincture"]:
		var action: ActionDefinition
		if id == &"focus_tincture":
			action = Database.registry.potions[id].action
		else:
			action = Database.registry.actions[id]
		var option := ActionOption.new()
		option.action = action
		option.legal = true
		option.target_uids.append(actor.uid)
		var readout := ActionReadout.build(scene.engine, companion.uid if id == &"intercept" else actor.uid, option, actor.uid)
		var details := PreviewPanel.describe_details(readout)
		assert_true(details.contains(action.description), "expanded support card always contains its rule explanation")
		assert_false(details.contains("[b]Details[/b]"), "no empty Details heading")
		var card := PreviewPanel.new()
		scene.add_child(card)
		card.size = Vector2(510, PreviewPanel.action_height(readout))
		card.show_readout(readout)
		await _frames(3)
		var fields := PackedStringArray()
		for region in card._regions:
			fields.append(region.text)
			assert_true(Rect2(Vector2.ZERO, card._summary.size).encloses(region.rect), "support field fits its card")
		assert_false("\n".join(fields).contains("—"), "a support action has no fabricated damage dash")
		if id == &"guard":
			assert_true(details.contains("40%"))
			assert_true("\n".join(fields).contains("+1 Focus"))
		elif id == &"intercept":
			assert_true("\n".join(fields).contains("Cover ally"))
			assert_true(details.contains("25%"))
		else:
			assert_true("\n".join(fields).contains("+4 Focus"))
			assert_false("\n".join(fields).contains("Healing / support"))
		card.queue_free()
	scene.queue_free()

func test_condition_announcements_dock_and_reduced_motion_stays_still() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	_tree.root.add_child(host)
	var ledger := PresentationLedger.new()
	var condition: BattlefieldConditionDefinition = Database.registry.conditions[&"flooded_ground"]
	ledger.conditions.append(condition)
	var ribbon := ConditionRibbon.new()
	ribbon.ledger = ledger
	ribbon.position = Vector2(900, 10)
	host.add_child(ribbon)
	ribbon.refresh()
	var banner := Banner.new()
	banner.ribbon = ribbon
	host.add_child(banner)
	await _frames(3)
	assert_true(ribbon.icon_for(condition.id) != null)
	for reduced in [false, true]:
		banner.announce_condition(condition, 0.02, reduced, 4.0)
		await _frames(3)
		var start := banner.position
		var seen_flight := false
		var seen_compression := false
		var deadline := Time.get_ticks_msec() + 2000
		while banner.visible and Time.get_ticks_msec() < deadline:
			seen_flight = seen_flight or banner.flying
			seen_compression = seen_compression or banner.scale.x < 0.9
			if reduced:
				assert_eq(banner.scale, Vector2.ONE, "reduced motion never compresses")
				assert_eq(banner.position, start, "reduced motion never flies")
			await _tree.process_frame
		assert_false(banner.visible, "announcement completes")
		assert_eq(seen_flight, not reduced)
		assert_eq(seen_compression, not reduced, "only the motion-enabled card compresses")
		if not reduced:
			assert_true(banner.position.distance_to(ribbon.icon_for(condition.id).get_global_rect().get_center()) < 50, "card arrives at the matching header icon")
		assert_false(ribbon.icon_for(condition.id).has_theme_stylebox_override("normal"), "arrival highlight clears")
	# A condition disappearing while its card is held falls back to a fade, never a freed target.
	ledger.conditions.clear()
	ribbon.refresh()
	assert_eq(ribbon.icon_for(condition.id), null)
	await banner.announce_condition(condition, 0.01, false, 10.0)
	assert_false(banner.flying)
	host.queue_free()

func test_existing_cast_has_art_and_familiar_footing_preserves_proportions() -> void:
	for actor in Database.registry.protagonists.values() + Database.registry.companions.values():
		assert_true(actor.sprite_frames != null, "party art: " + String(actor.id))
	for enemy in Database.registry.enemies.values():
		assert_true(enemy.sprite_frames != null, "enemy art: " + String(enemy.id))
	for familiar in Database.registry.familiars.values():
		assert_true(familiar.portrait != null, "familiar art: " + String(familiar.id))
		var card := FamiliarCard.new()
		_tree.root.add_child(card)
		card.setup(familiar, null)
		card.size = card.stage_size()
		var rect := card.art_rect()
		assert_true(Rect2(Vector2.ZERO, card.size).encloses(rect) and rect.size.x > 0, "familiar fits inside its actual stage slot")
		assert_true(is_equal_approx(rect.end.y, card.size.y - 8), "paws share the slot baseline")
		assert_true(is_equal_approx(rect.size.aspect(), familiar.portrait.get_size().aspect()), "pet artwork is never stretched")
		card.queue_free()
	var track := Rect2(0, 0, 200, 12)
	assert_eq(ResourceBarArt.fill_rect(track, 0).size.x, 0.0, "zero health is truly empty")
	assert_eq(ResourceBarArt.fill_rect(track, 1).size.x, 196.0, "full health stays inside the rim")
	assert_eq(ResourceBarArt.fill_rect(track, 0.5).size.x, 98.0)
	assert_true(ResourceBarArt.TRACK is StyleBoxTexture)
	assert_true(ResourceBarArt.BREAK is StyleBoxTexture)

func test_compact_terrain_feedback_stays_below_header() -> void:
	var overlay := Control.new()
	_tree.root.add_child(overlay)
	_tree.root.theme = UITheme.build(2.0)
	var bounds := Rect2(24, 156, 1232, 220)
	var text := FloatingText.spawn(overlay, Vector2(160, 160), "Wet · Flooded Ground", UITheme.WET, 0.9, 1.0, InspectionContent.CONTENT_SCALE, bounds)
	assert_eq(text.scale, Vector2.ONE * InspectionContent.CONTENT_SCALE)
	assert_true(text.position.y >= bounds.position.y)
	assert_true(text.position.x >= bounds.position.x)
	await _frames(5)
	assert_true(text.position.y >= bounds.position.y, "rising terrain feedback never overlaps the header")
	text.queue_free()
	overlay.queue_free()

func test_cinder_pup_grows_without_changing_its_floor_or_ally_slot() -> void:
	var scene := await _battle()
	var floor_y := scene._familiar.get_global_rect().end.y - 8
	var before := scene._familiar.size
	var pup: FamiliarDefinition = Database.registry.familiars[&"cinder_pup"]
	scene.engine.get_state().familiar = pup
	scene._familiar.setup(pup, scene._events.ledger)
	scene._place_dynamic()
	assert_eq(scene._familiar.size, Vector2(62, 70))
	assert_gt(scene._familiar.size.x, before.x)
	assert_true(is_equal_approx(scene._familiar.get_global_rect().end.y - 8, floor_y), "larger pup keeps the existing paw baseline")
	assert_gte(scene._familiar.global_position.x, scene._battlefield.global_position.x, "larger familiar stays on the stage")
	scene.queue_free()

func test_manual_attack_has_a_real_preparation_beat_and_no_buffered_press() -> void:
	var scene := await _battle()
	scene._executor = null
	Engine.time_scale = 20
	var button: Button
	for candidate in scene._menu._buttons:
		var option: ActionOption = candidate.get_meta(&"option")
		if option.legal and option.action.deals_damage():
			button = candidate
			break
	assert_not_null(button)
	button.pressed.emit()
	if scene._picker.is_targeting():
		scene._picker.click(scene._picker.reviewed_target_uid())
	var deadline := Time.get_ticks_msec() + 5000
	while not scene._preparing and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	assert_true(scene._preparing)
	assert_false(scene._idle.visible, "no separate preparation box replaces the timing display")
	assert_eq(scene._timed_host.get_child_count(), 1, "the real timing UI is visible during preparation")
	var widget := scene._timed_host.get_child(0) as CommandWidget
	assert_not_null(widget)
	assert_true(widget.is_preparing() and widget.clock.is_frozen())
	assert_eq(widget.elapsed_ms(), 0.0)
	var preparation_started := Time.get_ticks_usec() - int(scene._preparation_tween.get_total_elapsed_time() * 1000000)
	var log_count := scene.engine.input_log.size()
	Input.action_press(InputBindings.COMMAND)
	var press := InputEventAction.new()
	press.action = InputBindings.COMMAND
	press.pressed = true
	_tree.root.push_input(press, true)
	await _frames(3)
	assert_eq(scene.engine.input_log.size(), log_count, "a preparation press submits no timing result")
	assert_eq(widget.elapsed_ms(), 0.0, "the visible timing marker stays at its start")
	assert_false(widget.is_done(), "early preview input cannot grade a command")
	scene._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var frozen := scene._preparation_tween.get_total_elapsed_time()
	await _frames(5)
	assert_eq(scene._preparation_tween.get_total_elapsed_time(), frozen, "focus loss freezes the preparation beat")
	scene._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	while scene._preparing and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	assert_false(scene._preparing)
	assert_gte((Time.get_ticks_usec() - preparation_started) / 1000.0, BattleScene.PREPARATION_MS - 35, "Combat Speed/time_scale cannot shorten the real preparation beat")
	assert_eq(scene._timed_host.get_child(0), widget, "the preview becomes live without replacing the UI")
	assert_false(widget.is_preparing())
	assert_lt(widget.elapsed_ms(), 100, "the actual timing clock starts after preparation")
	assert_true(widget.latch.is_latched(InputBindings.COMMAND), "a button held through preparation must be released")
	assert_false(widget.is_done())
	Input.action_release(InputBindings.COMMAND)
	widget._finish(Enums.ExecutionGrade.GOOD)
	scene.queue_free()

func test_manual_reaction_preparation_preserves_impact_and_fresh_input() -> void:
	var scene := await _battle()
	scene._executor = null
	scene.launch.autoplay = true
	Engine.time_scale = 20
	# Commit this planning turn, then let the real presenter reach a defensive request.
	for button in scene._menu._buttons:
		if (button.get_meta(&"option") as ActionOption).action.id == &"guard":
			button.pressed.emit()
			break
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var request := scene.engine.get_request()
		if scene._preparing and request != null and request.kind == BattleRequest.Kind.REACTION:
			break
		for child in scene._timed_host.get_children():
			if child is CommandWidget and not child.is_preparing() and not child.is_done():
				child._finish(Enums.ExecutionGrade.GOOD)
		await _tree.process_frame
	assert_true(scene._preparing)
	var request := scene.engine.get_request() as ReactionRequest
	assert_not_null(request)
	if request == null:
		scene.queue_free()
		return
	var widget: ReactionWidget
	for child in scene._overlay.get_children():
		if child is ReactionWidget:
			widget = child
	assert_not_null(widget, "the real reaction ring and cards are present during preparation")
	assert_true(widget.is_preparing())
	assert_false(widget._running)
	assert_eq(widget.elapsed_ms(), 0.0)
	assert_false(scene._idle.visible)
	var reaction: Enums.ReactionType = request.spec.allowed[0]
	var key: StringName = ReactionReadout.KEYS[reaction]
	Input.action_press(key)
	var press := InputEventAction.new()
	press.action = key
	press.pressed = true
	_tree.root.push_input(press, true)
	await _frames(3)
	assert_eq(widget.chosen(), Enums.ReactionType.NONE, "preview input cannot lock a reaction")
	assert_eq(widget.elapsed_ms(), 0.0)
	assert_false(widget.invites_press(reaction))
	scene._preparation_tween.custom_step(BattleScene.PREPARATION_MS / 1000.0)
	await _frames(3)
	var live_widget: ReactionWidget
	for child in scene._overlay.get_children():
		if child is ReactionWidget:
			live_widget = child
	assert_eq(live_widget, widget, "the same preview ring becomes live")
	assert_false(widget.is_preparing())
	assert_eq(widget.spec, request.spec, "same rules and reaction windows")
	assert_eq(widget.impact_ms(), request.spec.windup_ms)
	assert_lt(widget.elapsed_ms(), 100, "full windup starts after the breathing beat")
	assert_eq(widget.chosen(), Enums.ReactionType.NONE)
	assert_true(widget.latch.is_latched(key), "held reaction cannot spill into the new window")
	Input.action_release(key)
	widget.latch.poll()
	widget.clock.set_elapsed(widget.impact_ms())
	widget._input(press)
	assert_eq(widget.chosen(), reaction)
	assert_true(widget._success, "the existing exact-impact grade remains unchanged")
	scene.queue_free()

func test_restart_during_preparation_cancels_its_wait() -> void:
	var scene := await _battle()
	scene._begin_timed()
	var widget := TimingWidget.new()
	scene._timed_host.add_child(widget)
	widget.begin(CommandSpec.new(), "Restart test", true)
	scene._prepare_timed()
	var tween := scene._preparation_tween
	assert_true(scene._preparing)
	scene.queue_free()
	await _frames(4)
	assert_false(is_instance_valid(scene))
	assert_false(is_instance_valid(widget), "the visible preview belongs to the replaced battle")
	assert_false(tween.is_valid(), "preparation tween belongs to the replaced battle")

func test_banner_fits_settled_text_and_shrinks_between_announcements() -> void:
	for text_scale in [1.0, 1.5, 2.0]:
		_tree.root.theme = UITheme.build(text_scale)
		for dimensions in [Vector2(1280, 720), Vector2(1920, 1080)]:
			var host := Control.new()
			host.size = dimensions
			_tree.root.add_child(host)
			var banner := Banner.new()
			host.add_child(banner)
			var title_height := 0.0
			for body in ["", "The enemy moves first. Read its declared move before reacting.", ""]:
				banner.announce("Custom" if body.is_empty() else "Ambushed!", body, 0.01)
				await _frames(6)
				assert_true(banner.visible)
				assert_lte(banner._panel.size.y, banner._panel.get_combined_minimum_size().y + 1, "temporary narrow wrapping cannot leave a tall empty panel")
				assert_true(Rect2(Vector2.ZERO, dimensions).encloses(banner._panel.get_global_rect()), "the full announcement remains on screen")
				assert_true(banner._panel.get_global_rect().encloses(banner._title.get_global_rect()))
				assert_eq(banner._body.visible, not body.is_empty())
				if body.is_empty():
					if title_height == 0:
						title_height = banner.size.y
					else:
						assert_eq(banner.size.y, title_height, "a later title-only card sheds the previous body height")
					assert_lt(banner.size.y, 80, "an encounter title never becomes a full-height box")
				banner._tween.custom_step(2.0)
				await _frames(2)
				assert_false(banner.visible)
			await banner.announce("", "", 0.0)
			assert_false(banner.visible, "empty content never opens a card")
			host.queue_free()
			await _frames(2)

func test_opening_and_condition_announcements_suppress_then_restore_hover() -> void:
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_bow"], registry.encounters[&"fen_patrol"], Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	setup.label = "Custom"
	var scene: BattleScene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	scene.start(launch)
	await _frames(6)
	assert_eq(scene._banner._title.text, "Custom")
	assert_true(scene._banner.visible)
	_move(scene._battlefield.body_point(scene.engine.get_state().party()[0].uid))
	Input.action_press(InputBindings.INFO)
	await _frames(4)
	assert_false(scene._inspector.visible, "expanded hover cannot cover the first announcement")
	Engine.time_scale = 20
	var seen_condition := false
	var clear_during_announcements := true
	var deadline := Time.get_ticks_msec() + 6000
	while not scene._picker.is_active() and Time.get_ticks_msec() < deadline:
		if scene._banner.visible:
			seen_condition = seen_condition or scene._banner._title.text == "Flooded Ground"
			clear_during_announcements = clear_during_announcements and not scene._inspector.visible
			if scene._banner._tween != null and scene._banner._tween.is_valid():
				scene._banner._tween.custom_step(5.0)
		await _tree.process_frame
	assert_true(seen_condition, "the opening still explains its actual battlefield condition")
	assert_true(clear_during_announcements)
	assert_true(scene._picker.is_active())
	Engine.time_scale = 1
	Input.action_release(InputBindings.INFO)
	_move(scene._battlefield.body_point(scene.engine.get_state().party()[0].uid))
	await _frames(8)
	assert_true(scene._inspector.visible, "hover returns normally once announcements end")
	# Starting a later round/result banner clears an already-open card synchronously.
	scene._banner.announce("Round 2", "", 0.01)
	assert_false(scene._inspector.visible)
	scene.queue_free()

func test_all_command_previews_ignore_input_then_grade_in_the_same_widget() -> void:
	Engine.time_scale = 20
	for type in [Enums.ActionCommandType.TIMING, Enums.ActionCommandType.HOLD_RELEASE, Enums.ActionCommandType.RHYTHM, Enums.ActionCommandType.OPTIONAL_AIM]:
		var spec := CommandSpec.new()
		spec.type = type
		var widget := BattleScene.make_command_widget(type)
		_tree.root.add_child(widget)
		widget.size = Vector2(1030, 266)
		widget.begin(spec, "Preview → Target", true)
		var press := InputEventAction.new()
		press.action = InputBindings.COMMAND
		press.pressed = true
		var release := InputEventAction.new()
		release.action = InputBindings.COMMAND
		release.pressed = false
		widget._input(press)
		widget._input(release)
		await _frames(3)
		assert_eq(widget.elapsed_ms(), 0.0)
		assert_false(widget.is_done())
		if widget is HoldReleaseWidget:
			assert_false(widget.is_holding(), "preview presses cannot begin charging")
		elif widget is RhythmWidget:
			assert_true(widget._presses.is_empty(), "preview presses cannot spend a beat")
		widget.start_timing()
		assert_false(widget.is_preparing())
		assert_eq(widget.spec, spec)
		if type == Enums.ActionCommandType.HOLD_RELEASE:
			widget._input(press)
			widget.clock.advance(spec.target_time_ms())
			widget._input(release)
		elif type == Enums.ActionCommandType.RHYTHM:
			for beat in spec.beat_count:
				widget.clock.set_elapsed(spec.beat_time_ms(beat))
				widget._input(press)
		else:
			widget.clock.set_elapsed(spec.target_time_ms())
			widget._input(press)
		var grade: Enums.ExecutionGrade = await widget.finished
		assert_eq(grade, Enums.ExecutionGrade.PERFECT, "preparation never changes grading or leaves a buffered attempt")
		widget.queue_free()
		await _frames(2)

func test_reaction_preview_preserves_pause_assist_and_latches_held_confirm() -> void:
	var spec := ReactionSpec.new()
	spec.allowed = [Enums.ReactionType.BRACE] as Array[Enums.ReactionType]
	spec.pause_before = true
	var widget := ReactionWidget.new()
	_tree.root.add_child(widget)
	widget.size = Vector2(1280, 720)
	var starts: Array[int] = [0]
	widget.started.connect(func() -> void: starts[0] += 1)
	widget.begin(spec, ReactionReadout.for_spec(spec, "Tester", "Heavy attack"), [Vector2(700, 280)] as Array[Vector2], Rect2(24, 488, 1030, 186), true)
	var confirm := InputEventAction.new()
	confirm.action = InputBindings.CONFIRM
	confirm.pressed = true
	var brace := InputEventAction.new()
	brace.action = InputBindings.BRACE
	brace.pressed = true
	Input.action_press(InputBindings.CONFIRM)
	Input.action_press(InputBindings.BRACE)
	widget._input(confirm)
	widget._input(brace)
	await _frames(3)
	assert_eq(starts[0], 0)
	assert_eq(widget.chosen(), Enums.ReactionType.NONE)
	assert_eq(widget.elapsed_ms(), 0.0)
	assert_false(widget.invites_press(Enums.ReactionType.BRACE))
	widget.start_timing()
	assert_true(widget.is_waiting_for_start())
	widget._input(confirm)
	assert_eq(starts[0], 0, "held Confirm cannot skip the assist pause")
	Input.action_release(InputBindings.CONFIRM)
	widget.latch.poll()
	widget._input(confirm)
	assert_eq(starts[0], 1, "one fresh Confirm starts the existing sequence")
	assert_false(widget.is_waiting_for_start())
	widget._input(brace)
	assert_eq(widget.chosen(), Enums.ReactionType.NONE, "held Brace cannot cross either preparation boundary")
	Input.action_release(InputBindings.BRACE)
	widget.latch.poll()
	widget.clock.set_elapsed(widget.impact_ms())
	widget._input(brace)
	assert_eq(widget.chosen(), Enums.ReactionType.BRACE)
	assert_true(widget._success)
	widget.queue_free()

func _battle() -> BattleScene:
	Engine.time_scale = 20
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"fen_patrol"], Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
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
	assert_true(scene._picker.is_active())
	Engine.time_scale = 1
	await _frames(4)
	return scene

func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame

## Waits (real time) until the inspector shows [param source]; replacing a subject settles briefly.
func _inspecting(scene: BattleScene, source: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while scene._inspector._source != source and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return scene._inspector._source == source

## Visible framed panels over the stage, other than those nested inside the inspector's own card.
func _stage_panels(scene: BattleScene) -> Array:
	var stage := scene._battlefield.get_global_rect()
	return scene.find_children("*", "PanelContainer", true, false).filter(func(node: Node) -> bool:
		var panel := node as Control
		return panel.is_visible_in_tree() and panel.get_global_rect().intersects(stage) and not scene._inspector.is_ancestor_of(panel))

func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(2, 0)
	_tree.root.push_input(motion, true)

func _wheel(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	_tree.root.push_input(event, true)
