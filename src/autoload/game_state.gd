extends Node
## The live progression state of the current save (ProgressState) plus helpers that turn it into
## battle inputs. Persisted by SaveManager; never stores node references.

var progress := ProgressState.new()
var active_slot: int = 0
var _session_resumed := false
## Outcome of the last start_journey() (V0.5 UI New Journey).
var last_journey := JourneyResult.new()
## Playtest revision: a journey was created this session and has not entered the world yet. The
## world host takes it once (take_fresh_journey) so only that first entry announces the new quest.
var _fresh_journey := false


## A complete fresh campaign of this build: ProgressState defaults plus the finite starter supplies
## (with their migration marked) and the bell journey at its first step, so it needs no world-entry
## migration. Older saves load through ProgressState.from_dict() instead and are migrated once.
func new_game() -> void:
	progress = ProgressState.new()
	SupplyRules.migrate(progress, Database.registry)
	QuestRules.sync(progress, WorldDefinition.load_default())


## Makes [param loaded] the live journey of [param slot] after a successful load or New Journey
## write: the session counts as resumed and Settings shows the journey's own Tactical Difficulty
## (D-009: still changeable at any time; WorldSession.follow_difficulty keeps the journey in step).
func adopt(loaded: ProgressState, slot: int) -> void:
	progress = loaded
	active_slot = slot
	_session_resumed = true
	_fresh_journey = false
	if int(Settings.data.tactical_difficulty) != progress.difficulty:
		Settings.set_value("tactical_difficulty", progress.difficulty)


## New Journey (V0.5 UI): validates [param options] ({difficulty, preset_id, slot, replace}), writes
## the fresh journey to the explicitly chosen slot and adopts it only after the write succeeded,
## then publishes the one save event. A rejection or failed write changes no save, no live state
## and no setting; the caller may retry the same options. [param writer]: tests inject failures
## (func(slot: int, progress: ProgressState) -> Error; default SaveManager.write_progress).
func start_journey(options: Dictionary, writer: Callable = Callable()) -> JourneyResult:
	var write := writer if writer.is_valid() else SaveManager.write_progress
	last_journey = JourneyRules.create(options, Database.registry, WorldDefinition.load_default(),
		SaveManager.summaries(), write)
	if last_journey.ok():
		adopt(last_journey.progress, last_journey.slot)
		_fresh_journey = true
		EventBus.game_saved.emit(last_journey.slot, true)
		# The first write of a journey is not one of the explicit Save commands.
		EventBus.save_completed.emit(SaveFact.make(last_journey.slot, SaveFact.Origin.AUTOMATIC))
	return last_journey


## True once after a journey was created this session (then false until the next New Journey).
func take_fresh_journey() -> bool:
	var fresh := _fresh_journey
	_fresh_journey = false
	return fresh


## Loads the active slot once per run (called by the main menu). M1 has a single implicit slot:
## progress recorded from battles is saved there and comes back next session.
func resume_session() -> bool:
	if _session_resumed:
		return false
	_session_resumed = true
	if not SaveManager.has_slot(active_slot):
		return false
	return SaveManager.load_slot(active_slot) == OK


## Bestiary knowledge to hand to a BattleSetup.
func research_levels() -> Dictionary[StringName, int]:
	return progress.bestiary.levels(Database.registry.research)


func research_level(enemy_id: StringName) -> Enums.ResearchLevel:
	return progress.bestiary.level(enemy_id, Database.registry.research)


## The campaign PartyLoadout the next encounter would capture: the saved ids (unknown ones fall
## back to the starter loadout), the active fittings and the Hollow's combat arrangement.
func build_loadout() -> PartyLoadout:
	return PreparationRules.campaign_loadout(progress, Database.registry)


func store_loadout(loadout: PartyLoadout) -> void:
	progress.loadout_weapon = loadout.weapon.id if loadout.weapon else &""
	progress.loadout_garb = loadout.garb.id if loadout.garb else &""
	progress.loadout_charm = loadout.charm.id if loadout.charm else &""
	progress.loadout_relic = loadout.relic.id if loadout.relic else &""
	progress.loadout_companion = loadout.companion.id if loadout.companion else &""
	progress.loadout_familiar = loadout.familiar.id if loadout.familiar else &""
	progress.loadout_potions.clear()
	for potion in loadout.potions:
		progress.loadout_potions.append(potion.id)


## Folds a finished battle into progression, announces new bestiary levels and saves the slot.
func record_battle(result: BattleResult) -> void:
	var research := Database.registry.research
	var before: Dictionary[StringName, int] = {}
	for enemy_id: StringName in result.research:
		before[enemy_id] = research_level(enemy_id)
	progress.apply_battle_result(result, research)
	for enemy_id: StringName in before:
		var level := research_level(enemy_id)
		if level > before[enemy_id]:
			EventBus.research_level_gained.emit(enemy_id, level)
	EventBus.battle_finished.emit(result)
	SaveManager.save_slot(active_slot)
