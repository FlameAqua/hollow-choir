class_name ActionMenu
extends PanelContainer
## The command list for the acting unit, grouped by the GDD's action types. Illegal options stay
## visible with their reason (rules are never hidden). Keyboard/gamepad via focus, mouse via clicks.

signal option_focused(option: ActionOption)
signal option_chosen(option: ActionOption)

const ORDER := [Enums.ActionCategory.ATTACK, Enums.ActionCategory.TECHNIQUE, Enums.ActionCategory.MAGIC,
	Enums.ActionCategory.GUARD, Enums.ActionCategory.ITEM, Enums.ActionCategory.INSPECT]

var _list: VBoxContainer
var _scroll: ScrollContainer
var _buttons: Array[Button] = []
## Last focused entry per unit, so each character's menu reopens where it was left.
var _last_focus: Dictionary[int, int] = {}
var _unit_uid := -1


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)


func show_options(unit: BattleUnit, options: Array[ActionOption], engine: BattleEngine) -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	_unit_uid = unit.uid
	var title := Label.new()
	title.text = "%s — choose an action" % unit.display_name
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	_list.add_child(title)
	for category in ORDER:
		var in_category: Array[ActionOption] = []
		for option in options:
			if option.action.category == category:
				in_category.append(option)
		if in_category.is_empty():
			continue
		var header := Label.new()
		header.text = EnumText.category(category).to_upper() if category != Enums.ActionCategory.ITEM else "ITEMS"
		header.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		header.add_theme_font_size_override("font_size", UITheme.font_size(0.7))
		_list.add_child(header)
		for option in in_category:
			_list.add_child(_make_button(option, engine))
	visible = true
	# Deferred: the new buttons take focus once the old ones are gone (and never on a freed menu).
	focus_index.call_deferred(clampi(_last_focus.get(unit.uid, 0), 0, maxi(0, _buttons.size() - 1)))


## Focuses the entry last used by the current unit (closing a pause overlay).
func refocus() -> void:
	focus_index(clampi(_last_focus.get(_unit_uid, 0), 0, maxi(0, _buttons.size() - 1)))


## Focuses the entry for [param option] (returning from target selection).
func focus_option(option: ActionOption) -> void:
	for button in _buttons:
		if button.get_meta(&"option") == option:
			button.grab_focus()
			return
	focus_index(0)


func focus_index(index: int) -> void:
	if _buttons.is_empty() or not visible:
		return
	for offset in _buttons.size():
		var button := _buttons[(index + offset) % _buttons.size()]
		if not button.disabled:
			button.grab_focus()
			return
	_buttons[index].grab_focus()


func hide_menu() -> void:
	visible = false


func _make_button(option: ActionOption, engine: BattleEngine) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	var label := option.action.display_name
	if option.item_slot >= 0:
		var slot := engine.get_state().potion_slots[option.item_slot]
		label = "%s  x%d" % [slot.potion.display_name, slot.charges]
	if option.action.focus_cost > 0:
		label += "  [%d Focus]" % option.action.focus_cost
	# The Focus cost already explains a "Needs N Focus" reason; other reasons are spelled out.
	if not option.legal and not (option.action.focus_cost > 0 and option.reason.begins_with("Needs")):
		label += "  — %s" % option.reason
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.disabled = not option.legal
	button.tooltip_text = option.action.description if option.legal else "%s\n(%s)" % [option.action.description, option.reason]
	button.set_meta(&"option", option)
	button.focus_entered.connect(func() -> void:
		_last_focus[_unit_uid] = _buttons.find(button)
		option_focused.emit(option))
	button.mouse_entered.connect(func() -> void: option_focused.emit(option))
	button.pressed.connect(func() -> void: option_chosen.emit(option))
	_buttons.append(button)
	return button
