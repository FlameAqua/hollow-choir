class_name UnitView
extends Control
## Stage view of one BattleUnit: its idle sprite (or the placeholder silhouette when it has no art),
## shared presentation transforms (lunge, hit, windup, fall), and a compact plate with textured
## HP/break tracks, HP digits and status icons. Everything shown comes from the PresentationLedger,
## so nothing appears before the event that caused it (D-013, M1.1 F3). Read-only on the unit.
##
## Art (M1.1 F5): CombatantDefinition.sprite_frames is optional. The `idle` animation's first frame
## is drawn at the SpriteFrames' `display_height` metadata (art pixels → screen pixels), scaled down
## further only when the stage is short; `faces_left` metadata says which way the art faces (party
## faces right, enemies left; never flipped twice). Missing art falls back to the silhouette. No
## targeting, hit area or timing comes from sprite bounds: the hit area is this control's rect.

signal clicked(uid: int)
signal hovered(uid: int)

const PIXEL := 4.0
const IDLE := &"idle"
const DEAD := &"dead"

## Pixel-art silhouettes: [x, y, w, h, shade] in grid cells. shade: 0 base, 1 dark, 2 light, 3 accent.
const SHAPES := {
	Enums.VisualShape.HUMANOID: {"grid": Vector2(16, 24), "cells": [
		[5, 0, 6, 2, 1], [6, 1, 4, 4, 2], [5, 5, 6, 8, 0], [4, 6, 1, 9, 1], [11, 6, 1, 9, 1],
		[3, 6, 2, 6, 0], [11, 6, 2, 6, 0], [5, 13, 2, 7, 1], [9, 13, 2, 7, 1], [13, 3, 1, 13, 3]]},
	Enums.VisualShape.TALL: {"grid": Vector2(16, 28), "cells": [
		[6, 0, 4, 2, 3], [6, 2, 4, 4, 2], [5, 6, 6, 10, 0], [4, 7, 1, 10, 1], [11, 7, 1, 10, 1],
		[3, 7, 2, 7, 0], [11, 7, 2, 7, 0], [5, 16, 2, 9, 1], [9, 16, 2, 9, 1], [13, 0, 1, 27, 3], [12, 0, 3, 2, 2]]},
	Enums.VisualShape.BEAST: {"grid": Vector2(24, 16), "cells": [
		[1, 5, 5, 2, 1], [5, 6, 13, 6, 0], [17, 3, 6, 5, 0], [21, 5, 2, 2, 3], [6, 12, 2, 4, 1],
		[10, 12, 2, 4, 1], [14, 12, 2, 4, 1], [17, 12, 2, 4, 1], [7, 4, 1, 2, 2], [10, 3, 1, 3, 2],
		[13, 4, 1, 2, 2], [16, 2, 1, 2, 2]]},
	Enums.VisualShape.SHELL: {"grid": Vector2(24, 16), "cells": [
		[4, 4, 16, 8, 0], [6, 2, 12, 3, 2], [0, 8, 4, 3, 1], [20, 8, 4, 3, 1], [5, 12, 2, 3, 1],
		[9, 12, 2, 3, 1], [13, 12, 2, 3, 1], [17, 12, 2, 3, 1], [9, 0, 1, 2, 3], [14, 0, 1, 2, 3],
		[7, 6, 10, 1, 1]]},
	Enums.VisualShape.BLOB: {"grid": Vector2(22, 20), "cells": [
		[5, 10, 2, 9, 1], [15, 9, 3, 10, 1], [10, 5, 2, 14, 1], [2, 6, 8, 4, 0], [12, 4, 9, 5, 0],
		[7, 0, 8, 5, 2], [4, 7, 1, 1, 3], [15, 5, 1, 1, 3], [10, 1, 1, 1, 3], [18, 6, 1, 1, 3]]},
	Enums.VisualShape.COLOSSUS: {"grid": Vector2(24, 28), "cells": [
		[3, 2, 18, 7, 2], [6, 8, 12, 14, 0], [2, 10, 4, 10, 1], [18, 10, 4, 10, 1], [7, 22, 4, 6, 1],
		[13, 22, 4, 6, 1], [6, 4, 2, 2, 3], [15, 3, 2, 2, 3], [11, 5, 2, 1, 3]]},
	Enums.VisualShape.DUMMY: {"grid": Vector2(16, 24), "cells": [
		[7, 8, 2, 16, 1], [1, 9, 14, 2, 1], [5, 1, 6, 7, 2], [4, 10, 8, 6, 0], [6, 3, 1, 1, 1], [9, 3, 1, 1, 1]]},
}

