extends TestCase
## Fifth playtest engineering checks beside Pause: a pinned readout survives recipient review and
## target hover until a boundary releases it; field explanations state what the engine and the
## player's settings actually do; announcement fades follow Combat Speed.

var _tree: SceneTree
var _tooltip_mode: int


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_tooltip_mode = Settings.data.advanced_tooltips


func after_each() -> void:
	Settings.data.advanced_tooltips = _tooltip_mode as GameSettings.TooltipMode
	Input.action_release(InputBindings.INFO)
	Engine.time_scale = 1.0
	AudioManager.silence()


func _battle() -> BattleScene:
	var fixture: TestCase = load("res://tests/ui/test_v02_ui.gd").new()
	fixture._tree = _tree
	return await fixture._battle()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _mouse(point: Vector2, button: int = 0) -> void:
	var at := _tree.root.get_final_transform() * point
	if button == 0:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.relative = Vector2(2, 0)
		_tree.root.push_input(motion, false)
	else:
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = at
			click.button_index = button
			click.pressed = pressed
			_tree.root.push_input(click, false)
	await _frames(6)


func test_pin_survives_recipient_review_and_target_hover_until_a_boundary() -> void:
	var scene := await _battle()
	var inspector := scene._inspector
	var button: Button
	for candidate in scene._menu._buttons:
		var option: ActionOption = candidate.get_meta(&"option")
		if option.legal and option.action.needs_target_choice() and option.action.targets_enemies() and option.target_uids.size() > 1:
			button = candidate
			break
	assert_not_null(button, "a multi-recipient enemy action")
	var center := button.get_global_rect().get_center()
	await _mouse(center)
	await _mouse(center, MOUSE_BUTTON_RIGHT)
	assert_true(inspector.pinned)
	var payload := inspector._payload
	var shown := inspector.shown_text()
	var logged := scene.engine.input_log.size()
	var focus := scene._picker.acting_unit().focus
	await _mouse(center, MOUSE_BUTTON_LEFT)
	assert_true(scene._picker.is_targeting(), "a left click still chooses the action")
	assert_true(inspector.pinned, "entering recipient review keeps the pin")
	assert_eq(inspector._payload, payload, "with its original snapshot")
	var reviewed := scene._picker.reviewed_target_uid()
	var other := -1
	for uid in scene._picker._targets:
		if uid != reviewed:
			other = uid
	await _mouse(scene._battlefield.body_point(other))
	assert_eq(scene._picker.reviewed_target_uid(), other, "hover still moves the reviewed recipient")
	assert_eq(inspector._payload, payload, "but never overwrites the pinned readout")
	assert_eq(inspector.shown_text(), shown)
	Input.action_press(InputBindings.INFO)
	await _frames(4)
	assert_true(inspector.expanded and inspector.pinned, "Details expands the pinned card in place")
	assert_eq(inspector._payload, payload)
	Input.action_release(InputBindings.INFO)
	await _frames(4)
	assert_eq(scene.engine.input_log.size(), logged, "nothing was submitted")
	assert_eq(scene._picker.acting_unit().focus, focus)
	scene.request_pause()
	await _frames(2)
	assert_false(inspector.pinned, "Pause is a boundary that releases the pin")
	scene._close_pause()
	await _frames(2)
	assert_true(scene._picker.is_targeting(), "the review itself survives Pause")
	assert_eq(scene._picker.reviewed_target_uid(), other)
	scene.queue_free()
	await _frames(2)


func test_timing_field_names_the_players_details_key_and_mode() -> void:
	var scene := await _battle()
	var option: ActionOption
	for button in scene._menu._buttons:
		var candidate: ActionOption = button.get_meta(&"option")
		if candidate.action.command != null and candidate.action.command.type != Enums.ActionCommandType.NONE:
			option = candidate
			break
	assert_not_null(option, "an action with a timing input")
	var panel := PreviewPanel.new()
	panel.size = Vector2(420, 200)
	scene.add_child(panel)
	var key := InputBindings.prompt(InputBindings.INFO)
	for mode in [GameSettings.TooltipMode.HOLD, GameSettings.TooltipMode.TOGGLE, GameSettings.TooltipMode.ALWAYS]:
		Settings.data.advanced_tooltips = mode
		panel.show_readout(ActionReadout.build(scene.engine, scene._picker.acting_unit().uid, option, option.target_uids[0]))
		await _frames(2)
		var timing := ""
		for region in panel._regions:
			if String(region.text).contains("timing grades"):
				timing = region.text
		assert_false(timing.is_empty(), "the scope field explains timing")
		match mode:
			GameSettings.TooltipMode.HOLD:
				assert_true(timing.contains("Hold " + key), timing)
			GameSettings.TooltipMode.TOGGLE:
				assert_true(timing.contains(key + " shows"), timing)
			GameSettings.TooltipMode.ALWAYS:
				assert_false(timing.contains(key), "Always mode names no key to hold")
	scene.queue_free()
	await _frames(2)


