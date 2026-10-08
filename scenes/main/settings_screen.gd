class_name SettingsScreen
extends Control
## Settings (GDD "Accessibility"): the two independent difficulty axes, assist overrides, display
## and accessibility options, volumes and input rebinding. Every change applies and saves at once.

const TEXT_SCALES := [0.75, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0]
const COMBAT_SPEEDS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const TOGGLE_ENTRIES := [["Use assist preset", GameSettings.Toggle.DEFAULT], ["On", GameSettings.Toggle.ON],
	["Off", GameSettings.Toggle.OFF]]

var _tabs: TabContainer
var _difficulty_note: Label
var _assist_note: Label
var _binding_buttons: Dictionary[StringName, Button] = {}
var _capturing: StringName = &""
var _first_control: Control


func _ready() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.add_theme_font_size_override("font_size", UITheme.font_size(1.6))
	column.add_child(title)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_gameplay(_page("Gameplay"))
	_build_display(_page("Display"))
	_build_audio(_page("Audio"))
	_build_controls(_page("Controls"))
	var back := Button.new()
	back.text = "Back  [%s]" % InputBindings.key_label(InputBindings.CANCEL)
	back.custom_minimum_size = Vector2(200, 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_leave)
	column.add_child(back)
	if _first_control != null:
		_first_control.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	var code := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_finish_capture("")
			get_viewport().set_input_as_handled()
			return
		code = InputBindings.code_from_event(event)
	elif event is InputEventJoypadButton and event.pressed:
		code = InputBindings.code_from_event(event)
	if not code.is_empty():
		get_viewport().set_input_as_handled()
		_finish_capture(code)


func _unhandled_input(event: InputEvent) -> void:
	if _capturing == &"" and (event.is_action_pressed(InputBindings.CANCEL) or event.is_action_pressed(InputBindings.MENU)):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	AudioManager.play(AudioManager.Cue.UI_CANCEL)
	SceneRouter.goto(SceneRouter.MAIN_MENU)


# --- Pages ---------------------------------------------------------------------------------------

func _build_gameplay(page: VBoxContainer) -> void:
	var data := Settings.data
	var registry := Database.registry
	var difficulty_entries: Array = []
	for value in Enums.TacticalDifficulty.values():
		difficulty_entries.append([registry.difficulty(value).display_name, value])
	var difficulty := _option(page, "Tactical difficulty", difficulty_entries, int(data.tactical_difficulty), func(value: int) -> void:
		Settings.set_value("tactical_difficulty", value)
		_difficulty_note.text = registry.difficulty(value).description)
	_first_control = difficulty
	_difficulty_note = _note(page, registry.difficulty(data.tactical_difficulty).description)
	_note(page, "How intelligently enemies fight. It never changes enemy health or damage.")
	var assist_entries: Array = []
	for value in Enums.ExecutionAssist.values():
		assist_entries.append([registry.assist(value).display_name, value])
	_option(page, "Execution assist", assist_entries, int(data.execution_assist), func(value: int) -> void:
		Settings.set_value("execution_assist", value)
		_assist_note.text = registry.assist(value).description)
	_assist_note = _note(page, registry.assist(data.execution_assist).description)
	_note(page, "Timing windows and speed of action commands and reactions. Independent of difficulty; change it any time.")
	_option(page, "Automatic Brace", TOGGLE_ENTRIES, int(data.auto_brace), func(value: int) -> void:
		Settings.set_value("auto_brace", value))
	_option(page, "Pause before reactions", TOGGLE_ENTRIES, int(data.reaction_pause), func(value: int) -> void:
		Settings.set_value("reaction_pause", value))


