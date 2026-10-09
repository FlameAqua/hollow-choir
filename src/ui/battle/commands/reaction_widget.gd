class_name ReactionWidget
extends Control
## Real-time defensive reaction (M1.1 F2). One clock drives three views: a ring that lands on each
## target at impact (stage), the dock meter with a fixed impact marker and the true windows, and the
## three reaction cards in fixed Brace / Evade / Parry order. Neither animation nor sound is a second
## timing source.
##
## The first allowed fresh press locks type and timing (D-008). Unavailable reactions are inert and
## labelled. A key held when the window opens (pad X is also the command key) must be released first.
## Pause-before-reaction waits for Confirm, which never counts as a reaction. While the window has no
## focus the clock freezes; it resumes after every reaction key is released. The battle scene
## ignores Pause while this window is open (pausing must never help timing).

signal finished(result: ReactionResult)
## The real-time sequence began (immediately, or after the assist pause): start the wind-up visuals.
signal started

const START_RADIUS := 110.0
const IMPACT_RADIUS := 26.0
const FEEDBACK_HOLD := 0.45
## How long a struck reaction's card says "Unavailable" after its key was pressed (wall clock).
const UNAVAILABLE_NOTE_MS := 600
const KEYS := ReactionReadout.KEYS
const REACTIONS := ReactionReadout.REACTIONS

var spec: ReactionSpec
var readout: ReactionReadout
var target_points: Array[Vector2] = []
## Where the dock part (meter and cards) is drawn, in this widget's coordinates.
var dock_rect: Rect2
var reduce_motion: bool = false
var clock := TimingClock.new()
var latch := FreshPressLatch.new()

var _waiting_for_start := false
var _preparing := false
var _running := false
var _chosen: Enums.ReactionType = Enums.ReactionType.NONE
var _success := false
## Press time minus impact (ms), measured when the choice locked.
var _offset_ms := 0.0
var _done := false
var _focus_lost := false
var _font: Font
var _cards: Array[PanelContainer] = []
var _card_status: Array[Label] = []
## Reaction -> Time.get_ticks_msec() until which its card notes the inert press.
var _unavailable_until: Dictionary[int, int] = {}
var _header: Label
var _instruction: Label
var _footer: Label
var _meter_space: Control


func begin(p_spec: ReactionSpec, p_readout: ReactionReadout, p_targets: Array[Vector2], p_dock_rect: Rect2, preparing: bool = false) -> void:
	spec = p_spec
	readout = p_readout
	target_points = p_targets
	dock_rect = p_dock_rect
	var compact_height := minf(dock_rect.size.y, 170 * UITheme.text_scale())
	dock_rect.position.y = dock_rect.end.y - compact_height
	dock_rect.size.y = compact_height
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cards()
	latch.latch_held(_reaction_actions())
	_preparing = preparing
	_waiting_for_start = not _preparing and spec.pause_before
	if _preparing:
		clock.freeze()
		clock.set_elapsed(0.0)
	elif _waiting_for_start:
		latch.latch_held([InputBindings.CONFIRM])
	else:
		_start()
	_refresh_cards()
	set_process(true)
	set_process_input(true)
	queue_redraw()


## Release the static preview without replacing the ring, meter or legality cards.
func start_timing() -> void:
	if not _preparing:
		return
	_preparing = false
	latch.poll()
	latch.latch_held(_reaction_actions())
	_waiting_for_start = spec.pause_before
	if _waiting_for_start:
		latch.latch_held([InputBindings.CONFIRM])
	else:
		_start()
	_refresh_cards()
	queue_redraw()


func is_preparing() -> bool:
	return _preparing


func impact_ms() -> float:
	return spec.windup_ms


func elapsed_ms() -> float:
	return clock.elapsed_ms() if _running else 0.0


func is_waiting_for_start() -> bool:
	return _waiting_for_start


func is_done() -> bool:
	return _done


func chosen() -> Enums.ReactionType:
	return _chosen


## "Success", "Early", "Late" (measured) or "No reaction" (nothing pressed).
func result_word() -> String:
	if _chosen == Enums.ReactionType.NONE:
		return "No reaction"
	if _success:
		return "Success"
	return "Early" if _offset_ms < 0.0 else "Late"


