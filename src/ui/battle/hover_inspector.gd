class_name HoverInspector
extends PanelContainer
## One contextual card. Modifier keys never change its source; only deliberate navigation does.
const EXIT_GRACE := 0.14
const SWAP_SETTLE := 0.065
var enabled := true
## Fixed shared information dock. No inspection card covers the battlefield.
var docked := false
var fallback_source: Callable
var suppressed: Callable
var bounds_provider: Callable
var keyboard_source: Callable
var expanded := false
var _text: RichTextLabel
var _scroll: ScrollContainer
var _card: PreviewPanel
var _unit_card: UnitInspectionCard
var _content: InspectionContent
var _shown := ""
var _candidate := ""
var _age := 0.0
var _pointer := true
var _accent := UITheme.ACCENT
var _payload: RefCounted
var _render_key := ""
var _source: Control
var _hint: Label
var _pointer_position := Vector2.ZERO
var pinned := false
var _field_help: PanelContainer
var _field_text: Label

func _ready() -> void:
	_pointer_position = get_viewport().get_mouse_position()
	z_index = 90
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UICraft.panel("inspection", 14, 14))
	var column := VBoxContainer.new()
	add_child(column)
	_scroll = ScrollContainer.new()
	_scroll.name = "InspectionScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = InspectionContent.new()
	_scroll.add_child(_content)
	var body := _content.body
	_card = PreviewPanel.new()
	_card.compact = docked
	_card.visible = false
	body.add_child(_card)
	_unit_card = UnitInspectionCard.new()
	_unit_card.visible = false
	body.add_child(_unit_card)
	_text = UITheme.rich_text(UITheme.secondary_size())
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_text)
	_hint = UITheme.label("", UITheme.TEXT_DIM, 11 if docked else UITheme.secondary_size())
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var footer := InspectionContent.new()
	column.add_child(footer)
	footer.body.add_child(_hint)
	# Only fields within this inspector get a secondary explanation. It never replaces the card.
	_field_help = PanelContainer.new()
	_field_help.name = "FieldHelp"
	_field_help.z_index = 1
	_field_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_help.add_theme_stylebox_override("panel", UICraft.panel("tooltip", 14, 14))
	_field_help.visible = false
	var help_host := Control.new()
	help_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_host)
	help_host.add_child(_field_help)
	_field_text = UITheme.label("", UITheme.TEXT, UITheme.secondary_size(), true)
	_field_text.custom_minimum_size.x = 260
	_field_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var field_content := InspectionContent.new()
	_field_help.add_child(field_content)
	field_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_content.body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_content.body.add_child(_field_text)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer = true
		_pointer_position = event.position
	elif event.is_pressed() and not event.is_echo():
		for action in [InputBindings.UP, InputBindings.DOWN, InputBindings.LEFT, InputBindings.RIGHT, InputBindings.CONFIRM, InputBindings.CANCEL]:
			if event.is_action(action):
				_pointer = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_pointer = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and enabled and not (suppressed.is_valid() and suppressed.call()):
		if pinned:
			pinned = false
			_field_help.hide()
			_update_hint()
			get_viewport().set_input_as_handled()
		else:
			var subject := _resolve(get_viewport().gui_get_hovered_control())
			if not subject.is_empty():
				_adopt(subject)
				pinned = true
				_update_hint()
				get_viewport().set_input_as_handled()
	# Wheel works over the inspected icon as well as inside the card; no pointer chase is needed.
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if claims_wheel(get_viewport().gui_get_hovered_control()):
			_scroll.scroll_vertical += (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1) * 72
			get_viewport().set_input_as_handled()
	if visible and not _pointer and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_scroll.scroll_vertical += (-1 if event.physical_keycode == KEY_PAGEUP else 1) * maxi(72, int(_scroll.size.y * 0.8))
		get_viewport().set_input_as_handled()

## The single wheel rule for a battle: does a wheel event over [param hovered] scroll this card?
## Yes over the card itself, or over its current source when that card has overflow.
## Otherwise Actions/Supplies keep their own list wheel. Every wheel handler asks here, so one
## event moves one pane regardless of which handler the scene tree calls first.
func claims_wheel(hovered: Control) -> bool:
	if not visible or hovered == null:
		return false
	if hovered == self or is_ancestor_of(hovered):
		return true
	if not is_instance_valid(_source) or (hovered != _source and not _source.is_ancestor_of(hovered)):
		return false
	if expanded or _scroll.get_v_scroll_bar().max_value > _scroll.size.y + 1:
		return true
	var parent := hovered
	while parent != null:
		if parent is ScrollContainer:
			return false
		parent = parent.get_parent_control()
	return true

## Deliberate keyboard/controller navigation selects focus inspection (or the reviewed target).
## Pointer motion or a click selects pointer inspection again. Modifier keys never switch it.
func follow_keyboard() -> void:
	_pointer = false

