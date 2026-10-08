class_name CombatSandbox
extends Control
## Practice and Lab (M1.1 F4, D-022): two views of one battle setup.
##
## Practice is the first fight a player sees: an encounter from GameDefaults.practice_encounters
## (each says what it tests), a starter loadout, and the player's own Tactical Difficulty and
## Execution Assist (changing them here changes Settings). Its rules are fixed and shown: manual
## play, Unknown bestiary knowledge, no autopilot, no debug AI, progress not recorded. It never
## reuses Lab overrides.
##
## Lab is the M1 design tool (GDD "CombatSandbox"): any enemies and conditions, individual
## equipment, knowledge override, simulated execution, autopilot, AI reasoning, progress recording,
## seed and re-seed, and batch simulation with an in-game report. Its choices persist in
## user://sandbox.cfg; Practice remembers only its encounter, loadout and the open view.

const PREFS_PATH := "user://sandbox.cfg"
const EXECUTION_MANUAL := -1
const KNOWLEDGE_FROM_SAVE := -1
const SIM_BATTLES_PER_FRAME := 2

enum View { PRACTICE = 0, LAB = 1 }

var _registry: DefinitionRegistry
var _battle: BattleScene
var _battle_host: Control
var _setup: Control
var _view := View.PRACTICE
var _view_tabs: Array[Button] = []
var _practice_page: Control
var _lab_page: Control
var _status: Label
var _report: PanelContainer
var _report_text: RichTextLabel
var _start_button: Button
var _begin_button: Button
var _simulate_button: Button
var _hide_button: Button
var _simulating := false
var _filling := false
## View of the battle that is running (its restart follows that view's rules).
var _running_view := View.PRACTICE

# Practice.
var _practice_encounter: OptionButton
var _practice_loadout: OptionButton
var _practice_difficulty: OptionButton
var _practice_assist: OptionButton
var _practice_summary: RichTextLabel
var _practice_grid: GridContainer

# Lab.
var _form: VBoxContainer
var _encounter: OptionButton
var _encounter_note: Label
var _enemy_slots: Array[OptionButton] = []
var _major: OptionButton
var _minor: OptionButton
var _advantage: OptionButton
var _loadout: OptionButton
var _weapon: OptionButton
var _garb: OptionButton
var _charm: OptionButton
var _relic: OptionButton
var _companion: OptionButton
var _familiar: OptionButton
var _potions: Array[OptionButton] = []
var _difficulty: OptionButton
var _assist: OptionButton
var _knowledge: OptionButton
var _execution: OptionButton
var _autoplay: CheckBox
var _reasons: CheckBox
var _record: CheckBox
var _seed: SpinBox
var _reseed: CheckBox
var _runs: SpinBox


func _ready() -> void:
	_registry = Database.registry
	_build()
	_load_prefs()
	_show_setup(true)
	resized.connect(_fit_setup)
	_fit_setup()


## Runs before the embedded battle sees the key, so Escape closes the report or the setup instead
## of opening the battle's pause menu.
func _input(event: InputEvent) -> void:
	if _report.visible and (event.is_action_pressed(InputBindings.CANCEL) or event.is_action_pressed(InputBindings.MENU)):
		get_viewport().set_input_as_handled()
		_report.visible = false
	elif _setup.visible and _battle != null and event.is_action_pressed(InputBindings.MENU):
		get_viewport().set_input_as_handled()
		_show_setup(false)


func show_view(view: View) -> void:
	_view = view
	_practice_page.visible = view == View.PRACTICE
	_practice_page.get_parent_control().visible = view == View.PRACTICE
	_lab_page.visible = view == View.LAB
	for index in _view_tabs.size():
		_view_tabs[index].button_pressed = index == int(view)
	_status.text = ""
	if view == View.PRACTICE:
		_update_practice_summary()
	_focus_setup_start(view)


func _focus_setup_start(view: View) -> void:
	# Reflow (especially the enlarged one-column grid) must finish before focus-follow scrolling.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _setup.visible or _view != view:
		return
	var first := _practice_encounter if view == View.PRACTICE else _encounter
	first.grab_focus()
	var scroll := _practice_page.get_parent_control() as ScrollContainer if view == View.PRACTICE else _form.get_parent_control() as ScrollContainer
	# This runs after the ScrollContainer's focus-follow callback, at the settled geometry.
	scroll.set_deferred("scroll_vertical", 0)


