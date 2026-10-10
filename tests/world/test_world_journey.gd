extends TestCase
## End-to-end V0.4 journey through the authored, dressed scenes. The real feet body walks every
## authored link in both areas (town routes, main approach past the optional patrol, bell steps,
## the outside loop, overlook, far side and the opened short return) with the move-away encounter
## countdown (playtest revision: it replaced the Engage card), one battle seam, both flags and both
## portals. Battles resolve through the host's result seam with synthetic outcomes, and waypoints
## are scripted at walking speed in simulated 60 Hz steps: this proves traversal, not human play.

const STEP := 1.0 / 60.0

var kit: WorldKit
var tree: SceneTree
var host: WorldHost
## The threat of every countdown the host started, in order.
var countdowns: Array[StringName] = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)


func after_each() -> void:
	if host != null:
		host.queue_free()
		host = null
	kit.restore()


func _start() -> void:
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	countdowns.clear()
	host.encounter_countdown_changed.connect(func(readout: EncounterCountdownReadout) -> void:
		if readout.state == EncounterCountdown.State.COUNTING:
			countdowns.append(readout.threat_id))
	await tree.process_frame
	await tree.physics_frame


## Walks the physical feet straight to each tile-centre waypoint (fractions allowed). Returns false
## when the feet are blocked; returns early when a modal opens, a battle starts, the area changes or
## [param until] holds. Two physics frames first let area loads and deferred collision toggles take
## effect. Every step is one sixtieth of a second for the countdown.
func _route(tiles: Array, until: Callable = Callable()) -> bool:
	await tree.physics_frame
	await tree.physics_frame
	var area_id := host.area_def.id
	for tile: Vector2 in tiles:
		var to := (tile + Vector2(0.5, 0.5)) * 32.0
		var reached := false
		for step in 3000:
			if (until.is_valid() and until.call()) or host.mode != WorldHost.Mode.EXPLORE or host.area_def.id != area_id:
				host.player.stop()
				return until.is_valid() and until.call()
			if host.player.position.distance_to(to) < 3.0:
				reached = true
				break
			host.player.step(host.player.position.direction_to(to), STEP)
			host._after_move(STEP)
		host.player.stop()
		if not reached:
			fail("feet stopped at %s on the way to tile %s in %s" % [host.player.position, tile, area_id])
			return false
	return true


func _counting() -> bool:
	return host.countdown.active()


## Stands still until the running countdown reaches zero and the host launches its battle.
func _stand_until_battle() -> bool:
	for step in 400:
		if host.battle != null:
			return true
		host.player.step(Vector2.ZERO, STEP)
		host._after_move(STEP)
	return host.battle != null


func _modal_text() -> String:
	var texts := PackedStringArray()
	for label in host.modal.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for label in host.modal.find_children("*", "RichTextLabel", true, false):
		texts.append((label as RichTextLabel).text)
	return "\n".join(texts)


## The patrol's countdown runs on the main boards; walking on [param around] the group leaves its
## reach in time, which cancels it for free.
func _pass_the_patrol(around: Array, label: String) -> void:
	assert_true(_counting(), "the patrol starts its countdown on the main boards")
	assert_eq(host.encounter_countdown().threat_id, &"reedway_patrol")
	assert_true(host.encounter_countdown().threat_label.contains("Patrol"))
	assert_null(host.modal, "no card interrupts the walk")
	var writes := kit.writer.writes.size()
	assert_true(await _route(around), label)
	assert_false(_counting(), "walking on out of its reach cancels the countdown")
	assert_null(host.battle, "passing by launches nothing")
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(kit.writer.writes.size(), writes, "and records nothing")


