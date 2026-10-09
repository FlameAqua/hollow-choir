class_name WorldHost
extends Node
## V0.4 exploration host. Owns input modes, the current area, the player, the HUD/modal readouts
## and the battle seam. Rules live in WorldRules and save boundaries in WorldSession; this node
## only routes input and presents their answers.
##
## Modes: EXPLORE (movement + interaction), MODAL (a world modal owns input; movement released),
## BATTLE (an embedded BattleScene owns input), BUSY (a transition or write is in progress).
## Any return to EXPLORE first blocks every world/confirm/cancel input still held, so the press
## that closed a modal, crossed a portal or ended a battle cannot act again until released.

signal area_loaded(area_id: StringName)
signal mode_changed(mode: Mode)
signal modal_opened(modal: WorldModal)

enum Mode { EXPLORE, MODAL, BATTLE, BUSY }

const ENCOUNTER_REARM := 24.0
const GATED_ACTIONS: Array[StringName] = [InputBindings.WORLD_UP, InputBindings.WORLD_DOWN, InputBindings.WORLD_LEFT,
	InputBindings.WORLD_RIGHT, InputBindings.WORLD_INTERACT, InputBindings.WORLD_MAP, InputBindings.WORLD_MENU,
	InputBindings.CONFIRM, InputBindings.CANCEL, InputBindings.MENU]

## Set before the node enters the tree to inject a session (tests use a failing or in-memory writer).
var session: WorldSession
var definition: WorldDefinition
var mode: Mode = Mode.BUSY
var area_def: AreaDefinition
var area: WorldArea
var player: WorldPlayer
var hud: ExplorationHUD
var modal: WorldModal
var battle: BattleScene
## Tests drive movement through this instead of the input map when set (Vector2.INF = off).
var scripted_move := Vector2.INF
var show_collision := false
## Capture fixtures run in a hidden window that never has OS focus; they turn this off.
var pause_on_focus_loss := true

var _world_root: Node2D
var _hud_layer: CanvasLayer
var _battle_layer: CanvasLayer
var _modal_layer: CanvasLayer
var _modal_root: Control
var _overlay: Control
var _held_block: Dictionary = {}
var _portals_armed := false
var _armed_sites: Dictionary = {}
var _prompt_target: StringName = &""
var _readout := ExplorationReadout.new()
var _encounter_position := Vector2.INF
var _encounter_facing: StringName = &"south"


func _ready() -> void:
	GameState.resume_session()
	if session == null:
		session = WorldSession.new()
	definition = session.definition
	for arg in OS.get_cmdline_user_args():
		if arg == "--world-collision":
			show_collision = true
	_build()
	EventBus.settings_changed.connect(_apply_theme)
	EventBus.settings_changed.connect(_refresh_hud)
	# Reduce Motion changed in the paused menu's Settings applies at once, not at the next area.
	EventBus.settings_changed.connect(_apply_motion_setting)
	EventBus.input_device_changed.connect(_refresh_hud)
	session.open()
	AudioManager.request_music(&"")
	load_area(session.world().area, session.world().anchor)


# --- Areas ---------------------------------------------------------------------------------------

## Replaces the current area and places the player at a named safe anchor (invalid → area default).
func load_area(area_id: StringName, anchor_id: StringName) -> void:
	var next := definition.area(area_id)
	if next == null:
		next = definition.area(definition.start_area)
		anchor_id = definition.start_anchor
	if area == null or area_def != next:
		if area != null:
			if player.get_parent() == area.depth_layer():
				area.depth_layer().remove_child(player)
			_world_root.remove_child(area)
			area.queue_free()
		area_def = next
		area = (load(next.scene_path) as PackedScene).instantiate() as WorldArea
		_world_root.add_child(area)
		area.collision_layer_node().visible = show_collision
		area.depth_layer().add_child(player)
		player.set_bounds(next.pixel_size(definition.tile_size))
		_apply_motion_setting()
	if not area.has_anchor(anchor_id):
		anchor_id = next.default_anchor
	area.apply_state(session.world())
	player.place(area.anchor(anchor_id))
	if next.landmark(anchor_id) != null:
		session.world().discover(anchor_id)
	_arm_triggers()
	_discover()
	AudioManager.request_music(next.music_cue)
	_set_mode(Mode.EXPLORE)
	area_loaded.emit(next.id)


