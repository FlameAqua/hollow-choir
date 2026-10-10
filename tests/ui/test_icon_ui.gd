extends TestCase
## Icon-first presentation contract: instant feedback, rules parity, no panel-driven shrink.
var _tree: SceneTree

func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree

func test_inspector_is_immediate_and_retains_content_across_short_gaps() -> void:
	# The fixed battle dock: a short gap between neighbouring icons never blanks it.
	var inspector := HoverInspector.new()
	inspector.docked = true
	_tree.root.add_child(inspector)
	inspector.set_process(false)
	inspector.advance("Burn · 2 turns", 0)
	assert_true(inspector.visible, "first feedback needs no dwell")
	assert_eq(inspector.shown_text(), "Burn · 2 turns")
	inspector.advance("", 0.1)
	assert_eq(inspector.shown_text(), "Burn · 2 turns", "a small pointer gap cannot flicker the dock")
	inspector.advance("Wet · 3 turns", 0.02)
	assert_eq(inspector.shown_text(), "Wet · 3 turns", "the dock follows the next icon at once")
	inspector.advance("", 0.15)
	assert_eq(inspector.shown_text(), "", "leaving clears stale details")
	inspector.queue_free()
	# A floating card: sweeping onto an adjacent icon settles briefly, but leaving dismisses it at
	# once (V0.5 playtest revision: a card leaves with its source).
	var card := HoverInspector.new()
	_tree.root.add_child(card)
	card.set_process(false)
	card.advance("Burn · 2 turns", 0)
	assert_true(card.visible, "first feedback needs no dwell")
	card.advance("Wet · 3 turns", 0.02)
	assert_eq(card.shown_text(), "Burn · 2 turns", "sweeping an adjacent icon settles briefly")
	card.advance("Wet · 3 turns", 0.05)
	assert_eq(card.shown_text(), "Wet · 3 turns")
	card.advance("", 0.0)
	assert_false(card.visible, "leaving dismisses the card")
	card.queue_free()

func test_unknown_move_icons_and_reaction_legality_match_the_filtered_readout() -> void:
	var driver := BattleDriver.new(_setup())
	driver.to_player_turn()
	for enemy in driver.engine.get_state().enemies():
		var preview := driver.engine.preview_intent(enemy.uid)
		if preview == null:
			continue
		var readout := IntentReadout.build(driver.engine, preview)
		assert_false(readout.named)
		assert_eq(CombatIcons.intent(readout), CombatIcons.mapping("intent_categories", readout.category), "unknown art cannot reveal a move family")
		var strip := IntentSlot.new(enemy.uid, 1, enemy.display_name)
		strip.show_readout(readout)
		for i in ReactionReadout.REACTIONS.size():
			assert_eq(strip.reaction_allowed(ReactionReadout.REACTIONS[i]), readout.allowed[i], "bool-array legality must not be tested with enum membership")
		strip.free()

func test_full_size_cast_and_supply_selection_reuse_existing_costs() -> void:
	Engine.time_scale = 25
	var setup := _setup()
	setup.enemies = [Database.registry.enemies[&"straw_penitent"], Database.registry.enemies[&"sporecaller"], Database.registry.enemies[&"rotcap_brute"], Database.registry.enemies[&"bogwife"]]
	var scene: BattleScene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	scene.embedded = true
	_tree.root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(1280, 720)
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.simulated_execution = Enums.SimulatedExecution.GOOD
	scene.start(launch)
	assert_true(await _until(func() -> bool: return scene._picker.is_active()))
	# The pointer now clears idle hover content. Deliberate keyboard inspection shows the action.
	scene._inspector.follow_keyboard()
	for i in 3:
		await _tree.process_frame
	# The party stands on stage only; the dock holds exactly Actions, the preview and Supplies.
	var dock := Rect2(scene.global_position + scene.layout.dock.position, scene.layout.dock.size)
	var dock_panels := scene.find_children("*", "PanelContainer", true, false).filter(func(node: Node) -> bool:
		return (node as Control).is_visible_in_tree() and (node as Control).get_global_rect().intersects(dock))
	assert_eq(dock_panels.size(), 3, "no duplicate party card in the dock")
	for panel in [scene._menu, scene._inspector, scene._inspector._card]:
		assert_true(dock_panels.has(panel))
	for member in scene.engine.get_state().party():
		assert_true(scene._battlefield.view(member.uid).is_visible_in_tree(), "each party member is shown on stage")
	# Intent icons reserve no sprite space: every body keeps its intended height.
	for enemy in scene.engine.get_state().enemies():
		var view := scene._battlefield.view(enemy.uid)
		assert_almost_eq(view._sprite_size.y, view.natural_height(), 1.0, "four-enemy bodies retain intended heights")
	var hovered := scene.engine.get_state().enemies()[0]
	var motion := InputEventMouseMotion.new()
	motion.position = scene._battlefield.body_point(hovered.uid)
	motion.global_position = motion.position
	motion.relative = Vector2(1, 0)
	_tree.root.push_input(motion, true)
	for i in 2:
		await _tree.process_frame
	assert_true(scene._inspector.visible, "stage hover is wired to immediate detail")
	assert_true(scene._inspector.shown_text().contains(hovered.display_name), "hover describes the actual unit")
	assert_lt(scene._familiar.position.x, scene.size.x * 0.5, "equipped familiar stands with allies")
	assert_ne(CombatIcons.mapping("potions", &"mending_draught"), CombatIcons.mapping("potions", &"fen_water_flask"), "supplies have distinct functional symbols")
	var potion_button: Button
	for button in scene._menu._buttons:
		var option: ActionOption = button.get_meta(&"option")
		if option.item_slot == 0:
			potion_button = button
			break
	assert_not_null(potion_button)
	potion_button.grab_focus()
	var navigation := InputEventAction.new()
	navigation.action = InputBindings.DOWN
	navigation.pressed = true
	scene._inspector._input(navigation)
	scene._inspector._process(0.07)
	assert_true(scene._inspector.shown_text().contains("Mending Draught"), "keyboard focus exposes the same supply details")
	var charges := scene.engine.get_state().potion_slots[0].charges
	potion_button.pressed.emit()
	if scene._picker.is_targeting():
		scene._picker.click(scene._picker._targets[0])
	assert_true(await _until(func() -> bool: return scene.engine.get_state().potion_slots[0].charges == charges - 1), "a supply slot spends exactly one charge through the normal engine")
	var item_actions := 0
	for entry in scene.engine.input_log:
		if entry.kind == "action" and entry.slot == 0:
			item_actions += 1
	assert_eq(item_actions, 1)
	scene.queue_free()
	Engine.time_scale = 1

