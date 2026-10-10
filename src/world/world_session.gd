class_name WorldSession
extends RefCounted
## World save boundaries (V0.4 rules 5–10). Every change that matters goes through commit(): the
## live progress is copied, the copy is changed and written, and only a successful write replaces
## GameState.progress. A failed write leaves the live state exactly as it was, so nothing is
## announced or published and the caller can offer Retry save / Return to title.
##
## Discoveries and walked links are map knowledge; they go into the live state at once and reach
## the disk with the next successful commit.
##
## V0.5A: a campaign reward rides inside the commit of its accomplishment (victory, bell, latch),
## never as a second write, and reconcile() grants the catch-up an older save can still prove at
## world entry. Receipts are published only after the write succeeded. Equipment commands need the
## session-owned preparation station context, which the host opens and closes with the bench.
##
## V0.5B: the bench also hosts the Forge and Stillroom services (purchase, refund, fit,
## prepare_potion) under the same context, through the same copy → change → write → adopt path.
## Each captured entry records the fittings resolved for its weapon, so a retry never reads live
## unlocks.
##
## V0.5 UI: commit() is the one owner of the save event: EventBus.game_saved(slot, true) is emitted
## once per successful write, after the candidate was adopted, and never for a rejection, a no-op or
## a failed write (the host shows no notice of its own). Equipment, prepared supplies and the combat
## arrangement are field commands (no station; rejected during a pending or active encounter). The
## Forge anvil and the Stillroom are separate station services: each command needs the open context
## of its own service. Each entry also captures the journey's difficulty and the Hollow's arranged
## actions.
##
## Playtest revision: every successful write also publishes a SaveFact with its origin (MANUAL only
## for the explicit Save commands) and re-derives the bell journey's journal stage. Brewing adds
## finite supply stock and a saved victory removes the doses its battle used, exactly once; fittings
## are crafted one by one; the familiar and its passive are field choices; a victory reports its
## Bestiary Learnings. Changed equipment, crafting and familiar commands publish one typed fact each.

var definition: WorldDefinition
## func(candidate: ProgressState) -> Error. Defaults to the active save slot; tests inject failures.
var writer: Callable
var last_error: Error = OK
## Content for rewards and preparation: Database.registry unless a test injects another.
var registry: DefinitionRegistry
## Receipts of the last reward-capable command (commit_victory, restore_bell, open_latch,
## reconcile); empty when it granted nothing or failed.
var last_receipts: Array[RewardReadout] = []
## Loadout repairs written by the last successful reconcile().
var last_repairs := PackedStringArray()
## Outcome of the last equip(), unequip() or choose_weapon().
var last_preparation := PreparationResult.new()
## Outcome of the last purchase(), refund(), fit(), remove_fitting() or prepare_potion().
var last_crafting := CraftingResult.new()
## Outcome of the last gather(), find_secret() or strike_rune() (V0.5C).
var last_exploration := ExplorationResult.new()
## Outcome of the last arrange_action(), swap_actions() or move_action() (V0.5 UI).
var last_combat := CombatResult.new()
## Playtest revision. Outcome of the last choose_familiar() or choose_familiar_passive().
var last_familiar := FamiliarResult.new()
## One-time content migrations written by the last successful reconcile() (SupplyRules.migrate).
var last_migrations := PackedStringArray()
## Supply doses the last successful commit_victory() removed from the stock:
## [{id, name, icon_path, count, total}]; empty when the battle used none.
var last_consumed: Array[Dictionary] = []
## Bestiary Learnings of the last successful commit_victory(): one entry per enemy whose knowledge
## tier rose, with the tier before the victory was adopted. Empty after a failure or a repeat.
var last_learnings: Array[LearningReadout] = []
## Journal changes the last successful write adopted and announced (EventBus.quest_changed).
var last_quest_changes: Array[QuestChange] = []
## Exploration-only randomness (battle seeds for new entries). Never the combat RNG.
var _rng := RandomNumberGenerator.new()
## The preparation landmark whose interaction is open, or &"". Never saved.
var _station: StringName = &""
## That landmark's station service (NONE when no station is open). Never saved.
var _service: LandmarkDefinition.Service = LandmarkDefinition.Service.NONE
## True during the reconcile() write: bringing a loaded save's journal in line with its world is
## bookkeeping, never news, so that write announces no quest change.
var _quiet_quests := false


func _init(p_definition: WorldDefinition = null, p_writer: Callable = Callable(), rng_seed: int = -1) -> void:
	definition = p_definition if p_definition != null else WorldDefinition.load_default()
	writer = p_writer if p_writer.is_valid() else func(candidate: ProgressState) -> Error:
		return SaveManager.write_progress(GameState.active_slot, candidate)
	registry = Database.registry
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func world() -> WorldState:
	return GameState.progress.world


## Entering the world from the title. Validates the saved section against approved content and
## turns an interrupted battle back into an available encounter at its approach (no award).
func open() -> PackedStringArray:
	var problems := world().sanitize(definition)
	if world().pending_entry != null:
		var entry := world().pending_entry
		world().area = entry.area_id()
		world().anchor = entry.approach_anchor()
		world().pending_entry = null
	for problem in problems:
		push_warning("WorldSession: " + problem)
	return problems


