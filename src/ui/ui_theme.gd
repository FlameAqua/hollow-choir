class_name UITheme
extends RefCounted
## Builds the project Theme in code so text scaling (accessibility) is one parameter and every
## screen shares one palette (M1.1 "Visual and layout contract"). Enemy red denotes allegiance/threat, not morality.
## Selection and Focus use bone-gold; symbols and inspection duplicate color meaning.

const BG := Color("101918")
const PANEL := Color("172321")
## Raised panel (focused rows, cards).
const PANEL_LIGHT := Color("20332e")
const BORDER := Color("62766b")
const TEXT := Color("f1ead5")
## Secondary text.
const TEXT_DIM := Color("bac6b5")
## Disabled / tertiary text that carries no essential meaning on its own.
const TEXT_FAINT := Color("7f8c80")
## Selection bracket, Focus and the current input task.
const ACCENT := Color("e2c681")
const FOCUS := Color("e2c681")
## Heart (HP) and positive outcomes.
const BLOOM := Color("94c89b")
const HEART := Color("94c89b")
const STAGGER := Color("c4b5e5")
## Threat; always shown together with a word or "!" (never colour alone).
const DANGER := Color("e56d72")
const THREAT := Color("e56d72")
const WET := Color("9ad7e0")
## Cover, targets and other neutral information.
const INFO := Color("a9c7d8")

## Departure Mono uses its native 11 px grid at 22/33/44 px for 100/150/200%. Nothing essential is
## smaller than SECONDARY_FONT_SIZE.
const BASE_FONT_SIZE := 22
const SECONDARY_FONT_SIZE := 22
## Minimum height of an interactive control at 100% text.
const CONTROL_HEIGHT := 40.0
## Bundled pixel font. Preloaded so exported builds keep it as a tracked dependency.
const PIXEL_FONT := preload("res://assets/art/global/fonts/DepartureMono.otf")

static var _markup: RegEx


## [param bbcode] without its markup: plain accessible text, footer explanations and text measurement.
static func plain_text(bbcode: String) -> String:
	if _markup == null:
		_markup = RegEx.create_from_string("\\[[^\\]]*\\]")
	return _markup.sub(bbcode, "", true)


## Canvas text needs an explicit fit; draw_string's width is an alignment width, not a clip.
static func fit_text(text: String, width: float, font: Font, font_size: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var shortened := text
	while not shortened.is_empty():
		shortened = shortened.left(shortened.length() - 1)
		if font.get_string_size(shortened + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			return shortened + "…"
	return ""


static func build(text_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var size := roundi(BASE_FONT_SIZE * text_scale)
	theme.default_font_size = size
	theme.default_font = PIXEL_FONT
	var pad := 8.0 * text_scale

	var panel := box(PANEL, BORDER, 1, 4, 10)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL_LIGHT, ACCENT, 1, 3, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", roundi(SECONDARY_FONT_SIZE * text_scale))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		theme.set_font_size(font, "RichTextLabel", size)

	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, box(PANEL_LIGHT, BORDER, 1, 3, 10, pad))
		theme.set_stylebox("hover", type, box(PANEL_LIGHT.lightened(0.06), ACCENT.darkened(0.25), 1, 3, 10, pad))
		theme.set_stylebox("pressed", type, box(PANEL.darkened(0.2), ACCENT, 1, 3, 10, pad))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), FOCUS, 2, 3, 10, pad))
		theme.set_stylebox("disabled", type, box(PANEL, BORDER.darkened(0.35), 1, 3, 10, pad))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, ACCENT.lightened(0.2))
		theme.set_color("font_pressed_color", type, ACCENT)
		theme.set_color("font_focus_color", type, FOCUS)
		theme.set_color("font_disabled_color", type, TEXT_FAINT)
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 6, pad))
		theme.set_stylebox("hover", type, box(PANEL_LIGHT, Color(0, 0, 0, 0), 0, 3, 6, pad))

	theme.set_stylebox("normal", "LineEdit", box(BG, BORDER, 1, 3, 8, pad))
	theme.set_stylebox("focus", "LineEdit", box(BG, FOCUS, 2, 3, 8, pad))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_stylebox("background", "ProgressBar", box(BG, BORDER, 1, 2, 0))
	theme.set_stylebox("fill", "ProgressBar", box(BLOOM, Color(0, 0, 0, 0), 0, 2, 0))
	theme.set_stylebox("slider", "HSlider", box(BG, BORDER, 1, 2, 2))
	theme.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.3), Color(0, 0, 0, 0), 0, 2, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 2, 2))
	theme.set_stylebox("panel", "PopupMenu", box(PANEL_LIGHT, BORDER, 1, 3, 6))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_stylebox("hover", "PopupMenu", box(PANEL, ACCENT.darkened(0.4), 1, 2, 4))
	theme.set_font_size("font_size", "PopupMenu", size)
	theme.set_constant("separation", "VBoxContainer", roundi(6 * text_scale))
	theme.set_constant("separation", "HBoxContainer", roundi(6 * text_scale))
	theme.set_stylebox("panel", "TabContainer", panel)
	theme.set_stylebox("tab_selected", "TabContainer", box(PANEL_LIGHT, ACCENT, 1, 3, 10, pad))
	theme.set_stylebox("tab_unselected", "TabContainer", box(PANEL, BORDER, 1, 3, 10, pad))
	theme.set_stylebox("tab_hovered", "TabContainer", box(PANEL_LIGHT, BORDER, 1, 3, 10, pad))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return theme


## [param margin] is the horizontal content margin; [param margin_v] the vertical one (defaults to
## 60% of the horizontal margin, the M1 look).
static func box(bg: Color, border: Color, border_width: int, radius: int, margin: float,
		margin_v: float = -1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = margin
	style.content_margin_right = margin
	var vertical := margin_v if margin_v >= 0.0 else margin * 0.6
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


## Current text-size setting (1.0 = 100%), read from the applied theme.
static func text_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.theme != null:
		return float(tree.root.theme.default_font_size) / BASE_FONT_SIZE
	return 1.0


## Font size scaled by the current setting (for labels sized explicitly in code).
static func font_size(multiplier: float = 1.0) -> int:
	return roundi(BASE_FONT_SIZE * text_scale() * multiplier)


## Body text (22 px at 100%).
static func body_size() -> int:
	return font_size(1.0)


## Secondary text uses the same legible 22 px grid at 100%.
static func secondary_size() -> int:
	return roundi(SECONDARY_FONT_SIZE * text_scale())


## Minimum control height, scaled with text.
static func control_height() -> float:
	return roundf(CONTROL_HEIGHT * maxf(1.0, text_scale()))


## Label with an explicit colour and size (code-built UI helper).
static func label(text: String, color: Color = TEXT, size: int = -1, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_color_override("font_color", color)
	if size > 0:
		node.add_theme_font_size_override("font_size", size)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## Small capitals heading used by dock columns ("YOUR PARTY", "CHOOSE AN ACTION").
static func heading(text: String, color: Color = TEXT_DIM) -> Label:
	var node := label(text.to_upper(), color, secondary_size())
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return node


static func rich_text(size: int = -1) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	if size > 0:
		for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			node.add_theme_font_size_override(font, size)
	return node


static func hex(color: Color) -> String:
	return "#" + color.to_html(false)
