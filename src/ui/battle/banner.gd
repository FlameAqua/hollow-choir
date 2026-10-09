class_name Banner
extends Control
## One compact announcement surface. Condition cards dock to their actual header icon;
## gameplay clocks and battle state are owned elsewhere.
const PANEL = preload("res://assets/art/global/ui/frames/choir_v01/styles/panel.tres")
const CONTENT_SCALE := 0.82
## An enemy's turn shows its absolute encounter number in the same badge as its intent above the
## stage (Adrian, 9 October 2026). Sized so that, after CONTENT_SCALE, it matches that badge.
const BADGE_SIZE := 34.0
const BADGE_FONT_SIZE := 14
var ribbon: ConditionRibbon
var _panel: PanelContainer
var _title: Label
var _body: Label
var _icon: TextureRect
var _badge: Control
var _number := 0
var _tween: Tween
var flying: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", PANEL)
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_icon = CombatIcons.image("intent_battlefield", 28)
	row.add_child(_icon)
	_badge = Control.new()
	_badge.name = "EnemyNumber"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.custom_minimum_size = Vector2.ONE * BADGE_SIZE
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.visible = false
	_badge.draw.connect(func() -> void:
		UICraft.number(_badge, Rect2(Vector2.ZERO, _badge.size), _number, UITheme.DANGER, BADGE_FONT_SIZE))
	row.add_child(_badge)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	_title.add_theme_font_size_override("font_size", UITheme.font_size())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_title)
	_body = Label.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", UITheme.secondary_size())
	box.add_child(_body)
	visible = false

func _show(title: String, body: String, icon_id: String = "", frame: String = "", number: int = 0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	flying = false
	_panel.add_theme_stylebox_override("panel", PANEL if frame.is_empty() else UICraft.panel(frame, 24, 12))
	_title.add_theme_color_override("font_color", UITheme.DANGER if frame == "attack" else UITheme.HEART if frame == "utility" else UITheme.ACCENT)
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 0)
	_number = number
	_badge.visible = number > 0
	_badge.queue_redraw()
	# A numbered name stays on one line, centred together with its badge.
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF if number > 0 else TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if number > 0 else Control.SIZE_EXPAND_FILL
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	_icon.visible = not icon_id.is_empty()
	_icon.texture = CombatIcons.texture(icon_id) if not icon_id.is_empty() else null
	var area := get_parent_area_size()
	var width := minf(560, area.x - 48) / CONTENT_SCALE
	_panel.custom_minimum_size.x = width
	_panel.size = Vector2(width, 0)
	_panel.scale = Vector2.ONE * CONTENT_SCALE
	visible = true
	# Autowrapped labels report a tall minimum while their containers still have the old width.
	# Let the width settle while transparent, then shrink away that temporary height.
	await get_tree().process_frame
	await get_tree().process_frame
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	await get_tree().process_frame
	size = _panel.size * CONTENT_SCALE
	position = Vector2((area.x - size.x) * 0.5, clampf(area.y * 0.24, 16, maxf(16, area.y - size.y - 16)))

## [param speed]: Combat Speed. Callers already scale [param hold]; the fades scale here.
func announce(title: String, body: String = "", hold: float = 0.8, speed: float = 1.0) -> void:
	if title.strip_edges().is_empty() and body.strip_edges().is_empty():
		return
	await _show(title, body)
	await _fade(hold, speed)

## [param number]: the enemy's absolute encounter number (intent badge order); allies have none.
func announce_turn(unit: BattleUnit, number: int, hold: float, speed: float = 1.0) -> void:
	var enemy := unit.is_enemy()
	await _show(unit.display_name + "'s Turn", "", "", "attack" if enemy else "utility", number if enemy else 0)
	await _fade(hold, speed)

func _fade(hold: float, speed: float = 1.0) -> void:
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15 / speed)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2 / speed)
	await _tween.finished
	visible = false

func announce_condition(definition: BattlefieldConditionDefinition, hold: float, reduce_motion: bool, speed: float = 1.0) -> void:
	await _show(definition.display_name, RuleNotes.condition_summary(definition), CombatIcons.mapping("conditions", definition.id, "intent_battlefield"))
	if ribbon != null:
		ribbon.highlight(definition.id, true)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15 / speed)
	_tween.tween_interval(hold)
	await _tween.finished
	var target := ribbon.icon_for(definition.id) if ribbon != null else null
	_tween = create_tween().set_parallel(true)
	if not reduce_motion and target != null:
		flying = true
		var destination := (get_parent() as CanvasItem).get_global_transform_with_canvas().affine_inverse() * target.get_global_rect().get_center()
		var shrink := minf(target.size.x / size.x, target.size.y / size.y)
		_tween.tween_property(self, "position", destination - size * shrink * 0.5, 0.32 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE * shrink, 0.32 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "modulate:a", 0.0, 0.1 / speed).set_delay(0.24 / speed)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, 0.2 / speed)
	await _tween.finished
	flying = false
	visible = false
	scale = Vector2.ONE
	if ribbon != null:
		ribbon.highlight(definition.id, false)