func _start() -> void:
	_waiting_for_start = false
	_running = true
	clock.start()
	if _focus_lost:
		clock.freeze()
	AudioManager.play(AudioManager.Cue.TELEGRAPH)
	started.emit()
	_refresh_cards()


func _reaction_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for reaction in REACTIONS:
		actions.append(KEYS[reaction])
	return actions


func _input(event: InputEvent) -> void:
	if _preparing:
		if event.is_action(InputBindings.CONFIRM) or event.is_action(InputBindings.BRACE) or event.is_action(InputBindings.EVADE) or event.is_action(InputBindings.PARRY):
			get_viewport().set_input_as_handled()
		return
	if _done or _focus_lost:
		return
	if _waiting_for_start:
		if latch.is_fresh_press(event, InputBindings.CONFIRM):
			get_viewport().set_input_as_handled()
			# The start press is consumed; reaction keys still held now must be released first.
			latch.latch_held(_reaction_actions())
			_start()
		else:
			for reaction in REACTIONS:
				if event.is_action_pressed(KEYS[reaction], false):
					# Reactions do nothing before the sequence starts (never an attempt).
					get_viewport().set_input_as_handled()
		return
	if clock.is_frozen() or _chosen != Enums.ReactionType.NONE:
		return
	for reaction in REACTIONS:
		if latch.is_fresh_press(event, KEYS[reaction]):
			get_viewport().set_input_as_handled()
			if not spec.is_allowed(reaction):
				# Unavailable reactions are inert: they neither lock the choice nor fail it.
				AudioManager.play(AudioManager.Cue.UI_CANCEL, 0.0, -6.0)
				_flash_unavailable(reaction)
				return
			_chosen = reaction
			_offset_ms = elapsed_ms() - impact_ms()
			_success = ReactionRules.is_success(spec, reaction, _offset_ms)
			_refresh_cards()
			if _offset_ms >= 0.0:
				_finish()
			return


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if spec != null and not _done and not _focus_lost:
				_focus_lost = true
				clock.freeze()
				_refresh_cards()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _focus_lost:
				_focus_lost = false
				latch.latch_held(_reaction_actions())
				latch.latch_held([InputBindings.CONFIRM])
				_refresh_cards()


func _process(_delta: float) -> void:
	latch.poll()
	if _running and clock.is_frozen() and not _focus_lost and not latch.any_latched():
		clock.resume()
		_refresh_cards()
	if _running and not _done and not clock.is_frozen():
		var largest := maxf(spec.brace_window_ms, maxf(spec.evade_window_ms, spec.parry_window_ms))
		var deadline := impact_ms() + (60.0 if _chosen != Enums.ReactionType.NONE else largest * 0.5)
		if elapsed_ms() >= deadline:
			_finish()
	queue_redraw()
	if _meter_space != null:
		_meter_space.queue_redraw()
	if not _done:
		_refresh_cards()


func _finish() -> void:
	if _done:
		return
	_done = true
	var result := ReactionResult.make(_chosen, _success)
	_refresh_cards()
	queue_redraw()
	var hold := create_tween()
	hold.tween_interval(FEEDBACK_HOLD)
	await hold.finished
	finished.emit(result)


# --- Drawing: rings on the stage and the dock meter ---------------------------------------------

func _draw() -> void:
	if spec == null:
		return
	var t := clampf(elapsed_ms() / maxf(1.0, impact_ms()), 0.0, 1.2)
	for point in target_points:
		# Painted medallions brighten at the grader's actual boundaries.
		for index in REACTIONS.size():
			var reaction: Enums.ReactionType = REACTIONS[index]
			var allowed := spec.is_allowed(reaction)
			var open := invites_press(reaction)
			var angle := -PI * 0.5 + index * TAU / 3
			var radius := IMPACT_RADIUS + 9
			var color := IconPainter.reaction_color(reaction) if allowed else UITheme.TEXT_FAINT
			var center := point + Vector2.from_angle(angle + PI / 3) * (radius + 22)
			CombatIcons.paint(self, CombatIcons.mapping("reactions", reaction), Rect2(center - Vector2(16, 16), Vector2(32, 32)), Color.WHITE if allowed else Color(0.35, 0.35, 0.35))
			if open:
				draw_texture_rect(UICraft.texture("reaction_selected"), Rect2(center - Vector2(19, 19), Vector2(38, 38)), false, color)
		draw_texture_rect(UICraft.texture("ring_open"), Rect2(point - Vector2.ONE * IMPACT_RADIUS, Vector2.ONE * IMPACT_RADIUS * 2), false)
		if _running or _preparing or _waiting_for_start:
			var radius := lerpf(START_RADIUS, IMPACT_RADIUS, minf(t, 1.0))
			var color := UITheme.TEXT if t < 1.0 else UITheme.THREAT
			draw_texture_rect(UICraft.texture("ring"), Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, color)


