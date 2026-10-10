extends TestCase
## Production station controls and real, placed exploration content. No fixture-only markers.

const KIT := &"forge.first_fitting"
const GRIP := &"fitting.merciful_grip"
const EDGE := &"pilgrims_edge"
const LOW := &"rhythm_stone_low"
const MID := &"rhythm_stone_mid"
const HIGH := &"rhythm_stone_high"
const PUZZLE := &"listening_rhythm"
var kit: WorldKit
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start(area_id: StringName = &"gloamstead", anchor: StringName = &"town_bell") -> void:
	GameState.progress.world.area = area_id
	GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.scripted_move = Vector2.ZERO
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame


func _fund() -> void:
	GameState.progress.materials[&"bog_iron"] = 5
	GameState.progress.materials[&"storm_salt"] = 1
	GameState.progress.weapon_mastery[EDGE] = 1


func _bench() -> LandmarkDefinition:
	return host.definition.find_landmark(&"preparation_bench")[1]


func _stillroom() -> LandmarkDefinition:
	return host.definition.find_landmark(&"stillroom_table")[1]


func _view() -> WorldCraftingView:
	return host.modal.find_child("Crafting", true, false) as WorldCraftingView


func _button(name: String) -> Button:
	return host.modal.find_child(name, true, false) as Button


func _text() -> String:
	var result := PackedStringArray()
	for label in host.modal.find_children("*", "Label", true, false):
		result.append(label.text)
	return "\n".join(result)


func _choose(selection: StringName, action: String) -> void:
	_view().select(selection)
	_button(action).pressed.emit()


func test_station_browsing_is_read_only_and_presents_backend_locks() -> void:
	await _start()
	var writes := kit.writer.writes.size()
	host.open_crafting(_bench())
	assert_eq(host.modal.kind, &"crafting")
	assert_eq(_view().service, &"forge")
	assert_true(_button("CraftFitting").disabled)
	var fitting := host.session.crafting().fitting(EDGE)
	assert_true(_text().contains(fitting.option(GRIP).craft_reason_text))
	var sockets := host.modal.find_child("WeaponSockets", true, false).find_children("FittingSocket_*", "Button", false, false)
	assert_eq(sockets.map(func(socket: Button) -> bool: return socket.toggle_mode), [true, false, false],
		"three sockets around the weapon: the backend's one usable, two locked")
	assert_null(_button("PurchaseRecipe"), "retired kit purchase is absent")
	host.open_crafting(_stillroom())
	assert_eq(_view().service, &"stillroom")
	assert_eq(host.modal.find_child("PotionSlots", true, false).get_child_count(), 4)
	assert_not_null(host.modal.find_child("UnpreparedStock", true, false))
	assert_not_null(host.modal.find_child("IngredientStrip", true, false))
	assert_not_null(_button("BrewRecipe"))
	assert_false(GameState.progress.has_recipe(&"stillroom.mending_draught"))
	host.modal.chosen.emit(&"preparation")
	assert_eq(host.modal.kind, &"character")
	assert_eq(kit.writer.writes.size(), writes, "browsing and service navigation write nothing")
	assert_eq(host.session.crafting().station_id, &"stillroom_table")


func test_craft_failure_retries_the_same_command_and_restores_selection() -> void:
	_fund()
	await _start()
	host.open_crafting(_bench())
	_view().select(&"fitting:fitting.merciful_grip")
	var before := GameState.progress.to_dict()
	var writes := kit.writer.writes.size()
	kit.writer.fail = true
	_button("CraftFitting").pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.to_dict(), before)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.modal.kind, &"crafting")
	assert_eq(_view().selection, &"fitting:fitting.merciful_grip")
	assert_eq(kit.writer.writes.size(), writes + 1)
	assert_eq(GameState.progress.materials[&"bog_iron"], 3)
	assert_true(host.session.crafting().fitting(EDGE).option(GRIP).owned)
	await tree.process_frame
	await tree.process_frame
	assert_eq(tree.root.gui_get_focus_owner(), _button("Choice_fitting_fitting_merciful_grip"))
	assert_false(_button("FitWeapon").disabled)


func _prepare_choice(position: int, potion: StringName) -> void:
	_button("PotionSlot_%d" % position).pressed.emit()
	await tree.process_frame
	await tree.process_frame
	_button("Owned_" + String(potion)).pressed.emit()