## Portals and encounter cards fire only once the feet have left them; arm them from where the
## feet stand now (after a load, or after victory returns Hollow to the engagement spot).
func _arm_triggers() -> void:
	_portals_armed = area.portal_at(player.position) == &""
	_armed_sites.clear()
	for site in area_def.landmarks:
		if site.kind == LandmarkDefinition.Kind.ENCOUNTER:
			_armed_sites[site.id] = player.position.distance_to(area.point(site.id)) > site.interact_radius


func _apply_motion_setting() -> void:
	if area == null:
		return
	# Optional breathing (NPC/enemy idles) holds its first frame under reduced motion; walking stays.
	for sprite in area.find_children("*", "AnimatedSprite2D", true, false):
		var animated := sprite as AnimatedSprite2D
		if Settings.data.reduce_motion:
			animated.stop()
			animated.frame = 0
		else:
			animated.play()


# --- Frame loop ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_release_held()
	if mode != Mode.EXPLORE or player == null:
		return
	player.step(move_vector(), delta)
	_after_move()


## The gated eight-direction input (held inputs from a previous context read as zero).
func move_vector() -> Vector2:
	if scripted_move != Vector2.INF:
		return scripted_move.limit_length(1.0)
	var x := _strength(InputBindings.WORLD_RIGHT) - _strength(InputBindings.WORLD_LEFT)
	var y := _strength(InputBindings.WORLD_DOWN) - _strength(InputBindings.WORLD_UP)
	return Vector2(x, y).limit_length(1.0)


func _strength(action: StringName) -> float:
	return 0.0 if _held_block.has(action) else Input.get_action_strength(action)


func _after_move() -> void:
	var feet := player.position
	var portal_id := area.portal_at(feet)
	if portal_id == &"":
		_portals_armed = true
	elif _portals_armed:
		take_portal(portal_id)
		return
	_discover()
	for site in area_def.landmarks:
		if site.kind != LandmarkDefinition.Kind.ENCOUNTER or session.world().is_cleared(site.id):
			continue
		var distance := feet.distance_to(area.point(site.id))
		if distance <= site.interact_radius:
			if _armed_sites.get(site.id, false):
				_armed_sites[site.id] = false
				open_encounter_card(site)
				return
		elif distance > site.interact_radius + ENCOUNTER_REARM:
			_armed_sites[site.id] = true
	_refresh_hud()


## Approaching a landmark discovers it; walking a link records it (map knowledge, saved at the
## next safe boundary). A gated link stays undrawn until its flag is set.
func _discover() -> void:
	var world := session.world()
	var feet := player.position
	for landmark in area_def.landmarks:
		if not world.is_discovered(landmark.id) and feet.distance_to(area.point(landmark.id)) <= landmark.discover_radius:
			world.discover(landmark.id)
	for path in area_def.paths:
		if world.links.has(path.id) or (path.requires_flag != &"" and not world.flag(path.requires_flag)):
			continue
		if path.distance_to(feet, definition.tile_size) <= path.width_tiles * definition.tile_size * 0.5:
			world.add_link(path.id)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.MODAL and modal != null and modal.kind == &"map" and _fresh(event, InputBindings.WORLD_MAP):
		get_viewport().set_input_as_handled()
		_close_modal()
		return
	if mode != Mode.EXPLORE:
		return
	if _fresh(event, InputBindings.WORLD_INTERACT):
		get_viewport().set_input_as_handled()
		interact()
	elif _fresh(event, InputBindings.WORLD_MAP):
		get_viewport().set_input_as_handled()
		open_map()
	elif _fresh(event, InputBindings.WORLD_MENU):
		get_viewport().set_input_as_handled()
		open_menu()


func _fresh(event: InputEvent, action: StringName) -> bool:
	return event.is_action_pressed(action, false) and not _held_block.has(action)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and mode == Mode.EXPLORE 			and pause_on_focus_loss:
		open_menu()


func _release_held() -> void:
	for action: StringName in _held_block.keys():
		if not Input.is_action_pressed(action):
			_held_block.erase(action)


func _block_held() -> void:
	for action in GATED_ACTIONS:
		if Input.is_action_pressed(action):
			_held_block[action] = true


func is_blocked(action: StringName) -> bool:
	return _held_block.has(action)


