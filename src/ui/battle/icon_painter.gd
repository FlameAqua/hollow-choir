class_name IconPainter
extends RefCounted
## Procedural icons drawn with CanvasItem primitives. Every icon has a distinct SHAPE (never colour
## alone) so status and intent icons stay readable for colour-blind players (GDD accessibility).

const STATUS_COLORS := {
	Enums.StatusId.BURN: Color(1.0, 0.45, 0.15),
	Enums.StatusId.WET: Color(0.35, 0.62, 1.0),
	Enums.StatusId.SHOCK: Color(1.0, 0.9, 0.25),
	Enums.StatusId.BLEED: Color(0.9, 0.15, 0.25),
	Enums.StatusId.CHILL: Color(0.7, 0.9, 1.0),
	Enums.StatusId.BLIGHT: Color(0.55, 0.75, 0.3),
}


static func status_color(status: Enums.StatusId) -> Color:
	return STATUS_COLORS.get(status, Color.WHITE)


## Draws a status icon inside [param rect] (roughly square).
static func draw_status(canvas: CanvasItem, rect: Rect2, status: Enums.StatusId) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	var color := status_color(status)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.55))
	match status:
		Enums.StatusId.BURN:
			var flame := PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.6, r * 0.1),
				c + Vector2(r * 0.4, r * 0.75), c + Vector2(-r * 0.4, r * 0.75), c + Vector2(-r * 0.6, r * 0.1)])
			canvas.draw_colored_polygon(flame, color)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.2), c + Vector2(r * 0.25, r * 0.6),
				c + Vector2(-r * 0.25, r * 0.6)]), Color(1, 0.9, 0.5))
		Enums.StatusId.WET:
			var drop := PackedVector2Array([c + Vector2(0, -r * 0.85)])
			for i in 9:
				var angle := PI * float(i) / 8.0
				drop.append(c + Vector2(cos(angle) * r * 0.55, r * 0.25 + sin(angle) * r * 0.55))
			canvas.draw_colored_polygon(drop, color)
		Enums.StatusId.SHOCK:
			var bolt := PackedVector2Array([c + Vector2(r * 0.2, -r * 0.9), c + Vector2(-r * 0.45, r * 0.1),
				c + Vector2(-r * 0.02, r * 0.1), c + Vector2(-r * 0.25, r * 0.9), c + Vector2(r * 0.5, -r * 0.15),
				c + Vector2(r * 0.05, -r * 0.15)])
			canvas.draw_colored_polygon(bolt, color)
		Enums.StatusId.BLEED:
			canvas.draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.3), color, maxf(2.0, r * 0.3))
			canvas.draw_circle(c + Vector2(-r * 0.15, r * 0.45), r * 0.3, color)
		_:
			canvas.draw_circle(c, r * 0.6, color)


