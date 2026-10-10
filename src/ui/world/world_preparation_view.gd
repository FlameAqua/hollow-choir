class_name WorldPreparationView
extends VBoxContainer
## Four slots, owned choices and public facts. All eligibility and action counts are readouts.

signal equip_requested(slot: Enums.EquipSlot, item_id: StringName)
signal unequip_requested(slot: Enums.EquipSlot)

var selected_slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON
var _readout: PreparationReadout
var _choices: VBoxContainer
var _details: WorldEquipmentDetails
var _scroll: ScrollContainer
var _tabs: Array[Button] = []


func present(readout: PreparationReadout, slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON) -> void:
	_readout = readout
	selected_slot = slot
	add_theme_constant_override("separation", 12)
	var count := UITheme.label("Hollow actions  %d / %d    ·    Mara  %d / %d" % [readout.protagonist_actions,
		readout.action_limit, readout.companion_actions, readout.action_limit], UITheme.INFO, 22, true)
	count.name = "ActionCount"
	add_child(count)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	add_child(tabs)
	for entry in readout.slots:
		var button := Button.new()
		button.name = "Slot_" + entry.label
		button.text = "%s\n%s" % [entry.label, entry.equipped_name if not entry.equipped_name.is_empty() else "Empty"]
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		tabs.add_child(button)
		_tabs.append(button)
		button.pressed.connect(func() -> void: select_slot(entry.slot))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.name = "ChoicesScroll"
	choices_scroll.custom_minimum_size.x = 310
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.follow_focus = true
	row.add_child(choices_scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation", 10)
	choices_scroll.add_child(_choices)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UICraft.panel("bag", 12, 12))
	row.add_child(panel)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(detail_column)
	_scroll = ScrollContainer.new()
	_scroll.name = "EquipmentScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(_scroll)
	_details = WorldEquipmentDetails.new()
	_details.name = "EquipmentDetails"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_details)
	add_child(UITheme.label(WorldCopy.PREP_FOOTER, UITheme.TEXT_DIM, 22, true))
	select_slot(slot)


func select_slot(slot: Enums.EquipSlot) -> void:
	selected_slot = slot
	for index in _tabs.size():
		_tabs[index].set_pressed_no_signal(_readout.slots[index].slot == slot)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var entry := _readout.slot(slot)
	var selected: Button = null
	var first: Button = null
	for option in entry.options:
		var button := Button.new()
		button.name = ("Weapon_" if slot == Enums.EquipSlot.WEAPON else "Item_") + String(option.id)
		button.text = String(option.name)
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.set_pressed_no_signal(option.equipped)
		button.disabled = not option.selectable
		if option.equipped:
			button.icon = preload("res://assets/art/global/ui/world/equipped.svg")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		_choices.add_child(button)
		button.focus_entered.connect(func() -> void: _show_option(option))
		button.mouse_entered.connect(func() -> void: _show_option(option))
		button.pressed.connect(func() -> void: equip_requested.emit(slot, option.id))
		if not option.selectable:
			_choices.add_child(UITheme.label(String(option.reason_text), UITheme.DANGER, 22, true))
		if first == null and not button.disabled:
			first = button
		if option.equipped:
			selected = button
	if entry.options.is_empty():
		_choices.add_child(UITheme.label("No owned %s." % entry.label.to_lower(), UITheme.TEXT_DIM, 22, true))
		for child in _details.get_children():
			_details.remove_child(child)
			child.queue_free()
		_details.text = ""
		_details.add_child(UITheme.label(WorldCopy.PREP_EMPTY, UITheme.TEXT_DIM, 22, true))
	else:
		var option := entry.option(entry.equipped_id)
		_show_option(entry.options[0] if option.is_empty() else option)
	if entry.optional:
		var remove := Button.new()
		remove.name = "RemoveItem"
		remove.text = "Remove " + entry.label.to_lower()
		remove.custom_minimum_size.y = 48
		remove.disabled = not entry.can_remove
		_choices.add_child(remove)
		remove.pressed.connect(func() -> void: unequip_requested.emit(slot))
	# The options change with the slot; rebuild the modal's bounded focus route after layout.
	_relink.call_deferred()
	WorldModal.focus_later(selected if selected != null and not selected.disabled else first)


func _show_option(option: Dictionary) -> void:
	_details.present(option, _readout.action_limit)
	_scroll.scroll_vertical = 0


func focus_choice(item_id: StringName = &"") -> void:
	var first: Button = null
	var selected: Button = null
	for child in _choices.get_children():
		if child is Button and not child.disabled:
			if first == null:
				first = child
			if child.button_pressed or (item_id != &"" and child.name.ends_with(String(item_id))):
				selected = child
	WorldModal.focus_later(selected if selected != null else first)


func show_notice(value: String) -> void:
	if not value.is_empty():
		_choices.add_child(UITheme.label(value, UITheme.INFO, 22, true))


func _relink() -> void:
	var parent := get_parent()
	while parent != null and not parent is WorldModal:
		parent = parent.get_parent()
	if parent is WorldModal:
		(parent as WorldModal)._link_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Read long facts using either keyboard or controller without moving the selected item.
	if event.is_action_pressed(&"ui_page_down", true):
		_scroll.scroll_vertical += 160
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_page_up", true):
		_scroll.scroll_vertical -= 160
		get_viewport().set_input_as_handled()
