class_name ResultPanel
extends PanelContainer
## End-of-battle summary (M1.1 F4): the outcome, a factual cause taken from the log, then Retry and
## Change setup. Seeds and metrics sit under a Details toggle; nothing here recommends a strategy.

signal primary_pressed
signal secondary_pressed

var _title: Label
var _cause: RichTextLabel
var _details_button: Button
var _details: RichTextLabel
var _primary: Button
var _secondary: Button


func _ready() -> void:
	custom_minimum_size = Vector2(640, 0)
	add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.ACCENT.darkened(0.3), 1, 6, 22, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title = UITheme.label("", UITheme.TEXT, UITheme.font_size(2.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_cause = UITheme.rich_text()
	_cause.custom_minimum_size = Vector2(600, 0)
	box.add_child(_cause)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_primary = Button.new()
	_primary.custom_minimum_size = Vector2(220, UITheme.control_height())
	_primary.pressed.connect(func() -> void: primary_pressed.emit())
	buttons.add_child(_primary)
	_secondary = Button.new()
	_secondary.custom_minimum_size = Vector2(220, UITheme.control_height())
	_secondary.pressed.connect(func() -> void: secondary_pressed.emit())
	buttons.add_child(_secondary)
	_details_button = Button.new()
	_details_button.text = "Show details"
	_details_button.toggle_mode = true
	_details_button.flat = true
	_details_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_button.toggled.connect(func(on: bool) -> void:
		_details.visible = on
		_details_button.text = "Hide details" if on else "Show details"
		reset_size()
		_center())
	box.add_child(_details_button)
	_details = UITheme.rich_text(UITheme.secondary_size())
	_details.custom_minimum_size = Vector2(600, 0)
	_details.visible = false
	box.add_child(_details)
	_primary.focus_neighbor_bottom = _primary.get_path_to(_details_button)
	_secondary.focus_neighbor_bottom = _secondary.get_path_to(_details_button)
	_details_button.focus_neighbor_top = _details_button.get_path_to(_primary)
	visible = false


func show_result(title: String, color: Color, cause: String, details: String, primary: String, secondary: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_cause.text = cause
	_details.text = details
	_details.visible = false
	_details_button.button_pressed = false
	_primary.text = primary
	_secondary.text = secondary
	_secondary.visible = not secondary.is_empty()
	visible = true
	reset_size()
	_center()
	_primary.grab_focus.call_deferred()


func focus_primary() -> void:
	_primary.grab_focus()


func cause_text() -> String:
	return _cause.get_parsed_text()


func _center() -> void:
	var parent_size := get_parent_area_size()
	position = ((parent_size - size) * 0.5).round()
