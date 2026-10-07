class_name BattleLogPanel
extends PanelContainer
## Scrolling battle log (toggled with the log key). Lines are kept while hidden, so opening it
## always shows the full story of the fight.

const MAX_LINES := 400

var _text: RichTextLabel
var _lines := PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Battle log  [%s]" % InputBindings.key_label(InputBindings.LOG)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.scroll_following = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", UITheme.font_size(0.78))
	_text.add_theme_font_size_override("bold_font_size", UITheme.font_size(0.78))
	_text.add_theme_font_size_override("italics_font_size", UITheme.font_size(0.78))
	box.add_child(_text)


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


func toggle() -> void:
	visible = not visible
