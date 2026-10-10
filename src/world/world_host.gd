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
##
## Playtest revision: walking into a threat starts a three-second move-away countdown instead of an
## Engage card (EncounterCountdown; only its expiry calls engage()). The host also routes the quest
## journal, the familiar commands, brewing and crafting, and the victory's Bestiary Learnings. New
## view hooks are detected by the methods and signals a view defines, so an older view keeps working.
## The host plays no success sound: the session's adopted operation facts drive that elsewhere.

signal area_loaded(area_id: StringName)
signal mode_changed(mode: Mode)
signal modal_opened(modal: WorldModal)
## V0.5C: a rune strike was saved (presentation hook for feedback; the outcome is already true).
signal rune_struck(result: ExplorationResult)
## Playtest revision: the move-away countdown changed state (started, held, resumed, cancelled or
## expired). encounter_countdown() is current every physics frame for the remaining time.
signal encounter_countdown_changed(readout: EncounterCountdownReadout)

enum Mode { EXPLORE, MODAL, BATTLE, BUSY }

const ENCOUNTER_REARM := EncounterCountdown.REARM
## V0.5 shortcuts and the view each toggles (toggle_view).
const SHORTCUTS := {InputBindings.WORLD_MAP: &"map", InputBindings.WORLD_LOADOUT: &"loadout",
	InputBindings.WORLD_INVENTORY: &"inventory", InputBindings.WORLD_JOURNAL: &"journal",
	InputBindings.WORLD_FIELD_GUIDE: &"field_guide"}
const GATED_ACTIONS: Array[StringName] = [InputBindings.WORLD_UP, InputBindings.WORLD_DOWN, InputBindings.WORLD_LEFT,
	InputBindings.WORLD_RIGHT, InputBindings.WORLD_INTERACT, InputBindings.WORLD_SPRINT, InputBindings.WORLD_MAP,
	InputBindings.WORLD_LOADOUT, InputBindings.WORLD_INVENTORY, InputBindings.WORLD_JOURNAL, InputBindings.WORLD_FIELD_GUIDE,
	InputBindings.WORLD_MENU, InputBindings.CONFIRM, InputBindings.CANCEL, InputBindings.MENU]

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
## With scripted_move set, whether the sprint input counts as held.
var scripted_sprint := false
var show_collision := false
## Capture fixtures run in a hidden window that never has OS focus; they turn this off.
var pause_on_focus_loss := true
## Save and Quit runs this only after the save succeeded (tests replace it; default: quit the game).
var quit_game := func() -> void: get_tree().quit()
## Save and return to title runs this only after the save succeeded (tests replace it).
var leave_to_title := func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU)

var _world_root: Node2D
var _hud_layer: CanvasLayer
var _battle_layer: CanvasLayer
var _modal_layer: CanvasLayer
var _modal_root: Control
## The full-screen view opened over the world (Settings, the Field Guide), or null.
var _screen: Control
var _overlay: Control
var _held_block: Dictionary = {}
var _portals_armed := false
## The move-away countdown for this area's threats (pure state; the host only ticks it).
var countdown := EncounterCountdown.new()
var _countdown_readout := EncounterCountdownReadout.new()
## Bestiary Learnings of the victory card on screen (the session's own facts; empty otherwise).
var victory_learnings: Array[LearningReadout] = []
var _prompt_target: StringName = &""
var _readout := ExplorationReadout.new()
var _encounter_position := Vector2.INF
var _encounter_facing: StringName = &"south"
var notices: JourneyNotices


func _ready() -> void:
	GameState.resume_session()
	if session == null:
		session = WorldSession.new()
	definition = session.definition
	for arg in OS.get_cmdline_user_args():
		if arg == "--world-collision":
			show_collision = true
	_build()
	var notice_layer := CanvasLayer.new()
	notice_layer.layer = 80
	add_child(notice_layer)
	notices = JourneyNotices.new()
	notice_layer.add_child(notices)
	rune_struck.connect(_present_rune_strike)
	EventBus.settings_changed.connect(_apply_theme)
	EventBus.settings_changed.connect(_refresh_hud)
	# Reduce Motion changed in the paused menu's Settings applies at once, not at the next area.
	EventBus.settings_changed.connect(_apply_motion_setting)
	# D-009: a Tactical Difficulty change in Settings becomes the journey's at once (saved next commit).
	EventBus.settings_changed.connect(_follow_difficulty)
	EventBus.input_device_changed.connect(_refresh_hud)
	area_loaded.connect(func(area_id: StringName) -> void:
		SessionLog.event("world", "area %s at %s" % [area_id, player.position.round()]))
	modal_opened.connect(func(view: WorldModal) -> void: SessionLog.event("world", "opened %s" % view.kind))
	session.open()
	AudioManager.request_music(&"")
	load_area(session.world().area, session.world().anchor)
	_reconcile()


func _follow_difficulty() -> void:
	session.follow_difficulty(int(Settings.data.tactical_difficulty))


