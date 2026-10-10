extends TestCase
## V0.5 UI saved combat arrangement through the production WorldSession and host: put/swap/move
## write once and reject whole; locked positions accept nothing; gear changes reconcile in the same
## write with an explicit result; old saves migrate deterministically; entries capture the exact
## order so a retry never changes; the Character view drives the same commands.

const SWORD_DEFAULT := [&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance", &"inspect", &"spark"]

var kit: WorldKit
var tree: SceneTree
var host: WorldHost
var saved: Array = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	tree = Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(1280, 720)
	saved.clear()
	EventBus.game_saved.connect(_on_saved)


func after_each() -> void:
	EventBus.game_saved.disconnect(_on_saved)
	if is_instance_valid(host):
		host.queue_free()
	host = null
	kit.restore()


func _on_saved(slot: int, ok: bool) -> void:
	saved.append([slot, ok])


static func _ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


static func _hero_actions(entry: EncounterEntry) -> Array:
	var engine := BattleEngine.new(entry.build_setup(Database.registry, Database.library))
	return engine.get_state().protagonist().actions.map(func(action: ActionDefinition) -> StringName: return action.id)


func test_commands_write_once_and_reject_whole() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.combat().arranged, _ids(SWORD_DEFAULT), "the deterministic default")
	assert_eq(session.arrange_action(5, &"kindle"), OK)
	assert_eq([session.last_combat.previous_id, session.last_combat.changed], [&"spark", true])
	assert_eq(GameState.progress.combat_actions, _ids([&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance",
		&"inspect", &"kindle"]), "replace: Spark leaves, Kindle takes position 6")
	assert_eq(session.combat().unarranged, _ids([&"spark"]), "and Spark is listed, never hidden")
	assert_eq(session.swap_actions(0, 4), OK)
	assert_eq(GameState.progress.combat_actions[0], &"inspect")
	assert_eq(session.move_action(&"kindle", 0), OK)
	assert_eq(GameState.progress.combat_actions, _ids([&"kindle", &"inspect", &"lunge", &"arc_cleave", &"riposte_stance",
		&"sword_strike"]))
	assert_eq(kit.writer.writes.size(), 3)
	assert_eq(saved.size(), 3, "one save event per write")
	# The same arrangement again is an accepted no-op: no write, no event.
	assert_eq(session.arrange_action(0, &"kindle"), OK)
	assert_eq(session.swap_actions(2, 2), OK)
	assert_false(session.last_combat.changed)
	assert_eq([kit.writer.writes.size(), saved.size()], [3, 3])
	var before := _snapshot()
	for case: Array in [
			[func() -> Error: return session.arrange_action(6, &"spark"), CombatResult.Reason.LOCKED_POSITION],
			[func() -> Error: return session.arrange_action(7, &"spark"), CombatResult.Reason.LOCKED_POSITION],
			[func() -> Error: return session.arrange_action(8, &"spark"), CombatResult.Reason.INVALID_POSITION],
			[func() -> Error: return session.arrange_action(0, &"earthsplitter"), CombatResult.Reason.NOT_GRANTED],
			[func() -> Error: return session.arrange_action(0, &"pilgrims_patience"), CombatResult.Reason.PASSIVE_SKILL],
			[func() -> Error: return session.arrange_action(0, &"made_up"), CombatResult.Reason.UNKNOWN_ACTION],
			[func() -> Error: return session.swap_actions(0, 7), CombatResult.Reason.LOCKED_POSITION],
			[func() -> Error: return session.move_action(&"spark", 0), CombatResult.Reason.EMPTY_POSITION]]:
		assert_eq((case[0] as Callable).call(), ERR_INVALID_PARAMETER)
		assert_eq(session.last_combat.reason, case[1])
		assert_false(session.last_combat.changed)
		assert_eq(session.last_combat.after, session.last_combat.before)
		assert_false(session.last_combat.text().is_empty(), "a public reason")
	assert_eq(_snapshot(), before, "nothing changed")
	assert_eq([kit.writer.writes.size(), saved.size()], [3, 3], "and nothing was written or announced")
	# A failed write keeps the old arrangement; Retry repeats the exact command once.
	kit.writer.fail = true
	assert_eq(session.arrange_action(1, &"spark"), ERR_FILE_CANT_WRITE)
	assert_eq(session.last_combat.reason, CombatResult.Reason.WRITE_FAILED)
	assert_eq(_snapshot(), before)
	assert_eq(saved.size(), 3)
	kit.writer.fail = false
	assert_eq(session.arrange_action(1, &"spark"), OK)
	assert_eq(GameState.progress.combat_actions[1], &"spark")
	assert_eq(saved.size(), 4)
	# Reload: the explicit arrangement round-trips.
	var arranged := GameState.progress.combat_actions.duplicate()
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq(GameState.progress.combat_actions, arranged)


