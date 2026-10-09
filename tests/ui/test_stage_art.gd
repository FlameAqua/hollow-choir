extends TestCase

func _setup() -> BattleSetup:
	var registry := Database.registry
	return BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"fen_patrol"], Database.library,
		registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 3)


func test_defeated_pose_follows_ledger_event_even_while_hp_tween_is_nonzero() -> void:
	var engine := BattleEngine.new(_setup())
	var enemy := engine.get_state().enemies()[0]
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var view := UnitView.new()
	view.setup(enemy, ledger)
	var before := view.size
	var damage := BattleEvent.new()
	damage.type = BattleEvent.Type.DAMAGE
	damage.subject = enemy.uid
	damage.amount = enemy.hp
	ledger.apply(damage, 0, engine)
	assert_eq(view.presentation_animation(), &"idle", "zero HP display cannot skip ahead of defeat presentation")
	var defeat := BattleEvent.new()
	defeat.type = BattleEvent.Type.UNIT_DEFEATED
	defeat.subject = enemy.uid
	ledger.apply(defeat, 1, engine)
	assert_gt(view.displayed_hp, 0, "this test retains the in-flight HP tween")
	assert_eq(view.presentation_animation(), &"dead", "defeat event selects corpse despite the old tween")
	assert_eq(view.size, before, "corpse art cannot move target lanes or surviving units")
	view.free()


func test_defeated_units_remain_in_state_but_are_excluded_from_living_targets() -> void:
	var driver := BattleDriver.new(_setup())
	var fallen := driver.engine.get_state().enemies()[0]
	fallen.hp = 0
	var request := driver.to_player_turn()
	assert_not_null(driver.engine.get_unit(fallen.uid), "stable instance survives defeat")
	assert_not_null(request)
	for option in request.options:
		assert_false(option.target_uids.has(fallen.uid), "retained artwork cannot make a corpse a legal living target")


func test_each_existing_enemy_has_a_static_dead_pose_with_explicit_anchor_scale() -> void:
	for definition in Database.registry.enemies.values():
		var frames: SpriteFrames = definition.sprite_frames
		assert_true(frames.has_animation(&"dead"), "%s defeated art" % definition.id)
		assert_eq(frames.get_frame_count(&"dead"), 1)
		assert_false(frames.get_animation_loop(&"dead"))
		var dead := frames.get_frame_texture(&"dead", 0)
		assert_not_null(dead)
		assert_gt(dead.get_width(), 0)
		assert_gt(float(frames.get_meta(&"dead_display_width", 0)), 0)


func test_footing_is_shared_and_compact_plate_retains_full_size_mixed_enemies() -> void:
	var setup := _setup()
	setup.enemies = [Database.registry.enemies[&"straw_penitent"], Database.registry.enemies[&"sporecaller"], Database.registry.enemies[&"rotcap_brute"], Database.registry.enemies[&"bogwife"]]
	var engine := BattleEngine.new(setup)
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	var field := Battlefield.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(field)
	field.size = Vector2(1232, 358)
	field.setup(engine, ledger, true)
	var foot := -1.0
	for enemy in engine.get_state().enemies():
		var view := field.view(enemy.uid)
		var feet := view.body_rect().end.y
		if foot >= 0:
			assert_almost_eq(feet, foot, 1)
		foot = feet
		assert_almost_eq(view._sprite_size.y, view.natural_height(), 1)
		assert_lte(view.plate_height(), 64, "compact plate reserves its status outline without a large extra HUD row")
	field.queue_free()


func test_title_menu_has_focus_and_a_bounded_fixed_layout() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var old_theme := tree.root.theme
	tree.root.theme = UITheme.build()
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	tree.root.add_child(menu)
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.size = Vector2(1280, 720)
	menu._layout_menu()
	for frame in 3:
		await tree.process_frame
	assert_true(menu._first_button.has_focus())
	assert_eq(menu.find_children("*", "ScrollContainer", true, false).size(), 0, "title options never need a scrollbar")
	var buttons := menu._column.get_children().filter(func(node: Node) -> bool: return node is Button)
	assert_eq(buttons.size(), 6)
	for button: Button in buttons:
		assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()), "every title option is visible")
	assert_lte(menu._menu_panel.position.x + menu._menu_panel.size.x, 1280)
	assert_lte(menu._menu_panel.position.y + menu._menu_panel.size.y, 720)
	menu.queue_free()
	tree.root.theme = old_theme