## Copies the live progress, applies [param mutator] (func(candidate: ProgressState)) and writes it.
## On success the copy becomes the live progress and then the save is published once: the legacy
## game_saved, then save_completed with [param origin] (MANUAL only for the explicit Save commands),
## then any journal change the write adopted. On failure the live progress is untouched and nothing
## is announced. The candidate's journal stage is re-derived from its world before the write
## (QuestRules.sync), so the journal cannot disagree with it; [param quest_reset] marks Reset journey.
func commit(mutator: Callable, origin: SaveFact.Origin = SaveFact.Origin.AUTOMATIC, quest_reset: bool = false) -> Error:
	last_quest_changes = []
	var candidate := ProgressState.from_dict(GameState.progress.to_dict())
	mutator.call(candidate)
	var change := QuestRules.sync(candidate, definition, quest_reset)
	last_error = writer.call(candidate)
	if last_error != OK:
		return last_error
	GameState.progress = candidate
	EventBus.game_saved.emit(GameState.active_slot, true)
	EventBus.save_completed.emit(SaveFact.make(GameState.active_slot, origin))
	# A quest entering the journal through a world write means an older or loaded save had no
	# recorded stage yet: that is recorded silently. A journey created this session is announced by
	# announce_new_journey() instead.
	if change != null and change.kind != QuestChange.Kind.ACQUIRED and not _quiet_quests:
		last_quest_changes = [change]
		EventBus.quest_changed.emit(change)
	return OK


## Announces the quests a journey created this session starts with: one ACQUIRED change per active
## journal entry, published once through EventBus.quest_changed. Writes nothing (the journey's own
## first write recorded them). The host calls this at that journey's first world entry only; loading,
## reopening or rebuilding never does.
func announce_new_journey() -> Array[QuestChange]:
	var changes: Array[QuestChange] = []
	for entry in quests().active:
		var change := QuestChange.new()
		change.kind = QuestChange.Kind.ACQUIRED
		change.quest_id = entry.id
		change.title = entry.title
		change.objective = entry.objective
		change.previous_stage = -1
		change.stage = entry.stage
		changes.append(change)
	last_quest_changes = changes
	for change in changes:
		EventBus.quest_changed.emit(change)
	return changes


## The quest journal for the live save (playtest revision). Reading announces nothing.
func quests() -> QuestJournalReadout:
	return QuestRules.journal(GameState.progress, definition)


## D-009 bridge (V0.5 UI): Settings may change Tactical Difficulty at any time; the journey follows
## it in the live state at once, like map knowledge, and the next successful commit saves it. The
## next captured entry uses it; a pending entry keeps the difficulty it captured. False when
## [param tier] is not a difficulty or already the journey's.
func follow_difficulty(tier: int) -> bool:
	if not Enums.TacticalDifficulty.values().has(tier) or GameState.progress.difficulty == tier:
		return false
	GameState.progress.difficulty = tier
	return true


## Area arrival through a portal (a safe boundary).
func arrive(area_id: StringName, anchor_id: StringName) -> Error:
	if not definition.is_anchor(area_id, anchor_id):
		return ERR_INVALID_PARAMETER
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.area = area_id
		candidate.world.anchor = anchor_id
		if definition.area(area_id).landmark(anchor_id) != null:
			candidate.world.discover(anchor_id))


## Explicit save from the world menu (Save, Save and return to title, Save and Quit): the one
## MANUAL save origin. Keeps the last committed safe anchor (never raw coordinates).
func save() -> Error:
	return commit(func(_candidate: ProgressState) -> void: pass, SaveFact.Origin.MANUAL)


## A completed discrete interaction at [param landmark_id]; safe-anchor landmarks become the resume point.
func complete_interaction(area_id: StringName, landmark_id: StringName) -> Error:
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.discover(landmark_id)
		if definition.is_anchor(area_id, landmark_id):
			candidate.world.area = area_id
			candidate.world.anchor = landmark_id)


## Rings the wayside bell. Its unclaimed WORLD_FLAG rewards (the restoration reward) are granted in
## the same write; standing near the bell or winning the guard fight never grants them.
func restore_bell(area_id: StringName) -> Error:
	last_receipts = []
	if not WorldRules.can_ring_bell(world()):
		return ERR_UNAVAILABLE
	var rewards := RewardRules.rewards_for(registry, RewardDefinition.Source.WORLD_FLAG, WorldDefinition.FLAG_BELL)
	var receipts: Array[RewardReadout] = []
	var err := commit(func(candidate: ProgressState) -> void:
		candidate.world.wayside_bell_restored = true
		candidate.world.discover(&"wayside_bell")
		candidate.world.area = area_id
		candidate.world.anchor = &"wayside_bell"
		receipts.assign(RewardRules.grant(candidate, rewards)))
	return _publish(err, receipts)


## Opens the return latch. The caller has checked the far side; the flag is independent of the bell.
## Any WORLD_FLAG reward for the latch is granted in the same write (none is authored in V0.5A).
func open_latch(area_id: StringName, link_id: StringName) -> Error:
	last_receipts = []
	if world().return_latch_open:
		return ERR_ALREADY_EXISTS
	var rewards := RewardRules.rewards_for(registry, RewardDefinition.Source.WORLD_FLAG, WorldDefinition.FLAG_LATCH)
	var receipts: Array[RewardReadout] = []
	var err := commit(func(candidate: ProgressState) -> void:
		candidate.world.return_latch_open = true
		candidate.world.discover(&"return_latch")
		candidate.world.add_link(link_id)
		candidate.world.area = area_id
		candidate.world.anchor = &"return_latch"
		receipts.assign(RewardRules.grant(candidate, rewards)))
	return _publish(err, receipts)


