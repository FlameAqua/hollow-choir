class_name UICraft
extends RefCounted
## Painted material assets. Nine-slicing preserves the authored seams and corner fittings.
const TEXTURES := {
	"bag": preload("res://assets/art/global/ui/material_v02/textures/bag.png"),
	"cloth": preload("res://assets/art/global/ui/material_v02/textures/cloth.png"),
	"inspection": preload("res://assets/art/global/ui/material_v02/textures/inspection.png"),
	"map": preload("res://assets/art/global/ui/material_v02/textures/map.png"),
	"attack": preload("res://assets/art/global/ui/material_v02/textures/attack.png"),
	"technique": preload("res://assets/art/global/ui/material_v02/textures/technique.png"),
	"utility": preload("res://assets/art/global/ui/material_v02/textures/utility.png"),
	"selected": preload("res://assets/art/global/ui/material_v02/textures/selected.png"),
	"portrait": preload("res://assets/art/global/ui/material_v02/textures/portrait.png"),
	"intent": preload("res://assets/art/global/ui/material_v02/textures/intent.png"),
	"number": preload("res://assets/art/global/ui/material_v02/textures/number.png"),
	"tooltip": preload("res://assets/art/global/ui/material_v02/textures/tooltip.png"),
	"slider_track": preload("res://assets/art/global/ui/material_v04/textures/slider_track.svg"),
	"slider_fill": preload("res://assets/art/global/ui/material_v04/textures/slider_fill.svg"),
	"slider_knob": preload("res://assets/art/global/ui/material_v02/textures/slider_knob.png"),
	"header": preload("res://assets/art/global/ui/material_v02/textures/header.png"),
	"ring": preload("res://assets/art/global/ui/material_v02/textures/ring.png"),
	"ring_open": preload("res://assets/art/global/ui/material_v02/textures/ring_open.png"),
	"needle": preload("res://assets/art/global/ui/material_v02/textures/needle.png"),
	"impact": preload("res://assets/art/global/ui/material_v02/textures/impact.png"),
	"brace": preload("res://assets/art/global/ui/material_v02/textures/brace.png"),
	"evade": preload("res://assets/art/global/ui/material_v02/textures/evade.png"),
	"parry": preload("res://assets/art/global/ui/material_v02/textures/parry.png"),
	"reaction_selected": preload("res://assets/art/global/ui/material_v02/textures/reaction_selected.png"),
	"timing_track": preload("res://assets/art/global/ui/material_v02/textures/timing_track.png"),
	"timing_fill": preload("res://assets/art/global/ui/material_v02/textures/timing_fill.png"),
	"cursor": preload("res://assets/art/global/ui/material_v02/textures/cursor.png"),
	"broken": preload("res://assets/art/global/ui/material_v02/textures/broken.png"),
	"broken_plaque": preload("res://assets/art/global/ui/material_v02/textures/broken_plaque.png"),
	"target_rim": preload("res://assets/art/global/ui/material_v02/textures/target_rim.png"),
	"scroll_corner": preload("res://assets/art/global/ui/material_v02/textures/scroll_corner.png"),
	"hollow_head": preload("res://assets/art/global/ui/material_v02/textures/hollow_head.png")
}
static var _draw_styles: Dictionary[String, StyleBoxTexture] = {}

const CONTROLS := {
	"check": preload("res://assets/art/global/ui/material_v03/textures/check.png"),
	"dropdown": preload("res://assets/art/global/ui/material_v03/textures/dropdown.png"),
	"scroll_up": preload("res://assets/art/global/ui/material_v03/textures/scroll_up.png"),
	"scroll_track": preload("res://assets/art/global/ui/material_v04/textures/scroll_track.svg"),
	"scroll_thumb": preload("res://assets/art/global/ui/material_v04/textures/scroll_thumb.svg"),
	"h_scroll_track": preload("res://assets/art/global/ui/material_v04/textures/h_scroll_track.svg"),
	"h_scroll_thumb": preload("res://assets/art/global/ui/material_v04/textures/h_scroll_thumb.svg"),
	"map": preload("res://assets/art/global/ui/material_v03/textures/map.png"),
	"menu": preload("res://assets/art/global/ui/material_v03/textures/menu.png"),
	"log": preload("res://assets/art/global/ui/material_v03/textures/log.png"),
	"pause": preload("res://assets/art/global/ui/material_v03/textures/pause.png"),
	"setup": preload("res://assets/art/global/ui/material_v03/textures/setup.png"),
	"restart": preload("res://assets/art/global/ui/material_v03/textures/restart.png"),
	"turn_order": preload("res://assets/art/global/ui/material_v03/textures/turn_order.png"),
	"intent_socket": preload("res://assets/art/global/ui/material_v03/textures/intent_socket.png"),
	"brace": preload("res://assets/art/global/ui/material_v03/textures/brace.png"),
	"evade": preload("res://assets/art/global/ui/material_v03/textures/evade.png"),
	"parry": preload("res://assets/art/global/ui/material_v03/textures/parry.png"),
	"peat": preload("res://assets/art/global/ui/material_v03/textures/peat.png"),
	"wordmark": preload("res://assets/art/global/ui/material_v03/textures/wordmark.png")
}

