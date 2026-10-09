class_name BattleLogPanel
extends PanelContainer
## Scrolling battle log (toggled with the log key). Lines are kept while hidden, so opening it
## always shows the full story of the fight.

const MAX_LINES := 400

var _text: RichTextLabel
var _scroll: ScrollContainer
var _reading_history := false
var _lines := PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 94
	add_theme_stylebox_override("panel", UICraft.panel("inspection", 14, 10))
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Battle log  [%s]" % InputBindings.key_label(InputBindings.LOG)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.fit_content = true
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_ALL
	for font in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_text.add_theme_font_size_override(font, UITheme.body_size())
	_scroll.add_child(_text)
	_scroll.get_v_scroll_bar().gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_reading_history = true
			if not event.pressed:
				_follow_if_at_end.call_deferred())


func _process(_delta: float) -> void:
	if not _reading_history:
		_scroll.scroll_vertical = roundi(_scroll.get_v_scroll_bar().max_value)


func _follow_if_at_end() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_reading_history = bar.value < bar.max_value - bar.page - 2


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var hovered := get_viewport().gui_get_hovered_control()
		var inside := hovered != null and (hovered == self or is_ancestor_of(hovered))
		inside = inside or Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * event.position)
		if inside:
			_reading_history = true
			_scroll.get_v_scroll_bar().value += (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1) * 66
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_follow_if_at_end.call_deferred()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END]:
		_reading_history = true
		match event.physical_keycode:
			KEY_HOME: _scroll.scroll_vertical = 0
			KEY_END: _scroll.scroll_vertical = roundi(_scroll.get_v_scroll_bar().max_value)
			_: _scroll.scroll_vertical += (-1 if event.physical_keycode == KEY_PAGEUP else 1) * maxi(66, roundi(_scroll.size.y * .8))
		if event.physical_keycode in [KEY_PAGEDOWN, KEY_END]:
			_follow_if_at_end.call_deferred()
		get_viewport().set_input_as_handled()


func append(line: String) -> void:
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
		_text.text = "\n".join(_lines)
		return
	if _text.get_parsed_text().is_empty():
		_text.append_text(line)
	else:
		_text.append_text("\n" + line)


func clear_lines() -> void:
	_lines.clear()
	_text.text = ""
	_reading_history = false


func toggle() -> void:
	visible = not visible