## Menu → Reset journey: a fresh journey at the start anchor, in one write. Only the `world` section
## changes (discoveries, walked links, cleared sites, both flags, any pending entry); research,
## mastery, loadout, inventory and statistics stay, and settings live in their own file. The entry
## serial and last applied token carry over, so a completion from before the reset can never be
## applied to the new journey and a new victory is never mistaken for an old one. The host calls
## this only from its paused exploration menu, never while a battle owns the session. Reward claims
## and materials live outside `world`, so a repeated site or bell after the reset grants nothing.
## V0.5C: gathered nodes are kept (a node yields once per save and never regrows); found secrets,
## solved puzzles and rune input reset like the bell, and their claimed rewards stay claimed.
func reset_journey() -> Error:
	leave_station()
	return commit(func(candidate: ProgressState) -> void:
		var fresh := WorldState.fresh(definition)
		fresh.entry_serial = candidate.world.entry_serial
		fresh.last_applied_token = candidate.world.last_applied_token
		fresh.gathered = candidate.world.gathered.duplicate()
		candidate.world = fresh, SaveFact.Origin.AUTOMATIC, true)


# --- Exploration vocabulary (V0.5C) ----------------------------------------------------------------

## Gathers the node at GATHERING landmark [param landmark_id] (the host has checked the player is
## within its reach): records it as gathered and claims its GATHERED rewards in one write. A node
## yields once per save; a gathered node is ALREADY_DONE (no write), and Reset journey keeps it.
func gather(area_id: StringName, landmark_id: StringName) -> Error:
	var result := ExplorationResult.make(ExplorationResult.Command.GATHER, landmark_id)
	var reason := ExplorationResult.Reason.OK
	if ExplorationRules.gathering(definition, landmark_id) == null:
		reason = ExplorationResult.Reason.UNKNOWN_FEATURE
	elif world().is_gathered(landmark_id):
		reason = ExplorationResult.Reason.ALREADY_DONE
	var rewards := RewardRules.rewards_for(registry, RewardDefinition.Source.GATHERED, landmark_id)
	return _field_write(result, reason, area_id, rewards, func(candidate: ProgressState) -> void:
		candidate.world.gathered.append(landmark_id))


## Finds the revealed secret at SECRET landmark [param landmark_id]: records it as found in this
## journey and claims its SECRET_FOUND rewards in the same write. An unrevealed secret is HIDDEN and
## a found one ALREADY_DONE (no write). After Reset journey it can be found again; its reward stays
## claimed, so that write grants nothing (result.rewarded = false).
func find_secret(area_id: StringName, landmark_id: StringName) -> Error:
	var result := ExplorationResult.make(ExplorationResult.Command.SEARCH, landmark_id)
	var entry := ExplorationRules.secret(definition, landmark_id)
	var reason := ExplorationResult.Reason.OK
	if entry == null:
		reason = ExplorationResult.Reason.UNKNOWN_FEATURE
	elif not ExplorationRules.revealed(world(), entry):
		reason = ExplorationResult.Reason.HIDDEN
	elif world().is_found(landmark_id):
		reason = ExplorationResult.Reason.ALREADY_DONE
	var rewards := RewardRules.rewards_for(registry, RewardDefinition.Source.SECRET_FOUND, landmark_id)
	return _field_write(result, reason, area_id, rewards, func(candidate: ProgressState) -> void:
		candidate.world.found.append(landmark_id))


## Strikes RUNE landmark [param landmark_id]. The rune grammar (ExplorationRules.strike) advances,
## clears or completes its puzzle's saved input; completing it solves the puzzle and claims its
## PUZZLE_SOLVED rewards in the same write. Strikes on a solved puzzle are ALREADY_DONE (no write).
## See last_exploration for the typed outcome.
func strike_rune(area_id: StringName, landmark_id: StringName) -> Error:
	var result := ExplorationResult.make(ExplorationResult.Command.STRIKE, landmark_id)
	var entry := ExplorationRules.puzzle_of(definition, landmark_id)
	var reason := ExplorationResult.Reason.OK
	if entry == null:
		reason = ExplorationResult.Reason.UNKNOWN_FEATURE
	elif world().is_solved(entry.id):
		reason = ExplorationResult.Reason.ALREADY_DONE
	var rewards: Array[RewardDefinition] = []
	var step := {"outcome": ExplorationResult.Strike.NONE, "input": [] as Array[StringName]}
	if entry != null:
		result.puzzle_id = entry.id
		result.length = entry.solution.size()
		step = ExplorationRules.strike(entry, world().rune_input_of(entry.id), landmark_id)
		if step.outcome == ExplorationResult.Strike.SOLVED:
			rewards = RewardRules.rewards_for(registry, RewardDefinition.Source.PUZZLE_SOLVED, entry.id)
	var err := _field_write(result, reason, area_id, rewards, func(candidate: ProgressState) -> void:
		var input: Array[StringName] = step.input
		if step.outcome == ExplorationResult.Strike.SOLVED:
			candidate.world.solved.append(entry.id)
			candidate.world.rune_input.erase(entry.id)
		elif input.is_empty():
			candidate.world.rune_input.erase(entry.id)
		else:
			candidate.world.rune_input[entry.id] = Array(input))
	if err == OK:
		result.strike = step.outcome
		result.progress = (step.input as Array).size()
		if result.strike == ExplorationResult.Strike.SOLVED:
			result.revealed = ExplorationRules.secrets_revealed_by(definition, entry.id)
	return err


