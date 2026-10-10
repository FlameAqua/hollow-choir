class_name JourneyNotices
extends Control
## Saved facts only. Wide menus reserve a footer dock for save confirmations; exploration
## and other notices retain the bottom-right stack. No writes or reward grants.
const CAPACITY := 4
var save_dock: Control
var _cards: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _autosave: Control
var _autosave_life := 0.0

func _ready() -> void:
	theme = UITheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.save_completed.connect(_save_completed)
	EventBus.rewards_granted.connect(_reward)
	_autosave = JourneyUI.picture(JourneyUI.icon("save"), Vector2(28, 28))
	_autosave.name = "AutosaveIcon"
	_autosave.size = Vector2(28, 28)
	_autosave.hide()
	add_child(_autosave)
	OperationFeedback.install(self)

## One indication per successful write: a manual save's card, otherwise the quiet icon.
func _save_completed(fact: SaveFact) -> void:
	if fact.origin == SaveFact.Origin.MANUAL:
		_autosave_life = 0
		push_notice("Game Saved", "", JourneyUI.icon("save"), &"save")
	else:
		_autosave_life = 1.35
		_autosave.show()

func _reward(receipt: RewardReadout) -> void:
	for item in receipt.items:
		if int(item.added) > 0:
			push_notice(String(item.name), "+%d" % item.added, load(item.icon_path) as Texture2D if not String(item.icon_path).is_empty() else null)
	if receipt.equipment_slots > 0:
		push_notice("Equipment pockets", "+%d" % receipt.equipment_slots,
			preload("res://assets/art/global/ui/items/satchel_v01.svg"))

func push_notice(title: String, detail: String = "", image: Texture2D = null, key: StringName = &"") -> void:
	if key != &"":
		for entry in _cards + _pending:
			if entry.key == key:
				entry.life = 3.4
				return
	_pending.append({"title": title, "detail": detail, "image": image, "key": key, "life": 3.4})
	_fill()

func _fill() -> void:
	while _cards.size() < CAPACITY and not _pending.is_empty():
		var entry: Dictionary = _pending.pop_front()
		var card := Panel.new()
		card.name = "Notice"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(330, 76)
		card.add_theme_stylebox_override("panel", UICraft.panel("tooltip", 16, 12))
		if entry.image != null:
			var picture := JourneyUI.picture(entry.image, Vector2(36, 36))
			picture.name = "Icon"
			picture.position = Vector2(16, 20)
			picture.size = Vector2(36, 36)
			card.add_child(picture)
		var caption := UITheme.label(entry.title, UITheme.TEXT, 22)
		caption.name = "Caption"
		caption.position = Vector2(64, 12)
		caption.size = Vector2(250, 52 if entry.detail.is_empty() else 26)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.clip_text = true
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
		if not entry.detail.is_empty():
			var detail := UITheme.label(entry.detail, UITheme.INFO, 22)
			detail.position = Vector2(64, 40)
			detail.size = Vector2(250, 26)
			detail.clip_text = true
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(detail)
		add_child(card)
		entry.node = card
		entry.age = 0.0
		_cards.append(entry)
	_layout()

func _process(delta: float) -> void:
	_autosave_life = maxf(0, _autosave_life - delta)
	_autosave.visible = _autosave_life > 0
	for index in range(_cards.size() - 1, -1, -1):
		var entry := _cards[index]
		entry.age += delta
		entry.life -= delta
		if entry.life <= 0:
			entry.node.queue_free()
			_cards.remove_at(index)
	_fill()
	_layout()

func _layout() -> void:
	if _autosave != null:
		_autosave.global_position = save_dock.global_position + Vector2(12, 10) if is_instance_valid(save_dock) and save_dock.is_visible_in_tree() else global_position + Vector2(1224, 88)
	var stack_index := 0
	for index in _cards.size():
		var entry := _cards[index]
		var card: Control = entry.node
		var docked: bool = entry.key == &"save" and is_instance_valid(save_dock) and save_dock.is_visible_in_tree()
		var caption := card.get_node("Caption") as Label
		var picture := card.get_node_or_null("Icon") as Control
		caption.position.y = 0 if docked else 12
		caption.size.y = 48 if docked else (52 if entry.detail.is_empty() else 26)
		if picture != null:
			picture.position.y = 6 if docked else 20
		if docked:
			card.custom_minimum_size = Vector2(330, 48)
			card.size = Vector2(330, 48)
			card.position = get_global_transform().affine_inverse() * save_dock.global_position
			continue
		card.custom_minimum_size = Vector2(330, 76)
		card.size = Vector2(330, 76)
		var slide := 0.0 if Settings.data.reduce_motion else 360.0 * pow(maxf(0, 1.0 - entry.age / .28), 3)
		card.position = Vector2(size.x - 354 + slide, size.y - 100 - stack_index * 84)
		stack_index += 1
