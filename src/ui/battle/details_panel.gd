class_name DetailsPanel
extends PanelContainer
## The analysis layer while planning (M1.1 "Details is a planning subview"): per-grade numbers,
## formula, windows, the focused unit's full details and the battlefield's full rules. Opens over
## the party half of the stage, so the selected action stays in the dock and the targets stay in
## view. Mouse wheel scrolls it; the most important lines come first.

var _scroll: ScrollContainer
var _text: RichTextLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.97), UITheme.ACCENT.darkened(0.3), 1, 4, 16, 12))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_text = UITheme.rich_text(UITheme.secondary_size())
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_text)


func show_text(bbcode: String) -> void:
	_text.text = bbcode
	_scroll.scroll_vertical = 0


func get_text() -> String:
	return _text.get_parsed_text()
