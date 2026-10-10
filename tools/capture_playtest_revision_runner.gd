extends Node
## Explicit in-memory capture fixtures, not a playthrough or backend acceptance claim.
const QA_USER_DATA := preload("res://tools/qa_user_data.gd")
var _args := {}
var _stage: Control
var _kit: WorldKit
var _logger := TestErrorLogger.new()

func _ready() -> void:
	OS.add_logger(_logger)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()

func _run() -> void:
	if not QA_USER_DATA.check():
		get_tree().quit(1)
		return
	var dimensions := String(_args.get("size", "1280x720")).split("x")
	var preset := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if not GameSettings.RESOLUTIONS.has(preset):
		push_error("Use a supported display preset")
		get_tree().quit(1)
		return
	Settings.data.window_resolution = preset
	if _args.has("reduced"):
		Settings.data.reduce_motion = true
		Settings.data.reduce_flashing = true
	Settings.apply()
	get_tree().root.theme = UITheme.build()
	_kit = WorldKit.new()
	_kit.isolate()
	_stage = Control.new()
	get_tree().root.add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state := String(_args.get("state", "loadout"))
	var session := _kit.session()
	# Use the real bounded old-save conversion in the isolated memory save, not an infinite fixture refill.
	session.reconcile()
	match state:
		"title": _stage.add_child(load(SceneRouter.MAIN_MENU).instantiate())
		"settings":
			var settings := SettingsScreen.new()
			settings.embedded = true
			_stage.add_child(settings)
			settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			settings._tabs.current_tab = 1
		"dialogue":
			var lines := PackedStringArray()
			for index in 18: lines.append("Earlier line %d. The old bell carries over the reeds." % index)
			var modal := WorldModal.make(&"dialogue", "Caretaker", lines, [{"id": &"close", "label": "Continue"}])
			_stage.add_child(modal)
			modal._revealed = 700
			modal._dialogue.visible_characters = 700
			modal.scroll_dialogue(48)
		"inventory", "inventory15", "loadout", "loadout-popup":
			var inventory := session.inventory()
			if state == "inventory15": inventory.equipment_capacity = 15
			var character := WorldCharacterView.new()
			character.present(inventory, session.loadout())
			character.select_tab(&"equipment" if state.begins_with("loadout") else &"inventory")
			_stage.add_child(WorldModal.make(&"character", "Character", PackedStringArray(), [{"id": &"close", "label": "Close"}], character))
		"forge", "forge-locked", "forge-owned", "forge-fitted", "stillroom", "stillroom-poor", "stillroom-depleted", "stillroom-stock":
			var forge := state.begins_with("forge")
			if state not in ["forge-locked", "stillroom-poor"]:
				GameState.progress.materials[&"bog_iron"] = 5
				GameState.progress.materials[&"storm_salt"] = 1
				GameState.progress.weapon_mastery[&"pilgrims_edge"] = 1
			if state in ["forge-owned", "forge-fitted"]: GameState.progress.add_recipe(&"forge.merciful_grip")
			if state == "forge-fitted": GameState.progress.weapon_fittings[&"pilgrims_edge"] = &"fitting.merciful_grip"
			if state == "stillroom-depleted": GameState.progress.consumables.clear()
			if state == "stillroom-stock": GameState.progress.set_supply(&"clotting_salve", 2) # Explicit stock-display fixture.
			session.enter_station(&"preparation_bench" if forge else &"stillroom_table")
			var station := WorldCraftingView.new()
			station.name = "Crafting"
			station.present(session.crafting(), &"forge" if forge else &"stillroom", &"fitting:fitting.merciful_grip" if state in ["forge-owned", "forge-fitted"] else &"", "", session.inventory())
			_stage.add_child(WorldModal.make(&"crafting", "Forge" if forge else "Stillroom", PackedStringArray(), [{"id": &"close", "label": "Close"}], station))
		"journal":
			_stage.add_child(WorldModal.make(&"journal", "Journal", PackedStringArray(), [{"id": &"close", "label": "Close"}], WorldJournalView.make(session.quests())))
		"reward", "reward-learnings":
			var receipt := RewardReadout.new()
			receipt.claim_id = &"capture.salvage"
			receipt.status = RewardReadout.Status.GRANTED
			receipt.equipment_slots = 5
			receipt.items = [{"kind": RewardItem.Kind.EQUIPMENT, "id": &"storm_salt_charm", "name": "Storm Salt Charm", "description": "A charm carrying the hush before a storm.", "icon_path": "res://assets/art/global/ui/materials/parcel_v01.svg", "count": 1, "added": 1, "total": 1, "owned": false}]
			var rewards := WorldRewardView.make([receipt])
			if state == "reward-learnings":
				rewards.present_learnings([LearningReadout.make(Database.registry.enemies[&"thornhound"], &"thornhound", Enums.ResearchLevel.UNKNOWN, Enums.ResearchLevel.OBSERVED)])
			_stage.add_child(WorldModal.make(&"victory", "Victory", PackedStringArray(), [{"id": &"continue", "label": "Continue"}], rewards))
		"countdown", "countdown-frozen", "quest", "autosave", "manual-save", "menu-hint":
			var hud := ExplorationHUD.new()
			_stage.add_child(hud)
			hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hud.journal_requested.connect(func() -> void: pass)
			hud._journal.show()
			if state == "menu-hint":
				TooltipPolicy.install(_stage)
				hud._map.tooltip_text = "Map"
				hud._menu.tooltip_text = "Menu"
			if state.begins_with("countdown"):
				var countdown := EncounterCountdownReadout.new()
				countdown.active = true
				countdown.frozen = state.ends_with("frozen")
				countdown.remaining = 1.8
				countdown.threat_label = "Patrol"
				hud.present_countdown(countdown)
			elif state == "quest":
				var change := QuestChange.new()
				change.title = WorldCopy.QUEST_BELL_TITLE
				change.objective = WorldCopy.OBJECTIVE_RESTORE
				hud._quest_changed(change)
			elif state != "menu-hint":
				var notices := JourneyNotices.new()
				_stage.add_child(notices)
				notices._save_completed(SaveFact.make(0, SaveFact.Origin.MANUAL if state == "manual-save" else SaveFact.Origin.AUTOMATIC))
		_:
			push_error("Unknown revision capture state: " + state)
			get_tree().quit(1)
			return
	for index in 12: await get_tree().process_frame
	if _args.has("checkbox"):
		var check := _stage.find_children("*", "CheckBox", true, false)[0] as CheckBox
		var variant := String(_args.checkbox)
		check.tooltip_text = "" # State-art fixture only; omit the unrelated inspection popup.
		check.set_pressed_no_signal(variant in ["focused", "disabled"])
		check.disabled = variant == "disabled"
		if variant == "focused": check.grab_focus()
		if variant in ["hover", "pressed"]:
			var motion := InputEventMouseMotion.new()
			motion.position = check.get_global_rect().get_center()
			get_viewport().push_input(motion, true)
			if variant == "pressed":
				var press := InputEventMouseButton.new()
				press.position = motion.position
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				get_viewport().push_input(press, true)
		for index in 8: await get_tree().process_frame
	if state == "loadout-popup":
		(_stage.find_child("Slot_weapon", true, false) as Button).pressed.emit()
		for index in 12: await get_tree().process_frame
	if _args.has("inspect"):
		var source := _stage.find_child(String(_args.inspect), true, false) as Control
		if source == null:
			push_error("Requested inspection source is absent: " + String(_args.inspect))
		else:
			source.grab_focus()
			for inspector in _stage.find_children("*", "PanelContainer", true, false):
				if inspector is HoverInspector: inspector.follow_keyboard()
			for index in 12: await get_tree().process_frame
	if _args.has("edge"):
		var source := Button.new()
		source.text = "?"
		source.size = Vector2(48, 48)
		var edge := String(_args.edge)
		source.position = Vector2(1220 if edge.ends_with("r") else 12, 660 if edge.begins_with("b") else 12)
		source.tooltip_text = "New Journey\nChoose your companion, pet and starter equipment, then select a save slot."
		_stage.add_child(source)
		TooltipPolicy.install(_stage)
		var inspector := _stage.get_node("ContextTooltip") as HoverInspector
		inspector.follow_keyboard()
		source.grab_focus()
		for index in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := String(_args.get("out", "res://docs/reports/v0_5_playtest_revision/" + state + "_" + String(_args.get("size", "1280x720")) + ".png"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := get_tree().root.get_texture().get_image().save_png(output)
	print("Capture fixture: %s (%s), %d memory writes, output %s, result %d" % [state, preset, _kit.writer.writes.size(), output, error])
	_kit.restore()
	AudioManager.silence()
	_stage.queue_free()
	for index in 4: await get_tree().process_frame
	await get_tree().create_timer(.1, true, false, true).timeout
	var errors := _logger.take_errors()
	for diagnostic in errors: print("Capture error: " + diagnostic)
	OS.remove_logger(_logger)
	get_tree().quit(0 if error == OK and errors.is_empty() else 1)