var uid: int = -1
## Hovered enemy move recipients. Presentation only; never changes action eligibility.
var intent_targeted := false
var unit: BattleUnit
var ledger: PresentationLedger
## Selection brackets (action or reaction targets).
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()
## Dim brackets on the acting unit.
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
## 0..1 hit flash (reduced flashing uses a dark tint instead).
var flash: float = 0.0:
	set(value):
		flash = value
		queue_redraw()
var body_offset: Vector2 = Vector2.ZERO:
	set(value):
		body_offset = value
		queue_redraw()
var body_scale: float = 1.0:
	set(value):
		body_scale = value
		queue_redraw()
var displayed_hp: float = 0.0:
	set(value):
		displayed_hp = value
		queue_redraw()
var displayed_stagger: float = 0.0:
	set(value):
		displayed_stagger = value
		queue_redraw()
var reduce_flashing: bool = false
var reduce_motion: bool = false
## Disables real art (tests: art must never change combat results or targeting).
var use_sprites: bool = true

var detail_provider: Callable
var readout_provider: Callable
var _regions: Array[Dictionary] = []
var _font: Font
var _texture: Texture2D
var _dead_texture: Texture2D
var _dead_size: Vector2
var _flip: bool = false
## Natural sprite size before the stage's shrink factor.
var _natural_size: Vector2
var _sprite_size: Vector2
var _plate_width: float = 150.0
var _shrink: float = 1.0
var _idle_time := 0.0
var _breath_scale := 1.0
var support_glow := 0.0


func _process(delta: float) -> void:
	if unit == null:
		return
	_idle_time += delta
	var alive := presentation_animation() == IDLE
	_breath_scale = 1.0 + (sin(_idle_time * 1.7 + uid * .61) * .009 if alive and not reduce_motion else 0.0)
	support_glow = maxf(0, support_glow - delta * 1.4)
	if alive or support_glow > 0:
		queue_redraw()


func pulse_support() -> void:
	support_glow = 1.0


func setup(battle_unit: BattleUnit, p_ledger: PresentationLedger) -> void:
	unit = battle_unit
	set_meta(&"enemy_inspection", unit.is_enemy())
	set_meta(&"inspection_unit", func(point: Vector2) -> UnitReadout:
		for region in _regions:
			if (region.rect as Rect2).has_point(point):
				return null
		return readout_provider.call(uid) if readout_provider.is_valid() else null)
	uid = battle_unit.uid
	ledger = p_ledger
	_load_art()
	displayed_hp = battle_unit.hp
	displayed_stagger = battle_unit.stagger
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(uid))
	tooltip_text = ""
	fit(1.0, _plate_width)


func _ready() -> void:
	_font = get_theme_default_font()


## Natural (unscaled) sprite height in screen pixels.
func natural_height() -> float:
	return _natural_size.y


## Resizes the view for the stage: [param shrink] (≤ 1) scales the sprite, [param plate_width] the
## nameplate. The nameplate never shrinks its text.
func fit(shrink: float, plate_width: float) -> void:
	_shrink = shrink
	_plate_width = plate_width
	_sprite_size = (_natural_size * clampf(shrink, 0.1, 1.0)).round()
	# Draw wide art beyond its lane; pixels must not enlarge/overlap input targets.
	custom_minimum_size = Vector2(_plate_width, _sprite_size.y + plate_height())
	size = custom_minimum_size
	queue_redraw()


