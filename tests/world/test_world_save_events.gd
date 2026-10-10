extends TestCase
## V0.5 UI autosave ownership: WorldSession.commit() publishes the one EventBus.game_saved(slot, true)
## after the candidate was adopted, for every world write and never for a failure, a rejection or a
## no-op; the host adds no notice of its own (automatic writes show the quiet icon, a manual save its
## one card), hides cards during battle and quits only after a successful save. Settings difficulty
## becomes the journey's and entries capture it.

var kit: WorldKit
var tree: SceneTree
var host: WorldHost
var saved: Array = []
var _difficulty: int
var _slot: int


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	saved.clear()
	_difficulty = int(Settings.data.tactical_difficulty)
	_slot = GameState.active_slot
	EventBus.game_saved.connect(_on_saved)


func after_each() -> void:
	EventBus.game_saved.disconnect(_on_saved)
	if is_instance_valid(host):
		host.queue_free()
	host = null
	if int(Settings.data.tactical_difficulty) != _difficulty:
		Settings.set_value("tactical_difficulty", _difficulty)
	GameState.active_slot = _slot
	kit.restore()


## Records each event with the live progress it saw, to prove it came after adoption.
func _on_saved(slot: int, ok: bool) -> void:
	saved.append({"slot": slot, "ok": ok, "live": JSON.stringify(GameState.progress.to_dict()),
		"written": JSON.stringify(kit.writer.last())})


func _start(area_id: StringName = &"", anchor: StringName = &"") -> void:
	if area_id != &"":
		GameState.progress.world.area = area_id
		GameState.progress.world.anchor = anchor
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	await tree.process_frame
	await tree.physics_frame


func _save_cards() -> int:
	return (host.notices._cards + host.notices._pending).filter(func(entry: Dictionary) -> bool: return entry.key == &"save").size()


func test_every_world_write_publishes_one_save_event_after_adoption() -> void:
	var session := kit.session()
	session.open()
	GameState.active_slot = 0
	# Area arrival, a story interaction, encounter entry and victory, the bell and latch, gathering,
	# a rune strike, equipment, the arrangement, the manual save and Reset journey.
	var writes: Array[Callable] = [
		func() -> Error: return session.arrive(&"briarfen_reedway", &"reedway_entry"),
		func() -> Error: return session.complete_interaction(&"gloamstead", &"bellkeeper"),
		func() -> Error: return OK if session.begin_entry(&"bell_guard", &"bell_guard") != null else FAILED,
		func() -> Error: return session.commit_victory(GameState.progress.world.pending_entry, WorldKit.victory(&"bell_guard")),
		func() -> Error: return session.restore_bell(&"briarfen_reedway"),
		func() -> Error: return session.open_latch(&"briarfen_reedway", &"short_return"),
		func() -> Error: return session.gather(&"briarfen_reedway", &"iron_seam"),
		func() -> Error: return session.strike_rune(&"briarfen_reedway", &"rhythm_stone_low"),
		func() -> Error: return session.equip(Enums.EquipSlot.CHARM, &"storm_salt_charm"),
		func() -> Error: return session.unequip(Enums.EquipSlot.GARB),
		func() -> Error: return session.arrange_action(5, &"kindle"),
		func() -> Error: return session.save(),
		func() -> Error: return session.reset_journey(),
	]
	for index in writes.size():
		var count := saved.size()
		var err: Error = writes[index].call()
		assert_eq(err, OK, "write %d succeeds" % index)
		assert_eq(saved.size(), count + 1, "write %d: one event per successful commit" % index)
		var event: Dictionary = saved.back()
		assert_eq([event.slot, event.ok], [0, true])
		assert_eq(event.live, JSON.stringify(GameState.progress.to_dict()), "write %d: published after adoption" % index)
		assert_eq(event.written, event.live, "the event names the state that is on disk")
	assert_eq(saved.size(), kit.writer.writes.size(), "every write announced once, none twice")