func _set_mode(next: Mode) -> void:
	if next == Mode.EXPLORE:
		_block_held()
		# A focused HUD button would take Confirm before the world can read it.
		if is_inside_tree():
			get_viewport().gui_release_focus()
	if next != Mode.EXPLORE and player != null:
		player.stop()
	mode = next
	_refresh_hud()
	mode_changed.emit(next)


# --- Interaction ---------------------------------------------------------------------------------

## The nearest eligible landmark within its radius (ties by stable ID), or null.
func interaction_target() -> LandmarkDefinition:
	var best: LandmarkDefinition
	var best_distance := INF
	for landmark in area_def.landmarks:
		if landmark.interact_radius <= 0.0:
			continue
		var at := area.point(landmark.id)
		var distance := player.position.distance_to(at)
		if distance > landmark.interact_radius:
			continue
		if WorldRules.interaction_label(landmark, session.world(), _far_side(landmark)).is_empty():
			continue
		if distance < best_distance - 0.01 or (absf(distance - best_distance) <= 0.01 and String(landmark.id) < String(best.id)):
			best = landmark
			best_distance = distance
	return best


func _far_side(landmark: LandmarkDefinition) -> bool:
	return WorldRules.on_far_side(landmark, area.point(landmark.id), player.position)


func interact() -> void:
	var target := interaction_target()
	if target == null:
		return
	match target.kind:
		LandmarkDefinition.Kind.ENCOUNTER:
			open_encounter_card(target)
		LandmarkDefinition.Kind.PREPARATION:
			open_bench(target)
		_:
			open_dialogue(target)


func open_dialogue(landmark: LandmarkDefinition) -> void:
	var far := _far_side(landmark)
	var readout := WorldRules.dialogue(landmark, session.world(), far)
	if readout == null:
		return
	var view := _open_modal(WorldModal.make(&"dialogue", readout.speaker, readout.paragraphs, readout.actions))
	view.cancel_id = WorldRules.ACT_LEAVE
	view.chosen.connect(func(id: StringName) -> void: _on_dialogue_action(landmark, id))


func _on_dialogue_action(landmark: LandmarkDefinition, id: StringName) -> void:
	match id:
		WorldRules.ACT_RING:
			_commit(func() -> Error: return session.restore_bell(area_def.id), func() -> void:
				area.apply_state(session.world())
				open_dialogue(landmark))
		WorldRules.ACT_OPEN_LATCH:
			if not _far_side(landmark):
				_close_modal()
				return
			_commit(func() -> Error: return session.open_latch(area_def.id, &"short_return"), func() -> void:
				area.apply_state(session.world())
				_close_modal())
		_:
			_commit(func() -> Error: return session.complete_interaction(area_def.id, landmark.id), _close_modal)


func open_encounter_card(site: LandmarkDefinition) -> void:
	var card := WorldRules.encounter_card(site, GameState.progress)
	var view := _open_modal(WorldEncounterView.make(card))
	view.cancel_id = WorldRules.ACT_LEAVE
	view.chosen.connect(func(id: StringName) -> void:
		if id == WorldRules.ACT_ENGAGE:
			engage(site)
		else:
			_close_modal())


func open_bench(landmark: LandmarkDefinition) -> void:
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 310
	list.add_theme_constant_override("separation", 10)
	content.add_child(list)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG, UITheme.BORDER, 1, 0, 16))
	content.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "WeaponScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	var details := WorldWeaponDetails.new()
	details.name = "WeaponDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(details)
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(WorldRules.ACT_LEAVE, WorldCopy.ACTION_CLOSE)]
	var view := WorldModal.make(&"bench", landmark.display_name, PackedStringArray(), actions, content)
	var weapons := WorldRules.bench_weapons(GameState.progress)
	for weapon in weapons:
		var button := Button.new()
		button.name = "Weapon_" + String(weapon.id)
		button.custom_minimum_size = Vector2(0, 52)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(button)
		button.focus_entered.connect(func() -> void:
			details.present(weapon, GameState.progress.loadout_weapon == weapon.id)
			detail_scroll.scroll_vertical = 0)
		button.mouse_entered.connect(func() -> void:
			details.present(weapon, GameState.progress.loadout_weapon == weapon.id)
			detail_scroll.scroll_vertical = 0)
		button.pressed.connect(func() -> void:
			details.present(weapon, GameState.progress.loadout_weapon == weapon.id)
			_commit(func() -> Error: return session.choose_weapon(weapon.id), func() -> void:
				_show_bench_choice(landmark, weapon)))
	var rule_row := HBoxContainer.new()
	rule_row.add_theme_constant_override("separation", 10)
	rule_row.add_child(CombatIcons.image("heart", 28))
	var recovery := UITheme.label("Party restored\nbetween encounters", UITheme.TEXT_DIM, 22, true)
	recovery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_row.add_child(recovery)
	list.add_child(rule_row)
	_label_bench(view)
	for weapon in weapons:
		if weapon.id == GameState.progress.loadout_weapon:
			details.present(weapon, true)
	_open_modal(view)
	view.cancel_id = WorldRules.ACT_LEAVE
	view.chosen.connect(func(_id: StringName) -> void:
		_commit(func() -> Error: return session.complete_interaction(area_def.id, landmark.id), _close_modal))
	WorldModal.focus_later(view.find_child("Weapon_" + String(GameState.progress.loadout_weapon), true, false) as Button)