# --- Running battles -----------------------------------------------------------------------------

func _begin_practice() -> void:
	var launch := make_practice_launch(randi_range(1, 99999))
	if launch == null:
		return
	_save_prefs()
	_running_view = View.PRACTICE
	_launch(launch, "Retry same setup", "Change setup")


func _start_lab() -> void:
	var launch := make_lab_launch(int(_seed.value))
	if launch == null:
		return
	_save_prefs()
	_running_view = View.LAB
	var retry := "Retry same setup (new seed)" if _reseed.button_pressed else "Retry same setup (seed %d)" % int(_seed.value)
	_launch(launch, retry, "Change setup")


func _launch(launch: BattleLaunch, retry_text: String, change_text: String) -> void:
	if _battle != null:
		_battle.queue_free()
	_battle = load(SceneRouter.BATTLE).instantiate() as BattleScene
	_battle.embedded = true
	_battle.retry_text = retry_text
	_battle.change_text = change_text
	_battle_host.add_child(_battle)
	_battle.add_toolbar_button("Setup", "Open Practice / Lab setup", _toggle_setup)
	_battle.add_toolbar_button("Restart", "Restart this battle", _restart)
	_battle.restart_requested.connect(_restart)
	_battle.setup_requested.connect(func() -> void: _show_setup(true))
	_battle.start(launch)
	_show_setup(false)


func _restart() -> void:
	if _running_view == View.PRACTICE:
		_begin_practice()
		return
	if _reseed.button_pressed:
		_seed.value = randi_range(1, 99999)
	_start_lab()


## Practice: the chosen preset and starter loadout with fixed rules, and the player's own
## difficulty and assist (with their auto-Brace / pause overrides).
func make_practice_launch(battle_seed: int) -> BattleLaunch:
	var encounter: EncounterDefinition = _practice_encounter.get_item_metadata(_practice_encounter.selected)
	var loadout: PartyLoadout = _practice_loadout.get_item_metadata(_practice_loadout.selected)
	if encounter == null or loadout == null:
		_status.text = "Pick an encounter and a loadout."
		return null
	var setup := BattleSetup.from_encounter(loadout, encounter, Database.library, Settings.difficulty_profile(),
		Settings.assist_profile(), battle_seed)
	for enemy in encounter.enemies:
		setup.research_levels[enemy.id] = Enums.ResearchLevel.UNKNOWN
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	launch.autoplay = false
	launch.simulated_execution = EXECUTION_MANUAL
	launch.show_ai_reasoning = false
	return launch


func make_lab_launch(battle_seed: int) -> BattleLaunch:
	var setup := _make_lab_setup(battle_seed)
	if setup == null:
		return null
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = _record.button_pressed
	launch.autoplay = _autoplay.button_pressed
	launch.simulated_execution = int(_meta(_execution))
	launch.show_ai_reasoning = _reasons.button_pressed
	return launch


func _simulate() -> void:
	if _simulating:
		return
	var setup := _make_lab_setup(int(_seed.value))
	if setup == null:
		return
	_save_prefs()
	var mode := int(_meta(_execution))
	var config := SimulationConfig.new()
	config.encounter = _make_encounter()
	config.loadout = setup.loadout
	config.library = setup.library
	config.difficulty = setup.difficulty
	config.assist = _registry.assist(int(_meta(_assist)) as Enums.ExecutionAssist)
	config.skill = _registry.skill((Enums.SimulatedExecution.GOOD if mode == EXECUTION_MANUAL else mode) as Enums.SimulatedExecution)
	config.research_levels = setup.research_levels
	config.runs = int(_runs.value)
	config.base_seed = int(_seed.value)
	config.label = "%s vs %s" % [setup.loadout.display_name, config.encounter.display_name]
	_simulating = true
	_simulate_button.disabled = true
	var report := SimulationReport.new(config)
	for index in config.runs:
		report.add(SimulationRunner.run_battle(config.make_setup(index), config.skill, config.policy))
		if index % SIM_BATTLES_PER_FRAME == SIM_BATTLES_PER_FRAME - 1:
			_status.text = "Simulating… %d / %d" % [index + 1, config.runs]
			await _next_frame()
	_simulating = false
	_simulate_button.disabled = false
	_status.text = "Simulated %d battles." % config.runs
	_show_report(report)


