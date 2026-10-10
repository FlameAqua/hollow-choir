extends TestCase
## Playtest revision through the real WorldHost and scenes: the move-away countdown that replaced
## the Engage card (start, real-time decrease, cancel by leaving, hysteresis, Interact fighting at once, held
## under a modal or a lost focus, one saved entry and one battle at expiry, a failed entry write and
## its Retry, cleared sites, area loads and portals), tapping into a wall never reading as walking,
## the paused menu's Journal, a new journey's one quest announcement and the victory's Bestiary
## Learnings. The countdown's own arithmetic is covered by tests/unit/test_encounter_countdown.gd.

const PATROL := &"reedway_patrol"
const GUARD := &"bell_guard"
const S := EncounterCountdown.State
const FORBIDDEN := ["fen_patrol", "rot_grove", "Fen Patrol", "Rot Grove", "Bogshell", "Thornhound", "Fen Wisp",
	"Rotcap", "Sporecaller", "affinit", "weakness", "resist"]

var kit: WorldKit
var tree: SceneTree
var host: WorldHost
var quest_changes: Array[QuestChange] = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	quest_changes.clear()
	EventBus.quest_changed.connect(_on_quest_changed)


func after_each() -> void:
	EventBus.quest_changed.disconnect(_on_quest_changed)
	for action in InputBindings.WORLD_ACTIONS + [InputBindings.CONFIRM, InputBindings.CANCEL]:
		Input.action_release(action)
	if host != null:
		host.queue_free()
		host = null
	GameState._fresh_journey = false
	kit.restore()


func _on_quest_changed(change: QuestChange) -> void:
	quest_changes.append(change)


func _start(area_id: StringName = &"", anchor: StringName = &"") -> void:
	if area_id != &"":
		GameState.progress.world.area = area_id
		GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	# Desktop focus must not interrupt scripted walking in hidden-window test runs.
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _frames(count: int) -> void:
	for frame in count:
		await tree.physics_frame


## Walks until [param done] returns true or [param limit] physics frames pass, then stands still.
func _walk_until(direction: Vector2, done: Callable, limit: int = 400) -> bool:
	host.scripted_move = direction
	for frame in limit:
		await tree.physics_frame
		if done.call():
			host.scripted_move = Vector2.ZERO
			return true
	host.scripted_move = Vector2.ZERO
	return false


func _texts(node: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	if node is Label:
		texts.append((node as Label).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).text)
	elif node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		texts.append_array(_texts(child))
	return texts


## Walks up from the patrol's approach until its countdown runs, then stands still.
func _into_patrol_reach() -> bool:
	return await _walk_until(Vector2.UP, func() -> bool: return host.countdown.active())


# --- The move-away countdown ---------------------------------------------------------------------