func test_controls_craft_fit_brew_prepare_and_capture_finite_supplies() -> void:
	_fund()
	await _start()
	host.open_crafting(_bench())
	_choose(&"fitting:fitting.merciful_grip", "CraftFitting")
	_choose(&"fitting:fitting.merciful_grip", "FitWeapon")
	assert_eq(GameState.progress.weapon_fittings[EDGE], GRIP)
	var writes := kit.writer.writes.size()
	_view().command_requested.emit(&"fit", GRIP, 0)
	assert_eq(kit.writer.writes.size(), writes, "re-choosing an installed fitting is a no-op")
	assert_not_null(_button("RemoveFitting"))
	host.open_crafting(_stillroom())
	_choose(&"stillroom.clotting_salve", "BrewRecipe")
	_choose(&"stillroom.focus_tincture", "BrewRecipe")
	await _prepare_choice(0, &"clotting_salve")
	await _prepare_choice(1, &"focus_tincture")
	assert_eq(GameState.progress.materials[&"bog_iron"], 2)
	assert_eq(GameState.progress.loadout_potions, [&"clotting_salve", &"focus_tincture"] as Array[StringName])
	assert_eq(GameState.progress.consumables[&"clotting_salve"], 2)
	assert_eq(GameState.progress.consumables[&"focus_tincture"], 2)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	var entry := host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	var setup := entry.build_setup(Database.registry, Database.library)
	assert_eq(setup.loadout.modifications[0].id, GRIP)
	assert_eq(setup.loadout.potions.map(func(p: PotionDefinition) -> StringName: return p.id), [&"clotting_salve", &"focus_tincture"])
	assert_eq(setup.loadout.potion_charges, [1, 1] as Array[int], "each position captures its finite allowance")


func test_fit_and_potion_failures_retry_exact_choices_with_quiet_autosave() -> void:
	_fund()
	await _start()
	host.open_crafting(_bench())
	_choose(&"fitting:fitting.merciful_grip", "CraftFitting")
	_view().select(&"fitting:fitting.merciful_grip")
	kit.writer.fail = true
	_button("FitWeapon").pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_false(GameState.progress.weapon_fittings.has(EDGE))
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(_view().selection, &"fitting:fitting.merciful_grip")
	assert_eq(GameState.progress.weapon_fittings[EDGE], GRIP)
	host.open_crafting(_stillroom())
	_choose(&"stillroom.focus_tincture", "BrewRecipe")
	kit.writer.fail = true
	await _prepare_choice(1, &"focus_tincture")
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.loadout_potions[1], &"fen_water_flask")
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(GameState.progress.loadout_potions[1], &"focus_tincture")
	var writes := kit.writer.writes.size()
	await _prepare_choice(1, &"focus_tincture")
	assert_eq(kit.writer.writes.size(), writes, "prepared re-choice writes nothing")
	await tree.process_frame
	await tree.process_frame
	assert_true(host.notices._cards.is_empty(), "station autosaves have no large confirmation")
	assert_true(host.notices._autosave.visible)
	for button in [_button("BrewRecipe"), host.modal.button(&"preparation"), host.modal.button(WorldRules.ACT_LEAVE)]:
		assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()))
	var frame := host.modal.find_child("Frame", true, false) as Control
	assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(frame.get_global_rect()))
	assert_eq(host.session.save(), OK)
	await tree.process_frame
	var card: Control = host.notices._cards[0].node
	assert_true(host.modal.notice_dock.get_global_rect().encloses(card.get_global_rect()), "explicit save uses reserved footer")
	assert_false(card.get_global_rect().intersects(host.modal.button(WorldRules.ACT_LEAVE).get_global_rect()))


func test_stale_craft_rejection_and_legacy_refund_overflow_stay_visible() -> void:
	_fund()
	await _start()
	host.open_crafting(_bench())
	GameState.progress.materials.clear()
	_button("CraftFitting").pressed.emit()
	assert_eq(host.modal.kind, &"crafting")
	assert_true(_text().contains(WorldCopy.CRAFT_INSUFFICIENT))
	assert_false(host.session.crafting().fitting(EDGE).option(GRIP).owned)
	# A preserved old paid kit still has a deliberate, whole-or-nothing reclaim path.
	GameState.progress.add_recipe(KIT)
	GameState.progress.weapon_fittings[EDGE] = GRIP
	GameState.progress.materials[&"bog_iron"] = 998
	host.open_crafting(_bench())
	assert_true(_button("RefundLegacyKit").disabled)
	var legacy := host.session.crafting().fitting(EDGE).legacy_kit
	assert_true(_button("RefundLegacyKit").tooltip_text.contains(legacy.name))
	GameState.progress.materials[&"bog_iron"] = 3
	host.open_crafting(_bench())
	_button("RefundLegacyKit").pressed.emit()
	assert_eq(GameState.progress.materials[&"bog_iron"], 5)
	assert_false(GameState.progress.has_recipe(KIT))
	assert_false(GameState.progress.weapon_fittings.has(EDGE))


## Walk the actual feet body along the authored terrain; no teleport to a new interaction.
func _walk(to: Vector2) -> bool:
	for step in 3000:
		if host.player.position.distance_to(to) < 3.0:
			host.player.stop()
			host._after_move()
			return true
		host.player.step(host.player.position.direction_to(to), 1.0 / 60.0)
		host._after_move()
	return false


