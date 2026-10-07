class_name BattleEventPlayer
extends Node
## Plays drained BattleEvents as presentation: movement, hit flashes, floating numbers, SFX, banners
## and log lines. It reads the engine only to look units up and never changes battle state.
##
## The engine resolves a whole step before the presenter sees it, so unit state is already final
## while events are played. HP/Stagger bars therefore follow a per-event ledger and are reconciled
## with the real state after each batch; the timeline follows TURN_* events, not the final state.
##
## Waits scale with the Combat Speed setting. Reaction windows never do (they live in the widgets).
## Every wait is a Tween bound to this node, so freeing the battle mid-animation (sandbox restart)
## simply drops the coroutine instead of resuming it on a freed instance.

signal log_line(bbcode: String)
## Timeline / party cards / side panel should redraw.
signal hud_changed

const HEAVY_HIT_FRACTION := 0.2
const FLOAT_STACK_MS := 450

var engine: BattleEngine
var battlefield: Battlefield
var timeline: TimelineBar
## Parent for floating text.
var overlay: Control
var banner: Banner
var speed := 1.0
var show_numbers := true
var show_ai_reasons := false
var familiar_fired_round := -1
## Everything played so far (defeat recap, end-of-battle metrics).
var history: Array[BattleEvent] = []
## Grade a manual command widget already displayed (-1 = none); COMMAND_RESULT then only shows a
## correction (e.g. raised by Execution Assist).
var widget_grade := -1

var _windup_shown: Dictionary[int, bool] = {}
var _hp: Dictionary[int, float] = {}
var _stagger: Dictionary[int, float] = {}
var _float_times: Dictionary[int, int] = {}
var _float_counts: Dictionary[int, int] = {}


func setup(p_engine: BattleEngine) -> void:
	engine = p_engine
	history.clear()
	_windup_shown.clear()
	for unit in engine.get_state().units:
		_hp[unit.uid] = unit.hp
		_stagger[unit.uid] = unit.stagger


func play(events: Array[BattleEvent]) -> void:
	for event in events:
		history.append(event)
		var text := BattleLogFormatter.line(event, engine)
		if not text.is_empty():
			log_line.emit(text)
		await _play_one(event)
	reconcile()


## Snap bars, intents and HUD to the engine's real state.
func reconcile() -> void:
	for unit in engine.get_state().units:
		_hp[unit.uid] = unit.hp
		_stagger[unit.uid] = unit.stagger
		var view := battlefield.view(unit.uid)
		if view == null:
			continue
		if not is_equal_approx(view.displayed_hp, unit.hp):
			_tween_property(view, "displayed_hp", float(unit.hp), 0.15)
		if not is_equal_approx(view.displayed_stagger, unit.stagger):
			_tween_property(view, "displayed_stagger", unit.stagger, 0.15)
		if not unit.is_alive():
			view.modulate.a = 0.0 if unit.is_enemy() else 0.55
	battlefield.refresh_intents()
	battlefield.refresh_units()
	hud_changed.emit()


## Wind-up before an action command or reaction; the following ACTION_STARTED only strikes.
## [param scaled] false = real time (matches a reaction's wind-up exactly).
func windup(uid: int, seconds: float, scaled: bool = true) -> void:
	_windup_shown[uid] = true
	var view := battlefield.view(uid)
	if view == null:
		return
	var duration := seconds / speed if scaled else seconds
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "body_offset", -battlefield.forward(uid) * 10.0, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(view, "body_scale", 1.07, duration)


func wait(seconds: float) -> void:
	await _wait(seconds)


