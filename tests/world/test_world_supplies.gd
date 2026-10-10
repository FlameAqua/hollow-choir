extends TestCase
## Playtest revision, finite supplies through the production WorldSession: Brew is an atomic,
## repeatable Stillroom command that spends ingredients and adds finite stock; an encounter entry
## captures an immutable allowance; only a saved victory removes the doses its battle used, exactly
## once; a failed write, Retry, defeat, leaving, a reload and Reset journey never spend or refill;
## an older save is granted its bounded stock once, behind a durable marker.

const STILLROOM := &"stillroom_table"
const BENCH := &"preparation_bench"
const MENDING := &"stillroom.mending_draught"
const FLASK := &"stillroom.fen_water_flask"
const SALVE := &"stillroom.clotting_salve"
const TINCTURE := &"stillroom.focus_tincture"
const PATROL := &"reedway_patrol"
const GUARD := &"bell_guard"

var kit: WorldKit
var published: Array[CraftingResult] = []
var saves: Array[SaveFact] = []


func before_each() -> void:
	kit = WorldKit.new()
	kit.isolate()
	published.clear()
	saves.clear()
	EventBus.crafting_completed.connect(_on_crafted)
	EventBus.save_completed.connect(_on_saved)


func after_each() -> void:
	EventBus.crafting_completed.disconnect(_on_crafted)
	EventBus.save_completed.disconnect(_on_saved)
	kit.restore()


func _on_crafted(result: CraftingResult) -> void:
	published.append(result)


func _on_saved(fact: SaveFact) -> void:
	saves.append(fact)


## The live progress as canonical JSON (numbers and key order as on disk).
static func _snapshot() -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(GameState.progress.to_dict())), "", true)


static func _stock(potion_id: StringName) -> int:
	return GameState.progress.supply_count(potion_id)


static func _fund(iron: int, salt: int = 0) -> void:
	var progress := GameState.progress
	progress.materials.clear()
	if iron > 0:
		progress.materials[&"bog_iron"] = iron
	if salt > 0:
		progress.materials[&"storm_salt"] = salt


## A victory result for [param site_id] in which the party used [param uses] (potion id -> doses).
static func _victory(site_id: StringName, uses: Dictionary) -> BattleResult:
	var result := WorldKit.victory(site_id)
	for potion_id: StringName in uses:
		result.item_uses[potion_id] = uses[potion_id]
	return result


static func _defeat(uses: Dictionary) -> BattleResult:
	var result := BattleResult.new()
	result.outcome = Enums.BattleOutcome.DEFEAT
	for potion_id: StringName in uses:
		result.item_uses[potion_id] = uses[potion_id]
	return result


func test_a_new_game_starts_with_the_finite_starter_batch() -> void:
	var session := kit.session()
	session.open()
	assert_eq(GameState.progress.consumables, {&"mending_draught": 4, &"fen_water_flask": 4} as Dictionary[StringName, int])
	assert_true(GameState.progress.has_migration(SupplyRules.MIGRATION))
	# World entry has nothing to grant or migrate: no write.
	assert_eq(session.reconcile(), OK)
	assert_empty(kit.writer.writes, "a current save needs no world-entry write")
	assert_empty(session.last_migrations)
	var crafting := session.crafting()
	assert_eq(crafting.supplies.size(), CraftingReadout.SUPPLY_POSITIONS)
	assert_eq([crafting.potion_slots.size(), crafting.potion_capacity], [2, 2], "two usable positions; no capacity was unlocked")
	assert_eq(crafting.stock.map(func(entry: Dictionary) -> Array: return [entry.id, entry.held, entry.prepared_slot]),
		[[&"mending_draught", 4, 0], [&"fen_water_flask", 4, 1]])


