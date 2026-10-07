class_name FloatingText
extends Label
## A short-lived label that rises and fades (damage numbers, "PERFECT!", "BREAK!").

static func spawn(parent: Node, at: Vector2, text: String, color: Color, size_multiplier: float = 1.0,
		duration: float = 0.9) -> FloatingText:
	var label := FloatingText.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", UITheme.font_size(size_multiplier))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	parent.add_child(label)
	label.reset_size()
	label.position = at - Vector2(label.size.x * 0.5, label.size.y)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 38.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
	tween.chain().tween_callback(label.queue_free)
	return label