func follows_pointer() -> bool:
	return _pointer

func clear() -> void:
	pinned = false
	if _field_help != null:
		_field_help.hide()
	visible = false
	_shown = ""
	_candidate = ""
	_render_key = ""
	_source = null
	_payload = null

func _process(delta: float) -> void:
	_update_hint()
	if not enabled or (suppressed.is_valid() and suppressed.call()):
		clear()
		return
	# Source destruction also releases a pin while the pointer is still reading its fields.
	if pinned and (not is_instance_valid(_source) or not _source.is_visible_in_tree()):
		clear()
		return
	var source := get_viewport().gui_get_hovered_control() if _pointer else get_viewport().gui_get_focus_owner()
	if source == null and not _pointer and keyboard_source.is_valid():
		source = keyboard_source.call()
	if source != null and (source == self or is_ancestor_of(source)):
		_render_content(_shown, _payload)
		var fact := ""
		if _card.visible:
			fact = _card.field_tooltip(_local_point(_card))
		elif _unit_card.visible:
			var field := source
			while field != null and field != self:
				fact = field.get_tooltip(_local_point(field))
				if not fact.is_empty():
					break
				field = field.get_parent_control()
		_show_field(fact if _pointer else "")
		return
	_field_help.hide()
	if pinned:
		_render_content(_shown, _payload)
		return
	var original := source
	var battle := get_parent_control()
	var outside := source != null and battle != null and source != battle and not battle.is_ancestor_of(source)
	var content := ""
	var enemy := false
	var payload: RefCounted
	while not outside and source != null and content.is_empty():
		var point := _local_point(source) if _pointer else source.size * 0.5
		content = source.get_tooltip(point)
		if not content.is_empty():
			enemy = bool(source.get_meta(&"enemy_inspection", false))
			var provider: Callable = source.get_meta(&"inspection_readout", source.get_meta(&"inspection_intent", source.get_meta(&"inspection_unit", Callable())))
			if provider.is_valid():
				payload = provider.call(point)
		source = source.get_parent_control()
	# Keyboard navigation may inspect the current action; pointer exit leaves the dock empty.
	if docked and not _pointer and content.is_empty() and fallback_source.is_valid():
		var fallback: Control = fallback_source.call()
		if fallback != null:
			content = fallback.tooltip_text
			var provider: Callable = fallback.get_meta(&"inspection_readout", Callable())
			if provider.is_valid():
				payload = provider.call(Vector2.ZERO)
			original = fallback
	# Expanded floating analysis stays reachable across the gap to its scrollbar.
	if content.is_empty() and expanded and not docked and not outside and not _shown.is_empty():
		_render_content(_shown, _payload)
		return
	var previous := _shown
	advance(content, delta)
	if not visible:
		return
	if content == _shown:
		_payload = payload
		_source = original
		var accent := UITheme.DANGER if enemy else UITheme.ACCENT
		if accent != _accent:
			_accent = accent
			add_theme_stylebox_override("panel", UICraft.panel("inspection", 14, 14))
		_render_content(content, payload)
	if previous != _shown:
		_position_card()

func _render_content(content: String, payload: RefCounted) -> void:
	var key := content + str(expanded)
	if key == _render_key:
		return
	_render_key = key
	_card.visible = payload is ActionReadout or payload is IntentReadout
	_unit_card.visible = payload is UnitReadout
	if payload != null:
		if payload is ActionReadout:
			_card.show_readout(payload)
			_text.text = payload.description + ("\n\n" + PreviewPanel.describe_details(payload, false) if expanded else "")
		elif payload is IntentReadout:
			_card.show_intent(payload)
			_text.text = PreviewPanel.intent_details(payload) if expanded else payload.telegraph
		elif payload is UnitReadout:
			_unit_card.show_readout(payload, expanded)
			_text.text = ""
		if _card.visible:
			_card.custom_minimum_size.y = PreviewPanel.card_height(payload, docked)
		_text.visible = not payload is UnitReadout and (expanded or payload is ActionReadout or docked)
	else:
		_text.visible = true
		_text.text = _styled(content, _accent)
	_fit(content, payload)
	_content._layout.call_deferred()
	_update_hint()

func _update_hint() -> void:
	if _hint == null:
		return
	var parts := PackedStringArray()
	var compact := UITheme.text_scale() >= 1.5
	if pinned:
		parts.append("Pinned · Right-click to release")
	elif not _shown.is_empty():
		parts.append("Right-click to pin")
	if _payload is ActionReadout or _payload is IntentReadout or _payload is UnitReadout:
		match Settings.data.advanced_tooltips:
			GameSettings.TooltipMode.HOLD:
				parts.append((("Release %s" if expanded else "Hold %s") if compact else ("Release %s to collapse" if expanded else "Hold %s for details")) % InputBindings.prompt(InputBindings.INFO))
			GameSettings.TooltipMode.TOGGLE:
				parts.append(("%s %s" if compact else "%s %s details") % [InputBindings.prompt(InputBindings.INFO), "Hide" if expanded else "Show"])
	if _scroll.get_v_scroll_bar().max_value > _scroll.size.y + 1:
		parts.append(("Scroll" if compact else "Scroll for more") if _pointer else "PgUp/PgDn" if compact else "Page Up / Down to scroll")
	_hint.text = " · ".join(parts)
	_hint.visible = not _hint.text.is_empty()

