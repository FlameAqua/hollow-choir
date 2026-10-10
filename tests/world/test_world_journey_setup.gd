extends TestCase
## V0.5 UI title and saves through the real files (isolated QA home): New Journey writes only an
## explicitly chosen slot and adopts it after the write; occupied slots need a deliberate
## replacement; failed writes and cancels keep every save and the live journey; restart resumes
## the right slot and difficulty; Continue lists readable journeys newest first and survives empty,
## damaged and newer saves without crashing or logging; a stale load changes nothing.

var kit: WorldKit
var tree: SceneTree
var menu: MainMenu
var _slot: int
var _saves: Dictionary
var _difficulty: int
var saved: Array = []
var entered := 0


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	_slot = GameState.active_slot
	_difficulty = int(Settings.data.tactical_difficulty)
	_saves = {}
	for index in SaveManager.SLOT_COUNT:
		if SaveManager.has_slot(index):
			_saves[index] = FileAccess.get_file_as_string(SaveManager.slot_path(index))
		SaveManager.delete_slot(index)
	saved.clear()
	entered = 0
	EventBus.game_saved.connect(_on_saved)


func after_each() -> void:
	EventBus.game_saved.disconnect(_on_saved)
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null
	for index in SaveManager.SLOT_COUNT:
		SaveManager.delete_slot(index)
		if _saves.has(index):
			var file := FileAccess.open(SaveManager.slot_path(index), FileAccess.WRITE)
			file.store_string(_saves[index])
	GameState.active_slot = _slot
	if int(Settings.data.tactical_difficulty) != _difficulty:
		Settings.set_value("tactical_difficulty", _difficulty)
	kit.restore()


func _on_saved(slot: int, ok: bool) -> void:
	saved.append([slot, ok])


func _frames(count := 4) -> void:
	for frame in count:
		await tree.process_frame


func _title() -> void:
	menu = load(SceneRouter.MAIN_MENU).instantiate()
	menu.enter_world = func() -> void: entered += 1
	tree.root.add_child(menu)
	await _frames()


## Writes a readable journey into [param slot] with [param won] victories at [param when].
static func _journey(slot: int, won: int, when: int, weapon: StringName = &"mire_maul") -> void:
	var progress := ProgressState.new()
	progress.battles_won = won
	progress.loadout_weapon = weapon
	progress.difficulty = Enums.TacticalDifficulty.STORY
	SaveManager.write_progress(slot, progress)
	var envelope := SaveManager.read_json(SaveManager.slot_path(slot))
	envelope.saved_at_unix = when
	SaveManager.write_json_atomic(SaveManager.slot_path(slot), envelope)


static func _raw(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_DIR))
	var file := FileAccess.open(SaveManager.slot_path(slot), FileAccess.WRITE)
	file.store_string(text)


func _modal_text() -> String:
	return _card_text(menu._modal)


static func _card_text(card: Control) -> String:
	var parts := PackedStringArray()
	for node in card.find_children("*", "Label", true, false) + card.find_children("*", "RichTextLabel", true, false):
		parts.append(node.get("text"))
	return "\n".join(parts)


static func _bytes(slot: int) -> String:
	return FileAccess.get_file_as_string(SaveManager.slot_path(slot)) if SaveManager.has_slot(slot) else ""


func _assert_slot_cards_visible() -> void:
	var viewport_rect := menu._modal._content_scroll.get_global_rect()
	for index in SaveManager.SLOT_COUNT:
		var card := menu._modal.find_child("JourneySlot_%d" % index, true, false) as Control
		assert_true(viewport_rect.encloses(card.get_global_rect()), "each journey card is fully readable without scrolling: %s inside %s" % [card.get_global_rect(), viewport_rect])