func _show_report(report: SimulationReport) -> void:
	var text := _markdown_to_bbcode(report.to_markdown())
	if int(_meta(_execution)) == EXECUTION_MANUAL:
		text = "[color=%s]Execution is Manual: simulated with GOOD execution.[/color]\n\n" % UITheme.hex(UITheme.TEXT_DIM) + text
	_report_text.text = text
	_report.visible = true
	_report.reset_size()
	_report.position = ((size - _report.size) * 0.5).round()


## Tables become "Metric: value" lines; headings become bold; warnings turn red.
static func _markdown_to_bbcode(markdown: String) -> String:
	var lines := PackedStringArray()
	for line in markdown.split("\n"):
		if line.begins_with("### "):
			lines.append("[b][color=%s]%s[/color][/b]" % [UITheme.hex(UITheme.ACCENT), line.substr(4)])
		elif line.begins_with("|---") or line.begins_with("| Metric"):
			continue
		elif line.begins_with("| "):
			var cells := line.trim_prefix("| ").trim_suffix(" |").split(" | ")
			lines.append("%s: [b]%s[/b]" % [cells[0], cells[1] if cells.size() > 1 else ""])
		elif line.begins_with("- ⚠"):
			lines.append("[color=%s]%s[/color]" % [UITheme.hex(UITheme.THREAT), line.substr(2)])
		else:
			lines.append(line)
	return "\n".join(lines)


func _next_frame() -> void:
	var tween := create_tween()
	tween.tween_interval(0.001)
	await tween.finished


# --- Lab form → setup ----------------------------------------------------------------------------

func _make_lab_setup(battle_seed: int) -> BattleSetup:
	var encounter := _make_encounter()
	if encounter.enemies.is_empty():
		_status.text = "Pick at least one enemy."
		return null
	var loadout := _make_loadout()
	var problems := loadout.validate()
	if not problems.is_empty():
		_status.text = "Loadout: %s" % problems[0]
		return null
	var assist := Settings.data.resolve_assist(_registry.assist(int(_meta(_assist)) as Enums.ExecutionAssist))
	var setup := BattleSetup.from_encounter(loadout, encounter, Database.library,
		_registry.difficulty(int(_meta(_difficulty)) as Enums.TacticalDifficulty), assist, battle_seed)
	var knowledge := int(_meta(_knowledge))
	if knowledge == KNOWLEDGE_FROM_SAVE:
		setup.research_levels = GameState.research_levels()
	else:
		for enemy in encounter.enemies:
			setup.research_levels[enemy.id] = knowledge
	_status.text = ""
	return setup


func _make_encounter() -> EncounterDefinition:
	var preset: EncounterDefinition = _registry.encounters.get(_meta(_encounter))
	if preset != null:
		return preset
	var custom := EncounterDefinition.new()
	custom.id = &"sandbox_custom"
	custom.display_name = "Custom battle"
	custom.group = "Lab"
	for slot in _enemy_slots:
		var enemy: EnemyDefinition = _registry.enemies.get(_meta(slot))
		if enemy != null:
			custom.enemies.append(enemy)
	for option in [_major, _minor]:
		var condition: BattlefieldConditionDefinition = _registry.conditions.get(_meta(option))
		if condition != null:
			custom.conditions.append(condition)
	custom.advantage = int(_meta(_advantage)) as Enums.Advantage
	return custom


func _make_loadout() -> PartyLoadout:
	var preset: PartyLoadout = _registry.loadouts.get(_meta(_loadout))
	var loadout := PartyLoadout.new()
	loadout.id = &"sandbox"
	loadout.display_name = preset.display_name if preset != null else "Custom loadout"
	loadout.protagonist = preset.protagonist if preset != null else _registry.protagonists.values()[0]
	loadout.weapon = _registry.weapons.get(_meta(_weapon))
	loadout.garb = _registry.armor.get(_meta(_garb))
	loadout.charm = _registry.armor.get(_meta(_charm))
	loadout.relic = _registry.armor.get(_meta(_relic))
	loadout.companion = _registry.companions.get(_meta(_companion))
	loadout.familiar = _registry.familiars.get(_meta(_familiar))
	for option in _potions:
		var potion: PotionDefinition = _registry.potions.get(_meta(option))
		if potion != null:
			loadout.potions.append(potion)
	return loadout


