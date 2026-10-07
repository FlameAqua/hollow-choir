class_name ResultPanel
extends PanelContainer
## End-of-battle summary with up to two actions (e.g. Restart / Change setup, or Retry / Continue).

signal primary_pressed
signal secondary_pressed

var _title: Label
var _body: RichTextLabel
var _primary: Button
var _secondary: Button


func _ready() -> void:
	custom_minimum_size = Vector2(620, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", UITheme.font_size(2.0))
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(600, 0)
	box.add_child(_body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_primary = Button.new()
	_primary.custom_minimum_size = Vector2(180, 36)
	_primary.pressed.connect(func() -> void: primary_pressed.emit())
	buttons.add_child(_primary)
	_secondary = Button.new()
	_secondary.custom_minimum_size = Vector2(180, 36)
	_secondary.pressed.connect(func() -> void: secondary_pressed.emit())
	buttons.add_child(_secondary)
	visible = false


func show_result(title: String, color: Color, body: String, primary: String, secondary: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	_primary.text = primary
	_secondary.text = secondary
	_secondary.visible = not secondary.is_empty()
	visible = true
	reset_size()
	var parent_size := get_parent_area_size()
	position = (parent_size - size) * 0.5
	_primary.grab_focus.call_deferred()
