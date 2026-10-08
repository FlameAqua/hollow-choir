class_name PartyCard
extends Control
## One party member in the dock's party column, in two lines: name and HP over the HP bar, then
## Focus pips and count followed by statuses in words with their remaining turns ("Wet 2"; the rest
## as "+N"). Reads the PresentationLedger, so values change with their events. The acting member
## gets a bone-gold side bar and name (a shape as well as a colour).

var unit: BattleUnit
var ledger: PresentationLedger
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_PASS


func refresh() -> void:
	custom_minimum_size = Vector2(0, preferred_height())
	queue_redraw()


func preferred_height() -> float:
	return float(UITheme.body_size()) + 8.0 + 6.0 + float(UITheme.secondary_size()) + 8.0


func _draw() -> void:
	if unit == null:
		return
	var display := ledger.unit(unit.uid) if ledger != null else null
	var hp := display.hp if display != null else float(unit.hp)
	var focus := display.focus if display != null else unit.focus
	var max_focus := display.max_focus if display != null else unit.max_focus
	var alive := display.alive if display != null else unit.is_alive()
	var body := UITheme.body_size()
	var small := UITheme.secondary_size()
	if active:
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.PANEL_LIGHT)
		draw_rect(Rect2(0, 0, 4, size.y), UITheme.ACCENT)
	var x := 10.0
	var right := size.x - 6.0
	var y := 2.0 + body
	var name_color := UITheme.ACCENT if active else (UITheme.TEXT if alive else UITheme.TEXT_FAINT)
	var hp_text := "Down" if not alive else "%d / %d HP" % [roundi(hp), unit.max_hp]
	var hp_width := _width(hp_text, small)
	draw_string(_font, Vector2(x, y), unit.display_name, HORIZONTAL_ALIGNMENT_LEFT, right - x - hp_width - 6.0, body, name_color)
	draw_string(_font, Vector2(x, y), hp_text, HORIZONTAL_ALIGNMENT_RIGHT, right - x, small, UITheme.TEXT if alive else UITheme.THREAT)
	y += 5.0
	var bar := Rect2(x, y, right - x, 5.0)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var ratio := clampf(hp / maxf(1.0, unit.max_hp), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), UITheme.HEART if ratio > 0.35 else UITheme.THREAT)
	y += 8.0
	var pip := clampf(small * 0.45, 6.0, 10.0)
	for i in max_focus:
		var center := Vector2(x + pip * (i + 0.5), y + small * 0.55)
		if i < focus:
			draw_circle(center, pip * 0.34, UITheme.FOCUS)
		else:
			draw_arc(center, pip * 0.3, 0, TAU, 12, UITheme.BORDER, 1.0)
	var cursor := x + pip * max_focus + 8.0
	var focus_text := "%d Focus" % focus
	draw_string(_font, Vector2(cursor, y + small), focus_text, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.FOCUS)
	cursor += _width(focus_text, small) + 10.0
	_draw_effects(Vector2(cursor, y), right - cursor, display)


## "Wet 2 · Guarding · +1": the first entries in words, the rest counted.
func _draw_effects(origin: Vector2, width: float, display: PresentationLedger.UnitDisplay) -> void:
	if display == null or width <= 0.0:
		return
	var small := UITheme.secondary_size()
	var parts: Array[Dictionary] = []
	for entry in display.statuses:
		var name := entry.definition.display_name if entry.definition != null else EnumText.status(entry.status)
		parts.append({"text": "%s %d" % [name, entry.remaining], "color": IconPainter.status_color(entry.status)})
	for buff in display.buffs:
		parts.append({"text": buff.name, "color": UITheme.THREAT if buff.definition != null and buff.definition.is_debuff else UITheme.INFO})
	if display.covered_by >= 0:
		parts.append({"text": "Covered", "color": UITheme.INFO})
	elif display.covering >= 0:
		parts.append({"text": "Covering", "color": UITheme.INFO})
	var cursor := origin.x
	for index in parts.size():
		var text: String = parts[index].text
		var w := _width(text, small)
		var left := parts.size() - index
		var more := "+%d" % left
		var reserve := 0.0 if left == 1 else _width(more, small) + 8.0
		if cursor + w + reserve > origin.x + width:
			draw_string(_font, Vector2(cursor, origin.y + small), more, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UITheme.TEXT)
			return
		draw_string(_font, Vector2(cursor, origin.y + small), text, HORIZONTAL_ALIGNMENT_LEFT, -1, small, parts[index].color)
		cursor += w + 10.0


func _width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if _font != null else text.length() * font_size * 0.6