## The grader's own test (ReactionRules.is_success at this instant), so the cue cannot drift from
## grading. Closed once a press has locked the choice.
func window_open(reaction: Enums.ReactionType) -> bool:
	return _running and not _done and _chosen == Enums.ReactionType.NONE \
		and ReactionRules.is_success(spec, reaction, elapsed_ms() - impact_ms())


## The window is open and a press would be read now: never while the clock is frozen (focus lost,
## or keys still held after regaining it), when presses are ignored. Arcs thicken and cards say NOW
## only then.
func invites_press(reaction: Enums.ReactionType) -> bool:
	return window_open(reaction) and not _focus_lost and not clock.is_frozen()


## Drawn on the meter's own control (above the dock panel). A horizontal track: the marker runs
## toward a fixed impact line; the bands are the real windows, so it reads without sound or motion.
func _draw_meter() -> void:
	if _meter_space == null:
		return
	var area := Rect2(Vector2.ZERO, _meter_space.size)
	var meter := Rect2(0.0, area.size.y - 12.0, area.size.x, 10.0)
	if meter.size.x <= 0.0:
		return
	var largest := maxf(spec.brace_window_ms, maxf(spec.evade_window_ms, spec.parry_window_ms))
	var span := impact_ms() + largest * 0.5 + 120.0
	var impact_x := meter.position.x + meter.size.x * impact_ms() / span
	UICraft.draw(_meter_space, "timing_track", meter.grow(4))
	for reaction in REACTIONS:
		if not spec.is_allowed(reaction):
			continue
		var width := spec.window_for(reaction) / span * meter.size.x
		var alpha: float = {Enums.ReactionType.BRACE: 0.22, Enums.ReactionType.EVADE: 0.4, Enums.ReactionType.PARRY: 0.7}[reaction]
		_meter_space.draw_texture_rect(UICraft.texture("timing_fill"), Rect2(impact_x - width * 0.5, meter.position.y, width, meter.size.y), false,
			Color(IconPainter.reaction_color(reaction), alpha))
	_meter_space.draw_texture_rect(UICraft.texture("needle"), Rect2(impact_x - 5, meter.position.y - 10, 10, 30), false)
	var small := UITheme.secondary_size()
	_meter_space.draw_string(_font, Vector2(impact_x + 6.0, meter.position.y - 4.0), "Impact", HORIZONTAL_ALIGNMENT_LEFT, -1,
		small, UITheme.TEXT_DIM)
	if _running or _preparing or _waiting_for_start:
		var x := meter.position.x + meter.size.x * clampf(elapsed_ms() / span, 0.0, 1.0)
		_meter_space.draw_texture_rect(UICraft.texture("cursor"), Rect2(x - 6, meter.position.y - 9, 12, 28), false)


# --- Dock cards ---------------------------------------------------------------------------------

