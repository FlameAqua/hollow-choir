class_name ConditionArt
extends RefCounted
## Shared terrain decoration: low-contrast, stepped pixels on a two-pixel grid. Drawn behind
## creatures from announced conditions only. Neither particles nor geometry carry game rules.
static func paint(canvas: CanvasItem, area: Vector2, definition: BattlefieldConditionDefinition,
		time: float, reduced_motion: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(definition.id)
	var phase := 0.0 if reduced_motion else floorf(time * 3.0) / 3.0
	match definition.id:
		&"flooded_ground":
			# Broken horizontal reflections and square-edged ripples remain on the ground plane.
			canvas.draw_rect(Rect2(0, area.y * 0.68, area.x, area.y * 0.32), Color("335963", 0.10))
			for i in 22:
				var at := Vector2(rng.randf_range(8, maxf(8, area.x - 40)), rng.randf_range(area.y * 0.69, area.y - 10)).snapped(Vector2(2, 2))
				var width := float(rng.randi_range(5, 14) * 2)
				var offset := roundf(sin(phase * 0.45 + i) * 2) * 2
				canvas.draw_rect(Rect2(at + Vector2(offset, 0), Vector2(width, 2)), Color("9ad7e0", 0.20))
				canvas.draw_rect(Rect2(at + Vector2(-4, 4), Vector2(width + 8, 2)), Color("486f76", 0.23))
				if i % 3 == 0:
					canvas.draw_rect(Rect2(at + Vector2(-6, 2), Vector2(2, 2)), Color("9ad7e0", 0.15))
		&"spore_fog":
			# Thin broken ground haze and sparse flecks; no bright bubbles floating across actors.
			for i in 8:
				var at := Vector2(rng.randf_range(-20, area.x), rng.randf_range(area.y * 0.65, area.y - 6)).snapped(Vector2(2, 2))
				var drift := roundf(sin(phase * 0.25 + i) * 3) * 2
				canvas.draw_rect(Rect2(at + Vector2(drift, 0), Vector2(rng.randi_range(20, 65) * 2, 4)), Color("89966a", 0.08))
			for i in 16:
				var at := Vector2(rng.randf_range(8, area.x - 8), rng.randf_range(area.y * 0.53, area.y - 12))
				at += Vector2(sin(phase * 0.3 + i) * 4, -fmod(phase * 1.5 + i, 8))
				canvas.draw_rect(Rect2(at.snapped(Vector2(2, 2)), Vector2(2, 2)), Color("c4c99a", 0.25))
		_:
			canvas.draw_rect(Rect2(0, area.y * 0.7, area.x, area.y * 0.3), Color(definition.tint, definition.tint.a * 0.25))
