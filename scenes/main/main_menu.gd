class_name MainMenu
extends Control
## Title screen. Milestone 1 exposes the Combat Sandbox and Settings; the expedition (world slice)
## arrives with the next milestone and is shown disabled so the roadmap is visible.

var _first_button: Button


func _ready() -> void:
	GameState.resume_session()
	var backdrop := Battlefield.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "HOLLOW CHOIR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", UITheme.font_size(3.4))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Milestone 1 · Combat Foundation"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	column.add_child(spacer)
	var expedition := _button(column, "Begin Expedition", Callable())
	expedition.disabled = true
	expedition.tooltip_text = "The Briarfen world slice arrives in the next milestone."
	_first_button = _button(column, "Combat Sandbox", func() -> void: SceneRouter.goto(SceneRouter.SANDBOX))
	_button(column, "Settings", func() -> void: SceneRouter.goto(SceneRouter.SETTINGS))
	_button(column, "Quit", func() -> void: get_tree().quit())

	var footer := Label.new()
	footer.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version", "0"),
		"%d content problems — see the log" % Database.problems.size() if not Database.problems.is_empty() else "content OK"]
	footer.add_theme_color_override("font_color", UITheme.DANGER if not Database.problems.is_empty() else UITheme.TEXT_DIM)
	footer.add_theme_font_size_override("font_size", UITheme.font_size(0.75))
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 12.0
	footer.offset_top = -28.0
	footer.offset_bottom = -8.0
	_first_button.grab_focus.call_deferred()


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 40)
	if callback.is_valid():
		button.pressed.connect(func() -> void:
			AudioManager.play(AudioManager.Cue.UI_CONFIRM)
			callback.call())
	parent.add_child(button)
	return button
