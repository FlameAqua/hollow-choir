class_name BattleResult
extends RefCounted
## What a finished battle hands back to progression (GameState) and to tools.

var outcome: Enums.BattleOutcome = Enums.BattleOutcome.NONE
var rounds: int = 0
var seed: int = 0
## enemy id -> research sources awarded this battle (Enums.ResearchSource values).
var research: Dictionary[StringName, PackedInt32Array] = {}
## weapon id -> actions performed with it / of which Perfect (feeds weapon Mastery).
var weapon_uses: Dictionary[StringName, int] = {}
var weapon_perfects: Dictionary[StringName, int] = {}
var defeated_enemies: Array[StringName] = []
## Inputs submitted, for exact replays (see BattleReplay).
var input_log: Array[Dictionary] = []


func is_victory() -> bool:
	return outcome == Enums.BattleOutcome.VICTORY