## After a saved bench choice. A failed write replaced the bench with the save-failure card, so a
## later successful retry reopens it; the callback holds only resources, never freed controls.
func _show_bench_choice(landmark: LandmarkDefinition, weapon: WeaponDefinition) -> void:
	if modal == null or modal.kind != &"bench":
		open_bench(landmark)
	_label_bench(modal)
	(modal.find_child("WeaponDetails", true, false) as WorldWeaponDetails).present(weapon, true)
	WorldModal.focus_later(modal.find_child("Weapon_" + String(weapon.id), true, false) as Button)


func _label_bench(view: Control) -> void:
	for weapon in WorldRules.bench_weapons(GameState.progress):
		var button := view.find_child("Weapon_" + String(weapon.id), true, false) as Button
		if button != null:
			var equipped := GameState.progress.loadout_weapon == weapon.id
			button.text = weapon.display_name
			button.icon = load("res://assets/art/global/ui/world/equipped.svg") if equipped else CombatIcons.texture(CombatIcons.mapping("player_actions", weapon.basic_attack.id, "action_slash"))
			button.toggle_mode = true
			button.set_pressed_no_signal(equipped)


## Static weapon facts: family, damage type and the actions it brings (shared definitions).
func _weapon_text(weapon: WeaponDefinition) -> String:
	var lines := PackedStringArray(["%s · %s" % [Enums.WeaponFamily.keys()[weapon.family].capitalize(),
		EnumText.damage_type(weapon.damage_type)]])
	if not weapon.description.is_empty():
		lines.append(weapon.description)
	var actions: Array[ActionDefinition] = []
	if weapon.basic_attack != null:
		actions.append(weapon.basic_attack)
	actions.append_array(weapon.techniques)
	for action in actions:
		lines.append("%s — %s" % [action.display_name, action.description])
	return "\n".join(lines)


func open_map() -> void:
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	var chart := VBoxContainer.new()
	chart.add_theme_constant_override("separation", 10)
	content.add_child(chart)
	var view := WorldMapView.new()
	view.name = "MapView"
	view.custom_minimum_size = Vector2(600, 340)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.add_child(view)
	chart.add_child(UITheme.label(WorldCopy.MAP_LEGEND, UITheme.TEXT_DIM, -1, true))
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 384
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	content.add_child(side)
	side.add_child(UITheme.heading("Discovered places"))
	var places_scroll := ScrollContainer.new()
	places_scroll.name = "PlacesScroll"
	places_scroll.custom_minimum_size.y = 224
	places_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	places_scroll.follow_focus = true
	side.add_child(places_scroll)
	var places := VBoxContainer.new()
	places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	places.add_theme_constant_override("separation", 6)
	places_scroll.add_child(places)
	var readout := map_readout()
	view.show_readout(readout)
	var description := UITheme.label("", UITheme.TEXT, UITheme.secondary_size(), true)
	description.name = "PlaceDescription"
	description.custom_minimum_size.y = 96
	var first: Button
	for index in readout.landmarks.size():
		var landmark: Dictionary = readout.landmarks[index]
		var button := Button.new()
		button.name = "Place%d" % index
		button.text = "%d  %s" % [index + 1, landmark.label]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = UITheme.control_height()
		button.focus_entered.connect(func() -> void:
			view.select(index)
			description.text = String(landmark.description))
		button.pressed.connect(func() -> void:
			view.select(index)
			description.text = String(landmark.description))
		places.add_child(button)
		first = first if first != null else button
	if readout.landmarks.is_empty():
		description.text = WorldCopy.MAP_EMPTY
	side.add_child(description)
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(WorldRules.ACT_LEAVE, "Back")]
	var modal_view := _open_modal(WorldModal.make(&"map", readout.area_name, PackedStringArray(), actions, content, 940))
	modal_view.cancel_id = WorldRules.ACT_LEAVE
	modal_view.toggle_action = InputBindings.WORLD_MAP
	modal_view.chosen.connect(func(_id: StringName) -> void: _close_modal())
	if first != null:
		WorldModal.focus_later(first)