func test_entries_capture_the_order_and_a_retry_never_changes() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.arrange_action(0, &"kindle"), OK)
	var order: Array[StringName] = session.combat().arranged
	var entry := session.begin_entry(&"reedway_patrol", &"reedway_patrol")
	assert_eq(entry.to_dict().loadout.actions, Array(order).map(func(id: StringName) -> String: return String(id)))
	assert_eq(_hero_actions(entry), Array(order), "the battle's grid is the arrangement, in order")
	assert_false(_hero_actions(entry).has(&"sword_strike"), "an unplaced action is not in battle")
	# While the entry is pending nothing can change the arrangement; live edits never reach a retry.
	assert_eq(session.arrange_action(0, &"sword_strike"), ERR_UNAVAILABLE)
	assert_eq(session.last_combat.reason, CombatResult.Reason.ENCOUNTER_PENDING)
	assert_eq(session.combat().reason, CombatResult.Reason.ENCOUNTER_PENDING)
	GameState.progress.combat_actions = _ids(SWORD_DEFAULT)
	GameState.progress.loadout_weapon = &"reedbow"
	var retry := EncounterEntry.from_dict(GameState.progress.world.pending_entry.to_dict())
	assert_eq(_hero_actions(retry), Array(order))
	assert_eq(WorldKit.fingerprint(retry.build_setup(Database.registry, Database.library)),
		WorldKit.fingerprint(entry.build_setup(Database.registry, Database.library)), "identical battle")
	# An entry captured before the arrangement existed keeps every granted action (old saves).
	var legacy := entry.to_dict()
	legacy.loadout.erase("actions")
	assert_eq(_hero_actions(EncounterEntry.from_dict(legacy)).size(), 7)


func test_gear_changes_reconcile_the_arrangement_in_the_same_write() -> void:
	var session := kit.session()
	session.open()
	assert_eq(session.swap_actions(0, 4), OK) # Inspect first, the sword's basic attack fifth.
	var before: Array[StringName] = session.combat().arranged
	var option := session.preparation().slot(Enums.EquipSlot.WEAPON).option(&"mire_maul")
	var preview: Dictionary = option.combat
	var writes := kit.writer.writes.size()
	assert_eq(session.choose_weapon(&"mire_maul"), OK)
	assert_eq(kit.writer.writes.size(), writes + 1, "one write for the gear and its arrangement")
	var result := session.last_preparation
	var after: Array[StringName] = GameState.progress.combat_actions
	assert_eq(after, CombatRules.arrangement(GameState.progress, Database.registry), "saved explicitly and valid")
	assert_eq([after[0], after[5]], [&"inspect", &"spark"], "shared actions keep their positions")
	for id in after:
		assert_true(CombatRules.ids_of(CombatRules.candidates(GameState.progress, Database.registry)).has(id))
	assert_eq(result.actions_removed.map(func(entry: Dictionary) -> StringName: return entry.id),
		[&"lunge", &"arc_cleave", &"riposte_stance", &"sword_strike"])
	assert_eq(result.actions_added.map(func(entry: Dictionary) -> int: return entry.position), [1, 2, 3, 4])
	assert_eq([preview.removed, preview.added], [result.actions_removed, result.actions_added], "the option previewed it exactly")
	var summary := result.summary()
	assert_true(summary.begins_with(WorldCopy.PREP_SAVED))
	assert_true(summary.contains(WorldCopy.COMBAT_REPLACED % [result.actions_added[0].name, "Lunge", 2]), summary)
	# Garb without actions changes nothing in the arrangement; the sword brings its actions back.
	assert_eq(session.unequip(Enums.EquipSlot.GARB), OK)
	assert_true(session.last_preparation.actions_removed.is_empty() and session.last_preparation.actions_added.is_empty())
	assert_eq(session.choose_weapon(&"pilgrims_edge"), OK)
	assert_eq(GameState.progress.combat_actions, _ids([&"inspect", &"sword_strike", &"lunge", &"arc_cleave",
		&"riposte_stance", &"spark"]), "kept positions stay; freed ones refill in grid order (no per-weapon memory)")
	assert_eq(session.last_preparation.actions_added.map(func(entry: Dictionary) -> StringName: return entry.id),
		[&"sword_strike", &"lunge", &"arc_cleave", &"riposte_stance"])
	assert_ne(before, GameState.progress.combat_actions, "the custom sword order is not remembered per weapon")
	# A failed gear write changes neither the gear nor the arrangement.
	var stable := _snapshot()
	kit.writer.fail = true
	assert_eq(session.choose_weapon(&"reedbow"), ERR_FILE_CANT_WRITE)
	assert_eq(_snapshot(), stable)
	kit.writer.fail = false


