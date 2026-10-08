class_name ActionPicker
extends Node
## Planning: focus an action → review a recipient for any explicitly targeted action → commit.
## Back from the target returns to the same action and spends nothing. The preview always shows the
## focused action against its actual target; pointer hover never replaces it unless Details is on,
## and Details never moves the target. Owns no battle state; returns an ActionChoice.

signal picked(choice: ActionChoice)
## The planning prompt changed (help bar text).
signal help_changed(text: String)
signal target_reviewed(uid: int)
signal keyboard_navigation

enum Mode { IDLE, MENU, TARGET }

var engine: BattleEngine
var menu: ActionMenu
var battlefield: Battlefield
var rail: IntentRail
var info: PreviewPanel
## Details (analysis layer) is on: hold, toggle or Always.
var details := false:
	set(value):
		if details != value:
			details = value
			if not value:
				_detail_uid = -1
			render()
## Lab debug: AI reasoning in unit details.
var show_debug := false
## Where the analysis layer goes (the Details panel over the stage); null = appended to the preview
## (stacked large-text layout).
var details_view: DetailsPanel

var _mode := Mode.IDLE
var _unit: BattleUnit
var _focused: ActionOption
var _group: Array = []
var _option: ActionOption
var _targets: Array[int] = []
var _target_index := 0
var _last_enemy_target := -1
## Unit under the pointer while Details is on (-1 = the action's own target).
var _detail_uid := -1


func setup(p_engine: BattleEngine, p_menu: ActionMenu, p_battlefield: Battlefield, p_rail: IntentRail,
		p_info: PreviewPanel) -> void:
	engine = p_engine
	menu = p_menu
	battlefield = p_battlefield
	rail = p_rail
	info = p_info
	menu.preview_provider = func(option: ActionOption) -> ActionReadout:
		var target := _targets[_target_index] if _mode == Mode.TARGET and option == _option else _default_target(option)
		return ActionReadout.build(engine, _unit.uid, option, target)
	if not menu.row_focused.is_connected(_on_row_focused):
		menu.row_focused.connect(_on_row_focused)
		menu.option_chosen.connect(_on_option_chosen)


func is_active() -> bool:
	return _mode != Mode.IDLE


func is_targeting() -> bool:
	return _mode == Mode.TARGET


func reviewed_target_uid() -> int:
	return _targets[_target_index] if _mode == Mode.TARGET else -1


func acting_unit() -> BattleUnit:
	return _unit if _mode != Mode.IDLE else null


## Shows the menu for the request's unit and waits for a complete choice.
func choose(request: ActionSelectRequest) -> ActionChoice:
	_unit = engine.get_unit(request.unit_uid)
	_focused = null
	_group = []
	_detail_uid = -1
	_mode = Mode.MENU
	battlefield.set_highlight(-1)
	menu.show_options(_unit, request.options, engine)
	help_changed.emit(_help())
	var choice: ActionChoice = await picked
	return choice


## Abandons the selection (battle freed or restarted).
func cancel() -> void:
	_mode = Mode.IDLE
	target_reviewed.emit(-1)
	menu.hide_menu()
	battlefield.set_highlight(-1)
	if rail != null:
		rail.set_selected(-1)


## Re-renders the preview for the current focus (Details toggled, device changed…).
func render() -> void:
	match _mode:
		Mode.MENU:
			if _focused != null:
				_show(_focused, _default_target(_focused))
			elif not _group.is_empty():
				_show_group(_group)
		Mode.TARGET:
			_show(_option, _targets[_target_index])


## Pointer over a unit: with Details on it chooses whose details to show; while targeting (Details
## off) it moves the target cursor. Otherwise it does nothing (the action summary stays).
func hover(uid: int) -> void:
	if _mode == Mode.IDLE:
		return
	if details:
		if uid >= 0 and uid != _detail_uid:
			_detail_uid = uid
			render()
		return
	if _mode == Mode.TARGET and uid >= 0 and _targets.has(uid) and _targets[_target_index] != uid:
		_target_index = _targets.find(uid)
		_update_target()


func click(uid: int) -> void:
	if _mode == Mode.TARGET and _targets.has(uid):
		_target_index = _targets.find(uid)
		_submit(_option, uid)


