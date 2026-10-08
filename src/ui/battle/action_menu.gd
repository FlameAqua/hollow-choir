class_name ActionMenu
extends PanelContainer
## Flat action grid + existing potion slots. Both use the same ActionOption path.
signal row_focused(option: ActionOption, group: Array)
signal option_chosen(option: ActionOption)
var supplies: PanelContainer
var _heading: Label
var _list: GridContainer
var _supply_list: GridContainer
var _buttons: Array[Button] = []
var _options: Array[ActionOption] = []
var _engine: BattleEngine
var _unit: BattleUnit
var _memory: Dictionary[int, int] = {}
var preview_provider: Callable
var _action_scroll: ScrollContainer
var _supply_scroll: ScrollContainer

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	_heading = UITheme.heading("Actions")
	column.add_child(_heading)
	var scroll := ScrollContainer.new()
	_action_scroll = scroll
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 3
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

func setup_supplies(panel: PanelContainer) -> void:
	supplies = panel
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := UITheme.heading("Supply")
	heading.tooltip_text = "Supplies\nEquipped potions and remaining charges."
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	_supply_scroll = scroll
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_supply_list = GridContainer.new()
	_supply_list.columns = 2
	_supply_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_supply_list)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton or not event.pressed or not event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	for scroll in [_action_scroll, _supply_scroll]:
		if scroll != null and scroll.is_visible_in_tree() and hovered != null and (hovered == scroll or scroll.is_ancestor_of(hovered)):
			scroll.scroll_vertical += (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1) * 64
			get_viewport().set_input_as_handled()
			return

func show_options(unit: BattleUnit, options: Array[ActionOption], engine: BattleEngine) -> void:
	_unit = unit
	_options = options
	_engine = engine
	visible = true
	if supplies != null:
		supplies.visible = true
	_rebuild()

func hide_menu() -> void:
	visible = false

func in_group() -> bool:
	return false

func back() -> bool:
	return false

func refocus() -> void:
	focus_index(_memory.get(_unit.uid, 0))

func focus_option(option: ActionOption) -> void:
	for button in _buttons:
		if button.get_meta(&"option", null) == option:
			button.grab_focus()
			return
	refocus()

func focus_index(index: int) -> void:
	if not _buttons.is_empty() and visible:
		_buttons[clampi(index, 0, _buttons.size() - 1)].grab_focus()

func row_texts() -> PackedStringArray:
	var result := PackedStringArray()
	for button in _buttons:
		result.append(str(button.get_meta(&"text", "")))
	return result

func _rebuild() -> void:
	_list.columns = 3 if UITheme.text_scale() >= 1.5 else 2
	if _supply_list != null:
		_supply_list.columns = 1 if UITheme.text_scale() >= 1.5 else 2
	for host in [_list, _supply_list]:
		if host == null:
			continue
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()
	_buttons.clear()
	_heading.text = _unit.display_name.to_upper()
	for option in _options:
		var host := _supply_list if option.item_slot >= 0 and _supply_list != null else _list
		host.add_child(_option_button(option))
	if _supply_list != null and _supply_list.get_child_count() == 0:
		var empty := UITheme.label("—", UITheme.TEXT_FAINT)
		empty.tooltip_text = "No potions equipped in this loadout."
		_supply_list.add_child(empty)
	for i in _buttons.size():
		var button := _buttons[i]
		button.focus_next = button.get_path_to(_buttons[wrapi(i + 1, 0, _buttons.size())])
		button.focus_previous = button.get_path_to(_buttons[wrapi(i - 1, 0, _buttons.size())])
	focus_index.call_deferred(_memory.get(_unit.uid, 0))

func _option_button(option: ActionOption) -> Button:
	var item := option.item_slot >= 0
	var label := option.action.display_name
	var count := str(option.action.focus_cost)
	if item:
		var slot := _engine.get_state().potion_slots[option.item_slot]
		label = slot.potion.display_name
		count = "×%d" % slot.charges
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, UITheme.control_height())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta(&"option", option)
	button.set_meta(&"inspection_readout", func(_point: Vector2) -> ActionReadout:
		if preview_provider.is_valid():
			return preview_provider.call(option)
		var target := option.target_uids[0] if not option.target_uids.is_empty() else -1
		return ActionReadout.build(_engine, _unit.uid, option, target))
	button.set_meta(&"text", "%s %s" % [label, count])
	var description := _engine.get_state().potion_slots[option.item_slot].potion.description if item else option.action.description
	button.tooltip_text = "%s\n%s\n%s" % [label, description, ActionReadout.reason_text(_unit, option) if not option.legal else ("%s charges" % count.trim_prefix("×") if item else "%s Focus" % count)]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	var icon_id := CombatIcons.mapping("potions", _engine.get_state().potion_slots[option.item_slot].potion.id) if item else CombatIcons.action(option)
	var icon := CombatIcons.image(icon_id, 30)
	row.add_child(icon)
	if not item and UITheme.text_scale() < 1.5:
		var name := UITheme.label(label, UITheme.TEXT if option.legal else UITheme.TEXT_FAINT, UITheme.secondary_size())
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name)
	if not item:
		row.add_child(CombatIcons.image("focus", 14))
	var amount := UITheme.label(count, UITheme.ACCENT if option.legal else UITheme.TEXT_FAINT, UITheme.secondary_size())
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount)
	if not option.legal:
		icon.modulate = Color(0.55, 0.55, 0.55)
		row.add_child(CombatIcons.image("unavailable", 18))
	_buttons.append(button)
	button.focus_entered.connect(func() -> void:
		_memory[_unit.uid] = _buttons.find(button)
		row_focused.emit(option, []))
	# Pointer preview never steals keyboard focus or turns a stray accept into a hovered action.
	button.mouse_entered.connect(func() -> void: row_focused.emit(option, []))
	button.pressed.connect(func() -> void: option_chosen.emit(option))
	return button
