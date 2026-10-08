class_name MainMenu
extends Control
## Scenic title menu; current playable entry remains the existing Combat Sandbox.

const TITLE_BACKDROP := preload("res://assets/art/environments/briarfen/briarfen_marsh_night_1.png")
const FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/panel.tres")
const RAISED := preload("res://assets/art/global/ui/frames/choir_v01/styles/raised.tres")
const SELECTED := preload("res://assets/art/global/ui/frames/choir_v01/styles/selected.tres")
const FOCUS_FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/focus.tres")

var _first_button: Button
var _menu_panel: PanelContainer
var _column: VBoxContainer


func _ready() -> void:
	GameState.resume_session()
	AudioManager.request_music(&"global_title")
	var backdrop := TextureRect.new()
	backdrop.texture = TITLE_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.035, 0.06, 0.055, 0.96))
	gradient.set_color(1, Color(0.035, 0.06, 0.055, 0.1))
	var veil := GradientTexture2D.new()
	veil.gradient = gradient
	veil.fill_from = Vector2.ZERO
	veil.fill_to = Vector2(0.85, 0)
	var shade := TextureRect.new()
	shade.texture = veil
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_panel = PanelContainer.new()
	_menu_panel.add_theme_stylebox_override("panel", FRAME)
	add_child(_menu_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_menu_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 16)
	scroll.add_child(_column)
	var title := UITheme.label("HOLLOW\nCHOIR", UITheme.ACCENT, UITheme.font_size(2.0))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", UITheme.BG)
	_column.add_child(title)
	_column.add_child(UITheme.label("Where the old song takes root.", UITheme.TEXT_DIM, -1, true))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_column.add_child(spacer)
	_first_button = _button("Combat Sandbox", func() -> void: SceneRouter.goto(SceneRouter.SANDBOX))
	_button("Field Guide", func() -> void: SceneRouter.goto(SceneRouter.FIELD_GUIDE))
	_button("Audio Lab", func() -> void: SceneRouter.goto(SceneRouter.AUDIO_LAB))
	_button("Settings", func() -> void: SceneRouter.goto(SceneRouter.SETTINGS))
	_button("Quit", func() -> void: get_tree().quit())
	_column.add_child(UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), UITheme.TEXT_DIM, UITheme.secondary_size()))
	if not Database.problems.is_empty():
		_column.add_child(UITheme.label("Some content could not load. See the diagnostic log.", UITheme.DANGER, -1, true))
	resized.connect(_layout_menu)
	_layout_menu()
	_first_button.grab_focus.call_deferred()


func _layout_menu() -> void:
	if _menu_panel == null:
		return
	var inset := minf(40, size.x * 0.04)
	var width := minf(size.x - inset * 2, maxf(440, size.x * 0.43))
	_menu_panel.position = Vector2(inset, inset)
	_menu_panel.size = Vector2(width, maxf(120, size.y - inset * 2))


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = maxf(52, UITheme.control_height())
	button.add_theme_stylebox_override("normal", RAISED)
	button.add_theme_stylebox_override("hover", SELECTED)
	button.add_theme_stylebox_override("focus", FOCUS_FRAME)
	button.pressed.connect(func() -> void:
		AudioManager.play(AudioManager.Cue.UI_CONFIRM)
		callback.call())
	_column.add_child(button)
	button.focus_entered.connect(func() -> void:
		var scroll := _column.get_parent() as ScrollContainer
		scroll.ensure_control_visible.call_deferred(button))
	return button
