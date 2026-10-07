extends Node
## Global signals for decoupled communication between scenes and systems. Battle logic never uses
## this: it reports through BattleEvents. Only cross-scene facts belong here.

## A battle finished and its result was recorded into GameState.
signal battle_finished(result: BattleResult)
## An enemy's bestiary level went up (enemy id, new Enums.ResearchLevel).
signal research_level_gained(enemy_id: StringName, level: int)
## Settings were changed and applied.
signal settings_changed
## A save slot was written (slot, success).
signal game_saved(slot: int, ok: bool)
## A save slot was loaded into GameState.
signal game_loaded(slot: int)
## Short player-facing notice ("Saved", "Bestiary updated").
signal toast(text: String)