func test_entering_reach_counts_down_and_walking_away_cancels_for_free() -> void:
	await _start(&"briarfen_reedway", PATROL)
	var seen: Array[EncounterCountdownReadout] = []
	host.encounter_countdown_changed.connect(func(readout: EncounterCountdownReadout) -> void: seen.append(readout))
	assert_false(host.encounter_countdown().active, "nothing counts at the approach")
	assert_true(host.countdown.is_armed(PATROL))
	var writes := kit.writer.writes.size()
	assert_true(await _into_patrol_reach(), "entering the patrol's reach starts the countdown")
	assert_null(host.modal, "no card opens: the world stays in play")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	var readout := host.encounter_countdown()
	assert_eq([readout.active, readout.frozen, readout.threat_id, readout.duration],
		[true, false, PATROL, EncounterCountdown.DURATION])
	assert_eq(readout.threat_label, WorldKit.site(PATROL).threat_label, "the public threat category")
	for word: String in FORBIDDEN:
		assert_false(readout.plain_text().contains(word), "the indicator names no creature: %s" % word)
	assert_eq(seen.map(func(entry: EncounterCountdownReadout) -> int: return entry.state), [S.COUNTING],
		"listeners hear the start once")
	# Real exploration time: half a second of frames is half a second less.
	var running := host.countdown.remaining
	await _frames(30)
	assert_almost_eq(running - host.countdown.remaining, 30.0 / Engine.physics_ticks_per_second, 0.05)
	assert_lt(host.encounter_countdown().fraction(), 1.0)
	assert_eq(seen.size(), 1, "a running countdown is not a new event every frame")
	# Walking back out cancels: nothing is saved, launched or owed.
	assert_true(await _walk_until(Vector2.DOWN, func() -> bool: return not host.countdown.active()),
		"leaving the reach cancels it")
	assert_null(host.battle)
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(kit.writer.writes.size(), writes, "cancelling writes nothing")
	assert_false(host.encounter_countdown().active)
	assert_true(seen.any(func(entry: EncounterCountdownReadout) -> bool: return entry.state == S.CANCELLED and not entry.active),
		"listeners hear the cancel")
	# Brushing the edge again does not restart it: Hollow must first be well clear.
	await _walk_until(Vector2.UP, func() -> bool: return false, 6)
	await _frames(4)
	assert_false(host.countdown.active(), "stepping straight back in does not restart it")
	assert_false(host.countdown.is_armed(PATROL))
	assert_eq(host.readout().interaction, WorldCopy.PROMPT_ENGAGE % WorldKit.site(PATROL).threat_label.to_lower(),
		"the prompt offers to fight at once instead")
	# Walking well clear re-arms the threat; returning then starts a fresh, full countdown.
	assert_true(await _walk_until(Vector2.DOWN, func() -> bool: return host.countdown.is_armed(PATROL)),
		"well clear of the patrol it is armed again")
	assert_false(host.countdown.active())
	assert_true(await _into_patrol_reach())
	await _frames(1)
	assert_gt(host.countdown.remaining, EncounterCountdown.DURATION - 0.1)
	assert_eq(kit.writer.writes.size(), writes, "none of it wrote anything")
	assert_eq(GameState.progress.battles_won + GameState.progress.battles_lost, 0)


func test_interact_at_a_threat_fights_at_once_and_only_once() -> void:
	await _start(&"briarfen_reedway", PATROL)
	var writes := kit.writer.writes.size()
	assert_true(await _into_patrol_reach())
	await _frames(6)
	assert_true(host.countdown.active())
	assert_eq(host.interaction_target().id, PATROL)
	# Interact (the bound key, through the host's own input) skips the rest of the wait: one saved
	# entry, one battle, and no countdown left running behind it.
	var press := InputEventAction.new()
	press.action = InputBindings.WORLD_INTERACT
	press.pressed = true
	host._unhandled_input(press)
	assert_not_null(host.battle, "Interact fights at once")
	if host.battle == null:
		return
	assert_eq(kit.writer.writes.size(), writes + 1, "the entry is saved before the battle starts")
	assert_eq(GameState.progress.world.pending_entry.site_id(), PATROL)
	assert_false(host.countdown.active())
	var battle := host.battle
	host.interact()
	host.engage(WorldKit.site(PATROL))
	await _frames(30)
	assert_eq(host.battle, battle, "nothing launches a second battle")
	assert_eq(kit.writer.writes.size(), writes + 1)
	# Leave battle, walk back in and Interact before anything counts: a failed entry write keeps the
	# journey, offers Retry, and Retry fights exactly once.
	battle.setup_requested.emit()
	await tree.process_frame
	assert_null(host.battle)
	assert_true(await _walk_until(Vector2.DOWN, func() -> bool: return host.countdown.is_armed(PATROL)))
	assert_true(await _into_patrol_reach())
	writes = kit.writer.writes.size()
	kit.writer.fail = true
	host.interact()
	assert_null(host.battle, "no battle without a saved entry")
	assert_eq(host.modal.kind, &"save_failed")
	assert_null(GameState.progress.world.pending_entry)
	assert_false(host.countdown.active(), "nothing counts behind the card")
	await _frames(20)
	assert_null(host.battle)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_not_null(host.battle, "Retry enters the same encounter")
	assert_eq(kit.writer.writes.size(), writes + 1, "once")
	assert_eq(GameState.progress.world.pending_entry.site_id(), PATROL)