func test_failures_rejections_and_no_ops_publish_nothing() -> void:
	var session := kit.session()
	session.open()
	kit.writer.fail = true
	for command: Callable in [
			func() -> Error: return session.arrive(&"briarfen_reedway", &"reedway_entry"),
			func() -> Error: return session.save(),
			func() -> Error: return session.choose_weapon(&"reedbow"),
			func() -> Error: return session.arrange_action(5, &"kindle"),
			func() -> Error: return session.gather(&"briarfen_reedway", &"iron_seam")]:
		assert_ne(command.call(), OK)
	kit.writer.fail = false
	assert_eq(session.gather(&"briarfen_reedway", &"iron_seam"), OK)
	var count := saved.size()
	for command: Callable in [
			func() -> Error: return session.equip(Enums.EquipSlot.CHARM, &"no_such_charm"),
			func() -> Error: return session.purchase(&"forge.first_fitting"),
			func() -> Error: return session.gather(&"briarfen_reedway", &"iron_seam"),
			func() -> Error: return session.arrange_action(6, &"kindle"),
			func() -> Error: return session.choose_weapon(&"pilgrims_edge"),
			func() -> Error: return session.prepare_potion(0, &"mending_draught"),
			func() -> Error: return session.arrange_action(0, &"sword_strike"),
			func() -> Error: return session.reconcile()]:
		command.call()
	assert_eq(saved.size(), count, "rejections and no-ops publish nothing")
	assert_eq(kit.writer.writes.size(), count)


func test_host_adds_no_notice_of_its_own_and_hides_cards_in_battle() -> void:
	await _start(&"briarfen_reedway", &"bell_guard")
	host.notices.set_process(false)
	var origins: Array[int] = []
	var record := func(fact: SaveFact) -> void: origins.append(fact.origin)
	EventBus.save_completed.connect(record)
	# Arrival through a portal is an automatic save: one event, the quiet icon and no card.
	host.take_portal(&"reedway_entry")
	assert_eq(saved.size(), 1)
	assert_eq(origins, [SaveFact.Origin.AUTOMATIC] as Array[int])
	assert_eq(_save_cards(), 0, "no card, and no duplicate host push")
	assert_gt(host.notices._autosave_life, 0.0, "the quiet save icon")
	# A failed manual save shows nothing; its retry shows the one manual confirmation card.
	_clear_cards()
	host.open_menu()
	kit.writer.fail = true
	host.modal.chosen.emit(&"save")
	assert_eq(host.modal.kind, &"save_failed")
	assert_eq([_save_cards(), host.notices._autosave_life], [0, 0.0])
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(_save_cards(), 1)
	assert_eq(origins.back(), SaveFact.Origin.MANUAL)
	assert_eq(host.modal.kind, &"menu")
	host._close_modal()
	# The entry is saved before launch; nothing covers the battle, and the receipts show afterwards.
	_clear_cards()
	await _start_battle_at_guard()
	assert_eq(host.mode, WorldHost.Mode.BATTLE)
	assert_false(host.notices.visible, "no card over the battle")
	var entry := GameState.progress.world.pending_entry
	host._on_battle_finished(entry, WorldKit.victory(&"bell_guard"))
	assert_eq(host.modal.kind, &"victory")
	assert_true(host.notices.visible)
	assert_eq(_save_cards(), 0, "automatic saves never show a card")
	assert_true((host.notices._cards + host.notices._pending).any(func(card: Dictionary) -> bool: return card.key == &""),
		"the salvage receipts arrive as their own cards")
	assert_eq(saved.size(), kit.writer.writes.size())
	assert_eq(origins.size(), saved.size(), "one origin fact per write")
	EventBus.save_completed.disconnect(record)


## Drops the notice cards only; the permanent save icon and operation feedback stay installed.
func _clear_cards() -> void:
	for entry in host.notices._cards:
		entry.node.queue_free()
	host.notices._cards.clear()
	host.notices._pending.clear()
	host.notices._autosave_life = 0.0


