class_name Banner
extends PanelContainer
## Centered announcement (round start, phase changes, battlefield changes, victory/defeat).

var _title: Label
var _body: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	_title.add_theme_font_size_override("font_size", UITheme.font_size(1.6))
	box.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(560, 0)
	box.add_child(_body)
	modulate.a = 0.0
	visible = false


## Shows the banner for [param hold] seconds (scaled by the caller) and waits until it is gone.
func announce(title: String, body: String = "", hold: float = 0.8) -> void:
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	visible = true
	reset_size()
	var parent_size := get_parent_area_size() if get_parent() is Control else get_viewport_rect().size
	position = Vector2((parent_size.x - size.x) * 0.5, parent_size.y * 0.28)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(hold)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false
