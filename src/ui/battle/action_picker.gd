class_name ActionPicker
extends Node
## Player action selection: the action menu, then (for single-target actions with a choice) the
## target, chosen with left/right or the mouse. The info panel always previews what is focused.
## Back returns from target selection to the menu. Owns no battle state; returns an ActionChoice.

signal picked(choice: ActionChoice)

enum Mode { IDLE, MENU, TARGET }

var engine: BattleEngine
var menu: ActionMenu
var battlefield: Battlefield
var info: PreviewPanel
## Analysis layer (info key held or tooltips set to ALWAYS).
var advanced := false

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
	if not menu.option_focused.is_connected(_on_option_focused):
		menu.option_focused.connect(_on_option_focused)
		menu.option_chosen.connect(_on_option_chosen)


func is_active() -> bool:
	return _mode != Mode.IDLE


func is_targeting() -> bool:
	return _mode == Mode.TARGET


## Shows the menu for the request's unit and waits for a complete choice.
func choose(request: ActionSelectRequest) -> ActionChoice:
	_unit = engine.get_unit(request.unit_uid)
	_focused = null
	_enter_menu(request.options)
	var choice: ActionChoice = await picked
	return choice


## Abandons the selection (battle freed or restarted).
func cancel() -> void:
	_mode = Mode.IDLE
	menu.hide_menu()
	battlefield.set_highlight(-1)


## Re-renders the info panel for the current focus (e.g. after the info key changed).
func render() -> void:
	match _mode:
		Mode.MENU:
			if _focused != null:
				_show_preview(_focused, _default_target(_focused))
		Mode.TARGET:
			_show_preview(_option, _targets[_target_index])


## Pointer over a unit while targeting: move the target cursor there.
func hover(uid: int) -> void:
	if _mode == Mode.TARGET and _targets.has(uid) and _targets[_target_index] != uid:
		_target_index = _targets.find(uid)
		_update_target()


func click(uid: int) -> void:
	if _mode == Mode.TARGET and _targets.has(uid):
		_target_index = _targets.find(uid)
		_submit(_option, uid)


func _input(event: InputEvent) -> void:
	if _mode != Mode.TARGET or event.is_echo():
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
		_mode = Mode.MENU
		battlefield.set_highlight(-1)
		menu.focus_option(_option)


func _enter_menu(options: Array[ActionOption]) -> void:
	_mode = Mode.MENU
	battlefield.set_highlight(-1)
	menu.show_options(_unit, options, engine)


func _on_option_focused(option: ActionOption) -> void:
	if _mode == Mode.IDLE:
		return
	_focused = option
	if _mode == Mode.MENU:
		AudioManager.play(AudioManager.Cue.UI_MOVE, 0.0, -8.0)
		_show_preview(option, _default_target(option))


func _on_option_chosen(option: ActionOption) -> void:
	if _mode == Mode.IDLE:
		return
	if not option.legal:
		AudioManager.play(AudioManager.Cue.UI_CANCEL)
		return
	AudioManager.play(AudioManager.Cue.UI_CONFIRM)
	if not option.action.needs_target_choice():
		_submit(option, -1)
	elif option.target_uids.size() == 1:
		_submit(option, option.target_uids[0])
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
	var uid := _targets[_target_index]
	battlefield.set_highlight(uid)
	AudioManager.play(AudioManager.Cue.UI_MOVE, 0.0, -8.0)
	_show_preview(_option, uid)


func _submit(option: ActionOption, target_uid: int) -> void:
	var target := engine.get_unit(target_uid)
	if target != null and target.is_enemy():
		_last_enemy_target = target_uid
	_mode = Mode.IDLE
	menu.hide_menu()
	battlefield.set_highlight(-1)
	picked.emit(ActionChoice.from_option(_unit.uid, option, target_uid))


func _default_target(option: ActionOption) -> int:
	if option.target_uids.is_empty():
		return -1
	if option.target_uids.has(_last_enemy_target):
		return _last_enemy_target
	var best := option.target_uids[0]
	for uid in option.target_uids:
		if battlefield.view(uid).position.x < battlefield.view(best).position.x:
			best = uid
	return best


func _show_preview(option: ActionOption, target_uid: int) -> void:
	var choice := ActionChoice.from_option(_unit.uid, option, target_uid)
	var preview := engine.preview(choice)
	var spec := CommandRules.build_spec(engine.ctx, _unit, option.action)
	var text := PreviewPanel.describe(preview, engine, advanced, spec)
	if not option.legal:
		text = "[color=#d65a43]Unavailable: %s[/color]\n%s" % [option.reason, text]
	elif _mode == Mode.TARGET:
		text += "\n[color=#5f5c55]%s/%s target · %s confirm · %s back[/color]" % [
			InputBindings.key_label(InputBindings.LEFT), InputBindings.key_label(InputBindings.RIGHT),
			InputBindings.key_label(InputBindings.CONFIRM), InputBindings.key_label(InputBindings.CANCEL)]
	info.show_text(text)
