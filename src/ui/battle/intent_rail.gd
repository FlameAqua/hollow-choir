class_name IntentRail
extends Control
## Stable enemy icon strips. No panel or reserved battlefield rectangle.
signal slot_hovered(enemy_uid: int)
signal slot_clicked(enemy_uid: int)
var slots: Dictionary[int, IntentSlot] = {}
var battlefield: Battlefield

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(enemies: Array[BattleUnit]) -> void:
	for child in get_children():
		child.queue_free()
	slots.clear()
	for i in enemies.size():
		var enemy := enemies[i]
		var entry := IntentSlot.new(enemy.uid, i + 1, enemy.display_name)
		entry.name = "Slot%d" % (i + 1)
		add_child(entry)
		entry.hovered.connect(func(uid: int) -> void: slot_hovered.emit(uid))
		entry.clicked.connect(func(uid: int) -> void: slot_clicked.emit(uid))
		entry.mouse_exited.connect(func() -> void: slot_hovered.emit(-1))
		slots[enemy.uid] = entry

## Covers the stage; each strip then follows its enemy's view.
func arrange(area: Rect2) -> void:
	position = area.position
	size = area.size
	place_slots()

func place_slots() -> void:
	if battlefield == null:
		return
	var width := minf(224, battlefield.size.x * 0.5 / maxi(1, slots.size()) - 6)
	for uid: int in slots:
		var entry := slots[uid]
		var view := battlefield.view(uid)
		if view == null:
			continue
		entry.engine = battlefield.engine
		entry.use_art = battlefield.use_art
		var content_width := 62.0 + (entry.readout.statuses.size() * 36 if entry.readout != null else 0)
		entry.size = Vector2(minf(width, maxf(94 if entry.readout != null and entry.readout.is_channel else 62, content_width)), 68 if entry.readout != null and entry.readout.is_channel else 30)
		entry.position = Vector2(view.position.x + view.size.x * 0.5 - width * 0.5, maxf(4, view.position.y - entry.size.y - 12))

func slot(uid: int) -> IntentSlot:
	return slots.get(uid)

func show_intent(uid: int, readout: IntentReadout) -> void:
	if slots.has(uid):
		slots[uid].show_readout(readout)

func show_state(uid: int, state: IntentSlot.State) -> void:
	if slots.has(uid):
		slots[uid].show_state(state)