## Constant for a given text size, so selecting, hitting or adding a status never moves the sprite.
func plate_height() -> float:
	# The bottom status cell starts 32px below the sprite and includes its outline.
	return float(UITheme.secondary_size()) + 42.0


## Point where effects / floating text should appear (above the sprite).
func anchor_top() -> Vector2:
	return global_position + Vector2(size.x * 0.5, 0.0)


## Global rect of the body (sprite area): selection and reaction rings centre on it.
func body_rect() -> Rect2:
	return Rect2(global_position + Vector2((size.x - _sprite_size.x) * 0.5, 0.0), _sprite_size)


func _load_art() -> void:
	_texture = null
	_dead_texture = null
	_flip = false
	var definition := unit.definition
	var frames := definition.sprite_frames
	if use_sprites and frames != null and frames.has_animation(IDLE) and frames.get_frame_count(IDLE) > 0:
		_texture = frames.get_frame_texture(IDLE, 0)
	if _texture != null:
		var native := Vector2(_texture.get_width(), _texture.get_height())
		var height := float(frames.get_meta(&"display_height", 0.0))
		if height <= 0.0:
			height = native.y
		_natural_size = Vector2(native.x * height / native.y, height).round()
		var faces_left := bool(frames.get_meta(&"faces_left", unit.is_enemy()))
		_flip = faces_left != unit.is_enemy()
		if frames.has_animation(DEAD) and frames.get_frame_count(DEAD) > 0:
			_dead_texture = frames.get_frame_texture(DEAD, 0)
			var width := float(frames.get_meta(&"dead_display_width", _natural_size.x))
			_dead_size = Vector2(width, width * _dead_texture.get_height() / maxf(1, _dead_texture.get_width()))
	else:
		var shape: Dictionary = SHAPES.get(definition.shape, SHAPES[Enums.VisualShape.HUMANOID])
		_natural_size = shape.grid * PIXEL * definition.visual_scale


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(uid)
		accept_event()


func _display() -> PresentationLedger.UnitDisplay:
	return ledger.unit(uid) if ledger != null else null


## Life presentation follows the defeat event, not an HP tween or future resolved engine state.
func presentation_animation() -> StringName:
	var display := _display()
	return IDLE if (display.alive if display != null else unit.is_alive()) else DEAD


