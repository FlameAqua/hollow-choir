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
var dialogue_following := true
var _latest: Button
var _content_scroll: ScrollContainer
## Space in wide menus for the save receipt; it never covers the neighbouring actions.
var notice_dock: Control


static func make(p_kind: StringName, title: String, paragraphs: PackedStringArray, actions: Array[Dictionary],
		extra: Control = null, width: float = 880.0, summary: Control = null) -> WorldModal:
	var modal := WorldModal.new()
	modal.kind = p_kind
	modal.name = "Modal_" + String(p_kind)
	modal._build(title, paragraphs, actions, extra, width, summary)
	return modal


func _build(title: String, paragraphs: PackedStringArray, actions: Array[Dictionary], extra: Control, width: float, summary: Control) -> void:
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
		&"map":
			width = 1120.0
			height = 624.0
		&"bench", &"character", &"inventory", &"crafting":
			width = 1120.0
			height = 664.0
		&"saves":
			height = 664.0
		&"journey_slot":
			height = 688.0
		&"journey_replace", &"new_journey":
			height = 540.0
		&"encounter":
			height = 624.0
		&"menu":
			width = 480.0
			height = 624.0
		&"reward", &"catch_up", &"victory":
			width = 800.0
			height = 400.0
	var panel := PanelContainer.new()
	panel.name = "Frame"
	panel.add_theme_stylebox_override("panel", UICraft.panel("cloth", 12, 10))
	add_child(panel)
	panel.position = Vector2((1280.0 - width) * 0.5, 424.0 if kind == &"dialogue" else (720.0 - height) * 0.5)
	panel.size = Vector2(width, height)
	if kind == &"crafting" and extra is WorldCraftingView:
		var backdrop := TextureRect.new()
		backdrop.texture = load(JourneyUI.ROOT + String(extra.service) + "_backdrop_v01.png")
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(backdrop)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8 if kind == &"dialogue" else 12 if kind == &"journey_slot" else 16)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.name = "TitleRow"
	column.add_child(heading)
	var title_label := UITheme.label(title, UITheme.ACCENT, 22 if kind == &"dialogue" else 33, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title_label)
	# Keep the existing Help control and its view-owned card/callback in the frame's title row.
	if extra != null:
		var help := extra.find_child("Help", true, false) as Button
		if help != null:
			var old_header := help.get_parent()
			old_header.remove_child(help)
			heading.add_child(help)
			if old_header.get_child_count() == 0: old_header.queue_free()
	column.add_child(HSeparator.new())
	if summary != null:
		column.add_child(summary)
	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 28)
	column.add_child(content_row)
	var scroll := ScrollContainer.new()
	_content_scroll = scroll
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
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.follow_focus = false
		scroll.get_v_scroll_bar().gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pause_dialogue_follow())
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
		if kind in [&"bench", &"inventory", &"character", &"crafting"]:
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
	if kind in [&"bench", &"character", &"inventory", &"crafting"]:
		notice_dock = Control.new()
		notice_dock.name = "NoticeDock"
		notice_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notice_dock.custom_minimum_size = Vector2(330, 48)
		notice_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_box.add_child(notice_dock)
	if kind == &"dialogue":
		var hint := UITheme.label("Hold Space to read faster", UITheme.TEXT_DIM, 11)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_box.add_child(hint)
		_latest = Button.new()
		_latest.name = "LatestText"
		_latest.text = "Latest"
		_latest.custom_minimum_size = Vector2(120, 48)
		_latest.disabled = true
		_latest.tooltip_text = "Return to the latest revealed text."
		_latest.pressed.connect(resume_dialogue_follow)
		action_box.add_child(_latest)
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
	if kind in [&"reward", &"catch_up", &"victory"]:
		var fit_outcome := func() -> void:
			var content_height := body.get_combined_minimum_size().y
			var chrome_height := panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
			var frame_height := clampf(content_height + chrome_height, 248, 580)
			panel.size = Vector2(width, frame_height)
			panel.position = Vector2((1280 - width) * .5, (720 - frame_height) * .5)
		body.minimum_size_changed.connect(fit_outcome.call_deferred)
		fit_outcome.call_deferred()


func _ready() -> void:
	_link_focus.call_deferred()
	UIFeedback.install(self)
	if kind in [&"bench", &"character", &"inventory", &"crafting"]:
		TooltipPolicy.suppress_native(self)
	else:
		var inspector := HoverInspector.new()
		inspector.name = "ContextTooltip"
		inspector.manages_detail_input = true
		# Outcome action footer is excluded from tooltip placement, keeping Continue reachable.
		if kind in [&"reward", &"catch_up", &"victory"]:
			inspector.bounds_provider = func() -> Rect2:
				var bottom := buttons[0].global_position.y - 12 if not buttons.is_empty() else 640.0
				return Rect2(12, 12, 1256, maxf(90, bottom - 12))
		add_child(inspector)


