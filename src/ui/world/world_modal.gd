class_name WorldModal
extends Control
## Fixed-canvas world frame. Content scrolls independently of named actions; this view owns
## focus and presentation only. WorldHost applies every chosen action through WorldSession.

signal chosen(id: StringName)
const FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/panel.tres")
## Empty means Cancel cannot dismiss the modal (save failure and encounter outcome).
var cancel_id: StringName = &""
var toggle_action: StringName = &""
var kind: StringName = &""
var buttons: Array[Button] = []
var _status: Label
var _dialogue: RichTextLabel
var _revealed := 0.0
var _dialogue_scroll: ScrollContainer
var _dialogue_scroll_value := 0.0
var _dialogue_fade: ShaderMaterial


static func make(p_kind: StringName, title: String, paragraphs: PackedStringArray, actions: Array[Dictionary],
		extra: Control = null, width: float = 880.0) -> WorldModal:
	var modal := WorldModal.new()
	modal.kind = p_kind
	modal.name = "Modal_" + String(p_kind)
	modal._build(title, paragraphs, actions, extra, width)
	return modal


func _build(title: String, paragraphs: PackedStringArray, actions: Array[Dictionary], extra: Control, width: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.64)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var height := 460.0
	match kind:
		&"dialogue":
			width = 940.0
			height = 264.0
		&"bench", &"map":
			width = 1120.0
			height = 624.0
		&"encounter":
			height = 568.0
		&"menu":
			width = 480.0
			height = 564.0
	var panel := PanelContainer.new()
	panel.name = "Frame"
	panel.add_theme_stylebox_override("panel", UICraft.panel("cloth", 12, 10))
	add_child(panel)
	panel.position = Vector2((1280.0 - width) * 0.5, 424.0 if kind == &"dialogue" else (720.0 - height) * 0.5)
	panel.size = Vector2(width, height)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8 if kind == &"dialogue" else 16)
	margin.add_child(column)
	column.add_child(UITheme.label(title, UITheme.ACCENT, 22 if kind == &"dialogue" else 33, true))
	column.add_child(HSeparator.new())
	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 28)
	column.add_child(content_row)
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Content"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	if kind == &"dialogue":
		_dialogue_scroll = scroll
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_dialogue = UITheme.rich_text(20)
		_dialogue.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		_dialogue_fade = ShaderMaterial.new()
		_dialogue_fade.shader = preload("res://src/ui/world/dialogue_fade.gdshader")
		_dialogue.material = _dialogue_fade
		_dialogue.text = "\n\n".join(paragraphs)
		_dialogue.visible_characters = 0
		body.add_child(_dialogue)
		body.add_theme_constant_override("separation", 0)
		var breathing_room := Control.new()
		breathing_room.custom_minimum_size.y = 12
		body.add_child(breathing_room)
	else:
		for paragraph in paragraphs:
			body.add_child(UITheme.label(paragraph, UITheme.TEXT, -1, true))
	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		extra.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if kind == &"bench":
			scroll.hide()
			content_row.add_child(extra)
		else:
			body.add_child(extra)
	_status = UITheme.label("", UITheme.BLOOM, -1, true)
	_status.name = "Status"
	_status.visible = false
	column.add_child(_status)
	var action_box: BoxContainer
	if kind == &"menu":
		action_box = VBoxContainer.new()
		content_row.visible = false
		column.add_child(action_box)
	else:
		action_box = HBoxContainer.new()
		action_box.alignment = BoxContainer.ALIGNMENT_END
		column.add_child(action_box)
	action_box.add_theme_constant_override("separation", 12)
	if kind == &"dialogue":
		var hint := UITheme.label("Hold Space to read faster", UITheme.TEXT_DIM, 11)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_box.add_child(hint)
	for action in actions:
		var control := Button.new()
		control.text = String(action.label)
		control.name = "Action_" + String(action.id)
		control.custom_minimum_size = Vector2(160, 48)
		var id: StringName = action.id
		control.pressed.connect(func() -> void:
			if reveal_dialogue():
				return
			AudioManager.play(AudioManager.Cue.UI_CONFIRM)
			chosen.emit(id))
		action_box.add_child(control)
		buttons.append(control)
	if not buttons.is_empty():
		focus_later(buttons[0])


func _ready() -> void:
	_link_focus.call_deferred()


func _process(delta: float) -> void:
	if _dialogue != null and _dialogue.visible_characters < _dialogue.get_total_character_count():
		_revealed += delta * (190.0 if Input.is_physical_key_pressed(KEY_SPACE) else 38.0)
		_dialogue.visible_characters = int(_revealed)
	if _dialogue != null and _dialogue.visible_characters > 0:
		var line := _dialogue.get_character_line(mini(_dialogue.visible_characters, _dialogue.get_total_character_count()) - 1)
		var line_height := _dialogue.get_theme_font("normal_font").get_height(_dialogue.get_theme_font_size("normal_font_size"))
		var target := maxf(0, _dialogue.get_line_offset(line) + line_height + 12 - _dialogue_scroll.size.y)
		_dialogue_scroll_value = lerpf(_dialogue_scroll_value, target, 1.0 - exp(-delta * 10.0))
		_dialogue_scroll.scroll_vertical = roundi(_dialogue_scroll_value)
		_dialogue_fade.set_shader_parameter("scroll_y", float(_dialogue_scroll.scroll_vertical))
		_dialogue_fade.set_shader_parameter("view_height", _dialogue_scroll.size.y)


## First Confirm reveals the full line; the next press chooses. No per-character sound.
func reveal_dialogue() -> bool:
	if _dialogue != null and _dialogue.visible_characters < _dialogue.get_total_character_count():
		_dialogue.visible_characters = _dialogue.get_total_character_count()
		_revealed = float(_dialogue.visible_characters)
		return true
	return false


## Keep directional and tab navigation inside the modal, including its scrolling content.
func _link_focus() -> void:
	var controls: Array[Control] = []
	for node in find_children("*", "Button", true, false):
		if (node as Button).focus_mode != Control.FOCUS_NONE and not (node as Button).disabled:
			controls.append(node as Control)
	for index in controls.size():
		var control := controls[index]
		var previous := control.get_path_to(controls[posmod(index - 1, controls.size())])
		var next := control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_left = previous
		control.focus_neighbor_right = next


static func focus_later(control: Control) -> void:
	(func() -> void:
		if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
			control.grab_focus()).call_deferred()


func set_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func button(id: StringName) -> Button:
	for entry in buttons:
		if entry.name == "Action_" + String(id):
			return entry
	return null


func _unhandled_input(event: InputEvent) -> void:
	if cancel_id == &"":
		return
	if event.is_action_pressed(InputBindings.CANCEL, false) or \
			(toggle_action != &"" and event.is_action_pressed(toggle_action, false)):
		get_viewport().set_input_as_handled()
		AudioManager.play(AudioManager.Cue.UI_CANCEL)
		chosen.emit(cancel_id)
