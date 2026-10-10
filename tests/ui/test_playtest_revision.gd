extends TestCase
## Presentation regressions. Fixtures never grant stock, equipment capacity or rewards.
var tree: SceneTree
var stage: Control
var old_theme: Theme
var kit: WorldKit

func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	old_theme = tree.root.theme
	tree.root.theme = UITheme.build()
	kit = WorldKit.new()
	kit.isolate()
	stage = Control.new()
	tree.root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func after_each() -> void:
	stage.queue_free()
	tree.root.theme = old_theme
	kit.restore()
	AudioManager.silence()

func _frames(count: int = 5) -> void:
	for index in count: await tree.process_frame

func test_tooltip_stays_inside_each_canvas_corner_and_keeps_source_clear() -> void:
	TooltipPolicy.install(stage)
	await _frames()
	var inspector := stage.get_node("ContextTooltip") as HoverInspector
	inspector.set_process(false)
	var source := Button.new()
	source.size = Vector2(48, 48)
	source.tooltip_text = "New Journey\nChoose a companion, pet and starter equipment before selecting a save slot."
	stage.add_child(source)
	var bounds := Rect2(Vector2(12, 12), Vector2(1256, 696))
	inspector.bounds_provider = func() -> Rect2: return bounds
	for point in [Vector2(12, 12), Vector2(1220, 12), Vector2(12, 660), Vector2(1220, 660)]:
		source.position = point
		inspector._source = source
		inspector._fit(source.tooltip_text)
		assert_true(bounds.encloses(inspector.get_global_rect()), "tooltip fits the safe canvas")
		assert_false(inspector.get_global_rect().intersects(source.get_global_rect()), "source remains visible")
	assert_eq(stage.theme.get_color("font_color", "TooltipLabel").a, 0.0, "native tooltip text is suppressed")
	source.tooltip_text = "New Journey\nChoose your companion, pet and starter equipment, then select a save slot."
	source.grab_focus()
	inspector.follow_keyboard()
	inspector.set_process(true)
	await _frames(10)
	assert_lte(inspector._scroll.get_v_scroll_bar().max_value, inspector._scroll.size.y + 1,
		"the short New Journey description is readable without scrolling past the wrapped footer")

func test_dialogue_reveal_does_not_pull_manual_reading_to_the_end() -> void:
	var paragraphs := PackedStringArray()
	for index in 18: paragraphs.append("Earlier line %d. The old bell carries over the reeds." % index)
	var modal := WorldModal.make(&"dialogue", "Caretaker", paragraphs, [{"id": &"close", "label": "Continue"}])
	stage.add_child(modal)
	await _frames()
	modal.set_process(false)
	modal._revealed = 600
	modal._dialogue.visible_characters = 600
	modal.scroll_dialogue(48)
	var scroll := modal._dialogue_scroll.scroll_vertical
	var characters := modal._dialogue.visible_characters
	modal._process(.5)
	assert_false(modal.dialogue_following)
	assert_eq(modal._dialogue_scroll.scroll_vertical, scroll, "manual position survives typewriter progress")
	assert_gt(modal._dialogue.visible_characters, characters, "reveal continues during reading back")
	modal.resume_dialogue_follow()
	assert_true(modal.dialogue_following)
	assert_true(modal.reveal_dialogue(), "Confirm still reveals the rest first")
	assert_false(modal.reveal_dialogue(), "next Confirm may choose")

func test_bag_has_twenty_equal_cells_without_initial_ingredient_focus_or_writes() -> void:
	var session := kit.session()
	var before := GameState.progress.to_dict()
	for capacity in [10, 15]:
		var inventory := session.inventory()
		inventory.equipment_capacity = capacity # View-only fixture: does not unlock a save.
		var bag := WorldInventoryView.make(inventory)
		stage.add_child(bag)
		await _frames()
		assert_eq(bag.grid.columns, 5)
		assert_eq(bag.grid.get_child_count(), 20)
		assert_eq(bag.grid.find_children("LockedSlot_*", "", false, false).size(), 20 - capacity)
		for cell in bag.grid.get_children(): assert_eq(cell.size, Vector2(48, 48))
		assert_true(String(bag.first_item.name).begins_with("Equipment_"))
		var strip := bag.find_child("IngredientStrip", true, false)
		assert_eq(strip.get_child_count(), inventory.ingredients.size())
		for index in inventory.ingredients.size():
			assert_eq((strip.get_child(index).get_node("Quantity") as Label).text, "×%d" % inventory.ingredients[index].count)
		stage.remove_child(bag)
		bag.queue_free()
	assert_eq(GameState.progress.to_dict(), before, "inspection is read-only")
	assert_eq(kit.writer.writes.size(), 0)