## Shared field transaction: a rejection writes nothing; otherwise [param change] runs on the commit
## candidate with the landmark charted (and made the resume point when it is a safe anchor) and
## [param rewards] granted in the same write. Receipts are published only after it succeeded.
func _field_write(result: ExplorationResult, reason: ExplorationResult.Reason, area_id: StringName,
		rewards: Array[RewardDefinition], change: Callable) -> Error:
	last_exploration = result
	last_receipts = []
	if reason == ExplorationResult.Reason.OK and world().pending_entry != null:
		reason = ExplorationResult.Reason.ENCOUNTER_PENDING
	result.reason = reason
	if reason != ExplorationResult.Reason.OK:
		result.error = ExplorationResult.error_for(reason)
		last_error = result.error
		return result.error
	var landmark_id := result.landmark_id
	var receipts: Array[RewardReadout] = []
	result.error = commit(func(candidate: ProgressState) -> void:
		change.call(candidate)
		candidate.world.discover(landmark_id)
		if definition.is_anchor(area_id, landmark_id):
			candidate.world.area = area_id
			candidate.world.anchor = landmark_id
		receipts.assign(RewardRules.grant(candidate, rewards)))
	if result.error != OK:
		result.reason = ExplorationResult.Reason.WRITE_FAILED
		return result.error
	result.rewarded = not receipts.is_empty()
	return _publish(OK, receipts)


## The public state of [param puzzle_id] in the live journey (null for an unknown puzzle).
func puzzle(puzzle_id: StringName) -> PuzzleReadout:
	var entry := ExplorationRules.puzzle(definition, puzzle_id)
	return ExplorationRules.readout(world(), definition, entry) if entry != null else null


# --- Rewards and compatibility (V0.5A) ------------------------------------------------------------

## World entry, after open(): one transaction that grants the catch-up rewards an older save can
## still prove (a cleared site or set flag without its claim; never a discovery, statistics or an
## accomplishment erased by an earlier reset) and repairs the saved equipment loadout
## (PreparationRules.repair_loadout). Writes nothing when there is nothing to do, so a second call
## is a no-op. A failed write changes nothing and publishes no receipt; calling again retries.
## Playtest revision: the same write applies the one-time supply migration (SupplyRules.migrate:
## the bounded starting stock and its durable marker; see last_migrations) and records the bell
## journey's journal stage for a save that has none or a stale one. That is silent: no quest event.
func reconcile() -> Error:
	last_receipts = []
	last_repairs = PackedStringArray()
	last_migrations = PackedStringArray()
	var probe := ProgressState.from_dict(GameState.progress.to_dict())
	var due := RewardRules.grant(probe, RewardRules.catch_up(probe, registry))
	var needed := not due.is_empty() or not PreparationRules.repair_loadout(probe, registry).is_empty() \
		or not SupplyRules.migrate(probe, registry).is_empty() or QuestRules.needs_sync(probe, definition)
	if not needed:
		last_error = OK
		return OK
	var receipts: Array[RewardReadout] = []
	var repairs: Array[String] = []
	var migrations: Array[String] = []
	_quiet_quests = true
	var err := commit(func(candidate: ProgressState) -> void:
		receipts.assign(RewardRules.grant(candidate, RewardRules.catch_up(candidate, registry)))
		repairs.append_array(Array(PreparationRules.repair_loadout(candidate, registry)))
		migrations.append_array(Array(SupplyRules.migrate(candidate, registry))))
	_quiet_quests = false
	if err == OK:
		last_repairs = PackedStringArray(repairs)
		last_migrations = PackedStringArray(migrations)
	return _publish(err, receipts)


## Reward previews for one accomplishment (e.g. an encounter site) against the live save.
func reward_previews(source: RewardDefinition.Source, source_id: StringName) -> Array[RewardReadout]:
	return RewardRules.previews(GameState.progress, registry, source, source_id)


func inventory() -> InventoryReadout:
	return PreparationRules.inventory(GameState.progress, registry)


## After a successful reward-capable write: keep and announce the receipts. Nothing on failure.
func _publish(err: Error, receipts: Array[RewardReadout]) -> Error:
	if err != OK:
		return err
	last_receipts = receipts
	for receipt in receipts:
		EventBus.rewards_granted.emit(receipt)
	return OK


# --- Preparation station (V0.5A) -------------------------------------------------------------------

## Opens the station context for the PREPARATION landmark the host has just interacted with (the
## host has checked the player is within its reach), with that landmark's service (V0.5 UI: the Forge
## anvil or the Stillroom). Session-owned and never saved: the host ends it when that interaction
## closes, on walking, transitions and battles; a saved anchor or a hidden button never stands in.
func enter_station(landmark_id: StringName) -> Error:
	var found := definition.find_landmark(landmark_id)
	if found.is_empty():
		return ERR_INVALID_PARAMETER
	var landmark: LandmarkDefinition = found[1]
	if landmark.kind != LandmarkDefinition.Kind.PREPARATION or landmark.service == LandmarkDefinition.Service.NONE:
		return ERR_INVALID_PARAMETER
	if world().pending_entry != null:
		return ERR_UNAVAILABLE
	_station = landmark_id
	_service = landmark.service
	return OK


func leave_station() -> void:
	_station = &""
	_service = LandmarkDefinition.Service.NONE


## The open station's landmark id, or &"".
func station() -> StringName:
	return _station


## The open station's service, or NONE.
func service() -> LandmarkDefinition.Service:
	return _service


## The typed equipment readout for the live save (slots, owned choices, rejection reasons).
func preparation() -> PreparationReadout:
	return PreparationRules.readout(GameState.progress, registry)