func test_all_semantic_icons_and_migrated_art_load() -> void:
	var mappings: Dictionary = CombatIcons.DATA.entries
	for group in mappings.values():
		for value in group.values():
			if value is String:
				assert_not_null(CombatIcons.texture(value))
	assert_not_null(load("res://assets/art/global/fonts/DepartureMono.otf"))
	for enemy in Database.registry.enemies.values():
		assert_not_null(enemy.sprite_frames, "%s idle art" % enemy.id)
		if enemy.sprite_frames != null:
			assert_gt(enemy.sprite_frames.get_frame_texture(&"idle", 0).get_width(), 0)

func test_four_wide_enemies_keep_disjoint_target_lanes_at_full_height() -> void:
	var setup := _setup()
	var wide: EnemyDefinition = Database.registry.enemies[&"bramblejaw"]
	setup.enemies = [wide, wide, wide, wide]
	var engine := BattleEngine.new(setup)
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var field := Battlefield.new()
	_tree.root.add_child(field)
	field.size = Vector2(1232, 358)
	field.setup(engine, ledger, true)
	var enemies := engine.get_state().enemies()
	for i in enemies.size():
		var view := field.view(enemies[i].uid)
		assert_almost_eq(view._sprite_size.y, view.natural_height(), 1.0)
		if i > 0:
			assert_false(view.get_global_rect().intersects(field.view(enemies[i - 1].uid).get_global_rect()), "wide decorative art must not steal another enemy's mouse target")
	field.queue_free()

func test_reaction_visual_windows_use_the_same_boundaries_as_rules() -> void:
	var widget := ReactionWidget.new()
	widget.spec = ReactionSpec.new()
	widget.spec.allowed = [Enums.ReactionType.BRACE, Enums.ReactionType.PARRY]
	widget._running = true
	widget.clock.start()
	widget.clock.freeze()
	for reaction in ReactionReadout.REACTIONS:
		var half := widget.spec.window_for(reaction) * 0.5
		for offset in [-half - 1, -half, 0.0, half, half + 1]:
			widget.clock.set_elapsed(widget.impact_ms() + offset)
			widget.clock.freeze()
			assert_eq(widget.window_open(reaction), ReactionRules.is_success(widget.spec, reaction, offset) and widget.spec.is_allowed(reaction), "visual/rule boundary parity")
	widget.clock.set_elapsed(widget.impact_ms())
	widget._chosen = Enums.ReactionType.BRACE
	assert_false(widget.window_open(Enums.ReactionType.PARRY), "no other window invites input after the first press locks")
	widget.free()

func test_exposure_is_an_inspectable_effect_and_waits_for_its_presentation_event() -> void:
	var engine := BattleEngine.new(_setup())
	var unit := engine.get_state().enemies()[0]
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var view := UnitView.new()
	view.setup(unit, ledger)
	_tree.root.add_child(view)
	# The engine can already have resolved a mark, but its icon waits for the public event.
	unit.weak_point_turns = 2
	view.queue_redraw()
	await _tree.process_frame
	assert_false(view._regions.any(func(region: Dictionary) -> bool: return String(region.text).begins_with("Exposed weak point")))
	ledger.apply(BattleEvent.new(BattleEvent.Type.WEAK_POINT_EXPOSED, unit.uid), 0, engine)
	view.queue_redraw()
	await _tree.process_frame
	var effects := view._regions.filter(func(region: Dictionary) -> bool: return String(region.text).contains("Exposed weak point"))
	assert_eq(effects.size(), 1, "one compact effect instead of a sprite banner")
	if not effects.is_empty():
		var text := view._get_tooltip((effects[0].rect as Rect2).get_center())
		assert_true(text.contains("Precision"))
		assert_true(text.contains("Spotter's Mark"))
		assert_true(text.contains("2 of the target's activations"))
		assert_true(text.contains("until recovery"))
	assert_eq(CombatIcons.texture("state_exposed").resource_path, "res://assets/art/global/ui/items/exposed_v01.svg")
	view.queue_free()


func _setup() -> BattleSetup:
	var registry := Database.registry
	return BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"fen_patrol"], Database.library,
		registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)

func _until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > 15000:
			return false
		await _tree.process_frame
	return true