func map_readout() -> WorldMapReadout:
	return WorldRules.map_readout(area_def, session.world(), definition.tile_size, player.position, area.landmark_positions())


func open_menu() -> void:
	var actions: Array[Dictionary] = [
		WorldDialogueReadout.action(&"resume", "Resume"),
		WorldDialogueReadout.action(&"field_guide", "Field Guide"),
		WorldDialogueReadout.action(&"settings", "Settings"),
		WorldDialogueReadout.action(&"help", "Help"),
		WorldDialogueReadout.action(&"save", "Save"),
		WorldDialogueReadout.action(&"reset", WorldCopy.ACTION_RESET),
		WorldDialogueReadout.action(&"title", "Save and return to title"),
	]
	var view := _open_modal(WorldModal.make(&"menu", "Paused", PackedStringArray(), actions))
	view.cancel_id = &"resume"
	view.toggle_action = InputBindings.WORLD_MENU
	view.chosen.connect(_on_menu_action)


func _on_menu_action(id: StringName) -> void:
	match id:
		&"field_guide":
			_open_screen(load(SceneRouter.FIELD_GUIDE).instantiate())
		&"settings":
			_open_screen(load(SceneRouter.SETTINGS).instantiate())
		&"help":
			var help_view := _open_modal(WorldModal.make(&"help", "Journey help", WorldCopy.SAVE_NOTE.split("\n\n"),
				[WorldDialogueReadout.action(&"back", "Back")]))
			help_view.cancel_id = &"back"
			help_view.chosen.connect(func(_action: StringName) -> void: open_menu())
		&"save":
			_commit(session.save, func() -> void:
				open_menu()
				modal.set_status("Saved."))
		&"reset":
			_confirm_reset()
		&"title":
			_commit(session.save, func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
		_:
			_close_modal()


## Menu → Reset journey asks first, with Cancel focused. Only a confirmation made on this live card,
## with no battle in progress, writes; a failed write keeps the journey and offers Retry save.
func _confirm_reset() -> void:
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(&"cancel", WorldCopy.ACTION_CANCEL),
		WorldDialogueReadout.action(&"reset", WorldCopy.ACTION_RESET)]
	var view := _open_modal(WorldModal.make(&"reset", WorldCopy.RESET_TITLE, PackedStringArray([WorldCopy.RESET_BODY]), actions))
	view.cancel_id = &"cancel"
	view.chosen.connect(func(id: StringName) -> void:
		if id != &"reset":
			open_menu()
		elif modal == view and battle == null:
			_commit(session.reset_journey, _restart_journey))


## After a successful reset write: the fresh journey at the start anchor, as on a first visit.
func _restart_journey() -> void:
	_dismiss_modal()
	_encounter_position = Vector2.INF
	_fade()
	load_area(definition.start_area, definition.start_anchor)


## Field Guide / Settings over the paused world; closing returns to the menu, not the title.
func _open_screen(screen: Control) -> void:
	_dismiss_modal()
	screen.set("embedded", true)
	_modal_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_mode(Mode.MODAL)
	screen.connect(&"closed", func() -> void:
		screen.queue_free()
		open_menu())


# --- Portals -------------------------------------------------------------------------------------

func take_portal(landmark_id: StringName) -> void:
	var portal := definition.portal_from(area_def.id, landmark_id)
	if portal == null:
		return
	_set_mode(Mode.BUSY)
	_commit(func() -> Error: return session.arrive(portal.to_area, portal.arrival_anchor), func() -> void:
		_fade()
		load_area(portal.to_area, portal.arrival_anchor))


func _fade() -> void:
	_overlay.modulate.a = 1.0
	_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _overlay.visible = false)


