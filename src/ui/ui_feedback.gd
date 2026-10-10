class_name UIFeedback
extends Node
## Soft navigation follows actual pointer/focus changes. Initial focus and rebuilds are silent.
var _scope: Control
var _last: Control
var _pending: Control
var _armed := false
var _intent_until := 0
var _queued := false

static func install(scope: Control) -> void:
	if scope.has_node("UIFeedback"): return
	var adapter := UIFeedback.new()
	adapter.name = "UIFeedback"
	adapter._scope = scope
	scope.add_child(adapter)

static func navigation(button: BaseButton) -> void:
	if button.has_meta(&"navigation_sound"): return
	button.set_meta(&"navigation_sound", true)
	var was_selected := [false]
	button.button_down.connect(func() -> void:
		was_selected[0] = button.toggle_mode and button.button_pressed and not (button is CheckBox or button is CheckButton))
	button.pressed.connect(func() -> void:
		if not was_selected[0]: AudioManager.play(AudioManager.Cue.UI_CONFIRM, 0, -9)
		was_selected[0] = false)

func _ready() -> void:
	_wire(_scope)
	get_tree().node_added.connect(_added)

func _added(node: Node) -> void:
	if _scope.is_ancestor_of(node): _wire.call_deferred(node)

func _wire(node: Node) -> void:
	if not is_instance_valid(node): return
	if node != _scope and node.has_node("UIFeedback"): return
	if node is BaseButton and not node.has_meta(&"hover_sound"):
		node.set_meta(&"hover_sound", true)
		node.mouse_entered.connect(func() -> void: _offer(node))
		node.focus_entered.connect(func() -> void: _offer(node))
	for child in node.get_children(): _wire(child)

func _input(event: InputEvent) -> void:
	var navigation_event := event is InputEventMouseMotion or event is InputEventJoypadMotion
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		navigation_event = navigation_event or event.is_action_pressed(action, true)
	if navigation_event:
		_armed = true
		_intent_until = Time.get_ticks_msec() + 120
	elif event.is_pressed():
		_armed = false

func _offer(control: Control) -> void:
	if not _armed or Time.get_ticks_msec() > _intent_until or control == _last or not control.is_visible_in_tree(): return
	if control is BaseButton and control.disabled: return
	_pending = control
	if not _queued:
		_queued = true
		_flush.call_deferred()

func _flush() -> void:
	_queued = false
	if not is_instance_valid(_pending) or not _pending.is_visible_in_tree(): return
	if _pending == _last: return
	_last = _pending
	AudioManager.play(AudioManager.Cue.UI_MOVE, 0, -12)