func test_start_journey_writes_the_chosen_slot_adopts_it_and_saves_once() -> void:
	var result := GameState.start_journey({"difficulty": Enums.TacticalDifficulty.TACTICIAN, "preset_id": &"reedbow", "slot": 1})
	assert_true(result.ok(), result.text())
	assert_eq([SaveManager.has_slot(0), SaveManager.has_slot(1), SaveManager.has_slot(2)], [false, true, false])
	assert_eq(GameState.active_slot, 1)
	assert_true(GameState._session_resumed, "the world will not reload another slot")
	assert_eq([GameState.progress.loadout_weapon, GameState.progress.difficulty], [&"reedbow", Enums.TacticalDifficulty.TACTICIAN])
	assert_eq(int(Settings.data.tactical_difficulty), Enums.TacticalDifficulty.TACTICIAN, "Settings shows the journey's difficulty")
	assert_eq(saved, [[1, true]], "one save event, after adoption")
	var summary := SaveManager.summary(1)
	assert_eq([summary.state, summary.weapon_name, summary.difficulty_name, summary.starter_preset, summary.battles_won],
		[SaveSlotSummary.State.READY, "Reedbow", "Tactician", &"reedbow", 0])
	assert_true(summary.saved_at_text.ends_with(" UTC"), "an explicit timezone")
	# Restart: the next run resumes this slot with its own difficulty and starter.
	Settings.set_value("tactical_difficulty", Enums.TacticalDifficulty.STORY)
	GameState.new_game()
	GameState._session_resumed = false
	assert_true(GameState.resume_session())
	assert_eq([GameState.progress.loadout_weapon, GameState.progress.difficulty, GameState.progress.starter_preset],
		[&"reedbow", Enums.TacticalDifficulty.TACTICIAN, &"reedbow"])
	assert_eq(int(Settings.data.tactical_difficulty), Enums.TacticalDifficulty.TACTICIAN, "loading applies it again")


func test_occupied_slots_cancels_and_failed_writes_never_overwrite() -> void:
	_journey(0, 4, 500)
	var existing := _bytes(0)
	GameState.active_slot = 0
	var live := JSON.stringify(GameState.progress.to_dict())
	var options := {"difficulty": 1, "preset_id": &"pilgrims_edge", "slot": 0}
	var occupied := GameState.start_journey(options)
	assert_eq(occupied.reason, JourneyResult.Reason.SLOT_OCCUPIED)
	options.replace = true
	var failed := GameState.start_journey(options, func(_slot_index: int, _candidate: ProgressState) -> Error: return ERR_FILE_CANT_WRITE)
	assert_eq(failed.reason, JourneyResult.Reason.WRITE_FAILED)
	assert_eq(_bytes(0), existing, "the save on disk is untouched")
	assert_eq(JSON.stringify(GameState.progress.to_dict()), live, "the live journey is untouched")
	assert_eq(GameState.active_slot, 0)
	assert_true(saved.is_empty(), "no save event for a rejection or a failure")
	# The explicitly confirmed replacement retries the same request.
	var replaced := GameState.start_journey(options)
	assert_true(replaced.ok() and replaced.replaced)
	assert_ne(_bytes(0), existing)
	assert_eq(SaveManager.summary(0).battles_won, 0, "a fresh journey")
	assert_eq(saved, [[0, true]])


func test_summaries_survive_empty_damaged_and_newer_saves_without_errors() -> void:
	_raw(0, "{ not json")
	_raw(1, JSON.stringify({"save_version": 1, "saved_at_unix": 10, "data": 5}))
	_raw(2, JSON.stringify({"save_version": SaveMigrator.CURRENT_VERSION + 1, "saved_at_unix": 20, "data": {}}))
	var states := SaveManager.summaries().map(func(entry: SaveSlotSummary) -> int: return entry.state)
	assert_eq(states, [SaveSlotSummary.State.UNREADABLE, SaveSlotSummary.State.UNREADABLE, SaveSlotSummary.State.UNSUPPORTED])
	assert_eq(SaveManager.summary(2).reason_text, WorldCopy.SAVE_SLOT_UNSUPPORTED)
	assert_true(SaveManager.journeys().is_empty(), "nothing loadable")
	for entry in SaveManager.summaries():
		assert_true(entry.occupied(), "damaged files still count as occupied")
	# Broken summary fields inside valid JSON: readable with safe defaults, and it loads.
	_raw(1, JSON.stringify({"save_version": 1, "saved_at_unix": "soon", "game_version": 5,
		"data": {"stats": "lots", "loadout": [], "campaign": {"difficulty": "hard"}, "weapon_mastery": 7,
			"bestiary": {"points": {"bogshell": "many"}, "sources": {"bogshell": 3}}, "world": {"entry_serial": {}},
			"familiars": "crow", "regions": {"events": {"briarfen": 1}}, "companions": {"mara": 2}}}))
	var broken := SaveManager.summary(1)
	assert_eq([broken.state, broken.saved_at_unix, broken.saved_at_text, broken.battles_won, broken.weapon_id, broken.difficulty],
		[SaveSlotSummary.State.READY, 0, WorldCopy.SAVE_TIME_UNKNOWN, 0, &"", Enums.TacticalDifficulty.ADVENTURER])
	assert_eq(SaveManager.load_slot(1), OK, "a damaged field loads as its default instead of crashing")
	assert_eq(GameState.active_slot, 1)
	assert_eq(GameState.progress.loadout_weapon, &"pilgrims_edge")
	# A failed load changes neither the live journey nor the active slot.
	var live := JSON.stringify(GameState.progress.to_dict())
	expect_engine_errors(3) # Explicit loads still log: invalid JSON twice, the newer version once.
	assert_eq(SaveManager.load_slot(0), ERR_FILE_CANT_READ)
	assert_eq(SaveManager.load_slot(2), ERR_FILE_UNRECOGNIZED)
	assert_eq([GameState.active_slot, JSON.stringify(GameState.progress.to_dict())], [1, live])