func test_break_field_promises_a_weak_point_only_when_the_enemy_has_one() -> void:
	for weak_point in ["", "Cracked bell"]:
		var readout := UnitReadout.new()
		readout.title = "Probe"
		readout.enemy = true
		readout.hp = 10
		readout.max_hp = 10
		readout.resource = 5
		readout.max_resource = 10
		readout.weak_point = weak_point
		var card := UnitInspectionCard.new()
		_tree.root.add_child(card)
		card.show_readout(readout, false)
		var help := ""
		for row in card.find_children("*", "VBoxContainer", true, false):
			if (row as Control).tooltip_text.begins_with("Break remaining"):
				help = (row as Control).tooltip_text
		assert_true(help.contains("next activation"), "Break costs the enemy its next activation")
		assert_eq(help.contains("weak point"), not weak_point.is_empty(), "weak point named only when it exists: " + help)
		card.queue_free()
	await _frames(2)


func test_focus_help_lists_the_engines_sources_without_a_missing_guard() -> void:
	# Every party action that grants its user Focus is one the help names (Inspect or a Guard action).
	for action: ActionDefinition in Database.registry.actions.values():
		if action is EnemyActionDefinition:
			continue
		for effect in action.effects:
			if effect != null and effect.type == Enums.EffectType.GAIN_FOCUS and effect.target == Enums.EffectTarget.OWNER:
				assert_true(action.category in [Enums.ActionCategory.GUARD, Enums.ActionCategory.INSPECT], String(action.id))
	# Weapons replace plain Guard, so the help may not promise "Guard" by name.
	for weapon: WeaponDefinition in Database.registry.weapons.values():
		if weapon.guard_action != null:
			assert_eq(weapon.guard_action.category, Enums.ActionCategory.GUARD, String(weapon.id))
	var readout := UnitReadout.new()
	readout.title = "Probe"
	readout.hp = 10
	readout.max_hp = 10
	readout.resource = 2
	readout.max_resource = 10
	var card := UnitInspectionCard.new()
	_tree.root.add_child(card)
	card.show_readout(readout, false)
	var help := ""
	for row in card.find_children("*", "VBoxContainer", true, false):
		if (row as Control).tooltip_text.begins_with("Focus"):
			help = (row as Control).tooltip_text
	assert_true(help.contains(PreviewPanel.FOCUS_SOURCES), help)
	assert_false(help.contains("Guard restores"), "no loadout of the Hollow has plain Guard")
	card.queue_free()
	await _frames(2)


## Names the fifth engineering review measured as ellipsized in the shipped grid (194px for a name,
## 170px beside the unavailable mark) and reported to the Director with the smallest layout fix.
## Remove entries once the layout gives them room; any other clipped name fails.
const KNOWN_CLIPPED_NAMES := ["Earthsplitter", "Riposte Stance", "Spotter's Mark"]


