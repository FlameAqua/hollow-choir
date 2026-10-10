class_name UITheme
extends RefCounted
## Builds the fixed 1280x720 game theme. Resolution presets scale the complete canvas; there is no
## player font-size preference. Enemy red denotes allegiance/threat, not morality.
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

## Departure Mono uses its native 11 px grid: 22 px body on the fixed design canvas. Resolution
## scaling gives 33 px at 1080p and 44 px at 1440p. Nothing essential is smaller than this body size.
const BASE_FONT_SIZE := 22
const SECONDARY_FONT_SIZE := 22
## Inspection content uses the existing 22 px font at 82% (about 18 px on the canvas).
const TOOLTIP_WIDTH := 380.0
const SLOT_SIZE := 48.0
const SOURCE_SIZE := 36.0
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


static func build() -> Theme:
	var theme := Theme.new()
	var size := BASE_FONT_SIZE
	theme.default_font_size = size
	theme.default_font = PIXEL_FONT
	var pad := 8.0

	var panel := UICraft.panel("cloth", 12, 10)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TooltipPanel", UICraft.panel("tooltip", 12, 10))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", SECONDARY_FONT_SIZE)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	for type in ["Label", "RichTextLabel"]:
		theme.set_color("font_shadow_color", type, Color(0.015, 0.02, 0.018, .95))
		theme.set_constant("shadow_offset_x", type, 2)
		theme.set_constant("shadow_offset_y", type, 2)
	for font in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		theme.set_font_size(font, "RichTextLabel", size)

	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, UICraft.panel("technique", 12, pad))
		theme.set_stylebox("hover", type, UICraft.panel("selected", 12, pad))
		theme.set_stylebox("pressed", type, UICraft.panel("selected", 12, pad, Color(0.8, 0.8, 0.8)))
		theme.set_stylebox("hover_pressed", type, UICraft.panel("selected", 12, pad, Color(0.8, 0.8, 0.8)))
		theme.set_stylebox("focus", type, UICraft.panel("selected", 12, pad))
		theme.set_stylebox("disabled", type, UICraft.panel("technique", 12, pad, Color(0.55, 0.55, 0.55)))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, ACCENT.lightened(0.2))
		theme.set_color("font_pressed_color", type, ACCENT)
		theme.set_color("font_focus_color", type, FOCUS)
		theme.set_color("font_disabled_color", type, TEXT_FAINT)

	theme.set_stylebox("normal", "LineEdit", UICraft.panel("inspection", 12, pad))
	theme.set_stylebox("focus", "LineEdit", UICraft.panel("selected", 12, pad))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_stylebox("background", "ProgressBar", box(BG, BORDER, 1, 2, 0))
	theme.set_stylebox("fill", "ProgressBar", box(BLOOM, Color(0, 0, 0, 0), 0, 2, 0))
	theme.set_stylebox("slider", "HSlider", UICraft.panel("slider_track", 8, 8))
	theme.set_stylebox("grabber_area", "HSlider", UICraft.panel("slider_fill", 8, 8))
	theme.set_stylebox("grabber_area_highlight", "HSlider", UICraft.panel("slider_fill", 8, 8))
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		theme.set_icon(icon, "HSlider", UICraft.texture("slider_knob"))
	theme.set_stylebox("panel", "PopupMenu", UICraft.panel("inspection", 12, 10))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_stylebox("hover", "PopupMenu", UICraft.panel("selected", 12, 6))
	theme.set_font_size("font_size", "PopupMenu", size)
	# A popup is a separate Window; explicit font/filter settings avoid its built-in UI font.
	theme.set_font("font", "PopupMenu", PIXEL_FONT)
	theme.set_font("font", "OptionButton", PIXEL_FONT)
	theme.set_icon("arrow", "OptionButton", UICraft.texture("dropdown"))
	theme.set_constant("arrow_margin", "OptionButton", 12)
	var empty_icon := ImageTexture.create_from_image(Image.create_empty(22, 22, false, Image.FORMAT_RGBA8))
	for icon in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled"]:
		theme.set_icon(icon, "PopupMenu", UICraft.texture("check"))
	for icon in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]:
		theme.set_icon(icon, "PopupMenu", empty_icon)
	# Every checkbox state reserves the same icon and frame dimensions, including keyboard focus.
	for type in ["CheckBox", "CheckButton"]:
		for icon in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled", "on", "on_disabled", "on_mirrored", "on_disabled_mirrored"]:
			theme.set_icon(icon, type, UICraft.texture("check"))
		for icon in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled", "off", "off_disabled", "off_mirrored", "off_disabled_mirrored"]:
			theme.set_icon(icon, type, empty_icon)
		theme.set_constant("h_separation", type, 12)
	for type in ["VScrollBar", "HScrollBar"]:
		var prefix := "h_" if type == "HScrollBar" else ""
		for style in ["scroll", "scroll_focus"]:
			theme.set_stylebox(style, type, UICraft.scrollbar(prefix + "scroll_track"))
		for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
			theme.set_stylebox(style, type, UICraft.scrollbar(prefix + "scroll_thumb", Color(1.18, 1.18, 1.1) if style != "grabber" else Color.WHITE))
		# Horizontal bars are not used in player flows; remove their default engine arrows.
		for icon in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			theme.set_icon(icon, type, empty_icon if type == "HScrollBar" else UICraft.texture("scroll_up" if icon.begins_with("decrement") else "dropdown"))
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_stylebox("panel", "TabContainer", UICraft.panel("cloth", 24, 24))
	theme.set_stylebox("tab_selected", "TabContainer", UICraft.panel("selected", 14, pad))
	theme.set_stylebox("tab_unselected", "TabContainer", UICraft.panel("technique", 14, pad))
	theme.set_stylebox("tab_hovered", "TabContainer", UICraft.panel("selected", 14, pad))
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


## Theme ratio for legacy internal helpers/test fixtures. The runtime theme is always 1.0.
static func text_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.theme != null:
		return float(tree.root.theme.default_font_size) / BASE_FONT_SIZE
	return 1.0


## Fixed-design font size (for labels sized explicitly in code).
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


static func selector() -> OptionButton:
	var option := OptionButton.new()
	var popup := option.get_popup()
	popup.theme = (Engine.get_main_loop() as SceneTree).root.theme
	popup.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return option