func test_continue_lists_newest_first_and_a_stale_load_changes_nothing() -> void:
	_journey(0, 1, 0)
	_journey(1, 2, 300)
	_journey(2, 3, 300)
	assert_eq(SaveManager.journeys().map(func(entry: SaveSlotSummary) -> int: return entry.slot), [1, 2, 0],
		"newest first, ties by slot number, unknown times last")
	assert_eq(SaveManager.summary(0).saved_at_text, WorldCopy.SAVE_TIME_UNKNOWN)
	assert_eq(SaveManager.summary(1).saved_at_text, "1970-01-01 00:05 UTC")
	_raw(2, "{ damaged")
	await _title()
	assert_false(menu._first_button.disabled)
	menu._open_save_picker()
	await _frames()
	var first := menu._modal.find_child("SaveSlot_1", true, false) as Button
	assert_true(_card_text(first).contains("Journey 2") and _card_text(first).contains("UTC") and _card_text(first).contains("Story"))
	var damaged := menu._modal.find_child("SaveSlot_2", true, false) as Button
	assert_true(damaged.disabled, "a damaged save is shown but cannot be chosen")
	assert_true(_card_text(damaged).contains(WorldCopy.SAVE_SLOT_UNREADABLE))
	var before := JSON.stringify(GameState.progress.to_dict())
	assert_eq(GameState.active_slot, _slot, "browsing changes nothing")
	SaveManager.delete_slot(1) # The file disappears after the list was built.
	first.pressed.emit()
	await _frames()
	assert_eq(menu._modal.kind, &"saves")
	assert_eq(menu._modal._status.text, WorldCopy.SAVE_LOAD_FAILED)
	assert_null(menu._modal.find_child("SaveSlot_1", true, false), "the list is rebuilt from the files")
	assert_eq([GameState.active_slot, JSON.stringify(GameState.progress.to_dict())], [_slot, before])
	assert_eq(entered, 0)
	(menu._modal.find_child("SaveSlot_0", true, false) as Button).pressed.emit()
	assert_eq([entered, GameState.active_slot], [1, 0], "a successful load enters the world")


