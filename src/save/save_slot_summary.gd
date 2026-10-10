class_name SaveSlotSummary
extends RefCounted
## What the title shows for one save slot (V0.5 UI): built by SaveManager.summary() without loading
## the slot into GameState, without writing and without logging an error for a damaged file. Only a
## READY slot can be loaded; every other non-EMPTY state still counts as occupied, so New Journey
## never writes over it without an explicit replacement.

## The number of save slots. SaveManager.SLOT_COUNT aliases it; pure rules use this one, because
## tool scripts compile them before the autoloads (SaveManager, GameState) exist.
const SLOT_COUNT := 3

enum State {
	## No file in the slot.
	EMPTY = 0,
	## A readable save of this build's version (or an older one the migrator upgrades).
	READY = 1,
	## The file exists but is not a readable save (invalid JSON, no version or no data section).
	UNREADABLE = 2,
	## Written by a newer build (save_version above SaveMigrator.CURRENT_VERSION).
	UNSUPPORTED = 3,
}

var slot: int = 0
var state: State = State.EMPTY
## Seconds since the Unix epoch (UTC) from the save envelope; 0 when unknown.
var saved_at_unix: int = 0
## "2026-10-10 14:03 UTC", or WorldCopy.SAVE_TIME_UNKNOWN when the time is missing.
var saved_at_text: String = ""
var save_version: int = 0
var game_version: String = ""
var battles_won: int = 0
## The equipped weapon id and its public name ("" when unknown content).
var weapon_id: StringName = &""
var weapon_name: String = ""
## The journey's Tactical Difficulty (Enums.TacticalDifficulty) and its public name.
var difficulty: int = Enums.TacticalDifficulty.ADVENTURER
var difficulty_name: String = ""
## The New Journey starter preset id (&"" for older saves).
var starter_preset: StringName = &""
## Public wording for a slot that cannot be loaded ("" when READY or EMPTY).
var reason_text: String = ""


func loadable() -> bool:
	return state == State.READY


func occupied() -> bool:
	return state != State.EMPTY


## "Journey 2" (slots are numbered from one for players).
func label() -> String:
	return WorldCopy.SAVE_SLOT_LABEL % (slot + 1)


## Newest first; equal times (including unknown ones) by slot number, so the order is total.
static func newest_first(a: SaveSlotSummary, b: SaveSlotSummary) -> bool:
	if a.saved_at_unix != b.saved_at_unix:
		return a.saved_at_unix > b.saved_at_unix
	return a.slot < b.slot


## The UTC text for [param unix] (whole minutes), or WorldCopy.SAVE_TIME_UNKNOWN for 0 or less.
static func utc_text(unix: int) -> String:
	if unix <= 0:
		return WorldCopy.SAVE_TIME_UNKNOWN
	var stamp := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d UTC" % [stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute]