func _on_encounter_selected(_index: int) -> void:
	var encounter: EncounterDefinition = _registry.encounters.get(_meta(_encounter))
	if encounter == null:
		_encounter_note.text = "Custom: choose up to four enemies and the conditions below."
		return
	_filling = true
	for index in _enemy_slots.size():
		_select_meta(_enemy_slots[index], encounter.enemies[index].id if index < encounter.enemies.size() else &"")
	_select_meta(_major, &"")
	_select_meta(_minor, &"")
	for condition in encounter.conditions:
		_select_meta(_major if condition.severity == Enums.ConditionSeverity.MAJOR else _minor, condition.id)
	_select_meta(_advantage, int(encounter.advantage))
	_filling = false
	_encounter_note.text = encounter.description


## Editing the enemies or conditions turns the preset into a custom battle.
func _on_encounter_edited(_index: int) -> void:
	if not _filling and _meta(_encounter) != &"":
		_select_meta(_encounter, &"")
		_encounter_note.text = "Custom: edited from a preset."


func _on_loadout_selected(_index: int) -> void:
	var loadout: PartyLoadout = _registry.loadouts.get(_meta(_loadout))
	if loadout == null:
		return
	_filling = true
	_select_meta(_weapon, loadout.weapon.id if loadout.weapon else &"")
	_select_meta(_garb, loadout.garb.id if loadout.garb else &"")
	_select_meta(_charm, loadout.charm.id if loadout.charm else &"")
	_select_meta(_relic, loadout.relic.id if loadout.relic else &"")
	_select_meta(_companion, loadout.companion.id if loadout.companion else &"")
	_select_meta(_familiar, loadout.familiar.id if loadout.familiar else &"")
	for index in _potions.size():
		_select_meta(_potions[index], loadout.potions[index].id if index < loadout.potions.size() else &"")
	_filling = false


# --- Practice -------------------------------------------------------------------------------------

func _update_practice_summary() -> void:
	if _practice_summary == null:
		return
	var encounter: EncounterDefinition = _practice_encounter.get_item_metadata(_practice_encounter.selected)
	if encounter == null:
		return
	var count := encounter.enemies.size()
	var enemies := "One enemy" if count == 1 else "%d enemies" % count
	if encounter.id == &"toy_training":
		enemies = "One training enemy"
	var conditions := PackedStringArray()
	for condition in encounter.conditions:
		conditions.append(condition.display_name)
	var facts := PackedStringArray([enemies])
	if not conditions.is_empty():
		facts.append(", ".join(conditions))
	facts.append_array(["Manual play", "Unknown bestiary knowledge", "Progress not recorded"])
	var note := encounter.practice_note if not encounter.practice_note.is_empty() else encounter.description
	_practice_summary.text = "%s\n[color=%s]%s[/color]" % [note, UITheme.hex(UITheme.TEXT_DIM), " · ".join(facts)]


## Practice difficulty / assist are the player's own preferences: changing them changes Settings.
func _on_practice_difficulty(index: int) -> void:
	if not _filling:
		Settings.set_value("tactical_difficulty", int(_practice_difficulty.get_item_metadata(index)))