func test_checkbox_frames_and_scrollbar_caps_keep_geometry_in_every_state() -> void:
	var theme := UITheme.build()
	var expected := theme.get_stylebox("normal", "CheckBox").get_minimum_size()
	for state in ["hover", "pressed", "hover_pressed", "focus", "disabled"]:
		assert_eq(theme.get_stylebox(state, "CheckBox").get_minimum_size(), expected)
	assert_eq(theme.get_icon("checked", "CheckBox"), UICraft.texture("check"))
	for id in ["scroll_track", "scroll_thumb"]:
		var style := UICraft.scrollbar(id)
		assert_eq(style.texture_margin_top, 8.0)
		assert_eq(style.texture_margin_bottom, 8.0)
		assert_eq(style.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH)

func test_operation_audio_and_save_notices_follow_adoption_once() -> void:
	var notices := JourneyNotices.new()
	stage.add_child(notices)
	var session := kit.session()
	var voice := AudioManager._next
	assert_eq(session.equip(Enums.EquipSlot.WEAPON, &"reedbow"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "one adopted equip cue")
	assert_true(notices._autosave.visible)
	assert_true(notices._cards.is_empty(), "automatic equip does not show a save card")
	voice = AudioManager._next
	var writes := kit.writer.writes.size()
	assert_eq(session.equip(Enums.EquipSlot.WEAPON, &"reedbow"), OK)
	assert_eq(AudioManager._next, voice, "re-choice is silent")
	assert_eq(kit.writer.writes.size(), writes)
	kit.writer.fail = true
	assert_eq(session.equip(Enums.EquipSlot.WEAPON, &"mire_maul"), ERR_FILE_CANT_WRITE)
	assert_eq(AudioManager._next, voice, "failed adoption is silent")
	assert_eq(kit.writer.writes.size(), writes)
	kit.writer.fail = false
	assert_eq(session.equip(Enums.EquipSlot.WEAPON, &"mire_maul"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "retry sounds once")
	voice = AudioManager._next
	assert_eq(session.save(), OK)
	assert_eq(AudioManager._next, voice, "save feedback has no cue")
	assert_eq(notices._cards.size(), 1, "one manual confirmation; no duplicate legacy signal listener")
	assert_eq(notices._cards[0].title, "Game Saved")
	GameState.progress.materials[&"bog_iron"] = 5 # Explicit funding fixture for adopted station facts.
	GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
	session.enter_station(&"preparation_bench")
	assert_eq(session.craft_fitting(&"fitting.merciful_grip"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "one smith cue")
	voice = AudioManager._next
	assert_eq(session.craft_fitting(&"fitting.merciful_grip"), ERR_ALREADY_EXISTS)
	assert_eq(AudioManager._next, voice, "owned craft no-op is silent")
	assert_eq(session.fit(&"pilgrims_edge", &"fitting.merciful_grip"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "one fit cue")
	voice = AudioManager._next
	assert_eq(session.remove_fitting(&"pilgrims_edge"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "one remove cue")
	voice = AudioManager._next
	session.enter_station(&"stillroom_table")
	assert_eq(session.brew(&"stillroom.clotting_salve"), OK)
	assert_eq(AudioManager._next, (voice + 1) % AudioManager.POOL_SIZE, "one brew cue")

func test_journal_steps_use_available_width_and_open_without_a_write() -> void:
	var journal := WorldJournalView.make(kit.session().quests())
	var modal := WorldModal.make(&"journal", "Journal", PackedStringArray(), [{"id": &"close", "label": "Close"}], journal)
	stage.add_child(modal)
	await _frames()
	for row in journal.get_children():
		if row is HBoxContainer:
			var copy := row.get_child(1) as Label
			assert_gt(copy.size.x, 500.0, "step prose receives the available row width")
			assert_lt(copy.size.y, 80.0, "short route steps do not become vertical character columns")
	assert_eq(kit.writer.writes.size(), 0)

func test_station_costs_and_actions_fit_at_the_smallest_preset_without_writes() -> void:
	var session := kit.session()
	session.reconcile()
	GameState.progress.materials[&"bog_iron"] = 5
	GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
	var writes := kit.writer.writes.size()
	for scenario in [{"service": &"forge", "poor": false}, {"service": &"stillroom", "poor": false}, {"service": &"forge", "poor": true}, {"service": &"stillroom", "poor": true}]:
		var service: StringName = scenario.service
		GameState.progress.materials[&"bog_iron"] = 0 if scenario.poor else 5
		GameState.progress.weapon_mastery[&"pilgrims_edge"] = 0 if scenario.poor else 1
		var before := GameState.progress.to_dict()
		session.enter_station(&"preparation_bench" if service == &"forge" else &"stillroom_table")
		var station := WorldCraftingView.new()
		station.present(session.crafting(), service, &"", "", session.inventory())
		var modal := WorldModal.make(&"crafting", "Station", PackedStringArray(), [{"id": &"close", "label": "Close"}], station)
		stage.add_child(modal)
		await _frames()
		assert_true(Rect2(0, 0, 1280, 720).encloses(modal.get_node("Frame").get_global_rect()))
		assert_true(station._recipe_text.text.contains("Bog Iron"), "selected costs remain in recipe details")
		if not scenario.poor:
			assert_lte(station._recipe_text.get_content_height(), station._scroll.size.y, "default effects and costs fit without scrolling")
		assert_lte(station._actions.get_global_rect().end.y, modal.buttons[0].global_position.y)
		stage.remove_child(modal)
		modal.queue_free()
		assert_eq(GameState.progress.to_dict(), before)
	assert_eq(kit.writer.writes.size(), writes, "opening stations changes no saved stock or ownership")

func test_reward_uses_one_bounded_card_and_same_style_for_capacity_and_items() -> void:
	var receipt := RewardReadout.new()
	receipt.claim_id = &"fixture.salvage"
	receipt.status = RewardReadout.Status.GRANTED
	receipt.equipment_slots = 5
	receipt.items = [{"kind": RewardItem.Kind.EQUIPMENT, "id": &"storm_salt_charm", "name": "Storm Salt Charm", "description": "A charm carrying the hush before a storm.", "icon_path": "res://assets/art/global/ui/materials/parcel_v01.svg", "count": 1, "added": 1, "total": 1, "owned": false}]
	var rewards := WorldRewardView.make([receipt])
	var modal := WorldModal.make(&"victory", "Victory", PackedStringArray(), [{"id": &"continue", "label": "Continue"}], rewards)
	stage.add_child(modal)
	await _frames()
	assert_null(modal.find_child("LootInspector", true, false))
	assert_eq(modal.find_children("ContextTooltip", "", true, false).size(), 1)
	var rows := rewards.find_children("*", "Button", true, false)
	assert_eq(rows.size(), 2)
	for row in rows:
		assert_true(modal._content_scroll.get_global_rect().encloses(row.get_global_rect()), "every reward row fits without initial scrolling")
	for state in ["normal", "hover", "focus", "pressed"]:
		for row in rows:
			var style := (row as Button).get_theme_stylebox(state) as StyleBoxFlat
			assert_eq(style.border_width_left, 0)
			assert_eq(style.get_minimum_size(), (rows[0] as Button).get_theme_stylebox(state).get_minimum_size())
	var inspector := modal.get_node("ContextTooltip") as HoverInspector
	inspector.set_process(false)
	inspector._source = rows[0]
	inspector._fit(rows[0].tooltip_text)
	assert_false(inspector.get_global_rect().intersects(modal.button(&"continue").get_global_rect()))
	assert_null(rewards.get_node_or_null("BestiaryLearnings"), "no invented learning on a repeat victory")

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	tree.root.push_input(motion, true)
	await _frames(2)

func test_unpinned_tooltip_dismisses_on_source_exit_and_compact_hints_cannot_pin() -> void:
	TooltipPolicy.install(stage)
	var source := Button.new()
	source.position = Vector2(100, 100)
	source.size = Vector2(48, 48)
	source.tooltip_text = "Sword\nAn owned weapon."
	stage.add_child(source)
	await _frames()
	var inspector := stage.get_node("ContextTooltip") as HoverInspector
	await _move_pointer(source.get_global_rect().get_center())
	assert_true(inspector.visible)
	inspector.expanded = true
	await _move_pointer(inspector.get_global_rect().get_center())
	assert_false(inspector.visible, "hovering the unpinned card dismisses it")
	await _move_pointer(source.get_global_rect().get_center())
	var pin := InputEventMouseButton.new()
	pin.position = source.get_global_rect().get_center()
	pin.pressed = true
	pin.button_index = MOUSE_BUTTON_RIGHT
	inspector._input(pin)
	assert_true(inspector.pinned)
	await _move_pointer(Vector2(900, 600))
	assert_true(inspector.visible, "explicit pins survive source exit")
	inspector.clear()
	source.set_meta(&"compact_tooltip", true)
	source.tooltip_text = "Map"
	await _move_pointer(source.get_global_rect().get_center())
	assert_true(inspector.visible)
	assert_lt(inspector.size.x, 200.0)
	assert_lte(inspector.size.y, 60.0)
	assert_false(inspector._hint.visible)
	inspector._input(pin)
	assert_false(inspector.pinned, "simple hints do not claim the pin input")
	await _move_pointer(Vector2(900, 600))
	assert_false(inspector.visible)

func test_help_is_in_title_and_station_empty_stock_retains_a_cell() -> void:
	var session := kit.session()
	session.reconcile()
	for service in [&"forge", &"stillroom"]:
		var view := WorldCraftingView.new()
		view.present(session.crafting(), service, &"", "", session.inventory())
		var modal := WorldModal.make(&"crafting", "Anvil" if service == &"forge" else "Stillroom", PackedStringArray(), [{"id": &"close", "label": "Close"}], view)
		stage.add_child(modal)
		await _frames()
		var help := modal.find_child("Help", true, false) as Button
		assert_eq(String(help.get_parent().name), "TitleRow")
		assert_lt(help.global_position.y, view.global_position.y)
		if service == &"stillroom":
			var empty := view.find_child("EmptyStock", true, false) as Button
			assert_not_null(empty)
			assert_eq(empty.size, Vector2(48, 48))
		else:
			var center := view.find_child("ForgeWeapon", true, false) as Button
			var top := view.find_child("FittingSocket_0", true, false) as Button
			var left := view.find_child("FittingSocket_1", true, false) as Button
			var right := view.find_child("FittingSocket_2", true, false) as Button
			assert_lt(top.position.y, center.position.y)
			assert_lt(left.position.x, center.position.x)
			assert_gt(right.position.x, center.position.x)
			assert_eq(left.size, top.size)
			assert_eq(right.size, top.size)
		stage.remove_child(modal)
		modal.queue_free()
	var hud := ExplorationHUD.new()
	stage.add_child(hud)
	await _frames()
	assert_eq(hud._journal.get_index(), hud._map.get_index() + 1)
	assert_gt(hud._menu.get_index(), hud._journal.get_index())
	assert_eq(hud._menu.get_index(), hud._menu.get_parent().get_child_count() - 1)

func test_reaction_centres_follow_the_target_through_initial_stage_layout() -> void:
	var registry := Database.registry
	var setup := BattleSetup.from_encounter(registry.loadouts[&"starter_sword"], registry.encounters[&"fen_patrol"], Database.library, registry.difficulty(Enums.TacticalDifficulty.ADVENTURER), registry.assist(Enums.ExecutionAssist.STANDARD), 11)
	var engine := BattleEngine.new(setup)
	var field := Battlefield.new()
	stage.add_child(field)
	field.position = Vector2(60, 70)
	field.size = Vector2(1000, 300)
	var ledger := PresentationLedger.new()
	ledger.snapshot(engine)
	field.setup(engine, ledger, false)
	await _frames()
	var spec := ReactionSpec.new()
	spec.windup_ms = 900
	var readout := ReactionReadout.for_spec(spec, "Attacker", "Swing")
	readout.target_uids = [engine.get_state().party()[0].uid]
	var widget := ReactionWidget.new()
	stage.add_child(widget)
	widget.position = Vector2(30, 20)
	widget.begin(spec, readout, [Vector2(1, 1)], Rect2(300, 500, 700, 180), true)
	# Draw uses the current target geometry; no process frame or timing start is required.
	widget._refresh_target_points()
	var expected := widget.get_global_transform().affine_inverse() * field.body_point(readout.target_uids[0])
	assert_eq(widget.target_points[0], expected)
	field.size.y = 220
	field.layout_units()
	widget._refresh_target_points()
	expected = widget.get_global_transform().affine_inverse() * field.body_point(readout.target_uids[0])
	assert_eq(widget.target_points[0], expected, "ring follows the dock's first layout change")
	assert_true(widget.is_preparing())
	assert_eq(widget.elapsed_ms(), 0.0)