func test_brew_is_an_atomic_repeatable_stillroom_command() -> void:
	var session := kit.session()
	session.open()
	_fund(3, 1)
	# No station, the wrong station and an encounter reject it with nothing spent.
	var before := _snapshot()
	assert_eq(session.brew(SALVE), ERR_UNAVAILABLE)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NO_STATION)
	assert_eq(session.enter_station(BENCH), OK)
	assert_eq(session.brew(SALVE), ERR_UNAVAILABLE)
	assert_eq([session.last_crafting.reason, session.last_crafting.command],
		[CraftingResult.Reason.WRONG_STATION, CraftingResult.Command.BREW])
	assert_eq(session.enter_station(STILLROOM), OK)
	assert_eq(session.brew(&"stillroom.nothing"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.UNKNOWN_RECIPE)
	assert_eq(session.brew(&"forge.merciful_grip"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NOT_BREWABLE)
	assert_eq([_snapshot(), kit.writer.writes.size(), published.size(), saves.size()], [before, 0, 0, 0],
		"a rejection changes, writes and announces nothing")
	# The readout says what a brew would do before it is asked for.
	var recipe := session.crafting().recipe(SALVE)
	assert_eq([recipe.can_brew, recipe.yield_count, recipe.potion_held, recipe.potion_total_after, recipe.potion_cap,
		recipe.repeatable, recipe.owned], [true, 2, 0, 2, 1, true, false])
	assert_eq(recipe.costs.map(func(cost: Dictionary) -> Array: return [cost.id, cost.count, cost.held, cost.enough]),
		[[&"bog_iron", 1, 3, true]])
	# One brew: one write, the price spent, the yield added, one adopted fact, an automatic save.
	assert_eq(session.brew(SALVE), OK)
	var result := session.last_crafting
	assert_eq([result.command, result.changed, result.recipe_id, result.potion_id, result.operation()],
		[CraftingResult.Command.BREW, true, SALVE, &"clotting_salve", &"brew"])
	assert_eq(result.spent.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]), [[&"bog_iron", 1, 2]])
	assert_eq(result.produced.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]),
		[[&"clotting_salve", 2, 2]])
	assert_eq([GameState.progress.material_count(&"bog_iron"), _stock(&"clotting_salve")], [2, 2])
	assert_eq([kit.writer.writes.size(), published.size(), saves.size()], [1, 1, 1])
	assert_eq(saves[0].origin, SaveFact.Origin.AUTOMATIC, "a brew is an automatic save")
	assert_eq(AudioManager.operation_cue(result), AudioManager.Cue.CRAFT_BREW)
	assert_eq(GameState.progress.loadout_potions, [&"mending_draught", &"fen_water_flask"] as Array[StringName],
		"brewing prepares nothing")
	assert_true(GameState.progress.world.is_discovered(STILLROOM), "the station is charted by its own work")
	# Repeatable: the same recipe again, and a starter potion's recipe, each paying again.
	assert_eq(session.brew(SALVE), OK)
	assert_eq(session.brew(MENDING), OK)
	assert_eq([GameState.progress.material_count(&"bog_iron"), _stock(&"clotting_salve"), _stock(&"mending_draught")], [0, 4, 6])
	assert_eq(session.brew(FLASK), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INSUFFICIENT_MATERIALS)
	assert_false(session.crafting().recipe(FLASK).can_brew, "the button state follows the spent materials")
	assert_eq(session.brew(TINCTURE), OK, "the Storm Salt is its own price")
	assert_eq([kit.writer.writes.size(), published.size()], [4, 4])
	# The old purchase command still works through the overlap: it brews.
	_fund(1)
	assert_eq(session.purchase(FLASK), OK)
	assert_eq([session.last_crafting.command, _stock(&"fen_water_flask")], [CraftingResult.Command.BREW, 6])
	# A yield that would pass the ceiling rejects the whole brew: nothing spent, nothing clipped.
	_fund(2)
	GameState.progress.set_supply(&"clotting_salve", PotionDefinition.MAX_STOCK - 1)
	before = _snapshot()
	var writes := kit.writer.writes.size()
	assert_eq(session.brew(SALVE), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.STOCK_OVERFLOW)
	assert_false(session.last_crafting.text().is_empty())
	assert_eq([_snapshot(), kit.writer.writes.size()], [before, writes])
	# Nothing can be brewed during an encounter.
	assert_not_null(session.begin_entry(PATROL, PATROL))
	assert_eq(session.enter_station(STILLROOM), ERR_UNAVAILABLE)
	assert_eq(session.brew(SALVE), ERR_UNAVAILABLE)


