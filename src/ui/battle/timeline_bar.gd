class_name TimelineBar
extends Control
## Initiative timeline: this round's order (acted / acting / upcoming), then the projected next
## round. Broken units show SKIP; channeling enemies show an hourglass. The current round is driven
## by the events the presenter has played (round_number / order / acting_uid / acted), so it never
## runs ahead of the animation; the forecast reads the engine.

const CHIP := 34.0
const GAP := 6.0

var engine: BattleEngine
var round_number := 0
var order: Array[int] = []
var acting_uid := -1
var acted: Dictionary[int, bool] = {}
## Width kept free on the right for the toolbar.
var reserved_right := 0.0
var _chips: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_PASS


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	_chips.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.88))
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), UITheme.BORDER, 1.0)
	if engine == null:
		return
	var font_size := UITheme.font_size(0.85)
	draw_string(_font, Vector2(14, size.y * 0.5 + font_size * 0.35), "ROUND %d" % maxi(1, round_number),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.ACCENT)
	var right_edge := size.x - reserved_right - 10.0
	var x := 110.0
	var y := (size.y - CHIP) * 0.5
	for uid in order:
		var unit := engine.get_unit(uid)
		if unit == null or not unit.is_alive() or x + CHIP > right_edge:
			continue
		var phase := 0 if acted.has(uid) else (1 if uid == acting_uid else 2)
		x = _chip(unit, Vector2(x, y), phase, false) + GAP
	x += 8.0
	draw_line(Vector2(x, 8), Vector2(x, size.y - 8), UITheme.BORDER, 1.0)
	draw_string(_font, Vector2(x + 6, 15), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(0.6), UITheme.TEXT_DIM)
	x += 10.0
	for uid in engine.forecast_next_round():
		var unit := engine.get_unit(uid)
		if unit != null and x + CHIP < right_edge:
			x = _chip(unit, Vector2(x, y + 4), 2, true) + GAP * 0.6


## Draws one chip; [param phase] 0 = acted, 1 = acting, 2 = upcoming. Returns the right edge.
func _chip(unit: BattleUnit, at: Vector2, phase: int, forecast: bool) -> float:
	var chip_size := CHIP * (0.78 if forecast else (1.15 if phase == 1 else 1.0))
	var rect := Rect2(at - Vector2(0, (chip_size - CHIP) * 0.5), Vector2(chip_size, chip_size))
	var base := unit.definition.color.darkened(0.45)
	var alpha := 0.45 if phase == 0 or forecast else 1.0
	draw_rect(rect, Color(base, alpha))
	var border := UITheme.INFO if unit.side == Enums.Side.PLAYER else UITheme.DANGER
	if phase == 1:
		border = UITheme.ACCENT
	draw_rect(rect, Color(border, alpha), false, 2.0 if phase == 1 else 1.0)
	var initials := unit.display_name.replace("The ", "").left(2).to_upper()
	var font_size := int(chip_size * 0.42)
	draw_string(_font, Vector2(rect.position.x, rect.get_center().y + font_size * 0.38), initials,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(UITheme.TEXT, alpha))
	if unit.is_broken() and phase != 0:
		draw_rect(rect, Color(0.2, 0.0, 0.3, 0.55))
		draw_string(_font, Vector2(rect.position.x, rect.end.y - 3), "SKIP", HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, int(chip_size * 0.28), UITheme.STAGGER)
	elif unit.intent != null and unit.intent.is_channel() and not forecast:
		IconPainter.draw_hourglass(self, Rect2(rect.end.x - 10, rect.position.y - 2, 8, 10), UITheme.ACCENT, null, 0)
	_chips.append({"rect": rect, "uid": unit.uid})
	return rect.end.x


func _get_tooltip(at_position: Vector2) -> String:
	for chip in _chips:
		if (chip.rect as Rect2).has_point(at_position):
			var unit := engine.get_unit(chip.uid)
			return "%s — Tempo %d%s" % [unit.display_name, roundi(Stats.tempo(engine.ctx, unit)),
				" (Broken: skips its next turn)" if unit.is_broken() else ""]
	return ""