func _play_one(event: BattleEvent) -> void:
	var T := BattleEvent.Type
	match event.type:
		T.ROUND_STARTED:
			timeline.round_number = int(event.amount)
			timeline.acted.clear()
			timeline.acting_uid = -1
			battlefield.hide_all_intents()
			hud_changed.emit()
			await banner.announce("Round %d" % int(event.amount), "", 0.3 / speed)
		T.TURN_ORDER:
			timeline.order = event.uids.duplicate()
			timeline.refresh()
		T.INTENT_DECLARED, T.INTENT_CHANGED:
			_show_declared_intent(event)
			AudioManager.play(AudioManager.Cue.TELEGRAPH, 0.05, -10.0)
			await _wait(0.14)
		T.TURN_STARTED:
			timeline.acting_uid = event.subject
			battlefield.set_active(event.subject)
			hud_changed.emit()
			await _wait(0.1)
		T.TURN_SKIPPED:
			_float(event.subject, "SKIP (Broken)", UITheme.STAGGER, 0.9)
			await _wait(0.5)
		T.TURN_ENDED:
			timeline.acted[event.subject] = true
			timeline.acting_uid = -1
			var unit := engine.get_unit(event.subject)
			if unit != null and unit.is_enemy() and (unit.intent == null or not unit.intent.channeling):
				battlefield.hide_intent(event.subject)
			hud_changed.emit()
		T.ACTION_STARTED:
			await _action_started(event)
		T.COMMAND_RESULT:
			if widget_grade != int(event.grade):
				var suffix := " (assist)" if widget_grade >= 0 else ""
				_float(event.subject, EnumText.grade(event.grade).to_upper() + suffix, CommandWidget.GRADE_COLORS[event.grade], 1.0)
				_grade_cue(event.grade)
				await _wait(0.3)
			widget_grade = -1
		T.REACTION_RESULT:
			await _reaction_result(event)
		T.DAMAGE:
			await _damage(event)
		T.HEAL:
			_hp[event.subject] = minf(_hp.get(event.subject, 0.0) + event.amount, engine.get_unit(event.subject).max_hp)
			_tween_property(battlefield.view(event.subject), "displayed_hp", _hp[event.subject], 0.3)
			if show_numbers:
				_float(event.subject, "+%d" % int(event.amount), UITheme.BLOOM, 1.05)
			AudioManager.play(AudioManager.Cue.HEAL)
			await _wait(0.22)
		T.FOCUS_CHANGED:
			var unit := engine.get_unit(event.subject)
			if event.amount > 0 and unit != null and not unit.is_enemy():
				_float(event.subject, "+%d Focus" % int(event.amount), UITheme.FOCUS, 0.75)
				AudioManager.play(AudioManager.Cue.FOCUS, 0.05, -6.0)
				await _wait(0.08)
			hud_changed.emit()
		T.STAGGER_DAMAGE:
			_stagger[event.subject] = event.amount2
			_tween_property(battlefield.view(event.subject), "displayed_stagger", event.amount2, 0.25)
		T.BROKEN:
			_stagger[event.subject] = 0.0
			_tween_property(battlefield.view(event.subject), "displayed_stagger", 0.0, 0.15)
			_float(event.subject, "BREAK!", UITheme.STAGGER, 1.6, 1.2)
			if event.has_flag(BattleEvent.FLAG_INTERRUPTED):
				_float(event.subject, "Channel interrupted!", UITheme.STAGGER, 0.9, 1.2)
			AudioManager.play(AudioManager.Cue.BREAK)
			battlefield.shake(9.0)
			_flash(event.subject, 1.0)
			await _wait(0.6)
		T.RECOVERED:
			var unit := engine.get_unit(event.subject)
			_stagger[event.subject] = unit.max_stagger
			_tween_property(battlefield.view(event.subject), "displayed_stagger", unit.max_stagger, 0.3)
			_float(event.subject, "Recovered", UITheme.TEXT_DIM, 0.8)
			await _wait(0.25)
		T.WEAK_POINT_EXPOSED:
			_float(event.subject, "Weak point exposed!", UITheme.FOCUS, 0.9)
			await _wait(0.3)
		T.STATUS_APPLIED:
			var verb := " (refreshed)" if event.has_flag(BattleEvent.FLAG_REFRESHED) else ""
			_float(event.subject, EnumText.status(event.status) + verb, IconPainter.status_color(event.status), 0.85)
			AudioManager.play(AudioManager.Cue.STATUS, 0.05, -3.0)
			await _wait(0.16)
		T.STATUS_BLOCKED:
			_float(event.subject, event.text.capitalize(), UITheme.TEXT_DIM, 0.8)
			await _wait(0.2)
		T.CHANNEL_STARTED:
			_show_declared_intent(event)
			_float(event.subject, "Channeling…", UITheme.ACCENT, 0.95)
			AudioManager.play(AudioManager.Cue.CHANNEL)
			await _wait(0.45)
		T.CHANNEL_CONTINUED:
			battlefield.refresh_intents()
			_float(event.subject, "Channeling (%d)" % int(event.amount), UITheme.ACCENT, 0.85)
			AudioManager.play(AudioManager.Cue.CHANNEL, 0.0, -6.0)
			await _wait(0.35)
		T.CHANNEL_INTERRUPTED:
			battlefield.hide_intent(event.subject)
			_float(event.subject, "Interrupted!", UITheme.STAGGER, 1.1)
			await _wait(0.4)
		T.INTERCEPTED:
			_float(event.subject, "Intercept!", UITheme.INFO, 0.95)
			_hop(event.subject)
			await _wait(0.3)
		T.COVER_STARTED, T.COVER_ENDED:
			battlefield.refresh_units()
			hud_changed.emit()
		T.TRIGGER_ACTIVATED:
			var state := engine.get_state()
			if state.familiar != null and event.text == state.familiar.display_name:
				familiar_fired_round = state.round
				hud_changed.emit()
			if event.subject >= 0:
				_float(event.subject, event.text, UITheme.TEXT_DIM.lightened(0.2), 0.75)
			await _wait(0.16)
		T.BUFF_APPLIED:
			_float(event.subject, event.text, UITheme.INFO, 0.8)
			battlefield.refresh_units()
			await _wait(0.12)
		T.BUFF_EXPIRED:
			battlefield.refresh_units()
		T.UNIT_DEFEATED:
			await _defeated(event)
		T.PHASE_CHANGED:
			_flash(event.subject, 1.0)
			battlefield.shake(6.0)
			await banner.announce(event.text, event.text2, 1.4 / speed)
		T.CONDITION_ADDED:
			await banner.announce(event.text, _condition_description(event.text), 1.0 / speed)
			hud_changed.emit()
		T.CONDITION_REMOVED:
			hud_changed.emit()
		T.DELAYED:
			_float(event.subject, "Delayed", UITheme.TEXT_DIM, 0.85)
			await _wait(0.25)
		T.INSPECTED:
			_float(event.subject, "Studied", UITheme.STAGGER, 0.9)
			battlefield.refresh_intents()
			await _wait(0.3)
		T.RESEARCH:
			var source := int(event.amount) as Enums.ResearchSource
			if source != Enums.ResearchSource.ENCOUNTER and source != Enums.ResearchSource.DEFEAT and event.subject >= 0:
				_float(event.subject, "Research: %s" % EnumText.research_source(source), UITheme.STAGGER.lightened(0.2), 0.7)