# --- Battles -------------------------------------------------------------------------------------

## Engage: capture and save exactly one entry, then hand input to the battle. Never twice.
func engage(site: LandmarkDefinition) -> void:
	if mode == Mode.BATTLE or battle != null:
		return
	_encounter_position = player.position
	_encounter_facing = player.facing
	_dismiss_modal()
	_set_mode(Mode.BUSY)
	var entry := session.begin_entry(site.id, site.id)
	if entry == null:
		if session.last_error == ERR_UNAVAILABLE:
			_set_mode(Mode.EXPLORE)
		else:
			_show_save_failure(func() -> void: engage(site))
		return
	launch_battle(entry)


func launch_battle(entry: EncounterEntry) -> void:
	var setup := entry.build_setup(Database.registry, Database.library)
	if setup == null:
		push_error("WorldHost: encounter %s cannot be built" % entry.encounter_id())
		_set_mode(Mode.EXPLORE)
		return
	var launch := BattleLaunch.make(setup, "")
	launch.record_progress = false
	battle = load(SceneRouter.BATTLE).instantiate() as BattleScene
	battle.embedded = true
	battle.host_result = true
	battle.leave_text = WorldCopy.LEAVE_BATTLE
	_battle_layer.add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.apply_battle_theme()
	battle.finished.connect(func(result: BattleResult) -> void: _on_battle_finished(entry, result))
	battle.setup_requested.connect(func() -> void: _on_battle_left(entry))
	_world_root.visible = false
	_hud_layer.visible = false
	_set_mode(Mode.BATTLE)
	battle.start(launch)


func _on_battle_finished(entry: EncounterEntry, result: BattleResult) -> void:
	if result.is_victory():
		_commit_victory(entry, result)
		return
	var actions: Array[Dictionary] = [
		WorldDialogueReadout.action(&"retry", WorldCopy.ACTION_RETRY_ENCOUNTER),
		WorldDialogueReadout.action(&"home", WorldCopy.ACTION_RETURN_HOME)]
	var view := _open_modal(WorldModal.make(&"defeat", EnumText.outcome(result.outcome), PackedStringArray([WorldCopy.DEFEAT_BODY]), actions))
	view.chosen.connect(func(id: StringName) -> void:
		if id == &"retry":
			_dismiss_modal()
			_close_battle()
			launch_battle(entry)
		else:
			_commit(func() -> Error: return session.return_home(entry), func() -> void:
				_dismiss_modal()
				_close_battle()
				load_area(definition.start_area, definition.start_anchor)))


func _commit_victory(entry: EncounterEntry, result: BattleResult) -> void:
	var before := {}
	for enemy_id: StringName in result.research:
		before[enemy_id] = GameState.research_level(enemy_id)
	var err := session.commit_victory(entry, result)
	if err != OK and err != ERR_ALREADY_EXISTS:
		_show_save_failure(func() -> void: _commit_victory(entry, result))
		return
	var lines := PackedStringArray([WorldCopy.VICTORY_BODY])
	for enemy_id: StringName in before:
		var after := GameState.research_level(enemy_id)
		if after > before[enemy_id]:
			var enemy: EnemyDefinition = Database.registry.enemies.get(enemy_id)
			lines.append("Bestiary: %s → %s" % [enemy.display_name if enemy != null else "?", EnumText.research_level(after)])
	_close_battle()
	area.apply_state(session.world())
	load_area(entry.area_id(), entry.approach_anchor())
	if _encounter_position != Vector2.INF:
		player.place(_encounter_position, _encounter_facing)
		_arm_triggers()
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(&"continue", WorldCopy.ACTION_CONTINUE)]
	var view := _open_modal(WorldModal.make(&"victory", "Victory", lines, actions))
	view.cancel_id = &"continue"
	view.chosen.connect(func(_id: StringName) -> void: _close_modal())


## Pause → Leave battle: back at the approach, encounter available, no attempt recorded.
func _on_battle_left(entry: EncounterEntry) -> void:
	_commit(func() -> Error: return session.leave_entry(entry), func() -> void:
		_dismiss_modal()
		_close_battle()
		load_area(entry.area_id(), entry.approach_anchor()))


func _close_battle() -> void:
	if battle != null:
		_battle_layer.remove_child(battle)
		battle.queue_free()
		battle = null
	_world_root.visible = true
	_hud_layer.visible = true
	AudioManager.request_music(area_def.music_cue if area_def != null else &"")