func _on_practice_assist(index: int) -> void:
	if not _filling:
		Settings.set_value("execution_assist", int(_practice_assist.get_item_metadata(index)))


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_host = Control.new()
	_battle_host.name = "BattleHost"
	add_child(_battle_host)
	_battle_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_setup = Control.new()
	_setup.name = "Setup"
	add_child(_setup)
	_setup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = UITheme.BG
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = Database.registry.defaults.battle_backdrop
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.modulate = Color(1, 1, 1, 0.35)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := ColorRect.new()
	fade.color = Color(UITheme.BG, 0.55)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 28)
	_setup.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(UITheme.label("Combat practice", UITheme.ACCENT, UITheme.body_size(), true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for name in ["Practice", "Lab"]:
		var tab := Button.new()
		tab.text = name
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(140, UITheme.control_height())
		var view := View.PRACTICE if name == "Practice" else View.LAB
		tab.pressed.connect(func() -> void: show_view(view))
		tabs.add_child(tab)
		_view_tabs.append(tab)
	_practice_page = _build_practice()
	var practice_scroll := ScrollContainer.new()
	practice_scroll.name = "PracticeScroll"
	practice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	practice_scroll.follow_focus = true
	practice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(practice_scroll)
	practice_scroll.add_child(_practice_page)
	_practice_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_tabs[0].toggled.connect(func(on: bool) -> void: practice_scroll.visible = on)
	_lab_page = _build_lab()
	_lab_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_lab_page)
	_status = UITheme.label("", UITheme.THREAT, UITheme.secondary_size(), true)
	column.add_child(_status)
	var footer := HBoxContainer.new()
	footer.name = "SetupFooter"
	column.add_child(footer)
	_hide_button = _button(footer, "Back to battle", func() -> void: _show_setup(false))
	_button(footer, "Main menu", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	_build_report_popup()


func _build_practice() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "Practice"
	page.add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	_practice_grid = grid
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	var defaults := _registry.defaults
	_practice_encounter = _field(grid, "Encounter")
	for encounter in defaults.practice_encounters:
		_practice_encounter.add_item(encounter.display_name)
		_practice_encounter.set_item_metadata(_practice_encounter.item_count - 1, encounter)
	_practice_encounter.item_selected.connect(func(_i: int) -> void: _update_practice_summary())
	_practice_loadout = _field(grid, "Loadout")
	for loadout in defaults.practice_loadouts:
		_practice_loadout.add_item(loadout.display_name)
		_practice_loadout.set_item_metadata(_practice_loadout.item_count - 1, loadout)
	_practice_difficulty = _field(grid, "Tactical difficulty")
	for value in Enums.TacticalDifficulty.values():
		_practice_difficulty.add_item(_registry.difficulty(value).display_name)
		_practice_difficulty.set_item_metadata(_practice_difficulty.item_count - 1, value)
	_practice_difficulty.item_selected.connect(_on_practice_difficulty)
	_practice_assist = _field(grid, "Execution assist")
	for value in Enums.ExecutionAssist.values():
		_practice_assist.add_item(_registry.assist(value).display_name)
		_practice_assist.set_item_metadata(_practice_assist.item_count - 1, value)
	_practice_assist.item_selected.connect(_on_practice_assist)
	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_LIGHT, UITheme.BORDER, 0, 3, 16, 12))
	page.add_child(summary_panel)
	_practice_summary = UITheme.rich_text()
	summary_panel.add_child(_practice_summary)
	_begin_button = Button.new()
	_begin_button.text = "Begin practice"
	_begin_button.custom_minimum_size = Vector2(240, UITheme.control_height() + 8.0)
	_begin_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_begin_button.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT, UITheme.ACCENT, 1, 3, 20, 10))
	_begin_button.add_theme_stylebox_override("hover", UITheme.box(UITheme.ACCENT.lightened(0.1), UITheme.ACCENT, 1, 3, 20, 10))
	_begin_button.add_theme_stylebox_override("focus", UITheme.box(Color(0, 0, 0, 0), UITheme.TEXT, 2, 3, 20, 10))
	_begin_button.add_theme_color_override("font_color", UITheme.BG)
	_begin_button.add_theme_color_override("font_hover_color", UITheme.BG)
	_begin_button.add_theme_color_override("font_focus_color", UITheme.BG)
	_begin_button.pressed.connect(_begin_practice)
	page.add_child(_begin_button)
	page.add_child(UITheme.label("Practice does not record progress. Timing help is independent of enemy tactics.",
		UITheme.TEXT_DIM, UITheme.secondary_size(), true))
	return page


func _field(grid: GridContainer, title: String) -> OptionButton:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	box.add_child(UITheme.heading(title))
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0, UITheme.control_height())
	box.add_child(option)
	grid.add_child(box)
	return option


func _build_lab() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "Lab"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	scroll.add_child(_form)
	_build_form()
	var buttons := HBoxContainer.new()
	page.add_child(buttons)
	_start_button = _button(buttons, "Start battle", _start_lab)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_simulate_button = _button(buttons, "Simulate", _simulate)
	_runs = SpinBox.new()
	_runs.min_value = 10
	_runs.max_value = 500
	_runs.step = 10
	_runs.value = 50
	_runs.tooltip_text = "Battles per simulation batch"
	buttons.add_child(_runs)
	return page