## World entry (V0.5A): catch-up rewards and loadout repair for an older save, in one write through
## the usual save-failure card (Retry save / Return to title). Usually there is nothing to write.
func _reconcile() -> void:
	_commit(session.reconcile, func() -> void:
		# A journey created this session announces its quest once, here; loading never does.
		if GameState.take_fresh_journey():
			session.announce_new_journey()
		if not _has_received(session.last_receipts):
			if modal == null and mode == Mode.MODAL:
				_set_mode(Mode.EXPLORE)
			return
		_show_rewards(&"catch_up", "Rewards from your journey", WorldCopy.REWARD_CATCH_UP, session.last_receipts,
			WorldCopy.REWARD_INVENTORY_NEXT))


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


## Portals and threat countdowns fire only once the feet have left them; arm them from where the
## feet stand now (after a load, or after victory returns Hollow to the engagement spot). Any
## running countdown is dropped: an area load never carries one over.
func _arm_triggers() -> void:
	_portals_armed = area.portal_at(player.position) == &""
	countdown.arm(_encounter_sites())
	_publish_countdown(true)


## Every uncleared encounter site of the current area with the feet's distance to it.
func _encounter_sites() -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	if area == null or area_def == null or player == null:
		return sites
	for site in area_def.landmarks:
		if site.kind == LandmarkDefinition.Kind.ENCOUNTER and not session.world().is_cleared(site.id):
			sites.append({"id": site.id, "distance": player.position.distance_to(area.point(site.id)),
				"radius": site.interact_radius})
	return sites


## The move-away countdown as the world indicator shows it (current every physics frame).
func encounter_countdown() -> EncounterCountdownReadout:
	return _countdown_readout


## Advances the countdown one frame. [param frozen]: exploration is not running (a modal, a pause,
## a lost focus, a transition), so the remaining time is held, never reset. Expiry calls engage(),
## as Interact at the threat does without waiting.
func _tick_countdown(delta: float, frozen: bool) -> void:
	var state := countdown.state
	var owner_id := countdown.site_id
	var expired := countdown.update(delta, _encounter_sites(), frozen)
	_publish_countdown(countdown.state != state or countdown.site_id != owner_id)
	if expired == &"":
		return
	var found := definition.find_landmark(expired)
	if not found.is_empty():
		engage(found[1])


## Rebuilds the public readout. [param changed]: the state changed, so listeners are told; while a
## countdown is active the HUD also receives every frame for a smooth indicator.
func _publish_countdown(changed: bool) -> void:
	if not changed and not countdown.active():
		return
	var readout := EncounterCountdownReadout.new()
	readout.state = countdown.state
	readout.active = countdown.active()
	readout.frozen = countdown.state == EncounterCountdown.State.FROZEN
	readout.threat_id = countdown.site_id
	readout.remaining = countdown.remaining
	readout.duration = countdown.duration
	var site := area_def.landmark(countdown.site_id) if area_def != null and countdown.site_id != &"" else null
	readout.threat_label = site.threat_label if site != null else ""
	_countdown_readout = readout
	if changed:
		encounter_countdown_changed.emit(readout)
	if hud != null:
		hud.present_countdown(readout)


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
	if player == null or area == null:
		return
	if mode != Mode.EXPLORE:
		# A modal, a pause or a transition holds the countdown where it is.
		if countdown.active():
			_tick_countdown(delta, true)
		return
	player.step(move_vector(), delta, sprint_held())
	_after_move(delta)


## The gated eight-direction input (held inputs from a previous context read as zero).
func move_vector() -> Vector2:
	if scripted_move != Vector2.INF:
		return scripted_move.limit_length(1.0)
	var x := _strength(InputBindings.WORLD_RIGHT) - _strength(InputBindings.WORLD_LEFT)
	var y := _strength(InputBindings.WORLD_DOWN) - _strength(InputBindings.WORLD_UP)
	return Vector2(x, y).limit_length(1.0)


## The gated sprint input (held from a previous context, it reads as released).
func sprint_held() -> bool:
	if scripted_move != Vector2.INF:
		return scripted_sprint
	return _strength(InputBindings.WORLD_SPRINT) > 0.5


func _strength(action: StringName) -> float:
	return 0.0 if _held_block.has(action) else Input.get_action_strength(action)


func _after_move(delta: float = 0.0) -> void:
	var feet := player.position
	var portal_id := area.portal_at(feet)
	if portal_id == &"":
		_portals_armed = true
	elif _portals_armed:
		take_portal(portal_id)
		return
	_discover()
	# Entering an armed threat's radius starts its countdown; leaving cancels it; expiry engages.
	_tick_countdown(delta, false)
	if mode == Mode.EXPLORE:
		_refresh_hud()


## Approaching a landmark discovers it; walking a link records it (map knowledge, saved at the
## next safe boundary). A gated link stays undrawn until its flag is set.
func _discover() -> void:
	var world := session.world()
	var feet := player.position
	for landmark in area_def.landmarks:
		if not world.is_discovered(landmark.id) and feet.distance_to(area.point(landmark.id)) <= landmark.discover_radius \
				and WorldRules.perceivable(landmark, world, definition):
			world.discover(landmark.id)
	for path in area_def.paths:
		if world.links.has(path.id) or (path.requires_flag != &"" and not world.flag(path.requires_flag)):
			continue
		if path.distance_to(feet, definition.tile_size) <= path.width_tiles * definition.tile_size * 0.5:
			world.add_link(path.id)