## The game draws a fixed 1280×720 canvas at every window preset, so this geometry is the same at
## each one. Every shipped loadout and companion shows its real actions inside the grid, and no
## name beyond the reported ones is clipped.
func test_every_shipped_action_name_fits_its_grid_cell() -> void:
	var scene := await _battle()
	var registry := Database.registry
	var menu := scene._menu
	for id: StringName in registry.loadouts:
		var setup := BattleSetup.from_encounter(registry.loadouts[id], registry.encounters[&"fen_patrol"], Database.library,
			registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
		var engine := BattleEngine.new(setup)
		for unit in engine.get_state().party(false):
			menu.show_options(unit, engine.options_for(unit.uid), engine)
			await _frames(3)
			assert_lte(menu._list.get_child_count(), ActionMenu.CAPACITY)
			for button: Control in menu._list.get_children():
				assert_true(menu.get_global_rect().encloses(button.get_global_rect()), "%s/%s: the cell is inside the dock" % [id, unit.display_name])
				for label: Label in button.find_children("*", "Label", true, false):
					var font := label.get_theme_font("font")
					var need := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
					if need > label.size.x + 0.5:
						assert_true(label.text in KNOWN_CLIPPED_NAMES, "%s/%s: '%s' needs %.0fpx, has %.0fpx" % [id, unit.display_name, label.text, need, label.size.x])
	scene.queue_free()
	await _frames(2)


## Adrian (9 October 2026): every party member has up to eight action slots; a slot without an
## action is an empty, inert frame, so the grid always reads as eight. Fixture: Mara (five actions).
func test_unused_action_slots_are_empty_inert_frames() -> void:
	var scene := await _battle()
	var menu := scene._menu
	var actions := scene._picker.acting_unit().actions.size()
	assert_lt(actions, ActionMenu.CAPACITY, "the fixture has spare slots")
	assert_eq(menu._list.get_child_count(), ActionMenu.CAPACITY, "the grid always shows eight slots")
	assert_eq(menu._list.get_children().filter(func(child: Node) -> bool: return child is Button).size(), actions,
		"only real actions are buttons (Supplies keeps the potions)")
	var empty: Array[Control] = []
	for child: Control in menu._list.get_children():
		if not child is Button:
			empty.append(child)
			assert_gte(child.get_index(), actions, "empty slots follow the actions")
			assert_eq(child.focus_mode, Control.FOCUS_NONE)
			assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_true(menu.get_global_rect().encloses(child.get_global_rect()))
	assert_eq(empty.size(), ActionMenu.CAPACITY - actions)
	var center := empty[0].get_global_rect().get_center()
	await _mouse(center)
	await _mouse(center, MOUSE_BUTTON_RIGHT)
	assert_false(scene._inspector.pinned, "an empty slot has nothing to pin")
	await _mouse(menu._buttons[0].get_global_rect().get_center())
	var last := menu._list.get_child(actions - 1) as Button
	last.grab_focus()
	for code in ["key:Down", "key:Right", "key:Down"]:
		var event := InputBindings.event_from_code(code)
		event.pressed = true
		_tree.root.push_input(event, true)
		event.pressed = false
		_tree.root.push_input(event, true)
		await _frames(2)
		assert_true(_tree.root.gui_get_focus_owner() is Button, "keyboard navigation never lands on an empty slot")
	scene.queue_free()
	await _frames(2)


## Adrian (9 October 2026): an enemy's turn shows its name beside its absolute encounter number,
## drawn in the same badge as its intent above the stage, so duplicates (Thornhound Pack) are never
## ambiguous. The numbers come from the real event path and must equal the intent badges'.
func test_enemy_turn_banner_carries_the_intent_badge_number() -> void:
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"thornhound_pack"],
		Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)
	var scene: BattleScene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	Engine.time_scale = 20
	scene.start(launch)
	var deadline := Time.get_ticks_msec() + 6000
	while not scene._picker.is_active() and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	Engine.time_scale = 1
	assert_true(scene._picker.is_active())
	var banner := scene._banner
	var enemies := scene.engine.get_state().enemies(false)
	assert_eq(enemies.size(), 3, "three Thornhounds")
	for enemy in enemies:
		scene._events._play_one(BattleEvent.new(BattleEvent.Type.TURN_STARTED, enemy.uid, -1))
		await _frames(6)
		assert_eq(banner._title.text, enemy.display_name + "'s Turn")
		assert_true(banner._badge.visible)
		assert_eq(banner._number, scene._rail.slots[enemy.uid].slot_number, "%s: the banner shows its intent badge's number" % enemy.display_name)
		var badge := banner._badge.get_global_rect()
		var title := banner._title.get_global_rect()
		assert_true(banner._panel.get_global_rect().encloses(badge), "the badge stays inside the turn frame")
		assert_lte(badge.end.x, title.position.x + 0.5, "the badge precedes the name")
		assert_lte(title.position.x - badge.end.x, 16.0, "beside the name, not at the frame's edge")
		assert_almost_eq(badge.get_center().y, title.get_center().y, 6.0, "on the name's line")
		if banner._tween != null and banner._tween.is_valid():
			await banner._tween.finished
	var ally := scene.engine.get_state().party()[0]
	scene._events._play_one(BattleEvent.new(BattleEvent.Type.TURN_STARTED, ally.uid, -1))
	await _frames(6)
	assert_false(banner._badge.visible, "allies have no enemy number")
	assert_eq(banner._title.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "other announcements keep their wrapping")
	scene.queue_free()
	await _frames(2)


func test_announcement_fades_follow_combat_speed() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	_tree.root.add_child(host)
	var banner := Banner.new()
	host.add_child(banner)
	await _frames(1)
	for speed in [1.0, 2.0]:
		banner.announce("Round 2", "", 0.3, speed)
		var deadline := Time.get_ticks_msec() + 2000
		while (banner._tween == null or not banner._tween.is_valid()) and Time.get_ticks_msec() < deadline:
			await _tree.process_frame
		banner._tween.pause()
		banner._tween.custom_step(0.075 - banner._tween.get_total_elapsed_time())
		assert_almost_eq(banner.modulate.a, 0.5 * speed, 0.05, "fade-in at Combat Speed %.1f" % speed)
		banner._tween.custom_step(10.0)
		await _frames(2)
	host.queue_free()
	await _frames(2)
