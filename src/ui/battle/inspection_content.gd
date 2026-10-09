class_name InspectionContent
extends Control
## Render the existing native pixel-font sizes at a compact presentation scale. Containers still
## lay out at their native size; this wrapper reports their transformed height to scrolling.
const CONTENT_SCALE := 0.82
const INSET := 6.0
var body: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body = VBoxContainer.new()
	body.scale = Vector2.ONE * CONTENT_SCALE
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	resized.connect(_layout)
	body.minimum_size_changed.connect(_layout.call_deferred)
	_layout()

func _layout() -> void:
	if body == null:
		return
	body.position = Vector2.ONE * INSET
	body.size = Vector2(maxf(1, size.x - INSET * 2) / CONTENT_SCALE, body.get_combined_minimum_size().y)
	custom_minimum_size.y = ceilf(body.get_combined_minimum_size().y * CONTENT_SCALE + INSET * 2)