func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in SHORTCUTS:
		if _fresh(event, action):
			if toggle_view(SHORTCUTS[action]):
				get_viewport().set_input_as_handled()
			return
	if mode != Mode.EXPLORE:
		return
	if _fresh(event, InputBindings.WORLD_INTERACT):
		get_viewport().set_input_as_handled()
		interact()
	elif _fresh(event, InputBindings.WORLD_MENU):
		get_viewport().set_input_as_handled()
		open_menu()


## The shortcut view on screen: &"map", &"loadout", &"inventory", &"journal" or &"field_guide";
## &"" while exploring with nothing open; &"other" for anything else (a station, dialogue, the menu,
## a reward or save-failure card, a battle, a transition), which shortcuts leave alone.
func shortcut_view() -> StringName:
	if mode == Mode.EXPLORE:
		return &""
	if mode != Mode.MODAL:
		return &"other"
	if is_instance_valid(_screen):
		return &"field_guide" if _screen is FieldGuide else &"other"
	if modal == null:
		return &"other"
	match modal.kind:
		&"map", &"journal":
			return modal.kind
		&"character", &"inventory":
			var character := modal.find_child("Character", true, false) as WorldCharacterView
			if character != null and session.station() == &"":
				return &"inventory" if character.selected_tab == &"inventory" else &"loadout"
	return &"other"


## A shortcut for [param view]: opens it from exploration, closes it when it is already on screen
## (through the view's own Back, so a view opened from the menu returns there), and switches to it
## from another shortcut view (the Character card just changes tab). Returns false when ignored.
func toggle_view(view: StringName) -> bool:
	var current := shortcut_view()
	if current == &"other":
		return false
	if current == view:
		if is_instance_valid(_screen):
			(_screen as FieldGuide).close()
		else:
			modal.chosen.emit(modal.cancel_id)
		return true
	if current in [&"loadout", &"inventory"] and view in [&"loadout", &"inventory"]:
		(modal.find_child("Character", true, false) as WorldCharacterView).select_tab(
			&"inventory" if view == &"inventory" else &"equipment")
		return true
	if current != &"":
		if is_instance_valid(_screen):
			_modal_root.remove_child(_screen)
			_screen.queue_free()
			_screen = null
		_close_modal()
	match view:
		&"map":
			open_map()
		&"loadout":
			open_character_menu()
		&"inventory":
			_open_character(&"character", null, Enums.EquipSlot.WEAPON, false, &"inventory")
		&"journal":
			open_journal(_close_modal)
		&"field_guide":
			_open_screen(load(SceneRouter.FIELD_GUIDE).instantiate(), _close_modal)
	return true


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
	# Walking, a battle or a transition always ends a preparation station interaction.
	if next != Mode.MODAL and session != null:
		session.leave_station()
	# Save and pickup cards never cover a battle; cards created meanwhile show once it closes.
	if notices != null:
		notices.visible = next != Mode.BATTLE
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
		if WorldRules.interaction_label(landmark, session.world(), _far_side(landmark), definition).is_empty():
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
			# Interact skips the wait (Adrian, V0.5): the same single entry write and launch as expiry;
			# engage() drops a running countdown first, so nothing can launch twice.
			engage(target)
		LandmarkDefinition.Kind.PREPARATION:
			open_crafting(target)
		LandmarkDefinition.Kind.RUNE:
			strike(target)
		_:
			open_dialogue(target)


## [param note]: an optional extra paragraph (a reward receipt) shown when the readout has room.
func open_dialogue(landmark: LandmarkDefinition, note: String = "") -> void:
	var far := _far_side(landmark)
	var readout := WorldRules.dialogue(landmark, session.world(), far, definition)
	if readout == null:
		return
	var paragraphs := readout.paragraphs.duplicate()
	if not note.is_empty() and paragraphs.size() < WorldDialogueReadout.MAX_PARAGRAPHS:
		paragraphs.append(note)
	var view := _open_modal(WorldModal.make(&"dialogue", readout.speaker, paragraphs, readout.actions))
	view.cancel_id = WorldRules.ACT_LEAVE
	view.chosen.connect(func(id: StringName) -> void: _on_dialogue_action(landmark, id))


