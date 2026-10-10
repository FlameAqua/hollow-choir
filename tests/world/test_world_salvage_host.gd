extends TestCase
## V0.5A through the real WorldHost and scenes: world entry reconciles an older save once, through
## the existing save-failure card when the write fails; the bench interaction owns the station
## context (a failure card over the bench keeps it, walking away ends it); victory and bell cards
## show each saved receipt once. Presentation also exercises charm equip/remove and inventory.

var kit: WorldKit
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	for action in InputBindings.WORLD_ACTIONS + [InputBindings.CONFIRM, InputBindings.CANCEL]:
		Input.action_release(action)
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start(area_id: StringName = &"", anchor: StringName = &"") -> void:
	if area_id != &"":
		GameState.progress.world.area = area_id
		GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _restart() -> void:
	host.queue_free()
	host = null
	await tree.process_frame
	await _start()


func _frames(count: int) -> void:
	for frame in count:
		await tree.physics_frame


func _texts(node: Node) -> String:
	var texts := PackedStringArray()
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	elif node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		texts.append(_texts(child))
	return " ".join(texts)


func test_world_entry_catches_up_an_older_journey_once() -> void:
	GameState.progress.world.cleared.append(&"bell_guard")
	GameState.progress.world.wayside_bell_restored = true
	await _start()
	assert_eq(kit.writer.writes.size(), 1, "one catch-up write at world entry")
	assert_eq(GameState.progress.reward_claims, [&"first_footsteps.guard", &"first_footsteps.restoration"] as Array[StringName])
	assert_true(GameState.progress.owned_equipment.has(&"storm_salt_charm"))
	assert_eq(host.modal.kind, &"catch_up", "one saved catch-up notice")
	assert_true(_texts(host.modal).contains(WorldCopy.REWARD_CATCH_UP))
	assert_eq(host.modal.find_children("Reward_*", "PanelContainer", true, false).size(), 2)
	host.modal.chosen.emit(&"continue")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.area_def.id, &"gloamstead")
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	await _restart()
	assert_eq(kit.writer.writes.size(), 1, "the next world entry has nothing to write")
	assert_eq(GameState.progress.owned_equipment.count(&"storm_salt_charm"), 1)
	assert_null(host.modal, "a reload never repeats the catch-up notice")


func test_a_failed_world_entry_write_offers_retry_before_play() -> void:
	GameState.progress.world.cleared.append(&"bell_guard")
	kit.writer.fail = true
	await _start()
	assert_not_null(host.modal)
	if host.modal == null:
		return
	assert_eq(host.modal.kind, &"save_failed")
	assert_ne(host.mode, WorldHost.Mode.EXPLORE, "no walking on with an unsaved catch-up")
	assert_true(GameState.progress.reward_claims.is_empty(), "nothing published")
	assert_true(GameState.progress.materials.is_empty())
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.modal.kind, &"catch_up")
	assert_true(_texts(host.modal).contains("Bog Iron ×2"))
	host.modal.chosen.emit(&"continue")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE, "the saved notice returns to exploration")
	assert_eq(GameState.progress.reward_claims, [&"first_footsteps.guard"] as Array[StringName])
	assert_eq(kit.writer.writes.size(), 1)


func test_the_anvil_interaction_owns_the_station_context_and_equipment_needs_none() -> void:
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	await _start()
	assert_eq(host.session.station(), &"")
	assert_eq(host.session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK, "equipment is a field command")
	assert_eq(host.session.unequip(Enums.EquipSlot.CHARM), OK)
	host.player.place(host.area.point(&"preparation_bench") + Vector2(0, 28))
	await _frames(2)
	host.interact()
	assert_eq(host.modal.kind, &"crafting")
	assert_eq([host.session.station(), host.session.service()], [&"preparation_bench", LandmarkDefinition.Service.FORGE])
	host.open_bench(WorldKit.site(&"preparation_bench"))
	assert_eq(host.session.station(), &"preparation_bench")
	assert_eq(host.session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"), OK, "the same production command")
	# A failed write replaces the bench with the failure card but the player is still at the bench.
	kit.writer.fail = true
	(host.modal.find_child("Weapon_reedbow", true, false) as Button).pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(host.session.station(), &"preparation_bench")
	await tree.process_frame
	await tree.process_frame
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	await tree.process_frame
	assert_eq(GameState.progress.loadout_weapon, &"reedbow", "Retry applies the choice")
	assert_eq(host.modal.kind, &"bench")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.session.station(), &"", "closing the bench ends the context")
	assert_eq(host.session.purchase(&"forge.first_fitting"), ERR_UNAVAILABLE, "no Forge work without the anvil")
	assert_eq(host.session.last_crafting.reason, CraftingResult.Reason.NO_STATION)
	assert_eq(GameState.progress.loadout_charm, &"storm_salt_charm")
	# Any return to exploration ends it too (e.g. a rejected command closing the bench).
	host.interact()
	assert_eq(host.session.station(), &"preparation_bench")
	host._close_modal()
	assert_eq(host.session.station(), &"")


