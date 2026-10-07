class_name CombatSandbox
extends Control
## Combat lab for design and tuning (GDD "CombatSandbox"). Pick an encounter or build one, choose
## the loadout, battlefield conditions, difficulty, assist and execution mode, then fight it,
## restart instantly, or batch-simulate the exact same setup and read the report in-game.
## Choices persist in user://sandbox.cfg between sessions.

const PREFS_PATH := "user://sandbox.cfg"
const DRAWER_WIDTH := 470.0
const EXECUTION_MANUAL := -1
const KNOWLEDGE_FROM_SAVE := -1
const SIM_BATTLES_PER_FRAME := 2

var _registry: DefinitionRegistry
var _battle: BattleScene
var _battle_host: Control
var _drawer: PanelContainer
var _form: VBoxContainer
var _encounter_note: Label
var _status: Label
var _report: PanelContainer
var _report_text: RichTextLabel
var _start_button: Button
var _simulate_button: Button
var _simulating := false
var _filling := false

var _encounter: OptionButton
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
	_show_drawer(true)


## Runs before the embedded battle sees the key, so Escape closes the report or the drawer instead
## of opening the battle's pause menu. Back keys other than Escape stay free for text fields.
func _input(event: InputEvent) -> void:
	if _report.visible and (event.is_action_pressed(InputBindings.CANCEL) or event.is_action_pressed(InputBindings.MENU)):
		get_viewport().set_input_as_handled()
		_report.visible = false
	elif _drawer.visible and _battle != null and event.is_action_pressed(InputBindings.MENU):
		get_viewport().set_input_as_handled()
		_show_drawer(false)


# --- Running battles -----------------------------------------------------------------------------

func _start_battle() -> void:
	var setup := _make_setup(int(_seed.value))
	if setup == null:
		return
	_save_prefs()
	if _battle != null:
		_battle.queue_free()
	_battle = load(SceneRouter.BATTLE).instantiate() as BattleScene
	_battle.embedded = true
	_battle_host.add_child(_battle)
	_battle.add_toolbar_button("Setup", "Open the sandbox setup", func() -> void: _show_drawer(not _drawer.visible))
	_battle.add_toolbar_button("Restart", "Restart this battle (new seed if enabled)", _restart)
	_battle.restart_requested.connect(_restart)
	_battle.setup_requested.connect(func() -> void: _show_drawer(true))
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = _record.button_pressed
	launch.autoplay = _autoplay.button_pressed
	launch.simulated_execution = int(_meta(_execution))
	launch.show_ai_reasoning = _reasons.button_pressed
	_battle.start(launch)
	_show_drawer(false)


func _restart() -> void:
	if _reseed.button_pressed:
		_seed.value = randi_range(1, 99999)
	_start_battle()


func _simulate() -> void:
	if _simulating:
		return
	var setup := _make_setup(int(_seed.value))
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
		text = "[color=#9b978b]Execution is Manual: simulated with GOOD execution.[/color]\n\n" + text
	_report_text.text = text
	_report.visible = true
	_report.reset_size()
	_report.position = (size - _report.size) * 0.5


## Tables become "Metric: value" lines; headings become bold; warnings turn red.
static func _markdown_to_bbcode(markdown: String) -> String:
	var lines := PackedStringArray()
	for line in markdown.split("\n"):
		if line.begins_with("### "):
			lines.append("[b][color=#d8b45a]%s[/color][/b]" % line.substr(4))
		elif line.begins_with("|---") or line.begins_with("| Metric"):
			continue
		elif line.begins_with("| "):
			var cells := line.trim_prefix("| ").trim_suffix(" |").split(" | ")
			lines.append("%s: [b]%s[/b]" % [cells[0], cells[1] if cells.size() > 1 else ""])
		elif line.begins_with("- ⚠"):
			lines.append("[color=#d65a43]%s[/color]" % line.substr(2))
		else:
			lines.append(line)
	return "\n".join(lines)


func _next_frame() -> void:
	var tween := create_tween()
	tween.tween_interval(0.001)
	await tween.finished


# --- Building the battle from the form -----------------------------------------------------------