func test_expiry_saves_one_entry_and_launches_one_battle() -> void:
	await _start(&"briarfen_reedway", PATROL)
	host.countdown.duration = 0.25
	var expired := [0]
	host.encounter_countdown_changed.connect(func(readout: EncounterCountdownReadout) -> void:
		if readout.state == S.EXPIRED:
			expired[0] += 1)
	var writes := kit.writer.writes.size()
	assert_true(await _into_patrol_reach())
	var spot := host.player.position
	await _frames(30)
	assert_not_null(host.battle, "staying in reach until zero launches the encounter")
	if host.battle == null:
		return
	assert_eq(host.mode, WorldHost.Mode.BATTLE)
	assert_eq(kit.writer.writes.size(), writes + 1, "the entry is saved before the battle starts")
	assert_not_null(GameState.progress.world.pending_entry)
	assert_eq(GameState.progress.world.pending_entry.site_id(), PATROL)
	assert_false(host.countdown.active())
	assert_eq(expired[0], 1, "it expired exactly once")
	assert_null(host.modal)
	# Nothing can launch a second battle behind this one: not time, not a second engage.
	var battle := host.battle
	await _frames(40)
	host.engage(WorldKit.site(PATROL))
	assert_eq(host.battle, battle)
	assert_eq(kit.writer.writes.size(), writes + 1)
	assert_eq(expired[0], 1)
	assert_false(battle.launch.record_progress, "the battle never records on its own")
	assert_true(battle.host_result)
	# Pause -> Leave battle: back at the approach with the threat armed again, nothing awarded.
	battle.setup_requested.emit()
	await tree.process_frame
	assert_null(host.battle)
	assert_ne(host.player.position, spot)
	assert_eq(host.player.position, host.area.anchor(PATROL))
	assert_null(GameState.progress.world.pending_entry)
	assert_false(GameState.progress.world.is_cleared(PATROL))
	assert_eq(GameState.progress.battles_won + GameState.progress.battles_lost, 0)
	assert_true(host.countdown.is_armed(PATROL), "the encounter is available again")
	assert_false(host.countdown.active())


func test_a_modal_or_a_lost_focus_holds_the_countdown_without_resetting_it() -> void:
	await _start(&"briarfen_reedway", PATROL)
	assert_true(await _into_patrol_reach())
	await _frames(12)
	var writes := kit.writer.writes.size()
	# A modal (the map): time stops where it was, for as long as the modal stays open.
	host.open_map()
	var held := host.countdown.remaining
	assert_lt(held, EncounterCountdown.DURATION)
	await _frames(45)
	assert_eq(host.countdown.state, S.FROZEN)
	assert_almost_eq(host.countdown.remaining, held, 0.0001, "held, never reset and never advanced")
	assert_eq([host.encounter_countdown().active, host.encounter_countdown().frozen], [true, true])
	assert_null(host.battle)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	await _frames(6)
	assert_eq(host.countdown.state, S.COUNTING, "it resumes with exploration")
	assert_lt(host.countdown.remaining, held)
	assert_gt(host.countdown.remaining, held - 0.25, "from the held time, not from zero")
	# A lost focus pauses into the menu, which holds it the same way.
	host.pause_on_focus_loss = true
	host._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(host.modal.kind, &"menu")
	held = host.countdown.remaining
	await _frames(30)
	assert_almost_eq(host.countdown.remaining, held, 0.0001)
	assert_eq(host.countdown.state, S.FROZEN)
	host.pause_on_focus_loss = false
	host.modal.chosen.emit(&"resume")
	# Opening and closing a menu again and again cannot keep postponing it: only running time counts.
	for cycle in 4:
		await _frames(3)
		host.open_map()
		await _frames(3)
		host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	await _frames(2)
	assert_lt(host.countdown.remaining, held - 0.15, "the running frames between the menus still counted")
	assert_true(host.countdown.active())
	assert_eq(kit.writer.writes.size(), writes, "holding and resuming writes nothing")
	# A held countdown still ends in the encounter once its remaining time has run.
	host.countdown.remaining = 0.1
	await _frames(12)
	assert_not_null(host.battle)
	assert_eq(kit.writer.writes.size(), writes + 1)