func test_old_saves_migrate_deterministically() -> void:
	# A save from before the arrangement existed. Its supply stock and journal stage are already
	# recorded (the playtest revision's own one-time migration is covered by test_world_supplies.gd),
	# so the arrangement is the only thing here that could need a write.
	var old := ProgressState.new()
	SupplyRules.migrate(old, Database.registry)
	QuestRules.sync(old, WorldDefinition.load_default())
	var data := old.to_dict()
	data.erase("combat")
	data.erase("campaign")
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate({"save_version": 1, "data": data}))
	assert_true(GameState.progress.combat_actions.is_empty())
	assert_eq(GameState.progress.difficulty, Enums.TacticalDifficulty.ADVENTURER, "the deterministic default")
	var session := kit.session()
	session.open()
	assert_eq(session.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 0, "a valid older save needs no write")
	assert_eq(session.combat().arranged, _ids(SWORD_DEFAULT))
	# An edited or older arrangement larger than six (and naming an ungranted action) is repaired once.
	data.combat = {"actions": ["inspect", "crush", "sword_strike", "lunge", "arc_cleave", "riposte_stance", "kindle", "spark"]}
	GameState.progress = ProgressState.from_dict(SaveMigrator.migrate({"save_version": 1, "data": data}))
	var repairing := kit.session()
	repairing.open()
	assert_eq(repairing.reconcile(), OK)
	assert_eq(GameState.progress.combat_actions, _ids([&"inspect", &"kindle", &"sword_strike", &"lunge", &"arc_cleave",
		&"riposte_stance"]), "the saved overflow takes the freed position first")
	assert_eq(repairing.last_repairs.size(), 1)
	assert_true(repairing.last_repairs[0].contains("spark"))
	var writes := kit.writer.writes.size()
	assert_eq(repairing.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), writes, "repaired once")
	# Wrong-typed sections load as defaults.
	data.combat = {"actions": "inspect"}
	data.campaign = {"difficulty": 9, "starter": 4}
	var odd := ProgressState.from_dict(data)
	assert_eq([odd.combat_actions, odd.difficulty, odd.starter_preset], [[] as Array[StringName],
		Enums.TacticalDifficulty.ADVENTURER, &""])


func test_character_view_arranges_equips_and_shows_typed_reasons() -> void:
	host = WorldHost.new()
	host.pause_on_focus_loss = false
	host.session = kit.session()
	tree.root.add_child(host)
	for frame in 4:
		await tree.process_frame
	host.open_character_menu()
	# The unified Loadout: the readout's unplaced action is named, a destination then a source places it.
	var character := host.modal.find_child("Character", true, false) as WorldCharacterView
	assert_eq(host.session.loadout().unarranged, _ids([&"kindle"]))
	assert_true(_selection_text().contains("Kindle"), _selection_text())
	(host.modal.find_child("CombatSlot_5", true, false) as Button).pressed.emit()
	(host.modal.find_child("Source_kindle", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(GameState.progress.combat_actions[5], &"kindle")
	assert_eq(kit.writer.writes.size(), 1)
	character = host.modal.find_child("Character", true, false) as WorldCharacterView
	assert_eq([character.selected_tab_id(), character.combat_position], [&"equipment", 5], "reopened on the same position")
	assert_true(_selection_text().contains("Spark") and not _selection_text().contains("Kindle"),
		"the visible unplaced action follows the saved change: " + _selection_text())
	assert_true((host.modal.find_child("Source_kindle", true, false) as Button).button_pressed, "a placed source is highlighted")
	# Equip from the owned-choice popup in the field: the write's reconciliation arrives as structured
	# facts for the view, not as the older card's prose.
	(host.modal.find_child("Slot_weapon", true, false) as Button).pressed.emit()
	(host.modal.find_child("Owned_reedbow", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(GameState.progress.loadout_weapon, &"reedbow")
	assert_eq(kit.writer.writes.size(), 2)
	var equipped := host.session.last_preparation
	assert_eq(equipped.arrangement_after, GameState.progress.combat_actions)
	assert_true(equipped.actions_kept.map(func(entry: Dictionary) -> StringName: return entry.id).has(&"kindle"),
		"the placed spell keeps its position")
	assert_true(equipped.actions_removed.map(func(entry: Dictionary) -> StringName: return entry.id).has(&"sword_strike"))
	assert_false(host.modal._status.visible, "no long status line beside the concise view")
	assert_eq(host.notices._cards.size() + host.notices._pending.size(), 0, "an automatic save shows no card")
	assert_gt(host.notices._autosave_life, 0.0, "only the quiet save icon")
	# During an encounter the same commands are rejected with their reason; nothing is written.
	host._close_modal()
	assert_not_null(host.session.begin_entry(&"reedway_patrol", &"reedway_patrol"))
	host.open_character_menu()
	(host.modal.find_child("CombatSlot_0", true, false) as Button).pressed.emit()
	(host.modal.find_child("Source_inspect", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(kit.writer.writes.size(), 3, "only the entry was written")
	(host.modal.find_child("Slot_weapon", true, false) as Button).pressed.emit()
	var maul := host.modal.find_child("Owned_mire_maul", true, false) as Button
	assert_true(maul.disabled, "the readout already says why")
	var inspection: ItemInspectionReadout = maul.get_meta(&"inspection_readout").call(Vector2.ZERO)
	assert_true(WorldCopy.PREP_ENCOUNTER_PENDING in inspection.facts, str(inspection.facts))
	maul.pressed.emit()
	await tree.process_frame
	assert_eq(GameState.progress.loadout_weapon, &"reedbow")
	assert_eq(kit.writer.writes.size(), 3)


func _selection_text() -> String:
	return (host.modal.find_child("SelectionStatus", true, false) as Label).text
