extends TestCase
## End-to-end V0.4 journey through the authored, dressed scenes. The real feet body walks every
## authored link in both areas (town routes, main approach past the optional patrol, bell steps,
## the outside loop, overlook, far side and the opened short return) with encounter cards, one
## battle seam, both flags and both portals. Battles resolve through the host's result seam with
## synthetic outcomes, and waypoints are scripted: this proves traversal, not human play.

var kit: WorldKit
var tree: SceneTree
var host: WorldHost


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
	await tree.process_frame
	await tree.physics_frame


## Walks the physical feet straight to each tile-centre waypoint (fractions allowed). Returns false
## when the feet are blocked; returns early when a modal opens, the area changes or [param until]
## holds. Two physics frames first let area loads and deferred collision toggles take effect.
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
			host.player.step(host.player.position.direction_to(to), 1.0 / 60.0)
			host._after_move()
		host.player.stop()
		if not reached:
			fail("feet stopped at %s on the way to tile %s in %s" % [host.player.position, tile, area_id])
			return false
	return true


func _card_open() -> bool:
	return host.modal != null and host.modal.kind == &"encounter"


func _modal_text() -> String:
	var texts := PackedStringArray()
	for label in host.modal.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for label in host.modal.find_children("*", "RichTextLabel", true, false):
		texts.append((label as RichTextLabel).text)
	return "\n".join(texts)


func _leave_patrol_card() -> void:
	assert_true(_card_open(), "the patrol presents its card on the main boards")
	if _card_open():
		assert_true(_modal_text().contains("Patrol"))
		host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_null(host.battle, "Leave launches nothing")


func test_complete_journey_walks_every_authored_link() -> void:
	await _start()
	# Gloamstead: bench, Bellkeeper, then out through the reed gate.
	assert_true(await _route([Vector2(24, 32), Vector2(15, 32)]), "square → bench")
	assert_eq(host.readout().interaction, "Use the preparation bench")
	host.interact()
	assert_eq(host.modal.kind, &"bench")
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(await _route([Vector2(24, 31), Vector2(30, 27), Vector2(26, 26)]), "bench → Bellkeeper")
	assert_eq(host.readout().interaction, "Talk to the Bellkeeper")
	host.interact()
	host.modal.chosen.emit(WorldRules.ACT_LEAVE)
	assert_true(await _route([Vector2(32, 32), Vector2(47, 30), Vector2(58, 26), Vector2(63, 26), Vector2(75, 26)],
		func() -> bool: return host.area_def.id != &"gloamstead"), "square → reed gate portal")
	assert_eq(host.area_def.id, &"briarfen_reedway")
	# Main approach: the optional patrol's card, Leave, then around the group to the junction.
	assert_true(await _route([Vector2(22, 67), Vector2(26, 59), Vector2(27, 41)], _card_open), "entry → fork → patrol")
	_leave_patrol_card()
	assert_true(await _route([Vector2(26, 40), Vector2(26, 38.56), Vector2(38, 27), Vector2(60, 25)]), "around the patrol to the junction")
	assert_null(host.modal, "the junction itself stays free")
	# Bell steps: the guard's card, one entry and a committed victory.
	assert_true(await _route([Vector2(65, 20)], _card_open), "junction → guard on the bell steps")
	assert_true(_card_open())
	var encounter_position := host.player.position
	host.modal.chosen.emit(WorldRules.ACT_ENGAGE)
	assert_not_null(host.battle)
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
	assert_null(host.modal, "the outside loop passes both groups without a card")
	assert_true(await _route([Vector2(27, 41)], _card_open), "fork → patrol again")
	_leave_patrol_card()
	assert_true(await _route([Vector2(26, 40), Vector2(26, 38.56), Vector2(38, 27), Vector2(60, 25)]), "patrol → junction")
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
			assert_true(saved.is_discovered(landmark.id), "%s/%s was discovered on the way" % [area.id, landmark.id])
	assert_eq(GameState.progress.battles_won, 1)
	assert_eq(GameState.progress.battles_lost, 0)