func _action_started(event: BattleEvent) -> void:
	var actor := event.subject
	var action := event.action
	if action == null:
		return
	_float(actor, action.display_name, UITheme.TEXT, 0.85)
	var hostile := action.deals_damage() or action.targets_enemies()
	if not _windup_shown.has(actor):
		windup(actor, 0.2)
		await _wait(0.2)
	_windup_shown.erase(actor)
	if hostile:
		await _lunge(actor)
	else:
		_settle(actor)
		_hop(actor)
		await _wait(0.2)


func _reaction_result(event: BattleEvent) -> void:
	if event.reaction == Enums.ReactionType.NONE:
		return
	var label: String
	if event.success:
		match event.reaction:
			Enums.ReactionType.BRACE:
				label = "Auto-Brace" if event.has_flag(BattleEvent.FLAG_AUTO) else "Braced"
				AudioManager.play(AudioManager.Cue.BRACE)
			Enums.ReactionType.EVADE:
				label = "Evaded!"
				AudioManager.play(AudioManager.Cue.EVADE)
				_dodge(event.subject)
			Enums.ReactionType.PARRY:
				label = "PARRY!"
				AudioManager.play(AudioManager.Cue.PARRY)
				battlefield.shake(5.0)
	else:
		label = "%s failed" % EnumText.reaction(event.reaction)
		AudioManager.play(AudioManager.Cue.MISS, 0.0, -4.0)
	_float(event.subject, label, IconPainter.reaction_color(event.reaction) if event.success else UITheme.DANGER, 1.0)
	await _wait(0.2)


