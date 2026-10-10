class_name ActionMenu
extends PanelContainer
## Flat action grid + existing potion slots. Both use the same ActionOption path.
## The grid's fixed capacity: two columns of four rows, no scrolling. Potions live in Supplies.
## tests/unit/test_action_capacity.gd holds every party member's non-item actions to it.
## Every party member has up to eight action slots (Adrian, 9 October 2026); a slot without an
## action shows an empty, inert frame, so the grid always reads as eight slots. The number is the
## rule's (PartyLoadout.MAX_ACTIONS), which campaign preparation also enforces.
const CAPACITY := PartyLoadout.MAX_ACTIONS
const EMPTY_SLOT_TINT := Color(0.6, 0.6, 0.6, 0.5)
signal row_focused(option: ActionOption)
signal option_chosen(option: ActionOption)
var supplies: PanelContainer
var _list: GridContainer
var _supply_list: GridContainer
var _buttons: Array[Button] = []
var _options: Array[ActionOption] = []
var _engine: BattleEngine
var _unit: BattleUnit
var _memory: Dictionary[int, int] = {}
var preview_provider: Callable
## (hovered: Control) -> bool: another pane owns this wheel event (HoverInspector.claims_wheel).
## The lists then stay still, so one wheel event never moves two panes.
var wheel_claimed: Callable
var _supply_scroll: ScrollContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UICraft.panel("cloth", 14, 10))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	_list = GridContainer.new()
	_list.columns = 2
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(_list)

func setup_supplies(panel: PanelContainer) -> void:
	supplies = panel
	var column := VBoxContainer.new()
	panel.add_child(column)
	panel.tooltip_text = "Supplies\nEquipped potions and remaining charges."
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
	if wheel_claimed.is_valid() and wheel_claimed.call(hovered):
		return
	for scroll in [_supply_scroll]:
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

## Recipient review releases keyboard focus; the reviewed action keeps the selected frame it showed
## while focused, so the pending choice stays obvious. null restores every row's own frame.
func mark_pending(option: ActionOption) -> void:
	for button in _buttons:
		var pending: bool = option != null and button.get_meta(&"option", null) == option
		button.set_meta(&"pending", pending)
		button.add_theme_stylebox_override("normal", UICraft.panel("selected", 12, 8) if pending else button.get_meta(&"normal_style"))

func pending_button() -> Button:
	for button in _buttons:
		if button.get_meta(&"pending", false):
			return button
	return null

func _rebuild() -> void:
	_list.columns = 2
	if _supply_list != null:
		_supply_list.columns = 1 if UITheme.text_scale() >= 1.5 else 2
	for host in [_list, _supply_list]:
		if host == null:
			continue
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()
	_buttons.clear()
	for option in _options:
		var host := _supply_list if option.item_slot >= 0 and _supply_list != null else _list
		host.add_child(_option_button(option))
	for i in maxi(0, CAPACITY - _list.get_child_count()):
		_list.add_child(_empty_slot())
	if _supply_list != null and _supply_list.get_child_count() == 0:
		var empty := UITheme.label("—", UITheme.TEXT_FAINT)
		empty.tooltip_text = "No potions equipped in this loadout."
		_supply_list.add_child(empty)
	for i in _buttons.size():
		var button := _buttons[i]
		button.focus_next = button.get_path_to(_buttons[wrapi(i + 1, 0, _buttons.size())])
		button.focus_previous = button.get_path_to(_buttons[wrapi(i - 1, 0, _buttons.size())])
	focus_index.call_deferred(_memory.get(_unit.uid, 0))

## An unused action slot: the neutral slot frame, dimmed. It takes no focus, pointer or inspection.
func _empty_slot() -> Panel:
	var slot := Panel.new()
	slot.name = "EmptySlot"
	slot.add_theme_stylebox_override("panel", UICraft.panel("utility", 12, 8, EMPTY_SLOT_TINT))
	slot.custom_minimum_size = Vector2(0, UITheme.control_height())
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.focus_mode = Control.FOCUS_NONE
	return slot

func _option_button(option: ActionOption) -> Button:
	var item := option.item_slot >= 0
	var label := option.action.display_name
	var count := str(option.action.focus_cost)
	if item:
		var slot := _engine.get_state().potion_slots[option.item_slot]
		label = slot.potion.display_name
		count = "×%d" % slot.charges
	var button := Button.new()
	var material := "utility" if item or option.action.category in [Enums.ActionCategory.GUARD, Enums.ActionCategory.INSPECT] else "attack" if option.action.category == Enums.ActionCategory.ATTACK else "technique"
	var normal := UICraft.panel(material, 12, 8)
	button.set_meta(&"normal_style", normal)
	button.add_theme_stylebox_override("normal", normal)
	button.custom_minimum_size = Vector2(84 if item else 0, UITheme.control_height())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta(&"option", option)
	button.set_meta(&"inspection_readout", func(_point: Vector2) -> ActionReadout:
		if preview_provider.is_valid():
			return preview_provider.call(option)
		var target := option.target_uids[0] if not option.target_uids.is_empty() else -1
		return ActionReadout.build(_engine, _unit.uid, option, target))
	var description := _engine.get_state().potion_slots[option.item_slot].potion.description if item else option.action.description
	button.tooltip_text = "%s\n%s\n%s" % [label, description, ActionReadout.reason_text(_unit, option) if not option.legal else ("%s charges" % count.trim_prefix("×") if item else "%s Focus" % count)]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 17
	row.offset_right = -17
	var icon_id := CombatIcons.mapping("potions", _engine.get_state().potion_slots[option.item_slot].potion.id) if item else CombatIcons.action(option)
	var icon := CombatIcons.image(icon_id, 24)
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
		row_focused.emit(option))
	# Pointer preview never steals keyboard focus or turns a stray accept into a hovered action.
	button.mouse_entered.connect(func() -> void: row_focused.emit(option))
	button.pressed.connect(func() -> void: option_chosen.emit(option))
	return button