## Intent category icon (sword, crossed swords, wave, spiral, cracked shield, cross…).
static func draw_intent(canvas: CanvasItem, rect: Rect2, category: Enums.IntentCategory, color: Color) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	var w := maxf(2.0, r * 0.22)
	match category:
		Enums.IntentCategory.ATTACK:
			_sword(canvas, c, r, color, -PI / 4.0, w)
		Enums.IntentCategory.HEAVY_ATTACK:
			_sword(canvas, c, r, color, -PI / 4.0, w * 1.5)
			canvas.draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.9, r * 0.9), color, w)
		Enums.IntentCategory.AREA_ATTACK:
			for i in 3:
				var y := c.y - r * 0.6 + i * r * 0.6
				canvas.draw_polyline(PackedVector2Array([Vector2(c.x - r, y), Vector2(c.x - r * 0.33, y - r * 0.3),
					Vector2(c.x + r * 0.33, y + r * 0.3), Vector2(c.x + r, y)]), color, w * 0.8)
		Enums.IntentCategory.HEX:
			var points := PackedVector2Array()
			for i in 24:
				var angle := float(i) * 0.55
				points.append(c + Vector2(cos(angle), sin(angle)) * r * (0.15 + 0.035 * i))
			canvas.draw_polyline(points, color, w * 0.8)
		Enums.IntentCategory.ARMOR_BREAK:
			_shield(canvas, c, r, color)
			canvas.draw_line(c + Vector2(-r * 0.2, -r * 0.7), c + Vector2(r * 0.15, r * 0.6), Color.BLACK, w)
		Enums.IntentCategory.HEAL:
			canvas.draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.8), Vector2(r * 0.5, r * 1.6)), color)
			canvas.draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.25), Vector2(r * 1.6, r * 0.5)), color)
		Enums.IntentCategory.BUFF:
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.75, 0),
				c + Vector2(r * 0.3, 0), c + Vector2(r * 0.3, r * 0.8), c + Vector2(-r * 0.3, r * 0.8),
				c + Vector2(-r * 0.3, 0), c + Vector2(-r * 0.75, 0)]), color)
		Enums.IntentCategory.PROTECT:
			_shield(canvas, c, r, color)
		Enums.IntentCategory.BATTLEFIELD:
			for i in 3:
				canvas.draw_arc(c, r * (0.35 + i * 0.25), 0.3 + i, 0.3 + i + PI * 1.3, 12, color, w * 0.7)
		_:
			for i in 3:
				canvas.draw_circle(c + Vector2((i - 1) * r * 0.6, 0), r * 0.15, color)


static func _sword(canvas: CanvasItem, c: Vector2, r: float, color: Color, angle: float, width: float) -> void:
	var direction := Vector2.from_angle(angle)
	var tip := c + direction * r * 0.95
	var hilt := c - direction * r * 0.55
	canvas.draw_line(hilt, tip, color, width)
	var guard := direction.orthogonal() * r * 0.4
	canvas.draw_line(hilt + guard, hilt - guard, color, width)
	canvas.draw_line(hilt, c - direction * r * 0.95, color.darkened(0.3), width)


static func _shield(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.8), c + Vector2(r * 0.75, -r * 0.8),
		c + Vector2(r * 0.7, r * 0.1), c + Vector2(0, r * 0.9), c + Vector2(-r * 0.7, r * 0.1)]), color)


## Hourglass with a countdown number (channels).
static func draw_hourglass(canvas: CanvasItem, rect: Rect2, color: Color, font: Font, turns: int) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(r * 0.6, -r * 0.8),
		c, ]), color)
	canvas.draw_colored_polygon(PackedVector2Array([c, c + Vector2(r * 0.6, r * 0.8), c + Vector2(-r * 0.6, r * 0.8)]), color.darkened(0.25))
	if font != null:
		canvas.draw_string(font, Vector2(rect.end.x + 1, c.y + r * 0.5), str(turns), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(r * 1.5), color)


## Reaction availability: letter in a box, struck through when unavailable (never colour alone).
static func draw_reaction(canvas: CanvasItem, rect: Rect2, reaction: Enums.ReactionType, allowed: bool,
		font: Font, font_size: int) -> void:
	var letter: String = {Enums.ReactionType.BRACE: "B", Enums.ReactionType.EVADE: "E", Enums.ReactionType.PARRY: "P"}.get(reaction, "?")
	var color := reaction_color(reaction) if allowed else Color(0.45, 0.45, 0.45)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.6))
	canvas.draw_rect(rect, color, false, 1.5)
	if font != null:
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		canvas.draw_string(font, rect.get_center() + Vector2(-text_size.x * 0.5, font_size * 0.36), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if not allowed:
		canvas.draw_line(rect.position, rect.end, Color(0.85, 0.3, 0.25), 2.0)


static func reaction_color(reaction: Enums.ReactionType) -> Color:
	match reaction:
		Enums.ReactionType.BRACE:
			return Color(0.55, 0.75, 1.0)
		Enums.ReactionType.EVADE:
			return Color(0.55, 0.95, 0.6)
		Enums.ReactionType.PARRY:
			return Color(1.0, 0.85, 0.35)
	return Color.WHITE
