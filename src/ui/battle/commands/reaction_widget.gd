class_name ReactionWidget
extends Control
## Real-time defensive reaction. A ring shrinks onto each target and lands at impact; press Brace,
## Evade or Parry as it lands. The first allowed key locks the choice (DECISION_LOG D-008);
## unavailable reactions are shown struck through and ignored. Execution Assist may add a pause
## before the sequence.

signal finished(result: ReactionResult)
## The real-time sequence began (immediately, or after the assist pause): start the wind-up visuals.
signal started

const START_RADIUS := 120.0
const IMPACT_RADIUS := 26.0
const KEYS := {
	Enums.ReactionType.BRACE: InputBindings.BRACE,
	Enums.ReactionType.EVADE: InputBindings.EVADE,
	Enums.ReactionType.PARRY: InputBindings.PARRY,
}
const WORDS := {
	Enums.ReactionType.BRACE: ["BRACED", "Brace too late"],
	Enums.ReactionType.EVADE: ["EVADED", "Evade failed"],
	Enums.ReactionType.PARRY: ["PARRY!", "Parry failed"],
}

var spec: ReactionSpec
var action: EnemyActionDefinition
var target_points: Array[Vector2] = []
var attacker_name: String = ""
var _waiting_for_start := false
var _start_us: int = 0
var _chosen: Enums.ReactionType = Enums.ReactionType.NONE
var _success := false
var _done := false
var _font: Font


func begin(p_spec: ReactionSpec, p_action: EnemyActionDefinition, p_targets: Array[Vector2], p_attacker: String) -> void:
	spec = p_spec
	action = p_action
	target_points = p_targets
	attacker_name = p_attacker
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_for_start = spec.pause_before
	if not _waiting_for_start:
		_start()
	set_process(true)
	set_process_input(true)


func impact_ms() -> float:
	return spec.windup_ms


func elapsed_ms() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1000.0


func _start() -> void:
	_waiting_for_start = false
	_start_us = Time.get_ticks_usec()
	AudioManager.play(AudioManager.Cue.TELEGRAPH)
	started.emit()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if _waiting_for_start:
		for reaction in KEYS:
			if event.is_action_pressed(KEYS[reaction], false):
				get_viewport().set_input_as_handled()
				_start()
				return
		if event.is_action_pressed(InputBindings.CONFIRM, false):
			get_viewport().set_input_as_handled()
			_start()
		return
	if _chosen != Enums.ReactionType.NONE:
		return
	for reaction in KEYS:
		if event.is_action_pressed(KEYS[reaction], false):
			get_viewport().set_input_as_handled()
			if not spec.is_allowed(reaction):
				# Struck-through reactions are inert: they neither lock the choice nor fail it.
				AudioManager.play(AudioManager.Cue.UI_CANCEL, 0.0, -6.0)
				return
			_chosen = reaction
			_success = ReactionRules.is_success(spec, reaction, elapsed_ms() - impact_ms())
			if elapsed_ms() >= impact_ms():
				_finish()
			return


func _process(_delta: float) -> void:
	if _done or _waiting_for_start:
		queue_redraw()
		return
	var largest := maxf(spec.brace_window_ms, maxf(spec.evade_window_ms, spec.parry_window_ms))
	var deadline := impact_ms() + (60.0 if _chosen != Enums.ReactionType.NONE else largest * 0.5)
	if elapsed_ms() >= deadline:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	var result := ReactionResult.make(_chosen, _success)
	queue_redraw()
	await get_tree().create_timer(0.18).timeout
	finished.emit(result)


func _draw() -> void:
	if spec == null:
		return
	var t := 0.0 if _waiting_for_start else clampf(elapsed_ms() / maxf(1.0, impact_ms()), 0.0, 1.2)
	for point in target_points:
		draw_arc(point, IMPACT_RADIUS, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.9), 3.0)
		if not _waiting_for_start:
			var radius := lerpf(START_RADIUS, IMPACT_RADIUS, minf(t, 1.0))
			var color := Color(1, 1, 1, 0.9) if t < 1.0 else Color(1, 0.4, 0.3, 0.9)
			draw_arc(point, radius, 0, TAU, 40, color, 3.0)
	var panel := Rect2(size.x * 0.5 - 250, size.y - 150, 500, 92)
	draw_rect(panel, Color(0.04, 0.04, 0.07, 0.92))
	draw_rect(panel, UITheme.DANGER, false, 1.5)
	var font_size := UITheme.font_size(0.85)
	draw_string(_font, panel.position + Vector2(12, 8 + font_size), "%s: %s" % [attacker_name, action.display_name],
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 24, font_size, UITheme.TEXT)
	var x := panel.position.x + 14
	for reaction: Enums.ReactionType in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		var allowed := spec.is_allowed(reaction)
		var key := InputBindings.key_label(KEYS[reaction])
		var box := Rect2(x, panel.position.y + 36, 150, 26)
		var highlight := _chosen == reaction
		draw_rect(box, Color(0.15, 0.15, 0.2) if not highlight else Color(0.3, 0.25, 0.1))
		draw_rect(box, IconPainter.reaction_color(reaction) if allowed else Color(0.35, 0.35, 0.35), false, 1.5)
		var label := "[%s] %s" % [key, EnumText.reaction(reaction)]
		draw_string(_font, box.position + Vector2(8, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(0.78),
			IconPainter.reaction_color(reaction) if allowed else Color(0.45, 0.45, 0.45))
		if not allowed:
			draw_line(box.position, box.end, Color(0.85, 0.3, 0.25), 2.0)
		x += 160
	var footer := ""
	if _waiting_for_start:
		footer = "Get ready — press a reaction key to start"
	elif _done:
		footer = WORDS[_chosen][0 if _success else 1] if _chosen != Enums.ReactionType.NONE else "No reaction"
	elif _chosen != Enums.ReactionType.NONE:
		footer = "%s locked in…" % EnumText.reaction(_chosen)
	else:
		footer = "React as the ring lands"
	draw_string(_font, panel.position + Vector2(12, 84), footer, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 24,
		UITheme.font_size(0.75), UITheme.ACCENT)
