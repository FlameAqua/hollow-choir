class_name ExplorationHUD
extends Control
## Quiet exploration chrome; the host owns facts and input eligibility.

signal map_requested
signal menu_requested
signal character_requested
signal journal_requested
## Kept for the historical world-study fixture.
const FRAME := preload("res://assets/art/global/ui/frames/choir_v01/styles/panel.tres")

var prompt_bottom_inset: float = 24.0
var _area: Label
var _objective: Label
var _prompt: PanelContainer
var _prompt_text: Label
var _map: Button
var _character: Button
var _menu: Button
var _area_time := 0.0
var _last_area := ""
var _feedback: Label
var _feedback_time := 0.0
var _journal: Button
var _quest_notice: Label
var _quest_time := 0.0
var _quest_attention := false
var _countdown: ThreatCountdownView

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area = UITheme.label("", UITheme.ACCENT, 33)
	_area.position = Vector2(28, 24)
	_area.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .9))
	_area.add_theme_constant_override("shadow_offset_x", 2)
	_area.add_theme_constant_override("shadow_offset_y", 2)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area)
	_objective = UITheme.label("", UITheme.TEXT, 22, true)
	_objective.position = Vector2(28, 76)
	_objective.size = Vector2(470, 60)
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.add_theme_color_override("font_shadow_color", Color.BLACK)
	_objective.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_objective)
	var toolbelt := PanelContainer.new()
	toolbelt.name = "Toolbelt"
	toolbelt.position = Vector2(1052, 24)
	toolbelt.add_theme_stylebox_override("panel", UICraft.panel("tooltip", 10, 4))
	add_child(toolbelt)
	var tools := HBoxContainer.new()
	toolbelt.add_child(tools)
	_character = _button("hollow_head", func() -> void: character_requested.emit())
	_character.name = "Character"
	_character.tooltip_text = "Character"
	_character.reparent(tools)
	_map = _button("map", func() -> void: map_requested.emit())
	_map.reparent(tools)
	_journal = _button("log", func() -> void:
		_quest_attention = false
		journal_requested.emit())
	_journal.name = "Journal"
	_journal.tooltip_text = "Journal"
	_journal.reparent(tools)
	_journal.hide()
	_menu = _button("menu", func() -> void: menu_requested.emit())
	_menu.reparent(tools)
	for button in tools.get_children(): button.set_meta(&"compact_tooltip", true)
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UICraft.panel("tooltip", 14, 8))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_prompt_text = UITheme.label("", UITheme.TEXT, 22)
	_prompt_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_prompt_text)
	_prompt.minimum_size_changed.connect(_layout_prompt.call_deferred)
	resized.connect(_layout_prompt.call_deferred)
	_prompt.hide()
	_feedback = UITheme.label("", UITheme.TEXT, 22, true)
	_feedback.name = "ExplorationFeedback"
	_feedback.position = Vector2(290, 578)
	_feedback.size = Vector2(700, 72)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.add_theme_color_override("font_shadow_color", Color.BLACK)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.hide()
	add_child(_feedback)
	_countdown = ThreatCountdownView.new()
	_countdown.name = "ThreatCountdown"
	_countdown.position = Vector2(510, 104)
	_countdown.size = Vector2(300, 44)
	add_child(_countdown)
	_quest_notice = UITheme.label("", UITheme.TEXT, 22, true)
	_quest_notice.name = "QuestNotice"
	_quest_notice.position = Vector2(340, 54)
	_quest_notice.size = Vector2(600, 64)
	_quest_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_notice.hide()
	add_child(_quest_notice)
	EventBus.quest_changed.connect(_quest_changed)
	TooltipPolicy.install(self)

func _process(delta: float) -> void:
	_area_time = maxf(0, _area_time - delta)
	_area.modulate.a = minf(1, _area_time / 1.2)
	_feedback_time = maxf(0, _feedback_time - delta)
	_feedback.visible = _feedback_time > 0
	_quest_time = maxf(0, _quest_time - delta)
	_quest_notice.visible = _quest_time > 0
	_quest_notice.modulate.a = minf(1, _quest_time / .7)
	var pulse := 1.0 + .18 * sin((4.5 - _quest_time) * TAU * .7) if _quest_attention and _quest_time > 0 and not Settings.data.reduce_motion and not Settings.data.reduce_flashing else 1.0
	_journal.modulate = Color(pulse, pulse, .85 if _quest_attention else 1.0)

func _quest_changed(change: QuestChange) -> void:
	_quest_attention = true
	_quest_time = 4.5
	_quest_notice.text = "%s\n%s" % [change.title, change.objective]
	_quest_notice.show()

func present_countdown(readout: EncounterCountdownReadout) -> void:
	_countdown.present(readout)

func show_feedback(value: String) -> void:
	_feedback.text = value
	_feedback_time = 4.5
	_feedback.show()

func present(readout: ExplorationReadout) -> void:
	if readout.area_name != _last_area:
		_last_area = readout.area_name
		_area_time = 7.0
	_area.text = readout.area_name
	_objective.text = "· " + readout.objective
	var journal_wired := not journal_requested.get_connections().is_empty()
	_journal.visible = journal_wired
	_objective.visible = not journal_wired and not readout.objective.is_empty()
	_map.tooltip_text = "%s Map" % InputBindings.prompt(InputBindings.WORLD_MAP)
	_character.tooltip_text = "%s Loadout" % InputBindings.prompt(InputBindings.WORLD_LOADOUT)
	_journal.tooltip_text = "%s Journal" % InputBindings.prompt(InputBindings.WORLD_JOURNAL)
	_menu.tooltip_text = "%s Menu" % InputBindings.prompt(InputBindings.WORLD_MENU)
	_prompt_text.text = "%s · %s" % [readout.interaction_binding, readout.interaction]
	_prompt.visible = not readout.interaction.is_empty()
	_layout_prompt.call_deferred()

func focus_map() -> void:
	_map.grab_focus()

func _layout_prompt() -> void:
	if _prompt == null:
		return
	var width := minf(900, _prompt_text.get_theme_default_font().get_string_size(_prompt_text.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 30)
	_prompt.size = Vector2(width, 44)
	_prompt.position = Vector2((size.x - width) * .5, size.y - prompt_bottom_inset - 44)

func _button(id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id.capitalize()
	button.icon = UICraft.texture(id)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(40, 36)
	UICraft.style_tool_button(button)
	button.size = Vector2(40, 36)
	button.pressed.connect(callback)
	add_child(button)
	return button