func test_victory_and_bell_cards_show_each_receipt_once() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	var site := WorldKit.site(&"bell_guard")
	var card := WorldRules.encounter_card(site, GameState.progress)
	assert_eq(card.rewards.size(), 1)
	assert_eq([card.rewards[0].claim_id, card.rewards[0].status], [&"first_footsteps.guard", RewardReadout.Status.AVAILABLE])
	host.open_encounter_card(site)
	assert_true(_texts(host.modal).contains("Bog Iron ×2"), "the public card previews first-clear salvage")
	assert_true(_texts(host.modal).contains(WorldCopy.REWARD_AVAILABLE))
	assert_eq(kit.writer.writes.size(), 0, "a preview never grants or saves")
	host.engage(site)
	var entry := GameState.progress.world.pending_entry
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_eq(host.modal.kind, &"victory")
	assert_true(_texts(host.modal).contains("Bog Iron ×2"))
	assert_true(_texts(host.modal).contains("Storm Salt ×1"))
	assert_eq(host.modal.find_children("Reward_*", "PanelContainer", true, false).size(), 1, "one receipt card")
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_null(host.modal.find_child("RewardItem_bog_iron", true, false), "a repeated result shows no second receipt")
	assert_eq(WorldRules.encounter_card(site, GameState.progress).rewards[0].status, RewardReadout.Status.CLAIMED)
	host.modal.chosen.emit(&"continue")
	host.load_area(&"briarfen_reedway", &"wayside_bell")
	await _frames(2)
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_RING)
	assert_eq(host.modal.kind, &"reward")
	var text := _texts(host.modal)
	assert_true(text.contains(WorldCopy.BELL_RESTORED))
	assert_true(text.contains("Storm Salt Charm ×1"))
	assert_true(text.contains(WorldCopy.REWARD_CHARM_NEXT))
	assert_eq(host.modal.find_children("RewardItem_*", "HBoxContainer", true, false).size(), 1)
	host.modal.chosen.emit(&"continue")
	host.interact()
	assert_null(host.modal.find_child("Rewards", true, false), "examining the rung bell again shows no receipt")


func test_charm_ui_equips_retries_and_removes_without_leaving_the_station() -> void:
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	await _start()
	host.open_bench(WorldKit.site(&"preparation_bench"))
	(host.modal.find_child("Slot_Charm", true, false) as Button).pressed.emit()
	await _frames(3)
	var charm := host.modal.find_child("Item_storm_salt_charm", true, false) as Button
	assert_eq(tree.root.gui_get_focus_owner(), charm, "owned charm is reachable without a mouse")
	assert_true(_texts(host.modal).contains("Shock you apply to a Wet target also deals 12 Stagger."))
	kit.writer.fail = true
	charm.pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.loadout_charm, &"", "a failed equip cannot publish")
	assert_eq(host.session.station(), &"preparation_bench")
	await _frames(2)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	await _frames(3)
	assert_eq(host.modal.kind, &"bench")
	assert_eq(GameState.progress.loadout_charm, &"storm_salt_charm")
	assert_eq(kit.writer.writes.size(), 1)
	assert_true((host.modal.find_child("Item_storm_salt_charm", true, false) as Button).button_pressed)
	assert_eq(tree.root.gui_get_focus_owner(), host.modal.find_child("Item_storm_salt_charm", true, false))
	assert_true(_texts(host.modal).contains("Equipment saved."))
	(host.modal.find_child("RemoveItem", true, false) as Button).pressed.emit()
	assert_eq(GameState.progress.loadout_charm, &"")
	assert_eq(kit.writer.writes.size(), 2)
	assert_true(GameState.progress.owned_equipment.has(&"storm_salt_charm"), "removing keeps ownership")
	assert_true((host.modal.find_child("RemoveItem", true, false) as Button).disabled)