func _on_dialogue_action(landmark: LandmarkDefinition, id: StringName) -> void:
	match id:
		WorldRules.ACT_RING:
			_commit(func() -> Error: return session.restore_bell(area_def.id), func() -> void:
				area.apply_state(session.world())
				if _has_received(session.last_receipts):
					_show_rewards(&"reward", WorldCopy.WAYSIDE_BELL, WorldCopy.BELL_RESTORED,
						session.last_receipts, WorldCopy.REWARD_CHARM_NEXT)
				else:
					open_dialogue(landmark))
		WorldRules.ACT_OPEN_LATCH:
			if not _far_side(landmark):
				_close_modal()
				return
			_commit(func() -> Error: return session.open_latch(area_def.id, &"short_return"), func() -> void:
				area.apply_state(session.world())
				_close_modal())
		WorldRules.ACT_GATHER:
			_commit(func() -> Error: return session.gather(area_def.id, landmark.id), func() -> void:
				area.apply_state(session.world())
				if _has_received(session.last_receipts):
					_show_rewards(&"reward", landmark.display_name, WorldCopy.GATHER_DONE, session.last_receipts)
				else:
					open_dialogue(landmark))
		WorldRules.ACT_SEARCH:
			_commit(func() -> Error: return session.find_secret(area_def.id, landmark.id), func() -> void:
				area.apply_state(session.world())
				if _has_received(session.last_receipts):
					_show_rewards(&"reward", landmark.display_name, WorldCopy.SECRET_FOUND_BODY, session.last_receipts)
				else:
					open_dialogue(landmark, WorldCopy.SECRET_EMPTY))
		_:
			_commit(func() -> Error: return session.complete_interaction(area_def.id, landmark.id), _close_modal)


## V0.5C: Confirm at a rune strikes it at once (no dialogue). The session saves the outcome; the
## area re-applies the scene views and rune_struck lets presentation add feedback. Solving shows a
## card (with any receipts); a rejected strike (a solved puzzle) changes nothing.
func strike(rune: LandmarkDefinition) -> void:
	_commit(func() -> Error: return session.strike_rune(area_def.id, rune.id), func() -> void:
		area.apply_state(session.world())
		var result := session.last_exploration
		rune_struck.emit(result)
		if result.strike != ExplorationResult.Strike.SOLVED:
			_refresh_hud()
			return
		var entry := ExplorationRules.puzzle(definition, result.puzzle_id)
		if _has_received(session.last_receipts):
			_show_rewards(&"reward", entry.display_name, WorldCopy.PUZZLE_SOLVED_TEXT, session.last_receipts)
		else:
			var view := _open_modal(WorldModal.make(&"dialogue", entry.display_name,
				PackedStringArray([_puzzle_solved_copy(result)]),
				[WorldDialogueReadout.action(WorldRules.ACT_LEAVE, WorldCopy.ACTION_CLOSE)]))
			view.cancel_id = WorldRules.ACT_LEAVE
			view.chosen.connect(func(_id: StringName) -> void: _close_modal()), _refresh_hud)


## The V0.4 Engage / Leave card. No longer opened by the world (playtest revision: the move-away
## countdown replaced it); kept as a working API for its tests and for tools.
func open_encounter_card(site: LandmarkDefinition) -> void:
	var card := WorldRules.encounter_card(site, GameState.progress)
	var view := _open_modal(WorldEncounterView.make(card))
	view.cancel_id = WorldRules.ACT_LEAVE
	view.chosen.connect(func(id: StringName) -> void:
		if id == WorldRules.ACT_ENGAGE:
			engage(site)
		else:
			_close_modal())


## The bench interaction owns the session's preparation context (V0.5A): it opens here and ends when
## the bench closes or the host returns to exploration (see _set_mode).
func open_bench(landmark: LandmarkDefinition, slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON,
		focus_id: StringName = &"", status: String = "") -> void:
	session.enter_station(landmark.id)
	var content := WorldPreparationView.new()
	content.name = "Preparation"
	content.present(session.preparation(), slot)
	# Legacy V0.5A equipment view (no longer reached from the world: equipment lives in Character).
	# It never jumps to a station service; each service opens only from its own landmark.
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(&"inventory", "Inventory"),
		WorldDialogueReadout.action(WorldRules.ACT_LEAVE, WorldCopy.ACTION_CLOSE)]
	var view := _open_modal(WorldModal.make(&"bench", landmark.display_name, PackedStringArray(), actions, content))
	view.cancel_id = WorldRules.ACT_LEAVE
	content.show_notice(status)
	content.equip_requested.connect(func(chosen_slot: Enums.EquipSlot, item_id: StringName) -> void:
		_prepare(landmark, chosen_slot, item_id))
	content.unequip_requested.connect(func(chosen_slot: Enums.EquipSlot) -> void:
		_prepare(landmark, chosen_slot, &""))
	view.chosen.connect(func(id: StringName) -> void:
		if id == &"inventory":
			open_inventory(landmark, content.selected_slot)
		else:
			session.leave_station()
			_commit(func() -> Error: return session.complete_interaction(area_def.id, landmark.id), _close_modal))
	content.focus_choice(focus_id)


