extends TestCase
## Third playtest: Menu → Reset journey. One confirmed write restarts only the exploration journey
## (route knowledge, cleared sites, bell and latch, any pending entry) at the Gloamstead square;
## research, mastery, loadout, inventory, statistics and settings stay. Cancel is the default and
## changes nothing; a failed write keeps the live journey and offers Retry save; repeated presses
## write once; completion tokens keep counting across the reset; the active slot is the only file.

const THROWAWAY_SLOT := 98

var kit: WorldKit
var tree: SceneTree
var host: WorldHost


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	for action in InputBindings.WORLD_ACTIONS + [InputBindings.CONFIRM, InputBindings.CANCEL]:
		Input.action_release(action)
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


## A journey well under way: research and practice from a committed victory, the bow equipped,
## routes charted, the guard cleared, bell rung, latch opened, standing at the latch.
func _progressed(session: WorldSession) -> void:
	var definition := session.definition
	assert_eq(session.enter_station(&"preparation_bench"), OK)
	assert_eq(session.choose_weapon(&"reedbow"), OK)
	session.leave_station()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), OK)
	var world := GameState.progress.world
	for area in definition.areas:
		for landmark in area.landmarks:
			world.discover(landmark.id)
		for path in area.paths:
			world.add_link(path.id)
	assert_eq(session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(session.open_latch(&"briarfen_reedway", &"short_return"), OK)
	world = GameState.progress.world # Every commit publishes a new progress object.
	assert_true(world.is_cleared(&"bell_guard") and world.wayside_bell_restored and world.return_latch_open)


static func _settings_text() -> String:
	var config := ConfigFile.new()
	Settings.data.write_to(config)
	return config.encode_to_text()


## Everything outside the journey as canonical JSON (numbers and key order as on disk). The
## journey is the world section and, since the playtest revision, the journal stage derived from it
## (`quests`): Reset journey rewinds both. Everything else, the supply stock included, is kept.
static func _kept(progress: ProgressState) -> String:
	var data := progress.to_dict()
	data.erase("world")
	data.erase("quests")
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true)


func _start() -> void:
	host = WorldHost.new()
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _modal_text() -> String:
	var texts := PackedStringArray()
	for label in host.modal.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return "\n".join(texts)


func test_reset_restarts_only_the_journey_and_keeps_combat_progression() -> void:
	var session := kit.session()
	session.open()
	_progressed(session)
	var kept := _kept(GameState.progress)
	assert_false(GameState.progress.bestiary.to_dict().is_empty(), "research to keep")
	assert_false(GameState.progress.weapon_mastery.is_empty(), "practice to keep")
	var serial := GameState.progress.world.entry_serial
	var token := GameState.progress.world.last_applied_token
	var settings := _settings_text()
	var writes := kit.writer.writes.size()
	assert_eq(session.reset_journey(), OK)
	assert_eq(kit.writer.writes.size(), writes + 1, "one write")
	for progress: ProgressState in [GameState.progress, ProgressState.from_dict(kit.writer.last())]:
		var world := progress.world
		assert_eq(world.area, &"gloamstead")
		assert_eq(world.anchor, &"town_bell")
		assert_true(world.discovered.is_empty() and world.links.is_empty() and world.cleared.is_empty(), "route knowledge and clears reset")
		assert_false(world.wayside_bell_restored or world.return_latch_open, "bell and latch reset")
		assert_null(world.pending_entry)
		assert_eq(world.entry_serial, serial, "completion tokens keep counting")
		assert_eq(world.last_applied_token, token)
		assert_eq(_kept(progress), kept, "research, mastery, loadout, inventory and statistics are kept")
		assert_eq(progress.quests.get(QuestRules.BELL), QuestRules.BellStage.FIND, "the journal follows the journey back")
		assert_true(progress.has_migration(SupplyRules.MIGRATION), "the supply migration is never repeated by a reset")
	assert_eq(GameState.progress.loadout_weapon, &"reedbow", "the equipped weapon is kept")
	assert_eq(_settings_text(), settings, "settings are untouched")
	# Fresh session from the saved file: the square, nothing to sanitize, progression intact.
	GameState.progress = ProgressState.from_dict(kit.writer.last())
	var reopened := kit.session()
	assert_true(reopened.open().is_empty(), "the reset save is clean")
	assert_eq(WorldRules.objective(reopened.world(), reopened.definition, &"gloamstead"), WorldCopy.OBJECTIVE_FIND)
	assert_eq(_kept(GameState.progress), kept)


