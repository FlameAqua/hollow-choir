class_name BattleSetup
extends RefCounted
## Everything needed to start a deterministic battle. Same setup + same inputs = same battle.

var loadout: PartyLoadout
var enemies: Array[EnemyDefinition] = []
var conditions: Array[BattlefieldConditionDefinition] = []
var advantage: Enums.Advantage = Enums.Advantage.NONE
var library: CombatLibrary
var difficulty: TacticalDifficultyProfile
var assist: ExecutionAssistProfile
## Bestiary knowledge going into the fight: enemy id -> Enums.ResearchLevel.
var research_levels: Dictionary[StringName, int] = {}
var seed: int = 1
## Optional label for logs / reports.
var label: String = ""


static func from_encounter(p_loadout: PartyLoadout, encounter: EncounterDefinition,
		p_library: CombatLibrary, p_difficulty: TacticalDifficultyProfile,
		p_assist: ExecutionAssistProfile, p_seed: int = 1) -> BattleSetup:
	var setup := BattleSetup.new()
	setup.loadout = p_loadout
	setup.enemies.assign(encounter.enemies)
	setup.conditions.assign(encounter.conditions)
	setup.advantage = encounter.advantage
	setup.library = p_library
	setup.difficulty = p_difficulty
	setup.assist = p_assist
	setup.seed = p_seed
	setup.label = encounter.display_name
	return setup


func research_level(enemy_id: StringName) -> Enums.ResearchLevel:
	return research_levels.get(enemy_id, Enums.ResearchLevel.UNKNOWN) as Enums.ResearchLevel


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if loadout == null:
		problems.append("setup has no loadout")
	else:
		problems.append_array(loadout.validate())
	if enemies.is_empty():
		problems.append("setup has no enemies")
	if library == null or library.balance == null or library.research == null:
		problems.append("setup has no combat library / balance / research config")
	if difficulty == null or assist == null:
		problems.append("setup needs difficulty and assist profiles")
	return problems
