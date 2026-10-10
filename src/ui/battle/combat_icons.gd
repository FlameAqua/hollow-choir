class_name CombatIcons
extends RefCounted
## Shared presentation lookup. Unknown enemy moves use public categories.
const DATA = preload("res://assets/art/global/ui/combat/icon_map.tres")
static var _map: Dictionary = {}
static var _textures: Dictionary = {}

static func mapping(group: String, key: Variant, fallback: String = "unavailable") -> String:
	if _map.is_empty():
		_map = DATA.entries
	return str(_map.get(group, {}).get(str(key), fallback))

static func texture(id: String) -> Texture2D:
	if id == "state_exposed":
		return preload("res://assets/art/global/ui/items/exposed_v01.svg")
	if id in ["log", "pause", "setup", "restart", "turn_order"]:
		return UICraft.texture(id)
	if id in ["stagger", "state_broken"]:
		return UICraft.texture("broken")
	if id in ["reaction_brace", "reaction_evade", "reaction_parry"]:
		return UICraft.texture(id.trim_prefix("reaction_"))
	if not _textures.has(id):
		_textures[id] = DATA.textures.get(id, DATA.textures.get("unavailable"))
	return _textures[id]

static func action(option: ActionOption) -> String:
	if option.item_slot >= 0:
		return "action_item"
	return mapping("player_actions", option.action.id, "action_slash")

static func intent(readout: IntentReadout) -> String:
	if readout.named:
		if _map.is_empty():
			mapping("intent_categories", readout.category)
		var entry: Dictionary = _map.get("enemy_actions", {}).get(str(readout.action.id), {})
		if entry.has("family_icon"):
			return entry.family_icon
	return mapping("intent_categories", readout.category, "intent_wait")

static func paint(canvas: CanvasItem, id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect(texture(id), rect, false, tint)

## Same art contract as UnitView: an `idle` frame, else the placeholder colour (never an error).
static func portrait(canvas: CanvasItem, unit: BattleUnit, rect: Rect2, dim: bool = false, show_art: bool = true) -> void:
	var tint := Color(1, 1, 1, 0.48) if dim else Color.WHITE
	var frames: SpriteFrames = unit.definition.sprite_frames if show_art else null
	var sprite: Texture2D = null
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		sprite = frames.get_frame_texture(&"idle", 0)
	if sprite != null:
		var source := sprite.get_size()
		var fit := minf(rect.size.x / source.x, rect.size.y / source.y)
		var drawn := source * fit
		canvas.draw_texture_rect(sprite, Rect2(rect.get_center() - drawn * 0.5, drawn), false, tint)
	else:
		canvas.draw_rect(rect.grow(-8), Color(unit.definition.color, tint.a))

static func image(id: String, side: float = 28.0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(id)
	node.custom_minimum_size = Vector2(side, side)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node