func _build_form() -> void:
	_section("Encounter")
	var encounter_entries: Array = [["Custom", &""]]
	var encounter_ids := _registry.sorted_ids(_registry.encounters)
	encounter_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left := _registry.encounters[a]
		var right := _registry.encounters[b]
		return left.group + left.display_name < right.group + right.display_name)
	for id in encounter_ids:
		var encounter := _registry.encounters[id]
		encounter_entries.append(["[%s] %s" % [encounter.group, encounter.display_name], id])
	_encounter = _option_row("Preset", encounter_entries)
	_encounter.item_selected.connect(_on_encounter_selected)
	_encounter_note = UITheme.label("", UITheme.TEXT_DIM, UITheme.secondary_size(), true)
	_form.add_child(_encounter_note)
	var enemy_entries: Array = [["—", &""]]
	for id in _registry.sorted_ids(_registry.enemies):
		var enemy := _registry.enemies[id]
		var tier := "" if enemy.tier == Enums.EnemyTier.NORMAL else " (%s)" % UnitDetails.TIER_WORDS[enemy.tier]
		enemy_entries.append([enemy.display_name + tier, id])
	for index in 4:
		var slot := _option_row("Enemy %d" % (index + 1), enemy_entries)
		slot.item_selected.connect(_on_encounter_edited)
		_enemy_slots.append(slot)
	_major = _option_row("Major condition", _condition_entries(Enums.ConditionSeverity.MAJOR))
	_major.item_selected.connect(_on_encounter_edited)
	_minor = _option_row("Minor condition", _condition_entries(Enums.ConditionSeverity.MINOR))
	_minor.item_selected.connect(_on_encounter_edited)
	_advantage = _option_row("Advantage", [["None", int(Enums.Advantage.NONE)], ["Party ambush", int(Enums.Advantage.PARTY_AMBUSH)],
		["Enemy ambush", int(Enums.Advantage.ENEMY_AMBUSH)]])
	_advantage.item_selected.connect(_on_encounter_edited)

	_section("Party")
	var loadout_entries: Array = []
	for id in _registry.sorted_ids(_registry.loadouts):
		loadout_entries.append([_registry.loadouts[id].display_name, id])
	_loadout = _option_row("Preset", loadout_entries)
	_loadout.item_selected.connect(_on_loadout_selected)
	var weapon_entries: Array = []
	for id in _registry.sorted_ids(_registry.weapons):
		var weapon := _registry.weapons[id]
		weapon_entries.append(["%s (%s)" % [weapon.display_name, EnumText.family(weapon.family)], id])
	_weapon = _option_row("Weapon", weapon_entries)
	_garb = _option_row("Garb", _armor_entries(Enums.EquipSlot.GARB))
	_charm = _option_row("Charm", _armor_entries(Enums.EquipSlot.CHARM))
	_relic = _option_row("Relic", _armor_entries(Enums.EquipSlot.RELIC))
	_companion = _option_row("Companion", _named_entries(_registry.companions, "None (solo)"))
	_familiar = _option_row("Familiar", _named_entries(_registry.familiars, "None"))
	for index in PartyLoadout.MAX_POTION_SLOTS:
		_potions.append(_option_row("Potion %d" % (index + 1), _named_entries(_registry.potions, "Empty")))

	_section("Rules")
	var difficulty_entries: Array = []
	for value in Enums.TacticalDifficulty.values():
		difficulty_entries.append([_registry.difficulty(value).display_name, value])
	_difficulty = _option_row("Tactical difficulty", difficulty_entries,
		"How smart enemies are. Changes decisions, never enemy stats.")
	var assist_entries: Array = []
	for value in Enums.ExecutionAssist.values():
		assist_entries.append([_registry.assist(value).display_name, value])
	_assist = _option_row("Execution assist", assist_entries, "Timing windows, speed, auto-Brace, reaction pause.")
	var knowledge_entries: Array = [["From save", KNOWLEDGE_FROM_SAVE]]
	for value in Enums.ResearchLevel.values():
		knowledge_entries.append([EnumText.research_level(value), value])
	_knowledge = _option_row("Bestiary knowledge", knowledge_entries, "What the HUD may reveal about these enemies.")

	_section("Play")
	var execution_entries: Array = [["Manual (you play)", EXECUTION_MANUAL]]
	for value in Enums.SimulatedExecution.values():
		execution_entries.append(["Simulated: %s" % EnumText.simulated_execution(value), value])
	_execution = _option_row("Execution", execution_entries, "Who performs action commands and reactions.")
	_autoplay = _check_row("Autopilot picks actions", "The party AI chooses actions (watch or test execution only).")
	_reasons = _check_row("Show AI reasoning (Lab debug)", "Intent details and the log explain why each move was chosen.")
	_record = _check_row("Record progress", "Bestiary research and weapon mastery from this battle are saved to your progress (slot 1).")
	_seed = SpinBox.new()
	_seed.min_value = 1
	_seed.max_value = 99999
	_seed.value = 1
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row("Seed", _seed, "Same seed + same inputs = same battle.")
	_reseed = _check_row("New seed on restart / retry", "Off: Retry replays the same seed.")
	_reseed.button_pressed = true


