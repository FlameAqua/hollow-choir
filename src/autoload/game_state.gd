extends Node
## The live progression state of the current save (ProgressState) plus helpers that turn it into
## battle inputs. Persisted by SaveManager; never stores node references.

var progress := ProgressState.new()
var active_slot: int = 0
var _session_resumed := false


func new_game() -> void:
	progress = ProgressState.new()


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


## Builds a PartyLoadout from the saved ids (unknown ids fall back to the starter loadout).
func build_loadout() -> PartyLoadout:
	return PartyLoadout.from_ids(Database.registry, progress.to_dict().loadout)


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
