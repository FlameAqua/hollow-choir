class_name SimulationConfig
extends RefCounted
## One batch of automated battles: the same matchup played [member runs] times with varying seeds.

var label: String = ""
var loadout: PartyLoadout
var encounter: EncounterDefinition
var library: CombatLibrary
var difficulty: TacticalDifficultyProfile
var assist: ExecutionAssistProfile
var skill: ExecutionSkillProfile
var policy: PartyAutopilot.Policy = PartyAutopilot.Policy.SMART
var research_levels: Dictionary[StringName, int] = {}
var runs: int = 100
var base_seed: int = 1


func make_setup(run_index: int) -> BattleSetup:
	var setup := BattleSetup.from_encounter(loadout, encounter, library, difficulty, assist, seed_for(run_index))
	setup.research_levels = research_levels.duplicate()
	return setup


func seed_for(run_index: int) -> int:
	return base_seed * 100003 + run_index * 7919 + 17