func test_scene_and_prompt_restore_partial_attempt_after_reload_and_reset_clears_it() -> void:
	await _start(&"briarfen_reedway", &"listening_stones")
	assert_eq(host.session.strike_rune(&"briarfen_reedway", LOW), OK)
	assert_eq(host.session.strike_rune(&"briarfen_reedway", HIGH), OK)
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	host.load_area(&"briarfen_reedway", &"listening_stones")
	assert_true(host.area.get_node("LowDecoration/Rune_low/Lit").visible)
	assert_true(host.area.get_node("LowDecoration/Rune_high/Lit").visible)
	assert_false(host.area.get_node("LowDecoration/Rune_mid/Lit").visible)
	host.player.place(host.area.point(MID))
	host._refresh_hud()
	assert_true(host.readout().interaction.ends_with("2 / 3"))
	assert_eq(host.session.reset_journey(), OK)
	host._restart_journey()
	host.load_area(&"briarfen_reedway", &"listening_stones")
	assert_false(host.area.get_node("LowDecoration/Rune_low/Lit").visible)
	assert_false(host.area.get_node("LowDecoration/Niche").visible)


func test_placed_iron_seam_is_walkable_from_the_outer_path_and_stays_gathered() -> void:
	await _start(&"briarfen_reedway", &"reedway_fork")
	assert_true(_walk(Vector2(336, 1744)), "fork to outer boards")
	assert_true(_walk(Vector2(336, 1232)), "outer boards to seam")
	assert_true(_walk(host.area.point(&"iron_seam")))
	assert_eq(host.interaction_target().id, &"iron_seam")
	host.interact()
	assert_eq(host.modal.kind, &"dialogue")
	host.modal.chosen.emit(WorldRules.ACT_GATHER)
	assert_eq(host.modal.kind, &"reward")
	assert_eq(GameState.progress.materials[&"bog_iron"], 1)
	assert_false(host.area.get_node("LowDecoration/IronSeam/OreRemaining").visible)
	host.modal.chosen.emit(&"continue")
	assert_eq(host.session.reset_journey(), OK)
	assert_true(GameState.progress.world.is_gathered(&"iron_seam"))
	assert_eq(host.session.gather(&"briarfen_reedway", &"iron_seam"), ERR_ALREADY_EXISTS)
	assert_eq(GameState.progress.materials[&"bog_iron"], 1)


func test_placed_runes_and_secret_are_walkable_with_saved_feedback_and_no_repeat_reward() -> void:
	await _start(&"briarfen_reedway", &"listening_stones")
	assert_false(host.area.get_node("LowDecoration/Niche").visible)
	assert_true(_walk(host.area.point(&"drowned_niche")))
	assert_null(host.interaction_target(), "the hidden secret offers no prompt")
	assert_false(GameState.progress.world.is_discovered(&"drowned_niche"))
	for rune in [LOW, MID, LOW, HIGH]:
		assert_true(_walk(host.area.point(rune)), "reachable rune: %s" % rune)
		assert_eq(host.interaction_target().id, rune)
		host.interact()
		assert_eq(host.mode, WorldHost.Mode.EXPLORE)
		var feedback := host.hud.get_node("ExplorationFeedback") as Label
		assert_true(feedback.visible)
		if rune == MID:
			assert_true(feedback.text.contains("rhythm breaks"))
			assert_false(host.area.get_node("LowDecoration/Rune_low/Lit").visible)
	assert_true(_walk(host.area.point(MID)))
	var before := GameState.progress.to_dict()
	kit.writer.fail = true
	host.interact()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.to_dict(), before)
	assert_false(host.area.get_node("LowDecoration/Niche").visible)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_true(GameState.progress.world.is_solved(PUZZLE))
	assert_true(host.area.get_node("LowDecoration/Niche").visible)
	for name in ["low", "mid", "high"]:
		assert_true(host.area.get_node("LowDecoration/Rune_" + name + "/Solved").visible)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(_walk(host.area.point(&"drowned_niche")))
	assert_eq(host.interaction_target().id, &"drowned_niche")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_SEARCH)
	assert_true(GameState.progress.owned_equipment.has(&"fenrunner_leathers"))
	assert_false(host.area.get_node("LowDecoration/Niche/Unsearched").visible)
	var claimed := GameState.progress.reward_claims.duplicate()
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	assert_eq(host.session.reset_journey(), OK)
	for rune in [LOW, HIGH, MID]:
		assert_eq(host.session.strike_rune(&"briarfen_reedway", rune), OK)
	assert_eq(host.session.find_secret(&"briarfen_reedway", &"drowned_niche"), OK)
	assert_eq(GameState.progress.reward_claims, claimed)
	assert_true(host.session.last_receipts.is_empty(), "finding again grants nothing")