func test_a_failed_entry_write_offers_retry_and_launches_once() -> void:
	await _start(&"briarfen_reedway", PATROL)
	host.countdown.duration = 0.2
	assert_true(await _into_patrol_reach())
	var writes := kit.writer.writes.size()
	var before := JSON.stringify(GameState.progress.to_dict())
	kit.writer.fail = true
	await _frames(24)
	assert_null(host.battle, "no battle without a saved entry")
	assert_not_null(host.modal)
	if host.modal == null:
		return
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq(host.modal.cancel_id, &"", "the failure cannot be dismissed into play")
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(JSON.stringify(GameState.progress.to_dict()), before, "the live save is unchanged")
	assert_false(host.countdown.active(), "nothing keeps counting behind the card")
	await _frames(40)
	assert_null(host.battle, "and nothing launches behind it")
	assert_eq(host.modal.kind, &"save_failed")
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_not_null(host.battle, "Retry enters the same encounter")
	assert_eq(kit.writer.writes.size(), writes + 1, "with exactly one saved entry")
	assert_eq(GameState.progress.world.pending_entry.site_id(), PATROL)
	var battle := host.battle
	await _frames(30)
	assert_eq(host.battle, battle, "once")
	assert_eq(kit.writer.writes.size(), writes + 1)


func test_cleared_sites_area_loads_and_portals_never_count() -> void:
	await _start(&"briarfen_reedway", GUARD)
	var site := WorldKit.site(GUARD)
	var inside := host.area.point(GUARD) + Vector2(0, site.interact_radius - 12.0)
	assert_true(host.countdown.is_armed(GUARD), "armed at the approach")
	# Arriving inside a threat's reach (a load, or the return from its battle) starts nothing.
	host.player.place(inside)
	host._arm_triggers()
	await _frames(20)
	assert_false(host.countdown.active(), "armed from the feet: a threat underfoot waits until Hollow has left")
	assert_false(host.countdown.is_armed(GUARD))
	# An area load drops a running countdown and never carries it over.
	await _count_down_at(inside)
	assert_true(host.countdown.active())
	host.load_area(&"gloamstead", &"town_bell")
	assert_false(host.countdown.active())
	assert_eq([host.encounter_countdown().active, host.encounter_countdown().threat_id], [false, &""])
	await _frames(20)
	assert_null(host.battle)
	assert_false(host.countdown.active(), "the home square has no threat")
	# A portal taken while a countdown runs cancels it before the arrival is saved.
	host.load_area(&"briarfen_reedway", GUARD)
	await _count_down_at(inside)
	assert_true(host.countdown.active())
	var portal_id := host.area.portal_at(host.area.portals()[0].position)
	assert_ne(portal_id, &"")
	host.take_portal(portal_id)
	assert_false(host.countdown.active())
	assert_eq(host.area_def.id, &"gloamstead", "the portal still leads home")
	assert_null(host.battle)
	assert_null(GameState.progress.world.pending_entry)
	# A cleared site owns nothing: no countdown by standing there, none by Interact.
	host.load_area(&"briarfen_reedway", GUARD)
	host.player.place(inside)
	host.engage(site)
	host._on_battle_finished(GameState.progress.world.pending_entry, WorldKit.victory(GUARD))
	host.modal.chosen.emit(&"continue")
	assert_true(GameState.progress.world.is_cleared(GUARD))
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	var writes := kit.writer.writes.size()
	await _frames(10)
	var target := host.interaction_target()
	assert_true(target == null or target.id != GUARD, "the cleared guard offers no interaction")
	host.interact()
	await _count_down_at(inside)
	await _frames(20)
	assert_false(host.countdown.active(), "a cleared threat never counts down")
	assert_null(host.battle)
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(kit.writer.writes.size(), writes)


## Arms the threats from well away, then stands Hollow at [param inside] for two physics frames:
## an armed threat's countdown starts there.
func _count_down_at(inside: Vector2) -> void:
	host.player.place(inside + Vector2(0, 400))
	host._arm_triggers()
	host.player.place(inside)
	await _frames(2)


# --- Movement --------------------------------------------------------------------------------------