## Opens the station service of PREPARATION [param landmark] (V0.5 UI: its typed service, the Forge
## anvil or the Stillroom). The session context names that exact service, so the other station's
## work is rejected there; closing, walking, transitions and battles end it.
## [param adopted]: the changed result of the station command that reopened this card (playtest
## revision); the view shows it concisely (present_operation) instead of the long [param notice]. A
## rejection or a no-op never passes one.
func open_crafting(landmark: LandmarkDefinition, selection: StringName = &"", notice: String = "",
		adopted: CraftingResult = null) -> void:
	if session.enter_station(landmark.id) != OK:
		_close_modal()
		return
	var service := station_service(landmark)
	var content := WorldCraftingView.new()
	content.name = "Crafting"
	content.present(session.crafting(), service, selection, "" if adopted != null else notice, session.inventory())
	if adopted != null:
		content.present_operation(adopted)
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(&"preparation", "Equipment"),
		WorldDialogueReadout.action(WorldRules.ACT_LEAVE, WorldCopy.ACTION_CLOSE)]
	var view := _open_modal(WorldModal.make(&"crafting", landmark.display_name, PackedStringArray(), actions, content))
	view.cancel_id = WorldRules.ACT_LEAVE
	content.command_requested.connect(func(command: StringName, id: StringName, slot: int) -> void:
		_craft(landmark, content.selection, command, id, slot))
	view.chosen.connect(func(id: StringName) -> void:
		if id == &"preparation":
			_open_character(&"character", landmark, Enums.EquipSlot.WEAPON, false, &"equipment")
		else:
			session.leave_station()
			_commit(func() -> Error: return session.complete_interaction(area_def.id, landmark.id), _close_modal))
	content.focus_selection()


## The crafting view's section for a station landmark's typed service.
static func station_service(landmark: LandmarkDefinition) -> StringName:
	return &"stillroom" if landmark.service == LandmarkDefinition.Service.STILLROOM else &"forge"


## One station command from the view's command_requested(command, id, slot): &"brew" (recipe id),
## &"craft" (fitting id), &"fit" (fitting id, socket), &"remove" (weapon id, socket), &"potion"
## (potion id, supply position), and the older &"purchase" / &"refund" (recipe id). The session
## validates everything; success and rejection reopen the station from saved truth, and a failed
## write offers Retry save for the exact command. Sound follows the session's adopted fact
## (EventBus.crafting_completed), never this handler.
func _craft(landmark: LandmarkDefinition, selection: StringName, command: StringName, id: StringName,
		slot: int) -> void:
	var write := func() -> Error:
		match command:
			&"brew": return session.brew(id)
			&"craft": return session.craft_fitting(id)
			&"purchase": return session.purchase(id)
			&"refund": return session.refund(id)
			&"fit": return session.fit(_fitting_weapon(id), id, maxi(slot, 0))
			&"remove": return session.remove_fitting(id, maxi(slot, 0))
			&"potion": return session.prepare_potion(slot, id)
		return ERR_INVALID_PARAMETER
	_commit(write, func() -> void:
		var result := session.last_crafting
		open_crafting(landmark, selection, _crafting_notice(result), result if result.changed else null), func() -> void:
		open_crafting(landmark, selection, session.last_crafting.text()))


## The older station card's receipt lines for an accepted command.
static func _crafting_notice(result: CraftingResult) -> String:
	var lines := PackedStringArray([WorldCopy.CRAFT_SAVED if result.changed else "Already set. Nothing changed."])
	for spent in result.spent:
		lines.append("Spent %d %s · Carried %d" % [spent.count, spent.name, spent.total])
	for made in result.produced:
		lines.append("Made %d %s · Held %d" % [made.count, made.name, made.total])
	for refunded in result.refunded:
		lines.append("Returned %d %s · Carried %d" % [refunded.count, refunded.name, refunded.total])
	if result.cleared_fitting != &"":
		lines.append("Installed fitting removed with the kit.")
	return "\n".join(lines)


## The fitting-capable weapon that offers [param fitting_id] (&"" when none does).
func _fitting_weapon(fitting_id: StringName) -> StringName:
	for weapon in CraftingRules.fitting_weapons(session.registry):
		for fitting in CraftingRules.weapon_fittings(session.registry, weapon.id):
			if fitting.id == fitting_id:
				return weapon.id
	return &""


## Outcome and progress are saved facts; sound is optional and has matching visible text.
func _present_rune_strike(result: ExplorationResult) -> void:
	var puzzle := session.puzzle(result.puzzle_id)
	match result.strike:
		ExplorationResult.Strike.ADVANCED:
			hud.show_feedback("%s · %d / %d stones answer" % [puzzle.name, result.progress, result.length])
		ExplorationResult.Strike.MISTAKE:
			hud.show_feedback("The rhythm breaks · %d / %d · Try again" % [result.progress, result.length])
		ExplorationResult.Strike.SOLVED:
			hud.show_feedback(_puzzle_solved_copy(result))
	# Scene-authored tone; no timing, puzzle truth or solution comes from sound.
	var point := area.get_node_or_null("Interactions/" + String(result.landmark_id))
	var cue := String(point.get_meta(&"strike_cue", &"step_stone")) if point != null else "step_stone"
	AudioManager.play(AudioManager.Cue.get(cue.to_upper(), AudioManager.Cue.STEP_STONE), 0.0, -3.0)


func _puzzle_solved_copy(result: ExplorationResult) -> String:
	var labels := PackedStringArray()
	for id in result.revealed:
		var found := definition.find_landmark(id)
		if not found.is_empty():
			labels.append(found[1].display_name)
	return WorldCopy.PUZZLE_SOLVED_TEXT + (" Revealed: " + ", ".join(labels) + ". Look beside the boards."
		if not labels.is_empty() else "")