## The pointer in [param control]'s own coordinates, through any content scale (82% cards).
func _local_point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas().affine_inverse() * _pointer_position

## Resolve only sources inside this battle, through ignored icon/label children.
func _resolve(source: Control) -> Dictionary:
	var battle := get_parent_control()
	if source == null or source == self or is_ancestor_of(source) or (battle != null and source != battle and not battle.is_ancestor_of(source)):
		return {}
	while source != null:
		var point := _local_point(source)
		var content := source.get_tooltip(point)
		if not content.is_empty():
			var provider: Callable = source.get_meta(&"inspection_readout", source.get_meta(&"inspection_intent", source.get_meta(&"inspection_unit", Callable())))
			return {"source": source, "content": content, "payload": provider.call(point) if provider.is_valid() else null, "enemy": bool(source.get_meta(&"enemy_inspection", false))}
		source = source.get_parent_control()
	return {}

func _adopt(subject: Dictionary) -> void:
	advance(subject.content, SWAP_SETTLE)
	_source = subject.source
	_payload = subject.payload
	_accent = UITheme.DANGER if subject.enemy else UITheme.ACCENT
	_render_key = ""
	_render_content(_shown, _payload)
	_position_card()

func _show_field(fact: String) -> void:
	if fact.is_empty():
		_field_help.hide()
		return
	_field_text.text = UITheme.plain_text(fact)
	_field_help.size = Vector2(288, 0)
	var viewport := get_viewport_rect()
	var x := global_position.x - _field_help.size.x - 10
	if x < 8:
		x = global_position.x + size.x + 10
	_field_help.global_position = Vector2(clampf(x, 8, maxf(8, viewport.end.x - _field_help.size.x - 8)), clampf(_pointer_position.y - 24, 8, maxf(8, viewport.end.y - _field_help.size.y - 8)))
	_field_help.show()

func _styled(content: String, accent: Color) -> String:
	var lines := content.split("\n", true, 1)
	return "[color=%s][b]%s[/b][/color]%s" % [UITheme.hex(accent), lines[0], "\n" + lines[1] if lines.size() > 1 else ""]

func _bounds() -> Rect2:
	if bounds_provider.is_valid():
		return bounds_provider.call()
	return Rect2(Vector2(12, 60), get_viewport_rect().size - Vector2(24, 84))

func _fit(content: String, payload: RefCounted = null) -> void:
	var bounds := _bounds()
	if docked:
		size = bounds.size
		position = bounds.position
		return
	var width := minf(560 * UITheme.text_scale(), minf(bounds.size.x * 0.46, get_viewport_rect().size.x - 24))
	var lines := 0
	for line in UITheme.plain_text(content).split("\n"):
		lines += maxi(1, ceili(get_theme_default_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.secondary_size()).x / maxf(60, width - 42)))
	var height := lines * (UITheme.secondary_size() + 5) + 70.0
	if payload != null:
		height = _card.custom_minimum_size.y * InspectionContent.CONTENT_SCALE + 60 + (180 if expanded else 0)
		if payload is UnitReadout:
			height = bounds.size.y if expanded else 230 * UITheme.text_scale()
	size = Vector2(width, clampf(height, 90, maxf(90, bounds.size.y)))
	_position_card()

func _position_card() -> void:
	var bounds := _bounds()
	if docked:
		position = bounds.position
		return
	var point := _source.get_global_rect().get_center() if is_instance_valid(_source) else get_global_mouse_position()
	# Fixed opposite-side placement leaves the source reachable and never covers the action dock.
	var x := bounds.end.x - size.x if point.x < bounds.get_center().x else bounds.position.x
	position = Vector2(x, bounds.position.y)

## Deterministic interaction seam; no dwell on first feedback, brief replacement/exit settling.
func advance(content: String, delta: float) -> void:
	if content != _candidate:
		_candidate = content
		_age = 0.0
	_age += delta
	if content == _shown:
		return
	if content.is_empty():
		if _age >= EXIT_GRACE:
			clear()
			if docked:
				_card.hide()
				_unit_card.hide()
				_text.text = ""
				_hint.text = ""
				_hint.hide()
				visible = true
		return
	if docked or _shown.is_empty() or _age >= SWAP_SETTLE:
		_shown = content
		_text.text = content
		_scroll.scroll_vertical = 0
		_fit(content)
		visible = true

func shown_text() -> String:
	return _shown
