extends TestCase
## The V0.5 UI: honest readouts and safe commands. New Journey, field equipment and the saved combat
## arrangement are real transactions since Claude's backend pass (tests updated with them).
var kit: WorldKit
var tree: SceneTree
var host: WorldHost
var menu: MainMenu
var _motion: bool
var _slot: int
var _saves: Dictionary

func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	_motion = Settings.data.reduce_motion
	_slot = GameState.active_slot
	_saves = {}
	for index in SaveManager.SLOT_COUNT:
		if SaveManager.has_slot(index): _saves[index] = FileAccess.get_file_as_string(SaveManager.slot_path(index))
		SaveManager.delete_slot(index)

func after_each() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	if is_instance_valid(menu): menu.queue_free()
	menu = null
	for index in SaveManager.SLOT_COUNT:
		SaveManager.delete_slot(index)
		if _saves.has(index):
			var file := FileAccess.open(SaveManager.slot_path(index), FileAccess.WRITE)
			file.store_string(_saves[index])
	Settings.data.reduce_motion = _motion
	GameState.active_slot = _slot
	kit.restore()

func _frames(count := 5) -> void:
	for frame in count: await tree.process_frame

func _start() -> void:
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await _frames()

func _title() -> void:
	menu = load(SceneRouter.MAIN_MENU).instantiate()
	tree.root.add_child(menu)
	await _frames()

func test_title_has_five_choices_and_setup_writes_nothing_before_an_explicit_slot() -> void:
	await _title()
	var labels := PackedStringArray()
	for child in menu._column.get_children():
		if child is Button: labels.append(child.text)
	assert_eq(labels, PackedStringArray(["Continue Journey", "New Journey", "Settings", "Credits", "Quit"]))
	assert_true(menu._first_button.disabled)
	var before := GameState.progress.to_dict()
	menu._open_new_journey()
	await _frames()
	(menu._modal.find_child("Preset_reedbow", true, false) as Button).pressed.emit()
	assert_eq(menu._preset, &"reedbow")
	assert_false(menu._modal.button(&"start").disabled, "the backend listener is connected")
	menu._modal.chosen.emit(&"start")
	assert_eq(menu._modal.kind, &"journey_slot", "Start asks for a save slot first")
	assert_eq(GameState.progress.to_dict(), before)
	assert_false(SaveManager.has_slot(0), "nothing written before a slot is chosen")
	menu._modal.chosen.emit(&"back")
	assert_eq(menu._modal.kind, &"new_journey")
	assert_eq(menu._preset, &"reedbow", "the setup keeps its choices")
	menu._back()
	await _frames()
	assert_eq(tree.root.gui_get_focus_owner().get_parent(), menu._column)

func test_save_picker_orders_newest_first_and_breaks_ties_by_slot() -> void:
	for index in 3:
		assert_eq(SaveManager.write_progress(index, GameState.progress), OK)
		var envelope := SaveManager.read_json(SaveManager.slot_path(index))
		envelope.saved_at_unix = [100, 300, 300][index]
		assert_eq(SaveManager.write_json_atomic(SaveManager.slot_path(index), envelope), OK)
	await _title()
	assert_false(menu._first_button.disabled)
	assert_eq(menu._saves().map(func(entry: SaveSlotSummary) -> int: return entry.slot), [1, 2, 0])
	menu._open_save_picker()
	await _frames()
	var entries := menu._modal.find_child("SaveSlot_1", true, false).get_parent()
	assert_eq(entries.get_child(0).name, &"SaveSlot_1")
	assert_eq(entries.get_child(2).name, &"SaveSlot_0")
	assert_eq(GameState.active_slot, _slot, "browsing does not adopt a slot")