func _draw() -> void:
	_regions.clear()
	if unit == null:
		return
	var display := _display()
	var alive := presentation_animation() == IDLE
	var broken := display.broken if display != null else unit.is_broken()
	var sprite_origin := Vector2((size.x - _sprite_size.x) * 0.5, 0.0) + body_offset
	var center := sprite_origin + _sprite_size * 0.5
	if support_glow > 0:
		var pulse_rect := Rect2(sprite_origin + Vector2(4, 4), _sprite_size - Vector2(8, 8))
		draw_rect(pulse_rect, Color(UITheme.INFO, support_glow * .30), false, 3.0)
		CombatIcons.paint(self, "action_empower", Rect2(sprite_origin + Vector2(_sprite_size.x * .5 - 14, 0), Vector2(28, 28)), Color(UITheme.INFO, support_glow))
	# Shadow.
	_draw_ellipse(Vector2(size.x * 0.5, _sprite_size.y - 2.0), Vector2(_sprite_size.x * 0.4, 5.0), Color(0, 0, 0, 0.35))
	if alive and intent_targeted:
		draw_texture_rect(UICraft.texture("target_rim"), Rect2(size.x * .5 - 32, _sprite_size.y - 18, 64, 22), false)
	# Selection uses corner brackets; turn ownership also appears in the portrait timeline.
	if alive and highlighted:
		_draw_brackets(Rect2(sprite_origin - Vector2(6, 6), _sprite_size + Vector2(12, 12)), UITheme.DANGER if unit.is_enemy() else UITheme.ACCENT)
	elif alive and active:
		_draw_brackets(Rect2(sprite_origin - Vector2(4, 4), _sprite_size + Vector2(8, 8)), UITheme.ACCENT.darkened(0.25))
	# Corpses stay at the same foot anchor and never acquire target eligibility from their pixels.
	if not alive:
		_draw_defeated(sprite_origin)
		return
	var pivot := Vector2(center.x, sprite_origin.y + _sprite_size.y)
	var body := Transform2D(0.0, Vector2(body_scale, body_scale * _breath_scale), 0.0, pivot)
	draw_set_transform_matrix(body)
	var local_origin := sprite_origin - pivot
	if _texture != null:
		_draw_sprite(local_origin, body)
	else:
		_draw_silhouette(local_origin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_plate(Vector2(0.0, _sprite_size.y + 4.0), display, broken)
	# Brackets carry selection; turn order carries the active turn. No repeated text over sprites.


func _draw_sprite(origin: Vector2, body: Transform2D) -> void:
	var tint := Color.WHITE
	if flash > 0.0:
		tint = Color(1, 1, 1).lerp(Color(0.35, 0.25, 0.25), flash) if reduce_flashing else Color(1, 1, 1).lerp(Color(2.2, 2.2, 2.2), flash)
	if _flip:
		# Mirror around the body's own axis (the pivot sits at the feet, centred).
		draw_set_transform_matrix(body * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2.ZERO))
		draw_texture_rect(_texture, Rect2(-(origin.x + _sprite_size.x), origin.y, _sprite_size.x, _sprite_size.y), false, tint)
		draw_set_transform_matrix(body)
	else:
		draw_texture_rect(_texture, Rect2(origin, _sprite_size), false, tint)


func _draw_silhouette(origin: Vector2) -> void:
	var base := unit.definition.color
	var flash_color := Color(0.15, 0.1, 0.1) if reduce_flashing else Color(1, 1, 1)
	var shades := [base, base.darkened(0.35), base.lightened(0.28), UITheme.ACCENT.lerp(base, 0.3)]
	var shape: Dictionary = SHAPES.get(unit.definition.shape, SHAPES[Enums.VisualShape.HUMANOID])
	var cell: float = _sprite_size.y / float(shape.grid.y) if unit.definition.shape != Enums.VisualShape.FLYER \
		else _sprite_size.x / 16.0
	var grid_width: float = shape.grid.x
	if unit.definition.shape == Enums.VisualShape.FLYER:
		var c := origin + Vector2(8, 8) * cell
		draw_circle(c, 7.5 * cell, Color(base, 0.18))
		draw_circle(c, 5.0 * cell, Color(base, 0.45).lerp(flash_color, flash))
		draw_circle(c, 3.0 * cell, base.lightened(0.5).lerp(flash_color, flash))
		for i in 3:
			draw_line(c + Vector2(-3 + i * 3, 5) * cell, c + Vector2(-4 + i * 3, 9) * cell, Color(base, 0.5), cell * 0.8)
		return
	var faces_left := unit.is_enemy()
	for spec: Array in shape.cells:
		var x: float = spec[0]
		if faces_left:
			x = grid_width - spec[0] - spec[2]
		var rect := Rect2(origin + Vector2(x, spec[1]) * cell, Vector2(spec[2], spec[3]) * cell)
		var color: Color = shades[spec[4]]
		draw_rect(rect, color.lerp(flash_color, flash))
	if unit.is_enemy() and unit.enemy_def().has_weak_point and unit.definition.shape == Enums.VisualShape.COLOSSUS:
		# The Cantor's bell, its weak point.
		var bell := Rect2(origin + Vector2(9, 12) * cell, Vector2(6, 6) * cell)
		draw_rect(bell, Color(0.75, 0.62, 0.3).lerp(flash_color, flash))
		draw_rect(Rect2(bell.position + Vector2(bell.size.x * 0.4, bell.size.y), Vector2(bell.size.x * 0.2, cell)), Color(0.5, 0.4, 0.2))