func test_inventory_round_trip_is_read_only_and_retains_the_selected_slot() -> void:
	GameState.progress.materials[&"bog_iron"] = 4
	GameState.progress.materials[&"storm_salt"] = 1
	await _start()
	host.open_bench(WorldKit.site(&"preparation_bench"), Enums.EquipSlot.GARB)
	var before := GameState.progress.to_dict()
	var writes := kit.writer.writes.size()
	host.modal.chosen.emit(&"inventory")
	assert_eq(host.modal.kind, &"inventory")
	assert_eq(host.session.station(), &"preparation_bench", "the satchel is part of this station interaction")
	assert_eq(_quantity(&"bog_iron"), "×4")
	assert_eq(_quantity(&"storm_salt"), "×1")
	assert_false(_texts(host.modal).contains(WorldCopy.MATERIALS_NOTE), "context is inspection-only")
	host.modal.chosen.emit(&"back")
	assert_eq(host.modal.kind, &"crafting", "Back returns to the dedicated Forge")
	assert_eq(kit.writer.writes.size(), writes)
	assert_eq(GameState.progress.to_dict(), before)
	host._close_modal()
	host.open_menu()
	host.modal.chosen.emit(&"inventory")
	assert_eq(host.modal.kind, &"inventory")
	assert_eq(host.session.station(), &"", "paused inventory does not create a station")
	host.modal.chosen.emit(&"back")
	assert_eq(host.modal.kind, &"menu")


## The shared ingredient strip's quantity label beside one material's icon.
func _quantity(material_id: StringName) -> String:
	var button := host.modal.find_child("Ingredient_" + String(material_id), true, false) as Button
	return (button.get_parent().get_node("Quantity") as Label).text


func test_disabled_overflow_and_stale_choice_rejection_keep_saved_equipment() -> void:
	GameState.progress.owned_equipment.append(&"storm_salt_charm")
	await _start()
	var registry := DefinitionRegistry.load_default()
	var charm := ArmorDefinition.new()
	charm.id = &"test_chorus_charm"
	charm.display_name = "Chorus Charm"
	charm.slot = Enums.EquipSlot.CHARM
	charm.granted_actions.assign([registry.actions[&"hammer_blow"], registry.actions[&"shockwave"]])
	registry.armor[charm.id] = charm
	GameState.progress.owned_equipment.append(charm.id)
	host.session.registry = registry
	host.open_bench(WorldKit.site(&"preparation_bench"), Enums.EquipSlot.CHARM)
	assert_true((host.modal.find_child("Item_test_chorus_charm", true, false) as Button).disabled)
	assert_true(_texts(host.modal).contains(WorldCopy.PREP_ACTION_LIMIT % 8), "the disabled reason is visible")
	# A stale option still goes through backend validation. No UI ownership or capacity calculation.
	var writes := kit.writer.writes.size()
	GameState.progress.owned_equipment.erase(&"storm_salt_charm")
	(host.modal.find_child("Item_storm_salt_charm", true, false) as Button).pressed.emit()
	assert_eq(host.modal.kind, &"bench", "rejection keeps the station open")
	assert_true(_texts(host.modal).contains(WorldCopy.PREP_NOT_OWNED))
	assert_eq(host.session.station(), &"preparation_bench")
	assert_eq(GameState.progress.loadout_charm, &"")
	assert_eq(kit.writer.writes.size(), writes)


func test_failed_bell_write_shows_no_receipt_and_retry_shows_one() -> void:
	GameState.progress.world.cleared.append(&"bell_guard")
	GameState.progress.add_claim(&"first_footsteps.guard")
	# A consistent save: its journal already records the cleared guard, so world entry writes nothing.
	QuestRules.sync(GameState.progress, WorldDefinition.load_default())
	await _start(&"briarfen_reedway", &"wayside_bell")
	assert_eq(kit.writer.writes.size(), 0)
	host.open_dialogue(WorldKit.site(&"wayside_bell"))
	kit.writer.fail = true
	host.modal.chosen.emit(WorldRules.ACT_RING)
	assert_eq(host.modal.kind, &"save_failed")
	assert_null(host.modal.find_child("Rewards", true, false))
	assert_false(GameState.progress.owned_equipment.has(&"storm_salt_charm"))
	await _frames(2)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.modal.kind, &"reward")
	assert_eq(host.modal.find_children("RewardItem_*", "HBoxContainer", true, false).size(), 1)
	assert_eq(kit.writer.writes.size(), 1)


