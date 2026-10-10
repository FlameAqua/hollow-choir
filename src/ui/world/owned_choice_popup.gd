class_name OwnedChoicePopup
extends PanelContainer
## Small owned-choice list. The caller supplies eligibility and applies every chosen command.
signal chosen(id: StringName)
var _origin: Control
var _choices: Array[Button] = []

static func make(origin: Control, title: String, options: Array[Dictionary]) -> OwnedChoicePopup:
	var popup := OwnedChoicePopup.new()
	popup.name = "OwnedChoices"
	popup._origin = origin
	popup.set_as_top_level(true)
	popup.z_index = 120
	# Item cards for its choices sit beside the whole popup, never over it (HoverInspector).
	popup.set_meta(&"tooltip_anchor", true)
	popup.add_theme_stylebox_override("panel", UICraft.panel("inspection", 16, 16))
	var column := VBoxContainer.new()
	popup.add_child(column)
	column.add_child(UITheme.label(title, UITheme.ACCENT, 22, true))
	var scroll := WorldInventoryView._scroll("OwnedChoicesScroll")
	scroll.custom_minimum_size = Vector2(300, minf(240, maxf(52, options.size() * 52)))
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for option in options:
		var payload: ItemInspectionReadout = option.payload
		var button := WorldInventoryView.item_button(payload, Vector2(0, 48), payload.title)
		button.name = "Owned_" + String(option.id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not option.selectable
		list.add_child(button)
		popup._choices.append(button)
		button.pressed.connect(func() -> void:
			# Restore focus before the synchronous host command can replace this view.
			popup.dismiss()
			popup.chosen.emit(option.id))
	var close := Button.new()
	close.name = "CloseChoices"
	close.text = "Cancel"
	close.custom_minimum_size.y = 40
	column.add_child(close)
	popup._choices.append(close)
	close.pressed.connect(popup.dismiss)
	return popup

func _ready() -> void:
	TooltipPolicy.install(self)
	# Both are top-level, so their z is absolute: the choice's card must out-rank the popup itself.
	(get_node("ContextTooltip") as CanvasItem).z_index = z_index + 10
	_layout.call_deferred()
	for button in _choices:
		if not button.disabled:
			WorldModal.focus_later(button)
			break
	var available: Array[Button] = []
	for button in _choices:
		if not button.disabled: available.append(button)
	for index in available.size():
		var button := available[index]
		var before := button.get_path_to(available[posmod(index - 1, available.size())])
		var after := button.get_path_to(available[(index + 1) % available.size()])
		button.focus_previous = before
		button.focus_next = after
		button.focus_neighbor_top = before
		button.focus_neighbor_bottom = after
		button.focus_neighbor_left = before
		button.focus_neighbor_right = after

func _layout() -> void:
	# A choice made in the frame the popup opened can replace the whole view before this runs.
	if not is_inside_tree():
		return
	size = Vector2(348, get_combined_minimum_size().y)
	if not is_instance_valid(_origin):
		queue_free()
		return
	var point := _origin.get_global_rect().end + Vector2(12, 0)
	position = Vector2(clampf(point.x, 12, maxf(12, get_viewport_rect().size.x - size.x - 12)),
		clampf(_origin.global_position.y, 12, maxf(12, get_viewport_rect().size.y - size.y - 12)))

func dismiss() -> void:
	if is_instance_valid(_origin): WorldModal.focus_later(_origin)
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.CANCEL):
		get_viewport().set_input_as_handled()
		AudioManager.play(AudioManager.Cue.UI_CANCEL, 0, -9)
		dismiss()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
			dismiss()