func _draw_defeated(origin: Vector2) -> void:
	var feet := Vector2(size.x * 0.5, origin.y + _sprite_size.y)
	if _dead_texture != null:
		var drawn := _dead_size * _shrink
		draw_texture_rect(_dead_texture, Rect2(feet - Vector2(drawn.x * 0.5, drawn.y), drawn), false, Color(0.78, 0.78, 0.78))
	else:
		# A generic flattened body is the fallback for missing dead art and fallen allies.
		var flattened := Transform2D(0.0, Vector2(1.0, 0.3), 0.0, feet)
		draw_set_transform_matrix(flattened)
		if _texture != null:
			_draw_sprite(Vector2(-_sprite_size.x * 0.5, -_sprite_size.y), flattened)
		else:
			_draw_silhouette(Vector2(-_sprite_size.x * 0.5, -_sprite_size.y))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Compact team-colored HP and icon/number resources. Effects move above the plate when enlarged
## HP digits leave too little room. Full identity/maxima are in immediate details.
func _draw_plate(origin: Vector2, display: PresentationLedger.UnitDisplay, broken: bool) -> void:
	var width := _plate_width
	var x := (size.x - width) * 0.5 + 6
	var y := origin.y + 4
	var small := UITheme.secondary_size()
	var side := 22.0
	var inner := width - 12
	var team := UITheme.DANGER if unit.is_enemy() else UITheme.HEART
	var max_hp := display.max_hp if display != null else unit.max_hp
	var max_stagger := display.max_stagger if display != null else unit.max_stagger
	var hp_rect := Rect2(x, y, inner, 12)
	ResourceBarArt.paint(self, hp_rect, displayed_hp / maxf(1, max_hp), unit.is_enemy())
	_regions.append({"rect": hp_rect, "text": "%s · Health\n%d / %d" % [unit.display_name, roundi(displayed_hp), max_hp]})
	# Thin break track is immediately beneath HP; its value is available in inspection.
	var has_break := bool(display.get("has_break")) if display != null and JourneyUI.has_fact(display, &"has_break") else unit.is_enemy()
	if has_break:
		var break_rect := Rect2(x, y + 14, inner, 5)
		ResourceBarArt.paint(self, break_rect, displayed_stagger / maxf(1, max_stagger), true, true)
		var policy := "Break it to interrupt its channel and skip its next activation." if unit.is_enemy() else "Broken: loses one activation, then recovers. Cannot react while Broken."
		_regions.append({"rect": break_rect, "text": "%s · Break remaining\n%d / %d\n%s" % [unit.display_name, roundi(displayed_stagger), roundi(max_stagger), policy]})
	y += 24
	CombatIcons.paint(self, "heart", Rect2(x, y, side, side), team)
	var hp := str(roundi(displayed_hp))
	draw_string(_font, Vector2(x + side + 4, y + small), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT)
	if not unit.is_enemy():
		var focus := str(display.focus if display != null else unit.focus)
		var right := x + inner - _text_width(focus, small) - side - 4
		CombatIcons.paint(self, "focus", Rect2(right, y, side, side))
		draw_string(_font, Vector2(right + side + 4, y + small), focus, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.FOCUS)
	if unit.is_enemy():
		var effect_x := x + side + 9 + _text_width(hp, small)
		var remaining := maxf(0, x + inner - effect_x)
		if remaining < side + _text_width("+9", small):
			_draw_effects(Vector2(x, origin.y - side - 4), inner, display)
		else:
			_draw_effects(Vector2(effect_x, y), remaining, display)
	else:
		_draw_effects(Vector2(x, origin.y - small - 10), inner, display)