func test_failed_reset_write_leaves_the_live_journey_untouched() -> void:
	var session := kit.session()
	session.open()
	_progressed(session)
	var before := GameState.progress.to_dict()
	var writes := kit.writer.writes.size()
	kit.writer.fail = true
	assert_eq(session.reset_journey(), ERR_FILE_CANT_WRITE)
	assert_eq(GameState.progress.to_dict(), before, "nothing published")
	assert_eq(kit.writer.writes.size(), writes, "nothing written")


func test_pending_entries_and_old_completions_cannot_cross_the_reset() -> void:
	var session := kit.session()
	session.open()
	var cleared := session.begin_entry(&"bell_guard", &"bell_guard")
	assert_eq(session.commit_victory(cleared, WorldKit.victory(&"bell_guard")), OK)
	var interrupted := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_not_null(GameState.progress.world.pending_entry)
	assert_eq(session.reset_journey(), OK)
	assert_null(GameState.progress.world.pending_entry, "the pending entry is gone")
	var won := GameState.progress.battles_won
	assert_ne(session.commit_victory(interrupted, WorldKit.victory(&"reedway_patrol")), OK, "a pre-reset entry cannot complete")
	assert_eq(session.commit_victory(cleared, WorldKit.victory(&"bell_guard")), ERR_ALREADY_EXISTS, "an old completion stays a no-op")
	assert_false(GameState.progress.world.is_cleared(&"bell_guard") or GameState.progress.world.is_cleared(&"reedway_patrol"))
	assert_eq(GameState.progress.battles_won, won)
	# The new journey's first victory is new, even at the same site.
	var again := session.begin_entry(&"bell_guard", &"bell_guard")
	assert_ne(again.token(), cleared.token(), "tokens never repeat across a reset")
	assert_eq(session.commit_victory(again, WorldKit.victory(&"bell_guard")), OK)
	assert_true(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_eq(GameState.progress.battles_won, won + 1)


func test_menu_reset_asks_first_with_cancel_focused() -> void:
	await _start()
	assert_eq(host.session.enter_station(&"preparation_bench"), OK)
	assert_eq(host.session.choose_weapon(&"mire_maul"), OK)
	host.session.leave_station()
	var before := GameState.progress.to_dict()
	var writes := kit.writer.writes.size()
	host.open_menu()
	assert_null(host.modal.button(&"reset"), "Reset journey is debug-only")
	host._confirm_reset()
	assert_eq(host.modal.kind, &"reset")
	assert_true(_modal_text().contains(WorldCopy.RESET_BODY), "the card states what resets and what is kept")
	await tree.process_frame
	await tree.process_frame
	assert_eq(host.get_viewport().gui_get_focus_owner(), host.modal.button(&"cancel"), "Cancel is focused first")
	host.modal.button(&"cancel").pressed.emit()
	assert_eq(host.modal.kind, &"menu", "Cancel returns to the paused menu")
	host._confirm_reset()
	var back := InputEventAction.new()
	back.action = InputBindings.CANCEL
	back.pressed = true
	host.get_viewport().push_input(back)
	await tree.process_frame
	assert_eq(host.modal.kind, &"menu", "Back is Cancel")
	assert_eq(kit.writer.writes.size(), writes, "nothing written")
	assert_eq(GameState.progress.to_dict(), before, "nothing changed")


func test_confirmed_reset_rebuilds_the_host_at_the_square_once() -> void:
	var session := kit.session()
	session.open()
	_progressed(session)
	var kept := _kept(GameState.progress)
	await _start()
	assert_eq(host.area_def.id, &"briarfen_reedway")
	assert_true((host.area.get_node("DepthSorted/ReturnLatch/Open") as Node2D).visible)
	host.open_menu()
	host._confirm_reset()
	var confirm := host.modal.button(&"reset")
	var writes := kit.writer.writes.size()
	confirm.pressed.emit()
	confirm.pressed.emit() # A second press reaches the replaced card: no second write.
	assert_eq(kit.writer.writes.size(), writes + 1, "one confirmation, one write")
	assert_null(host.modal)
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_eq(host.area_def.id, &"gloamstead")
	assert_eq(host.player.position, host.area.anchor(&"town_bell"))
	assert_false((host.area.get_node("DepthSorted/TownBell/Answering") as Node2D).visible, "the town bell is quiet again")
	assert_false((host.area.get_node("DepthSorted/SquareLamp/Lit") as Node2D).visible, "the lamp is unlit again")
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_FIND)
	assert_eq(_kept(GameState.progress), kept)
	var fen := WorldDefinition.load_default().area(&"briarfen_reedway")
	for landmark in fen.landmarks:
		assert_false(GameState.progress.world.is_discovered(landmark.id), "%s is uncharted again" % landmark.id)
	for path in fen.paths:
		assert_false(GameState.progress.world.links.has(path.id), "%s is unwalked again" % path.id)
	assert_true(GameState.progress.world.cleared.is_empty())
	# Back in the fen the gate is shut and the guard is back.
	host.load_area(&"briarfen_reedway", &"reedway_entry")
	assert_true((host.area.get_node("DepthSorted/ReturnLatch/Closed") as Node2D).visible)
	assert_true((host.area.get_node("DepthSorted/GuardGroup") as Node2D).visible)