## Puts an owned, approved [param item_id] in [param slot] for the next entry snapshot. A field
## command (V0.5 UI: from Character, no station): rejected during a pending or active encounter; a
## wrong-slot, unowned, unknown item, a duplicated fitting trait or gear granting more than
## PartyLoadout.MAX_ACTIONS actions is rejected whole. Re-choosing the equipped item is an accepted
## no-op that writes nothing. The same write reconciles the combat arrangement with the new gear
## (CombatRules.reconcile; see last_preparation.actions_removed / actions_added).
func equip(slot: Enums.EquipSlot, item_id: StringName) -> Error:
	var result := PreparationResult.make(slot, item_id, PreparationRules.equipped(GameState.progress, slot))
	last_preparation = result
	result.reason = PreparationRules.availability(GameState.progress)
	if result.reason == PreparationResult.Reason.OK:
		result.reason = PreparationRules.check(GameState.progress, registry, slot, item_id)
	if result.reason != PreparationResult.Reason.OK:
		result.error = PreparationResult.error_for(result.reason)
		last_error = result.error
		return result.error
	if result.previous_id == item_id:
		last_error = OK
		return OK
	var changes := {}
	result.error = commit(func(candidate: ProgressState) -> void:
		var before := CombatRules.arrangement(candidate, registry)
		var before_names := CombatRules.names(candidate, registry)
		PreparationRules.apply(candidate, slot, item_id)
		changes.merge(CombatRules.reconcile(candidate, registry, before, before_names)))
	if result.error != OK:
		result.reason = PreparationResult.Reason.WRITE_FAILED
		return result.error
	result.changed = true
	result.actions_removed.assign(changes.removed)
	result.actions_added.assign(changes.added)
	result.actions_kept.assign(changes.kept)
	result.arrangement_before.assign(changes.before)
	result.arrangement_after.assign(changes.after)
	EventBus.preparation_completed.emit(result)
	return OK


## The unified Loadout readout for the live save (playtest revision): gear and the actions each
## source authors, the Core group, the familiar, supplies, combat positions, passives and mastery.
func loadout() -> LoadoutReadout:
	return LoadoutRules.readout(GameState.progress, registry, Database.library)


# --- Familiar (playtest revision) ---------------------------------------------------------------

## The travelling familiar, the owned choices and its passive choices for the live save.
func familiar() -> FamiliarReadout:
	return FamiliarRules.readout(GameState.progress, registry)


## Makes owned familiar [param familiar_id] travel with the party from the next encounter on, with
## its default passive selected in the same write. A field command: rejected during a pending or
## active encounter; an unknown or unowned familiar is rejected; re-choosing the travelling one is
## an accepted no-op that writes nothing. See last_familiar.
func choose_familiar(familiar_id: StringName) -> Error:
	var result := FamiliarResult.make(FamiliarResult.Command.CHOOSE_FAMILIAR)
	result.familiar_id = familiar_id
	result.previous_familiar_id = GameState.progress.loadout_familiar
	result.previous_passive_id = FamiliarRules.passive_id(GameState.progress, registry)
	var chosen: FamiliarDefinition = registry.familiars.get(familiar_id)
	var passive := chosen.default_passive() if chosen != null else null
	result.passive_id = passive.id if passive != null else &""
	return _familiar_command(result, FamiliarRules.familiar_check(GameState.progress, registry, familiar_id),
		result.previous_familiar_id != familiar_id,
		func(candidate: ProgressState) -> void: FamiliarRules.choose(candidate, chosen))


## Selects [param passive_id], one of the travelling familiar's authored passive choices, for the
## next encounter. Exactly one passive is in effect; re-choosing it is an accepted no-op.
func choose_familiar_passive(passive_id: StringName) -> Error:
	var result := FamiliarResult.make(FamiliarResult.Command.CHOOSE_PASSIVE)
	result.familiar_id = GameState.progress.loadout_familiar
	result.previous_familiar_id = result.familiar_id
	result.passive_id = passive_id
	result.previous_passive_id = FamiliarRules.passive_id(GameState.progress, registry)
	return _familiar_command(result, FamiliarRules.passive_check(GameState.progress, registry, passive_id),
		result.previous_passive_id != passive_id,
		func(candidate: ProgressState) -> void: candidate.loadout_familiar_passive = passive_id)


## Field availability, then [param check], then one atomic write. Rejections, no-ops and failed
## writes change and announce nothing; a changed command publishes familiar_changed once.
func _familiar_command(result: FamiliarResult, check: FamiliarResult.Reason, would_change: bool, change: Callable) -> Error:
	last_familiar = result
	result.reason = FamiliarRules.availability(GameState.progress)
	if result.reason == FamiliarResult.Reason.OK:
		result.reason = check
	if result.reason != FamiliarResult.Reason.OK:
		result.error = FamiliarResult.error_for(result.reason)
		result.reason_text = FamiliarRules.reason_text(result.reason)
		last_error = result.error
		return result.error
	if not would_change:
		last_error = OK
		return OK
	result.error = commit(change)
	if result.error != OK:
		result.reason = FamiliarResult.Reason.WRITE_FAILED
		result.reason_text = FamiliarRules.reason_text(result.reason)
		return result.error
	result.changed = true
	EventBus.familiar_changed.emit(result)
	return OK


## Empties an optional armor slot (garb, charm or relic); the weapon slot is REQUIRED_SLOT.
func unequip(slot: Enums.EquipSlot) -> Error:
	return equip(slot, &"")


## Bench weapon choice (V0.4 API): equip(WEAPON, weapon_id), so it needs the station and ownership.
func choose_weapon(weapon_id: StringName) -> Error:
	return equip(Enums.EquipSlot.WEAPON, weapon_id)


# --- Forge and Stillroom (V0.5B) -------------------------------------------------------------------

## The typed Forge/Stillroom readout for the live save and the open station: recipes with prices
## and reasons (WRONG_STATION for the other service's work), fitting capacity and choices, and the
## two potion slots (field choices).
func crafting() -> CraftingReadout:
	return CraftingRules.readout(GameState.progress, registry, _station, _service)