func _build_display(page: VBoxContainer) -> void:
	var data := Settings.data
	_option(page, "Window", [["Windowed", GameSettings.WindowMode.WINDOWED], ["Fullscreen", GameSettings.WindowMode.FULLSCREEN],
		["Borderless", GameSettings.WindowMode.BORDERLESS]], int(data.window_mode), func(value: int) -> void:
		Settings.set_value("window_mode", value))
	var resolution_entries: Array = []
	for index in GameSettings.RESOLUTIONS.size():
		var resolution := GameSettings.RESOLUTIONS[index]
		resolution_entries.append(["%d × %d" % [resolution.x, resolution.y], index])
	_option(page, "Window resolution", resolution_entries, maxi(0, GameSettings.RESOLUTIONS.find(data.window_resolution)), func(index: int) -> void:
		Settings.set_value("window_resolution", GameSettings.RESOLUTIONS[index]))
	_note(page, "The interface scales with the window. Fullscreen uses your desktop resolution; windowed sizes fit your monitor.")
	var scale_entries: Array = []
	for index in TEXT_SCALES.size():
		scale_entries.append(["%d%%" % roundi(TEXT_SCALES[index] * 100.0), index])
	_option(page, "Text size", scale_entries, _closest(TEXT_SCALES, data.text_scale), func(index: int) -> void:
		Settings.set_value("text_scale", TEXT_SCALES[index])
		_rebuild.call_deferred())
	var speed_entries: Array = []
	for index in COMBAT_SPEEDS.size():
		speed_entries.append(["%sx" % str(COMBAT_SPEEDS[index]), index])
	_option(page, "Combat animation speed", speed_entries, _closest(COMBAT_SPEEDS, data.combat_speed), func(index: int) -> void:
		Settings.set_value("combat_speed", COMBAT_SPEEDS[index]))
	_note(page, "Reaction windows are never sped up.")
	_option(page, "Battle details", [["While holding %s" % InputBindings.key_label(InputBindings.INFO), GameSettings.TooltipMode.HOLD],
		["Press %s to toggle" % InputBindings.key_label(InputBindings.INFO), GameSettings.TooltipMode.TOGGLE],
		["Always", GameSettings.TooltipMode.ALWAYS]], int(data.advanced_tooltips), func(value: int) -> void:
		Settings.set_value("advanced_tooltips", value))
	_check(page, "Screen shake", data.screen_shake, "screen_shake")
	_check(page, "Reduce flashing", data.reduce_flashing, "reduce_flashing")
	_check(page, "Reduce motion (no decorative bobbing or pulses)", data.reduce_motion, "reduce_motion")
	_check(page, "Damage numbers", data.show_damage_numbers, "show_damage_numbers")
	_check(page, "Auto-advance text", data.auto_advance_text, "auto_advance_text")
	_check(page, "Subtitles", data.subtitles, "subtitles")


func _build_audio(page: VBoxContainer) -> void:
	var data := Settings.data
	_slider(page, "Master volume", data.master_volume, "master_volume")
	_slider(page, "Music volume", data.music_volume, "music_volume")
	_slider(page, "Effects volume", data.sfx_volume, "sfx_volume")


func _build_controls(page: VBoxContainer) -> void:
	_note(page, "Click a binding, then press a key or gamepad button (Escape cancels). The new input replaces " +
		"the first binding of the same kind; the others stay.")
	for action: StringName in InputBindings.DEFAULTS:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _begin_capture(action))
		_row(page, InputBindings.DISPLAY_NAMES.get(action, String(action)), button)
		_binding_buttons[action] = button
	var reset := Button.new()
	reset.text = "Reset all bindings"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh_bindings())
	page.add_child(reset)
	_refresh_bindings()


# --- Rebinding -----------------------------------------------------------------------------------

func _begin_capture(action: StringName) -> void:
	_capturing = action
	_binding_buttons[action].text = "Press a key or button…"


func _finish_capture(code: String) -> void:
	var action := _capturing
	_capturing = &""
	if not code.is_empty():
		var codes := InputBindings.codes_for(action)
		var kind := code.get_slice(":", 0)
		var replaced := false
		for index in codes.size():
			if codes[index].get_slice(":", 0) == kind:
				codes[index] = code
				replaced = true
				break
		if not replaced:
			codes.insert(0, code)
		Settings.set_binding(action, codes)
		AudioManager.play(AudioManager.Cue.UI_CONFIRM)
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action: StringName in _binding_buttons:
		var labels := PackedStringArray()
		for code in InputBindings.codes_for(action):
			labels.append(InputBindings.code_label(code))
		_binding_buttons[action].text = ", ".join(labels) if not labels.is_empty() else "(unbound)"


# --- Widgets -------------------------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	scroll.add_child(page)
	return page


func _row(page: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(240, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 320.0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	page.add_child(row)


func _option(page: VBoxContainer, label_text: String, entries: Array, selected_value: int, on_change: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	for entry: Array in entries:
		option.add_item(entry[0])
		option.set_item_metadata(option.item_count - 1, entry[1])
		if int(entry[1]) == selected_value:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int) -> void: on_change.call(int(option.get_item_metadata(index))))
	_row(page, label_text, option)
	return option


func _check(page: VBoxContainer, label_text: String, value: bool, field: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.clip_text = true
	check.tooltip_text = label_text
	check.button_pressed = value
	check.toggled.connect(func(pressed: bool) -> void: Settings.set_value(field, pressed))
	page.add_child(check)
	return check


func _rebuild() -> void:
	var tab := _tabs.current_tab
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_binding_buttons.clear()
	_first_control = null
	_ready()
	_tabs.current_tab = tab


func _slider(page: VBoxContainer, label_text: String, value: float, field: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(func(new_value: float) -> void: Settings.set_value(field, new_value))
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play(AudioManager.Cue.UI_CONFIRM))
	_row(page, label_text, slider)
	return slider


func _note(page: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	label.add_theme_font_size_override("font_size", UITheme.font_size(0.82))
	page.add_child(label)
	return label


static func _closest(values: Array, target: float) -> int:
	var best := 0
	for index in values.size():
		if absf(float(values[index]) - target) < absf(float(values[best]) - target):
			best = index
	return best