func test_empty_slots_and_native_scrolling_keep_focus_inside_the_modal() -> void:
	await _start()
	host.open_bench(WorldKit.site(&"preparation_bench"), Enums.EquipSlot.RELIC)
	await _frames(3)
	assert_true(_texts(host.modal).contains("No owned relic."))
	assert_true((host.modal.find_child("RemoveItem", true, false) as Button).disabled)
	for button: Button in host.modal.find_children("*", "Button", true, false):
		if button.disabled:
			continue
		for neighbour in [button.focus_neighbor_top, button.focus_neighbor_bottom, button.focus_next, button.focus_previous]:
			assert_true(host.modal.is_ancestor_of(button.get_node(neighbour)))
	(host.modal.find_child("Slot_Weapon", true, false) as Button).pressed.emit()
	await _frames(3)
	var scroll := host.modal.find_child("EquipmentScroll", true, false) as ScrollContainer
	var page := InputEventAction.new()
	page.action = &"ui_page_down"
	page.pressed = true
	(host.modal.find_child("Preparation", true, false) as WorldPreparationView)._unhandled_input(page)
	assert_gt(scroll.scroll_vertical, 0, "long public facts use their existing scroll container")
	page.action = &"ui_page_up"
	(host.modal.find_child("Preparation", true, false) as WorldPreparationView)._unhandled_input(page)
	assert_eq(scroll.scroll_vertical, 0)
	assert_null(host.modal.find_child("ReadFurther", true, false))
	assert_null(host.modal.find_child("ReadEarlier", true, false))
	assert_eq(kit.writer.writes.size(), 0, "browsing facts does not save or equip")


func test_reward_and_inventory_scroll_without_extra_reading_buttons_or_writes() -> void:
	GameState.progress.world.cleared.assign([&"reedway_patrol", &"bell_guard"])
	GameState.progress.world.wayside_bell_restored = true
	await _start()
	await _frames(3)
	assert_eq(host.modal.kind, &"catch_up")
	var writes := kit.writer.writes.size()
	var scroll := host.modal.find_child("ContentScroll", true, false) as ScrollContainer
	for index in 10:
		var page := InputEventAction.new()
		page.action = &"ui_page_down"
		page.pressed = true
		host.modal._unhandled_input(page)
	await _frames(2)
	var charm := host.modal.find_child("RewardItem_storm_salt_charm", true, false) as Control
	assert_gt(scroll.scroll_vertical, 0)
	assert_true(scroll.get_global_rect().encloses(charm.get_global_rect()), "the last compact receipt remains reachable")
	for direction in ["ReadEarlier", "ReadFurther"]:
		assert_null(host.modal.find_child(direction, true, false))
	assert_eq(kit.writer.writes.size(), writes, "reading cannot repeat a grant")
	host.modal.chosen.emit(&"continue")
	host.open_inventory()
	await _frames(3)
	assert_null(host.modal.find_child("ReadFurther", true, false))
	assert_not_null(host.modal.find_child("CharacterInspector", true, false), "the satchel shares combat's inspection scrolling")
	assert_eq(kit.writer.writes.size(), writes)


func test_first_clear_preview_is_visible_before_engaging() -> void:
	await _start(&"briarfen_reedway", &"reedway_patrol")
	host.open_encounter_card(WorldKit.site(&"reedway_patrol"))
	await _frames(3)
	var scroll := host.modal.find_child("ContentScroll", true, false) as Control
	var preview := host.modal.find_child("Rewards", true, false) as Control
	assert_true(scroll.get_global_rect().encloses(preview.get_global_rect()), "salvage is visible on the initial card")
	assert_true(_texts(preview).contains("Bog Iron ×2"))
	assert_true(_texts(preview).contains(WorldCopy.REWARD_AVAILABLE))
	assert_null(host.battle)
	assert_eq(kit.writer.writes.size(), 0)