func _build_report_popup() -> void:
	_report = PanelContainer.new()
	_report.name = "Report"
	_report.visible = false
	_report.custom_minimum_size = Vector2(860, 560)
	add_child(_report)
	var box := VBoxContainer.new()
	_report.add_child(box)
	_report_text = RichTextLabel.new()
	_report_text.bbcode_enabled = true
	_report_text.scroll_active = true
	_report_text.selection_enabled = true
	_report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_report_text)
	var close := _button(box, "Close", func() -> void: _report.visible = false)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(160, UITheme.control_height())


## The battle header's Setup button. The setup page covers the whole battle, so the battle pauses
## first; during a timed input or playback that pause, and then this page, wait for the next safe
## point (the battle emits setup_requested), so no clock or input runs under the page.
func _toggle_setup() -> void:
	if _setup.visible:
		_show_setup(false)
	elif _battle == null or _battle.pause_for_host():
		_show_setup(true)


func _show_setup(open: bool) -> void:
	_setup.visible = open or _battle == null
	AudioManager.request_music(&"global_title" if _setup.visible else AudioManager.battle_music(_battle.launch.setup))
	_hide_button.visible = _battle != null
	if _setup.visible:
		if _battle != null:
			_battle.cover_for_host()
		_sync_practice_preferences()
		show_view(_view)
	elif _battle != null:
		_battle.resume_from_host()


func _fit_setup() -> void:
	if _practice_grid != null:
		_practice_grid.columns = 1 if size.x < 1100 or UITheme.text_scale() >= 1.5 else 2


## Practice shows the player's current difficulty / assist (they may have changed in Settings).
func _sync_practice_preferences() -> void:
	_filling = true
	_select_meta(_practice_difficulty, int(Settings.data.tactical_difficulty))
	_select_meta(_practice_assist, int(Settings.data.execution_assist))
	_filling = false


func _section(title: String) -> void:
	var label := UITheme.label(title.to_upper(), UITheme.ACCENT, UITheme.secondary_size())
	_form.add_child(label)


