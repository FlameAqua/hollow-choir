class_name ActionPicker
extends Node
## Planning: focus an action → review a recipient for any explicitly targeted action → commit.
## Back from the target returns to the same action and spends nothing. The preview always shows the
## focused action against its actual target. While target review is open, pointer hover moves the
## reviewed recipient unless Details is on (Details never moves the target). Owns no battle state;
## returns an ActionChoice.

signal picked(choice: ActionChoice)
## The planning prompt changed (help bar text).
signal help_changed(text: String)
## Direction/Confirm/Back arrived; emitted before target review consumes the key, so the shared
## inspector can follow keyboard focus even when its own input callback never sees the event.
signal keyboard_navigation

enum Mode { IDLE, MENU, TARGET }

var engine: BattleEngine
var menu: ActionMenu
var battlefield: Battlefield
var info: PreviewPanel
## Details (analysis layer) is on: hold, toggle or Always.
var details := false

var _mode := Mode.IDLE
var _unit: BattleUnit
var _focused: ActionOption
var _option: ActionOption
var _targets: Array[int] = []
var _target_index := 0
var _last_enemy_target := -1


func setup(p_engine: BattleEngine, p_menu: ActionMenu, p_battlefield: Battlefield, p_info: PreviewPanel) -> void:
	engine = p_engine
	menu = p_menu
	battlefield = p_battlefield
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
	_mode = Mode.MENU
	battlefield.set_highlight(-1)
	menu.show_options(_unit, request.options, engine)
	help_changed.emit(_help())
	var choice: ActionChoice = await picked
	return choice


## Abandons the selection (battle freed or restarted).
func cancel() -> void:
	_mode = Mode.IDLE
	menu.hide_menu()
	battlefield.set_highlight(-1)


## Re-renders the preview for the current focus (device changed, returned from target review…).
func render() -> void:
	match _mode:
		Mode.MENU:
			if _focused != null:
				_show(_focused, _default_target(_focused))
		Mode.TARGET:
			_show(_option, _targets[_target_index])


## Pointer over a unit while targeting moves the target cursor, unless Details is on: expanded
## inspection may read any unit without changing the reviewed recipient.
func hover(uid: int) -> void:
	if _mode == Mode.IDLE or details:
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


func _on_row_focused(option: ActionOption) -> void:
	if _mode != Mode.MENU:
		return
	AudioManager.play(AudioManager.Cue.UI_MOVE, 0.0, -8.0)
	_focused = option
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
	var target := engine.get_unit(target_uid)
	if target != null and target.is_enemy():
		_last_enemy_target = target_uid
	_mode = Mode.IDLE
	menu.hide_menu()
	help_changed.emit("")
	battlefield.set_highlight(-1)
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


## Selection brackets on the unit(s) the action would actually hit (no words over the sprites).
func _highlight(readout: ActionReadout) -> void:
	var uids: Array[int] = []
	for row in readout.targets:
		uids.append(row.uid)
	if readout.scope == ActionReadout.Scope.SELF:
		uids = [_unit.uid]
	battlefield.set_highlights(uids)


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
			return "[%s/%s] Choose · %s Select · %s Pause · %s Details" % [InputBindings.label(InputBindings.UP),
				InputBindings.label(InputBindings.DOWN), InputBindings.prompt(InputBindings.CONFIRM),
				InputBindings.prompt(InputBindings.MENU), details_key]
	return ""

func target_prompt() -> String:
	if _mode != Mode.TARGET:
		return ""
	return "Pick an enemy" if _option.action.targets_enemies() else "Pick an ally"