func _input(event: InputEvent) -> void:
	if _mode == Mode.IDLE or event.is_echo():
		return
	for action in [InputBindings.UP, InputBindings.DOWN, InputBindings.LEFT, InputBindings.RIGHT, InputBindings.CONFIRM, InputBindings.CANCEL]:
		if event.is_action_pressed(action):
			# Target navigation is consumed here, before the inspector's own input callback.
			keyboard_navigation.emit()
			break
	if _mode == Mode.MENU:
		if event.is_action_pressed(InputBindings.CANCEL) and menu.in_group():
			get_viewport().set_input_as_handled()
			AudioManager.play(AudioManager.Cue.UI_CANCEL)
			menu.back()
		return
	var step := 0
	if event.is_action_pressed(InputBindings.LEFT) or event.is_action_pressed(InputBindings.UP):
		step = -1
	elif event.is_action_pressed(InputBindings.RIGHT) or event.is_action_pressed(InputBindings.DOWN):
		step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		_target_index = wrapi(_target_index + step, 0, _targets.size())
		_update_target()
	elif event.is_action_pressed(InputBindings.CONFIRM):
		get_viewport().set_input_as_handled()
		_submit(_option, _targets[_target_index])
	elif event.is_action_pressed(InputBindings.CANCEL):
		get_viewport().set_input_as_handled()
		AudioManager.play(AudioManager.Cue.UI_CANCEL)
		back_to_menu()


## Leaves target review for the same action in the menu; nothing is spent (Back / a host pause).
func back_to_menu() -> void:
	if _mode != Mode.TARGET:
		return
	_mode = Mode.MENU
	menu.focus_option(_option)
	_focused = _option
	render()
	help_changed.emit(_help())


func _on_row_focused(option: ActionOption, group: Array) -> void:
	if _mode != Mode.MENU:
		return
	AudioManager.play(AudioManager.Cue.UI_MOVE, 0.0, -8.0)
	_focused = option
	_group = group
	render()
	help_changed.emit(_help())


func _on_option_chosen(option: ActionOption) -> void:
	if _mode != Mode.MENU or option == null:
		return
	if not option.legal:
		AudioManager.play(AudioManager.Cue.UI_CANCEL)
		return
	AudioManager.play(AudioManager.Cue.UI_CONFIRM)
	if not option.action.needs_target_choice():
		_submit(option, -1)
	else:
		_enter_target(option)


func _enter_target(option: ActionOption) -> void:
	_mode = Mode.TARGET
	_option = option
	_targets = option.target_uids.duplicate()
	_targets.sort_custom(func(a: int, b: int) -> bool:
		return battlefield.view(a).position.x < battlefield.view(b).position.x)
	_target_index = maxi(0, _targets.find(_default_target(option)))
	menu.get_viewport().gui_release_focus()
	_update_target()


func _update_target() -> void:
	AudioManager.play(AudioManager.Cue.UI_MOVE, 0.0, -8.0)
	_show(_option, _targets[_target_index])
	help_changed.emit(_help())


func _submit(option: ActionOption, target_uid: int) -> void:
	target_reviewed.emit(-1)
	var target := engine.get_unit(target_uid)
	if target != null and target.is_enemy():
		_last_enemy_target = target_uid
	_mode = Mode.IDLE
	menu.hide_menu()
	help_changed.emit("")
	battlefield.set_highlight(-1)
	if rail != null:
		rail.set_selected(-1)
	picked.emit(ActionChoice.from_option(_unit.uid, option, target_uid))


func _default_target(option: ActionOption) -> int:
	if option.target_uids.is_empty():
		return -1
	if option.target_uids.has(_last_enemy_target):
		return _last_enemy_target
	if not option.action.targets_enemies() and option.target_uids.has(_unit.uid):
		return _unit.uid
	var best := option.target_uids[0]
	for uid in option.target_uids:
		if battlefield.view(uid).position.x < battlefield.view(best).position.x:
			best = uid
	return best


func _show(option: ActionOption, target_uid: int) -> void:
	var readout := ActionReadout.build(engine, _unit.uid, option, target_uid)
	info.show_readout(readout)
	_highlight(readout)