func test_tapping_into_a_wall_never_reads_as_walking() -> void:
	await _start()
	host.player.place(Vector2(64.5, 10.5) * 32)
	host.scripted_move = Vector2.RIGHT
	await _frames(90)
	host.scripted_move = Vector2.ZERO
	await _frames(4)
	assert_lt(host.player.position.x, 66 * 32.0, "resting against the reed fence")
	assert_false(host.player.moving)
	var rest := host.player.position
	var footsteps := [0]
	host.player.footstep.connect(func(_at: Vector2) -> void: footsteps[0] += 1)
	# Taps of one to four frames with pauses of one to five, as a player hammering the key does.
	# Each physics frame's result is read at the start of the next one.
	var walking := 0
	for tap in 30:
		host.scripted_move = Vector2.RIGHT
		for frame in 1 + tap % 4:
			await tree.physics_frame
			walking += int(host.player.moving or String(host.player.animation_name()).begins_with("walk_"))
		host.scripted_move = Vector2.ZERO
		for frame in 1 + tap % 5:
			await tree.physics_frame
			walking += int(host.player.moving or String(host.player.animation_name()).begins_with("walk_"))
	await _frames(2)
	walking += int(host.player.moving)
	assert_eq(walking, 0, "no tap into the fence shows a walking frame")
	assert_eq(host.player.facing, &"east", "the taps still turn Hollow to face the wall")
	assert_eq(host.player.animation_name(), &"idle_east")
	assert_lt(host.player.position.distance_to(rest), 0.5, "the feet stay where they were")
	assert_eq(footsteps[0], 0, "and no footstep sounds")
	# Real movement still walks: a short tap away from the wall, and it stops with the input.
	host.scripted_move = Vector2.LEFT
	await _frames(3)
	assert_true(host.player.moving, "a tap away from the wall walks")
	assert_eq(host.player.animation_name(), &"walk_west")
	host.scripted_move = Vector2.ZERO
	await _frames(2)
	assert_false(host.player.moving, "no input is never walking")
	# Sliding along the wall is walking: a diagonal into the fence keeps the travel along it.
	host.scripted_move = Vector2.RIGHT
	await _frames(20)
	host.scripted_move = Vector2(1, 1)
	var sliding := 0
	var along := host.player.position.y
	for frame in 12:
		await tree.physics_frame
		sliding += int(host.player.moving)
	host.scripted_move = Vector2.ZERO
	assert_gt(host.player.position.y, along + 4.0, "the feet slid along the fence")
	assert_gte(sliding, 8, "and that reads as walking")
	# With nothing in the way the whole displacement counts (the pure helper; a body outside the
	# tree has no collisions and cannot be stepped).
	var free := WorldPlayer.new()
	assert_eq(free.walked(Vector2(3, -4)), Vector2(3, -4))
	free.free()


# --- Journal, quest announcements and Bestiary Learnings ------------------------------------------

func test_the_paused_menu_opens_the_journal_and_announces_nothing() -> void:
	await _start()
	assert_empty(quest_changes, "loading a journey announces no quest")
	var writes := kit.writer.writes.size()
	host.open_menu()
	assert_not_null(host.modal.button(&"journal"), "the paused menu offers the Journal")
	host.modal.chosen.emit(&"journal")
	assert_eq(host.modal.kind, &"journal")
	assert_eq(host.mode, WorldHost.Mode.MODAL, "the world stays paused behind it")
	var journal := host.session.quests()
	assert_eq(journal.active.map(func(entry: QuestReadout) -> StringName: return entry.id), [QuestRules.BELL])
	var texts := " ".join(_texts(host.modal))
	assert_true(texts.contains(journal.active[0].title), "the journal shows the quest")
	assert_true(texts.contains(journal.active[0].objective), "and its current objective")
	for word: String in FORBIDDEN:
		assert_false(texts.contains(word), "no creature facts in the journal: %s" % word)
	host.modal.chosen.emit(&"back")
	assert_eq(host.modal.kind, &"menu", "Back returns to the paused menu")
	# Reopening it any number of times is reading: no write and no announcement.
	for again in 3:
		host.modal.chosen.emit(&"journal")
		host.modal.chosen.emit(&"back")
	host.modal.chosen.emit(&"resume")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
	assert_empty(quest_changes)
	assert_eq(kit.writer.writes.size(), writes)
	# A caller may name where Back goes (the HUD's journal button returns to the world).
	var returned := [0]
	host.open_journal(func() -> void:
		returned[0] += 1
		host._close_modal())
	host.modal.chosen.emit(&"back")
	assert_eq([returned[0], host.mode], [1, WorldHost.Mode.EXPLORE])