## Status icons with their remaining turns first (the dangerous information), then stance and
## cover badges; whatever does not fit becomes "+N" (names and turns are in Details).
func _draw_effects(origin: Vector2, width: float, display: PresentationLedger.UnitDisplay) -> void:
	if display == null:
		return
	var side := float(UITheme.secondary_size() + 4)
	var entries: Array[Dictionary] = []
	if display.broken:
		entries.append({"icon": "state_broken", "count": "", "text": "Broken\nLoses its next activation. Any channel was interrupted." if unit.is_enemy() else "Broken\nCannot react. Loses one activation, then recovers."})
	if display.weak_point:
		entries.append({"icon": "state_exposed", "count": "", "text": "Exposed weak point\nTakes increased damage; Precision attacks gain an extra bonus.\nSpotter's Mark exposes it for 2 of the target's activations. A Break can also expose it until recovery. These effects can overlap."})
	for status in display.statuses:
		entries.append({"icon": CombatIcons.mapping("statuses", status.status), "count": str(status.remaining), "text": "%s · %s\n%s" % [EnumText.status(status.status), UnitDetails.remaining_text(status.definition, status.remaining), status.definition.description if status.definition != null else ""]})
	for buff in display.buffs:
		entries.append({"icon": CombatIcons.mapping("buffs", buff.definition.id if buff.definition != null else ""), "count": str(buff.remaining), "text": "%s · %d\n%s" % [buff.name, buff.remaining, buff.definition.description if buff.definition != null else ""]})
	if display.covered_by >= 0 or display.covering >= 0:
		entries.append({"icon": "action_intercept", "count": "", "text": "Intercept\nCovered by an ally" if display.covered_by >= 0 else "Intercept\nCovering an ally"})
	var cursor := origin.x
	if unit.is_enemy():
		var total_width := 0.0
		for entry in entries:
			total_width += side + _text_width(entry.count, UITheme.secondary_size()) + 12
		cursor += maxf(0, width - total_width)
	for i in entries.size():
		var entry := entries[i]
		var cell_width := side + _text_width(entry.count, UITheme.secondary_size()) + 12
		var reserve := _text_width("+%d" % (entries.size() - i - 1), UITheme.secondary_size()) if i < entries.size() - 1 else 0.0
		if cursor + cell_width > origin.x + width - reserve:
			var overflow := UITheme.fit_text("+%d" % (entries.size() - i), origin.x + width - cursor, _font, UITheme.secondary_size())
			draw_string(_font, Vector2(cursor, origin.y + side - 3), overflow, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.secondary_size(), UITheme.TEXT)
			var notes := PackedStringArray()
			for extra in entries.slice(i):
				notes.append(extra.text)
			_regions.append({"rect": Rect2(cursor, origin.y, origin.x + width - cursor, side), "text": "Effects\n" + "\n\n".join(notes)})
			break
		var cell := Rect2(cursor - 2, origin.y - 2, cell_width - 6, side + 4)
		draw_rect(cell, Color(UITheme.BG, 0.96))
		draw_rect(cell, UITheme.BORDER.darkened(0.25), false, 1)
		_regions.append({"rect": cell, "text": entry.text})
		CombatIcons.paint(self, entry.icon, Rect2(cursor, origin.y, side, side))
		draw_string(_font, Vector2(cursor + side, origin.y + side - 3), entry.count, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.secondary_size(), UITheme.TEXT)
		cursor += cell_width


func _text_width(text: String, font_size: int) -> float:
	if _font == null:
		return text.length() * font_size * 0.6
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _draw_brackets(rect: Rect2, color: Color) -> void:
	var length := 10.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var horizontal := Vector2(length if corner.x == rect.position.x else -length, 0)
		var vertical := Vector2(0, length if corner.y == rect.position.y else -length)
		draw_line(corner, corner + horizontal, color, 2.0)
		draw_line(corner, corner + vertical, color, 2.0)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _get_tooltip(_point: Vector2) -> String:
	for region in _regions:
		if (region.rect as Rect2).has_point(_point):
			return region.text
	return detail_provider.call(uid) if detail_provider.is_valid() else unit.display_name