func _process(delta: float) -> void:
	if _dialogue != null and _dialogue.visible_characters < _dialogue.get_total_character_count():
		_revealed += delta * (190.0 if Input.is_physical_key_pressed(KEY_SPACE) else 38.0)
		_dialogue.visible_characters = int(_revealed)
	if _dialogue != null and _dialogue.visible_characters > 0:
		var line := _dialogue.get_character_line(mini(_dialogue.visible_characters, _dialogue.get_total_character_count()) - 1)
		var line_height := _dialogue.get_theme_font("normal_font").get_height(_dialogue.get_theme_font_size("normal_font_size"))
		var target := maxf(0, _dialogue.get_line_offset(line) + line_height + 12 - _dialogue_scroll.size.y)
		if dialogue_following:
			_dialogue_scroll_value = lerpf(_dialogue_scroll_value, target, 1.0 - exp(-delta * 10.0))
			_dialogue_scroll.scroll_vertical = roundi(_dialogue_scroll_value)
		_dialogue_fade.set_shader_parameter("scroll_y", float(_dialogue_scroll.scroll_vertical))
		_dialogue_fade.set_shader_parameter("view_height", _dialogue_scroll.size.y)


func _pause_dialogue_follow() -> void:
	dialogue_following = false
	_latest.disabled = false


func resume_dialogue_follow() -> void:
	dialogue_following = true
	_dialogue_scroll_value = float(_dialogue_scroll.scroll_vertical)
	_latest.disabled = true
	WorldModal.focus_later(buttons[0] if not buttons.is_empty() else null)


func scroll_dialogue(amount: int) -> void:
	if _dialogue_scroll == null: return
	_pause_dialogue_follow()
	_dialogue_scroll.scroll_vertical += amount


func _input(event: InputEvent) -> void:
	if _dialogue_scroll == null or not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _dialogue_scroll.get_global_rect().has_point(event.position):
			_pause_dialogue_follow()
		return
	for action in [&"ui_up", &"ui_down", &"ui_page_up", &"ui_page_down"]:
		if event.is_action_pressed(action, true):
			var amount := 160 if action in [&"ui_page_up", &"ui_page_down"] else 48
			scroll_dialogue(-amount if action in [&"ui_up", &"ui_page_up"] else amount)
			get_viewport().set_input_as_handled()
			return


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
		if node.is_visible_in_tree() and (node as Button).focus_mode != Control.FOCUS_NONE and not (node as Button).disabled:
			controls.append(node as Control)
	for index in controls.size():
		var control := controls[index]
		var previous := control.get_path_to(controls[posmod(index - 1, controls.size())])
		var next := control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = _directional_focus(control, controls, Vector2.UP, previous)
		control.focus_neighbor_bottom = _directional_focus(control, controls, Vector2.DOWN, next)
		control.focus_neighbor_left = _directional_focus(control, controls, Vector2.LEFT, previous)
		control.focus_neighbor_right = _directional_focus(control, controls, Vector2.RIGHT, next)


func _directional_focus(origin: Control, controls: Array[Control], direction: Vector2, fallback: NodePath) -> NodePath:
	var best := fallback
	var score := INF
	var center := origin.get_global_rect().get_center()
	for candidate in controls:
		if candidate == origin: continue
		var offset := candidate.get_global_rect().get_center() - center
		var forward := offset.dot(direction)
		if forward <= 1: continue
		var sideways := absf(offset.cross(direction))
		var distance := forward + sideways * 4
		if distance < score:
			score = distance
			best = origin.get_path_to(candidate)
	return best


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
	if kind not in [&"bench", &"inventory", &"character", &"crafting"] and _content_scroll != null:
		if event.is_action_pressed(&"ui_page_down", true):
			_content_scroll.scroll_vertical += 160
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_page_up", true):
			_content_scroll.scroll_vertical -= 160
			get_viewport().set_input_as_handled()
			return
	if cancel_id == &"":
		return
	if event.is_action_pressed(InputBindings.CANCEL, false) or \
			(toggle_action != &"" and event.is_action_pressed(toggle_action, false)):
		get_viewport().set_input_as_handled()
		AudioManager.play(AudioManager.Cue.UI_CANCEL)
		chosen.emit(cancel_id)