func _start_battle_at_guard() -> void:
	host.load_area(&"briarfen_reedway", &"bell_guard")
	host.engage(load("res://data/world/first_footsteps.tres").find_landmark(&"bell_guard")[1])
	await tree.process_frame


func test_save_and_quit_waits_for_success_and_retries_the_same_save() -> void:
	await _start(&"briarfen_reedway", &"listening_stones")
	var quits: Array[int] = []
	var titles: Array[int] = []
	host.quit_game = func() -> void: quits.append(1)
	host.leave_to_title = func() -> void: titles.append(1)
	# Save and return to title follows the same rule.
	host.open_menu()
	kit.writer.fail = true
	host.modal.chosen.emit(&"title")
	assert_eq(host.modal.kind, &"save_failed")
	assert_true(titles.is_empty(), "never leaves before the save succeeded")
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(titles.size(), 1)
	saved.clear()
	var anchor := [GameState.progress.world.area, GameState.progress.world.anchor]
	host.open_menu()
	kit.writer.fail = true
	host.modal.chosen.emit(&"quit")
	assert_eq(host.modal.kind, &"save_failed")
	assert_true(quits.is_empty(), "never quits before the save succeeded")
	assert_true(saved.is_empty())
	kit.writer.fail = false
	host.modal.chosen.emit(&"retry")
	assert_eq(quits.size(), 1, "the retry saves, then quits once")
	assert_eq(saved.size(), 1)
	var written: Dictionary = kit.writer.last()
	assert_eq([StringName(written.world.area), StringName(written.world.anchor)], anchor, "the safe anchor is kept")


func test_settings_difficulty_becomes_the_journeys_and_entries_capture_it() -> void:
	await _start()
	assert_eq(GameState.progress.difficulty, Enums.TacticalDifficulty.ADVENTURER)
	Settings.set_value("tactical_difficulty", Enums.TacticalDifficulty.TACTICIAN)
	assert_eq(GameState.progress.difficulty, Enums.TacticalDifficulty.TACTICIAN, "the journey follows at once")
	assert_eq(kit.writer.writes.size(), 0, "in the live state, like map knowledge")
	assert_eq(host.session.save(), OK)
	assert_eq(int(kit.writer.last().campaign.difficulty), Enums.TacticalDifficulty.TACTICIAN, "the next commit saves it")
	var entry := host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(int(entry.to_dict().difficulty), Enums.TacticalDifficulty.TACTICIAN)
	var setup := entry.build_setup(Database.registry, Database.library)
	assert_eq(setup.difficulty, Database.registry.difficulty(Enums.TacticalDifficulty.TACTICIAN))
	# A change while the entry is pending reaches the journey but never the captured retry.
	Settings.set_value("tactical_difficulty", Enums.TacticalDifficulty.STORY)
	assert_eq(GameState.progress.difficulty, Enums.TacticalDifficulty.STORY)
	var retry := EncounterEntry.from_dict(GameState.progress.world.pending_entry.to_dict())
	assert_eq(retry.build_setup(Database.registry, Database.library).difficulty,
		Database.registry.difficulty(Enums.TacticalDifficulty.TACTICIAN))
	assert_false(host.session.follow_difficulty(Enums.TacticalDifficulty.STORY), "already the journey's")
	assert_false(host.session.follow_difficulty(7), "not a difficulty")
	# The journey's own difficulty is what an entry captures, whatever Settings shows at that moment.
	assert_eq(host.session.return_home(entry), OK)
	GameState.progress.difficulty = Enums.TacticalDifficulty.ADVENTURER
	Settings.data.tactical_difficulty = Enums.TacticalDifficulty.TACTICIAN
	var own := host.session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	Settings.data.tactical_difficulty = Enums.TacticalDifficulty.STORY
	assert_eq(int(own.to_dict().difficulty), Enums.TacticalDifficulty.ADVENTURER)