func test_complete_journey_walks_every_authored_link() -> void:
	await _start()
	# Gloamstead: bench, Bellkeeper, then out through the reed gate.
	assert_true(await _route([Vector2(24, 32), Vector2(15, 32)]), "square → bench")
	assert_eq(host.readout().interaction, "Use the forge")
	host.interact()
	assert_eq(host.modal.kind, &"crafting")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(await _route([Vector2(24, 31), Vector2(30, 27), Vector2(26, 26)]), "bench → Bellkeeper")
	assert_eq(host.readout().interaction, "Talk to the Bellkeeper")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(await _route([Vector2(32, 32), Vector2(47, 30), Vector2(58, 26), Vector2(63, 26), Vector2(75, 26)],
		func() -> bool: return host.area_def.id != &"gloamstead"), "square → reed gate portal")
	assert_eq(host.area_def.id, &"briarfen_reedway")
	# Main approach: the optional patrol's countdown, then on around the group to the junction.
	assert_true(await _route([Vector2(22, 67), Vector2(26, 59), Vector2(27, 41)], _counting), "entry → fork → patrol")
	await _pass_the_patrol([Vector2(26, 40), Vector2(26, 38.56), Vector2(38, 27), Vector2(60, 25)],
		"around the patrol to the junction")
	assert_null(host.modal, "the junction itself stays free")
	assert_false(_counting())
	# Bell steps: the guard's countdown runs out where Hollow stands: one entry, a committed victory.
	assert_true(await _route([Vector2(65, 20)], _counting), "junction → guard on the bell steps")
	assert_eq(host.encounter_countdown().threat_id, &"bell_guard")
	var entry_writes := kit.writer.writes.size()
	assert_true(_stand_until_battle(), "staying on the steps for the whole countdown starts the encounter")
	assert_not_null(host.battle)
	assert_eq(kit.writer.writes.size(), entry_writes + 1, "one saved entry")
	var encounter_position := host.player.position
	host._on_battle_finished(GameState.progress.world.pending_entry, WorldKit.victory(&"bell_guard"))
	assert_eq(host.modal.kind, &"victory")
	host.modal.chosen.emit(&"continue")
	assert_eq(host.player.position, encounter_position, "victory retains the exact approach position during this session")
	assert_true(await _route([Vector2(60, 25), Vector2(65, 20), Vector2(65, 16)]), "cleared steps → wayside bell")
	assert_eq(host.readout().interaction, "Examine the wayside bell")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_RING)
	assert_true(GameState.progress.world.wayside_bell_restored)
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_RETURN)
	# The outside loop backwards to the fork, then the main approach north again past the patrol.
	assert_true(await _route([Vector2(65, 20), Vector2(60, 25), Vector2(38, 13), Vector2(10, 22), Vector2(10, 54),
		Vector2(26, 59)]), "bell → outside loop → fork")
	assert_null(host.modal)
	assert_null(host.battle)
	assert_eq(countdowns, [&"reedway_patrol", &"bell_guard"] as Array[StringName],
		"the outside loop passes both groups without starting a countdown")
	assert_true(await _route([Vector2(27, 41)], _counting), "fork → patrol again")
	await _pass_the_patrol([Vector2(26, 40), Vector2(26, 38.56), Vector2(38, 27), Vector2(60, 25)], "patrol → junction")
	# Overlook and listening stones, then the far side to the latch.
	assert_true(await _route([Vector2(68, 35), Vector2(77, 33), Vector2(84, 40)]), "junction → overlook → stones")
	assert_eq(host.readout().interaction, "Look at the listening stones")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(await _route([Vector2(77, 33), Vector2(68, 35), Vector2(65, 50), Vector2(65, 61)]), "overlook → far side")
	assert_eq(host.readout().interaction, WorldCopy.ACTION_OPEN_LATCH)
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_OPEN_LATCH)
	assert_true(GameState.progress.world.return_latch_open)
	assert_null(host.modal)
	# The short return through the opened gate, the entry portal and home.
	assert_true(await _route([Vector2(65, 72), Vector2(44, 76), Vector2(22, 76), Vector2(22, 85)],
		func() -> bool: return host.area_def.id != &"briarfen_reedway"), "short return → entry portal")
	assert_eq(host.area_def.id, &"gloamstead")
	assert_eq(host.player.position, host.area.anchor(&"reed_gate"))
	assert_true(await _route([Vector2(58, 26), Vector2(47, 30), Vector2(33, 32)]), "gate → square")
	assert_true((host.area.get_node("DepthSorted/TownBell/Answering") as Node2D).visible, "home bell answers")
	assert_true((host.area.get_node("DepthSorted/SquareLamp/Lit") as Node2D).visible, "home lamp lit")
	assert_eq(host.readout().objective, WorldCopy.OBJECTIVE_DONE)
	assert_true(await _route([Vector2(30, 32), Vector2(30, 27), Vector2(26, 26)]), "square → Bellkeeper")
	host.interact()
	assert_true(_modal_text().contains(WorldCopy.BELLKEEPER_AFTER[0]), "the Bellkeeper acknowledges the answer")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	# Everything above reached the last successful write.
	var saved := ProgressState.from_dict(kit.writer.last()).world
	assert_true(saved.wayside_bell_restored and saved.return_latch_open)
	assert_true(saved.is_cleared(&"bell_guard"))
	assert_false(saved.is_cleared(&"reedway_patrol"), "the bypassed patrol stays available")
	for area in WorldDefinition.load_default().areas:
		for path in area.paths:
			assert_true(saved.links.has(path.id), "walked link %s/%s is charted" % [area.id, path.id])
		for landmark in area.landmarks:
			if landmark.id == &"stillroom_table":
				continue # Optional station has its own reachability test.
			if WorldRules.perceivable(landmark, saved, WorldDefinition.load_default()):
				assert_true(saved.is_discovered(landmark.id), "%s/%s was discovered on the way" % [area.id, landmark.id])
			else:
				assert_false(saved.is_discovered(landmark.id), "the optional unsolved secret stays hidden")
	assert_eq(GameState.progress.battles_won, 1)
	assert_eq(GameState.progress.battles_lost, 0)
	assert_eq(countdowns, [&"reedway_patrol", &"bell_guard", &"reedway_patrol"] as Array[StringName],
		"three countdowns on the whole journey; only the guard's ran out")