## Legacy entry point, kept so older callers work through the overlap (playtest revision): a potion
## recipe is brewed (brew), a fitting recipe crafts its fitting (craft_fitting), and an older fitting
## kit can no longer be bought (RECIPE_RETIRED). Nothing is a one-time unlock any more.
func purchase(recipe_id: StringName) -> Error:
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	if recipe != null and recipe.kind == RecipeDefinition.Kind.POTION:
		return brew(recipe_id)
	if recipe != null and recipe.kind == RecipeDefinition.Kind.FITTING and recipe.fittings.size() == 1 \
			and recipe.fittings[0] != null:
		return craft_fitting(recipe.fittings[0].id)
	var result := CraftingResult.make(CraftingResult.Command.PURCHASE)
	result.recipe_id = recipe_id
	result.changed = true
	return _station_command(result, _required(recipe), CraftingRules.purchase_check(GameState.progress, registry, recipe_id),
		func(_candidate: ProgressState) -> void: pass, recipe)


## Brews [param recipe_id] at the Stillroom (playtest revision): spends its whole price and adds its
## yield to the saved supply stock in one write. Repeatable. A wrong station, an encounter, an
## unknown or non-potion recipe, an unmet mastery gate, missing materials or a yield that would pass
## PotionDefinition.MAX_STOCK rejects the whole brew: nothing is spent and nothing is made. Brewing
## never prepares a supply position. See last_crafting (spent, produced).
func brew(recipe_id: StringName) -> Error:
	var result := CraftingResult.make(CraftingResult.Command.BREW)
	result.recipe_id = recipe_id
	result.changed = true
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	if recipe != null and recipe.potion != null:
		result.potion_id = recipe.potion.id
	return _station_command(result, LandmarkDefinition.Service.STILLROOM,
		SupplyRules.brew_check(GameState.progress, registry, recipe_id),
		func(candidate: ProgressState) -> void:
			var outcome := SupplyRules.brew(candidate, recipe)
			result.spent.assign(outcome.spent)
			result.produced.assign(outcome.produced), recipe)


## Crafts fitting [param fitting_id] at the Forge anvil (playtest revision): spends its recipe's
## whole price and records ownership in one write. The fitting is then fitted and removed for free.
## An unknown fitting, an unowned weapon, an already owned fitting (crafted, or through an older
## kit), an unmet mastery gate or missing materials rejects it and spends nothing.
func craft_fitting(fitting_id: StringName) -> Error:
	var result := CraftingResult.make(CraftingResult.Command.CRAFT)
	result.modification_id = fitting_id
	result.changed = true
	var recipe := CraftingRules.fitting_recipe(registry, fitting_id)
	if recipe != null:
		result.recipe_id = recipe.id
		result.weapon_id = recipe.weapon.id if recipe.weapon != null else &""
	return _station_command(result, LandmarkDefinition.Service.FORGE,
		CraftingRules.craft_check(GameState.progress, registry, fitting_id),
		func(candidate: ProgressState) -> void: result.spent.assign(CraftingRules.craft(candidate, recipe)), recipe)


## Reclaims a refundable recipe (the fitting kit) at the Forge anvil: returns its exact price, clears
## the unlock and the weapon's installed fitting in one write. A permanent, unowned or overflowing
## refund is rejected whole and credits nothing.
func refund(recipe_id: StringName) -> Error:
	var result := CraftingResult.make(CraftingResult.Command.REFUND)
	result.recipe_id = recipe_id
	result.changed = true
	var recipe: RecipeDefinition = registry.recipes.get(recipe_id)
	return _station_command(result, _required(recipe), CraftingRules.refund_check(GameState.progress, registry, recipe_id),
		func(candidate: ProgressState) -> void:
			var outcome := CraftingRules.refund(candidate, recipe, registry)
			result.refunded.assign(outcome.refunded)
			result.cleared_fitting = outcome.cleared, recipe)


## Installs owned fitting [param modification_id] in [param socket] of [param weapon_id] for free at
## the Forge anvil (&"" removes the fitting). The socket must be a usable one (only socket 0 today)
## and the fitting crafted, or granted by an older kit (playtest revision); fitting never spends.
## Re-choosing the installed fitting is an accepted no-op.
func fit(weapon_id: StringName, modification_id: StringName, socket: int = 0) -> Error:
	var result := CraftingResult.make(CraftingResult.Command.FIT)
	result.weapon_id = weapon_id
	result.modification_id = modification_id
	result.socket = socket
	result.previous_id = GameState.progress.weapon_fittings.get(weapon_id, &"")
	result.changed = result.previous_id != modification_id
	return _station_command(result, LandmarkDefinition.Service.FORGE,
		CraftingRules.fit_check(GameState.progress, registry, weapon_id, modification_id, socket),
		func(candidate: ProgressState) -> void: CraftingRules.set_fitting(candidate, weapon_id, modification_id),
		CraftingRules.fitting_recipe(registry, modification_id))


## The service a command on [param recipe] needs (an unknown recipe is checked at the open one).
func _required(recipe: RecipeDefinition) -> LandmarkDefinition.Service:
	return CraftingRules.service_for(recipe.station) if recipe != null else _service


## Removes the fitting in [param socket] of the weapon for free; never grants materials, and the
## fitting stays owned.
func remove_fitting(weapon_id: StringName, socket: int = 0) -> Error:
	return fit(weapon_id, &"", socket)


