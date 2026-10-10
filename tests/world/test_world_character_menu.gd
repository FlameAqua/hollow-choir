extends TestCase
## Character inspection must remain read-only; progression expansion follows committed claims.
var kit: WorldKit
var tree: SceneTree
var host: WorldHost
var tooltip_mode: GameSettings.TooltipMode


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	tooltip_mode = Settings.data.advanced_tooltips
	Settings.data.advanced_tooltips = GameSettings.TooltipMode.HOLD


func after_each() -> void:
	Input.action_release(InputBindings.INFO)
	Settings.data.advanced_tooltips = tooltip_mode
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start() -> void:
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await _frames(3)


func _frames(count: int) -> void:
	for frame in count:
		await tree.process_frame


func test_exploration_portrait_opens_twenty_cells_and_returns_to_exploration() -> void:
	await _start()
	var before := GameState.progress.to_dict()
	(host.hud.find_child("Character", true, false) as Button).pressed.emit()
	await _frames(5)
	assert_eq(host.modal.kind, &"character")
	assert_not_null(host.modal.find_child("Slot_weapon", true, false))
	(host.modal.find_child("Tab_inventory", true, false) as Button).pressed.emit()
	await _frames(3)
	var grid := host.modal.find_child("EquipmentSlots", true, false) as GridContainer
	assert_eq(grid.columns, 5)
	assert_eq(grid.get_child_count(), 20)
	assert_eq(grid.find_children("LockedSlot_*", "", false, false).size(), 10)
	assert_true((host.modal.get_node("Frame") as Control).get_global_rect().encloses(grid.get_global_rect()))
	for item: Dictionary in host.session.inventory().equipment:
		var button := host.modal.find_child("Equipment_" + String(item.id), true, false) as Button
		assert_not_null(button.icon)
		assert_eq(button.icon.resource_path, item.icon_path, "each owned item uses its authored icon")
		assert_true(button.text.is_empty(), "equipment cells use icons, with names in inspection")
	for id in [&"equipment", &"inventory"]:
		assert_not_null(host.modal.find_child("Tab_" + String(id), true, false))
	assert_null(host.modal.find_child("Tab_combat", true, false), "Combat lives in the Loadout")
	assert_null(host.modal.find_child("ReadFurther", true, false))
	host.modal.chosen.emit(&"back")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_null(host.modal)
	assert_eq(kit.writer.writes.size(), 0)
	assert_eq(GameState.progress.to_dict(), before)


func test_character_tabs_match_combat_actions_and_current_passives() -> void:
	await _start()
	var readout := CharacterReadout.build(GameState.progress, host.session.registry)
	var loadout := PartyLoadout.from_ids(host.session.registry, GameState.progress.loadout_ids())
	var combat_actions := UnitFactory.protagonist_actions(loadout, host.session.registry.balance)
	assert_eq(readout.actions.size() + readout.magic.size(), combat_actions.size())
	host.open_character_menu()
	var unified := host.session.loadout()
	for entry in unified.all_actions():
		assert_eq(host.modal.find_children("Source_" + String(entry.id), "Button", true, false).size(), 1, "each grant has exactly one source")
	for entry in unified.passives:
		assert_not_null(host.modal.find_child("Passive_" + String(entry.id), true, false))
	assert_null(host.modal.find_child("Tab_combat", true, false), "Combat is part of the Loadout, not a separate tab")
	assert_eq(kit.writer.writes.size(), 0, "reading sources/passives cannot save")


func test_items_share_alt_pin_and_inspector_scrolling_without_equipping() -> void:
	GameState.progress.materials[&"bog_iron"] = 4
	await _start()
	host.open_inventory()
	await _frames(5)
	var before := GameState.progress.to_dict()
	var character := host.modal.find_child("Character", true, false) as WorldCharacterView
	var inspector := character.inspector
	var sword := host.modal.find_child("Equipment_pilgrims_edge", true, false) as Button
	var iron := host.modal.find_child("Ingredient_bog_iron", true, false) as Button
	sword.grab_focus()
	inspector.follow_keyboard()
	await _frames(5)
	assert_true(inspector.shown_text().contains("Pilgrim's Edge"))
	assert_false(inspector._text.text.contains("Weapon mastery"))
	Input.action_press(InputBindings.INFO)
	await _frames(3)
	assert_true(inspector.expanded)
	assert_true(inspector._text.text.contains("Weapon mastery"))
	assert_true(inspector.claims_wheel(sword), "the shared inspector owns scrolling over its expanded source")
	Input.action_release(InputBindings.INFO)
	await _frames(3)
	assert_false(inspector.expanded)
	# Real pointer motion resolves the source; right-click pins using the shared controller.
	var motion := InputEventMouseMotion.new()
	motion.position = sword.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await _frames(5)
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(3)
	assert_true(inspector.pinned)
	motion.position = iron.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await _frames(5)
	assert_true(inspector.shown_text().contains("Pilgrim's Edge"), "browsing another item preserves the pin")
	click.position = motion.position
	Input.parse_input_event(click)
	await _frames(7)
	assert_false(inspector.pinned)
	assert_true(inspector.shown_text().contains("Bog Iron"))
	sword.pressed.emit()
	assert_eq(GameState.progress.to_dict(), before)
	assert_eq(kit.writer.writes.size(), 0)


func test_progression_reward_expands_bag_only_after_save_and_survives_reset_reload() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.inventory().equipment_capacity, 10)
	GameState.progress.world.cleared.append(&"bell_guard")
	GameState.progress.add_claim(&"first_footsteps.guard")
	kit.writer.fail = true
	assert_eq(session.restore_bell(&"briarfen_reedway"), ERR_FILE_CANT_WRITE)
	assert_eq(session.inventory().equipment_capacity, 10)
	assert_empty(session.last_receipts)
	kit.writer.fail = false
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(session.last_receipts[0].equipment_slots, 5)
	assert_eq(session.inventory().equipment_capacity, 15)
	assert_eq(session.reset_journey(), OK)
	assert_eq(session.inventory().equipment_capacity, 15)
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq(session.inventory().equipment_capacity, 15)
	GameState.progress.world.cleared.append(&"bell_guard")
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_empty(session.last_receipts, "resetting the bell never adds a second row")
	assert_eq(session.inventory().equipment_capacity, 15)
	GameState.progress.add_claim(&"future.unknown_expansion")
	assert_eq(session.inventory().equipment_capacity, 15, "unknown claims cannot invent bag slots")


func test_loot_uses_quantity_rows_and_inspection_keeps_descriptions_off_the_card() -> void:
	await _start()
	var receipt := RewardRules.grant(GameState.progress, [Database.registry.rewards[&"first_footsteps.guard"]])[0]
	host._show_rewards(&"reward", "Salvage", "", [receipt])
	await _frames(4)
	for item: Dictionary in receipt.items:
		var row := host.modal.find_child("RewardItem_" + String(item.id), true, false)
		var button := row.get_child(0) as Button
		assert_eq(button.text, "%s ×%d" % [item.name, item.added])
		assert_true(button.tooltip_text.contains(item.description))
		var payload: ItemInspectionReadout = button.get_meta(&"inspection_readout").call(Vector2.ZERO)
		assert_eq(payload.description, item.description)
		assert_true(row.find_children("*", "Label", true, false).is_empty(), "there are no inline description or stock labels")
	assert_null(host.modal.find_child("LootInspector", true, false))
	assert_eq(host.modal.find_children("ContextTooltip", "", true, false).size(), 1)
	assert_eq(kit.writer.writes.size(), 0, "showing a receipt never grants it again")