# --- Transactions and modals ---------------------------------------------------------------------

## Runs a session write; on success calls [param then], on failure keeps everything unpublished and
## offers Retry save / Return to title.
func _commit(write: Callable, then: Callable) -> void:
	var err: Error = write.call()
	if err == OK:
		then.call()
	elif err in [ERR_UNAVAILABLE, ERR_INVALID_PARAMETER, ERR_ALREADY_EXISTS]:
		_close_modal()
	else:
		_show_save_failure(func() -> void: _commit(write, then))


func _show_save_failure(retry: Callable) -> void:
	var actions: Array[Dictionary] = [
		WorldDialogueReadout.action(&"retry", WorldCopy.ACTION_RETRY_SAVE),
		WorldDialogueReadout.action(&"title", WorldCopy.ACTION_TITLE)]
	var view := _open_modal(WorldModal.make(&"save_failed", WorldCopy.SAVE_FAILED_TITLE,
		PackedStringArray([WorldCopy.SAVE_FAILED_BODY]), actions))
	view.chosen.connect(func(id: StringName) -> void:
		if id == &"retry":
			_dismiss_modal()
			retry.call()
		else:
			SceneRouter.goto(SceneRouter.MAIN_MENU))


func _open_modal(view: WorldModal) -> WorldModal:
	_dismiss_modal()
	modal = view
	_modal_root.add_child(view)
	_set_mode(Mode.MODAL)
	modal_opened.emit(view)
	return view


func _dismiss_modal() -> void:
	if modal != null:
		_modal_root.remove_child(modal)
		modal.queue_free()
		modal = null


func _close_modal() -> void:
	_dismiss_modal()
	if battle == null:
		_set_mode(Mode.EXPLORE)


# --- HUD -----------------------------------------------------------------------------------------

func readout() -> ExplorationReadout:
	return _readout


func _refresh_hud() -> void:
	if hud == null or area_def == null or player == null:
		return
	_readout.area_name = area_def.display_name
	_readout.objective = WorldRules.objective(session.world(), definition, area_def.id)
	var target := interaction_target() if mode == Mode.EXPLORE else null
	_prompt_target = target.id if target != null else &""
	_readout.interaction = WorldRules.interaction_label(target, session.world(), _far_side(target)) if target != null else ""
	_readout.interaction_binding = InputBindings.prompt(InputBindings.WORLD_INTERACT)
	hud.present(_readout)


## Controls under a CanvasLayer do not inherit the window theme; give each layer root the game theme.
func _apply_theme() -> void:
	var theme := get_tree().root.theme
	for control: Control in [hud, _modal_root]:
		if control != null:
			control.theme = theme
	if battle != null:
		battle.apply_battle_theme()


func _build() -> void:
	_world_root = Node2D.new()
	_world_root.name = "World"
	add_child(_world_root)
	player = WorldPlayer.new()
	player.footstep.connect(_play_footstep)
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "Interface"
	_hud_layer.layer = 5
	add_child(_hud_layer)
	hud = ExplorationHUD.new()
	hud.name = "ExplorationHUD"
	_hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.map_requested.connect(func() -> void:
		if mode == Mode.EXPLORE:
			open_map())
	hud.menu_requested.connect(func() -> void:
		if mode == Mode.EXPLORE:
			open_menu())
	_battle_layer = CanvasLayer.new()
	_battle_layer.name = "Battle"
	_battle_layer.layer = 10
	add_child(_battle_layer)
	_modal_layer = CanvasLayer.new()
	_modal_layer.name = "Modals"
	_modal_layer.layer = 15
	add_child(_modal_layer)
	_modal_root = Control.new()
	_modal_root.name = "ModalRoot"
	_modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.add_child(_modal_root)
	_modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.02, 0.02, 0.03)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_hud_layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()


func _play_footstep(at: Vector2) -> void:
	if mode != Mode.EXPLORE or area == null:
		return
	match area.surface_at(at):
		&"wood": AudioManager.play(AudioManager.Cue.STEP_WOOD, 0.08)
		&"stone": AudioManager.play(AudioManager.Cue.STEP_STONE, 0.08)
		_: AudioManager.play(AudioManager.Cue.STEP_PEAT, 0.08)