func test_a_new_journey_announces_its_quest_once_and_progress_announces_each_stage() -> void:
	# The first world entry of a journey created this session.
	GameState._fresh_journey = true
	await _start()
	assert_eq(quest_changes.map(func(change: QuestChange) -> Array: return [change.kind, change.quest_id]),
		[[QuestChange.Kind.ACQUIRED, QuestRules.BELL]], "the new quest is announced once")
	assert_eq(quest_changes[0].title, host.session.quests().active[0].title)
	assert_eq(kit.writer.writes.size(), 0, "announcing writes nothing: the journey's own first write recorded it")
	assert_false(GameState.take_fresh_journey(), "the announcement is spent")
	# Rebuilding the world (an area load, returning from a menu, a second host) never repeats it.
	host.load_area(&"gloamstead", &"town_bell")
	host.open_menu()
	host.modal.chosen.emit(&"resume")
	host.queue_free()
	host = null
	await tree.process_frame
	await _start()
	assert_eq(quest_changes.size(), 1, "loading or reopening never announces it again")
	# Real progress announces each stage exactly once, after its save.
	host.load_area(&"briarfen_reedway", GUARD)
	host.engage(WorldKit.site(GUARD))
	var entry := GameState.progress.world.pending_entry
	host._on_battle_finished(entry, WorldKit.victory(GUARD))
	assert_eq(quest_changes.size(), 2)
	assert_eq([quest_changes[1].kind, quest_changes[1].stage], [QuestChange.Kind.ADVANCED, QuestRules.BellStage.RESTORE])
	host._on_battle_finished(entry, WorldKit.victory(GUARD))
	assert_eq(quest_changes.size(), 2, "a repeated result announces nothing")
	host.modal.chosen.emit(&"continue")
	# A failed write announces nothing; its Retry announces once.
	kit.writer.fail = true
	assert_eq(host.session.restore_bell(&"briarfen_reedway"), ERR_FILE_CANT_WRITE)
	assert_eq(quest_changes.size(), 2)
	kit.writer.fail = false
	assert_eq(host.session.restore_bell(&"briarfen_reedway"), OK)
	assert_eq(quest_changes.size(), 3)
	assert_eq(quest_changes[2].stage, QuestRules.BellStage.RETURN)


func test_victory_shows_bestiary_learnings_once_and_only_after_the_save() -> void:
	await _start(&"briarfen_reedway", GUARD)
	host.engage(WorldKit.site(GUARD))
	var entry := GameState.progress.world.pending_entry
	# A failed victory write shows no learning: nothing was learned yet.
	kit.writer.fail = true
	host._on_battle_finished(entry, WorldKit.victory(GUARD))
	assert_eq(host.modal.kind, &"save_failed")
	assert_empty(host.victory_learnings)
	assert_empty(host.session.last_learnings)
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(host.modal.kind, &"victory")
	var learnings := host.victory_learnings.duplicate()
	assert_false(learnings.is_empty(), "the first victory over the guard teaches something")
	var texts := " ".join(_texts(host.modal))
	var ids: Array[StringName] = []
	for learning in learnings:
		assert_gt(learning.new_tier, learning.previous_tier, "only real increases are reported")
		assert_eq(learning.new_tier, int(GameState.research_level(learning.enemy_id)), "the saved tier")
		assert_false(ids.has(learning.enemy_id), "one line per enemy")
		ids.append(learning.enemy_id)
		assert_true(texts.contains(learning.name), "%s is shown on the victory card" % learning.name)
		assert_true(texts.contains(learning.new_tier_name))
	# A repeated result is a no-op: nothing is learned or shown twice.
	host._on_battle_finished(entry, WorldKit.victory(GUARD))
	assert_eq(host.modal.kind, &"victory")
	assert_empty(host.victory_learnings, "a repeated result reports no learning")
	host.modal.chosen.emit(&"continue")
	assert_empty(host.victory_learnings, "the card's facts are dropped when it closes")
	assert_eq(host.mode, WorldHost.Mode.EXPLORE)