## Prepares [param potion_id] in supply position [param slot_index] (0 or 1) for the next
## encounter: a potion the save holds at least one dose of (playtest revision: NO_STOCK otherwise),
## not already in the other position. A field command (V0.5 UI: from Character, or the Stillroom
## screen; no station needed), rejected during a pending or active encounter. It moves no stock:
## the battle takes min(per-encounter cap, held) when it is entered. Brewing stays Stillroom work.
func prepare_potion(slot_index: int, potion_id: StringName) -> Error:
	var result := CraftingResult.make(CraftingResult.Command.PREPARE_POTION)
	result.potion_slot = slot_index
	result.potion_id = potion_id
	var potions := GameState.progress.loadout_potions
	result.previous_id = potions[slot_index] if slot_index >= 0 and slot_index < potions.size() else &""
	result.changed = result.previous_id != potion_id
	return _crafting_command(result, CraftingRules.field_availability(GameState.progress),
		CraftingRules.potion_check(GameState.progress, registry, slot_index, potion_id),
		func(candidate: ProgressState) -> void: CraftingRules.set_potion(candidate, slot_index, potion_id),
		CraftingRules.potion_recipe(registry, potion_id))


## Shared station transaction: the open station must offer [param required] (and no encounter may
## be pending), then the command's [param check]. See _crafting_command; the station is charted.
func _station_command(result: CraftingResult, required: LandmarkDefinition.Service, check: CraftingResult.Reason,
		change: Callable, recipe: RecipeDefinition) -> Error:
	return _crafting_command(result, CraftingRules.availability(GameState.progress, _service, required), check,
		change, recipe, _station)


## Availability [param available] first, then [param check]. A rejection changes and writes
## nothing; an accepted no-op writes nothing; otherwise [param change] runs on the commit candidate
## (with [param station_id] charted when given) and the result is published once, only after the
## write succeeded.
func _crafting_command(result: CraftingResult, available: CraftingResult.Reason, check: CraftingResult.Reason,
		change: Callable, recipe: RecipeDefinition, station_id: StringName = &"") -> Error:
	last_crafting = result
	result.reason = available
	if result.reason == CraftingResult.Reason.OK:
		result.reason = check
	if result.reason != CraftingResult.Reason.OK:
		result.changed = false
		result.error = CraftingResult.error_for(result.reason)
		result.reason_text = CraftingRules.reason_text(result.reason, recipe)
		last_error = result.error
		return result.error
	if not result.changed:
		last_error = OK
		return OK
	result.error = commit(func(candidate: ProgressState) -> void:
		change.call(candidate)
		if station_id != &"":
			candidate.world.discover(station_id))
	if result.error != OK:
		result.reason = CraftingResult.Reason.WRITE_FAILED
		result.reason_text = CraftingRules.reason_text(result.reason)
		result.changed = false
		result.spent.clear()
		result.refunded.clear()
		result.produced.clear()
		result.cleared_fitting = &""
		return result.error
	EventBus.crafting_completed.emit(result)
	return OK


# --- Combat arrangement (V0.5 UI) ---------------------------------------------------------------

## The Hollow's combat arrangement for the live save: positions, locks, candidates and passives.
func combat() -> CombatReadout:
	return CombatRules.readout(GameState.progress, registry, Database.library)


## PUT: [param action_id] into unlocked combat [param position]. An unarranged action replaces the
## position's action (or fills an empty position); an arranged one swaps places with it. A locked or
## missing position, a passive skill, an unknown or ungranted action is rejected; the same
## arrangement is an accepted no-op that writes nothing. See last_combat.
func arrange_action(position: int, action_id: StringName) -> Error:
	var result := CombatResult.make(CombatResult.Command.PUT)
	result.position = position
	result.action_id = action_id
	var current := CombatRules.arrangement(GameState.progress, registry)
	result.previous_id = current[position] if position >= 0 and position < current.size() else &""
	return _combat_command(result, CombatRules.put_check(GameState.progress, registry, Database.library, position,
		action_id), func() -> Array[StringName]: return CombatRules.put(current, position, action_id))


## SWAP: exchanges the actions in two unlocked, occupied positions.
func swap_actions(first: int, second: int) -> Error:
	var result := CombatResult.make(CombatResult.Command.SWAP)
	result.position = first
	result.other_position = second
	var current := CombatRules.arrangement(GameState.progress, registry)
	return _combat_command(result, CombatRules.swap_check(GameState.progress, registry, first, second),
		func() -> Array[StringName]: return CombatRules.swap(current, first, second))


## MOVE (reorder): an arranged [param action_id] to occupied [param position]; the actions between
## shift by one place.
func move_action(action_id: StringName, position: int) -> Error:
	var result := CombatResult.make(CombatResult.Command.MOVE)
	result.position = position
	result.action_id = action_id
	var current := CombatRules.arrangement(GameState.progress, registry)
	return _combat_command(result, CombatRules.move_check(GameState.progress, registry, Database.library, action_id,
		position), func() -> Array[StringName]: return CombatRules.move(current, action_id, position))


## Field availability, then [param check], then one atomic write of the explicit arrangement that
## [param arrange] returns. Rejections, no-ops and failed writes change and announce nothing.
func _combat_command(result: CombatResult, check: CombatResult.Reason, arrange: Callable) -> Error:
	last_combat = result
	result.before = CombatRules.arrangement(GameState.progress, registry)
	result.after = result.before.duplicate()
	result.reason = CombatRules.availability(GameState.progress)
	if result.reason == CombatResult.Reason.OK:
		result.reason = check
	if result.reason != CombatResult.Reason.OK:
		result.error = CombatResult.error_for(result.reason)
		result.reason_text = CombatResult.reason_text_for(result.reason)
		last_error = result.error
		return result.error
	var after: Array[StringName] = arrange.call()
	if after == result.before:
		last_error = OK
		return OK
	result.error = commit(func(candidate: ProgressState) -> void: candidate.combat_actions = after)
	if result.error != OK:
		result.reason = CombatResult.Reason.WRITE_FAILED
		result.reason_text = CombatResult.reason_text_for(result.reason)
		return result.error
	result.after = after
	result.changed = true
	return OK


