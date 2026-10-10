class_name WorldLoadoutView
extends VBoxContainer
## Consumes the published LoadoutReadout. No eligibility, stock or source rules live here.
signal equip_requested(slot: int, item: StringName)
signal unequip_requested(slot: int)
signal potion_requested(slot: int, potion: StringName)
signal combat_requested(command: StringName, position: int, action_id: StringName, other: int)
signal familiar_requested(id: StringName)
signal familiar_passive_requested(id: StringName)
signal position_selected(index: int)
var combat_position := 0
var first_item: Button
var _readout: LoadoutReadout
var _positions: GridContainer
var _sources: Array[Button] = []
var _popup: OwnedChoicePopup
var _selection: Label
var _receipt := ""

func _ready() -> void:
	TooltipPolicy.install.call_deferred(self)

func present(readout: LoadoutReadout) -> void:
	_readout = readout
	name = "Loadout"
	add_theme_constant_override("separation", 10)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 510
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var paper := HBoxContainer.new()
	paper.add_theme_constant_override("separation", 16)
	left.add_child(paper)
	var portrait := JourneyUI.picture(preload("res://assets/art/global/characters/sprites/hollow_idle.png"), Vector2(104, 212))
	paper.add_child(portrait)
	var gear := VBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	paper.add_child(gear)
	for slot in readout.gear:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		gear.add_child(row)
		var equipped: Dictionary = slot.option(slot.equipped_id)
		var payload := ItemInspectionReadout.from_item(equipped) if not equipped.is_empty() else JourneyUI.facts(slot.label, "Empty", "Equipment", JourneyUI.icon("empty"))
		var button := JourneyUI.button(payload)
		button.name = "Slot_" + String(slot.source_id)
		row.add_child(button)
		if first_item == null: first_item = button
		button.pressed.connect(func() -> void: _gear_choices(button, slot))
		UIFeedback.navigation(button)
		var label := UITheme.label(slot.label, UITheme.TEXT_DIM, 22)
		label.custom_minimum_size.x = 72
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		for action in slot.actions: row.add_child(_source(action))
		for index in maxi(0, slot.strip_cells - slot.actions.size()):
			row.add_child(_empty_source())
	# Pet sits directly below the relic, without a separate equipment action footer.
	var pet_row := HBoxContainer.new()
	pet_row.add_theme_constant_override("separation", 12)
	left.add_child(pet_row)
	var pet = readout.familiar
	var pet_payload := JourneyUI.facts(pet.name, pet.description, "Pet", load(pet.portrait_path) if not String(pet.portrait_path).is_empty() else JourneyUI.icon("empty"))
	var pet_button := JourneyUI.button(pet_payload)
	pet_button.name = "Pet"
	pet_row.add_child(pet_button)
	pet_row.add_child(UITheme.label("Pet", UITheme.TEXT_DIM, 22))
	pet_button.pressed.connect(func() -> void: _pet_choices(pet_button))
	UIFeedback.navigation(pet_button)
	for passive in pet.passives:
		var payload := JourneyUI.facts(passive.name, passive.description, "Pet passive", CombatIcons.texture("action_empower"))
		payload.details.append(passive.details)
		var button := JourneyUI.button(payload, Vector2.ONE * UITheme.SOURCE_SIZE)
		button.name = "PetPassive_" + String(passive.id)
		button.toggle_mode = true
		button.set_pressed_no_signal(passive.selected)
		pet_row.add_child(button)
		button.pressed.connect(func() -> void:
			button.set_pressed_no_signal(passive.selected)
			if passive.selectable: familiar_passive_requested.emit(passive.id))
	left.add_child(UITheme.label("Supplies", UITheme.ACCENT, 22))
	var supplies := HBoxContainer.new()
	supplies.name = "PreparedSupplies"
	supplies.add_theme_constant_override("separation", 12)
	left.add_child(supplies)
	for slot in readout.supplies:
		var payload := JourneyUI.supply_inspection(slot)
		var button := JourneyUI.button(payload)
		button.name = "Supply_%d" % slot.index
		if slot.locked: button.modulate = Color(.6, .6, .55)
		elif slot.state == PotionSlotReadout.State.DEPLETED: button.modulate = Color(.65, .65, .65)
		supplies.add_child(button)
		if not slot.locked:
			button.pressed.connect(func() -> void: _supply_choices(button, slot))
			UIFeedback.navigation(button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(UITheme.label("Combat · %d / %d" % [readout.capacity, readout.positions_total], UITheme.ACCENT, 22))
	_positions = GridContainer.new()
	_positions.name = "CombatSlots"
	_positions.columns = 4
	_positions.add_theme_constant_override("h_separation", 12)
	_positions.add_theme_constant_override("v_separation", 12)
	right.add_child(_positions)
	combat_position = clampi(combat_position, 0, maxi(0, int(readout.capacity) - 1))
	for entry in readout.positions:
		var action := _action(entry.action_id)
		var payload := JourneyUI.action_fact(action) if not action.is_empty() else JourneyUI.facts("Empty position", "Choose a source action.", "Combat", JourneyUI.icon("empty"))
		if entry.locked: payload = JourneyUI.facts("Locked position", entry.reason_text, "Locked", JourneyUI.icon("lock"))
		var button := JourneyUI.button(payload)
		button.name = "CombatSlot_%d" % entry.index
		button.toggle_mode = not entry.locked
		_positions.add_child(button)
		if not entry.locked:
			button.pressed.connect(func() -> void:
				combat_position = entry.index
				position_selected.emit(combat_position)
				_refresh_selection())
			UIFeedback.navigation(button)
	right.add_child(UITheme.label("Active passives", UITheme.ACCENT, 22))
	var passives := GridContainer.new()
	passives.name = "ActivePassives"
	passives.columns = 8
	right.add_child(passives)
	for entry in readout.passives:
		var payload := JourneyUI.facts(entry.name, entry.description, "Passive · " + String(entry.source_name), CombatIcons.texture("action_empower"))
		payload.details.append(entry.details)
		var button := JourneyUI.button(payload, Vector2.ONE * UITheme.SOURCE_SIZE)
		button.name = "Passive_" + String(entry.id)
		passives.add_child(button)
	right.add_child(UITheme.label("Core / stance", UITheme.ACCENT, 22))
	var core := GridContainer.new()
	core.columns = 8
	right.add_child(core)
	for entry in readout.core: core.add_child(_source(entry))
	_selection = UITheme.label("", UITheme.INFO, 22, true)
	_selection.name = "SelectionStatus"
	_selection.custom_minimum_size.y = 54
	right.add_child(_selection)
	_refresh_selection()

func _source(action: Dictionary) -> Button:
	var button := JourneyUI.button(JourneyUI.action_fact(action), Vector2.ONE * UITheme.SOURCE_SIZE)
	button.name = "Source_" + String(action.id)
	button.toggle_mode = true
	button.set_meta(&"action_fact", action)
	_sources.append(button)
	button.pressed.connect(func() -> void:
		button.set_pressed_no_signal(action.arranged)
		if action.selectable: combat_requested.emit(&"put", combat_position, action.id, -1))
	return button

func _empty_source() -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2.ONE * UITheme.SOURCE_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell

func _action(id: StringName) -> Dictionary:
	for slot in _readout.gear:
		for action in slot.actions:
			if action.id == id: return action
	for action in _readout.core:
		if action.id == id: return action
	return {}

func _refresh_selection() -> void:
	for button in _positions.get_children():
		button.set_pressed_no_signal(button.name == "CombatSlot_%d" % combat_position)
	for button in _sources:
		var action: Dictionary = button.get_meta(&"action_fact")
		button.set_pressed_no_signal(action.arranged)
		button.modulate = Color.WHITE if action.arranged else Color(.78, .78, .74)
	if _selection != null:
		_selection.text = _receipt if not _receipt.is_empty() else "Position %d · choose a source" % (combat_position + 1)
		var names := PackedStringArray()
		for id in _readout.unarranged:
			var action := _action(id)
			if not action.is_empty(): names.append(action.name)
		if not names.is_empty(): _selection.text += "\nUnplaced: " + ", ".join(names)

func present_preparation(result: PreparationResult) -> void:
	_receipt = "Saved · %d positions kept" % result.actions_kept.size() if result.changed else WorldCopy.PREP_UNCHANGED
	if not result.ok(): _receipt = result.text()
	_refresh_selection()

func _show_choices(origin: Control, title: String, options: Array[Dictionary], callback: Callable) -> void:
	if is_instance_valid(_popup):
		remove_child(_popup)
		_popup.queue_free()
	_popup = OwnedChoicePopup.make(origin, title, options)
	_popup.chosen.connect(callback)
	add_child(_popup)

func _gear_choices(button: Control, slot) -> void:
	var options: Array[Dictionary] = []
	for entry in slot.options:
		var payload := ItemInspectionReadout.from_item(entry)
		if not entry.selectable: payload.facts.append(entry.reason_text)
		options.append({"id": entry.id, "payload": payload, "selectable": entry.selectable})
	if slot.optional:
		options.append({"id": &"", "payload": JourneyUI.facts("Remove", "", slot.label, JourneyUI.icon("empty")), "selectable": slot.can_remove})
	_show_choices(button, slot.label, options, func(id: StringName) -> void:
		if id == &"": unequip_requested.emit(slot.slot)
		else: equip_requested.emit(slot.slot, id))

func _pet_choices(button: Control) -> void:
	var options: Array[Dictionary] = []
	for entry in _readout.familiar.choices:
		var payload := JourneyUI.facts(entry.name, entry.description, "Owned pet", load(entry.portrait_path) if not String(entry.portrait_path).is_empty() else null)
		if not entry.selectable: payload.facts.append(entry.reason_text)
		options.append({"id": entry.id, "payload": payload, "selectable": entry.selectable})
	_show_choices(button, "Pet", options, func(id: StringName) -> void: familiar_requested.emit(id))

func _supply_choices(button: Control, slot) -> void:
	var options: Array[Dictionary] = []
	for entry in slot.choices:
		var payload := JourneyUI.facts(entry.name, entry.description, "Supply", JourneyUI.potion_icon(entry.id, entry.icon_path))
		payload.facts = PackedStringArray(["Held  %d · next battle  %d / %d" % [entry.held, entry.usable, entry.cap]])
		if not entry.selectable: payload.facts.append(entry.reason_text)
		options.append({"id": entry.id, "payload": payload, "selectable": entry.selectable})
	_show_choices(button, "Supply %d" % (slot.index + 1), options, func(id: StringName) -> void: potion_requested.emit(slot.index, id))