## Group row focused: what is inside, with costs and reasons, before opening it.
func _show_group(group: Array) -> void:
	var lines := PackedStringArray()
	for item: ActionOption in group:
		var name := item.action.display_name
		if item.item_slot >= 0:
			name = engine.get_state().potion_slots[item.item_slot].potion.display_name
		var cost := " · %d Focus" % item.action.focus_cost if item.action.focus_cost > 0 else ""
		var line := "[b]%s[/b]%s" % [name, cost]
		if not item.legal:
			line += "  [color=%s]%s[/color]" % [UITheme.hex(UITheme.THREAT), ActionReadout.reason_text(_unit, item)]
		lines.append(line)
		if not item.action.description.is_empty():
			lines.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.TEXT_DIM), item.action.description])
	lines.append("[color=%s]%s Open[/color]" % [UITheme.hex(UITheme.TEXT_DIM), InputBindings.prompt(InputBindings.CONFIRM)])
	info.show_text("\n".join(lines))
	battlefield.set_highlight(-1)
	if rail != null:
		rail.set_selected(-1)


## Bone-gold bracket + "TARGET" on the unit(s) the action would actually hit, and the rail slot.
func _highlight(readout: ActionReadout) -> void:
	var uids: Array[int] = []
	for row in readout.targets:
		uids.append(row.uid)
	if readout.scope == ActionReadout.Scope.SELF:
		uids = [_unit.uid]
	battlefield.set_highlights(uids, "TARGET" if _mode == Mode.TARGET or uids.size() == 1 else "TARGETS")
	if rail != null:
		rail.set_selected(uids[0] if uids.size() == 1 and engine.get_unit(uids[0]).is_enemy() else -1)
	target_reviewed.emit(uids[0] if _mode == Mode.TARGET and uids.size() == 1 else -1)


func _details_extra(readout: ActionReadout) -> String:
	var uid := _detail_uid
	if uid < 0:
		uid = readout.targets[0].uid if not readout.targets.is_empty() else _unit.uid
	var parts := PackedStringArray()
	parts.append(UnitDetails.describe(engine, engine.get_unit(uid), show_debug))
	for active in engine.get_state().conditions:
		parts.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.WET), "\n".join(RuleNotes.condition_rule(engine.ctx.library, active.definition))])
	var interactions := RuleNotes.status_interactions(engine.ctx.library)
	if not interactions.is_empty():
		parts.append("[color=%s]Status rules: %s[/color]" % [UITheme.hex(UITheme.TEXT_DIM), " ".join(interactions)])
	return "\n\n".join(parts)


func _prompt(option: ActionOption) -> String:
	if not option.legal:
		return ""
	var confirm := InputBindings.prompt(InputBindings.CONFIRM)
	if _mode == Mode.TARGET:
		return "%s Confirm target · %s Back" % [confirm, InputBindings.prompt(InputBindings.CANCEL)]
	if option.action.needs_target_choice():
		return "%s Choose target" % confirm
	return "%s Use" % confirm


## Device-aware keys for the current planning step only (M1.1 context help).
func help_text() -> String:
	return _help()


func _help() -> String:
	var details_key := InputBindings.prompt(InputBindings.INFO)
	match _mode:
		Mode.TARGET:
			return "%s · [%s/%s] Choose · %s Confirm · %s Back" % [target_prompt(), InputBindings.label(InputBindings.LEFT),
				InputBindings.label(InputBindings.RIGHT), InputBindings.prompt(InputBindings.CONFIRM),
				InputBindings.prompt(InputBindings.CANCEL)]
		Mode.MENU:
			var back := " · %s Back" % InputBindings.prompt(InputBindings.CANCEL) if menu.in_group() else \
				" · %s Pause" % InputBindings.prompt(InputBindings.MENU)
			return "[%s/%s] Choose · %s Select%s · %s Details" % [InputBindings.label(InputBindings.UP),
				InputBindings.label(InputBindings.DOWN), InputBindings.prompt(InputBindings.CONFIRM), back, details_key]
	return ""

func target_prompt() -> String:
	if _mode != Mode.TARGET:
		return ""
	return "Pick an enemy" if _option.action.targets_enemies() else "Pick an ally"