func _damage(event: BattleEvent) -> void:
	var unit := engine.get_unit(event.subject)
	if unit == null:
		return
	_hp[event.subject] = maxf(0.0, _hp.get(event.subject, float(unit.hp)) - event.amount)
	_tween_property(battlefield.view(event.subject), "displayed_hp", _hp[event.subject], 0.3)
	var heavy := event.amount >= unit.max_hp * HEAVY_HIT_FRACTION
	var tick := event.has_flag(BattleEvent.FLAG_STATUS_TICK)
	if show_numbers:
		var color := UITheme.TEXT
		var size := 1.15
		var text := str(int(event.amount))
		if event.has_flag(BattleEvent.FLAG_WEAKNESS):
			color = UITheme.ACCENT
			size = 1.45
			text += " WEAK"
		elif event.has_flag(BattleEvent.FLAG_RESISTED):
			color = UITheme.TEXT_DIM
			size = 0.95
			text += " resist"
		elif tick:
			color = IconPainter.status_color(event.status) if event.status != Enums.StatusId.NONE else UITheme.DANGER
			size = 0.95
		if event.has_flag(BattleEvent.FLAG_WEAK_POINT):
			text += " ◆"
		_float(event.subject, text, color, size)
	if tick:
		AudioManager.play(AudioManager.Cue.HIT, 0.1, -8.0)
	elif event.has_flag(BattleEvent.FLAG_WEAKNESS):
		AudioManager.play(AudioManager.Cue.WEAKNESS)
	else:
		AudioManager.play(AudioManager.Cue.HIT_HEAVY if heavy else AudioManager.Cue.HIT, 0.08)
	_flash(event.subject, 1.0 if not tick else 0.5)
	if not tick:
		_knockback(event.subject)
	if heavy or event.has_flag(BattleEvent.FLAG_WEAKNESS):
		battlefield.shake(7.0 if heavy else 4.0)
	await _wait(0.34 if heavy else 0.22)


func _defeated(event: BattleEvent) -> void:
	var unit := engine.get_unit(event.subject)
	var view := battlefield.view(event.subject)
	if unit == null or view == null:
		return
	_hp[event.subject] = 0.0
	view.displayed_hp = 0.0
	battlefield.hide_intent(event.subject)
	AudioManager.play(AudioManager.Cue.HIT_HEAVY, 0.0, -2.0)
	var tween := create_tween()
	tween.tween_property(view, "modulate:a", 0.0 if unit.is_enemy() else 0.55, 0.45 / speed)
	await _wait(0.45)


func _show_declared_intent(event: BattleEvent) -> void:
	var unit := engine.get_unit(event.subject)
	if unit == null or not unit.is_alive() or not unit.is_enemy():
		return
	var preview := engine.preview_intent(event.subject)
	if preview == null:
		# Already consumed later in this batch: rebuild the telegraph from the event itself.
		preview = _preview_from_event(event, unit)
	if preview == null:
		return
	battlefield.show_intent(event.subject, preview)
	if show_ai_reasons and unit.intent != null and not unit.intent.reasons.is_empty():
		log_line.emit("  [color=#c9a3ff]Why: %s[/color]" % "; ".join(unit.intent.reasons))