func _build_cards() -> void:
	var panel := PanelContainer.new()
	panel.name = "ReactionDock"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UICraft.panel("cloth", 14, 10))
	add_child(panel)
	panel.position = dock_rect.position
	panel.size = dock_rect.size
	panel.custom_minimum_size = dock_rect.size
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(6 * UITheme.text_scale()))
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_header = UITheme.label("%s → %s" % [readout.attacker_name.to_upper(), readout.target_text.to_upper()], UITheme.ACCENT,
		UITheme.body_size())
	_header.clip_text = true
	_header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	_instruction = UITheme.label("", UITheme.TEXT, UITheme.secondary_size())
	_instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_instruction)
	_meter_space = Control.new()
	_meter_space.custom_minimum_size = Vector2(0, UITheme.secondary_size() + 18)
	_meter_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_space.draw.connect(_draw_meter)
	column.add_child(_meter_space)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Long condition caveats cannot force the dock outside the viewport. The real impact meter
	# stays fixed above this scroll area; keyboard navigation can read overflow before/after input.
	var scroll := ScrollContainer.new()
	scroll.name = "ReactionCards"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	scroll.add_child(row)
	for reaction_row in readout.rows:
		row.add_child(_make_card(reaction_row))
	_footer = UITheme.label("", UITheme.WET, UITheme.secondary_size(), true)
	column.add_child(_footer)


func _make_card(reaction_row: ReactionReadout.Row) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.focus_mode = Control.FOCUS_ALL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	title_row.add_child(CombatIcons.image(CombatIcons.mapping("reactions", reaction_row.reaction), 28))
	var key := UITheme.label(reaction_row.key_text(), UITheme.TEXT, UITheme.secondary_size())
	key.add_theme_stylebox_override("normal", UICraft.icon_frame())
	key.custom_minimum_size = Vector2(34, 34)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(key)
	var name := UITheme.label(reaction_row.name, UITheme.TEXT if reaction_row.allowed else UITheme.TEXT_FAINT, UITheme.body_size())
	title_row.add_child(name)
	var status := UITheme.label("", UITheme.ACCENT, UITheme.secondary_size())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme.text_scale() >= 1.3:
		box.add_child(status)
	else:
		title_row.add_child(status)
	if not reaction_row.allowed:
		# Struck through and labelled in words: never colour alone.
		name.text = reaction_row.name
		name.add_theme_color_override("font_color", UITheme.TEXT_FAINT)
		var strike := ColorRect.new()
		strike.color = UITheme.THREAT
		strike.custom_minimum_size = Vector2(0, 2)
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.add_child(strike)
		strike.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	_cards.append(card)
	_card_status.append(status)
	return card


func _refresh_cards() -> void:
	if _cards.is_empty():
		return
	for index in _cards.size():
		var reaction: Enums.ReactionType = REACTIONS[index]
		var allowed := spec.is_allowed(reaction)
		var selected := false
		var status := "" if allowed else "Unavailable"
		if allowed and invites_press(reaction):
			selected = true
			status = "NOW"
		elif not allowed and Time.get_ticks_msec() < _unavailable_until.get(int(reaction), 0):
			status = "Unavailable"
		if reaction == _chosen:
			selected = true
			status = result_word() if _done else "Locked"
		_cards[index].add_theme_stylebox_override("panel", UICraft.panel("selected" if selected else "technique", 12, 8, Color.WHITE if allowed else Color(0.6, 0.6, 0.6)))
		_card_status[index].text = status
		_card_status[index].add_theme_color_override("font_color",
			UITheme.HEART if status == "Success" else (UITheme.THREAT if status in ["Early", "Late", "Unavailable"] else UITheme.ACCENT))
	var key := InputBindings.prompt(InputBindings.CONFIRM)
	if _focus_lost:
		_instruction.text = "Paused: focus lost"
	elif _preparing:
		_instruction.text = "Prepare"
	elif _running and clock.is_frozen():
		_instruction.text = "Release held keys"
	elif _waiting_for_start:
		_instruction.text = "%s Begin" % key
	elif _done:
		_instruction.text = result_word() if _chosen != Enums.ReactionType.NONE else "No reaction"
	else:
		_instruction.text = "React at impact"
	# The help bar says "first allowed press locks"; the dock keeps only the assist note.
	_footer.text = readout.assist_text
	_footer.visible = not readout.assist_text.is_empty()


## Notes the inert press on the struck card for a moment (cards refresh every frame, so the note is
## state rather than a one-frame label; static text, no flashing).
func _flash_unavailable(reaction: Enums.ReactionType) -> void:
	_unavailable_until[int(reaction)] = Time.get_ticks_msec() + UNAVAILABLE_NOTE_MS
	_refresh_cards()