## The host sends the command, then refreshes from saved truth. Retry captures IDs/resources only.
func _prepare(landmark: LandmarkDefinition, slot: Enums.EquipSlot, item_id: StringName) -> void:
	var write := func() -> Error:
		return session.unequip(slot) if item_id == &"" else session.equip(slot, item_id)
	_commit(write, func() -> void:
		open_bench(landmark, slot, item_id, "Equipment saved."), func() -> void:
		open_bench(landmark, slot, &"", session.last_preparation.text()))


func open_inventory(bench: LandmarkDefinition = null, slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON) -> void:
	_open_character(&"inventory", bench, slot, true)


func open_character_menu() -> void:
	_open_character(&"character")


## Character: the unified Loadout (gear, pet, supplies, the saved combat arrangement) and the
## Inventory. Equipment, supplies, arrangement and familiar choices are field commands through the
## session (rejected during an encounter); a rejection or a no-op reopens the same tab with the typed
## reason, a failed write offers Retry save for the exact command, and success rebuilds from adopted
## state (the save notice comes from the session's one save event). [param status]: a line shown on
## the reopened card. [param adopted] (the changed result of the command that reopened the card)
## goes to the view's concise hook (present_preparation / present_combat).
func _open_character(kind: StringName, bench: LandmarkDefinition = null,
		slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON, return_to_menu: bool = false, tab: StringName = &"",
		status: String = "", combat_position: int = 0, adopted: RefCounted = null) -> void:
	var content := WorldCharacterView.new()
	content.combat_position = combat_position
	content.present(session.inventory(), session.loadout())
	content.selected_slot = slot
	content.select_tab(tab if tab != &"" else (&"inventory" if kind == &"inventory" else &"equipment"))
	if adopted is PreparationResult:
		content.present_preparation(adopted)
	elif adopted is CombatResult:
		content.present_combat(adopted)
	var reopen := func(next_status: String, next_tab: StringName, next_slot: Enums.EquipSlot, position: int,
			result: RefCounted) -> void:
		_open_character(kind, bench, next_slot, return_to_menu, next_tab, next_status, position, result)
	content.equip_requested.connect(func(chosen_slot: Enums.EquipSlot, item: StringName) -> void:
		_character_command(func() -> Error: return session.equip(chosen_slot, item),
			func() -> RefCounted: return session.last_preparation, reopen, &"equipment", chosen_slot,
			content.combat_position, true))
	content.unequip_requested.connect(func(chosen_slot: Enums.EquipSlot) -> void:
		_character_command(func() -> Error: return session.unequip(chosen_slot),
			func() -> RefCounted: return session.last_preparation, reopen, &"equipment", chosen_slot,
			content.combat_position, true))
	content.potion_requested.connect(func(index: int, potion: StringName) -> void:
		_character_command(func() -> Error: return session.prepare_potion(index, potion),
			func() -> RefCounted: return session.last_crafting, reopen, &"equipment", content.selected_slot,
			content.combat_position, false))
	content.combat_requested.connect(func(command: StringName, position: int, action_id: StringName, other: int) -> void:
		var write := func() -> Error:
			match command:
				&"swap": return session.swap_actions(position, other)
				&"move": return session.move_action(action_id, position)
			return session.arrange_action(position, action_id)
		_character_command(write, func() -> RefCounted: return session.last_combat, reopen,
			content.selected_tab_id(), content.selected_slot, position, false))
	content.familiar_requested.connect(func(familiar_id: StringName) -> void:
		_character_command(func() -> Error: return session.choose_familiar(familiar_id),
			func() -> RefCounted: return session.last_familiar, reopen, content.selected_tab_id(),
			content.selected_slot, content.combat_position, false))
	content.familiar_passive_requested.connect(func(passive_id: StringName) -> void:
		_character_command(func() -> Error: return session.choose_familiar_passive(passive_id),
			func() -> RefCounted: return session.last_familiar, reopen, content.selected_tab_id(),
			content.selected_slot, content.combat_position, false))
	content.journal_requested.connect(func() -> void:
		var journal_slot := content.selected_slot
		var journal_tab := content.selected_tab_id()
		var journal_position := content.combat_position
		open_journal(func() -> void:
			_open_character(kind, bench, journal_slot, return_to_menu, journal_tab, "", journal_position)))
	content.field_guide_requested.connect(func() -> void:
		var back_slot := content.selected_slot
		var back_tab := content.selected_tab_id()
		var back_position := content.combat_position
		_open_screen(load(SceneRouter.FIELD_GUIDE).instantiate(), func() -> void:
			_open_character(kind, bench, back_slot, return_to_menu, back_tab, "", back_position)))
	var view := _open_modal(WorldModal.make(kind, "Hollow", PackedStringArray(),
		[WorldDialogueReadout.action(&"back", "Back to station" if bench != null else "Back")],
		content))
	if not status.is_empty():
		view.set_status(status)
	content._relink.call_deferred()
	WorldModal.focus_later(content.first_item)
	view.cancel_id = &"back"
	view.chosen.connect(func(_id: StringName) -> void:
		if bench != null:
			open_crafting(bench)
		elif return_to_menu:
			open_menu()
		else:
			_close_modal())