func _make_setup(battle_seed: int) -> BattleSetup:
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
	custom.group = "Sandbox"
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


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Battlefield.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color(1, 1, 1, 0.5)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := Label.new()
	hint.text = "COMBAT SANDBOX\nConfigure a battle on the left and press Start."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.offset_left = DRAWER_WIDTH
	_battle_host = Control.new()
	_battle_host.name = "BattleHost"
	add_child(_battle_host)
	_battle_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_drawer = PanelContainer.new()
	_drawer.name = "Drawer"
	_drawer.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.97), UITheme.ACCENT.darkened(0.4), 1, 0, 10))
	add_child(_drawer)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_drawer.offset_right = DRAWER_WIDTH
	var column := VBoxContainer.new()
	_drawer.add_child(column)
	var title := Label.new()
	title.text = "Combat Sandbox"
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.add_theme_font_size_override("font_size", UITheme.font_size(1.35))
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	scroll.add_child(_form)
	_build_form()
	_status = Label.new()
	_status.add_theme_color_override("font_color", UITheme.DANGER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_start_button = _button(buttons, "Start battle", _start_battle)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_simulate_button = _button(buttons, "Simulate", _simulate)
	_runs = SpinBox.new()
	_runs.min_value = 10
	_runs.max_value = 500
	_runs.step = 10
	_runs.value = 50
	_runs.tooltip_text = "Battles per simulation batch"
	buttons.add_child(_runs)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_button(footer, "Hide", func() -> void: _show_drawer(false)).tooltip_text = "Back to the battle"
	_button(footer, "Main menu", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))

	_build_report_popup()


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
	_encounter_note = Label.new()
	_encounter_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_encounter_note.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_encounter_note.add_theme_font_size_override("font_size", UITheme.font_size(0.8))
	_form.add_child(_encounter_note)
	var enemy_entries: Array = [["—", &""]]
	for id in _registry.sorted_ids(_registry.enemies):
		var enemy := _registry.enemies[id]
		var tier := "" if enemy.tier == Enums.EnemyTier.NORMAL else " (%s)" % UnitInfo.TIER_WORDS[enemy.tier]
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
	_reasons = _check_row("Show AI reasoning", "Enemy intent tooltips and the log explain why each move was chosen.")
	_record = _check_row("Record progress", "Bestiary research and weapon mastery are written to the current save.")
	_seed = SpinBox.new()
	_seed.min_value = 1
	_seed.max_value = 99999
	_seed.value = 1
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row("Seed", _seed, "Same seed + same inputs = same battle.")
	_reseed = _check_row("New seed on restart", "")
	_reseed.button_pressed = true


func _build_report_popup() -> void:
	_report = PanelContainer.new()
	_report.name = "Report"
	_report.visible = false
	_report.custom_minimum_size = Vector2(820, 560)
	add_child(_report)
	var box := VBoxContainer.new()
	_report.add_child(box)
	_report_text = RichTextLabel.new()
	_report_text.bbcode_enabled = true
	_report_text.scroll_active = true
	_report_text.selection_enabled = true
	_report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report_text.add_theme_font_size_override("normal_font_size", UITheme.font_size(0.85))
	_report_text.add_theme_font_size_override("bold_font_size", UITheme.font_size(0.9))
	box.add_child(_report_text)
	var close := _button(box, "Close", func() -> void: _report.visible = false)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(160, 32)


func _show_drawer(open: bool) -> void:
	_drawer.visible = open or _battle == null
	if _drawer.visible:
		_start_button.grab_focus.call_deferred()


func _section(title: String) -> void:
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_color_override("font_color", UITheme.ACCENT)
	label.add_theme_font_size_override("font_size", UITheme.font_size(0.8))
	_form.add_child(label)


func _row(label_text: String, control: Control, tooltip: String = "") -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
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
	button.custom_minimum_size = Vector2(0, 32)
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
	var fields := _option_fields()
	for key: String in fields:
		config.set_value("sandbox", key, _meta(fields[key]))
	config.set_value("sandbox", "autoplay", _autoplay.button_pressed)
	config.set_value("sandbox", "reasons", _reasons.button_pressed)
	config.set_value("sandbox", "record", _record.button_pressed)
	config.set_value("sandbox", "reseed", _reseed.button_pressed)
	config.set_value("sandbox", "seed", int(_seed.value))
	config.set_value("sandbox", "runs", int(_runs.value))
	config.save(PREFS_PATH)


func _load_prefs() -> void:
	# Defaults first: the first preset encounter and loadout, the player's own settings.
	_select_meta(_encounter, _registry.defaults.practice_encounter.id)
	_on_encounter_selected(_encounter.selected)
	_select_meta(_loadout, _registry.defaults.starter_loadout.id)
	_on_loadout_selected(_loadout.selected)
	_select_meta(_difficulty, int(Settings.data.tactical_difficulty))
	_select_meta(_assist, int(Settings.data.execution_assist))
	_select_meta(_knowledge, KNOWLEDGE_FROM_SAVE)
	_select_meta(_execution, EXECUTION_MANUAL)
	var config := ConfigFile.new()
	if config.load(PREFS_PATH) != OK:
		return
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
	var encounter: EncounterDefinition = _registry.encounters.get(_meta(_encounter))
	_encounter_note.text = encounter.description if encounter != null else "Custom battle."
