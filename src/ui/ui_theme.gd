class_name UITheme
extends RefCounted
## Builds the project Theme in code so text scaling (accessibility) is one parameter and every
## screen shares one palette. Palette: dusk-dark panels, parchment text, Choir gold accents,
## Bloom green for positive/organic, ember red for danger.

const BG := Color("0e0f14")
const PANEL := Color("181a23")
const PANEL_LIGHT := Color("222533")
const BORDER := Color("3a3d50")
const TEXT := Color("e8e3d4")
const TEXT_DIM := Color("9b978b")
const ACCENT := Color("d8b45a")
const BLOOM := Color("7fbf6a")
const DANGER := Color("d65a43")
const INFO := Color("6fa8d8")
const FOCUS := Color("e9d58c")
const STAGGER := Color("c9a3ff")

const BASE_FONT_SIZE := 15


static func build(text_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var size := roundi(BASE_FONT_SIZE * text_scale)
	theme.default_font_size = size

	var panel := box(PANEL, BORDER, 1, 4, 8)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL_LIGHT, ACCENT, 1, 3, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", roundi(size * 0.93))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", size)
	theme.set_font_size("bold_font_size", "RichTextLabel", size)

	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, box(PANEL_LIGHT, BORDER, 1, 3, 6))
		theme.set_stylebox("hover", type, box(PANEL_LIGHT.lightened(0.08), ACCENT.darkened(0.3), 1, 3, 6))
		theme.set_stylebox("pressed", type, box(PANEL.darkened(0.2), ACCENT, 1, 3, 6))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), FOCUS, 2, 3, 6))
		theme.set_stylebox("disabled", type, box(PANEL, BORDER.darkened(0.3), 1, 3, 6))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, ACCENT.lightened(0.3))
		theme.set_color("font_pressed_color", type, ACCENT)
		theme.set_color("font_focus_color", type, FOCUS)
		theme.set_color("font_disabled_color", type, TEXT_DIM.darkened(0.25))
	for type in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 4))
		theme.set_stylebox("hover", type, box(PANEL_LIGHT, Color(0, 0, 0, 0), 0, 3, 4))

	theme.set_stylebox("normal", "LineEdit", box(BG, BORDER, 1, 3, 6))
	theme.set_stylebox("focus", "LineEdit", box(BG, FOCUS, 1, 3, 6))
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
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_stylebox("panel", "TabContainer", panel)
	theme.set_stylebox("tab_selected", "TabContainer", box(PANEL_LIGHT, ACCENT, 1, 3, 8))
	theme.set_stylebox("tab_unselected", "TabContainer", box(PANEL, BORDER, 1, 3, 8))
	theme.set_stylebox("tab_hovered", "TabContainer", box(PANEL_LIGHT, BORDER, 1, 3, 8))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return theme


static func box(bg: Color, border: Color, border_width: int, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style


## Font size scaled by the current setting (for labels sized explicitly in code).
static func font_size(multiplier: float = 1.0) -> int:
	var scale := 1.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.theme != null:
		scale = float(tree.root.theme.default_font_size) / BASE_FONT_SIZE
	return roundi(BASE_FONT_SIZE * scale * multiplier)