func _preview_from_event(event: BattleEvent, unit: BattleUnit) -> IntentPreview:
	var action := event.action as EnemyActionDefinition
	if action == null:
		return null
	var preview := IntentPreview.new()
	preview.enemy_uid = unit.uid
	preview.action = action
	preview.target_uids = event.uids.duplicate()
	preview.detail_level = ResearchRules.detail_level(engine.ctx, unit)
	preview.turns_until_release = int(event.amount)
	for reaction: Enums.ReactionType in [Enums.ReactionType.BRACE, Enums.ReactionType.EVADE, Enums.ReactionType.PARRY]:
		if action.allows_reaction(reaction):
			preview.allowed.append(reaction)
	return preview


func _condition_description(display_name: String) -> String:
	for active in engine.get_state().conditions:
		if active.definition.display_name == display_name:
			return active.definition.description
	return ""


func _grade_cue(grade: Enums.ExecutionGrade) -> void:
	match grade:
		Enums.ExecutionGrade.PERFECT:
			AudioManager.play(AudioManager.Cue.PERFECT)
		Enums.ExecutionGrade.GOOD:
			AudioManager.play(AudioManager.Cue.GOOD)
		_:
			AudioManager.play(AudioManager.Cue.MISS)


# --- Motion helpers ------------------------------------------------------------------------------

func _lunge(uid: int) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	var tween := create_tween()
	tween.tween_property(view, "body_offset", battlefield.forward(uid) * 34.0, 0.08 / speed).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	_settle(uid)


## Returns the body to rest without blocking.
func _settle(uid: int) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, "body_offset", Vector2.ZERO, 0.22 / speed).set_trans(Tween.TRANS_SINE)
	tween.tween_property(view, "body_scale", 1.0, 0.22 / speed)


func _hop(uid: int) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	var tween := create_tween()
	tween.tween_property(view, "body_offset", Vector2(0, -12), 0.1 / speed).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(view, "body_offset", Vector2.ZERO, 0.14 / speed).set_trans(Tween.TRANS_QUAD)


func _dodge(uid: int) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	var tween := create_tween()
	tween.tween_property(view, "body_offset", -battlefield.forward(uid) * 26.0, 0.08 / speed)
	tween.tween_property(view, "body_offset", Vector2.ZERO, 0.25 / speed)


func _knockback(uid: int) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	var tween := create_tween()
	tween.tween_property(view, "body_offset", -battlefield.forward(uid) * 8.0, 0.05 / speed)
	tween.tween_property(view, "body_offset", Vector2.ZERO, 0.16 / speed)


func _flash(uid: int, strength: float) -> void:
	var view := battlefield.view(uid)
	if view == null:
		return
	view.flash = strength
	_tween_property(view, "flash", 0.0, 0.28)


func _float(uid: int, text: String, color: Color, size: float = 1.0, duration: float = 0.9) -> void:
	if overlay == null:
		return
	var now := Time.get_ticks_msec()
	var count := 0
	if now - _float_times.get(uid, -100000) < FLOAT_STACK_MS:
		count = _float_counts.get(uid, 0) + 1
	_float_times[uid] = now
	_float_counts[uid] = count
	var at := overlay.get_global_transform().affine_inverse() * battlefield.top_point(uid)
	FloatingText.spawn(overlay, at + Vector2(0, -6.0 - 20.0 * (count % 4)), text, color, size, duration / speed)


func _tween_property(target: Object, property: String, value: Variant, seconds: float) -> void:
	if target == null:
		return
	create_tween().tween_property(target, property, value, seconds / speed)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var tween := create_tween()
	tween.tween_interval(seconds / speed)
	await tween.finished
