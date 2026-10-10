extends Node
## Global signals for decoupled communication between scenes and systems. Battle logic never uses
## this: it reports through BattleEvents. Only cross-scene facts belong here.

## A battle finished and its result was recorded into GameState.
signal battle_finished(result: BattleResult)
## An enemy's bestiary level went up (enemy id, new Enums.ResearchLevel).
signal research_level_gained(enemy_id: StringName, level: int)
## A world write granted a campaign reward (V0.5A). Emitted once per receipt, only after the save
## succeeded; a failed write emits nothing. WorldSession.last_receipts holds the same receipts.
signal rewards_granted(receipt: RewardReadout)
## A Forge/Stillroom station command changed the save (V0.5B purchase, refund, fitting or potion
## choice). Emitted once, only after the write succeeded; rejections, no-ops and failed writes emit
## nothing. WorldSession.last_crafting holds the same result (spent/refunded receipts included).
signal crafting_completed(result: CraftingResult)
## Playtest revision: an equip or unequip changed the save. Emitted once, only after the write
## succeeded; a rejection, a re-choice or a failed write emits nothing. WorldSession.last_preparation
## holds the same result (result.operation() names it for feedback).
signal preparation_completed(result: PreparationResult)
## Playtest revision: the travelling familiar or its selected passive changed in the save. Emitted
## once, only after the write succeeded.
signal familiar_changed(result: FamiliarResult)
## Playtest revision: the bell journey's journal entry changed in the save (acquired, advanced,
## completed or reset). Emitted once per adopted change, after the save events. Loading, opening the
## world and old-save reconciliation never emit it.
signal quest_changed(change: QuestChange)
## Settings were changed and applied.
signal settings_changed
## The player switched between keyboard/mouse and gamepad; prompts should show the new bindings.
signal input_device_changed
## A save slot was written (slot, success). Kept for older listeners; presentation should use
## save_completed, which also says whether the player asked for the save.
signal game_saved(slot: int, ok: bool)
## Playtest revision: a save slot was written successfully (after adoption), with its origin: MANUAL
## for Save, Save and return to title and Save and Quit; AUTOMATIC for every other write. Never
## emitted for a rejection, a no-op or a failed write. One per write, after game_saved.
signal save_completed(fact: SaveFact)
## A save slot was loaded into GameState.
signal game_loaded(slot: int)
## Short player-facing notice ("Saved", "Bestiary updated").
signal toast(text: String)