func _row(label_text: String, control: Control, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	var label := UITheme.label(label_text, UITheme.TEXT, UITheme.secondary_size())
	label.custom_minimum_size = Vector2(190, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	control.tooltip_text = tooltip
	row.add_child(control)
	_form.add_child(row)


func _option_row(label_text: String, entries: Array, tooltip: String = "") -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	option.fit_to_longest_item = false
	for entry: Array in entries:
		option.add_item(entry[0])
		option.set_item_metadata(option.item_count - 1, entry[1])
	_row(label_text, option, tooltip)
	return option


func _check_row(label_text: String, tooltip: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.tooltip_text = tooltip
	_form.add_child(check)
	return check


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, UITheme.control_height())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _condition_entries(severity: Enums.ConditionSeverity) -> Array:
	var entries: Array = [["None", &""]]
	for id in _registry.sorted_ids(_registry.conditions):
		var condition := _registry.conditions[id]
		if condition.severity == severity:
			entries.append([condition.display_name, id])
	return entries


func _armor_entries(slot: Enums.EquipSlot) -> Array:
	var entries: Array = [["None", &""]]
	for id in _registry.sorted_ids(_registry.armor):
		var item := _registry.armor[id]
		if item.slot == slot:
			entries.append([item.display_name, id])
	return entries


func _named_entries(collection: Dictionary, none_label: String) -> Array:
	var entries: Array = [[none_label, &""]]
	for id in _registry.sorted_ids(collection):
		entries.append([collection[id].display_name, id])
	return entries


static func _meta(option: OptionButton) -> Variant:
	return option.get_item_metadata(option.selected) if option.selected >= 0 else null


static func _select_meta(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return


# --- Preferences ---------------------------------------------------------------------------------

func _option_fields() -> Dictionary:
	var fields := {"encounter": _encounter, "major": _major, "minor": _minor, "advantage": _advantage,
		"loadout": _loadout, "weapon": _weapon, "garb": _garb, "charm": _charm, "relic": _relic,
		"companion": _companion, "familiar": _familiar, "difficulty": _difficulty, "assist": _assist,
		"knowledge": _knowledge, "execution": _execution}
	for index in _enemy_slots.size():
		fields["enemy_%d" % index] = _enemy_slots[index]
	for index in _potions.size():
		fields["potion_%d" % index] = _potions[index]
	return fields


func _save_prefs() -> void:
	var config := ConfigFile.new()
	config.load(PREFS_PATH)
	var fields := _option_fields()
	for key: String in fields:
		config.set_value("sandbox", key, _meta(fields[key]))
	config.set_value("sandbox", "autoplay", _autoplay.button_pressed)
	config.set_value("sandbox", "reasons", _reasons.button_pressed)
	config.set_value("sandbox", "record", _record.button_pressed)
	config.set_value("sandbox", "reseed", _reseed.button_pressed)
	config.set_value("sandbox", "seed", int(_seed.value))
	config.set_value("sandbox", "runs", int(_runs.value))
	var encounter: EncounterDefinition = _practice_encounter.get_item_metadata(_practice_encounter.selected)
	var loadout: PartyLoadout = _practice_loadout.get_item_metadata(_practice_loadout.selected)
	config.set_value("practice", "encounter", encounter.id if encounter != null else &"")
	config.set_value("practice", "loadout", loadout.id if loadout != null else &"")
	config.set_value("practice", "view", int(_view))
	config.save(PREFS_PATH)


func _load_prefs() -> void:
	# Lab defaults first: the practice encounter and starter loadout, the player's own settings.
	_select_meta(_encounter, _registry.defaults.practice_encounter.id)
	_on_encounter_selected(_encounter.selected)
	_select_meta(_loadout, _registry.defaults.starter_loadout.id)
	_on_loadout_selected(_loadout.selected)
	_select_meta(_difficulty, int(Settings.data.tactical_difficulty))
	_select_meta(_assist, int(Settings.data.execution_assist))
	_select_meta(_knowledge, KNOWLEDGE_FROM_SAVE)
	_select_meta(_execution, EXECUTION_MANUAL)
	_practice_encounter.select(0)
	_practice_loadout.select(0)
	var config := ConfigFile.new()
	if config.load(PREFS_PATH) == OK:
		_filling = true
		var fields := _option_fields()
		for key: String in fields:
			if config.has_section_key("sandbox", key):
				_select_meta(fields[key], config.get_value("sandbox", key))
		_filling = false
		_autoplay.button_pressed = config.get_value("sandbox", "autoplay", false)
		_reasons.button_pressed = config.get_value("sandbox", "reasons", false)
		_record.button_pressed = config.get_value("sandbox", "record", false)
		_reseed.button_pressed = config.get_value("sandbox", "reseed", true)
		_seed.value = config.get_value("sandbox", "seed", 1)
		_runs.value = config.get_value("sandbox", "runs", 50)
		_select_practice(config.get_value("practice", "encounter", &""), config.get_value("practice", "loadout", &""))
		_view = clampi(int(config.get_value("practice", "view", View.PRACTICE)), 0, 1) as View
	var encounter: EncounterDefinition = _registry.encounters.get(_meta(_encounter))
	_encounter_note.text = encounter.description if encounter != null else "Custom battle."
	_sync_practice_preferences()
	_update_practice_summary()


func _select_practice(encounter_id: StringName, loadout_id: StringName) -> void:
	for index in _practice_encounter.item_count:
		var encounter: EncounterDefinition = _practice_encounter.get_item_metadata(index)
		if encounter != null and encounter.id == encounter_id:
			_practice_encounter.select(index)
	for index in _practice_loadout.item_count:
		var loadout: PartyLoadout = _practice_loadout.get_item_metadata(index)
		if loadout != null and loadout.id == loadout_id:
			_practice_loadout.select(index)
