class_name BattleLayout
extends RefCounted
## Icon-first combat layout. Sprites have no reserved intent-panel region.
enum Mode { STANDARD = 0, LARGE = 1, STACKED = 2 }
const MARGIN := 24.0
const LARGE_SCALE := 1.3
const STACKED_SCALE := 1.7
const COLUMN_GAP := 12.0
var mode: Mode = Mode.STANDARD
var text_scale := 1.0
var header: Rect2
var timeline: Rect2
var stage: Rect2
var rail: Rect2
var ribbon: Rect2
var dock: Rect2
var help: Rect2
var party: Rect2
var actions: Rect2
var preview: Rect2
## Compatibility field: supplies occupy the former familiar column.
var familiar: Rect2
var timed: Rect2
var overlay: Rect2
var details: Rect2

static func compute(viewport_size: Vector2, scale: float) -> BattleLayout:
	var result := BattleLayout.new()
	result.text_scale = scale
	result.mode = Mode.STACKED if scale >= STACKED_SCALE else Mode.LARGE if scale >= LARGE_SCALE else Mode.STANDARD
	var width := viewport_size.x - 48
	var header_h := maxf(40, UITheme.BASE_FONT_SIZE * scale + 16)
	var timeline_h := clampf(40 * scale + 12, 52, 64)
	var help_h := UITheme.SECONDARY_FONT_SIZE * scale + 8
	var dock_h := dock_height(scale)
	result.header = Rect2(24, 12, width, header_h)
	result.timeline = Rect2(24, result.header.end.y + 8, width, timeline_h)
	result.help = Rect2(24, viewport_size.y - help_h - 8, width, help_h)
	result.dock = Rect2(24, result.help.position.y - dock_h - 8, width, dock_h)
	result.stage = Rect2(24, result.timeline.end.y + 12, width, result.dock.position.y - result.timeline.end.y - 24)
	result.rail = result.stage
	result.ribbon = Rect2(result.header.end.x - 360, 12, 90, header_h)
	var actions_w := width * (0.47 if scale < STACKED_SCALE else 0.52)
	var supplies_w := 190.0 if scale < LARGE_SCALE else 220.0
	result.actions = Rect2(result.dock.position, Vector2(actions_w, dock_h))
	result.preview = Rect2(result.actions.end.x + 12, result.dock.position.y, width - actions_w - supplies_w - 24, dock_h)
	result.familiar = Rect2(result.preview.end.x + 12, result.dock.position.y, supplies_w, dock_h)
	result.party = Rect2()
	# Enlarged timing content may cover decorative scenery/timeline, never extend off-screen.
	var timed_h := minf(result.dock.end.y - 64, maxf(dock_h, (300 if scale >= STACKED_SCALE else 360 if scale >= LARGE_SCALE else 280) * scale))
	result.timed = Rect2(24, result.dock.end.y - timed_h, width, timed_h)
	result.overlay = Rect2(result.stage.position, Vector2(width, result.dock.end.y - result.stage.position.y))
	result.details = Rect2(result.stage.position + Vector2(4, 4), Vector2(width * 0.48, result.stage.size.y - 8))
	return result

static func dock_height(scale: float) -> float:
	return roundf(186 + maxf(0, scale - 1) * 80)

func dock_columns() -> Array[Rect2]:
	return [actions, preview, familiar] as Array[Rect2]