## One Character command. [param result_of] returns the session's typed result for it. Success and
## rejection both reopen [param tab] from saved truth; a failed write keeps everything and offers
## Retry save, which repeats exactly [param write]. A changed result is handed to the reopened view;
## with [param concise] (a view that shows it itself) the long status line is left out.
func _character_command(write: Callable, result_of: Callable, reopen: Callable, tab: StringName,
		slot: Enums.EquipSlot, position: int, concise: bool) -> void:
	_commit(write, func() -> void:
		var result: RefCounted = result_of.call()
		var changed: bool = result.get(&"changed")
		reopen.call("" if concise and changed else _result_text(result), tab, slot, position,
			result if changed else null), func() -> void:
		reopen.call(_result_text(result_of.call()), tab, slot, position, null))


## The status line of a typed command result: an equipment result's summary (its rejection, its
## no-op line or the older card's prose), otherwise the result's reason text ("" on success).
static func _result_text(result: RefCounted) -> String:
	if result is PreparationResult:
		return (result as PreparationResult).summary()
	return String(result.call(&"text"))


func open_map() -> void:
	var view := WorldMapView.new()
	view.name = "MapView"
	view.custom_minimum_size = Vector2(1000, 420)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.show_readout(map_readout())
	var modal_view := _open_modal(WorldModal.make(&"map", area_def.display_name, PackedStringArray(),
		[WorldDialogueReadout.action(WorldRules.ACT_LEAVE, "Back")], view, 1120))
	modal_view.cancel_id = WorldRules.ACT_LEAVE
	modal_view.toggle_action = InputBindings.WORLD_MAP
	modal_view.chosen.connect(func(_id: StringName) -> void: _close_modal())


func map_readout() -> WorldMapReadout:
	return WorldRules.map_readout(area_def, session.world(), definition.tile_size, player.position, area.landmark_positions(),
		definition)


func open_menu() -> void:
	var actions: Array[Dictionary] = [
		WorldDialogueReadout.action(&"resume", "Resume"),
		WorldDialogueReadout.action(&"journal", WorldCopy.JOURNAL_TITLE),
		WorldDialogueReadout.action(&"settings", "Settings"),
		WorldDialogueReadout.action(&"help", "Help"),
		WorldDialogueReadout.action(&"save", "Save"),
		WorldDialogueReadout.action(&"title", "Save and return to title"),
		WorldDialogueReadout.action(&"quit", "Save and Quit"),
	]
	var view := _open_modal(WorldModal.make(&"menu", "Paused", PackedStringArray(), actions))
	view.cancel_id = &"resume"
	view.toggle_action = InputBindings.WORLD_MENU
	view.chosen.connect(_on_menu_action)


func _on_menu_action(id: StringName) -> void:
	match id:
		&"journal":
			open_journal()
		&"inventory":
			open_inventory()
		&"field_guide":
			_open_screen(load(SceneRouter.FIELD_GUIDE).instantiate())
		&"settings":
			_open_screen(load(SceneRouter.SETTINGS).instantiate())
		&"help":
			var help := WorldCopy.SAVE_NOTE.split("\n\n")
			help.append(WorldCopy.CONTROLS_NOTE % [InputBindings.prompt(InputBindings.WORLD_SPRINT),
				InputBindings.prompt(InputBindings.WORLD_LOADOUT), InputBindings.prompt(InputBindings.WORLD_INVENTORY),
				InputBindings.prompt(InputBindings.WORLD_JOURNAL), InputBindings.prompt(InputBindings.WORLD_FIELD_GUIDE),
				InputBindings.prompt(InputBindings.WORLD_MAP)])
			var help_view := _open_modal(WorldModal.make(&"help", "Journey help", help,
				[WorldDialogueReadout.action(&"back", "Back")]))
			help_view.cancel_id = &"back"
			help_view.chosen.connect(func(_action: StringName) -> void: open_menu())
		&"save":
			_commit(session.save, open_menu)
		&"quit":
			_commit(session.save, func() -> void: quit_game.call())
		&"reset":
			_confirm_reset()
		&"title":
			_commit(session.save, func() -> void: leave_to_title.call())
		_:
			_close_modal()


## The quest journal (playtest revision): the session's typed journal in a paused-world card.
## Opening it reads the saved stage and announces nothing. [param returned]: where Back goes
## (default: the paused menu).
func open_journal(returned: Callable = Callable()) -> void:
	var view := _open_modal(WorldModal.make(&"journal", WorldCopy.JOURNAL_TITLE, PackedStringArray(),
		[WorldDialogueReadout.action(&"back", "Back")], WorldJournalView.make(session.quests())))
	view.cancel_id = &"back"
	view.chosen.connect(func(_id: StringName) -> void:
		if returned.is_valid():
			returned.call()
		else:
			open_menu())


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
func _open_screen(screen: Control, returned: Callable = Callable()) -> void:
	_dismiss_modal()
	screen.set("embedded", true)
	_modal_root.add_child(screen)
	_screen = screen
	SessionLog.event("world", "opened %s" % screen.name)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_mode(Mode.MODAL)
	screen.connect(&"closed", func() -> void:
		if _screen == screen:
			_screen = null
		screen.queue_free()
		if returned.is_valid(): returned.call()
		else: open_menu())