func test_equipment_filters_owned_items_and_changes_in_the_field() -> void:
	await _start()
	host.open_character_menu()
	await _frames()
	var tools := host.hud.find_child("Character", true, false).get_parent()
	assert_eq(tools.get_child(0).name, &"Character")
	var character := host.modal.find_child("Character", true, false) as WorldCharacterView
	assert_eq(character.selected_tab, &"equipment")
	(host.modal.find_child("Slot_garb", true, false) as Button).pressed.emit()
	await _frames()
	assert_not_null(host.modal.find_child("Owned_pilgrims_coat", true, false))
	assert_null(host.modal.find_child("Owned_reedbow", true, false), "choices belong to the selected gear slot")
	(host.modal.find_child("Owned_pilgrims_coat", true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(kit.writer.writes.size(), 0, "owned gear re-choice writes nothing")
	assert_eq(GameState.progress.loadout_garb, &"pilgrims_coat")
	(host.modal.find_child("FieldGuide", true, false) as Button).pressed.emit()
	await _frames()
	var guide: FieldGuide
	for child in host._modal_root.get_children():
		if child is FieldGuide: guide = child
	assert_not_null(guide)
	guide.closed.emit()
	await _frames()
	assert_not_null(host.modal.find_child("Loadout", true, false), "Field Guide returns to Loadout")

func test_combat_arrangement_saves_swaps_and_reaches_battle() -> void:
	await _start()
	host.open_character_menu()
	var character := host.modal.find_child("Character", true, false) as WorldCharacterView
	character.select_tab(&"combat")
	await _frames()
	var slots := host.modal.find_child("CombatSlots", true, false)
	assert_eq(slots.get_child_count(), 8)
	assert_true((host.modal.find_child("CombatSlot_6", true, false) as Button).tooltip_text.contains(WorldCopy.COMBAT_LOCKED_POSITION))
	var unplaced := host.modal.find_child("SelectionStatus", true, false) as Label
	assert_true(unplaced.text.contains("Kindle"))
	var before := host.session.combat().arranged
	assert_eq(before.size(), 6, "six usable positions, filled by default")
	(slots.get_child(1) as Button).pressed.emit()
	(host.modal.find_child("Source_" + String(before[0]), true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(kit.writer.writes.size(), 1, "one atomic write")
	var after := host.session.combat().arranged
	assert_eq([after[0], after[1]], [before[1], before[0]], "an arranged action swaps places")
	assert_eq(GameState.progress.combat_actions, after, "saved explicitly")
	character = host.modal.find_child("Character", true, false) as WorldCharacterView
	assert_eq([character.selected_tab, character.combat_position], [&"equipment", 1], "the view reopens where it was")
	# The locked positions accept nothing; the next battle uses the saved order.
	assert_eq(host.session.arrange_action(6, before[0]), ERR_INVALID_PARAMETER)
	assert_eq(host.session.last_combat.reason, CombatResult.Reason.LOCKED_POSITION)
	host._close_modal()
	var entry := host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var hero := BattleEngine.new(entry.build_setup(Database.registry, Database.library)).get_state().protagonist()
	assert_eq(hero.actions.map(func(action: ActionDefinition) -> StringName: return action.id), Array(after))

func test_pause_save_notice_never_moves_menu_and_failed_save_has_no_success() -> void:
	await _start()
	host.open_menu()
	await _frames()
	for id in [&"reset", &"inventory", &"field_guide"]: assert_null(host.modal.button(id))
	assert_eq(host.modal.button(&"quit").text, "Save and Quit")
	var rect := (host.modal.get_node("Frame") as Control).get_global_rect()
	kit.writer.fail = true
	host.modal.button(&"save").pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_true(host.notices._cards.is_empty())
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	await _frames()
	assert_eq(host.notices._cards.size(), 1)
	assert_eq(host.notices._cards[0].title, "Game Saved")
	assert_eq((host.modal.get_node("Frame") as Control).get_global_rect(), rect)
	assert_false(host.modal._status.visible)

func test_notices_queue_stack_coalesce_and_respect_reduced_motion() -> void:
	await _start()
	host.notices.set_process(false)
	Settings.data.reduce_motion = true
	EventBus.game_saved.emit(0, false)
	assert_true(host.notices._cards.is_empty())
	host.notices.push_notice("Game Saved", "", JourneyUI.icon("save"), &"save")
	host.notices.push_notice("Game Saved", "", JourneyUI.icon("save"), &"save")
	for index in 5: host.notices.push_notice("Fenrunner Leathers", "+1", JourneyUI.icon("save"))
	await _frames()
	assert_eq(host.notices._cards.size(), 4)
	assert_eq(host.notices._pending.size(), 2)
	var canvas := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for index in 4:
		var card: Control = host.notices._cards[index].node
		assert_true(canvas.encloses(card.get_global_rect()), "notice fits the game canvas")
		assert_lte(card.size.y, 76, "long pickup names do not grow through the stack")
		if index > 0:
			var previous: Control = host.notices._cards[index - 1].node
			assert_false(previous.get_global_rect().intersects(card.get_global_rect()))
	host.notices._process(3.5)
	assert_eq(host.notices._cards.size(), 2, "queued cards receive a fresh full lifetime")
	assert_true(host.notices._pending.is_empty())

func test_dedicated_stations_are_reachable_and_open_their_service() -> void:
	await _start()
	for id in [&"preparation_bench", &"stillroom_table"]:
		var point := host.area.point(id)
		host.player.place(point + Vector2(0, 65))
		# Walk inside a physics frame: outside one, move_and_slide() uses the process delta, and a
		# frame under ~2 ms left the feet 60 px away, beyond the 56 px reach (intermittent failure).
		await tree.physics_frame
		for step in 40: host.player.step(Vector2.UP, 1.0 / 60.0)
		assert_eq(host.interaction_target().id, id)
		var writes := kit.writer.writes.size()
		host.interact()
		assert_eq(host.modal.kind, &"crafting")
		assert_eq(kit.writer.writes.size(), writes, "opening a service is read-only")
		assert_eq((host.modal.find_child("Crafting", true, false) as WorldCraftingView).service, &"forge" if id == &"preparation_bench" else &"stillroom")
		host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(kit.writer.writes.size(), 2, "closing each newly discovered station saves its existing interaction")

func test_help_wraps_in_its_overlay_and_scrolls_from_the_toggle() -> void:
	await _start()
	host.open_crafting(WorldKit.site(&"preparation_bench"))
	await _frames()
	var help := host.modal.find_child("Help", true, false) as Button
	help.grab_focus()
	help.pressed.emit()
	await _frames()
	var card := host.modal.find_child("HelpCard", true, false) as Control
	var scroll := card.find_child("HelpScroll", true, false) as ScrollContainer
	var copy := scroll.get_child(0) as Label
	assert_true(card.visible)
	assert_gte(copy.size.x, 400, "help uses a paragraph column, not a one-character minimum")
	assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(card.get_global_rect()))
	var event := InputEventAction.new()
	event.action = &"ui_page_down"
	event.pressed = true
	help.gui_input.emit(event)
	assert_gt(scroll.scroll_vertical, 0)
	help.pressed.emit()
	assert_false(card.visible)
	assert_eq(kit.writer.writes.size(), 0)


func test_station_save_receipt_uses_footer_and_returns_to_exploration_stack() -> void:
	await _start()
	for station_id in [&"preparation_bench", &"stillroom_table"]:
		Settings.data.reduce_motion = station_id == &"stillroom_table"
		host.open_crafting(WorldKit.site(station_id))
		assert_eq(host.session.save(), OK)
		await _frames()
		assert_eq(host.notices._cards.size(), 1, "repeated saves coalesce")
		var card: Control = host.notices._cards[0].node
		assert_true(host.modal.notice_dock.get_global_rect().encloses(card.get_global_rect()), "reserved space fits the save confirmation")
		for button in host.modal.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				assert_false(card.get_global_rect().intersects(button.get_global_rect()), "all station actions remain visible during a save")
		host._close_modal()
		await _frames()
		host.notices._process(.3) # Let the normal-motion exploration slide settle.
		assert_null(host.notices.save_dock)
		assert_eq(card.size, Vector2(330, 76), "the ordinary exploration card is restored")
		assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(card.get_global_rect()))
	assert_eq(kit.writer.writes.size(), 2, "changing presentation creates no extra saves")
