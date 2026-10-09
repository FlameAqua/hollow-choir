class_name IntentSlot
extends Control
## Compact icon strip; full public information is available on hover/selection.
signal hovered(enemy_uid: int)
signal clicked(enemy_uid: int)
enum State { WAITING = 0, PLANNED = 1, ACTED = 2, BROKEN = 3, DEFEATED = 4 }
var enemy_uid := -1
var slot_number := 0
var enemy_name := ""
var state: State = State.WAITING
var readout: IntentReadout
var engine: BattleEngine
var use_art := true
var _regions: Array[Dictionary] = []

func _init(uid: int = -1, number: int = 0, title: String = "") -> void:
	enemy_uid = uid
	slot_number = number
	enemy_name = title

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta(&"enemy_inspection", true)
	set_meta(&"inspection_intent", func(point: Vector2) -> IntentReadout:
		for region in _regions:
			if region.get("move", false) and (region.rect as Rect2).has_point(point):
				return readout
		return null)
	mouse_entered.connect(func() -> void: hovered.emit(enemy_uid))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(enemy_uid)
		accept_event()

func show_readout(value: IntentReadout) -> void:
	readout = value
	state = State.PLANNED
	queue_redraw()

func show_state(value: State) -> void:
	state = value
	if state != State.PLANNED:
		readout = null
	queue_redraw()

func plain_text() -> String:
	var title := "%02d %s" % [slot_number, enemy_name]
	match state:
		State.PLANNED:
			return "%s · ! %s\n%s → %s\n%s\n%s\n%s · %s\n%s" % [title, readout.threat_word, readout.label, readout.target_text, readout.telegraph, readout.status_text(), readout.reactions_text(), readout.channel_text(), readout.interrupt_text()]
		State.ACTED:
			return title + " · Acted\nNo pending action this round. Next intent at round start."
		State.BROKEN:
			return title + " · Broken\nLoses its next activation. Any channel was interrupted."
		State.DEFEATED:
			return title + " · Defeated"
	return title + "\nNo intent declared."

func _get_tooltip(_point: Vector2) -> String:
	for region in _regions:
		if (region.rect as Rect2).has_point(_point):
			return region.text
	if readout != null and engine != null:
		return "%02d %s\n%s" % [slot_number, enemy_name, UnitDetails.intent_text(engine, readout)]
	return plain_text()

func reaction_allowed(reaction: Enums.ReactionType) -> bool:
	var index := ReactionReadout.REACTIONS.find(reaction)
	return readout != null and index >= 0 and readout.allowed[index]

func _tile(icon: String, rect: Rect2, text: String, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(UICraft.texture("intent_socket"), rect, false)
	CombatIcons.paint(self, icon, rect.grow(-4), tint)
	_regions.append({"rect": rect, "text": text})

func _draw() -> void:
	_regions.clear()
	var font := get_theme_default_font()
	var side := 30.0
	var step := side + 6
	var x := 32.0
	UICraft.number(self, Rect2(0, 2, 26, 26), slot_number)
	_regions.append({"rect": Rect2(0, 0, 26, side), "text": enemy_name + "\nEnemy " + str(slot_number)})
	if readout == null:
		if state != State.BROKEN:
			_tile("intent_wait", Rect2(x, 0, side, side), plain_text(), Color(1, 1, 1, 0.5) if state in [State.ACTED, State.DEFEATED] else Color.WHITE)
		return
	var move_text := UnitDetails.intent_text(engine, readout) if engine != null else plain_text()
	_tile(CombatIcons.intent(readout), Rect2(x, 0, side, side), enemy_name + "\n" + move_text)
	_regions[-1]["move"] = true
	x += step
	# Recipients are named in inspection and marked on stage while hovering the move.
	# Public status payloads share the first row; overflow remains explicit and inspectable.
	for i in readout.statuses.size():
		var note := readout.statuses[i]
		if x + (readout.statuses.size() - i) * step - 6 > size.x:
			var overflow := Rect2(x, 0, side, side)
			draw_rect(overflow, UITheme.BG)
			draw_string(font, overflow.position + Vector2(2, 23), "+%d" % (readout.statuses.size() - i), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.ACCENT)
			var notes := PackedStringArray()
			for n in readout.statuses:
				notes.append(n.text())
			_regions.push_front({"rect": overflow, "text": "Status payloads\n" + "\n".join(notes)})
			break
		_tile(CombatIcons.mapping("statuses", note.status), Rect2(x, 0, side, side), note.text())
		if note.qualifier != RuleNotes.Qualifier.ALWAYS:
			draw_string(font, Vector2(x + 20, 24), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.TEXT)
		x += step
	# Reaction legality belongs in move inspection and the active reaction UI, not a repeated row.
	if readout.is_channel:
		var y := 38.0
		var channel_x := 26.0
		_tile("channel", Rect2(channel_x, y, 24, side), "Channel\n%s\n%s" % [readout.channel_text(), readout.interrupt_text()])
		if not readout.interruptible:
			draw_line(Vector2(channel_x, y + side), Vector2(channel_x + 24, y), UITheme.DANGER, 2)
