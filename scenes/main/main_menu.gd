class_name MainMenu
extends Control
## Scenic title menu. Continue journey enters the V0.4 world on the single slot (an old slot keeps
## its research/mastery/loadout and starts at the square); the Combat Sandbox stays alongside.

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
	_menu_panel.add_theme_stylebox_override("panel", UICraft.panel("cloth", 12, 10))
	add_child(_menu_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_menu_panel.add_child(margin)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 8)
	margin.add_child(_column)
	var title := TextureRect.new()
	title.name = "Wordmark"
	title.texture = UICraft.texture("wordmark")
	title.custom_minimum_size.y = 120
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(title)
	_column.add_child(UITheme.label("Where the old song takes root.", UITheme.TEXT_DIM, -1, true))
	_first_button = _button("Continue journey", func() -> void: SceneRouter.goto(SceneRouter.WORLD))
	_button("Combat Sandbox", func() -> void: SceneRouter.goto(SceneRouter.SANDBOX))
	_button("Field Guide", func() -> void: SceneRouter.goto(SceneRouter.FIELD_GUIDE))
	_button("Audio Lab", func() -> void: SceneRouter.goto(SceneRouter.AUDIO_LAB))
	_button("Settings", func() -> void: SceneRouter.goto(SceneRouter.SETTINGS))
	_button("Quit", func() -> void: get_tree().quit())
	_column.add_child(UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), UITheme.TEXT_DIM, UITheme.secondary_size()))
	if not Database.problems.is_empty():
		_first_button.tooltip_text = "Some content could not load. See the diagnostic log."
	resized.connect(_layout_menu)
	_menu_panel.minimum_size_changed.connect(_layout_menu.call_deferred)
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
	button.custom_minimum_size.y = UITheme.control_height()
	button.add_theme_stylebox_override("normal", UICraft.panel("technique", 12, 4))
	button.add_theme_stylebox_override("hover", UICraft.panel("selected", 12, 4))
	button.add_theme_stylebox_override("focus", UICraft.panel("selected", 12, 4))
	button.pressed.connect(func() -> void:
		AudioManager.play(AudioManager.Cue.UI_CONFIRM)
		callback.call())
	_column.add_child(button)
	return button