static func texture(id: String) -> Texture2D:
	return CONTROLS[id] if CONTROLS.has(id) else TEXTURES[id]

## Small controls scale the complete thin atlas frame; large panels retain their authored seams.
static func icon_frame(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURES["tooltip"]
	style.set_texture_margin_all(0)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.modulate_color = tint
	return style

static func style_icon_button(button: Button, icon_size: int = 24) -> void:
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_stylebox_override("normal", icon_frame())
	button.add_theme_stylebox_override("hover", icon_frame(Color(1.2, 1.14, .95)))
	button.add_theme_stylebox_override("focus", icon_frame(Color(1.35, 1.2, .85)))
	button.add_theme_stylebox_override("pressed", icon_frame(Color(.8, .8, .75)))
	button.add_theme_stylebox_override("disabled", icon_frame(Color(.5, .5, .5)))
	button.add_theme_constant_override("icon_max_width", icon_size)

## Tools share an outer stitched dock; hover and focus retain an individual frame.
static func style_tool_button(button: Button) -> void:
	style_icon_button(button, 23)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", empty)

## Small square pockets retain the complete cloth/leather frame at the slot's scale.
static func inventory_slot(occupied: bool = true, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURES["inspection" if occupied else "cloth"]
	style.set_texture_margin_all(0)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_content_margin_all(12)
	style.modulate_color = tint
	return style


static func style_inventory_slot(button: Button) -> void:
	button.add_theme_stylebox_override("normal", inventory_slot())
	button.add_theme_stylebox_override("hover", inventory_slot(true, Color(1.18, 1.12, .95)))
	button.add_theme_stylebox_override("pressed", inventory_slot(true, Color(.85, .82, .75)))
	button.add_theme_stylebox_override("focus", inventory_slot(true, Color(1.35, 1.2, .85)))


## Nine-sliced strips keep rivets intact while their textured centres fill long rows.
static func style_character_row(button: Button) -> void:
	# These two lower-atlas strips are also used by meters; the whole frame is useful for rows.
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var tint := Color(.85, .82, .75) if state == "pressed" else Color.WHITE
		var style := panel("slider_track" if state == "normal" else "slider_fill", 16, 8, tint)
		# Row corners include the complete diagonal fittings, beyond the meter's eight-pixel seam.
		style.texture_margin_left = 16
		style.texture_margin_right = 16
		button.add_theme_stylebox_override(state, style)

static func scrollbar(id: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(id)
	# Continuous strips: native end caps, one stretched centre, no repeating tile seams.
	var horizontal := id.begins_with("h_")
	style.texture_margin_left = 8 if horizontal else 0
	style.texture_margin_right = 8 if horizontal else 0
	style.texture_margin_top = 0 if horizontal else 8
	style.texture_margin_bottom = 0 if horizontal else 8
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 0 if horizontal else 8
	style.content_margin_right = 0 if horizontal else 8
	style.content_margin_top = 8 if horizontal else 0
	style.content_margin_bottom = 8 if horizontal else 0
	style.modulate_color = tint
	return style


## Identical geometry for occupied, empty, selected and locked compact cells.
static func compact_slot(button: Button, source: bool = false) -> void:
	var extent := UITheme.SOURCE_SIZE if source else UITheme.SLOT_SIZE
	button.custom_minimum_size = Vector2.ONE * extent
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", int(extent - 12))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint := Color(.55, .55, .52) if state == "disabled" else Color.WHITE
		if state in ["hover", "focus"]: tint = Color(1.25, 1.16, .9)
		var style := icon_frame(tint)
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state, style)

## Native decorated number badge, with type aligned by its real font metrics.
static func number(canvas: Control, rect: Rect2, value: int, color: Color = UITheme.DANGER, font_size: int = 11) -> void:
	canvas.draw_texture_rect(texture("number"), rect, false)
	var font := canvas.get_theme_default_font()
	var text := str(value)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * .5
	canvas.draw_string(font, Vector2(rect.get_center().x - width * .5, baseline).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

static func panel(id: String = "cloth", horizontal: float = 12, vertical: float = 10, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(id)
	var seam := 32.0 if id in ["bag", "cloth", "inspection"] else 16.0
	if id in ["slider_track", "slider_fill", "timing_track", "timing_fill", "header", "broken_plaque"]:
		seam = 8.0
	style.set_texture_margin_all(seam)
	if id == "header":
		style.texture_margin_left = 20
		style.texture_margin_right = 20
		style.texture_margin_top = 12
		style.texture_margin_bottom = 12
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	if id in ["slider_track", "slider_fill", "timing_track", "timing_fill", "broken_plaque"]:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	style.modulate_color = tint
	return style

static func draw(canvas: CanvasItem, id: String, rect: Rect2) -> void:
	if id == "number":
		canvas.draw_texture_rect(texture(id), rect, false)
		return
	if not _draw_styles.has(id):
		_draw_styles[id] = panel(id, 0, 0)
	canvas.draw_style_box(_draw_styles[id], rect)