# --- Encounters ----------------------------------------------------------------------------------

## Captures one immutable entry for [param site_id] and saves it before any battle launches.
## Null when the site is unavailable or the write failed (see last_error).
func begin_entry(site_id: StringName, approach_anchor: StringName) -> EncounterEntry:
	leave_station()
	var found := definition.find_landmark(site_id)
	last_error = ERR_UNAVAILABLE
	if found.is_empty() or world().pending_entry != null or world().is_cleared(site_id):
		return null
	var area: AreaDefinition = found[0]
	var site: LandmarkDefinition = found[1]
	if site.kind != LandmarkDefinition.Kind.ENCOUNTER or not definition.is_anchor(area.id, approach_anchor):
		return null
	var serial := world().entry_serial + 1
	var ids := PreparationRules.battle_ids(GameState.progress, registry)
	# Playtest revision: the entry also captures the supply allowance (min(per-encounter cap, held)
	# per prepared position) and the familiar's selected passive. Entering moves no stock.
	var entry := EncounterEntry.capture("%s#%d" % [site_id, serial], area.id, site, approach_anchor,
		_rng.randi_range(1, 999_999), GameState.progress, Settings.data, Database.registry.research,
		ids.modifications, ids.actions, ids.potion_charges, StringName(ids.familiar_passive))
	var record := func(candidate: ProgressState) -> void:
		candidate.world.entry_serial = serial
		candidate.world.pending_entry = EncounterEntry.from_dict(entry.to_dict())
		candidate.world.discover(site_id)
		candidate.world.area = area.id
		candidate.world.anchor = approach_anchor
	if commit(record) != OK:
		return null
	return entry


## Commits a victory exactly once: research/mastery, the cleared site, the site's unclaimed
## SITE_VICTORY rewards and the return boundary in one write. A repeated token is a no-op
## (ERR_ALREADY_EXISTS); a failed write changes nothing. A site cleared again after Reset journey
## commits normally but grants no reward a second time (the claim is kept).
## Playtest revision: the same write settles the supply doses the battle actually used against the
## stock (never more than the entry's captured allowance; last_consumed), and a success reports the
## Bestiary Learnings (last_learnings): each enemy whose knowledge tier rose, with the tier it had
## before this victory was adopted. A failed write adopts nothing, so a retry reports the same.
func commit_victory(entry: EncounterEntry, result: BattleResult) -> Error:
	last_receipts = []
	last_consumed = []
	last_learnings = []
	if entry.token() == world().last_applied_token:
		last_error = ERR_ALREADY_EXISTS
		return last_error
	var pending := world().pending_entry
	if pending == null or pending.token() != entry.token() or result == null or not result.is_victory():
		last_error = ERR_INVALID_PARAMETER
		return last_error
	var research := Database.registry.research
	var before: Dictionary[StringName, int] = {}
	for enemy_id: StringName in result.research:
		before[enemy_id] = GameState.research_level(enemy_id)
	var rewards := RewardRules.rewards_for(registry, RewardDefinition.Source.SITE_VICTORY, entry.site_id())
	var receipts: Array[RewardReadout] = []
	var consumed: Array[Dictionary] = []
	# The allowance settled is the saved pending entry's own (the same token as [param entry]).
	var captured := pending.loadout()
	var err := commit(func(candidate: ProgressState) -> void:
		candidate.apply_battle_result(result, research)
		if not candidate.world.cleared.has(entry.site_id()):
			candidate.world.cleared.append(entry.site_id())
		candidate.world.pending_entry = null
		candidate.world.last_applied_token = entry.token()
		candidate.world.area = entry.area_id()
		candidate.world.anchor = entry.approach_anchor()
		consumed.assign(SupplyRules.settle(candidate, registry, captured, result.item_uses))
		receipts.assign(RewardRules.grant(candidate, rewards)))
	if err != OK:
		return err
	last_consumed = consumed
	var learned_ids: Array[StringName] = []
	learned_ids.assign(before.keys())
	learned_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for enemy_id in learned_ids:
		var level := GameState.research_level(enemy_id)
		if level > before[enemy_id]:
			last_learnings.append(LearningReadout.make(Database.registry.enemies.get(enemy_id), enemy_id,
				before[enemy_id], level))
			EventBus.research_level_gained.emit(enemy_id, level)
	EventBus.battle_finished.emit(result)
	return _publish(OK, receipts)


## Quitting a battle from its pause menu: back to the approach, encounter still available, no award.
func leave_entry(entry: EncounterEntry) -> Error:
	return _close_entry(entry, entry.area_id(), entry.approach_anchor())


## Defeat → Return to Gloamstead: committed victories, discoveries and flags stay; no fee.
func return_home(entry: EncounterEntry) -> Error:
	return _close_entry(entry, definition.start_area, definition.start_anchor)


func _close_entry(entry: EncounterEntry, area_id: StringName, anchor_id: StringName) -> Error:
	var pending := world().pending_entry
	if pending == null or pending.token() != entry.token():
		last_error = ERR_INVALID_PARAMETER
		return last_error
	return commit(func(candidate: ProgressState) -> void:
		candidate.world.pending_entry = null
		candidate.world.area = area_id
		candidate.world.anchor = anchor_id)