func test_new_journey_title_flow_chooses_a_slot_and_confirms_replacement() -> void:
	_journey(1, 5, 900)
	await _title()
	menu._open_new_journey()
	await _frames()
	(menu._modal.find_child("Difficulty_2", true, false) as Button).pressed.emit()
	(menu._modal.find_child("Preset_mire_maul", true, false) as Button).pressed.emit()
	menu._modal.chosen.emit(&"start")
	await _frames()
	assert_eq(menu._modal.kind, &"journey_slot")
	assert_eq(tree.root.gui_get_focus_owner(), menu._modal.find_child("JourneySlot_0", true, false), "the first free slot")
	assert_true(_card_text(menu._modal.find_child("JourneySlot_1", true, false)).contains(WorldCopy.JOURNEY_REPLACE_HINT))
	assert_true(_modal_text().contains("Mire Maul · Tactician"), "the save step recaps the requested setup")
	# A failed write stays on the slot list with the reason; choosing again retries.
	menu.journey_writer = func(_slot_index: int, _candidate: ProgressState) -> Error: return ERR_FILE_CANT_WRITE
	(menu._modal.find_child("JourneySlot_2", true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(menu._modal.kind, &"journey_slot")
	assert_eq(menu._modal._status.text, WorldCopy.JOURNEY_WRITE_FAILED)
	var recap := menu._modal.find_child("JourneyRecap", true, false) as Control
	assert_false(recap.get_global_rect().intersects(menu._modal._content_scroll.get_global_rect()), "the requested setup stays above scrolling choices after a failure")
	_assert_slot_cards_visible()
	assert_false(SaveManager.has_slot(2))
	assert_eq(entered, 0)
	menu.journey_writer = Callable()
	(menu._modal.find_child("JourneySlot_2", true, false) as Button).pressed.emit()
	assert_eq(entered, 1, "the journey starts after its write")
	assert_eq([GameState.active_slot, GameState.progress.loadout_weapon, GameState.progress.difficulty],
		[2, &"mire_maul", Enums.TacticalDifficulty.TACTICIAN])
	# A stale list: Journey 3 was free when the list was built, and a save appears there before the
	# click. The request is rejected against the current files; nothing is overwritten.
	SaveManager.delete_slot(2)
	menu._open_new_journey()
	menu._modal.chosen.emit(&"start")
	await _frames()
	var listed := menu._modal.find_child("JourneySlot_2", true, false) as Button
	assert_false(_card_text(listed).contains(WorldCopy.JOURNEY_REPLACE_HINT), "listed as free")
	_journey(2, 7, 50)
	var behind := _bytes(2)
	listed.pressed.emit()
	await _frames()
	assert_eq(menu._modal.kind, &"journey_slot", "back on the refreshed list")
	assert_eq(menu._modal._status.text, WorldCopy.JOURNEY_SLOT_OCCUPIED % 3)
	assert_eq(_bytes(2), behind, "the save that appeared is untouched")
	assert_eq(entered, 1)
	assert_true(_card_text(menu._modal.find_child("JourneySlot_2", true, false)).contains(WorldCopy.JOURNEY_REPLACE_HINT))
	# With every slot occupied only a deliberate, confirmed replacement writes.
	_journey(0, 1, 100)
	var victim := _bytes(1)
	menu._open_new_journey()
	menu._modal.chosen.emit(&"start")
	await _frames()
	assert_true(_modal_text().contains(WorldCopy.JOURNEY_SLOTS_FULL), "every slot is occupied")
	_assert_slot_cards_visible()
	(menu._modal.find_child("JourneySlot_1", true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(menu._modal.kind, &"journey_replace")
	assert_eq(tree.root.gui_get_focus_owner(), menu._modal.button(&"cancel"), "Cancel is focused")
	assert_true(_card_text(menu._modal.find_child("ReplacementJourney", true, false)).contains("5 victories"), "the exact journey being erased is shown separately")
	assert_true(_modal_text().contains(WorldCopy.JOURNEY_REPLACE_BODY % "Journey 2"))
	menu._modal.chosen.emit(&"cancel")
	assert_eq(menu._modal.kind, &"journey_slot")
	assert_eq(_bytes(1), victim, "cancel writes nothing")
	(menu._modal.find_child("JourneySlot_1", true, false) as Button).pressed.emit()
	menu._modal.chosen.emit(&"replace")
	assert_eq(entered, 2)
	assert_ne(_bytes(1), victim)
	assert_eq([GameState.active_slot, SaveManager.summary(1).battles_won], [1, 0])


func test_slot_cards_fit_and_damaged_replacement_cancel_keeps_the_file() -> void:
	_journey(1, 1, 900)
	_raw(2, "{ damaged")
	var damaged_bytes := _bytes(2)
	await _title()
	menu._open_new_journey()
	menu._modal.chosen.emit(&"start")
	await _frames()
	var canvas := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for index in SaveManager.SLOT_COUNT:
		var card := menu._modal.find_child("JourneySlot_%d" % index, true, false) as Button
		assert_true(canvas.encloses(card.get_global_rect()))
		for label in card.find_children("*", "Label", true, false):
			assert_true(card.get_global_rect().encloses(label.get_global_rect()), "every save fact fits its card")
		for child in card.find_children("*", "Control", true, false):
			assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the whole card is one hit area")
	assert_true(_card_text(menu._modal.find_child("JourneySlot_1", true, false)).contains("1 victory"))
	(menu._modal.find_child("JourneySlot_2", true, false) as Button).pressed.emit()
	await _frames()
	assert_eq(tree.root.gui_get_focus_owner(), menu._modal.button(&"cancel"))
	assert_true(_modal_text().contains(WorldCopy.SAVE_SLOT_UNREADABLE))
	for action in [&"cancel", &"replace"]:
		assert_true(canvas.encloses(menu._modal.button(action).get_global_rect()))
	menu._modal.chosen.emit(&"cancel")
	assert_eq(menu._modal.kind, &"journey_slot")
	assert_eq(_bytes(2), damaged_bytes, "review and Cancel preserve the damaged save byte for byte")
	assert_true(saved.is_empty())
	assert_eq(entered, 0)