func test_a_failed_brew_write_changes_nothing_and_a_retry_brews_once() -> void:
	var session := kit.session()
	session.open()
	_fund(1)
	session.enter_station(STILLROOM)
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(session.brew(SALVE), ERR_FILE_CANT_WRITE)
	var failed := session.last_crafting
	assert_eq([failed.reason, failed.changed, failed.spent.size(), failed.produced.size(), failed.operation()],
		[CraftingResult.Reason.WRITE_FAILED, false, 0, 0, &""])
	assert_eq(AudioManager.operation_cue(failed), -1, "a failed write is silent")
	assert_eq([_snapshot(), published.size(), saves.size()], [before, 0, 0])
	kit.writer.fail = false
	assert_eq(session.brew(SALVE), OK)
	assert_eq([GameState.progress.material_count(&"bog_iron"), _stock(&"clotting_salve"), published.size(), saves.size()],
		[0, 2, 1, 1], "the retry spends and brews exactly once")
	# Reload: the stock and the spent materials are what was written.
	var reloaded := ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq([reloaded.supply_count(&"clotting_salve"), reloaded.material_count(&"bog_iron")], [2, 0])


func test_preparing_a_supply_needs_stock_and_moves_none() -> void:
	var session := kit.session()
	session.open()
	# A field command: no station. A potion with no dose cannot be prepared.
	assert_eq(session.prepare_potion(0, &"clotting_salve"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.NO_STOCK)
	assert_eq(session.prepare_potion(2, &"mending_draught"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.INVALID_POTION_SLOT, "positions 2 and 3 are locked")
	assert_empty(kit.writer.writes)
	GameState.progress.set_supply(&"clotting_salve", 3)
	var stock_before := GameState.progress.consumables.duplicate()
	assert_eq(session.prepare_potion(0, &"clotting_salve"), OK)
	assert_eq([session.last_crafting.changed, session.last_crafting.operation(), published.size(), kit.writer.writes.size()],
		[true, &"prepare", 1, 1])
	assert_eq(AudioManager.operation_cue(session.last_crafting), AudioManager.Cue.UI_EQUIP)
	assert_eq(GameState.progress.consumables, stock_before, "preparing moves no stock")
	assert_eq(GameState.progress.loadout_potions, [&"clotting_salve", &"fen_water_flask"] as Array[StringName])
	# Re-choosing it is the accepted no-op, with or without stock: no write, no fact.
	assert_eq(session.prepare_potion(0, &"clotting_salve"), OK)
	GameState.progress.set_supply(&"clotting_salve", 0)
	assert_eq(session.prepare_potion(0, &"clotting_salve"), OK)
	assert_eq([session.last_crafting.changed, published.size(), kit.writer.writes.size()], [false, 1, 1])
	assert_eq(AudioManager.operation_cue(session.last_crafting), -1)
	# The depleted choice is kept and shown as depleted; the next battle would start it empty.
	var slot := session.loadout().supply(0)
	assert_eq([slot.state, slot.potion_id, slot.held, slot.usable], [PotionSlotReadout.State.DEPLETED, &"clotting_salve", 0, 0])
	assert_eq(PreparationRules.battle_ids(GameState.progress, session.registry).potion_charges, [0, 2])
	# The duplicate rule is unchanged.
	assert_eq(session.prepare_potion(1, &"clotting_salve"), ERR_INVALID_PARAMETER)
	assert_eq(session.last_crafting.reason, CraftingResult.Reason.DUPLICATE_POTION)


func test_an_entry_captures_the_allowance_and_a_saved_victory_settles_it_once() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.set_supply(&"mending_draught", 3)
	var entry := session.begin_entry(GUARD, GUARD)
	assert_not_null(entry)
	assert_eq(entry.loadout().potion_charges, [2, 2], "min(per-encounter cap, held) per prepared position")
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask")], [3, 4], "entering moves no stock")
	var setup := entry.build_setup(Database.registry, Database.library)
	assert_eq(setup.loadout.potion_charges, [2, 2] as Array[int])
	# The battle itself starts with the captured allowance.
	var driver := BattleDriver.new(setup)
	driver.next_request()
	assert_eq(driver.engine.get_state().potion_slots.map(func(slot: PotionSlotState) -> int: return slot.charges), [2, 2])
	# Victory: the doses the battle actually used leave the stock in the victory's own write.
	var writes := kit.writer.writes.size()
	assert_eq(session.commit_victory(entry, _victory(GUARD, {&"mending_draught": 2, &"fen_water_flask": 1})), OK)
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask")], [1, 3])
	assert_eq(session.last_consumed.map(func(line: Dictionary) -> Array: return [line.id, line.count, line.total]),
		[[&"fen_water_flask", 1, 3], [&"mending_draught", 2, 1]])
	assert_eq(kit.writer.writes.size(), writes + 1, "settlement rides inside the victory's write")
	var written := ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_eq([written.supply_count(&"mending_draught"), written.supply_count(&"fen_water_flask")], [1, 3])
	# The same result committed again is a no-op: nothing is charged twice.
	assert_eq(session.commit_victory(entry, _victory(GUARD, {&"mending_draught": 2, &"fen_water_flask": 1})), ERR_ALREADY_EXISTS)
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask"), kit.writer.writes.size()], [1, 3, writes + 1])
	assert_empty(session.last_consumed)
	# The next entry's allowance follows what is left: never refilled above the stock.
	var next := session.begin_entry(PATROL, PATROL)
	assert_eq(next.loadout().potion_charges, [1, 2])
	# A battle that used nothing settles nothing.
	assert_eq(session.commit_victory(next, _victory(PATROL, {})), OK)
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask")], [1, 3])
	assert_empty(session.last_consumed)


func test_a_failed_victory_write_spends_nothing_and_its_retry_spends_once() -> void:
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(GUARD, GUARD)
	var result := _victory(GUARD, {&"mending_draught": 2})
	var before := _snapshot()
	kit.writer.fail = true
	assert_eq(session.commit_victory(entry, result), ERR_FILE_CANT_WRITE)
	assert_eq(_snapshot(), before, "the failed write adopted nothing")
	assert_eq(_stock(&"mending_draught"), 4)
	assert_empty(session.last_consumed)
	kit.writer.fail = false
	assert_eq(session.commit_victory(entry, result), OK, "Retry save repeats the same commit")
	assert_eq(_stock(&"mending_draught"), 2, "the uses are settled exactly once")
	assert_eq(session.commit_victory(entry, result), ERR_ALREADY_EXISTS)
	assert_eq(_stock(&"mending_draught"), 2)


func test_retry_defeat_leave_and_reload_never_spend_or_refill() -> void:
	var session := kit.session()
	session.open()
	GameState.progress.set_supply(&"mending_draught", 2)
	var entry := session.begin_entry(PATROL, PATROL)
	var stock := GameState.progress.consumables.duplicate()
	var writes := kit.writer.writes.size()
	# Defeat -> Retry: the host relaunches the same entry and writes nothing. The retried battle
	# starts with the same captured allowance, whatever the lost attempt drank.
	var first := entry.build_setup(Database.registry, Database.library)
	var retry := GameState.progress.world.pending_entry.build_setup(Database.registry, Database.library)
	assert_eq([first.loadout.potion_charges, retry.loadout.potion_charges], [[2, 2] as Array[int], [2, 2] as Array[int]])
	assert_eq(WorldKit.fingerprint(retry), WorldKit.fingerprint(first), "an identical battle")
	assert_eq([GameState.progress.consumables, kit.writer.writes.size()], [stock, writes], "a retry charges nothing")
	# Defeat -> Return to Gloamstead: the attempt and its uses are discarded ("no fee").
	assert_eq(session.return_home(entry), OK)
	assert_eq(GameState.progress.consumables, stock)
	assert_null(GameState.progress.world.pending_entry)
	# Leave battle: the same.
	entry = session.begin_entry(PATROL, PATROL)
	assert_eq(session.leave_entry(entry), OK)
	assert_eq(GameState.progress.consumables, stock)
	# A defeat is never a victory: committing it is rejected and spends nothing.
	entry = session.begin_entry(PATROL, PATROL)
	assert_eq(session.commit_victory(entry, _defeat({&"mending_draught": 2})), ERR_INVALID_PARAMETER)
	assert_eq(GameState.progress.consumables, stock)
	# Quit mid-battle and reload: the pending entry becomes the approach again; nothing is spent,
	# nothing is refilled, and nothing is granted by loading.
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	assert_not_null(GameState.progress.world.pending_entry)
	var resumed := kit.session()
	resumed.open()
	assert_null(GameState.progress.world.pending_entry, "the interrupted attempt is discarded")
	assert_eq(resumed.reconcile(), OK)
	assert_eq(GameState.progress.consumables, stock)
	assert_empty(resumed.last_migrations, "a reload never grants supplies")
	# Reset journey keeps the stock and the marker: no refill.
	GameState.progress.set_supply(&"mending_draught", 0)
	assert_eq(resumed.reset_journey(), OK)
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask")], [0, 4])
	assert_true(GameState.progress.has_migration(SupplyRules.MIGRATION))
	assert_eq(resumed.reconcile(), OK)
	assert_eq(_stock(&"mending_draught"), 0, "an exhausted stock is never migrated again")


func test_an_older_save_is_granted_its_bounded_stock_once_at_world_entry() -> void:
	# A V0.5 save: both Stillroom recipes owned, Clotting Salve prepared, no stock, no marker, and
	# an encounter left pending by a quit.
	var old := ProgressState.new()
	old.add_recipe(SALVE)
	old.add_recipe(TINCTURE)
	old.loadout_potions = [&"mending_draught", &"clotting_salve"]
	var data := JSON.parse_string(JSON.stringify(old.to_dict())) as Dictionary
	data.erase("migrations")
	data.erase("quests")
	(data.inventory as Dictionary).erase("consumables")
	(data.loadout as Dictionary).erase("familiar_passive")
	GameState.progress = ProgressState.from_dict(data)
	var session := kit.session()
	session.open()
	assert_not_null(session.begin_entry(PATROL, PATROL), "an entry from before the migration")
	GameState.progress = ProgressState.from_dict(JSON.parse_string(JSON.stringify(kit.writer.last())))
	(GameState.progress.world.pending_entry._data.loadout as Dictionary).erase("potion_charges")
	GameState.progress.consumables.clear()
	GameState.progress.migrations.clear()
	kit.writer.writes.clear()
	# World entry: the old pending entry is discarded, then one write migrates.
	var entered := kit.session()
	entered.open()
	assert_null(GameState.progress.world.pending_entry)
	assert_eq(entered.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 1, "one migration write")
	assert_eq(GameState.progress.consumables, {&"mending_draught": 4, &"fen_water_flask": 4, &"clotting_salve": 2,
		&"focus_tincture": 2} as Dictionary[StringName, int])
	assert_eq(entered.last_migrations.size(), 5)
	assert_empty(entered.last_repairs, "a migration is not a loadout repair")
	assert_eq(GameState.progress.loadout_potions, [&"mending_draught", &"clotting_salve"] as Array[StringName],
		"the prepared choices are kept")
	assert_empty(entered.last_quest_changes, "an older save's journal is recorded silently")
	# The second entry writes nothing; stock used to zero stays at zero.
	assert_eq(entered.reconcile(), OK)
	assert_eq(kit.writer.writes.size(), 1)
	GameState.progress.consumables.clear()
	assert_eq(entered.reconcile(), OK)
	assert_empty(GameState.progress.consumables)
	assert_eq(kit.writer.writes.size(), 1)
	# A failed migration write changes nothing and the next entry retries it.
	GameState.progress = ProgressState.from_dict(data)
	var failing := kit.session()
	failing.open()
	kit.writer.fail = true
	assert_eq(failing.reconcile(), ERR_FILE_CANT_WRITE)
	assert_empty(GameState.progress.consumables)
	assert_false(GameState.progress.has_migration(SupplyRules.MIGRATION))
	kit.writer.fail = false
	assert_eq(failing.reconcile(), OK)
	assert_eq(_stock(&"clotting_salve"), 2)


func test_a_real_battle_consumes_through_the_whole_path() -> void:
	# Entry -> real engine -> the engine's own use count -> the victory commit.
	var session := kit.session()
	session.open()
	var entry := session.begin_entry(PATROL, PATROL)
	var driver := BattleDriver.new(entry.build_setup(Database.registry, Database.library))
	driver.to_player_turn()
	assert_eq(driver.act(&"use_mending_draught", driver.hero().uid), OK)
	driver.to_player_turn()
	var uses := driver.engine.build_result().item_uses
	assert_eq(uses, {&"mending_draught": 1} as Dictionary[StringName, int])
	var result := WorldKit.victory(PATROL)
	result.item_uses = uses
	assert_eq(session.commit_victory(entry, result), OK)
	assert_eq([_stock(&"mending_draught"), _stock(&"fen_water_flask")], [3, 4])
	# Practice and the Lab never touch campaign stock: recording a battle changes none of it.
	var stock := GameState.progress.consumables.duplicate()
	var practice := BattleResult.new()
	practice.outcome = Enums.BattleOutcome.VICTORY
	practice.item_uses[&"mending_draught"] = 2
	GameState.progress.apply_battle_result(practice, Database.registry.research)
	assert_eq(GameState.progress.consumables, stock)