# --- Portals -------------------------------------------------------------------------------------

func take_portal(landmark_id: StringName) -> void:
	var portal := definition.portal_from(area_def.id, landmark_id)
	if portal == null:
		return
	# Leaving the area drops any running countdown.
	_publish_countdown(countdown.cancel())
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
## Playtest revision: called by the countdown's expiry (and by the save-failure Retry, which repeats
## the same site). Any countdown still running is dropped first, so nothing can launch a second
## battle behind this one.
func engage(site: LandmarkDefinition) -> void:
	if mode == Mode.BATTLE or battle != null:
		return
	SessionLog.event("world", "engage %s" % site.id)
	_publish_countdown(countdown.cancel())
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


## Playtest revision: the victory card shows the session's own saved facts: Bestiary Learnings (each
## enemy whose tier rose, old tier -> new tier, captured before adoption) and salvage receipts. A
## failed write shows the Retry card and nothing else; a repeated result shows neither again.
func _commit_victory(entry: EncounterEntry, result: BattleResult) -> void:
	var err := session.commit_victory(entry, result)
	if err != OK and err != ERR_ALREADY_EXISTS:
		_show_save_failure(func() -> void: _commit_victory(entry, result))
		return
	var receipts: Array[RewardReadout] = []
	victory_learnings = []
	if err == OK:
		receipts.assign(session.last_receipts)
		victory_learnings.assign(session.last_learnings)
	_close_battle()
	area.apply_state(session.world())
	load_area(entry.area_id(), entry.approach_anchor())
	if _encounter_position != Vector2.INF:
		player.place(_encounter_position, _encounter_facing)
		_arm_triggers()
	var actions: Array[Dictionary] = [WorldDialogueReadout.action(&"continue", WorldCopy.ACTION_CONTINUE)]
	# Bestiary Learnings and Salvage only: no explanatory prose.
	var content := WorldRewardView.make(receipts)
	content.present_learnings(victory_learnings)
	var view := _open_modal(WorldModal.make(&"victory", "Victory", PackedStringArray(), actions, content))
	view.cancel_id = &"continue"
	view.chosen.connect(func(_id: StringName) -> void:
		victory_learnings = []
		_close_modal())


## Receipts exist only after a successful write. Each caller consumes only that command's result.
func _has_received(receipts: Array[RewardReadout]) -> bool:
	return receipts.any(func(receipt: RewardReadout) -> bool: return not receipt.summary().is_empty())


func _show_rewards(kind: StringName, title: String, body: String, receipts: Array[RewardReadout],
		next_step: String = "") -> void:
	var content := WorldRewardView.make(receipts)
	if not next_step.is_empty():
		content.add_child(UITheme.label(next_step, UITheme.INFO, 22, true))
	var view := _open_modal(WorldModal.make(kind, title, PackedStringArray([body]),
		[WorldDialogueReadout.action(&"continue", WorldCopy.ACTION_CONTINUE)], content))
	view.cancel_id = &"continue"
	view.chosen.connect(func(_id: StringName) -> void: _close_modal())


## Leave battle returns to the approach without recording an attempt.
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
func _commit(write: Callable, then: Callable, rejected: Callable = Callable()) -> void:
	var err: Error = write.call()
	if err == OK:
		then.call()
	elif err in [ERR_UNAVAILABLE, ERR_INVALID_PARAMETER, ERR_ALREADY_EXISTS]:
		if rejected.is_valid():
			rejected.call()
		else:
			_close_modal()
	else:
		_show_save_failure(func() -> void: _commit(write, then, rejected))


func _show_save_failure(retry: Callable) -> void:
	SessionLog.event("save", "write failed: %s" % error_string(session.last_error))
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
	if notices != null:
		notices.save_dock = view.notice_dock
	_set_mode(Mode.MODAL)
	modal_opened.emit(view)
	return view


func _dismiss_modal() -> void:
	if notices != null:
		notices.save_dock = null
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
	_readout.interaction = WorldRules.interaction_label(target, session.world(), _far_side(target), definition) \
		if target != null else ""
	if target != null and target.kind == LandmarkDefinition.Kind.RUNE:
		var sequence := ExplorationRules.puzzle_of(definition, target.id)
		if sequence != null:
			var state := session.puzzle(sequence.id)
			_readout.interaction += " · %d / %d" % [state.entered, state.length]
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
	hud.character_requested.connect(func() -> void:
		if mode == Mode.EXPLORE:
			open_character_menu())
	hud.journal_requested.connect(func() -> void:
		if mode == Mode.EXPLORE:
			open_journal(_close_modal))
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