func test_failed_reset_offers_retry_and_keeps_the_journey_until_it_saves() -> void:
	var session := kit.session()
	session.open()
	_progressed(session)
	await _start()
	var before := GameState.progress.to_dict()
	host.open_menu()
	host._confirm_reset()
	kit.writer.fail = true
	host.modal.button(&"reset").pressed.emit()
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(GameState.progress.to_dict(), before, "the live journey is untouched")
	assert_eq(host.area_def.id, &"briarfen_reedway")
	assert_ne(host.mode, WorldHost.Mode.EXPLORE)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.area_def.id, &"gloamstead")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_false(GameState.progress.world.return_latch_open)


func test_reset_writes_only_the_active_slot() -> void:
	var previous_slot := GameState.active_slot
	GameState.active_slot = THROWAWAY_SLOT # Never a player's save; this run's user:// is a QA home.
	SaveManager.delete_slot(THROWAWAY_SLOT)
	var dir := ProjectSettings.globalize_path(SaveManager.slot_path(THROWAWAY_SLOT).get_base_dir())
	var files_before := Array(DirAccess.get_files_at(dir)) if DirAccess.dir_exists_absolute(dir) else []
	var session := WorldSession.new(WorldDefinition.load_default(), Callable(), 5)
	session.open()
	assert_eq(session.enter_station(&"preparation_bench"), OK)
	assert_eq(session.choose_weapon(&"reedbow"), OK)
	session.leave_station()
	var entry := session.begin_entry(&"bell_guard", &"bell_guard")
	assert_eq(session.commit_victory(entry, WorldKit.victory(&"bell_guard")), OK)
	var kept := _kept(GameState.progress)
	assert_eq(session.reset_journey(), OK)
	var files_after := Array(DirAccess.get_files_at(dir))
	var added := files_after.filter(func(file: String) -> bool: return not files_before.has(file))
	assert_eq(added, ["slot_%d.json" % THROWAWAY_SLOT], "the active slot is the only file written")
	GameState.progress = ProgressState.new()
	assert_eq(SaveManager.load_slot(THROWAWAY_SLOT), OK)
	assert_eq(GameState.progress.world.anchor, &"town_bell")
	assert_false(GameState.progress.world.is_cleared(&"bell_guard"))
	assert_eq(_kept(GameState.progress), kept, "reloaded from disk with progression kept")
	SaveManager.delete_slot(THROWAWAY_SLOT)
	GameState.active_slot = previous_slot
