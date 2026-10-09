class_name BattleLayout
extends RefCounted
## Icon-first combat layout: header · portrait timeline · full-size stage · dock (actions, preview,
## supplies) · context help. Sprites have no reserved intent-panel region. Presentation geometry
## only: none of these rectangles is a combat target or hit area.
const MARGIN := 24.0
const COLUMN_GAP := 12.0
## Text scale from which the supply column widens and the timed dock grows.
const LARGE_SCALE := 1.3
## Text scale from which the action column widens (200% text).
const EXTRA_LARGE_SCALE := 1.7
var header: Rect2
var timeline: Rect2
var stage: Rect2
var dock: Rect2
var help: Rect2
var actions: Rect2
var preview: Rect2
var supplies: Rect2
## Command meter / reaction cards. Enlarged timing may cover decorative scenery above the dock.
var timed: Rect2

static func compute(viewport_size: Vector2, scale: float) -> BattleLayout:
	var result := BattleLayout.new()
	var width := viewport_size.x - MARGIN * 2.0
	var header_h := maxf(40, UITheme.BASE_FONT_SIZE * scale + 16)
	var timeline_h := clampf(40 * scale + 12, 52, 64)
	var help_h := 16.0
	var dock_h := dock_height(scale)
	result.header = Rect2(MARGIN, 12, width, header_h)
	result.timeline = Rect2(MARGIN, result.header.end.y + 8, width, timeline_h)
	result.help = Rect2(MARGIN, viewport_size.y - help_h - 6, width, help_h)
	result.dock = Rect2(MARGIN, result.help.position.y - dock_h - 4, width, dock_h)
	result.stage = Rect2(MARGIN, result.timeline.end.y + 12, width, result.dock.position.y - result.timeline.end.y - 24)
	var actions_w := width * 0.51
	result.actions = Rect2(result.dock.position, Vector2(actions_w, dock_h))
	result.preview = Rect2(result.actions.end.x + COLUMN_GAP, result.dock.position.y, width - actions_w - COLUMN_GAP, dock_h)
	result.supplies = Rect2(MARGIN, result.timeline.end.y + 12, 196, 64)
	# Enlarged timing content may cover decorative scenery/timeline, never extend off-screen.
	var timed_h := minf(result.dock.end.y - 64, maxf(dock_h, (300 if scale >= EXTRA_LARGE_SCALE else 360 if scale >= LARGE_SCALE else 280) * scale))
	result.timed = Rect2(MARGIN, result.dock.end.y - timed_h, width, timed_h)
	return result

static func dock_height(scale: float) -> float:
	# Four rows of two actions remain visible, including at 200% text size.
	return roundf(204 + maxf(0, scale - 1) * 148)
