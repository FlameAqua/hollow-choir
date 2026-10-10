class_name JourneyResult
extends RefCounted
## Outcome of one New Journey request (V0.5 UI): GameState.start_journey() records it in
## GameState.last_journey. A rejected or failed request wrote nothing over any save and left the
## live journey, the active slot and Settings exactly as they were.

enum Reason {
	OK = 0,
	## Not one of Enums.TacticalDifficulty (or no profile is authored for it).
	UNKNOWN_DIFFICULTY = 1,
	## Not an approved starter preset (GameDefaults.journey_presets).
	UNKNOWN_PRESET = 2,
	## The request names no save slot; the player must choose one explicitly.
	NO_SLOT = 3,
	## Not one of SaveSlotSummary.SLOT_COUNT slots.
	INVALID_SLOT = 4,
	## The chosen slot holds a file (readable or not) and replacement was not confirmed.
	SLOT_OCCUPIED = 5,
	## Valid, but writing the new save failed (see error); every existing save is unchanged.
	WRITE_FAILED = 6,
}

var reason: Reason = Reason.OK
## OK; ERR_INVALID_PARAMETER (rejections); ERR_ALREADY_EXISTS (SLOT_OCCUPIED); the writer's error.
var error: Error = OK
## The requested slot (-1 when none was named).
var slot: int = -1
var difficulty: int = Enums.TacticalDifficulty.ADVENTURER
var preset_id: StringName = &""
## The request confirmed replacing an occupied slot.
var replace := false
## True when an occupied slot was replaced by this successful request.
var replaced := false
## True only after the new journey was written (and then adopted by GameState).
var changed := false
## The written journey, for GameState to adopt (null unless OK).
var progress: ProgressState


func ok() -> bool:
	return reason == Reason.OK


## Default public wording (WorldCopy; presentation may restyle it).
func text() -> String:
	return reason_text(reason, slot)


static func reason_text(value: Reason, slot_index: int = -1) -> String:
	match value:
		Reason.UNKNOWN_DIFFICULTY:
			return WorldCopy.JOURNEY_UNKNOWN_DIFFICULTY
		Reason.UNKNOWN_PRESET:
			return WorldCopy.JOURNEY_UNKNOWN_PRESET
		Reason.NO_SLOT:
			return WorldCopy.JOURNEY_NO_SLOT
		Reason.INVALID_SLOT:
			return WorldCopy.JOURNEY_INVALID_SLOT % SaveSlotSummary.SLOT_COUNT
		Reason.SLOT_OCCUPIED:
			return WorldCopy.JOURNEY_SLOT_OCCUPIED % (slot_index + 1)
		Reason.WRITE_FAILED:
			return WorldCopy.JOURNEY_WRITE_FAILED
	return ""


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.SLOT_OCCUPIED:
			return ERR_ALREADY_EXISTS
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER
